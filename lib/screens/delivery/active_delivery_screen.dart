import 'package:flutter/material.dart';
import '../../core/campus_geofence.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../services/rider_location_broadcaster.dart';
import '../../services/user_service.dart';
import '../../widgets/campus_map.dart';
import '../../widgets/custom_dialogs.dart';
import '../../widgets/delivery_tracking_map.dart';
import '../../widgets/order_status_timeline.dart';
import '../../widgets/premium_paddling_boat.dart';
import '../../widgets/tracking_scaffold.dart';
import '../order_chat_screen.dart';

/// Rider's view of one delivery: live map (the rider is the boat), the order
/// timeline, the button that moves the order to its next status, and live
/// GPS sharing to the customer.
///
/// Firebase sync:
/// - reads `orders/{orderId}` in real time (status, drop-off, items);
/// - writes the status through [OrderService.updateStatus] (transactional);
/// - writes GPS to `riderLocation` through [RiderLocationBroadcaster], which
///   the customer's tracking screen streams.
class ActiveDeliveryScreen extends StatefulWidget {
  final String orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> with WidgetsBindingObserver {
  late final Stream<OrderModel?> _order = OrderService.orderStream(widget.orderId);
  late final RiderLocationBroadcaster _gps = RiderLocationBroadcaster(orderId: widget.orderId);
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gps.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gps.dispose();
    super.dispose();
  }

  /// Coming back from Settings: retry if location was off or not allowed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    const blocked = {
      LocationSharingStatus.serviceDisabled,
      LocationSharingStatus.permissionDenied,
      LocationSharingStatus.permissionDeniedForever,
    };
    if (state == AppLifecycleState.resumed && blocked.contains(_gps.status)) _gps.start();
  }

  Future<void> _advance(OrderModel order, String next) async {
    if (next == OrderStatus.delivered) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Mark as delivered?',
        message: 'Confirm you handed over the order and collected ${formatPeso(order.totalPrice)} cash.',
        confirmText: 'Delivered',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _isUpdating = true);
    try {
      await OrderService.updateStatus(order, next);
      if (next == OrderStatus.delivered) await _gps.stop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not update delivery. ${friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OrderModel?>(
      stream: _order,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Message(text: 'Could not load this delivery. ${friendlyError(snapshot.error!)}');
        }
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final order = snapshot.data;
        if (order == null || order.deliveryPersonId != UserService.uid) {
          return const _Message(text: 'This delivery is no longer assigned to you.');
        }

        // Delivered or cancelled elsewhere (e.g. by the admin): stop sharing.
        if (!OrderStatus.riderActive.contains(order.status) && _gps.status != LocationSharingStatus.stopped) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _gps.stop());
        }

        void back() => Navigator.pop(context);
        return TrackingScaffold(
          // The live map has its own top bar with the back button.
          onBack: order.deliveryPoint == null ? back : null,
          collapsedHeight: 300,
          mapBuilder: (context, overlayPadding) => order.deliveryPoint == null
              ? const CampusMap()
              : DeliveryTrackingMap(
                  key: ValueKey(order.id),
                  viewer: TrackingViewer.rider,
                  dropoff: CampusGeofence.fromGeoPoint(order.deliveryPoint)!,
                  pickup: CampusGeofence.fromGeoPoint(order.pickupPoint),
                  driverLocations: _gps.positions,
                  initialDriverLocation: _gps.lastPosition ?? CampusGeofence.fromGeoPoint(order.riderLocation),
                  riderName: 'You',
                  initialCenter: CampusGeofence.focus,
                  maxZoom: 21,
                  overlayPadding: overlayPadding,
                  onBack: back,
                ),
          cardChildren: (context) => _card(order),
        );
      },
    );
  }

  (String, String) _headline(OrderModel order) => switch (order.status) {
        OrderStatus.pickedUp => ('Picked up from ${order.stallName}', 'Start the trip when you head out'),
        OrderStatus.onTheWay => ('On the way', 'Deliver to ${order.deliveryLocation}'),
        OrderStatus.delivered => ('Delivered', 'Collected ${formatPeso(order.totalPrice)}. Great job!'),
        OrderStatus.cancelled => ('Cancelled', order.cancelReason.isEmpty ? 'This order was cancelled' : order.cancelReason),
        _ => (order.status, 'Waiting for the stall'),
      };

  List<Widget> _card(OrderModel order) {
    final (label, headline) = _headline(order);
    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: order.status == OrderStatus.cancelled ? Colors.red : Colors.grey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
      if (order.status != OrderStatus.cancelled) OrderStatusTimeline(status: order.status),
      const SizedBox(height: 16),
      _actionButton(order),
      const SizedBox(height: 8),
      ListenableBuilder(listenable: _gps, builder: (context, _) => _LocationSharingRow(gps: _gps)),
      Divider(color: Colors.grey.shade200),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: AppTheme.backgroundColor, child: Icon(Icons.person, color: Colors.black87)),
        title: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(order.deliveryLocation),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Collect', style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text(formatPeso(order.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
              ],
            ),
            // Message the customer (directions, "I'm here", change notes…).
            if (OrderStatus.riderActive.contains(order.status)) ...[
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Chat with ${order.customerName}',
                onPressed: () => OrderChatScreen.open(context, order.id),
                style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
              ),
            ],
          ],
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: Color(0xFF0D3B2E), child: Icon(Icons.storefront, color: AppTheme.primaryColor)),
        title: Text('Pick up at ${order.stallName}'),
        subtitle: Text(order.itemsSummary),
      ),
    ];
  }

  /// The one action that moves the order forward from the rider's side.
  Widget _actionButton(OrderModel order) {
    final (String label, String? next) = switch (order.status) {
      OrderStatus.pickedUp => ('Start delivery', OrderStatus.onTheWay),
      OrderStatus.onTheWay => ('Mark as delivered', OrderStatus.delivered),
      _ => ('Back to jobs', null),
    };
    return ElevatedButton(
      onPressed: _isUpdating ? null : (next == null ? () => Navigator.pop(context) : () => _advance(order, next)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: next == null ? Colors.grey.shade300 : AppTheme.primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: _isUpdating
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
    );
  }
}

/// Live-location status with a one-tap fix when sharing is blocked.
class _LocationSharingRow extends StatelessWidget {
  final RiderLocationBroadcaster gps;
  const _LocationSharingRow({required this.gps});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text, String? action, VoidCallback? onAction) = switch (gps.status) {
      LocationSharingStatus.sharing => (
          Icons.my_location,
          Colors.green,
          gps.publishFailing ? 'Live location: reconnecting…' : 'Sharing live location with the customer',
          null,
          null,
        ),
      LocationSharingStatus.starting => (Icons.location_searching, Colors.grey, 'Turning on location…', null, null),
      LocationSharingStatus.serviceDisabled => (Icons.location_off, Colors.red, 'Location is turned off', 'Turn on', gps.openSettings),
      LocationSharingStatus.permissionDenied => (Icons.location_off, Colors.red, 'Location permission needed', 'Allow', gps.start),
      LocationSharingStatus.permissionDeniedForever => (Icons.location_off, Colors.red, 'Location is blocked for PaddlerBites', 'Settings', gps.openSettings),
      LocationSharingStatus.stopped => (Icons.location_disabled, Colors.grey, 'Location sharing ended', null, null),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color == Colors.grey ? Colors.grey : Colors.black87))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PremiumPaddlingBoatAnimation(size: 72, animate: false),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
