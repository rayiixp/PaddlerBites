import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/admin_ui.dart';
import 'core/user_roles.dart';
import 'views/live_map_view.dart';
import 'views/orders_view.dart';
import 'views/overview_view.dart';
import 'views/settings_view.dart';
import 'views/stalls_view.dart';
import 'views/users_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase not initialized yet: $e");
  }
  runApp(const PaddlerBitesAdminApp());
}

class PaddlerBitesAdminApp extends StatelessWidget {
  const PaddlerBitesAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaddlerBites Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFBC02D),
          primary: const Color(0xFFFBC02D),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        useMaterial3: true,
      ),
      home: const AdminAuthGate(),
    );
  }
}

// -----------------------------------------------------------------------------
// AUTH GATE — only @csucc.edu.ph accounts that an admin has granted access
// -----------------------------------------------------------------------------
class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnapshot.data;
        if (user == null) return const AdminLoginScreen();

        final email = (user.email ?? '').toLowerCase();
        if (!email.endsWith('@csucc.edu.ph')) {
          FirebaseAuth.instance.signOut();
          return const AdminLoginScreen(deniedEmail: 'Please use an official @csucc.edu.ph account');
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final doc = userSnapshot.data!;
            final data = doc.data();

            if (data?['adminSuspended'] == true) {
              return AdminLoginScreen(deniedEmail: user.email ?? 'This account');
            }

            // Admin access is granted by another admin (Users → a user →
            // Admin access); the Firestore rules don't let anyone grant it
            // to themselves.
            if (!doc.exists || data?['isAdmin'] != true) {
              return AdminLoginScreen(deniedEmail: user.email ?? 'This account');
            }

            return AdminMainShell(
              initialTab: 'Overview',
              adminName: data?['name'] ?? user.displayName ?? 'Admin',
              adminEmail: user.email ?? '',
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN NAVIGATION SHELL (Persistent Sidebar)
// -----------------------------------------------------------------------------
class AdminMainShell extends StatefulWidget {
  final String initialTab;
  final String adminName;
  final String adminEmail;
  const AdminMainShell({super.key, required this.initialTab, this.adminName = 'Admin', this.adminEmail = ''});

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  late String _currentTab;
  // Where the Users tab opens; bumping the key resets it to these filters.
  String _usersRole = 'Customers';
  String _usersStatus = 'All';
  int _usersKey = 0;

  final _pendingApplications = FirebaseFirestore.instance.collection('users').snapshots().map((snap) => snap.docs
      .where((d) =>
          UserRoles.isPendingApplication(d.data(), UserRoles.delivery) ||
          UserRoles.isPendingApplication(d.data(), UserRoles.vendor))
      .length);

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  void _openUsers(String role, String status) {
    setState(() {
      _currentTab = 'Users';
      _usersRole = role;
      _usersStatus = status;
      _usersKey++;
    });
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 'Overview':
        return DashboardOverviewView(
          onReviewApplications: (role) => _openUsers(role, RoleStatus.pending),
          onOpenOrders: () => setState(() => _currentTab = 'Orders'),
        );
      case 'Users':
        return UserManagementView(key: ValueKey(_usersKey), initialRole: _usersRole, initialStatus: _usersStatus);
      case 'Stalls':
        return const StallOversightView();
      case 'Orders':
        return const OrdersView();
      case 'Live map':
        return const LiveMapView();
      case 'Settings':
        return const SystemSettingsView();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.adminName.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(
        children: [
          // Persitent Sidebar
          Container(
            width: 260,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header logo
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/paddlerbites_icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'PaddlerBites',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 0, height: 40),

                // Navigation items
                _buildSidebarItem('Overview', Icons.space_dashboard_outlined, Icons.space_dashboard),
                StreamBuilder<int>(
                  stream: _pendingApplications,
                  builder: (context, snap) =>
                      _buildSidebarItem('Users', Icons.people_outline, Icons.people, badge: snap.data ?? 0),
                ),
                _buildSidebarItem('Stalls', Icons.storefront_outlined, Icons.storefront),
                _buildSidebarItem('Orders', Icons.receipt_long_outlined, Icons.receipt_long),
                _buildSidebarItem('Live map', Icons.map_outlined, Icons.map),
                _buildSidebarItem('Settings', Icons.wb_sunny_outlined, Icons.wb_sunny),

                const Spacer(),

                // Profile footer
                const Divider(height: 32, color: Color(0xFFEEEEEE)),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.green.shade700,
                      child: Text(initials.isEmpty ? 'A' : initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.adminName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                          Text(widget.adminEmail,
                              style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                      // AdminAuthGate returns to the login screen.
                      onPressed: () => FirebaseAuth.instance.signOut(),
                    ),
                  ],
                )
              ],
            ),
          ),

          // Main content view layer
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: _buildTabContent(),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, IconData iconOutlined, IconData iconFilled, {int badge = 0}) {
    bool isActive = _currentTab == title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _currentTab = title),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AdminColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(isActive ? iconFilled : iconOutlined, color: Colors.black87, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. ADMIN LOGIN SCREEN
// -----------------------------------------------------------------------------
class AdminLoginScreen extends StatefulWidget {
  /// Set when a signed-in account is not an admin.
  final String? deniedEmail;
  const AdminLoginScreen({super.key, this.deniedEmail});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // A denied account is still signed in; switch accounts cleanly.
      if (widget.deniedEmail != null) await FirebaseAuth.instance.signOut();
      final provider = GoogleAuthProvider()..setCustomParameters({'hd': 'csucc.edu.ph', 'prompt': 'select_account'});
      // Web-only console: Google sign-in opens in a popup window.
      final credential = await FirebaseAuth.instance.signInWithPopup(provider);
      final email = (credential.user?.email ?? '').toLowerCase();
      if (!email.endsWith('@csucc.edu.ph')) {
        await FirebaseAuth.instance.signOut();
        if (mounted) setState(() => _error = 'Please use your official @csucc.edu.ph account.');
      }
      // Otherwise AdminAuthGate checks the admin role and opens the console.
    } on FirebaseAuthException catch (e) {
      if (mounted && e.code != 'popup-closed-by-user' && e.code != 'cancelled-popup-request') {
        setState(() => _error = e.message ?? 'Sign-in failed (${e.code}).');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _error ??
        (widget.deniedEmail == null
            ? null
            : '${widget.deniedEmail} is not an administrator. Ask an existing admin to grant access, or sign in with another account.');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Dark Green Logo badge
              ClipOval(
                child: Image.asset(
                  'assets/images/paddlerbites_icon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'PaddlerBites Admin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                'Campus operations console',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              if (message != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(message, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 24),
              ],

              // Google OAuth Login Action Trigger
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                          const SizedBox(width: 10),
                          Text(
                            widget.deniedEmail == null ? 'Continue with Google' : 'Use another Google account',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
              if (widget.deniedEmail != null)
                TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
              const SizedBox(height: 24),
              Text(
                'Only pre-approved @csucc.edu.ph admin accounts can access this console',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
