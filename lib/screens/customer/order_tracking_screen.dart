import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/errors.dart';
import '../../core/campus_geofence.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/campus_map.dart';
import '../../widgets/custom_dialogs.dart';
import '../../widgets/delivery_tracking_map.dart';
import '../../widgets/order_status_timeline.dart';
import '../../widgets/premium_paddling_boat.dart';
import '../../widgets/tracking_scaffold.dart';
import '../order_chat_screen.dart';

/// Tracks the order whose id is passed as the route argument, or the
/// customer's most recent active order when opened without one.
///
/// This widget only wires Firebase into [DeliveryTrackingView]:
/// - order status  → `orders/{id}` snapshots
/// - rider GPS     → the order's `riderLocation`, written by the rider app
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late final String? _orderId = ModalRoute.of(context)!.settings.arguments as String?;

  // Broadcast: the sheet and the rider feed both listen to the same query.
  late final Stream<OrderModel?> _order = (_orderId != null
          ? OrderService.orderStream(_orderId)
          : OrderService.customerOrders(UserService.uid).map((orders) {
              final active = orders.where((o) => o.isActive);
              return active.isEmpty ? null : active.first;
            }))
      .asBroadcastStream();

  /// Live rider position while the rider has the order (Picked up / On the way).
  late final Stream<LatLng> _riderLocations = _order
      .map((o) => o != null && OrderStatus.riderActive.contains(o.status) ? CampusGeofence.fromGeoPoint(o.riderLocation) : null)
      .where((p) => p != null)
      .cast<LatLng>();

  Future<void> _cancel(OrderModel order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel this order?',
      message: 'You can cancel until ${order.stallName} accepts it.',
      confirmText: 'Cancel order',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await OrderService.cancelByCustomer(order.id);
    } catch (e) {
      if (mounted) showAppSnackBar(context, friendlyError(e), isError: true);
    }
  }

  void _chatWithRider(OrderModel order) => OrderChatScreen.open(context, order.id);

  @override
  Widget build(BuildContext context) {
    return DeliveryTrackingView(
      orderUpdates: _order,
      riderLocations: _riderLocations,
      onCancelOrder: _cancel,
      onChatWithRider: _chatWithRider,
      onBack: () => Navigator.pop(context),
    );
  }
}

/// Customer's live delivery tracking UI: satellite map with the rider's boat
/// on top, draggable order card with the paddling-boat timeline below.
///
/// Feed it any data source:
/// - [orderUpdates]: emits the order whenever its status changes (null = no order)
/// - [riderLocations]: emits the rider's GPS position as it moves
class DeliveryTrackingView extends StatelessWidget {
  final Stream<OrderModel?> orderUpdates;
  final Stream<LatLng> riderLocations;
  final Future<void> Function(OrderModel order)? onCancelOrder;

  /// Opens a chat with the order's rider (shown once a rider is assigned).
  final void Function(OrderModel order)? onChatWithRider;
  final VoidCallback? onBack;

  const DeliveryTrackingView({
    super.key,
    required this.orderUpdates,
    required this.riderLocations,
    this.onCancelOrder,
    this.onChatWithRider,
    this.onBack,
  });

  /// The stall hasn't accepted yet: the only stage the customer can cancel
  /// in (OrderService.cancelByCustomer enforces the same rule).
  static bool canCancel(OrderModel order) => order.status == OrderStatus.pending;

  /// Finished orders have nothing to cancel, so the button disappears.
  static bool showsCancelButton(OrderModel order) =>
      order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled;

  static bool canChat(OrderModel order) => order.deliveryPersonId != null && order.isActive;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OrderModel?>(
      stream: orderUpdates,
      builder: (context, snapshot) {
        final order = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting && order == null;
        final hasLiveMap = order?.deliveryPoint != null;
        return TrackingScaffold(
          // The live map has its own top bar with the back button.
          onBack: hasLiveMap ? null : onBack,
          mapBuilder: (context, overlayPadding) => !hasLiveMap
              ? const CampusMap()
              : DeliveryTrackingMap(
                  key: ValueKey(order!.id), // new order → fresh trail
                  dropoff: CampusGeofence.fromGeoPoint(order.deliveryPoint)!,
                  pickup: CampusGeofence.fromGeoPoint(order.pickupPoint),
                  driverLocations: riderLocations,
                  initialDriverLocation: OrderStatus.riderActive.contains(order.status)
                      ? CampusGeofence.fromGeoPoint(order.riderLocation)
                      : null,
                  riderName: order.deliveryPersonName ?? 'Your rider',
                  initialCenter: CampusGeofence.focus,
                  maxZoom: 21,
                  overlayPadding: overlayPadding,
                  onBack: onBack,
                ),
          cardChildren: (context) => order == null
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      isLoading ? 'Finding your active order…' : 'You have no active orders.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                ]
              : _orderDetails(order),
        );
      },
    );
  }

  (String, String) _statusHeadline(OrderModel order) {
    switch (order.status) {
      case OrderStatus.pending:
        return ('Order placed', 'Waiting for the stall to accept');
      case OrderStatus.preparing:
        return ('Being prepared', 'The stall is cooking your order');
      case OrderStatus.ready:
        return ('Ready for pickup', 'Looking for a rider');
      case OrderStatus.pickedUp:
        return ('Picked up', 'Your rider has your food');
      case OrderStatus.onTheWay:
        return ('On the way', 'Arriving in 5–10 min');
      case OrderStatus.delivered:
        return ('Delivered', 'Enjoy your meal!');
      default:
        return ('Order cancelled', order.cancelReason.isNotEmpty ? order.cancelReason : 'This order will not be delivered');
    }
  }

  List<Widget> _orderDetails(OrderModel order) {
    final (label, headline) = _statusHeadline(order);
    final isCancelled = order.status == OrderStatus.cancelled;

    return [
      // Status headline
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isCancelled ? Colors.red : Colors.grey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(headline, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
            child: Text(order.shortId, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (isCancelled)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red),
              SizedBox(width: 10),
              Expanded(child: Text('This order was cancelled.')),
            ],
          ),
        )
      else
        OrderStatusTimeline(status: order.status),
      const SizedBox(height: 16),
      Divider(color: Colors.grey.shade200),
      ListTile(
        contentPadding: EdgeInsets.zero,
        // The rider is the PaddlerBites boat, paddling while en route.
        leading: PremiumPaddlingBoatAnimation(size: 40, animate: OrderStatus.riderActive.contains(order.status)),
        title: Text(order.deliveryPersonName ?? 'Searching for rider…', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('From ${order.stallName}'),
        trailing: onChatWithRider != null && canChat(order)
            ? IconButton.filled(
                tooltip: 'Chat with ${order.deliveryPersonName ?? 'your rider'}',
                onPressed: () => onChatWithRider!(order),
                style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
              )
            : null,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: AppTheme.backgroundColor, child: Icon(Icons.location_on, color: AppTheme.secondaryColor)),
        title: const Text('Delivering to'),
        subtitle: Text(order.deliveryLocation),
      ),
      Divider(color: Colors.grey.shade200),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(order.itemsSummary, style: const TextStyle(color: Colors.black87)),
      ),
      SummaryRow(label: 'Delivery fee', value: formatPeso(order.deliveryFee)),
      SummaryRow(label: 'Total (Cash on Delivery)', value: formatPeso(order.totalPrice), isTotal: true),
      if (onCancelOrder != null && showsCancelButton(order)) ...[
        const SizedBox(height: 16),
        OutlinedButton(
          // Disabled (greyed out) once the stall has accepted the order.
          onPressed: canCancel(order) ? () => onCancelOrder!(order) : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            side: BorderSide(color: canCancel(order) ? Colors.red.shade200 : Colors.grey.shade300),
          ),
          child: Text(
            'Cancel order',
            style: TextStyle(color: canCancel(order) ? Colors.red : Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        if (!canCancel(order)) ...[
          const SizedBox(height: 6),
          Text(
            OrderStatus.riderActive.contains(order.status)
                ? "Your food is already with the rider, so it can't be cancelled."
                : "${order.stallName} has started on your order, so it can't be cancelled.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ],
    ];
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const SummaryRow({super.key, required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The label wraps instead of pushing the amount off screen (large text).
          Flexible(child: Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal))),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
