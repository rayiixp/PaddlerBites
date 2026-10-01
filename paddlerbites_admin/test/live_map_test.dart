import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:paddlerbites_admin/core/campus.dart';
import 'package:paddlerbites_admin/core/premium_paddling_boat.dart';
import 'package:paddlerbites_admin/views/live_map_view.dart';

void main() {
  group('camera lock', () {
    // Admin content areas from laptop to large monitor (sidebar excluded).
    const viewports = [Size(800, 500), Size(1100, 700), Size(1600, 900), Size(2200, 1300)];

    for (final size in viewports) {
      test('contain constraint accepts the min zoom on a ${size.width.toInt()}×${size.height.toInt()} viewport', () {
        final fill = Campus.zoomToFill(Campus.viewBounds, size.width, size.height);
        final minZoom = ((fill * 4).ceil() / 4).clamp(16.5, 20.0);
        final camera = MapCamera(
          crs: const Epsg3857(),
          center: Campus.center,
          zoom: minZoom,
          rotation: 0,
          nonRotatedSize: size,
        );
        // null would mean flutter_map rejects every pan/zoom (a frozen map).
        expect(CameraConstraint.contain(bounds: Campus.viewBounds).constrain(camera), isNotNull);
      });
    }

    test('small viewports keep the requested 16.5 minimum', () {
      expect(Campus.zoomToFill(Campus.viewBounds, 600, 400), lessThan(16.5));
    });

    test('campus outline is inside the allowed view area', () {
      for (final p in Campus.boundary) {
        expect(Campus.viewBounds.contains(p), isTrue);
      }
      expect(Campus.contains(Campus.center), isTrue);
      expect(Campus.contains(const LatLng(9.1250, 125.5400)), isFalse);
    });
  });

  ActiveDelivery delivery(String id, String name, LatLng at, {String status = 'On the way'}) => ActiveDelivery(
        orderId: id,
        riderName: name,
        stallName: 'Snackpreneurs',
        status: status,
        position: at,
        dropoff: const LatLng(9.1176, 125.5350),
      );

  Widget map(List<ActiveDelivery> deliveries) =>
      MaterialApp(home: Scaffold(body: LiveDeliveriesMap(deliveries: deliveries)));

  testWidgets('shows every active rider as a boat and grows trails from live updates', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(map([
      delivery('order1', 'Juan', const LatLng(9.1152, 125.5343)),
      delivery('order2', 'Maria', const LatLng(9.1170, 125.5352), status: 'Picked up'),
    ]));
    expect(find.text('2 active deliveries'), findsOneWidget);
    expect(find.byType(PremiumPaddlingBoatAnimation), findsNWidgets(2));
    expect(find.byIcon(Icons.delivery_dining), findsNothing);

    // Juan moves: his trail gets longer (distance shown in the panel).
    await tester.pumpWidget(map([
      delivery('order1', 'Juan', const LatLng(9.1156, 125.5344)),
      delivery('order2', 'Maria', const LatLng(9.1170, 125.5352), status: 'Picked up'),
    ]));
    expect(find.textContaining(RegExp(r'^[1-9]\d* m$')), findsOneWidget);

    // Maria's order is delivered: she drops off the map and the list.
    await tester.pumpWidget(map([delivery('order1', 'Juan', const LatLng(9.1160, 125.5345))]));
    expect(find.text('1 active delivery'), findsOneWidget);
    expect(find.text('Maria'), findsNothing);
    expect(find.byType(PremiumPaddlingBoatAnimation), findsOneWidget);
  });

  testWidgets('empty state when nobody is delivering', (tester) async {
    await tester.pumpWidget(map(const []));
    expect(find.text('0 active deliveries'), findsOneWidget);
    expect(find.textContaining('No riders are delivering right now'), findsOneWidget);
  });
}
