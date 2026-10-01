import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import 'app_image.dart';
import 'custom_dialogs.dart';

/// Adds one [food] to the cart and confirms with a snackbar.
Future<void> quickAddToCart(BuildContext context, FoodModel food) async {
  try {
    await Provider.of<CartProvider>(context, listen: false).addToCart(food);
    if (context.mounted) showAppSnackBar(context, '${food.name} added to cart');
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, 'Could not add to cart. ${friendlyError(e)}', isError: true);
  }
}

/// Grid tile for a menu item: photo with a quick-add button, name and price.
class MenuGridItem extends StatelessWidget {
  final FoodModel food;

  /// False when the stall is closed; hides the quick-add button.
  final bool canOrder;

  const MenuGridItem({super.key, required this.food, this.canOrder = true});

  @override
  Widget build(BuildContext context) {
    final orderable = canOrder && food.isAvailable;
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
                  child: AppNetworkImage(url: food.imageUrl, width: double.infinity, height: double.infinity),
                ),
                if (!food.isAvailable)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('Sold out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      ),
                    ),
                  ),
                if (orderable)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => quickAddToCart(context, food),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.add, size: 18, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(food.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            formatPeso(food.price),
            style: TextStyle(
              color: food.isAvailable ? AppTheme.secondaryColor : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
