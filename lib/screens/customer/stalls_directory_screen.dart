import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/catalog_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/menu_grid_item.dart';

class StallsDirectoryScreen extends StatefulWidget {
  const StallsDirectoryScreen({super.key});

  @override
  State<StallsDirectoryScreen> createState() => _StallsDirectoryScreenState();
}

class _StallsDirectoryScreenState extends State<StallsDirectoryScreen> {
  bool isStallsActive = true;
  final TextEditingController _searchController = TextEditingController();
  final _stalls = CatalogService.customerStalls();
  final _items = CatalogService.availableItems();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
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
              child: StreamBuilder<List<StallModel>>(
                stream: _stalls,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Could not load stalls: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return isStallsActive ? _buildStallsList(snapshot.data!) : _buildMenuGrid(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matches(String text) => _query.isEmpty || text.toLowerCase().contains(_query);

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
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: isStallsActive ? 'Search stalls...' : 'Search food...',
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

  Widget _buildEmpty(String text) {
    return Center(child: Text(text, style: TextStyle(color: Colors.grey.shade400)));
  }

  Widget _buildStallsList(List<StallModel> allStalls) {
    final stalls = allStalls.where((s) => _matches(s.name) || _matches(s.program) || _matches(s.category)).toList();
    if (stalls.isEmpty) return _buildEmpty(_query.isEmpty ? 'No stalls yet' : 'No stalls match your search');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      itemCount: stalls.length,
      itemBuilder: (context, index) {
        final stall = stalls[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pushNamed(context, '/stall-detail', arguments: stall),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                StallLogo(imageUrl: stall.imageUrl, size: 76, radius: 14, bgColor: stall.bgColor),
                const SizedBox(width: 16), // Adjusted spacing to match new image size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stall.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        [stall.program, stall.category].where((t) => t.isNotEmpty).join(' · '),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stall.isOpen ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stall.isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      color: stall.isOpen ? Colors.green : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid(List<StallModel> stalls) {
    final stallsById = {for (final s in stalls) s.id: s};
    return StreamBuilder<List<FoodModel>>(
      stream: _items,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        // Only items from approved stalls, matching the search.
        final menu = snapshot.data!
            .where((f) => stallsById.containsKey(f.stallId))
            .where((f) => _matches(f.name) || _matches(f.stallName))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (menu.isEmpty) return _buildEmpty(_query.isEmpty ? 'No menu items yet' : 'No food matches your search');

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.85,
          ),
          itemCount: menu.length,
          itemBuilder: (context, index) {
            final food = menu[index];
            return MenuGridItem(food: food, canOrder: stallsById[food.stallId]?.isOpen ?? false);
          },
        );
      },
    );
  }
}
