import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/admin_ui.dart';
import '../core/user_roles.dart';
import 'orders_view.dart';

// -----------------------------------------------------------------------------
// 2. DASHBOARD OVERVIEW VIEW
// -----------------------------------------------------------------------------
class DashboardOverviewView extends StatefulWidget {
  /// Opens the Users tab on the pending queue for 'Delivery' or 'Vendors'.
  final void Function(String roleSegment) onReviewApplications;
  final VoidCallback onOpenOrders;

  const DashboardOverviewView({super.key, required this.onReviewApplications, required this.onOpenOrders});

  @override
  State<DashboardOverviewView> createState() => _DashboardOverviewViewState();
}

class _DashboardOverviewViewState extends State<DashboardOverviewView> {
  final _db = FirebaseFirestore.instance;
  late final _recentOrders = _db.collection('orders').orderBy('createdAt', descending: true).limit(200).snapshots();
  late final _stalls = _db.collection('stalls').snapshots();
  // Per-role statuses (and legacy documents) are evaluated on the client.
  late final _users = _db.collection('users').snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(title: 'Overview', subtitle: formatLongDate(DateTime.now())),
        const SizedBox(height: 32),

        // Metrics Summary Row grid layout with live Firestore StreamBuilders
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _recentOrders,
          builder: (context, snap) {
            final today = (snap.data?.docs ?? [])
                .map((d) => d.data())
                .where((o) => isToday(o['createdAt']) && o['status'] != OrderStatus.cancelled)
                .toList();
            final revenue = today
                .where((o) => o['status'] == OrderStatus.delivered)
                .fold<double>(0, (total, o) => total + ((o['totalPrice'] as num?) ?? 0).toDouble());
            return Row(
              children: [
                Expanded(child: _buildMetricCard('Orders today', '${today.length}', 'excluding cancelled')),
                const SizedBox(width: 20),
                Expanded(child: _buildMetricCard('Revenue today', formatPeso(revenue), 'delivered orders')),
                const SizedBox(width: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _stalls,
                    builder: (context, s) {
                      final stalls = s.data?.docs.map((d) => d.data()) ?? [];
                      final open = stalls.where((d) => d['isOpen'] == true && (d['status'] ?? AccountStatus.active) == AccountStatus.active);
                      return _buildMetricCard('Active stalls', '${open.length}', 'of ${stalls.length} registered');
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _users,
                    builder: (context, s) {
                      final approved = (s.data?.docs ?? [])
                          .map((d) => d.data())
                          .where((d) => UserRoles.statusOf(d, UserRoles.delivery) == RoleStatus.approved);
                      final online = approved.where((d) => d['isOnline'] == true).length;
                      return _buildMetricCard('Active riders', '$online online', '${approved.length} approved');
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Pending application banners linked to the live pending stream
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _users,
          builder: (context, snap) {
            final users = (snap.data?.docs ?? []).map((d) => d.data()).toList();
            final riders = users.where((u) => UserRoles.isPendingApplication(u, UserRoles.delivery)).length;
            final vendors = users.where((u) => UserRoles.isPendingApplication(u, UserRoles.vendor)).length;
            return Column(
              children: [
                if (riders > 0) _buildPendingBanner('$riders delivery application${riders == 1 ? '' : 's'} pending review', 'Delivery'),
                if (vendors > 0) _buildPendingBanner('$vendors stall application${vendors == 1 ? '' : 's'} pending review', 'Vendors'),
              ],
            );
          },
        ),

        // Recent orders feed
        Expanded(
          child: AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(onPressed: widget.onOpenOrders, child: const Text('View all orders')),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _recentOrders,
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs.take(15).toList();
                      if (docs.isEmpty) return const EmptyState('No orders yet.');
                      return ListView(children: docs.map((d) => _buildActivityItem(d.id, d.data())).toList());
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingBanner(String text, String roleSegment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFF59D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 22),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          const Spacer(),
          ElevatedButton(
            onPressed: () => widget.onReviewApplications(roleSegment),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.accent),
            child: const Text('Review now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String? sub) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(String orderId, Map<String, dynamic> order) {
    final status = order['status'] ?? OrderStatus.pending;
    final delayed = isOrderDelayed(order);
    return InkWell(
      onTap: () => showOrderDetail(context, orderId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Order ${shortOrderId(orderId)} — ${order['customerName'] ?? 'Customer'} from ${order['stallName'] ?? 'a stall'}'
                '${delayed ? ' · delayed' : ''}',
                style: TextStyle(fontSize: 14, color: delayed ? Colors.amber.shade900 : Colors.black87),
              ),
            ),
            StatusPill(status),
            const SizedBox(width: 16),
            SizedBox(
              width: 90,
              child: Text(timeAgo(order['createdAt']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
