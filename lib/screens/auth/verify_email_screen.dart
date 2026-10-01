import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_dialogs.dart';

/// Shown by the router for email/password accounts until the user clicks the
/// verification link, proving they own the @csucc.edu.ph mailbox.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isChecking = false;

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);
    try {
      // reload() fires userChanges; the router moves on once verified.
      await AuthService.reloadUser();
      if (mounted && !(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
        showAppSnackBar(context, 'Not verified yet. Open the link in the email we sent you.');
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_unread_outlined, color: Colors.black, size: 48),
              ),
              const SizedBox(height: 32),
              const Text('Verify your email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'We sent a verification link to\n$email\nOpen it, then come back here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkVerified,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('I\'ve verified my email', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              TextButton(
                onPressed: () async {
                  await AuthService.resendVerificationEmail();
                  if (context.mounted) showAppSnackBar(context, 'Verification email sent to $email');
                },
                child: const Text('Resend email', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => AuthService.signOut(),
                child: const Text('Use another account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
