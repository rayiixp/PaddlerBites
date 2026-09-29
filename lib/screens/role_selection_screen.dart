import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'delivery/delivery_registration_screen.dart';
import 'vendor/vendor_setup_screen.dart';
import 'welcome_screen.dart';
import 'auth/login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> roles = [
    {
      'name': 'Customer',
      'icon': 'assets/images/customer_icon.png',
    },
    {
      'name': 'Delivery Personnel',
      'icon': 'assets/images/delivery_personnel_icon.png',
    },
    {
      'name': 'Vendor',
      'icon': 'assets/images/vendor_icon.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Shield icon removed here
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Login as',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
                          roles[index]['icon']!,
                          height: 200,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          roles[index]['name']!,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
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
              onPressed: () {
                final selectedRole = roles[_currentPage]['name']!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WelcomeScreen(selectedRole: selectedRole),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }
}