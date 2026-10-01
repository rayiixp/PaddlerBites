import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'models/app_user.dart';
import 'providers/user_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/customer/main_wrapper.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/vendor/vendor_main_wrapper.dart';
import 'screens/vendor/vendor_setup_screen.dart';
import 'screens/delivery/delivery_main_wrapper.dart';
import 'screens/welcome_screen.dart';

/// Root router.
///
/// 1. Signed out → [WelcomeScreen] (login).
/// 2. Non-institutional or unverified accounts are stopped here.
/// 3. The user document is streamed, so admin approvals, rejections and
///    suspensions re-route the app in real time:
///    - one approved role → straight into that module;
///    - several approved roles → [RoleSelectionScreen] until one is picked;
///    - the picked role lost its approval → [PendingApprovalScreen].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static const _loading = Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  Widget build(BuildContext context) {
    // userChanges (not authStateChanges) also fires after reload(), which is
    // how a completed email verification is detected.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loading;

        final user = snapshot.data;
        if (user == null) {
          // Drop the previous account's cached profile
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(context, listen: false).clearUser();
          });
          return const WelcomeScreen();
        }

        // Defense in depth: never let a non-institutional session through.
        if (!AuthService.isInstitutional(user.email)) {
          WidgetsBinding.instance.addPostFrameCallback((_) => AuthService.signOut());
          return _loading;
        }
        if (AuthService.needsEmailVerification(user)) return const VerifyEmailScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return _loading;

            final data = userSnapshot.data!.data();
            if (data == null) {
              // Signed in but no profile yet (e.g. mid sign-up): create it.
              WidgetsBinding.instance.addPostFrameCallback((_) => AuthService.ensureProfile(user));
              return _loading;
            }

            // Store user data in Provider for global access
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<UserProvider>(context, listen: false).setUser(user.uid, data);
            });

            final profile = AppUser.fromMap(user.uid, data);
            final module = profile.resolvedModule;

            if (module == null) {
              // A chosen role that is no longer approved (e.g. suspended while in use).
              if (profile.activeRole != null) return PendingApprovalScreen(role: profile.activeRole!);
              return const RoleSelectionScreen();
            }

            switch (module) {
              case UserRole.customer:
                return const MainWrapper();
              case UserRole.vendor:
                // An approved vendor always has a stall; guard against manual edits.
                return profile.stallId == null ? const VendorSetupScreen() : const VendorMainWrapper();
              case UserRole.delivery:
                return const DeliveryMainWrapper();
            }
          },
        );
      },
    );
  }
}
