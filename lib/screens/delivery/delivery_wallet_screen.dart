import 'package:flutter/material.dart';
import '../../core/theme.dart';

class DeliveryWalletScreen extends StatelessWidget {
  const DeliveryWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                    const Text('₱845.00', style: TextStyle(color: AppTheme.primaryColor, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {},
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
              _buildHistoryItem('Order #1042', 'Today, 9:20 AM', '+₱15'),
              const Divider(),
              _buildHistoryItem('Order #1038', 'Today, 8:45 AM', '+₱10'),
              const Divider(),
              _buildHistoryItem('Order #1030', 'Yesterday, 3:12 PM', '+₱15'),
              const Divider(),
              _buildHistoryItem('Order #1022', 'Yesterday, 11:05 AM', '+₱10'),
              const SizedBox(height: 100),
            ],
          ),
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
