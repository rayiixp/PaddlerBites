import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_dialogs.dart';
import '../../widgets/premium_paddling_boat.dart';

class DeliveryProfileScreen extends StatelessWidget {
  /// Switches to the Wallet tab, which lists delivery history.
  final VoidCallback? onOpenWallet;
  const DeliveryProfileScreen({super.key, this.onOpenWallet});

  static const _modes = ['On foot', 'Bicycle', 'Motorcycle'];

  Future<void> _pickMode(BuildContext context, String current) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Delivery mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ..._modes.map((mode) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(mode),
                    trailing: mode == current
                        ? const Icon(Icons.check_circle, color: AppTheme.secondaryColor)
                        : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
                    onTap: () => Navigator.pop(context, mode),
                  )),
            ],
          ),
        ),
      ),
    );
    if (mode != null && context.mounted) {
      await runGuarded(context, () => UserService.currentUserRef.update({'deliveryMode': mode}), success: 'Delivery mode set to $mode');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserProvider>().userData ?? {};
    final mode = userData['deliveryMode'] ?? 'On foot';
    final deliveryStatus = context.watch<UserProvider>().profile?.deliveryStatus;
    final isVerified = deliveryStatus == RoleStatus.approved;

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
            const PremiumPaddlingBoatAnimation(size: 90),
            const SizedBox(height: 12),
            Text(userData['name'] ?? 'Rider', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 2),
            Text(userData['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(isVerified ? 'Verified' : (deliveryStatus ?? 'Pending'),
                  style: TextStyle(color: isVerified ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 28),

            // Section 1: Main Options Grouped in a Single White Card
            _buildSection([
              _buildProfileOption(context, Icons.history, 'Delivery history', onTap: onOpenWallet),
              _buildProfileOption(context, Icons.kayaking, 'Mode: $mode',
                  onTap: () => _pickMode(context, mode)),
              _buildProfileOption(
                context,
                Icons.payment,
                (userData['payoutAccount'] ?? '').isEmpty
                    ? 'Payout method (GCash)'
                    : 'Payout: GCash ${userData['payoutAccount']}',
                onTap: () async {
                  final account = await showTextInputDialog(
                    context,
                    title: 'GCash payout number',
                    initialValue: userData['payoutAccount'] ?? '',
                    hint: '09XX-XXX-XXXX',
                    keyboardType: TextInputType.phone,
                  );
                  if (account != null && context.mounted) {
                    await runGuarded(context, () => UserService.currentUserRef.update({'payoutAccount': account}),
                        success: 'Payout number saved');
                  }
                },
              ),
            ]),
            const SizedBox(height: 16),

            // Section 2: Toggle Option Grouped in a Single White Card
            _buildSection([
              _buildToggleOption(
                context,
                Icons.notifications_active_outlined,
                'New delivery alerts',
                userData['deliveryAlerts'] ?? true,
                (v) => runGuarded(context, () => UserService.currentUserRef.update({'deliveryAlerts': v})),
              ),
            ]),
            const SizedBox(height: 16),

            // Section 3: Support Option Grouped in a Single White Card
            _buildSection([
              _buildProfileOption(context, Icons.help_outline, 'Help & support',
                  onTap: () => showComingSoon(context, 'In-app support')),
            ]),
            const SizedBox(height: 16),

            // Section 4: Switch Role & Logout Grouped in a Single White Card
            _buildSection([
              _buildProfileOption(
                context,
                Icons.swap_horiz,
                'Switch role',
                onTap: () {
                  Navigator.pushNamed(context, '/role-selection');
                },
              ),
              _buildProfileOption(
                context,
                Icons.logout,
                'Logout',
                textColor: Colors.redAccent,
                onTap: () async {
                  await UserService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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

  Widget _buildToggleOption(BuildContext context, IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
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
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: Colors.black,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}
