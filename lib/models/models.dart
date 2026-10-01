import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Menu categories shared by the vendor menu form and the customer filters.
const List<String> kMenuCategories = ['Meals', 'Snacks', 'Drinks', 'Desserts'];

/// Flat delivery fee charged per stall order.
const double kDeliveryFee = 15.0;

/// Values of `users/{uid}.status` and `stalls/{id}.status`, set by the admin.
class AccountStatus {
  static const active = 'Active';
  static const pending = 'Pending Review';
  static const suspended = 'Suspended';
}

double _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;

/// `stalls/{stallId}` — the stall id is the owning vendor's uid.
class StallModel {
  final String id;
  final String name;
  final String program;
  final String category;
  final String operatingHours;
  final double rating;
  final String imageUrl;
  final String imagePath;
  final bool isOpen;
  final String status;
  final GeoPoint? pickupPoint;
  final String payoutAccount;

  StallModel({
    required this.id,
    required this.name,
    this.program = '',
    this.category = '',
    this.operatingHours = '',
    this.rating = 0,
    this.imageUrl = '',
    this.imagePath = '',
    this.isOpen = false,
    this.status = AccountStatus.active,
    this.pickupPoint,
    this.payoutAccount = '',
  });

  /// Only admin-approved stalls are shown to customers.
  bool get isApproved => status == AccountStatus.active;

  /// Background behind stall logos when no photo is uploaded.
  Color get bgColor => const Color(0xFF0D3B2E);

  factory StallModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return StallModel(
      id: doc.id,
      name: data['stallName'] ?? 'Unnamed stall',
      program: data['program'] ?? '',
      category: data['category'] ?? '',
      operatingHours: data['operatingHours'] ?? '',
      rating: _toDouble(data['rating']),
      imageUrl: data['imageUrl'] ?? '',
      imagePath: data['imagePath'] ?? '',
      isOpen: data['isOpen'] ?? false,
      // Stalls created before approvals existed have no status; treat them as approved.
      status: data['status'] ?? AccountStatus.active,
      pickupPoint: data['pickupPoint'] as GeoPoint?,
      payoutAccount: data['payoutAccount'] ?? '',
    );
  }
}

/// `menuItems/{itemId}` — one document per item, linked to its stall by `stallId`.
class FoodModel {
  final String id;
  final String stallId;
  final String name;
  final String stallName;
  final String description;
  final double price;
  final double rating;
  final String imageUrl;
  final String imagePath;
  final String category;
  final bool isAvailable;

  FoodModel({
    required this.id,
    required this.stallId,
    required this.name,
    required this.stallName,
    required this.price,
    this.description = '',
    this.rating = 0,
    this.imageUrl = '',
    this.imagePath = '',
    this.category = '',
    this.isAvailable = true,
  });

  String get ratingLabel => rating > 0 ? rating.toStringAsFixed(1) : 'New';

  factory FoodModel.fromDoc(DocumentSnapshot doc) => FoodModel.fromMap(doc.id, (doc.data() as Map<String, dynamic>?) ?? {});

  factory FoodModel.fromMap(String id, Map<String, dynamic> data) {
    return FoodModel(
      id: id,
      stallId: data['stallId'] ?? '',
      name: data['name'] ?? 'Unnamed item',
      stallName: data['stallName'] ?? '',
      description: data['description'] ?? '',
      price: _toDouble(data['price']),
      rating: _toDouble(data['rating']),
      imageUrl: data['imageUrl'] ?? '',
      imagePath: data['imagePath'] ?? '',
      category: data['category'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  /// Copy stored in a customer's wishlist / recently viewed lists.
  Map<String, dynamic> toSnapshotMap() => {
        'stallId': stallId,
        'name': name,
        'stallName': stallName,
        'description': description,
        'price': price,
        'rating': rating,
        'imageUrl': imageUrl,
        'category': category,
      };
}

/// Order lifecycle: Pending → Preparing → Ready → Picked up → On the way → Delivered.
class OrderStatus {
  static const pending = 'Pending';
  static const preparing = 'Preparing';
  static const ready = 'Ready';
  static const pickedUp = 'Picked up';
  static const onTheWay = 'On the way';
  static const delivered = 'Delivered';
  static const cancelled = 'Cancelled';

  static const active = [pending, preparing, ready, pickedUp, onTheWay];
  static const riderActive = [pickedUp, onTheWay];

  static Color color(String status) {
    switch (status) {
      case preparing:
        return Colors.blue;
      case ready:
        return Colors.green;
      case pickedUp:
      case onTheWay:
        return Colors.purple;
      case delivered:
        return Colors.teal;
      case cancelled:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

class OrderItem {
  final String itemId;
  final String name;
  final double price;
  final int qty;
  final String imageUrl;

  OrderItem({required this.itemId, required this.name, required this.price, required this.qty, this.imageUrl = ''});

  factory OrderItem.fromValue(dynamic value) {
    // Early test orders stored items as plain names.
    if (value is String) return OrderItem(itemId: '', name: value, price: 0, qty: 1);
    final data = value as Map<String, dynamic>;
    return OrderItem(
      itemId: data['itemId'] ?? '',
      name: data['name'] ?? 'Item',
      price: _toDouble(data['price']),
      qty: (data['qty'] as num?)?.toInt() ?? 1,
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'itemId': itemId, 'name': name, 'price': price, 'qty': qty, 'imageUrl': imageUrl};
}

/// `orders/{orderId}` — one order per stall.
class OrderModel {
  final String id;
  final String status;
  final String customerId;
  final String customerName;
  final String stallId;
  final String stallName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double totalPrice;
  final String paymentMethod;
  final String deliveryLocation;
  final GeoPoint? deliveryPoint;
  final GeoPoint? pickupPoint;
  final GeoPoint? riderLocation;
  final String? deliveryPersonId;
  final String? deliveryPersonName;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final String cancelReason;

  /// 1–5 stars from the customer after delivery; 0 = not rated yet.
  final int customerRating;

  OrderModel({
    required this.id,
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.stallId,
    required this.stallName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalPrice,
    required this.paymentMethod,
    required this.deliveryLocation,
    this.deliveryPoint,
    this.pickupPoint,
    this.riderLocation,
    this.deliveryPersonId,
    this.deliveryPersonName,
    this.createdAt,
    this.deliveredAt,
    this.cancelReason = '',
    this.customerRating = 0,
  });

  String get shortId => '#${id.substring(0, id.length < 4 ? id.length : 4).toUpperCase()}';

  bool get isActive => OrderStatus.active.contains(status);

  int get itemCount => items.fold(0, (total, item) => total + item.qty);

  String get itemsSummary => items.isEmpty ? 'No items' : items.map((i) => '${i.qty}× ${i.name}').join(', ');

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return OrderModel(
      id: doc.id,
      status: data['status'] ?? OrderStatus.pending,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? 'Customer',
      stallId: data['stallId'] ?? '',
      stallName: data['stallName'] ?? 'Campus Stall',
      items: ((data['items'] as List?) ?? []).map(OrderItem.fromValue).toList(),
      subtotal: _toDouble(data['subtotal'] ?? data['totalPrice']),
      deliveryFee: _toDouble(data['deliveryFee'] ?? kDeliveryFee),
      totalPrice: _toDouble(data['totalPrice']),
      paymentMethod: data['paymentMethod'] ?? 'COD',
      deliveryLocation: data['deliveryLocation'] ?? 'CSU Cabadbaran Campus',
      deliveryPoint: data['deliveryPoint'] as GeoPoint?,
      pickupPoint: data['pickupPoint'] as GeoPoint?,
      riderLocation: data['riderLocation'] as GeoPoint?,
      deliveryPersonId: data['deliveryPersonId'],
      deliveryPersonName: data['deliveryPersonName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      cancelReason: data['cancelReason'] ?? '',
      customerRating: (data['customerRating'] as num?)?.toInt() ?? 0,
    );
  }
}
