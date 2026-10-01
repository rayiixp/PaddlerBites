import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/admin_ui.dart';
import '../services/admin_service.dart';

/// Orders waiting this long for the stall or a rider are flagged as delayed.
const _delayThreshold = Duration(minutes: 15);

bool isOrderDelayed(Map<String, dynamic> order) {
  final status = order['status'];
  final since = status == OrderStatus.pending
      ? toDate(order['createdAt'])
      : status == OrderStatus.ready
          ? toDate(order['readyAt'] ?? order['updatedAt'])
          : null;
  return since != null && DateTime.now().difference(since) > _delayThreshold;
}

// -----------------------------------------------------------------------------
// ORDERS MONITOR
// -----------------------------------------------------------------------------
class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  static const _filters = {
    'All': <String>[],
    'Active': OrderStatus.active,
    'Pending': [OrderStatus.pending],
    'Preparing': [OrderStatus.preparing],
    'Ready': [OrderStatus.ready],
    'In delivery': [OrderStatus.pickedUp, OrderStatus.onTheWay],
    'Delivered': [OrderStatus.delivered],
    'Cancelled': [OrderStatus.cancelled],
  };

  // Newest 300 orders, live.
  final _orders = FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).limit(300).snapshots();
  String _filter = 'Active';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _orders,
      builder: (context, snapshot) {
        final all = snapshot.data?.docs ?? [];
        bool inFilter(String filter, Map<String, dynamic> o) => filter == 'All' || _filters[filter]!.contains(o['status']);
        final counts = {for (final f in _filters.keys) f: all.where((d) => inFilter(f, d.data())).length};
        final docs = all.where((d) {
          final o = d.data();
          if (!inFilter(_filter, o)) return false;
          if (_query.isEmpty) return true;
          return '${d.id} ${o['customerName']} ${o['stallName']} ${o['deliveryPersonName'] ?? ''} ${o['deliveryLocation']}'
              .toLowerCase()
              .contains(_query.replaceAll('#', ''));
        }).toList();

        final todays = all.where((d) => isToday(d.data()['createdAt'])).map((d) => d.data()).toList();
        final awaitingRider =
            all.where((d) => d.data()['status'] == OrderStatus.ready && d.data()['deliveryPersonId'] == null).length;
        final delayed = all.where((d) => isOrderDelayed(d.data())).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Orders',
              subtitle: 'Live across all stalls',
              searchHint: 'Search order #, customer, stall, rider',
              onSearch: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _summary('Active now', '${counts['Active']}', Icons.local_fire_department_outlined),
                const SizedBox(width: 20),
                _summary('Awaiting rider', '$awaitingRider', Icons.kayaking),
                const SizedBox(width: 20),
                _summary('Delivered today', '${todays.where((o) => o['status'] == OrderStatus.delivered).length}',
                    Icons.check_circle_outline),
                const SizedBox(width: 20),
                _summary('Delayed (>15 min)', '$delayed', Icons.warning_amber_rounded, highlight: delayed > 0),
              ],
            ),
            const SizedBox(height: 24),
            FilterChips(options: _filters.keys.toList(), selected: _filter, counts: counts, onSelected: (f) => setState(() => _filter = f)),
            const SizedBox(height: 24),
            Expanded(
              child: AdminCard(
                padding: EdgeInsets.zero,
                child: !snapshot.hasData
                    ? (snapshot.hasError
                        ? EmptyState('Could not load orders: ${snapshot.error}')
                        : const Center(child: CircularProgressIndicator()))
                    : docs.isEmpty
                        ? const EmptyState('No orders in this view.')
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                horizontalMargin: 24,
                                showCheckboxColumn: false,
                                columns: const [
                                  DataColumn(label: Text('ORDER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('PLACED', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('STALL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('RIDER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                ],
                                rows: docs.map((doc) => _buildRow(doc.id, doc.data())).toList(),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summary(String label, String value, IconData icon, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFFF9C4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12)],
        ),
        child: Row(
          children: [
            Icon(icon, color: highlight ? Colors.amber.shade800 : Colors.grey),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(String orderId, Map<String, dynamic> order) {
    final delayed = isOrderDelayed(order);
    return DataRow(
      onSelectChanged: (_) => showOrderDetail(context, orderId),
      cells: [
        DataCell(Row(
          children: [
            Text(shortOrderId(orderId), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (delayed) ...[
              const SizedBox(width: 6),
              Tooltip(message: 'Waiting more than 15 minutes', child: Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade800)),
            ],
          ],
        )),
        DataCell(Text(timeAgo(order['createdAt']))),
        DataCell(Text(order['customerName'] ?? '—')),
        DataCell(Text(order['stallName'] ?? '—')),
        DataCell(Text(order['deliveryPersonName'] ?? '—')),
        DataCell(Text(formatPeso(order['totalPrice']))),
        DataCell(StatusPill(order['status'] ?? OrderStatus.pending)),
      ],
    );
  }
}

/// Live order detail with the admin's cancel action.
void showOrderDetail(BuildContext context, String orderId) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(width: 620, child: _OrderDetail(orderId: orderId)),
    ),
  );
}

class _OrderDetail extends StatefulWidget {
  final String orderId;
  const _OrderDetail({required this.orderId});

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  late final _order = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots();
  bool _isCancelling = false;

  Future<void> _cancel() async {
    final reason = await showAdminConfirm(
      context,
      title: 'Cancel order ${shortOrderId(widget.orderId)}?',
      message: 'The customer, vendor and rider will all see this order as cancelled.',
      confirmText: 'Cancel order',
      isDestructive: true,
      askReason: true,
      reasonHint: 'Reason (e.g. stall ran out of stock)',
    );
    if (reason == null) return;
    setState(() => _isCancelling = true);
    try {
      await AdminService.cancelOrder(widget.orderId, reason);
      if (mounted) showAdminSnackBar(context, 'Order ${shortOrderId(widget.orderId)} cancelled');
    } catch (e) {
      if (mounted) showAdminSnackBar(context, 'Could not cancel: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _order,
      builder: (context, snapshot) {
        final order = snapshot.data?.data();
        if (order == null) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        final status = order['status'] ?? OrderStatus.pending;
        final items = (order['items'] as List?) ?? [];
        final dropoff = order['deliveryPoint'] as GeoPoint?;

        final timeline = <(String, dynamic)>[
          ('Placed', order['createdAt']),
          ('Accepted by stall', order['acceptedAt']),
          ('Ready for pickup', order['readyAt']),
          ('Picked up by rider', order['pickedUpAt']),
          ('On the way', order['departedAt']),
          ('Delivered', order['deliveredAt']),
          ('Cancelled', order['cancelledAt']),
        ].where((e) => e.$2 != null).toList();

        return Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Order ${shortOrderId(widget.orderId)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    StatusPill(status),
                    if (isOrderDelayed(order)) ...[
                      const SizedBox(width: 8),
                      const StatusPill('Delayed'),
                    ],
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                SelectableText(widget.orderId, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                MetaRow('Customer', order['customerName'] ?? '—'),
                MetaRow('Stall', order['stallName'] ?? '—'),
                MetaRow('Rider', order['deliveryPersonName'] ?? 'Not assigned'),
                MetaRow('Deliver to', order['deliveryLocation'] ?? '—'),
                if (dropoff != null)
                  MetaRow('Drop-off pin', '${dropoff.latitude.toStringAsFixed(5)}, ${dropoff.longitude.toStringAsFixed(5)}'),
                MetaRow('Payment', order['paymentMethod'] == 'COD' || order['paymentMethod'] == null ? 'Cash on Delivery' : '${order['paymentMethod']}'),
                if (order['cancelReason'] != null && '${order['cancelReason']}'.isNotEmpty)
                  MetaRow('Cancel reason', '${order['cancelReason']} (by ${order['cancelledBy'] ?? 'unknown'})'),
                const Divider(height: 32),
                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((i) {
                  final item = i is Map ? i : {'name': '$i', 'qty': 1};
                  final qty = (item['qty'] as num?) ?? 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('$qty× ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text('${item['name']}')),
                        if (item['price'] != null) Text(formatPeso((item['price'] as num) * qty)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Row(children: [const Text('Delivery fee'), const Spacer(), Text(formatPeso(order['deliveryFee']))]),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(formatPeso(order['totalPrice']), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 32),
                const Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...timeline.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: e.$1 == 'Cancelled' ? Colors.red : Colors.amber),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.$1)),
                          Text(formatDateTime(e.$2), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )),
                if (OrderStatus.active.contains(status)) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _isCancelling ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel order', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
