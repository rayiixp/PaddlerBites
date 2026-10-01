import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/catalog_service.dart';
import '../../widgets/app_image.dart';

class HomeScreen extends StatefulWidget {
  /// Opens the Stalls tab, where search lives.
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _stalls = CatalogService.customerStalls();
  final _items = CatalogService.availableItems();
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final name = (context.watch<UserProvider>().userData?['name'] as String? ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<List<StallModel>>(
        stream: _stalls,
        builder: (context, stallSnapshot) {
          final openStalls = (stallSnapshot.data ?? []).where((s) => s.isOpen).toList();
          final openStallIds = openStalls.map((s) => s.id).toSet();

          return StreamBuilder<List<FoodModel>>(
            stream: _items,
            builder: (context, itemSnapshot) {
              // Popular = highest rated available items from open stalls.
              final foods = (itemSnapshot.data ?? [])
                  .where((f) => openStallIds.contains(f.stallId))
                  .where((f) => _category == 'All' || f.category == _category)
                  .toList()
                ..sort((a, b) => b.rating.compareTo(a.rating));
              final popular = foods.take(10).toList();
              final isLoading = !stallSnapshot.hasData || !itemSnapshot.hasData;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting(), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(name.isEmpty ? 'Paddler' : name,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                const Text('☀️', style: TextStyle(fontSize: 24)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildSearchBar(),
                            const SizedBox(height: 32),
                            const Text('Open Stalls', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            if (!stallSnapshot.hasData)
                              const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
                            else if (openStalls.isEmpty)
                              _buildEmptyText('No stalls are open right now')
                            else
                              _buildStallList(openStalls),
                            const SizedBox(height: 32),
                            CategoryFilter(selected: _category, onSelected: (cat) => setState(() => _category = cat)),
                            const SizedBox(height: 32),
                            const Text('Popular Now', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            if (!isLoading && popular.isEmpty) _buildEmptyText('Nothing to show here yet'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => FoodCard(food: popular[index]),
                        childCount: popular.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for floating nav
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text, style: TextStyle(color: Colors.grey.shade400))),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: widget.onSearchTap,
      child: Container(
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
                  child: stall.imageUrl.isEmpty
                      ? const Center(child: Icon(Icons.storefront_outlined, color: AppTheme.primaryColor, size: 48))
                      : AppNetworkImage(url: stall.imageUrl, width: double.infinity, placeholderIcon: Icons.storefront_outlined),
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
                          stall.rating > 0 ? stall.rating.toStringAsFixed(1) : 'New',
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

class CategoryFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const CategoryFilter({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: ['All', ...kMenuCategories].map((cat) {
          bool isActive = selected == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onSelected(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: isActive ? Colors.black : Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Text(cat, style: TextStyle(color: isActive ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }).toList(),
      ),
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
                child: AppNetworkImage(
                  url: food.imageUrl,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(food.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                Row(children: [const Icon(Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 4), Text(food.ratingLabel, style: const TextStyle(fontWeight: FontWeight.bold))]),
              ],
            ),
            Text(formatPeso(food.price), style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(food.stallName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
