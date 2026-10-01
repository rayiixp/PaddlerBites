import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'auth_gate.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/customer/main_wrapper.dart';
import 'screens/customer/stall_detail_screen.dart';
import 'screens/customer/food_detail_screen.dart';
import 'screens/customer/checkout_screen.dart';
import 'screens/customer/order_tracking_screen.dart';
import 'screens/vendor/vendor_main_wrapper.dart';
import 'screens/delivery/delivery_main_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const PaddlerBitesApp(),
    ),
  );
}

/// Dev helper: seeds one approved, open stall with a menu item.
/// Stall ids are the owning vendor's uid; menu items live in `menuItems`.
// ignore: unused_element
Future<void> _seedDatabase() async {
  final db = FirebaseFirestore.instance;

  final stall = db.collection('stalls').doc('demo_vendor_uid');
  await stall.set({
    'ownerId': 'demo_vendor_uid',
    'stallName': 'Snackpreneurs',
    'program': 'BSEntrep',
    'category': 'Snacks',
    'operatingHours': '7:00 AM - 5:00 PM',
    'status': 'Active',
    'isOpen': true,
    'rating': 4.8,
    'totalOrders': 0,
    'imageUrl': '',
    'pickupPoint': const GeoPoint(9.1163954, 125.5346985),
  });

  await db.collection('menuItems').add({
    'stallId': stall.id,
    'stallName': 'Snackpreneurs',
    'name': 'Cheese Burger',
    'description': 'Beef patty, melted cheese, lettuce and tomato on a toasted bun.',
    'price': 30.00,
    'category': 'Snacks',
    'isAvailable': true,
    'rating': 4.8,
    'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&q=80',
  });
}

class PaddlerBitesApp extends StatelessWidget {
  const PaddlerBitesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaddlerBites',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/customer-main': (context) => const MainWrapper(),
        '/stall-detail': (context) => const StallDetailScreen(),
        '/food-detail': (context) => const FoodDetailScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/order-tracking': (context) => const OrderTrackingScreen(),
        '/vendor-home': (context) => const VendorMainWrapper(),
        '/delivery-main': (context) => const DeliveryMainWrapper(),
      },
    );
  }
}
