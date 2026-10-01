import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paddlerbites/core/app_theme.dart';
import 'package:paddlerbites/models/models.dart';
import 'package:paddlerbites/screens/order_chat_screen.dart';
import 'package:paddlerbites/services/chat_service.dart';

OrderModel _order(String status, {String? riderId = 'rider1'}) => OrderModel(
      id: 'abcd1234',
      status: status,
      customerId: 'cust1',
      customerName: 'Rayt',
      stallId: 's1',
      stallName: 'Snackpreneurs',
      items: [OrderItem(itemId: 'b1', name: 'Cheese Burger', price: 30, qty: 1)],
      subtotal: 30,
      deliveryFee: 15,
      totalPrice: 45,
      paymentMethod: 'COD',
      deliveryLocation: 'BSIT Building, Room 204',
      deliveryPoint: const GeoPoint(9.1176, 125.5350),
      deliveryPersonId: riderId,
      deliveryPersonName: riderId == null ? null : 'Juan',
    );

ChatMessage _msg(String id, String from, String text, {bool pending = false}) => ChatMessage(
      id: id,
      senderId: from,
      senderName: from == 'rider1' ? 'Juan' : 'Rayt',
      senderRole: from == 'rider1' ? ChatRole.rider : ChatRole.customer,
      text: text,
      sentAt: DateTime.now(),
      isPending: pending,
    );

class _Harness {
  final orders = StreamController<OrderModel?>.broadcast();
  final messages = StreamController<List<ChatMessage>>.broadcast();
  final sent = <(ChatRole, String)>[];
  Object? failWith;

  Widget build(String uid) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: OrderChatView(
          orderUpdates: orders.stream,
          messages: messages.stream,
          currentUserId: uid,
          onSend: (order, role, text) async {
            if (failWith != null) throw failWith!;
            sent.add((role, text));
          },
        ),
      );

  Future<void> show(WidgetTester tester, OrderModel order, List<ChatMessage> list) async {
    orders.add(order);
    await tester.pump();
    messages.add(list);
    await tester.pump();
  }

  void close() {
    orders.close();
    messages.close();
  }
}

void main() {
  testWidgets('customer: rider in the header, live messages, my bubbles on the right', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await tester.pumpWidget(h.build('cust1'));
    await h.show(tester, _order(OrderStatus.onTheWay), []);

    expect(find.text('Juan'), findsOneWidget);
    expect(find.textContaining('No messages yet'), findsOneWidget);

    // A message from the rider arrives in real time.
    h.messages.add([_msg('1', 'rider1', "I'm at the gate"), _msg('2', 'cust1', 'Coming down!', pending: true)]);
    await tester.pump();
    final width = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getCenter(find.text("I'm at the gate")).dx, lessThan(width / 2));
    expect(tester.getCenter(find.text('Coming down!')).dx, greaterThan(width / 2));
    expect(find.byIcon(Icons.schedule), findsOneWidget, reason: 'my unsent message shows a clock');
  });

  testWidgets('sending clears the field and passes the right role', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await tester.pumpWidget(h.build('rider1'));
    await h.show(tester, _order(OrderStatus.pickedUp), []);
    expect(find.text('Rayt'), findsOneWidget, reason: 'the rider talks to the customer');

    final send = find.byTooltip('Send');
    expect(tester.widget<IconButton>(find.ancestor(of: send, matching: find.byType(IconButton))).onPressed, isNull,
        reason: 'nothing to send yet');

    await tester.enterText(find.byType(TextField), '  On my way with your burger  ');
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    expect(h.sent, [(ChatRole.rider, 'On my way with your burger')]);
    expect(find.text('  On my way with your burger  '), findsNothing);
  });

  testWidgets('a failed send puts the text back and explains', (tester) async {
    final h = _Harness()..failWith = ChatException('You appear to be offline.');
    addTearDown(h.close);
    await tester.pumpWidget(h.build('cust1'));
    await h.show(tester, _order(OrderStatus.onTheWay), []);

    await tester.enterText(find.byType(TextField), 'Room 204 please');
    await tester.pump(); // the send button enables
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // snackbar slides in
    expect(find.text('Room 204 please'), findsOneWidget, reason: 'restored so they can retry');
    expect(h.sent, isEmpty);
    expect(find.textContaining('Message not sent'), findsOneWidget);
  });

  testWidgets('chat closes once delivered, but the history stays', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await tester.pumpWidget(h.build('cust1'));
    await h.show(tester, _order(OrderStatus.delivered), [_msg('1', 'rider1', 'Enjoy!')]);
    expect(find.text('Enjoy!'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('chat is closed'), findsOneWidget);
  });

  testWidgets('no composer before a rider accepts; outsiders are kept out', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await tester.pumpWidget(h.build('cust1'));
    await h.show(tester, _order(OrderStatus.preparing, riderId: null), []);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('once a rider accepts'), findsOneWidget);

    await tester.pumpWidget(h.build('someone-else'));
    await h.show(tester, _order(OrderStatus.onTheWay), []);
    expect(find.textContaining('Only the customer and the rider'), findsOneWidget);
  });

  test('messages are validated before they reach Firestore', () {
    expect(
      () => ChatService.send(orderId: 'o', senderId: 'u', senderName: 'n', senderRole: ChatRole.customer, text: '   '),
      throwsA(isA<ChatException>()),
    );
    expect(
      () => ChatService.send(
          orderId: 'o', senderId: 'u', senderName: 'n', senderRole: ChatRole.customer, text: 'x' * (ChatService.maxLength + 1)),
      throwsA(isA<ChatException>()),
    );
  });
}
