import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';

class DeliveryHomeScreen extends StatelessWidget {
  const DeliveryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good morning,', style: TextStyle(color: Colors.grey)),
                      Text('Juan Cruz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Offline', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Switch(value: true, onChanged: (v) {}, activeColor: AppTheme.primaryColor),
                      const Text('Online', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Today\'s earnings', '₱185')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Deliveries done', '7')),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Available deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
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
                        padding: const EdgeInsets.all(32.0),
                        child: Text('No orders ready for pickup', style: TextStyle(color: Colors.grey.shade400)),
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

Widget buildDeliveryJobCard({
  required BuildContext context, 
  required String docId,
  required String stall, 
  required String fee, 
  required String details
}) {
  final userProvider = Provider.of<UserProvider>(context, listen: false);
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
            Text(stall, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(fee, style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Expanded(child: Text(details, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('orders').doc(docId).update({
              'status': 'Picked up',
              'deliveryPersonId': FirebaseAuth.instance.currentUser?.uid, 
              'deliveryPersonName': userProvider.userData?['name'] ?? 'Juan Cruz',
            });
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveDeliveryScreen(orderId: docId)));
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Accept delivery', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class ActiveDeliveryScreen extends StatelessWidget {
  final String orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle), child: const Text('4', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(width: 8),
            const Text('Active delivery', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'Picked up';
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivering order #${orderId.substring(0, 4)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(24)),
                  child: const Center(child: Icon(Icons.map, size: 60, color: Colors.blue)),
                ),
                const SizedBox(height: 32),
                DeliveryProgressTracker(status: status),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['customerName'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(data['deliveryLocation'] ?? 'CSU Campus', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      const Icon(Icons.phone_outlined, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
                const Spacer(),
                if (status != 'Delivered')
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'Delivered'});
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Text('Mark as delivered', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  )
                else
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Text('Return to Home', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }
}

class DeliveryProgressTracker extends StatelessWidget {
  final String status;
  const DeliveryProgressTracker({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep('Picked up', true),
        _buildConnector(status == 'On the way' || status == 'Delivered'),
        _buildStep('On the way', status == 'On the way' || status == 'Delivered'),
        _buildConnector(status == 'Delivered'),
        _buildStep('Delivered', status == 'Delivered'),
      ],
    );
  }

  Widget _buildStep(String label, bool isDone) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4), 
          decoration: BoxDecoration(color: isDone ? AppTheme.primaryColor : Colors.grey.shade300, shape: BoxShape.circle), 
          child: Icon(isDone ? Icons.check : Icons.circle, size: 12, color: isDone ? Colors.black : Colors.white)
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black)),
      ],
    );
  }

  Widget _buildConnector(bool isDone) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), 
        height: 2, 
        color: isDone ? AppTheme.primaryColor : Colors.grey.shade300
      ),
    );
  }
}
