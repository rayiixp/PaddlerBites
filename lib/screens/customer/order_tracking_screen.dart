import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Placeholder
          Container(
            color: Colors.blue.shade50,
            child: const Center(
              child: Icon(Icons.map, size: 100, color: Colors.blue),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: const Text('Searching for your active order...'),
                  );
                }

                final order = snapshot.data!.docs.first;
                final data = order.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Placed';

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.orange),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Arriving in', style: TextStyle(color: Colors.grey)),
                                Text(data['eta'] ?? '15–20 min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      OrderProgressTracker(status: status),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundImage: NetworkImage('https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&q=80'),
                        ),
                        title: Text(data['deliveryPersonName'] ?? 'Searching for rider...', style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chat_bubble_outline),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                        title: const Text('Delivering to'),
                        subtitle: Text(data['deliveryLocation'] ?? 'CSU Cabadbaran Campus'),
                      ),
                      const Divider(),
                      const SummaryRow(label: 'Total', value: '₱70.00', isTotal: true),
                    ],
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

class OrderProgressTracker extends StatelessWidget {
  final String status;
  const OrderProgressTracker({super.key, required this.status});

  bool _isStepDone(String step) {
    final statusList = ['Placed', 'Preparing', 'Ready', 'Picked up', 'On the way', 'Delivered'];
    return statusList.indexOf(status) >= statusList.indexOf(step);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStep('Placed', _isStepDone('Placed')),
        _buildConnector(_isStepDone('Preparing')),
        _buildStep('Preparing', _isStepDone('Preparing')),
        _buildConnector(_isStepDone('Picked up')),
        _buildStep('Picked up', _isStepDone('Picked up')),
        _buildConnector(_isStepDone('On the way')),
        _buildStep('On the way', _isStepDone('On the way')),
        _buildConnector(_isStepDone('Delivered')),
        _buildStep('Delivered', _isStepDone('Delivered')),
      ],
    );
  }

  Widget _buildStep(String label, bool isDone) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDone ? AppTheme.primaryColor : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(isDone ? Icons.check : Icons.circle, size: 12, color: isDone ? Colors.black : Colors.white),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 8, color: isDone ? Colors.black : Colors.grey)),
      ],
    );
  }

  Widget _buildConnector(bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        color: isDone ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const SummaryRow({super.key, required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
