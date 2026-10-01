import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/campus_geofence.dart';
import '../core/app_theme.dart';
import 'premium_paddling_boat.dart';

/// Mapbox access token, passed at build time so it never lives in source:
///   flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
/// Without it the map uses Esri satellite imagery with Esri road and place
/// labels, which gives the same "hybrid" look and needs no key.
const String kMapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

/// Who is looking at the map; changes the wording, not the data.
enum TrackingViewer { customer, rider }

/// Live delivery map shared by the customer's tracking screen and the rider's
/// active-delivery screen: satellite + labels, locked to CSU Cabadbaran
/// Campus, with the delivery zone, drop-off and stall pins, the rider as the
/// animated PaddlerBites boat, and the trail travelled so far.
///
/// Rider positions arrive as a `Stream<LatLng>`: the order's `riderLocation`
/// from Firestore for customers, or the phone's own GPS for the rider.
class DeliveryTrackingMap extends StatefulWidget {
  /// Customer's drop-off pin.
  final LatLng dropoff;

  /// Stall the order is picked up from (optional pin).
  final LatLng? pickup;

  /// Live rider positions.
  final Stream<LatLng> driverLocations;

  /// Last known rider position, shown before the stream emits.
  final LatLng? initialDriverLocation;

  final String riderName;
  final TrackingViewer viewer;

  /// Extra space covered by overlays (e.g. a bottom sheet) that the initial
  /// framing should avoid.
  final EdgeInsets overlayPadding;

  /// When set, the map opens centred exactly on this point (within the area
  /// not covered by [overlayPadding]) instead of framing the pins.
  final LatLng? initialCenter;
  final double initialZoom;

  /// Highest zoom (e.g. 21 for close-up satellite detail).
  final double maxZoom;

  /// When set, a back button leads the top bar.
  final VoidCallback? onBack;

  const DeliveryTrackingMap({
    super.key,
    required this.dropoff,
    required this.driverLocations,
    this.pickup,
    this.initialDriverLocation,
    this.riderName = 'Your rider',
    this.viewer = TrackingViewer.customer,
    this.overlayPadding = EdgeInsets.zero,
    this.initialCenter,
    this.initialZoom = 17,
    this.maxZoom = 21,
    this.onBack,
  });

  @override
  State<DeliveryTrackingMap> createState() => _DeliveryTrackingMapState();
}

class _DeliveryTrackingMapState extends State<DeliveryTrackingMap> {
  static const double _minZoom = 16.5;
  double get _maxZoom => widget.maxZoom;
  static const _distance = Distance();

  final _mapController = MapController();
  StreamSubscription<LatLng>? _subscription;

  /// Current rider position; null until the first location arrives.
  LatLng? _driver;

  /// Every rider position received, oldest first; drawn as the trail.
  final List<LatLng> _trail = [];

  /// Lowest zoom the current viewport allows (see [build]).
  double _currentMinZoom = _minZoom;

  double? get _metersToCustomer =>
      _driver == null ? null : _distance.as(LengthUnit.Meter, _driver!, widget.dropoff);

  @override
  void initState() {
    super.initState();
    if (widget.initialDriverLocation != null) _onDriverLocation(widget.initialDriverLocation!, rebuild: false);
    _subscription = widget.driverLocations.listen(_onDriverLocation);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Moves the rider marker and extends the trail.
  void _onDriverLocation(LatLng position, {bool rebuild = true}) {
    if (_trail.isNotEmpty && _trail.last == position) return; // no movement
    final isFirst = _driver == null;
    void update() {
      _driver = position;
      _trail.add(position);
    }

    if (rebuild && mounted) {
      setState(update);
      // The rider may appear far from the drop-off; frame both once. Later
      // updates don't move the camera, so the customer can pan freely.
      if (isFirst && widget.initialCenter == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _recenter() : null);
      }
    } else {
      update();
    }
  }

  void _recenter() {
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: [widget.dropoff, ?_driver],
      padding: _framePadding,
      minZoom: _currentMinZoom,
      maxZoom: 18,
    ));
  }

  EdgeInsets get _framePadding => const EdgeInsets.fromLTRB(60, 110, 60, 60) + widget.overlayPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // `contain` freezes the map when the viewport is bigger than its bounds,
        // so on tall screens the minimum zoom rises just enough above 16.5 to fit.
        final fillZoom = CampusGeofence.zoomToFill(CampusGeofence.cameraBounds, constraints.maxWidth, constraints.maxHeight);
        final minZoom = math.min(_maxZoom, math.max(_minZoom, (fillZoom * 4).ceil() / 4));
        _currentMinZoom = minZoom;

        return Stack(
          children: [
            FlutterMap(
              key: ValueKey(minZoom),
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: widget.initialCenter != null
                    // A single point fitted at a fixed zoom = centred exactly on it,
                    // in the part of the map the sheet doesn't cover.
                    ? CameraFit.coordinates(
                        coordinates: [widget.initialCenter!],
                        padding: widget.overlayPadding,
                        minZoom: math.max(minZoom, widget.initialZoom),
                        maxZoom: math.max(minZoom, widget.initialZoom),
                      )
                    : CameraFit.coordinates(
                        coordinates: [widget.dropoff, ?_driver, ?widget.pickup],
                        padding: _framePadding,
                        minZoom: minZoom,
                        maxZoom: 18,
                      ),
                minZoom: minZoom,
                maxZoom: _maxZoom,
                cameraConstraint: CameraConstraint.contain(bounds: CampusGeofence.cameraBounds),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                ..._hybridTileLayers(),
                // Delivery zone
                PolygonLayer(
                  polygons: [
                    // Soft outer glow
                    Polygon(
                      points: CampusGeofence.boundary,
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderColor: AppTheme.primaryColor.withValues(alpha: 0.30),
                      borderStrokeWidth: 10,
                    ),
                    // Crisp dashed edge
                    Polygon(
                      points: CampusGeofence.boundary,
                      borderColor: AppTheme.primaryColor,
                      borderStrokeWidth: 2.5,
                      pattern: StrokePattern.dashed(segments: const [14, 8]),
                      label: 'Delivery zone',
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    // Straight dotted line: how far the rider still has to go.
                    if (_driver != null)
                      Polyline(
                        points: [_driver!, widget.dropoff],
                        strokeWidth: 3,
                        color: Colors.white.withValues(alpha: 0.85),
                        pattern: const StrokePattern.dotted(),
                      ),
                    // The path the rider has actually taken.
                    if (_trail.length > 1)
                      Polyline(
                        points: _trail,
                        strokeWidth: 5,
                        color: AppTheme.secondaryColor,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white.withValues(alpha: 0.8),
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (widget.pickup != null)
                      Marker(point: widget.pickup!, width: 36, height: 36, child: const _StallPin()),
                    Marker(
                      point: widget.dropoff,
                      width: 90,
                      height: 84,
                      alignment: Alignment.topCenter, // pin tip on the drop-off point
                      child: const _CustomerPin(),
                    ),
                    if (_driver != null)
                      Marker(point: _driver!, width: 140, height: 76, child: _DriverMarker(name: widget.riderName)),
                  ],
                ),
                RichAttributionWidget(
                  attributions: kMapboxAccessToken.isEmpty
                      ? const [
                          TextSourceAttribution('Powered by Esri'),
                          TextSourceAttribution('Esri, Maxar, Earthstar Geographics, and the GIS User Community'),
                        ]
                      : const [TextSourceAttribution('© Mapbox'), TextSourceAttribution('© OpenStreetMap contributors')],
                ),
              ],
            ),
            // Top bar: back on the left, status pill centred, recenter on the
            // right. Both side slots are the same width, so spaceBetween keeps
            // the pill exactly in the middle.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.onBack != null)
                        MapCircleButton(icon: Icons.arrow_back, tooltip: 'Back', onPressed: widget.onBack!)
                      else
                        const SizedBox(width: MapCircleButton.size),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _DistanceChip(meters: _metersToCustomer, viewer: widget.viewer),
                        ),
                      ),
                      MapCircleButton(
                        icon: Icons.center_focus_strong,
                        tooltip: 'Show rider and drop-off',
                        onPressed: _recenter,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Satellite imagery with street and place labels on top.
  List<Widget> _hybridTileLayers() {
    if (kMapboxAccessToken.isNotEmpty) {
      return [
        TileLayer(
          // Mapbox Satellite Streets: imagery and labels in one tile.
          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/512/{z}/{x}/{y}@2x?access_token={accessToken}',
          additionalOptions: const {'accessToken': kMapboxAccessToken},
          tileDimension: 512,
          zoomOffset: -1,
          // @2x tiles up to native zoom 22 keep imagery and labels sharp at 21.
          maxNativeZoom: 22,
          maxZoom: _maxZoom,
          userAgentPackageName: 'com.example.paddlerbites',
        ),
      ];
    }
    const esri = 'https://server.arcgisonline.com/ArcGIS/rest/services';
    return [
      TileLayer(
        urlTemplate: '$esri/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        maxNativeZoom: 19, // imagery tops out around 19 here; 20 scales it up
        maxZoom: _maxZoom,
        userAgentPackageName: 'com.example.paddlerbites',
      ),
      // Transparent overlays: roads, then place names.
      TileLayer(
        urlTemplate: '$esri/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
        maxNativeZoom: 19,
        maxZoom: _maxZoom,
        userAgentPackageName: 'com.example.paddlerbites',
      ),
      TileLayer(
        urlTemplate: '$esri/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
        maxNativeZoom: 19,
        maxZoom: _maxZoom,
        userAgentPackageName: 'com.example.paddlerbites',
      ),
    ];
  }
}

// -----------------------------------------------------------------------------
// Markers and overlays
// -----------------------------------------------------------------------------

class _CustomerPin extends StatelessWidget {
  const _CustomerPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: const Text('Drop-off', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const Icon(Icons.location_on, size: 44, color: AppTheme.secondaryColor, shadows: [Shadow(blurRadius: 6)]),
      ],
    );
  }
}

class _StallPin extends StatelessWidget {
  const _StallPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D3B2E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.storefront, color: AppTheme.primaryColor, size: 18),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  final String name;
  const _DriverMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        const PremiumPaddlingBoatAnimation(size: 44),
      ],
    );
  }
}

/// White round button floating over the map (back, recenter).
class MapCircleButton extends StatelessWidget {
  static const double size = 44;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const MapCircleButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: SizedBox.square(
        dimension: size,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: Colors.black87, size: 22),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  final double? meters;
  final TrackingViewer viewer;
  const _DistanceChip({required this.meters, required this.viewer});

  @override
  Widget build(BuildContext context) {
    final isRider = viewer == TrackingViewer.rider;
    final String text;
    if (meters == null) {
      text = isRider ? 'Finding your location…' : 'Waiting for your rider…';
    } else if (meters! < 10) {
      text = isRider ? 'You\'re at the drop-off' : 'Your rider has arrived';
    } else {
      text = isRider ? '${meters!.round()} m to the drop-off' : 'Rider is ${meters!.round()} m away';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.kayaking, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
