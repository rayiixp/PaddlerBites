import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/errors.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/custom_dialogs.dart';
import 'auth/login_screen.dart';

/// Login entry point, shown by the router whenever no one is signed in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
                          try {
                            // Only @csucc.edu.ph accounts get through; the router then
                            // opens the right module or the profile picker.
                            await AuthService.signInWithGoogle();
                          } on AuthException catch (e) {
                            if (context.mounted) showAppSnackBar(context, e.message, isError: true);
                          } catch (e) {
                            if (context.mounted) showAppSnackBar(context, 'Authentication failed. ${friendlyError(e)}', isError: true);
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
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        ),
                        child: const Text(
                          'Use email and password instead',
                          style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 28),
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