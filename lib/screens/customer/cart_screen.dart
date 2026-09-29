import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/cart_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Applied theme background color
      appBar: AppBar(
        title: const Text('Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false, // Left-aligned like the photo
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartProvider.getCartStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Your cart is empty', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          final cartItems = snapshot.data!.docs;
          double total = 0;
          for (var item in cartItems) {
            final data = item.data() as Map<String, dynamic>;
            total += (data['price'] ?? 0) * (data['qty'] ?? 0);
          }

          // Update total price in Provider for other screens to use
          cartProvider.updateTotalPrice(total);

          // Format total to remove trailing .00 if it's a whole number, to match "₱40" in the design
          String displayTotal = total.toStringAsFixed(2).endsWith('.00')
              ? total.toStringAsFixed(0)
              : total.toStringAsFixed(2);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final doc = cartItems[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return CartItemCard(
                      docId: doc.id,
                      name: data['name'] ?? 'Unknown',
                      price: (data['price'] ?? 0.0).toDouble(),
                      stall: data['stallName'] ?? 'Snackpreneurs', // Defaulted to match photo
                      image: data['imageUrl'] ?? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&q=80',
                      quantity: data['qty'] ?? 1,
                    );
                  },
                ),
              ),
              Padding(
                // Bottom padding 120 ensures the button sits nicely above the floating nav
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120, top: 10),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/checkout'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Checkout ₱$displayTotal',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CartItemCard extends StatefulWidget {
  final String docId;
  final String name;
  final double price;
  final String stall;
  final String image;
  final int quantity;

  const CartItemCard({
    super.key,
    required this.docId,
    required this.name,
    required this.price,
    required this.stall,
    required this.image,
    required this.quantity,
  });

  @override
  State<CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends State<CartItemCard> {
  bool _isSelected = false; // State to track if the card is clicked

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return GestureDetector(
      onTap: () {
        setState(() {
          _isSelected = !_isSelected; // Toggle the yellow stroke
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.stall, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(widget.image, width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('₱${widget.price.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildStepButton(Icons.remove, () {
                        cartProvider.decrementQuantity(widget.docId, widget.quantity);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('${widget.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      ),
                      _buildStepButton(Icons.add, () {
                        cartProvider.incrementQuantity(widget.docId, widget.quantity);
                      }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black87, width: 1), // Exact black border style from photo
        ),
        child: Icon(icon, size: 18, color: Colors.black),
      ),
    );
  }
}