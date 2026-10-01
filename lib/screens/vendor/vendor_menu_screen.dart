import 'package:flutter/material.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/catalog_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/custom_dialogs.dart';
import 'vendor_menu_item_form_screen.dart';

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  final _stallMenu = CatalogService.stallMenu(UserService.uid);
  String _query = '';

  void _openForm([FoodModel? item]) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => VendorMenuItemFormScreen(existing: item)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My menu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_box_outlined, color: AppTheme.primaryColor, size: 28),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search your menu items',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<FoodModel>>(
                stream: _stallMenu,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Could not load menu: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!
                      .where((item) => _query.isEmpty || item.name.toLowerCase().contains(_query))
                      .toList();

                  if (snapshot.data!.isEmpty) return _buildEmptyState();
                  if (items.isEmpty) {
                    return Center(child: Text('No items match "$_query"', style: const TextStyle(color: Colors.grey)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildMenuItem(items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Your menu is empty', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Add your first item so customers can order it', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _openForm(),
              style: ElevatedButton.styleFrom(elevation: 0),
              child: const Text('Add menu item'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(FoodModel item) {
    return GestureDetector(
      onTap: () => _openForm(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppNetworkImage(url: item.imageUrl, width: 60, height: 60),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    item.isAvailable ? formatPeso(item.price) : 'Sold out',
                    style: TextStyle(
                      color: item.isAvailable ? AppTheme.secondaryColor : Colors.grey,
                      fontWeight: item.isAvailable ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (item.category.isNotEmpty)
                    Text(item.category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: item.isAvailable,
              onChanged: (v) async {
                try {
                  await CatalogService.setItemAvailability(item.id, v);
                } catch (e) {
                  if (mounted) showAppSnackBar(context, 'Could not update ${item.name}. ${friendlyError(e)}', isError: true);
                }
              },
              activeColor: AppTheme.primaryColor,
            ),
            IconButton(
              onPressed: () => _openForm(item),
              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
