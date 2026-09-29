import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/customer/main_wrapper.dart';
import 'screens/vendor/vendor_main_wrapper.dart';
import 'screens/role_selection_screen.dart';
import 'screens/delivery/delivery_main_wrapper.dart';
import 'screens/welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 1. If not logged in, show Role Selection Screen first
        if (!snapshot.hasData) {
          return const RoleSelectionScreen();
        }

        // 2. If logged in, fetch role from Firestore in real-time
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User is logged into Auth but no document in Firestore yet
              // This can happen during the split second of registration
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            
            // Store user data in Provider for global access
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<UserProvider>(context, listen: false).setUser(data);
            });

            // 3. Automated Routing based on Role
            String role = data['role'] ?? 'customer';

            if (role == 'vendor') {
              return const VendorMainWrapper();
            } else if (role == 'delivery') {
              return const DeliveryMainWrapper();
            } else {
              return const MainWrapper(); // Customer Dashboard
            }
          },
        );
      },
    );
  }
}
