import 'package:flutter/material.dart';
import '../../core/errors.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_dialogs.dart';

/// Email/password login and registration, restricted to @csucc.edu.ph.
/// New accounts must verify their email before the app opens.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  final String _institutionalDomain = AuthService.institutionalDomain;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      showAppSnackBar(context, 'Please fill in all fields', isError: true);
      return;
    }
    if (!AuthService.isInstitutional(email)) {
      showAppSnackBar(context, 'Only $_institutionalDomain emails are allowed', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await AuthService.signInWithEmail(email, password);
      } else {
        await AuthService.registerWithEmail(name: name, email: email, password: password);
      }
      // The router takes over (email verification, profile picker or module).
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Authentication failed. ${friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Text(
              'PaddlerBites account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Exclusive for $_institutionalDomain',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Institutional Email',
                hintText: 'name@csucc.edu.ph',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _handleAuth,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(_isLogin ? 'Login' : 'Create Account'),
              ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin
                ? 'Don\'t have an account? Register'
                : 'Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
