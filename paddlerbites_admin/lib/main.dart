import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

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
      home: const AdminLoginScreen(),
      routes: {
        '/login': (context) => const AdminLoginScreen(),
        '/dashboard': (context) => const AdminMainShell(initialTab: 'Overview'),
        '/users': (context) => const AdminMainShell(initialTab: 'Users'),
        '/stalls': (context) => const AdminMainShell(initialTab: 'Stalls'),
        '/orders': (context) => const AdminMainShell(initialTab: 'Orders'),
        '/settings': (context) => const AdminMainShell(initialTab: 'Settings'),
      },
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN NAVIGATION SHELL (Persistent Sidebar)
// -----------------------------------------------------------------------------
class AdminMainShell extends StatefulWidget {
  final String initialTab;
  const AdminMainShell({super.key, required this.initialTab});

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  late String _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 'Overview':
        return const DashboardOverviewView();
      case 'Users':
        return const UserManagementView();
      case 'Stalls':
        return const StallOversightView();
      case 'Orders':
        return const Center(child: Text('Orders Module View', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
      case 'Settings':
        return const SystemSettingsView();
      default:
        return const DashboardOverviewView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
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
                    Text(
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
                _buildSidebarItem('Users', Icons.people_outline, Icons.people),
                _buildSidebarItem('Stalls', Icons.storefront_outlined, Icons.storefront),
                _buildSidebarItem('Orders', Icons.receipt_long_outlined, Icons.receipt_long),
                _buildSidebarItem('Settings', Icons.wb_sunny_outlined, Icons.wb_sunny),
                
                const Spacer(),
                
                // Profile footer
                const Divider(height: 32, color: Color(0xFFEEEEEE)),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.green.shade700,
                      child: const Text('IT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IT Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Super Administrator', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                      onPressed: () async {
                        await GoogleSignIn().signOut();
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
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

  Widget _buildSidebarItem(String title, IconData iconOutlined, IconData iconFilled) {
    bool isActive = _currentTab == title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentTab = title;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFD54F) : Colors.transparent,
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
class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Text(
                'PaddlerBites Admin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                'Campus operations console',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              
              // Google OAuth Login Action Trigger
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
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

// -----------------------------------------------------------------------------
// 2. DASHBOARD OVERVIEW VIEW
// -----------------------------------------------------------------------------
class DashboardOverviewView extends StatelessWidget {
  const DashboardOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Bar Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Monday, September 7', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search orders, users, stalls...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 32),
        
        // Metrics Summary Row grid layout with live Firestore StreamBuilders
        Row(
          children: [
            Expanded(
              child: StreamBuilder<num>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots().map((snap) => snap.docs.length),
                builder: (context, snap) => _buildMetricCard('Orders today', '${snap.data ?? 0}', null),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: StreamBuilder<double>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots().map((snap) {
                  double total = 0.0;
                  for (var doc in snap.docs) {
                    total += (doc.data()['totalPrice'] ?? 0.0).toDouble();
                  }
                  return total;
                }),
                builder: (context, snap) => _buildMetricCard('Revenue today', '₱${(snap.data ?? 0.0).toStringAsFixed(2)}', null),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: StreamBuilder<num>(
                stream: FirebaseFirestore.instance.collection('stalls').where('isOpen', isEqualTo: true).snapshots().map((snap) => snap.docs.length),
                builder: (context, snap) => _buildMetricCard('Active stalls', '${snap.data ?? 0}', null),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: StreamBuilder<num>(
                stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'delivery').where('status', isEqualTo: 'Active').snapshots().map((snap) => snap.docs.length),
                builder: (context, snap) => _buildMetricCard('Active riders', '${snap.data ?? 0}', null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Pending Delivery Notifications Banner alert box linked to live pending stream
        StreamBuilder<num>(
          stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'delivery').where('status', isEqualTo: 'Pending Review').snapshots().map((snap) => snap.docs.length),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            if (count == 0) return const SizedBox.shrink();
            
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFF59D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 22),
                  const SizedBox(width: 16),
                  Text(
                    '$count delivery applications pending review',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate directly to the Users Tab overview layout stream
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                    ),
                    child: const Text('Review now', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        
        // Recent Activities Log card list section
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _buildActivityItem('New stall registered — Taste Venture', '10 min ago'),
                      _buildActivityItem('Order #1042 flagged — delayed pickup', '25 min ago'),
                      _buildActivityItem('Delivery personnel approved — J. Cruz', '1 hr ago'),
                    ],
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String? sub) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String text, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: TextStyle(fontSize: 14, color: Colors.black87)),
          Text(time, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3 & 4. USER MANAGEMENT & APPROVAL FLOW VIEW
// -----------------------------------------------------------------------------
class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  String selectedRoleSegment = 'Customers';
  bool viewingApplicationDetail = false;

  @override
  Widget build(BuildContext context) {
    if (viewingApplicationDetail) {
      return _buildApplicationDetailScreen();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title bar with Search Box filter input
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Users', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('1,204 registered accounts', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),
        
        // Horizontal Segmented Radio controls
        Row(
          children: ['Customers', 'Vendors', 'Delivery'].map((role) {
            bool isSelected = selectedRoleSegment == role;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
                label: Text(role),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    selectedRoleSegment = role;
                  });
                },
                selectedColor: Colors.black,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        
        // Data Sheet Table display list with live Firestore Query Streams
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: selectedRoleSegment.toLowerCase().replaceAll('customers', 'customer'))
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No matching user records found in this category.'),
                  ));
                }

                return SingleChildScrollView(
                  child: DataTable(
                    horizontalMargin: 24,
                    columns: const [
                      DataColumn(label: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('EMAIL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('JOINED', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed User';
                      final email = data['email'] ?? 'No Email';
                      final status = data['status'] ?? 'Active';
                      final isActionable = status == 'Pending Review';
                      
                      return _buildUserTableRow(name, email, 'Recent', status, isActionable);
                    }).toList(),
                  ),
                );
              }
            ),
          ),
        )
      ],
    );
  }

  DataRow _buildUserTableRow(String name, String email, String date, String status, bool isActionable) {
    Color statusBg = Colors.green.shade50;
    Color statusText = Colors.green.shade700;
    if (status == 'Suspended') {
      statusBg = Colors.red.shade50;
      statusText = Colors.red.shade700;
    } else if (status == 'Pending Review') {
      statusBg = Colors.amber.shade50;
      statusText = Colors.amber.shade700;
    }
    
    return DataRow(
      cells: [
        DataCell(Row(
          children: [
            CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.person, size: 16, color: Colors.grey)),
            const SizedBox(width: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        )),
        DataCell(Text(email)),
        DataCell(Text(date)),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
          child: Text(status, style: TextStyle(color: statusText, fontWeight: FontWeight.bold, fontSize: 12)),
        )),
        DataCell(isActionable 
          ? IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  viewingApplicationDetail = true;
                });
              },
            )
          : const Icon(Icons.more_vert, color: Colors.grey, size: 18)
        ),
      ],
    );
  }

  // View Application detail matching layout design block #4
  Widget _buildApplicationDetailScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Navigation anchor
        TextButton.icon(
          onPressed: () {
            setState(() {
              viewingApplicationDetail = false;
            });
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          label: const Text('Back to users list', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        Text('Delivery application', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Profile metrics card metadata section
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 30, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.person, size: 36, color: Colors.grey)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Juan Cruz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('juan.cruz@csucc.edu.ph', style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildMetaFieldRow('Student ID number', '2023-00456'),
                    const Divider(height: 24),
                    _buildMetaFieldRow('Contact number', '0917-123-4567'),
                    const Divider(height: 24),
                    _buildMetaFieldRow('Submitted', 'Sep 6, 2026'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Right Document Image Upload verification file section
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uploaded student ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 16),
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(color: const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Icon(Icons.badge, size: 48, color: Colors.grey)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              // Perform live Firestore reject update state
                              await FirebaseFirestore.instance.collection('users').doc('delivery_person_uid_placeholder').update({
                                'status': 'Suspended'
                              });
                              setState(() { viewingApplicationDetail = false; });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Perform live Firestore approval update state
                              await FirebaseFirestore.instance.collection('users').doc('delivery_person_uid_placeholder').update({
                                'status': 'Active'
                              });
                              setState(() { viewingApplicationDetail = false; });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD54F),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildMetaFieldRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 5. STALL OVERSIGHT VIEW
// -----------------------------------------------------------------------------
class StallOversightView extends StatelessWidget {
  const StallOversightView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stalls', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('5 registered stalls', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search stalls',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 32),
        
        // Data Sheet Table display list connected to live stalls collection stream
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('stalls').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No registered campus food stalls found yet.'),
                  ));
                }

                return SingleChildScrollView(
                  child: DataTable(
                    horizontalMargin: 24,
                    columns: const [
                      DataColumn(label: Text('STALL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('RATING', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('ORDERS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['stallName'] ?? 'Unnamed Stall';
                      final category = data['category'] ?? 'BSBA';
                      final rating = data['rating'] != null ? '⭐ ${data['rating']}' : '—';
                      final ordersCount = '${data['totalOrders'] ?? 0}';
                      final isOpen = data['isOpen'] ?? false;
                      final status = isOpen ? 'Active' : 'Closed';
                      
                      return _buildStallRow(name, category, rating, ordersCount, status, const Color(0xFF0D47A1));
                    }).toList(),
                  ),
                );
              }
            ),
          ),
        )
      ],
    );
  }

  DataRow _buildStallRow(String name, String category, String rating, String orders, String status, Color badgeColor) {
    Color statusBg = Colors.green.shade50;
    Color statusText = Colors.green.shade700;
    if (status == 'Suspended') {
      statusBg = Colors.red.shade50;
      statusText = Colors.red.shade700;
    } else if (status == 'New') {
      statusBg = Colors.amber.shade50;
      statusText = Colors.amber.shade700;
    }

    return DataRow(cells: [
      DataCell(Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
            child: const Center(child: Icon(Icons.storefront, size: 16, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      )),
      DataCell(Text(category)),
      DataCell(Text(rating, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(orders)),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
        child: Text(status, style: TextStyle(color: statusText, fontWeight: FontWeight.bold, fontSize: 12)),
      )),
    ]);
  }
}

// -----------------------------------------------------------------------------
// 6. SYSTEM SETTINGS VIEW
// -----------------------------------------------------------------------------
class SystemSettingsView extends StatefulWidget {
  const SystemSettingsView({super.key});

  @override
  State<SystemSettingsView> createState() => _SystemSettingsViewState();
}

class _SystemSettingsViewState extends State<SystemSettingsView> {
  bool gcashEnabled = true;
  bool codEnabled = true;
  bool voiceOrderingEnabled = true;
  bool autoApprovalEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left grid layout panel: Geofence card bounds
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Campus geofence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.teal.shade50, Colors.blue.shade50]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200, style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Text(
                          '[ Geofence Boundary Map Area Grid ]',
                          style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Geofence radius', style: TextStyle(color: Colors.grey)),
                        Text('450 m', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Right grid layout panel: Payments channels switch options
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('GCash via PayMongo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      value: gcashEnabled,
                      activeColor: Colors.amber,
                      onChanged: (val) { setState(() { gcashEnabled = val; }); },
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Cash on delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      value: codEnabled,
                      activeColor: Colors.amber,
                      onChanged: (val) { setState(() { codEnabled = val; }); },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),
        
        // Bottom full-width card parameters view list
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Voice ordering', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                value: voiceOrderingEnabled,
                activeColor: Colors.amber,
                onChanged: (val) { setState(() { voiceOrderingEnabled = val; }); },
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('New vendor auto-approval', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                value: autoApprovalEnabled,
                activeColor: Colors.amber,
                onChanged: (val) { setState(() { autoApprovalEnabled = val; }); },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        )
      ],
    );
  }
}
