import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'delivery_home_screen.dart';
import 'delivery_jobs_screen.dart';
import 'delivery_wallet_screen.dart';
import 'delivery_profile_screen.dart';

class DeliveryMainWrapper extends StatefulWidget {
  const DeliveryMainWrapper({super.key});

  @override
  State<DeliveryMainWrapper> createState() => _DeliveryMainWrapperState();
}

class _DeliveryMainWrapperState extends State<DeliveryMainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DeliveryHomeScreen(),
    const DeliveryJobsScreen(),
    const DeliveryWalletScreen(),
    const DeliveryProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),

          // Fading Gradient behind Navbar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08), 
                        blurRadius: 15, 
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                      _buildNavItem(1, Icons.assignment_outlined, Icons.assignment, 'Jobs'),
                      _buildNavItem(2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Wallet'),
                      _buildNavItem(3, Icons.person_outline, Icons.person, 'Profile'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.black : Colors.grey.shade400,
              size: 24,
            ),
          ),
          Text(
            label, 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
