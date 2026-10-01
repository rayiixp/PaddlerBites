import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../core/campus_geofence.dart';
import '../models/models.dart';

/// Thrown when an order action is refused; [message] is shown to the user.
class OrderException implements Exception {
  final String message;
  OrderException(this.message);
  @override
  String toString() => message;
}

class OrderService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  // --------------------------------------------------------------- Streams
  // Queries use a single equality filter and are sorted on the device, so no
  // composite Firestore indexes are needed.

  static List<OrderModel> _newestFirst(QuerySnapshot snap) {
    final orders = snap.docs.map(OrderModel.fromDoc).toList();
    orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return orders;
  }

  static Stream<OrderModel?> orderStream(String orderId) =>
      _orders.doc(orderId).snapshots().map((doc) => doc.exists ? OrderModel.fromDoc(doc) : null);

  static Stream<List<OrderModel>> customerOrders(String customerId) =>
      _orders.where('customerId', isEqualTo: customerId).snapshots().map(_newestFirst);

  static Stream<List<OrderModel>> stallOrders(String stallId) =>
      _orders.where('stallId', isEqualTo: stallId).snapshots().map(_newestFirst);

  static Stream<List<OrderModel>> riderOrders(String riderId) =>
      _orders.where('deliveryPersonId', isEqualTo: riderId).snapshots().map(_newestFirst);

  /// Orders the stall has marked ready and no rider has claimed yet, oldest first.
  static Stream<List<OrderModel>> availableDeliveries() {
    return _orders.where('status', isEqualTo: OrderStatus.ready).snapshots().map((snap) {
      final orders = _newestFirst(snap).where((o) => o.deliveryPersonId == null).toList();
      return orders.reversed.toList();
    });
  }

  // ------------------------------------------------------------- Customer

  /// Turns the cart into one order per stall, re-checking stall status, item
  /// availability and current prices. Returns the new order ids.
  static Future<List<String>> placeOrders({
    required List<QueryDocumentSnapshot> cartDocs,
    required String customerId,
    required String customerName,
    required String deliveryLocation,
    required LatLng deliveryPoint,
  }) async {
    if (cartDocs.isEmpty) throw OrderException('Your cart is empty.');
    if (deliveryLocation.trim().isEmpty) throw OrderException('Please enter the building / room for the rider.');
    if (deliveryLocation.length > 120) throw OrderException('Please keep the building / room note under 120 characters.');
    if (!CampusGeofence.contains(deliveryPoint)) {
      throw OrderException('Drop-off pin must be inside the CSU Cabadbaran campus.');
    }

    final byStall = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in cartDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final stallId = data['stallId'] as String?;
      if (stallId == null || stallId.isEmpty) {
        throw OrderException('"${data['name']}" is out of date. Remove it from your cart and add it again.');
      }
      byStall.putIfAbsent(stallId, () => []).add(doc);
    }

    final batch = _db.batch();
    final orderIds = <String>[];

    for (final entry in byStall.entries) {
      final stallDoc = await _db.collection('stalls').doc(entry.key).get();
      if (!stallDoc.exists) throw OrderException('A stall in your cart no longer exists.');
      final stall = StallModel.fromDoc(stallDoc);
      if (!stall.isApproved || !stall.isOpen) throw OrderException('${stall.name} is closed right now.');

      final items = <OrderItem>[];
      for (final cartDoc in entry.value) {
        final cartData = cartDoc.data() as Map<String, dynamic>;
        final itemDoc = await _db.collection('menuItems').doc(cartDoc.id).get();
        final item = itemDoc.exists ? FoodModel.fromDoc(itemDoc) : null;
        if (item == null || !item.isAvailable) {
          throw OrderException('${cartData['name']} is sold out. Remove it from your cart to continue.');
        }
        final qty = (cartData['qty'] as num?)?.toInt() ?? 0;
        if (qty < 1) throw OrderException('Please set a quantity for ${item.name}.');
        items.add(OrderItem(
          itemId: item.id,
          name: item.name,
          price: item.price,
          qty: qty,
          imageUrl: item.imageUrl,
        ));
      }

      final subtotal = items.fold<double>(0, (total, i) => total + i.price * i.qty);
      final ref = _orders.doc();
      orderIds.add(ref.id);
      batch.set(ref, {
        'customerId': customerId,
        'customerName': customerName,
        'stallId': stall.id,
        'stallName': stall.name,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'deliveryFee': kDeliveryFee,
        'totalPrice': subtotal + kDeliveryFee,
        'paymentMethod': 'COD',
        'status': OrderStatus.pending,
        'deliveryLocation': deliveryLocation,
        'deliveryPoint': CampusGeofence.toGeoPoint(deliveryPoint),
        'pickupPoint': stall.pickupPoint,
        'deliveryPersonId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    for (final doc in cartDocs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return orderIds;
  }

  static Future<void> cancelByCustomer(String orderId) {
    return _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final snap = await tx.get(ref);
      if (snap.data()?['status'] != OrderStatus.pending) {
        throw OrderException('The stall has already accepted this order.');
      }
      tx.update(ref, _statusUpdate(OrderStatus.cancelled));
    });
  }

  // --------------------------------------------------------- Vendor/rider

  static Map<String, dynamic> _statusUpdate(String status) {
    const timestampField = {
      OrderStatus.preparing: 'acceptedAt',
      OrderStatus.ready: 'readyAt',
      OrderStatus.pickedUp: 'pickedUpAt',
      OrderStatus.onTheWay: 'departedAt',
      OrderStatus.delivered: 'deliveredAt',
      OrderStatus.cancelled: 'cancelledAt',
    };
    return {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (timestampField[status] != null) timestampField[status]!: FieldValue.serverTimestamp(),
    };
  }

  /// Which status each step may move to. Anything else means someone else
  /// already changed the order (e.g. the customer cancelled it).
  static const Map<String, List<String>> _allowedNext = {
    OrderStatus.pending: [OrderStatus.preparing, OrderStatus.cancelled],
    OrderStatus.preparing: [OrderStatus.ready],
    OrderStatus.pickedUp: [OrderStatus.onTheWay],
    OrderStatus.onTheWay: [OrderStatus.delivered],
  };

  /// Moves an order to [status] inside a transaction, re-reading the latest
  /// status first so stale screens and double taps can't overwrite it.
  static Future<void> updateStatus(OrderModel order, String status) {
    return _db.runTransaction((tx) async {
      final ref = _orders.doc(order.id);
      final snap = await tx.get(ref);
      final current = snap.data()?['status'] as String?;
      if (current == null) throw OrderException('This order no longer exists.');
      if (current == status) return; // already done (e.g. a double tap)
      if (!(_allowedNext[current] ?? const []).contains(status)) {
        throw OrderException('This order is already "$current" and can no longer be changed to "$status".');
      }
      tx.update(ref, _statusUpdate(status));
      if (status == OrderStatus.delivered && order.stallId.isNotEmpty) {
        tx.update(_db.collection('stalls').doc(order.stallId), {'totalOrders': FieldValue.increment(1)});
      }
    });
  }

  /// Claims a ready order for [riderId]. Fails if another rider got it first.
  static Future<void> acceptDelivery({required String orderId, required String riderId, required String riderName}) {
    return _db.runTransaction((tx) async {
      final ref = _orders.doc(orderId);
      final data = (await tx.get(ref)).data();
      if (data == null || data['status'] != OrderStatus.ready || data['deliveryPersonId'] != null) {
        throw OrderException('Another rider already accepted this delivery.');
      }
      tx.update(ref, {
        ..._statusUpdate(OrderStatus.pickedUp),
        'deliveryPersonId': riderId,
        'deliveryPersonName': riderName,
      });
    });
  }

  /// Customer's 1–5 star rating of a delivered order.
  static Future<void> rateOrder(String orderId, int rating) {
    if (rating < 1 || rating > 5) throw OrderException('Please choose 1 to 5 stars.');
    return _orders.doc(orderId).update({'customerRating': rating, 'ratedAt': FieldValue.serverTimestamp()});
  }

  /// Customer-reported problem with a delivered order, kept on the order for the admin.
  static Future<void> reportIssue(String orderId, String message) {
    if (message.trim().isEmpty) throw OrderException('Please describe the issue.');
    return _orders.doc(orderId).update({
      'issueReport': {'message': message.trim(), 'reportedAt': FieldValue.serverTimestamp()},
    });
  }

  static Future<void> updateRiderLocation(String orderId, double latitude, double longitude) {
    return _orders.doc(orderId).update({
      'riderLocation': GeoPoint(latitude, longitude),
      'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
