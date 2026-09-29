import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'delivery_home_screen.dart';

class DeliveryJobsScreen extends StatelessWidget {
  const DeliveryJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delivery Jobs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Available orders ready for pickup', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('status', isEqualTo: 'Ready')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No active jobs right now', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text('Check back soon for new order pickup requests', style: TextStyle(color: Colors.grey.shade400, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }
                  final readyOrders = snapshot.data!.docs;
                  return Column(
                    children: readyOrders.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: buildDeliveryJobCard(
                          context: context,
                          docId: doc.id,
                          stall: data['stallName'] ?? 'Campus Stall',
                          fee: '₱15 fee',
                          details: 'Drop-off: ${data['deliveryLocation'] ?? 'CSU Campus'}',
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
