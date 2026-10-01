import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paddlerbites/core/app_theme.dart';
import 'package:paddlerbites/screens/customer/my_orders_screen.dart';
import 'package:paddlerbites/widgets/order_card.dart';

Future<void> _pumpPreview(WidgetTester tester, {ThemeData? theme}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: theme ?? AppTheme.lightTheme, home: MyOrdersScreen.preview()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Active tab lists in-progress orders with Track order', (tester) async {
    await _pumpPreview(tester);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets); // tab label
    expect(find.byType(OrderCard), findsNWidgets(3));
    expect(find.text('Track order'), findsNWidgets(3));
    expect(find.text('Reorder'), findsNothing);
    expect(find.text('1x Cheese Burger, 1x Fries'), findsOneWidget);
  });

  testWidgets('Completed tab shows Reorder, Rate and Report issue for delivered orders', (tester) async {
    await _pumpPreview(tester);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderCard), findsNWidgets(2));
    expect(find.text('Reorder'), findsNWidgets(2));
    expect(find.text('Report issue'), findsNWidgets(2));
    expect(find.text('Rate'), findsOneWidget); // the other one is already rated
    expect(find.text('Rated ★★★★★'), findsOneWidget);
    expect(find.text('Track order'), findsNothing);
  });

  testWidgets('Cancelled tab shows the cancelled order without actions', (tester) async {
    await _pumpPreview(tester);
    await tester.tap(find.widgetWithText(Tab, 'Cancelled'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderCard), findsOneWidget);
    expect(find.text('Reorder'), findsNothing);
    expect(find.text('Track order'), findsNothing);
  });

  testWidgets('Rate dialog returns the chosen stars', (tester) async {
    await _pumpPreview(tester);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3)); // 4 stars
    await tester.pump();
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(find.text('Preview: rated 4 stars.'), findsOneWidget);
  });

  testWidgets('renders in dark mode without errors', (tester) async {
    await _pumpPreview(
      tester,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor, brightness: Brightness.dark), useMaterial3: true),
    );
    expect(find.byType(OrderCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
