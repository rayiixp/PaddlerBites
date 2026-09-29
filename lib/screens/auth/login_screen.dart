import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  final String initialRole;
  const LoginScreen({super.key, required this.initialRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  final String _institutionalDomain = '@csucc.edu.ph';

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!email.endsWith(_institutionalDomain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only $_institutionalDomain emails are allowed')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String targetRole = widget.initialRole.toLowerCase().replaceAll(' personnel', '');

      if (_isLogin) {
        UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
            'role': targetRole,
            'status': targetRole == 'customer' ? 'Active' : 'Pending Review',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Save user role and info to Firestore
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'name': email.split('@')[0], // Default name from email
          'email': email,
          'role': targetRole,
          'status': targetRole == 'customer' ? 'Active' : 'Pending Review',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        if (targetRole == 'vendor') {
          Navigator.pushNamedAndRemoveUntil(context, '/vendor-home', (route) => false);
        } else if (targetRole == 'delivery') {
          Navigator.pushNamedAndRemoveUntil(context, '/delivery-main', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/customer-main', (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Authentication failed';
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found with this institutional email.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Incorrect password. Please try again.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        } else {
          errorMessage = e.message ?? 'An unknown error occurred.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Access for ${widget.initialRole}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Exclusive for $_institutionalDomain',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
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
