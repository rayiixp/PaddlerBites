import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:paddlerbites/core/app_theme.dart';
import 'package:paddlerbites/models/models.dart';
import 'package:paddlerbites/screens/customer/order_tracking_screen.dart';
import 'package:paddlerbites/widgets/order_status_timeline.dart';
import 'package:paddlerbites/widgets/premium_paddling_boat.dart';

OrderModel _order(String status) => OrderModel(
      id: 'abcd1234',
      status: status,
      customerId: 'c1',
      customerName: 'Rayt',
      stallId: 's1',
      stallName: 'Snackpreneurs',
      items: [OrderItem(itemId: 'b1', name: 'Cheese Burger', price: 30, qty: 2)],
      subtotal: 60,
      deliveryFee: 15,
      totalPrice: 75,
      paymentMethod: 'COD',
      deliveryLocation: 'BSIT Building, Room 204',
      deliveryPoint: const GeoPoint(9.1176, 125.5350),
      pickupPoint: const GeoPoint(9.1152, 125.5343),
      deliveryPersonName: status == OrderStatus.pending ? null : 'Juan',
      deliveryPersonId: status == OrderStatus.pending ? null : 'rider1',
    );

Widget _timeline(String status, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion, size: const Size(360, 640)),
        child: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: OrderStatusTimeline(status: status))),
      ),
    );

double _boatPhase(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(PremiumPaddlingBoatAnimation), matching: find.byType(CustomPaint)));
  return (paint.painter as dynamic).t as double;
}

void main() {
  group('status timeline', () {
    const expected = {
      OrderStatus.pending: 0,
      OrderStatus.preparing: 1,
      OrderStatus.ready: 1,
      OrderStatus.pickedUp: 2,
      OrderStatus.onTheWay: 3,
      OrderStatus.delivered: 4,
    };
    for (final entry in expected.entries) {
      testWidgets('${entry.key}: boat on step ${entry.value}, earlier steps checked', (tester) async {
        await tester.pumpWidget(_timeline(entry.key));
        expect(find.byType(PremiumPaddlingBoatAnimation), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNWidgets(entry.value));
        // The boat sits in the column of the current step's label.
        final boatX = tester.getCenter(find.byType(PremiumPaddlingBoatAnimation)).dx;
        final labelX = tester.getCenter(find.text(OrderStatusTimeline.steps[entry.value])).dx;
        expect((boatX - labelX).abs(), lessThan(1));
      });
    }

    testWidgets('upcoming steps show their grey icon; reached steps are checked', (tester) async {
      await tester.pumpWidget(_timeline(OrderStatus.preparing));
      // Placed is checked, Preparing has the boat, the rest show their icon.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
      expect(find.byIcon(Icons.soup_kitchen_outlined), findsNothing);
      for (final icon in [Icons.shopping_bag_outlined, Icons.directions_run_outlined, Icons.home_outlined]) {
        expect(tester.widget<Icon>(find.byIcon(icon)).color, Colors.grey.shade400);
      }
    });

    testWidgets('the boat glides to the new step instead of jumping', (tester) async {
      await tester.pumpWidget(_timeline(OrderStatus.pending));
      double boatX() => tester.getCenter(find.byType(PremiumPaddlingBoatAnimation)).dx;
      final placedX = tester.getCenter(find.text('Placed')).dx;
      final preparingX = tester.getCenter(find.text('Preparing')).dx;
      expect((boatX() - placedX).abs(), lessThan(1));

      await tester.pumpWidget(_timeline(OrderStatus.preparing));
      await tester.pump(OrderStatusTimeline.glideDuration ~/ 2);
      expect(boatX(), inExclusiveRange(placedX + 5, preparingX - 5), reason: 'halfway along the connector');

      await tester.pump(OrderStatusTimeline.glideDuration ~/ 2);
      expect((boatX() - preparingX).abs(), lessThan(1));
    });

    testWidgets('cancelled orders have no active step', (tester) async {
      await tester.pumpWidget(_timeline(OrderStatus.cancelled));
      expect(find.byType(PremiumPaddlingBoatAnimation), findsNothing);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget); // all steps grey
    });

    testWidgets('the boat paddles while the order is in progress', (tester) async {
      await tester.pumpWidget(_timeline(OrderStatus.onTheWay));
      final before = _boatPhase(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_boatPhase(tester), isNot(before));
    });

    testWidgets('the boat rests once delivered and under reduce-motion', (tester) async {
      await tester.pumpWidget(_timeline(OrderStatus.delivered));
      final delivered = _boatPhase(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_boatPhase(tester), delivered);

      await tester.pumpWidget(_timeline(OrderStatus.preparing, reduceMotion: true));
      final still = _boatPhase(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_boatPhase(tester), still);
    });
  });

  testWidgets('tracking view runs purely on streams: status updates move the boat, GPS moves the rider', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340); // 360 × 780 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final orders = StreamController<OrderModel?>.broadcast();
    final gps = StreamController<LatLng>.broadcast();
    addTearDown(orders.close);
    addTearDown(gps.close);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DeliveryTrackingView(orderUpdates: orders.stream, riderLocations: gps.stream, onBack: () {}),
    ));
    expect(find.text('Finding your active order…'), findsOneWidget);

    orders.add(_order(OrderStatus.preparing));
    await tester.pump();
    await tester.pump();
    expect(find.text('The stall is cooking your order'), findsOneWidget);
    // Collapsed card: the timeline is fully on screen above the bottom edge.
    final deliveredStep = find.descendant(of: find.byType(OrderStatusTimeline), matching: find.text('Delivered'));
    expect(tester.getBottomLeft(deliveredStep).dy, lessThan(780));

    orders.add(_order(OrderStatus.onTheWay));
    await tester.pump();
    await tester.pump();
    await tester.pump(OrderStatusTimeline.glideDuration); // let the boat paddle over
    expect(find.text('Arriving in 5–10 min'), findsOneWidget);
    final timelineBoat = find.descendant(of: find.byType(OrderStatusTimeline), matching: find.byType(PremiumPaddlingBoatAnimation));
    final boatX = tester.getCenter(timelineBoat).dx;
    final timelineLabel = find.descendant(of: find.byType(OrderStatusTimeline), matching: find.text('On the way'));
    expect((boatX - tester.getCenter(timelineLabel).dx).abs(), lessThan(1));

    gps.add(const LatLng(9.1160, 125.5345));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('m away'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('tracking screen controls', () {
    Future<StreamController<OrderModel?>> pumpView(
      WidgetTester tester, {
      List<OrderModel>? cancelled,
      List<OrderModel>? chats,
      VoidCallback? onBack,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340); // 360 × 780 dp
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final orders = StreamController<OrderModel?>.broadcast();
      addTearDown(orders.close);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: DeliveryTrackingView(
          orderUpdates: orders.stream,
          riderLocations: const Stream.empty(),
          onBack: onBack ?? () {},
          onCancelOrder: (o) async => cancelled?.add(o),
          onChatWithRider: (o) => chats?.add(o),
        ),
      ));
      return orders;
    }

    Future<void> show(WidgetTester tester, StreamController<OrderModel?> orders, String status) async {
      orders.add(_order(status));
      await tester.pump();
      await tester.pump();
      await tester.pump(OrderStatusTimeline.glideDuration);
    }

    testWidgets('top bar: back left, status pill centred, recenter right, on one line', (tester) async {
      var backTaps = 0;
      final orders = await pumpView(tester, onBack: () => backTaps++);
      await show(tester, orders, OrderStatus.preparing);

      final back = find.byTooltip('Back');
      final recenter = find.byTooltip('Show rider and drop-off');
      final pill = find.text('Waiting for your rider…');
      expect(back, findsOneWidget, reason: 'only the map top bar draws a back button');
      expect(tester.getCenter(back).dx, lessThan(40));
      expect(tester.getCenter(recenter).dx, greaterThan(320));
      final chip = find.ancestor(of: pill, matching: find.byType(Container)).first;
      expect(tester.getCenter(chip).dx, closeTo(180, 1), reason: 'pill exactly centred');
      expect(tester.getCenter(back).dy, closeTo(tester.getCenter(chip).dy, 1));
      expect(tester.getCenter(recenter).dy, closeTo(tester.getCenter(chip).dy, 1));

      await tester.tap(back);
      expect(backTaps, 1);
    });

    testWidgets('chat button appears once a rider is assigned', (tester) async {
      final chats = <OrderModel>[];
      final orders = await pumpView(tester, chats: chats);
      await show(tester, orders, OrderStatus.pending);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing, reason: 'no rider yet');

      await show(tester, orders, OrderStatus.onTheWay);
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      expect(chats.single.status, OrderStatus.onTheWay);
    });

    testWidgets('cancel: enabled while pending, disabled once accepted, hidden when delivered', (tester) async {
      final cancelled = <OrderModel>[];
      final orders = await pumpView(tester, cancelled: cancelled);
      OutlinedButton cancelButton() =>
          tester.widget<OutlinedButton>(find.ancestor(of: find.text('Cancel order'), matching: find.byType(OutlinedButton)));

      await show(tester, orders, OrderStatus.pending);
      // Drag the order card all the way up to reach the button.
      await tester.drag(find.text('Waiting for the stall to accept'), const Offset(0, -600));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(cancelButton().onPressed, isNotNull);

      for (final status in [OrderStatus.preparing, OrderStatus.pickedUp, OrderStatus.onTheWay]) {
        await show(tester, orders, status);
        expect(cancelButton().onPressed, isNull, reason: '$status can no longer be cancelled');
        expect(find.textContaining("can't be cancelled"), findsOneWidget);
      }

      await show(tester, orders, OrderStatus.delivered);
      expect(find.text('Cancel order'), findsNothing);
      expect(cancelled, isEmpty);
    });
  });
}
