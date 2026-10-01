import 'package:flutter/material.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../services/catalog_service.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_dialogs.dart';
import 'vendor_orders_screen.dart';

class VendorHomeScreen extends StatefulWidget {
  /// Switches the dashboard to the Orders tab.
  final VoidCallback? onOpenOrders;
  const VendorHomeScreen({super.key, this.onOpenOrders});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  final _stall = CatalogService.stallStream(UserService.uid);
  final _orders = OrderService.stallOrders(UserService.uid);

  Future<void> _toggleOpen(StallModel stall) async {
    try {
      await CatalogService.updateStall(stall.id, {'isOpen': !stall.isOpen});
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not update stall. ${friendlyError(e)}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<StallModel?>(
          stream: _stall,
          builder: (context, stallSnapshot) {
            final stall = stallSnapshot.data;
            return StreamBuilder<List<OrderModel>>(
              stream: _orders,
              builder: (context, snapshot) {
                final orders = snapshot.data ?? [];
                final now = DateTime.now();
                final todays = orders.where((o) => isSameDay(o.createdAt ?? now, now) && o.status != OrderStatus.cancelled);
                final todaysSales = todays.fold<double>(0, (total, o) => total + o.subtotal);
                final waiting = orders.where((o) => o.status == OrderStatus.pending).length;
                final incoming = orders
                    .where((o) => [OrderStatus.pending, OrderStatus.preparing, OrderStatus.ready].contains(o.status))
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(greeting(), style: const TextStyle(color: Colors.grey)),
                                Text('${stall?.name ?? 'My stall'} 🏪',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (stall != null) _buildOpenBadge(stall),
                        ],
                      ),
                      if (stall != null && !stall.isApproved) ...[
                        const SizedBox(height: 24),
                        _buildBanner(
                          icon: Icons.hourglass_top,
                          color: Colors.amber,
                          text: stall.status == AccountStatus.suspended
                              ? 'Your stall was not approved. Contact the admin for details.'
                              : 'Your stall is under review. You can build your menu now; customers will see it once an admin approves it.',
                        ),
                      ],
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: widget.onOpenOrders,
                        child: _buildBanner(
                          icon: Icons.notifications_active_outlined,
                          color: Colors.orange,
                          text: waiting == 0 ? 'No orders waiting' : '$waiting order${waiting == 1 ? '' : 's'} waiting',
                          bold: true,
                          showChevron: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Today\'s orders', '${todays.length}')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Today\'s sales', formatPeso(todaysSales, decimals: 0))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Incoming orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (!snapshot.hasData && !snapshot.hasError)
                        const Center(child: CircularProgressIndicator())
                      else if (incoming.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text('No orders yet', style: TextStyle(color: Colors.grey.shade400)),
                          ),
                        )
                      else
                        ...incoming.map((order) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: VendorOrderCard(order: order),
                            )),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOpenBadge(StallModel stall) {
    final color = stall.isOpen ? Colors.green : Colors.grey;
    return GestureDetector(
      onTap: () => _toggleOpen(stall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: stall.isOpen ? Colors.green.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 8),
            Text(stall.isOpen ? 'Stall Open' : 'Stall Closed',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required MaterialColor color,
    required String text,
    bool bold = false,
    bool showChevron = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
          if (showChevron) Icon(Icons.chevron_right, color: color.shade300),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
