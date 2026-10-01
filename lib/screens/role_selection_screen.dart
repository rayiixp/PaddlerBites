import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/errors.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_dialogs.dart';
import 'delivery/delivery_registration_screen.dart';
import 'pending_approval_screen.dart';
import 'vendor/vendor_setup_screen.dart';

/// Opens the vendor or delivery application form (prefilled when resubmitting).
Future<void> openRoleApplication(BuildContext context, UserRole role, {bool replace = false}) async {
  final Widget form;
  if (role == UserRole.vendor) {
    final stall = await CatalogService.getStall(UserService.uid);
    form = VendorSetupScreen(existing: stall, isApplication: true);
  } else {
    form = const DeliveryRegistrationScreen();
  }
  if (!context.mounted) return;
  final route = MaterialPageRoute(builder: (context) => form);
  if (replace) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}

/// "Select profile" screen, shown after login when the account has more than
/// one approved role, and from each module's "Switch role" option.
/// Unapproved roles show their status and lead to [PendingApprovalScreen] or
/// the application form.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _isOpening = false;

  final List<UserRole> roles = UserRole.values;

  @override
  void initState() {
    super.initState();
    final active = Provider.of<UserProvider>(context, listen: false).profile?.activeRole;
    _currentPage = active == null ? 0 : roles.indexOf(active);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue(AppUser profile) async {
    final role = roles[_currentPage];
    final status = profile.statusOf(role);

    if (status == RoleStatus.approved) {
      setState(() => _isOpening = true);
      try {
        await AuthService.setActiveRole(profile, role);
        // The router swaps to the module; close the picker if it was pushed.
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (mounted) showAppSnackBar(context, friendlyError(e), isError: true);
      } finally {
        if (mounted) setState(() => _isOpening = false);
      }
    } else if (status == null && role.requiresApproval) {
      await openRoleApplication(context, role);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => PendingApprovalScreen(role: role)));
    }
  }

  String _buttonLabel(UserRole role, String? status) {
    if (status == RoleStatus.approved) return 'Continue as ${role.label}';
    if (status == null) return 'Apply as ${role.label}';
    return 'View application status';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().profile;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final firstName = profile.name.split(' ').first;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: Navigator.canPop(context),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await AuthService.signOut();
              if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            firstName.isEmpty ? 'Choose your profile' : 'Hi $firstName, choose your profile',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: roles.length,
              itemBuilder: (context, index) {
                final role = roles[index];
                return AnimatedScale(
                  scale: _currentPage == index ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 300),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: (_currentPage == index)
                          ? const BorderSide(color: AppTheme.primaryColor, width: 2)
                          : BorderSide.none,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          role.iconAsset,
                          height: 200,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          role.label,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        RoleStatusChip(status: profile.statusOf(role)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              roles.length,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? AppTheme.primaryColor
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: ElevatedButton(
              onPressed: _isOpening ? null : () => _continue(profile),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: Text(_buttonLabel(roles[_currentPage], profile.statusOf(roles[_currentPage]))),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status badge for a role card.
class RoleStatusChip extends StatelessWidget {
  final String? status;
  const RoleStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (String label, MaterialColor color) = switch (status) {
      RoleStatus.approved => ('Approved', Colors.green),
      RoleStatus.pending => ('Pending admin approval', Colors.orange),
      RoleStatus.rejected => ('Not approved', Colors.red),
      RoleStatus.suspended => ('Suspended', Colors.red),
      _ => ('Not registered', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
