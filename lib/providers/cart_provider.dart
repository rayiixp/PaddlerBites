import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

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

  // Add to cart; the cart doc id is the menu item id so repeats stack up
  Future<void> addToCart(FoodModel food, {int qty = 1}) async {
    final doc = await _cartRef.doc(food.id).get();
    if (doc.exists) {
      await _cartRef.doc(food.id).update({'qty': FieldValue.increment(qty), 'price': food.price});
    } else {
      await _cartRef.doc(food.id).set({
        'name': food.name,
        'price': food.price,
        'qty': qty,
        'stallId': food.stallId,
        'stallName': food.stallName,
        'imageUrl': food.imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
