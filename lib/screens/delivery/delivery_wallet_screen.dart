import 'package:flutter/material.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_dialogs.dart';

class DeliveryWalletScreen extends StatefulWidget {
  const DeliveryWalletScreen({super.key});

  @override
  State<DeliveryWalletScreen> createState() => _DeliveryWalletScreenState();
}

class _DeliveryWalletScreenState extends State<DeliveryWalletScreen> {
  final _myOrders = OrderService.riderOrders(UserService.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<OrderModel>>(
          stream: _myOrders,
          builder: (context, snapshot) {
            final delivered = (snapshot.data ?? []).where((o) => o.status == OrderStatus.delivered).toList();
            final weekStart = startOfWeek(DateTime.now());
            final weekEarnings = delivered
                .where((o) => !(o.deliveredAt ?? o.createdAt ?? DateTime.now()).isBefore(weekStart))
                .fold<double>(0, (total, o) => total + o.deliveryFee);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Earnings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B2E),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        const Text('This week\'s earnings', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(formatPeso(weekEarnings), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => showComingSoon(context, 'Cash out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Cash out', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Delivery history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (delivered.isEmpty)
                    Text('Completed deliveries will show up here', style: TextStyle(color: Colors.grey.shade400))
                  else
                    for (int i = 0; i < delivered.length; i++) ...[
                      if (i > 0) const Divider(),
                      _buildHistoryItem(
                        'Order ${delivered[i].shortId}',
                        formatDateTime(delivered[i].deliveredAt ?? delivered[i].createdAt),
                        '+${formatPeso(delivered[i].deliveryFee, decimals: 0)}',
                      ),
                    ],
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String id, String time, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Text(amount, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
