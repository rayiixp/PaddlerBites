import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_dialogs.dart';
import 'my_orders_screen.dart';
import 'saved_items_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final userData = context.watch<UserProvider>().userData ?? {};
    final authUser = FirebaseAuth.instance.currentUser;
    final name = userData['name'] ?? authUser?.displayName ?? 'Paddler';
    final photoUrl = authUser?.photoURL;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Profile', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
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
            CircleAvatar(
              radius: 45,
              backgroundColor: colors.primary,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: theme.textTheme.headlineMedium?.copyWith(color: colors.onPrimary, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              userData['email'] ?? authUser?.email ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 32),

            _buildSection(context, [
              _buildMenuItem(
                context: context,
                icon: Icons.shopping_cart_outlined,
                title: 'My Orders',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersScreen()));
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.sailing_outlined,
                title: 'Order Tracking',
                onTap: () {
                  Navigator.pushNamed(context, '/order-tracking');
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.favorite_border,
                title: 'Wishlist',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedItemsScreen(
                        title: 'Wishlist',
                        collection: 'favorites',
                        emptyText: 'Tap ♡ on any food to save it here',
                      ),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.history,
                title: 'Recently Viewed',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedItemsScreen(
                        title: 'Recently Viewed',
                        collection: 'recentlyViewed',
                        emptyText: 'Food you open will show up here',
                      ),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 16),

            _buildSection(context, [
              _buildToggleItem(
                context,
                Icons.notifications_none,
                'Notifications',
                userData['notificationsEnabled'] ?? true,
                (v) => runGuarded(context, () => UserService.currentUserRef.update({'notificationsEnabled': v})),
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.lock_outline,
                title: 'Set/Change MPIN',
                onTap: () => showComingSoon(context, 'MPIN settings'),
              ),
              _buildToggleItem(
                context,
                Icons.dark_mode_outlined,
                'Dark Mode',
                false,
                (v) => showComingSoon(context, 'Dark mode'),
              ),
            ]),
            const SizedBox(height: 16),

            _buildSection(context, [
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
                textColor: colors.error,
                onTap: () async {
                  await UserService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
              ),
            ]),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, List<Widget> items) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    List<Widget> separatedItems = [];
    for (int i = 0; i < items.length; i++) {
      separatedItems.add(items[i]);
      if (i < items.length - 1) {
        separatedItems.add(Divider(height: 1, thickness: 1, color: colors.onSurface.withValues(alpha: 0.08)));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final itemColor = textColor ?? colors.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: itemColor, size: 24),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(color: itemColor, fontWeight: FontWeight.w500),
      ),
      trailing: textColor == null
          ? Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.4), size: 22)
          : null,
      onTap: onTap ?? () {},
    );
  }

  Widget _buildToggleItem(BuildContext context, IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: colors.onSurface, size: 24),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w500),
      ),
      trailing: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: colors.onPrimary,
          activeTrackColor: colors.primary,
          inactiveThumbColor: colors.surface,
          inactiveTrackColor: colors.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
