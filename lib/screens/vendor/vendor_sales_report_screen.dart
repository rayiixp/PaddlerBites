import 'package:flutter/material.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';

class VendorSalesReportScreen extends StatefulWidget {
  const VendorSalesReportScreen({super.key});

  @override
  State<VendorSalesReportScreen> createState() => _VendorSalesReportScreenState();
}

class _VendorSalesReportScreenState extends State<VendorSalesReportScreen> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _orders = OrderService.stallOrders(UserService.uid);
  bool _isMonth = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Sales report', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<bool>(
            onSelected: (isMonth) => setState(() => _isMonth = isMonth),
            itemBuilder: (context) => const [
              PopupMenuItem(value: false, child: Text('This week')),
              PopupMenuItem(value: true, child: Text('This month')),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Text(_isMonth ? 'This month' : 'This week',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Could not load sales: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final now = DateTime.now();
          final start = _isMonth ? DateTime(now.year, now.month) : startOfWeek(now);
          final orders = snapshot.data!
              .where((o) => o.status != OrderStatus.cancelled && o.createdAt != null && !o.createdAt!.isBefore(start))
              .toList();
          final totalSales = orders.fold<double>(0, (total, o) => total + o.subtotal);

          // Chart buckets: days of this week, or weeks (W1–W5) of this month.
          final labels = _isMonth ? List.generate(5, (i) => 'W${i + 1}') : _days;
          final buckets = List<double>.filled(labels.length, 0);
          for (final o in orders) {
            final index = _isMonth ? (o.createdAt!.day - 1) ~/ 7 : o.createdAt!.weekday - 1;
            buckets[index.clamp(0, labels.length - 1)] += o.subtotal;
          }
          final maxBucket = buckets.fold<double>(0, (m, v) => v > m ? v : m);
          final currentBucket = _isMonth ? (now.day - 1) ~/ 7 : now.weekday - 1;

          final sold = <String, int>{};
          for (final o in orders) {
            for (final item in o.items) {
              sold[item.name] = (sold[item.name] ?? 0) + item.qty;
            }
          }
          final bestSellers = sold.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Total sales', formatPeso(totalSales, decimals: 0))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSummaryCard('Total orders', '${orders.length}')),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isMonth ? 'Sales this month' : 'Sales this week',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                            labels.length,
                            (i) => _buildBar(
                              labels[i],
                              maxBucket == 0 ? 0.02 : (buckets[i] / maxBucket).clamp(0.02, 1.0),
                              isHighlighted: i == currentBucket,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Best sellers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (bestSellers.isEmpty)
                  Text('No sales yet for this period', style: TextStyle(color: Colors.grey.shade400))
                else
                  ...bestSellers.take(5).toList().asMap().entries.map(
                        (e) => _buildBestSellerItem('${e.key + 1}. ${e.value.key}', '${e.value.value} sold'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double heightFactor, {bool isHighlighted = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 120 * heightFactor,
          decoration: BoxDecoration(
            color: isHighlighted ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBestSellerItem(String name, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(count, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
