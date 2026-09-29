import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.black)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent, // Prevents Material 3 from tinting the app bar on scroll
        elevation: 0,
        scrolledUnderElevation: 0, // Keeps the app bar flat and clean when scrolling underneath
        automaticallyImplyLeading: false,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 45,
              backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&q=80'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Rayt Polistico',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 2),
            const Text(
              'rayt.polistico@csucc.edu.ph',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),

            _buildSection([
              _buildMenuItem(Icons.shopping_cart_outlined, 'My Orders'),
              _buildMenuItem(Icons.sailing_outlined, 'Order Tracking'),
              _buildMenuItem(Icons.favorite_border, 'Wishlist'),
              _buildMenuItem(Icons.history, 'Recently Viewed'),
            ]),
            const SizedBox(height: 16),

            _buildSection([
              _buildMenuItem(Icons.location_on_outlined, 'Saved Addresses'),
              _buildMenuItem(Icons.account_balance_wallet_outlined, 'Payment Method (GCash/cash)'),
            ]),
            const SizedBox(height: 16),

            _buildSection([
              _buildToggleItem(Icons.notifications_none, 'Notifications', true),
              _buildMenuItem(Icons.translate, 'Language'),
              _buildToggleItem(Icons.dark_mode_outlined, 'Dark Mode', false),
              _buildMenuItem(Icons.swap_horiz, 'Switch Role', onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
              }),
            ]),
            const SizedBox(height: 24),

            _buildLogoutButton(context),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: const Icon(Icons.logout, color: Colors.redAccent),
        title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 15)),
        onTap: () async {
          await GoogleSignIn().signOut();
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
          }
        },
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

  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: Colors.black87, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildToggleItem(IconData icon, String title, bool value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: Colors.black87, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87)),
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