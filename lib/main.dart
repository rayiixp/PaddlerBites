import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
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

Future<void> _seedDatabase() async {
  final db = FirebaseFirestore.instance;
  
  final stall1 = await db.collection('stalls').add({
    'stallName': 'Snackpreneurs',
    'isOpen': true,
    'rating': 4.8,
    'category': 'Snacks',
    'imageUrl': 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?w=500&q=80',
    'totalOrders': 214,
  });

  final stall2 = await db.collection('stalls').add({
    'stallName': 'Taste Venture',
    'isOpen': true,
    'rating': 4.9,
    'category': 'Meals',
    'imageUrl': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&q=80',
    'totalOrders': 180,
  });

  await stall1.collection('menuItems').add({
    'name': 'Cheese Burger',
    'price': 30.00,
    'isAvailable': true,
    'rating': 4.8,
    'stallName': 'Snackpreneurs',
    'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&q=80',
  });

  await db.collection('users').doc('admin_user').set({
    'name': 'IT Admin',
    'email': 'admin@csucc.edu.ph',
    'role': 'admin',
    'status': 'Active'
  });

  await db.collection('users').add({
    'name': 'Juan Cruz',
    'email': 'juan.cruz@csucc.edu.ph',
    'role': 'delivery',
    'status': 'Pending Review'
  });

  await db.collection('orders').add({
    'status': 'Pending',
    'totalPrice': 65.00,
    'items': ['Cheese Burger', 'Fries'],
    'createdAt': FieldValue.serverTimestamp(),
    'deliveryLocation': 'BSIT Building, Room 204'
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
