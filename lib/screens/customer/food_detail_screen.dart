import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/catalog_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/custom_dialogs.dart';

class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({super.key});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  int quantity = 1;
  bool _isAdding = false;
  bool _recorded = false;

  late final FoodModel _initialFood = ModalRoute.of(context)!.settings.arguments as FoodModel;
  late final Stream<FoodModel?> _item = CatalogService.itemStream(_initialFood.id);
  late final Stream<StallModel?> _stall = CatalogService.stallStream(_initialFood.stallId);
  late final DocumentReference<Map<String, dynamic>> _favoriteRef =
      UserService.currentUserRef.collection('favorites').doc(_initialFood.id);
  late final Stream<DocumentSnapshot> _favorite = _favoriteRef.snapshots();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorded) return;
    _recorded = true;
    // Remember this item for the profile's "Recently Viewed" list.
    UserService.currentUserRef.collection('recentlyViewed').doc(_initialFood.id).set({
      ..._initialFood.toSnapshotMap(),
      'savedAt': FieldValue.serverTimestamp(),
    }).ignore(); // Best effort; never blocks viewing the item.
  }

  Future<void> _toggleFavorite(bool isFavorite, FoodModel food) {
    return runGuarded(context, () async {
      if (isFavorite) {
        await _favoriteRef.delete();
      } else {
        await _favoriteRef.set({...food.toSnapshotMap(), 'savedAt': FieldValue.serverTimestamp()});
      }
    });
  }

  Future<void> _addToCart(FoodModel food) async {
    setState(() => _isAdding = true);
    try {
      await Provider.of<CartProvider>(context, listen: false).addToCart(food, qty: quantity);
      if (!mounted) return;
      showAppSnackBar(context, 'Added $quantity × ${food.name} to cart');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not add to cart. ${friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _openStall(String stallId) async {
    final stall = await CatalogService.getStall(stallId);
    if (stall != null && mounted) Navigator.pushNamed(context, '/stall-detail', arguments: stall);
  }

  @override
  Widget build(BuildContext context) {
    // Live item + stall so price, availability and open status stay current.
    return StreamBuilder<FoodModel?>(
      stream: _item,
      initialData: _initialFood,
      builder: (context, itemSnapshot) => StreamBuilder<StallModel?>(
        stream: _stall,
        builder: (context, stallSnapshot) => StreamBuilder<DocumentSnapshot>(
          stream: _favorite,
          builder: (context, favSnapshot) => _buildPage(
            itemSnapshot.data,
            stallIsOpen: stallSnapshot.data?.isOpen ?? true,
            isFavorite: favSnapshot.data?.exists ?? false,
          ),
        ),
      ),
    );
  }

  Widget _buildPage(FoodModel? liveFood, {required bool stallIsOpen, required bool isFavorite}) {
    final food = liveFood ?? _initialFood;
    final String? blockedReason = liveFood == null
        ? 'No longer available'
        : !food.isAvailable
            ? 'Sold out'
            : !stallIsOpen
                ? 'Stall closed'
                : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // Light icons for the image header
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Image Header with Overlays
                        Stack(
                          children: [
                            AppNetworkImage(
                              url: food.imageUrl,
                              height: 400,
                              width: double.infinity,
                            ),
                            Positioned(
                              top: 50,
                              left: 20,
                              child: _buildCircleButton(
                                icon: Icons.arrow_back_ios_new,
                                onTap: () => Navigator.pop(context),
                              ),
                            ),
                            Positioned(
                              top: 50,
                              right: 20,
                              child: _buildCircleButton(
                                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                                iconColor: isFavorite ? Colors.redAccent : Colors.black,
                                onTap: () => _toggleFavorite(isFavorite, food),
                              ),
                            ),
                            // Rounded overlap container start
                            Positioned(
                              bottom: -1,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Details Container
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      food.name,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 24),
                                      const SizedBox(width: 4),
                                      Text(
                                        food.ratingLabel,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatPeso(food.price),
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                food.description.isEmpty ? 'No description provided.' : food.description,
                                style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
                              ),
                              const SizedBox(height: 30),
                              GestureDetector(
                                onTap: () => _openStall(food.stallId),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Color(0xFF0D3B2E),
                                      child: Icon(Icons.storefront_outlined, color: AppTheme.primaryColor, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        food.stallName,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      // Quantity Selector (Updated layout style matching photo)
                      Row(
                        children: [
                          _buildQtyBtn(Icons.remove, () {
                            if (quantity > 1) setState(() => quantity--);
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$quantity',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          _buildQtyBtn(Icons.add, () => setState(() => quantity++)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      // Add to Cart Button (Updated border radius matching photo)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: blockedReason != null || _isAdding ? null : () => _addToCart(food),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            elevation: 0,
                          ),
                          child: Text(
                            blockedReason ?? 'Add to Cart · ${formatPeso(food.price * quantity)}',
                            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Top Status Bar Gradient (Scroll Protection)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: MediaQuery.of(context).padding.top + 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2), // Darker gradient for image protection
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap, Color iconColor = Colors.black}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black87, width: 1),
        ),
        child: Icon(icon, size: 18, color: Colors.black),
      ),
    );
  }
}