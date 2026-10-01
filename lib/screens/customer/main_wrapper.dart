import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/custom_dialogs.dart';
import '../../widgets/voice_order_sheet.dart';
import 'home_screen.dart';
import 'stalls_directory_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(onSearchTap: () => setState(() => _selectedIndex = 1)),
    const StallsDirectoryScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  /// The voice order in progress (its sheet is open).
  VoiceOrderController? _voice;

  /// Mic FAB, tap-to-toggle: the first tap starts recording and opens the
  /// voice sheet; the next tap (the sheet's big mic, or this button) stops
  /// and sends it. After the customer confirms, jump to the cart.
  Future<void> _onMicTap() async {
    final current = _voice;
    if (current != null) {
      current.finishRecording(); // ignored unless it's actually recording
      return;
    }
    final voice = _voice = VoiceOrderController();
    final added = await VoiceOrderSheet.show(context, voice);
    _voice = null;
    if (added == null || added == 0 || !mounted) return;
    setState(() => _selectedIndex = 2);
    showAppSnackBar(context, 'Added $added item${added == 1 ? '' : 's'} to your cart');
  }

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

          // Fading Gradient behind Navbar - Height reduced to prevent exceeding navbar top
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60, // Adjusted to match the navbar height + padding
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

          // Custom Bottom Navigation Overlay
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Main Nav Pill
                    Expanded(
                      child: Container(
                        height: 60, // Reduced height
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30), // Adjusted for new height
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(0, Icons.home_outlined, Icons.home),
                            _buildNavItem(1, Icons.restaurant_menu_outlined, Icons.restaurant_menu),
                            _buildNavItem(2, Icons.shopping_cart_outlined, Icons.shopping_cart),
                            _buildNavItem(3, Icons.person_outline, Icons.person),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Floating Mic Button
                    GestureDetector(
                      onTap: _onMicTap,
                      child: Container(
                        height: 60, // Reduced height
                        width: 60,  // Reduced width to keep it perfectly circular
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.mic, color: Colors.black, size: 26),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // Slightly tighter padding
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? Colors.black : Colors.grey.shade400,
          size: 24, // Slightly scaled down icon
        ),
      ),
    );
  }
}
