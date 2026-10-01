import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/catalog_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/custom_dialogs.dart';

/// Wishlist (`users/{uid}/favorites`) or Recently Viewed (`users/{uid}/recentlyViewed`).
class SavedItemsScreen extends StatelessWidget {
  final String title;
  final String collection;
  final String emptyText;

  const SavedItemsScreen({super.key, required this.title, required this.collection, required this.emptyText});

  Future<void> _open(BuildContext context, String itemId) async {
    // Open the live item so price/availability are current.
    final food = await CatalogService.getItem(itemId);
    if (!context.mounted) return;
    if (food == null) {
      showAppSnackBar(context, 'This item is no longer on the menu');
      return;
    }
    Navigator.pushNamed(context, '/food-detail', arguments: food);
  }

  @override
  Widget build(BuildContext context) {
    final ref = UserService.currentUserRef.collection(collection);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.orderBy('savedAt', descending: true).limit(30).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text(emptyText, style: const TextStyle(color: Colors.grey, fontSize: 16)));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final food = FoodModel.fromMap(docs[index].id, docs[index].data());
              return GestureDetector(
                onTap: () => _open(context, food.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppNetworkImage(url: food.imageUrl, width: 60, height: 60),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(food.stallName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 2),
                            Text(formatPeso(food.price), style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                        onPressed: () => runGuarded(context, () => ref.doc(food.id).delete()),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
