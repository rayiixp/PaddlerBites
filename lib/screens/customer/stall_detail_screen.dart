import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/catalog_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/menu_grid_item.dart';

class StallDetailScreen extends StatefulWidget {
  const StallDetailScreen({super.key});

  @override
  State<StallDetailScreen> createState() => _StallDetailScreenState();
}

class _StallDetailScreenState extends State<StallDetailScreen> {
  late final StallModel _initialStall = ModalRoute.of(context)!.settings.arguments as StallModel;
  late final Stream<StallModel?> _stall = CatalogService.stallStream(_initialStall.id);
  late final Stream<List<FoodModel>> _menu = CatalogService.stallMenu(_initialStall.id);
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    // Live stall doc so open/closed changes show up while browsing.
    return StreamBuilder<StallModel?>(
      stream: _stall,
      initialData: _initialStall,
      builder: (context, snapshot) => _buildPage(snapshot.data ?? _initialStall),
    );
  }

  Widget _buildPage(StallModel stall) {
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
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: StallLogo(imageUrl: stall.imageUrl, size: 85, radius: 20, bgColor: stall.bgColor),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 45),

              // Stall Info
              Text(stall.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              if (stall.program.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(stall.program, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(stall.rating > 0 ? stall.rating.toStringAsFixed(1) : 'New',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  if (stall.operatingHours.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, color: Colors.grey.shade500, size: 14),
                    const SizedBox(width: 4),
                    Text(stall.operatingHours, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ],
              ),

              if (!stall.isOpen) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      children: [
                        Icon(Icons.storefront_outlined, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(child: Text('This stall is closed right now. You can browse, but ordering is paused.')),
                      ],
                    ),
                  ),
                ),
              ],

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
                          Expanded(
                            child: TextField(
                              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                              decoration: InputDecoration(
                                hintText: 'Search food from this stall...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', ...kMenuCategories]
                            .map((cat) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: CategoryChip(
                                    label: cat,
                                    isActive: _category == cat,
                                    onTap: () => setState(() => _category = cat),
                                  ),
                                ))
                            .toList(),
                      ),
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

              // Menu Grid — exactly what the vendor has published, in real time
              StreamBuilder<List<FoodModel>>(
                stream: _menu,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(padding: const EdgeInsets.all(24), child: Text('Could not load menu: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator());
                  }
                  final menu = snapshot.data!
                      .where((f) => _category == 'All' || f.category == _category)
                      .where((f) => _query.isEmpty || f.name.toLowerCase().contains(_query))
                      .toList();
                  // Available items first; sort is stable so names stay alphabetical.
                  mergeSort(menu, compare: (a, b) => (a.isAvailable ? 0 : 1) - (b.isAvailable ? 0 : 1));

                  if (menu.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                      child: Text(
                        snapshot.data!.isEmpty ? 'This stall hasn\'t added any items yet' : 'No items match your search',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    );
                  }

                  return Padding(
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
                      itemCount: menu.length,
                      itemBuilder: (context, index) => MenuGridItem(food: menu[index], canOrder: stall.isOpen),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
  final VoidCallback? onTap;
  const CategoryChip({super.key, required this.label, required this.isActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}
