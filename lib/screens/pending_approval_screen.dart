import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/errors.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../widgets/custom_dialogs.dart';
import 'role_selection_screen.dart';

/// Shown when a user opens a Vendor or Delivery profile that an admin has not
/// approved, and when a role in use is suspended. It watches the user's
/// profile live, so an admin's decision on the web console appears here
/// immediately.
class PendingApprovalScreen extends StatelessWidget {
  final UserRole role;
  const PendingApprovalScreen({super.key, required this.role});

  /// Back to the profile picker: pops when opened from it, otherwise (shown by
  /// the router for a revoked role) clears the active role.
  Future<void> _backToProfiles(BuildContext context, AppUser profile) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      await AuthService.setActiveRole(profile, null);
    }
  }

  Future<void> _openDashboard(BuildContext context, AppUser profile) async {
    try {
      await AuthService.setActiveRole(profile, role);
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, friendlyError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().profile;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final status = profile.statusOf(role);
    final note = profile.reviewNoteFor(role);
    final view = _StatusView.of(role, status);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => _backToProfiles(context, profile),
        ),
        title: Text(role.label, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(color: view.color, shape: BoxShape.circle),
              child: Icon(view.icon, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 32),
            Text(view.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(view.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: view.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('Status: ${status ?? 'not applied'}',
                  style: TextStyle(color: view.color, fontWeight: FontWeight.bold)),
            ),
            if (note.isNotEmpty && status != RoleStatus.approved) ...[
              const SizedBox(height: 16),
              Text('Admin note: $note', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
            ],
            const Spacer(),
            if (status == RoleStatus.approved)
              _primaryButton('Open ${role.label} dashboard', () => _openDashboard(context, profile))
            else if (role.requiresApproval && (status == null || status == RoleStatus.rejected))
              _primaryButton(
                status == null ? 'Apply now' : 'Update & resubmit application',
                () => openRoleApplication(context, role, replace: true),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _backToProfiles(context, profile),
              child: const Text('Back to profiles', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                await AuthService.signOut();
                if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
    );
  }
}

class _StatusView {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  const _StatusView(this.title, this.message, this.icon, this.color);

  factory _StatusView.of(UserRole role, String? status) {
    switch (status) {
      case RoleStatus.pending:
        return _StatusView(
          'Pending Admin Approval',
          role == UserRole.vendor
              ? 'An admin is reviewing your stall application.\nThe Vendor dashboard unlocks once it\'s approved.'
              : 'The admin team is verifying your student ID and details.\nThis usually takes 1-2 business days.',
          Icons.access_time_filled,
          AppTheme.primaryColor,
        );
      case RoleStatus.rejected:
        return const _StatusView(
          'Application not approved',
          'Check the admin\'s note, update your details and resubmit.',
          Icons.cancel_outlined,
          Colors.redAccent,
        );
      case RoleStatus.suspended:
        return _StatusView(
          role == UserRole.customer ? 'Account suspended' : '${role.label} access suspended',
          'An admin has suspended this profile.\nPlease contact support for details.',
          Icons.block,
          Colors.redAccent,
        );
      case RoleStatus.approved:
        return _StatusView(
          'You\'re approved!',
          'Your ${role.label} profile is ready to use.',
          Icons.check,
          Colors.green,
        );
      default:
        return _StatusView(
          'Not registered yet',
          'Apply to become a ${role.label.toLowerCase()} for PaddlerBites. An admin reviews every application.',
          Icons.assignment_outlined,
          Colors.grey,
        );
    }
  }
}
