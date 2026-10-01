import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'order_service.dart';

enum LocationSharingStatus { starting, sharing, serviceDisabled, permissionDenied, permissionDeniedForever, stopped }

/// Publishes the rider's GPS position to `orders/{orderId}.riderLocation`
/// during an active delivery. The customer's tracking screen streams that
/// field, so they see the boat move in real time.
///
/// - [positions] re-emits every GPS fix immediately for the rider's own map.
/// - Firestore writes are throttled: at most one every [minPublishInterval],
///   unless the rider has moved [publishDistanceMeters] since the last one.
class RiderLocationBroadcaster extends ChangeNotifier {
  RiderLocationBroadcaster({
    required this.orderId,
    @visibleForTesting Stream<LatLng> Function()? positionSource,
    @visibleForTesting Future<void> Function(String orderId, LatLng position)? publisher,
    @visibleForTesting DateTime Function()? clock,
  })  : _positionSource = positionSource,
        _publisher = publisher ?? ((id, p) => OrderService.updateRiderLocation(id, p.latitude, p.longitude)),
        _clock = clock ?? DateTime.now;

  final String orderId;
  final Stream<LatLng> Function()? _positionSource;
  final Future<void> Function(String orderId, LatLng position) _publisher;
  final DateTime Function() _clock;

  static const minPublishInterval = Duration(seconds: 3);
  static const double publishDistanceMeters = 20;
  static const _distance = Distance();

  final _positions = StreamController<LatLng>.broadcast();
  StreamSubscription<LatLng>? _subscription;

  LocationSharingStatus _status = LocationSharingStatus.stopped;
  LocationSharingStatus get status => _status;

  LatLng? _lastPosition;
  LatLng? get lastPosition => _lastPosition;

  LatLng? _lastPublished;
  DateTime? _lastPublishedAt;
  DateTime? get lastPublishedAt => _lastPublishedAt;

  /// Set when the latest upload failed (e.g. offline); cleared by the next success.
  bool _publishFailing = false;
  bool get publishFailing => _publishFailing;

  bool _disposed = false;

  /// The rider's own position, as soon as the phone reports it.
  Stream<LatLng> get positions => _positions.stream;

  void _setStatus(LocationSharingStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  /// Checks permissions and starts sharing. Safe to call again (e.g. after the
  /// rider enabled location in Settings).
  Future<void> start() async {
    await _subscription?.cancel();
    _setStatus(LocationSharingStatus.starting);

    final Stream<LatLng> source;
    if (_positionSource != null) {
      source = _positionSource();
    } else {
      if (!await Geolocator.isLocationServiceEnabled()) return _setStatus(LocationSharingStatus.serviceDisabled);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return _setStatus(LocationSharingStatus.permissionDeniedForever);
      if (permission == LocationPermission.denied) return _setStatus(LocationSharingStatus.permissionDenied);

      // Publish a first fix right away so the customer sees the boat immediately.
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
        _onPosition(LatLng(current.latitude, current.longitude));
      } catch (_) {
        // The stream below delivers a fix shortly anyway.
      }
      source = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).map((p) => LatLng(p.latitude, p.longitude));
    }

    if (_disposed) return;
    _subscription = source.listen(_onPosition, onError: (_) => _setStatus(LocationSharingStatus.serviceDisabled));
    _setStatus(LocationSharingStatus.sharing);
  }

  void _onPosition(LatLng position) {
    if (_disposed) return;
    _lastPosition = position;
    _positions.add(position);
    if (_shouldPublish(position)) _publish(position);
  }

  bool _shouldPublish(LatLng position) {
    if (_lastPublished == null || _lastPublishedAt == null) return true;
    if (_clock().difference(_lastPublishedAt!) >= minPublishInterval) return true;
    return _distance.as(LengthUnit.Meter, _lastPublished!, position) >= publishDistanceMeters;
  }

  Future<void> _publish(LatLng position) async {
    _lastPublished = position;
    _lastPublishedAt = _clock();
    try {
      await _publisher(orderId, position);
      if (_publishFailing) {
        _publishFailing = false;
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      // Offline or denied: keep going; the next fix retries.
      if (!_publishFailing) {
        _publishFailing = true;
        if (!_disposed) notifyListeners();
      }
    }
  }

  /// Opens the right Settings page for the current problem.
  Future<void> openSettings() async {
    if (_status == LocationSharingStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Stops GPS and uploads (e.g. once the order is delivered).
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _setStatus(LocationSharingStatus.stopped);
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _positions.close();
    super.dispose();
  }
}
