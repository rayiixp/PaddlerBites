import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../widgets/custom_dialogs.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const CartItemSummary(name: 'Cheese Burger', price: 30.00, qty: 2),
            const CartItemSummary(name: 'Banana Cue', price: 10.00, qty: 1),
            const Divider(height: 40),
            const SummaryRow(label: 'Subtotal', value: '₱70.00'),
            const SummaryRow(label: 'Delivery Fee', value: '₱15.00'),
            const SummaryRow(label: 'Total', value: '₱85.00', isTotal: true),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection('orders').add({
                    'customerId': 'current_user_id_placeholder',
                    'customerName': 'Rayt', 
                    'items': ['Cheese Burger', 'Banana Cue'],
                    'totalPrice': 85.00,
                    'status': 'Pending',
                    'createdAt': FieldValue.serverTimestamp(),
                    'deliveryLocation': 'CSU Cabadbaran Campus',
                  });

                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => SuccessDialog(
                        title: 'Order Placed!',
                        message: 'Your order is being sent to the stall. You can track its progress in the tracking screen.',
                        buttonText: 'Track Order',
                        onDismiss: () {
                          Navigator.pushNamed(context, '/order-tracking');
                        },
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to place order: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Place Order'),
            ),
          ],
        ),
      ),
    );
  }
}

class CartItemSummary extends StatelessWidget {
  final String name;
  final double price;
  final int qty;

  const CartItemSummary({super.key, required this.name, required this.price, required this.qty});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
        child: Text('${qty}x', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(name),
      trailing: Text('₱${price * qty}'),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
          Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
        ],
      ),
    );
  }
}
