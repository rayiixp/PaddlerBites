import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/theme.dart';
import 'vendor_sales_report_screen.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Matches the theme background color
      appBar: AppBar(
        title: const Text('Stall profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.black)),
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
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B2E),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Center(child: Icon(Icons.storefront_outlined, color: AppTheme.primaryColor, size: 45)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Snackpreneurs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('BSEntrep', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(width: 8),
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Section 1: Main Options Grouped in a Single White Card
            _buildSection([
              _buildMenuItem(
                context: context,
                icon: Icons.bar_chart_outlined,
                title: 'Sales report',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorSalesReportScreen())),
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.edit_note_outlined,
                title: 'Edit stall info',
                onTap: () {},
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.access_time_outlined,
                title: 'Operating hours',
                onTap: () {},
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.payment_outlined,
                title: 'Payout account',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 16),

            // Section 2: Toggles Grouped in a Single White Card
            _buildSection([
              _buildToggleItem(Icons.notifications_active_outlined, 'Order notifications', true),
              _buildToggleItem(Icons.store_mall_directory_outlined, 'Stall open', true),
            ]),
            const SizedBox(height: 16),

            // Section 3: Role Switch & Logout Grouped in a Single White Card
            _buildSection([
              _buildMenuItem(
                context: context,
                icon: Icons.swap_horiz,
                title: 'Switch role',
                onTap: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.logout,
                title: 'Logout',
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

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    Color? textColor,
    VoidCallback? onTap,
  }) {
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

  Widget _buildToggleItem(IconData icon, String title, bool value) {
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