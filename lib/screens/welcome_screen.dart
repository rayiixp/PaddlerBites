import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

class WelcomeScreen extends StatelessWidget {
  final String selectedRole;
  const WelcomeScreen({super.key, this.selectedRole = 'Customer'});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // Background photo
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/welcome_background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 0.9],
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      // Fork/Spoon/Wave Logo (Reduced size)
                      Image.asset(
                        'assets/images/paddlerbites_logo.png',
                        height: 100,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10), // Small gap to keep them close
                      // SVG Text Logo (Reduced size)
                      SvgPicture.asset(
                        'assets/images/paddlerbites_text.svg',
                        height: 22,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      const SizedBox(height: 220), // Increased to push lower content down
                      const Text(
                        'Paddle your way to great food',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18, // Slightly smaller to match target
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      // Sign up or log in divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.8), thickness: 1)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Sign up or log in',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.8), thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 25),
                      // Google Login Button (Updated to use AppTheme.primaryColor)
                      OutlinedButton(
                        onPressed: () async {
                          final GoogleSignIn googleSignIn = GoogleSignIn();
                          try {
                            final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
                            if (googleUser == null) return;

                            // Domain validation (@csucc.edu.ph)
                            if (!googleUser.email.endsWith('@csucc.edu.ph')) {
                              await googleSignIn.disconnect();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Access Denied: Please use your official institutional email address.'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                              }
                              return;
                            }

                            final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
                            final AuthCredential credential = GoogleAuthProvider.credential(
                              accessToken: googleAuth.accessToken,
                              idToken: googleAuth.idToken,
                            );

                            final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
                            final User? user = userCredential.user;

                            if (user != null) {
                              final String targetRole = selectedRole.toLowerCase().replaceAll(' personnel', '');

                              // Create or update user role and details in Firestore
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                'name': user.displayName ?? 'User',
                                'email': user.email,
                                'role': targetRole,
                                'status': targetRole == 'customer' ? 'Active' : 'Pending Review',
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              if (context.mounted) {
                                if (targetRole == 'vendor') {
                                  Navigator.pushNamedAndRemoveUntil(context, '/vendor-home', (route) => false);
                                } else if (targetRole == 'delivery') {
                                  Navigator.pushNamedAndRemoveUntil(context, '/delivery-main', (route) => false);
                                } else {
                                  Navigator.pushNamedAndRemoveUntil(context, '/customer-main', (route) => false);
                                }
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Authentication failed: $e')),
                              );
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor, // Using theme color
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 54),
                          side: const BorderSide(color: Colors.transparent), // Removes the grey border
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/google_icon.png',
                              height: 24,
                              width: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F1F1F),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Campus eats, delivered by your fellow Paddlers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}