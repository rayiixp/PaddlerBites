import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/catalog_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/custom_dialogs.dart';
import 'vendor_sales_report_screen.dart';
import 'vendor_setup_screen.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  Future<void> _updateStall(BuildContext context, Map<String, dynamic> data) async {
    try {
      await CatalogService.updateStall(UserService.uid, data);
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, 'Could not save. ${friendlyError(e)}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StallModel?>(
      stream: CatalogService.stallStream(UserService.uid),
      builder: (context, snapshot) {
        final stall = snapshot.data;
        final userData = context.watch<UserProvider>().userData ?? {};
        return _buildScaffold(context, stall, userData);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, StallModel? stall, Map<String, dynamic> userData) {
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
                  StallLogo(imageUrl: stall?.imageUrl ?? '', size: 90, radius: 26),
                  const SizedBox(height: 12),
                  Text(stall?.name ?? 'My stall', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (stall?.program.isNotEmpty ?? false) ...[
                        Text(stall!.program, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(width: 8),
                      ],
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        (stall?.rating ?? 0) > 0 ? stall!.rating.toStringAsFixed(1) : 'New',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
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
                onTap: stall == null
                    ? null
                    : () => Navigator.push(
                        context, MaterialPageRoute(builder: (context) => VendorSetupScreen(existing: stall))),
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.access_time_outlined,
                title: 'Operating hours',
                onTap: () async {
                  final hours = await showTextInputDialog(
                    context,
                    title: 'Operating hours',
                    initialValue: stall?.operatingHours ?? '',
                    hint: '7:00 AM - 5:00 PM',
                  );
                  if (hours != null && context.mounted) await _updateStall(context, {'operatingHours': hours});
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.payment_outlined,
                title: 'Payout account',
                onTap: () async {
                  final account = await showTextInputDialog(
                    context,
                    title: 'GCash payout number',
                    initialValue: stall?.payoutAccount ?? '',
                    hint: '09XX-XXX-XXXX',
                    keyboardType: TextInputType.phone,
                  );
                  if (account != null && context.mounted) await _updateStall(context, {'payoutAccount': account});
                },
              ),
            ]),
            const SizedBox(height: 16),

            // Section 2: Toggles Grouped in a Single White Card
            _buildSection([
              _buildToggleItem(
                Icons.notifications_active_outlined,
                'Order notifications',
                userData['orderNotifications'] ?? true,
                (v) => runGuarded(context, () => UserService.currentUserRef.update({'orderNotifications': v})),
              ),
              _buildToggleItem(
                Icons.store_mall_directory_outlined,
                'Stall open',
                stall?.isOpen ?? false,
                stall == null ? null : (v) => _updateStall(context, {'isOpen': v}),
              ),
            ]),
            const SizedBox(height: 16),

            // Section 3: Role Switch & Logout Grouped in a Single White Card
            _buildSection([
              _buildMenuItem(
                context: context,
                icon: Icons.swap_horiz,
                title: 'Switch role',
                onTap: () {
                  Navigator.pushNamed(context, '/role-selection');
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.logout,
                title: 'Logout',
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

  Widget _buildToggleItem(IconData icon, String title, bool value, ValueChanged<bool>? onChanged) {
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