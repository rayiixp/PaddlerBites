import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

class StallDetailScreen extends StatelessWidget {
  const StallDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stall = ModalRoute.of(context)!.settings.arguments as StallModel;

    // Dummy menu items for this stall
    final List<FoodModel> stallMenu = [
      FoodModel(name: 'Cheese Burger', stallName: stall.name, price: 30.00, rating: 4.8, imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&q=80'),
      FoodModel(name: 'Fried Chicken', stallName: stall.name, price: 50.00, rating: 4.7, imageUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&q=80'),
      FoodModel(name: 'Fries', stallName: stall.name, price: 35.00, rating: 4.6, imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500&q=80'),
      FoodModel(name: 'Orange Juice', stallName: stall.name, price: 20.00, rating: 4.5, imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500&q=80'),
      FoodModel(name: 'Spaghetti', stallName: stall.name, price: 70.00, rating: 4.7, imageUrl: 'https://images.unsplash.com/photo-1589187151032-573a91d17046?w=500&q=80'),
      FoodModel(name: 'Banana Cue', stallName: stall.name, price: 10.00, rating: 4.9, imageUrl: 'https://images.unsplash.com/photo-1632731805562-b91a789c62c9?w=500&q=80'),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Curved Header + Logo with properly positioned back button near the status bar
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  ClipPath(
                    clipper: HeaderClipper(),
                    child: Container(
                      height: 190,
                      width: double.infinity,
                      color: AppTheme.primaryColor,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -35,
                    child: Container(
                      height: 85,
                      width: 85,
                      decoration: BoxDecoration(
                        color: stall.bgColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(stall.logoPath, height: 50, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 45),

              // Stall Info
              Text(stall.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 2),
              const Text('BSEntrep', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(stall.rating.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),

              const SizedBox(height: 24),

              // Search and Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey.shade400, size: 22),
                          const SizedBox(width: 12),
                          Text('Search food from this stall...', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        CategoryChip(label: 'All', isActive: true),
                        SizedBox(width: 8),
                        CategoryChip(label: 'Snacks', isActive: false),
                        SizedBox(width: 8),
                        CategoryChip(label: 'Drinks', isActive: false),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Our Menu Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Our Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
              const SizedBox(height: 14),

              // Menu Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: stallMenu.length,
                  itemBuilder: (context, index) => _buildMenuItem(context, stallMenu[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, FoodModel food) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/food-detail', arguments: food),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    food.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
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
          const SizedBox(height: 8),
          Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text('₱${food.price.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 45);
    // Adjusted quadratic bezier curve to match the smooth symmetric arch shown in photo_3e37e5.png
    path.quadraticBezierTo(size.width / 2, size.height + 35, size.width, size.height - 45);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;
  const CategoryChip({super.key, required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}