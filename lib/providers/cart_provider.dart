import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _totalPrice = 0.0;
  double get totalPrice => _totalPrice;

  // Collection reference for current user's cart
  CollectionReference get _cartRef => 
    _db.collection('users').doc(_auth.currentUser?.uid).collection('cart');

  // Set total price (called from StreamBuilder)
  void updateTotalPrice(double price) {
    if (_totalPrice != price) {
      _totalPrice = price;
      // We use notifyListeners() carefully to avoid rebuild loops
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }

  // Real-time stream of cart items
  Stream<QuerySnapshot> getCartStream() {
    return _cartRef.snapshots();
  }

  // Increment Quantity
  Future<void> incrementQuantity(String itemId, int currentQty) async {
    await _cartRef.doc(itemId).update({'qty': currentQty + 1});
  }

  // Decrement Quantity
  Future<void> decrementQuantity(String itemId, int currentQty) async {
    if (currentQty > 1) {
      await _cartRef.doc(itemId).update({'qty': currentQty - 1});
    } else {
      // Remove item if qty becomes 0
      await _cartRef.doc(itemId).delete();
    }
  }

  // Add to cart helper (to be used from Food Detail Screen)
  Future<void> addToCart({
    required String itemId,
    required String name,
    required double price,
    required String stallName,
    required String imageUrl,
  }) async {
    final doc = await _cartRef.doc(itemId).get();
    if (doc.exists) {
      await _cartRef.doc(itemId).update({'qty': FieldValue.increment(1)});
    } else {
      await _cartRef.doc(itemId).set({
        'name': name,
        'price': price,
        'qty': 1,
        'stallName': stallName,
        'imageUrl': imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
