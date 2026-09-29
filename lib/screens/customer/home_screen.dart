import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- Dynamic Lists ---
    final List<StallModel> stalls = [
      StallModel(name: 'Snackpreneurs', rating: 4.8, logoPath: 'assets/images/customer_icon.png', bgColor: const Color(0xFF0D3B2E)),
      StallModel(name: 'Taste Venture', rating: 4.9, logoPath: 'assets/images/vendor_icon.png', bgColor: Colors.white),
      StallModel(name: 'Paddler Eats', rating: 4.7, logoPath: 'assets/images/app_icon.png', bgColor: AppTheme.primaryColor),
    ];

    final List<FoodModel> foods = [
      FoodModel(name: 'Cheese Burger', stallName: 'Snackpreneurs', price: 30.00, rating: 4.8, imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&q=80'),
      FoodModel(name: 'Pizza', stallName: 'Taste Venture', price: 110.00, rating: 4.8, imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&q=80'),
      FoodModel(name: 'Chocolate Cake', stallName: 'Taste Venture', price: 80.00, rating: 4.9, imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500&q=80'),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Good morning,', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const Row(
                      children: [
                        Text('Rayt', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Text('☀️', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSearchBar(),
                    const SizedBox(height: 32),
                    const Text('Open Stalls', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildStallList(stalls),
                    const SizedBox(height: 32),
                    const CategoryFilter(),
                    const SizedBox(height: 32),
                    const Text('Popular Now', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => FoodCard(food: foods[index]),
                childCount: foods.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for floating nav
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50, // Reduced height to match the photo's proportions
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300, width: 1), // Distinct but light border
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey.shade400, size: 24),
          const SizedBox(width: 12),
          Text(
            'Search stalls or food...',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15), // Adjusted font size
          ),
        ],
      ),
    );
  }

  Widget _buildStallList(List<StallModel> stalls) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(left: 4, bottom: 20),
        itemCount: stalls.length,
        itemBuilder: (context, index) => StallCard(stall: stalls[index]),
      ),
    );
  }
}

class StallCard extends StatelessWidget {
  final StallModel stall;
  const StallCard({super.key, required this.stall});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/stall-detail', arguments: stall),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Adjusted shadow to match the specific look from the photo
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15.0,
              spreadRadius: 1.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: stall.bgColor,
                  ),
                  child: Center(
                    child: Image.asset(stall.logoPath, height: 60, fit: BoxFit.contain),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stall.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          stall.rating.toString(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryFilter extends StatefulWidget {
  const CategoryFilter({super.key});
  @override
  State<CategoryFilter> createState() => _CategoryFilterState();
}

class _CategoryFilterState extends State<CategoryFilter> {
  String selected = 'All';
  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['All', 'Snacks', 'Drinks'].map((cat) {
        bool isActive = selected == cat;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => setState(() => selected = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: isActive ? Colors.black : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Text(cat, style: TextStyle(color: isActive ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class FoodCard extends StatelessWidget {
  final FoodModel food;
  const FoodCard({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/food-detail', arguments: food),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  food.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(food.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(children: [const Icon(Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 4), Text(food.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold))]),
              ],
            ),
            Text('₱${food.price.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(food.stallName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}