import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// Stalls and their menu items. Vendors write here; customers read the same
/// documents through the streams below, so edits appear on customer screens
/// as soon as they are saved.
class CatalogService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _stalls => _db.collection('stalls');
  static CollectionReference<Map<String, dynamic>> get _menuItems => _db.collection('menuItems');

  // ---------------------------------------------------------------- Stalls

  static Stream<StallModel?> stallStream(String stallId) =>
      _stalls.doc(stallId).snapshots().map((doc) => doc.exists ? StallModel.fromDoc(doc) : null);

  static Future<StallModel?> getStall(String stallId) async {
    final doc = await _stalls.doc(stallId).get();
    return doc.exists ? StallModel.fromDoc(doc) : null;
  }

  /// Approved stalls, open ones first.
  static Stream<List<StallModel>> customerStalls() {
    return _stalls.snapshots().map((snap) {
      final stalls = snap.docs.map(StallModel.fromDoc).where((s) => s.isApproved).toList();
      stalls.sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return stalls;
    });
  }

  /// Creates or updates the vendor's stall. [submitForReview] marks it as a
  /// (re)submitted application: pending, closed and hidden from customers.
  static Future<void> saveStall({
    required String stallId,
    required bool submitForReview,
    required String name,
    required String program,
    required String category,
    required String operatingHours,
    required GeoPoint pickupPoint,
    XFile? logo,
    String? previousLogoPath,
  }) async {
    final data = <String, dynamic>{
      'ownerId': stallId,
      'stallName': name,
      'program': program,
      'category': category,
      'operatingHours': operatingHours,
      'pickupPoint': pickupPoint,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (logo != null) {
      final (url, path) = await StorageService.upload(
        logo,
        folder: 'stalls/$stallId',
        name: 'logo_${DateTime.now().millisecondsSinceEpoch}',
      );
      data['imageUrl'] = url;
      data['imagePath'] = path;
    }

    final bool exists;
    try {
      exists = (await _stalls.doc(stallId).get()).exists;
      if (submitForReview) {
        data.addAll({'status': AccountStatus.pending, 'isOpen': false, 'submittedAt': FieldValue.serverTimestamp()});
      }
      if (!exists) {
        data.addAll({'rating': 0.0, 'totalOrders': 0, 'createdAt': FieldValue.serverTimestamp()});
      }
      await _stalls.doc(stallId).set(data, SetOptions(merge: true));
    } catch (_) {
      // Don't leave the just-uploaded logo behind if the stall wasn't saved.
      if (logo != null) await StorageService.delete(data['imagePath'] as String?);
      rethrow;
    }
    if (exists) await _renameStallOnMenuItems(stallId, name);

    if (logo != null) await StorageService.delete(previousLogoPath);
  }

  static Future<void> updateStall(String stallId, Map<String, dynamic> data) =>
      _stalls.doc(stallId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  static Future<void> _renameStallOnMenuItems(String stallId, String stallName) async {
    final items = await _menuItems.where('stallId', isEqualTo: stallId).get();
    final batch = _db.batch();
    for (final doc in items.docs) {
      if (doc.data()['stallName'] != stallName) batch.update(doc.reference, {'stallName': stallName});
    }
    await batch.commit();
  }

  // ------------------------------------------------------------ Menu items

  static Stream<List<FoodModel>> stallMenu(String stallId) {
    return _menuItems.where('stallId', isEqualTo: stallId).snapshots().map((snap) {
      final items = snap.docs.map(FoodModel.fromDoc).toList();
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  static Stream<List<FoodModel>> availableItems() {
    return _menuItems
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(FoodModel.fromDoc).toList());
  }

  static Stream<FoodModel?> itemStream(String itemId) =>
      _menuItems.doc(itemId).snapshots().map((doc) => doc.exists ? FoodModel.fromDoc(doc) : null);

  static Future<FoodModel?> getItem(String itemId) async {
    final doc = await _menuItems.doc(itemId).get();
    return doc.exists ? FoodModel.fromDoc(doc) : null;
  }

  /// Adds a new item ([existing] is null) or updates one. A new [image]
  /// replaces the previous photo in Firebase Storage.
  static Future<void> saveMenuItem({
    FoodModel? existing,
    required String stallId,
    required String stallName,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
    XFile? image,
  }) async {
    final ref = existing == null ? _menuItems.doc() : _menuItems.doc(existing.id);
    final data = <String, dynamic>{
      'stallId': stallId,
      'stallName': stallName,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 1. Upload the photo first (fully awaited, URL taken from the finished upload).
    String? uploadedPath;
    if (image != null) {
      final (url, path) = await StorageService.upload(
        image,
        folder: 'stalls/$stallId/menu',
        name: '${ref.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      data['imageUrl'] = url;
      data['imagePath'] = path;
      uploadedPath = path;
    }

    // 2. Save the complete item. If this fails, remove the photo just uploaded
    //    so no orphaned file is left in Storage.
    try {
      if (existing == null) {
        await ref.set({
          'imageUrl': '',
          'imagePath': '',
          ...data,
          'rating': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.update(data);
      }
    } catch (_) {
      await StorageService.delete(uploadedPath);
      rethrow;
    }

    // 3. The new photo is saved; the replaced one can go.
    if (existing != null && image != null) await StorageService.delete(existing.imagePath);
  }

  static Future<void> setItemAvailability(String itemId, bool isAvailable) =>
      _menuItems.doc(itemId).update({'isAvailable': isAvailable, 'updatedAt': FieldValue.serverTimestamp()});

  static Future<void> deleteMenuItem(FoodModel item) async {
    await _menuItems.doc(item.id).delete();
    await StorageService.delete(item.imagePath);
  }
}
