import 'package:flutter/material.dart';
import '../../core/theme.dart';

class StallsDirectoryScreen extends StatefulWidget {
  const StallsDirectoryScreen({super.key});

  @override
  State<StallsDirectoryScreen> createState() => _StallsDirectoryScreenState();
}

class _StallsDirectoryScreenState extends State<StallsDirectoryScreen> {
  bool isStallsActive = true;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> dummyStalls = [
    {'name': 'Food Foundry', 'sub': 'BSEntrep', 'image': 'assets/images/app_icon.png'},
    {'name': 'Snackpreneurs', 'sub': 'BSEntrep', 'image': 'assets/images/customer_icon.png'},
    {'name': 'Taste Venture', 'sub': 'BSEntrep', 'image': 'assets/images/vendor_icon.png'},
    {'name': 'Snackpreneurs', 'sub': 'BSEntrep', 'image': 'assets/images/customer_icon.png'},
    {'name': 'Snackpreneurs', 'sub': 'BSEntrep', 'image': 'assets/images/customer_icon.png'},
  ];

  final List<Map<String, dynamic>> dummyMenu = [
    {'name': 'Cheese Burger', 'price': '₱30.00', 'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&q=80'},
    {'name': 'Fried Chicken', 'price': '₱50.00', 'image': 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&q=80'},
    {'name': 'Fries', 'price': '₱35.00', 'image': 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500&q=80'},
    {'name': 'Orange Juice', 'price': '₱20.00', 'image': 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500&q=80'},
    {'name': 'Spaghetti', 'price': '₱70.00', 'image': 'https://images.unsplash.com/photo-1589187151032-573a91d17046?w=500&q=80'},
    {'name': 'Banana Cue', 'price': '₱10.00', 'image': 'https://images.unsplash.com/photo-1632731805562-b91a789c62c9?w=500&q=80'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text(
                    'Stalls',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                _buildSearchBar(),
                _buildToggleRow(),
                Expanded(
                  child: isStallsActive ? _buildStallsList() : _buildMenuGrid(),
                ),
              ],
            ),

            // Fading Gradient behind Navbar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppTheme.backgroundColor,
                      AppTheme.backgroundColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            _buildFloatingNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade400, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search food from this stall...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _toggleButton('Stalls', isStallsActive, () => setState(() => isStallsActive = true)),
          const SizedBox(width: 8),
          _toggleButton('Menu', !isStallsActive, () => setState(() => isStallsActive = false)),
        ],
      ),
    );
  }

  Widget _toggleButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), // Reduced padding
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(10), // Slightly reduced border radius to match smaller size
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 14, // Reduced font size
          ),
        ),
      ),
    );
  }

  Widget _buildStallsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      itemCount: dummyStalls.length,
      itemBuilder: (context, index) {
        final stall = dummyStalls[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Container(
                width: 76, // Reduced image width
                height: 76, // Reduced image height
                decoration: BoxDecoration(
                  color: index == 0 ? const Color(0xFF333132) :
                  index == 1 ? const Color(0xFF1E4C59) :
                  index == 2 ? Colors.white :
                  Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(14), // Scaled down border radius slightly
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: index > 2
                      ? const SizedBox()
                      : Image.asset(stall['image']!, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 16), // Adjusted spacing to match new image size
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stall['name']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(stall['sub']!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.85,
      ),
      itemCount: dummyMenu.length,
      itemBuilder: (context, index) {
        final item = dummyMenu[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(image: NetworkImage(item['image']), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(item['price'], style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 13)),
          ],
        );
      },
    );
  }

  Widget _buildFloatingNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navItem(Icons.home, true),
                    _navItem(Icons.restaurant_menu_outlined, false),
                    _navItem(Icons.shopping_cart_outlined, false),
                    _navItem(Icons.person_outline, false),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.black, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: isActive ? Colors.black : Colors.grey.shade400, size: 24),
    );
  }
}