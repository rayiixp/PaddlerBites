import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_dialogs.dart';
import '../../widgets/premium_paddling_boat.dart';
import 'active_delivery_screen.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  final _myOrders = OrderService.riderOrders(UserService.uid);

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserProvider>().userData ?? {};
    final isOnline = userData['isOnline'] ?? false;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<OrderModel>>(
          stream: _myOrders,
          builder: (context, snapshot) {
            final myOrders = snapshot.data ?? [];
            final now = DateTime.now();
            final deliveredToday = myOrders
                .where((o) => o.status == OrderStatus.delivered && isSameDay(o.deliveredAt ?? o.createdAt, now))
                .toList();
            final earningsToday = deliveredToday.fold<double>(0, (total, o) => total + o.deliveryFee);
            final activeJobs = myOrders.where((o) => OrderStatus.riderActive.contains(o.status)).toList();

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
                            Text(
                              userData['name'] ?? 'Rider',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Offline', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Switch(
                            value: isOnline,
                            onChanged: (v) => runGuarded(context, () => UserService.currentUserRef.update({'isOnline': v})),
                            activeColor: AppTheme.primaryColor,
                          ),
                          Text(
                            'Online',
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Today\'s earnings', formatPeso(earningsToday, decimals: 0))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Deliveries done', '${deliveredToday.length}')),
                    ],
                  ),
                  if (activeJobs.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text('Current delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...activeJobs.map(
                      (order) => Padding(padding: const EdgeInsets.only(bottom: 16), child: buildActiveJobCard(context, order)),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const Text('Available deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (!isOnline)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text('Go online to see available deliveries', style: TextStyle(color: Colors.grey.shade400)),
                      ),
                    )
                  else
                    AvailableDeliveriesList(hasActiveJob: activeJobs.isNotEmpty),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
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

/// Real-time list of ready orders no rider has claimed yet.
class AvailableDeliveriesList extends StatefulWidget {
  final bool hasActiveJob;
  const AvailableDeliveriesList({super.key, required this.hasActiveJob});

  @override
  State<AvailableDeliveriesList> createState() => _AvailableDeliveriesListState();
}

class _AvailableDeliveriesListState extends State<AvailableDeliveriesList> {
  final _available = OrderService.availableDeliveries();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _available,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Could not load deliveries: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No active jobs right now',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orders show up here as soon as a stall marks them ready for pickup.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: snapshot.data!
              .map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DeliveryJobCard(order: order, hasActiveJob: widget.hasActiveJob),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Available job with an "Accept delivery" button that shows progress and
/// ignores repeat taps while the claim transaction runs.
class DeliveryJobCard extends StatefulWidget {
  final OrderModel order;
  final bool hasActiveJob;
  const DeliveryJobCard({super.key, required this.order, required this.hasActiveJob});

  @override
  State<DeliveryJobCard> createState() => _DeliveryJobCardState();
}

class _DeliveryJobCardState extends State<DeliveryJobCard> {
  bool _isAccepting = false;

  Future<void> _accept() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    final order = widget.order;
    final accepted = await runGuarded(context, () async {
      await OrderService.acceptDelivery(
        orderId: order.id,
        riderId: UserService.uid,
        riderName: Provider.of<UserProvider>(context, listen: false).userData?['name'] ?? 'Rider',
      );
    });
    if (!mounted) return;
    setState(() => _isAccepting = false);
    if (accepted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveDeliveryScreen(orderId: order.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final hasActiveJob = widget.hasActiveJob;
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
              Expanded(
                child: Text(order.stallName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Text(
                '${formatPeso(order.deliveryFee, decimals: 0)} fee',
                style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Drop-off: ${order.deliveryLocation}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · collect ${formatPeso(order.totalPrice)} (COD)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: hasActiveJob || _isAccepting ? null : _accept,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isAccepting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text(
                    hasActiveJob ? 'Finish your current delivery first' : 'Accept delivery',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Compact card for the rider's own in-progress delivery.
Widget buildActiveJobCard(BuildContext context, OrderModel order) {
  return GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveDeliveryScreen(orderId: order.id))),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const PremiumPaddlingBoatAnimation(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ${order.shortId} · ${order.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${order.stallName} → ${order.deliveryLocation}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.orange.shade300),
        ],
      ),
    ),
  );
}
