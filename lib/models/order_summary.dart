import 'models.dart';

/// One line of an order, e.g. "1x Burger".
class OrderLine {
  final String itemId;
  final String name;
  final int qty;

  const OrderLine({required this.itemId, required this.name, required this.qty});

  @override
  String toString() => '${qty}x $name';
}

/// What the My Orders screen needs to draw an [OrderCard]. Built from a live
/// Firestore [OrderModel] with [Order.fromModel], or from [Order.samples] to
/// preview the UI without a backend.
class Order {
  final String id;
  final String stallId;
  final String stallName;
  final String status;
  final DateTime? placedAt;
  final List<OrderLine> items;
  final double total;

  /// 1–5 stars once the customer rated the order; 0 = not rated.
  final int rating;

  const Order({
    required this.id,
    required this.stallId,
    required this.stallName,
    required this.status,
    required this.placedAt,
    required this.items,
    required this.total,
    this.rating = 0,
  });

  factory Order.fromModel(OrderModel model) => Order(
        id: model.id,
        stallId: model.stallId,
        stallName: model.stallName,
        status: model.status,
        placedAt: model.createdAt,
        items: model.items.map((i) => OrderLine(itemId: i.itemId, name: i.name, qty: i.qty)).toList(),
        total: model.totalPrice,
        rating: model.customerRating,
      );

  String get shortId => '#${id.substring(0, id.length < 4 ? id.length : 4).toUpperCase()}';

  /// "1x Burger, 2x Fries"
  String get summary => items.isEmpty ? 'No items' : items.join(', ');

  bool get isActive => OrderStatus.active.contains(status);
  bool get isDelivered => status == OrderStatus.delivered;
  bool get isCancelled => status == OrderStatus.cancelled;

  /// Dummy orders covering every tab and button state.
  static List<Order> get samples {
    final now = DateTime.now();
    return [
      Order(
        id: 'a1b2c3', stallId: '', stallName: 'Snackpreneurs', status: OrderStatus.onTheWay,
        placedAt: now.subtract(const Duration(minutes: 12)),
        items: const [OrderLine(itemId: '', name: 'Cheese Burger', qty: 1), OrderLine(itemId: '', name: 'Fries', qty: 1)],
        total: 80,
      ),
      Order(
        id: 'd4e5f6', stallId: '', stallName: 'Taste Venture', status: OrderStatus.pending,
        placedAt: now.subtract(const Duration(minutes: 3)),
        items: const [OrderLine(itemId: '', name: 'Spaghetti', qty: 2)],
        total: 155,
      ),
      Order(
        id: 'g7h8i9', stallId: '', stallName: 'Food Foundry', status: OrderStatus.pickedUp,
        placedAt: now.subtract(const Duration(minutes: 20)),
        items: const [OrderLine(itemId: '', name: 'Fried Chicken', qty: 1)],
        total: 65,
      ),
      Order(
        id: 'j1k2l3', stallId: '', stallName: 'Snackpreneurs', status: OrderStatus.delivered,
        placedAt: now.subtract(const Duration(days: 1, hours: 2)),
        items: const [OrderLine(itemId: '', name: 'Burger', qty: 1)],
        total: 46,
      ),
      Order(
        id: 'm4n5o6', stallId: '', stallName: 'Taste Venture', status: OrderStatus.delivered,
        placedAt: now.subtract(const Duration(days: 3)),
        items: const [OrderLine(itemId: '', name: 'Chocolate Cake', qty: 1), OrderLine(itemId: '', name: 'Orange Juice', qty: 2)],
        total: 135,
        rating: 5,
      ),
      Order(
        id: 'p7q8r9', stallId: '', stallName: 'Food Foundry', status: OrderStatus.cancelled,
        placedAt: now.subtract(const Duration(days: 2)),
        items: const [OrderLine(itemId: '', name: 'Banana Cue', qty: 3)],
        total: 45,
      ),
    ];
  }
}
