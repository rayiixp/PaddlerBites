import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/theme.dart';

class DeliveryProfileScreen extends StatelessWidget {
  const DeliveryProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Matches the theme background color
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.black)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            // Header Profile Avatar and Details
            const CircleAvatar(radius: 45, backgroundColor: Colors.grey),
            const SizedBox(height: 12),
            const Text('Juan Cruz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 2),
            const Text('juan.cruz@csucc.edu.ph', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Text('Verified', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 28),

            // Section 1: Main Options Grouped in a Single White Card
            _buildSection([
              _buildProfileOption(context, Icons.history, 'Delivery history'),
              _buildProfileOption(context, Icons.directions_walk, 'Mode: On foot'),
              _buildProfileOption(context, Icons.payment, 'Payout method (GCash)'),
            ]),
            const SizedBox(height: 16),

            // Section 2: Toggle Option Grouped in a Single White Card
            _buildSection([
              _buildToggleOption(context, Icons.notifications_active_outlined, 'New delivery alerts', true),
            ]),
            const SizedBox(height: 16),

            // Section 3: Support Option Grouped in a Single White Card
            _buildSection([
              _buildProfileOption(context, Icons.help_outline, 'Help & support'),
            ]),
            const SizedBox(height: 16),

            // Section 4: Switch Role & Logout Grouped in a Single White Card
            _buildSection([
              _buildProfileOption(
                context,
                Icons.swap_horiz,
                'Switch role',
                onTap: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
                },
              ),
              _buildProfileOption(
                context,
                Icons.logout,
                'Logout',
                textColor: Colors.redAccent,
                onTap: () async {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
                  }
                },
              ),
            ]),
            const SizedBox(height: 120), // Bottom padding to clear the floating nav bar
          ],
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> items) {
    List<Widget> separatedItems = [];
    for (int i = 0; i < items.length; i++) {
      separatedItems.add(items[i]);
      if (i < items.length - 1) {
        separatedItems.add(Divider(height: 1, thickness: 1, color: Colors.grey.shade200));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: separatedItems,
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context, IconData icon, String title, {Color? textColor, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: textColor ?? Colors.black87, size: 24),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor ?? Colors.black87),
      ),
      trailing: textColor == Colors.redAccent
          ? null
          : Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildToggleOption(BuildContext context, IconData icon, String title, bool value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: Colors.black87, size: 24),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
      ),
      trailing: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: value,
          onChanged: (v) {},
          activeColor: Colors.white,
          activeTrackColor: Colors.black,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}