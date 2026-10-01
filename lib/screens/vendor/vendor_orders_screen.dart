import 'package:flutter/material.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_dialogs.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final _orders = OrderService.stallOrders(UserService.uid);
  int _activeTab = 0;

  static const _tabStatuses = [
    [OrderStatus.pending],
    [OrderStatus.preparing],
    [OrderStatus.ready],
    [OrderStatus.pickedUp, OrderStatus.onTheWay, OrderStatus.delivered, OrderStatus.cancelled],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<OrderModel>>(
          stream: _orders,
          builder: (context, snapshot) {
            final allOrders = snapshot.data ?? [];
            int count(int tab) => allOrders.where((o) => _tabStatuses[tab].contains(o.status)).length;
            final tabs = ['New (${count(0)})', 'Preparing (${count(1)})', 'Ready (${count(2)})', 'Done'];
            final orders = allOrders.where((o) => _tabStatuses[_activeTab].contains(o.status)).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Text('Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(tabs.length, (index) {
                      bool isSelected = _activeTab == index;
                      return GestureDetector(
                        onTap: () => setState(() => _activeTab = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tabs[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(child: _buildList(snapshot, orders)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(AsyncSnapshot<List<OrderModel>> snapshot, List<OrderModel> orders) {
    if (snapshot.hasError) {
      return Center(child: Text('Could not load orders: ${snapshot.error}'));
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return Center(child: Text('No orders here yet', style: TextStyle(color: Colors.grey.shade400)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: orders.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: VendorOrderCard(order: orders[index]),
      ),
    );
  }
}

/// Order card with the vendor's next action (accept/reject, mark as ready).
class VendorOrderCard extends StatefulWidget {
  final OrderModel order;
  const VendorOrderCard({super.key, required this.order});

  @override
  State<VendorOrderCard> createState() => _VendorOrderCardState();
}

class _VendorOrderCardState extends State<VendorOrderCard> {
  bool _isBusy = false;

  OrderModel get order => widget.order;

  Future<void> _setStatus(String status) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    await runGuarded(context, () => OrderService.updateStatus(order, status), errorPrefix: 'Could not update order.');
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _reject() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reject order ${order.shortId}?',
      message: 'The customer will see that the order was cancelled.',
      confirmText: 'Reject',
      isDestructive: true,
    );
    if (confirmed && mounted) await _setStatus(OrderStatus.cancelled);
  }

  Widget _label(String text, {Color color = Colors.black}) => _isBusy
      ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
      : Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold));

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderStatus.color(order.status);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order ${order.shortId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(order.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${order.customerName} · ${timeAgo(order.createdAt)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Text(order.itemsSummary, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Deliver to', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(order.deliveryLocation,
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(order.paymentMethod == 'COD' ? 'Cash on delivery' : order.paymentMethod,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Spacer(),
              Text(formatPeso(order.subtotal),
                  style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          if (order.status == OrderStatus.pending) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _label('Reject', color: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isBusy ? null : () => _setStatus(OrderStatus.preparing),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _label('Accept order'),
                  ),
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.preparing) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isBusy ? null : () => _setStatus(OrderStatus.ready),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _label('Mark as ready'),
            ),
          ],
          if (order.status == OrderStatus.ready) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.hourglass_top, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                const Text('Waiting for a rider to pick up', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
          if (order.deliveryPersonName != null && order.status != OrderStatus.ready) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.kayaking, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('Rider: ${order.deliveryPersonName}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
