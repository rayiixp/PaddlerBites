import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:paddlerbites/core/campus_geofence.dart';
import 'package:paddlerbites/widgets/delivery_tracking_map.dart';
import 'package:paddlerbites/widgets/premium_paddling_boat.dart';

const _stall = LatLng(9.11520, 125.53430);
const _dropoff = LatLng(9.11760, 125.53500);

/// Metres shown in the distance chip, or null when it shows something else.
int? _chipMeters(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.textContaining('m away')).map((t) => t.data!);
  if (texts.isEmpty) return null;
  return int.parse(RegExp(r'(\d+) m away').firstMatch(texts.first)!.group(1)!);
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

void main() {
  group('camera lock on phones', () {
    const screens = [Size(360, 640), Size(390, 844), Size(412, 915), Size(800, 1280)];
    for (final size in screens) {
      test('map stays movable at its min zoom on ${size.width.toInt()}×${size.height.toInt()}', () {
        final fill = CampusGeofence.zoomToFill(CampusGeofence.cameraBounds, size.width, size.height);
        final minZoom = ((fill * 4).ceil() / 4).clamp(16.5, 20.0);
        final camera = MapCamera(crs: const Epsg3857(), center: CampusGeofence.center, zoom: minZoom, rotation: 0, nonRotatedSize: size);
        // null = flutter_map would reject every pan/zoom (frozen map).
        expect(CameraConstraint.contain(bounds: CampusGeofence.cameraBounds).constrain(camera), isNotNull);
      });
    }

    test('sample points are inside the delivery zone', () {
      expect(CampusGeofence.contains(_stall), isTrue);
      expect(CampusGeofence.contains(_dropoff), isTrue);
    });
  });

  testWidgets('GPS updates move the boat toward the drop-off until it arrives', (tester) async {
    await _phone(tester);
    final gps = StreamController<LatLng>();
    addTearDown(gps.close);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DeliveryTrackingMap(pickup: _stall, dropoff: _dropoff, driverLocations: gps.stream)),
    ));

    // Ten fixes along the straight line from the stall to the drop-off.
    int? previous;
    for (var step = 0; step <= 10; step++) {
      final f = step / 10;
      gps.add(LatLng(_stall.latitude + (_dropoff.latitude - _stall.latitude) * f,
          _stall.longitude + (_dropoff.longitude - _stall.longitude) * f));
      await tester.pump();
      await tester.pump();
      if (step < 10) {
        final now = _chipMeters(tester)!;
        if (previous != null) expect(now, lessThan(previous));
        previous = now;
      }
    }
    expect(find.text('Your rider has arrived'), findsOneWidget);
    // The rider is drawn as the PaddlerBites boat, never a vehicle icon.
    expect(find.byType(PremiumPaddlingBoatAnimation), findsOneWidget);
    expect(find.byIcon(Icons.delivery_dining), findsNothing);
  });

  testWidgets('rider view uses rider wording', (tester) async {
    await _phone(tester);
    final gps = StreamController<LatLng>();
    addTearDown(gps.close);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DeliveryTrackingMap(dropoff: _dropoff, driverLocations: gps.stream, viewer: TrackingViewer.rider)),
    ));
    expect(find.text('Finding your location…'), findsOneWidget);
    gps.add(_stall);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('m to the drop-off'), findsOneWidget);
  });

  testWidgets('real stream: waits for the rider, then shows the distance', (tester) async {
    await _phone(tester);
    final controller = StreamController<LatLng>();
    addTearDown(controller.close);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DeliveryTrackingMap(dropoff: _dropoff, driverLocations: controller.stream))));
    expect(find.text('Waiting for your rider…'), findsOneWidget);

    controller.add(_stall);
    await tester.pump();
    await tester.pump();
    expect(_chipMeters(tester), greaterThan(200));
    expect(find.text('Your rider'), findsOneWidget); // marker tag
  });
}
