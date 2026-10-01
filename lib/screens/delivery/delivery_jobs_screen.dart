import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import 'delivery_home_screen.dart';

class DeliveryJobsScreen extends StatefulWidget {
  const DeliveryJobsScreen({super.key});

  @override
  State<DeliveryJobsScreen> createState() => _DeliveryJobsScreenState();
}

class _DeliveryJobsScreenState extends State<DeliveryJobsScreen> {
  final _myOrders = OrderService.riderOrders(UserService.uid);

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<UserProvider>().userData?['isOnline'] ?? false;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<OrderModel>>(
          stream: _myOrders,
          builder: (context, snapshot) {
            final activeJobs = (snapshot.data ?? []).where((o) => OrderStatus.riderActive.contains(o.status)).toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Jobs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Available orders ready for pickup', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 24),
                  if (activeJobs.isNotEmpty) ...[
                    const Text('My active job', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...activeJobs.map((order) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: buildActiveJobCard(context, order),
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (isOnline)
                    AvailableDeliveriesList(hasActiveJob: activeJobs.isNotEmpty)
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Text('You are offline. Go online on the Home tab to receive jobs.',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
