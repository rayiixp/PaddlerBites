import 'package:flutter/material.dart';
import '../../core/theme.dart';

class VendorMenuScreen extends StatelessWidget {
  const VendorMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My menu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add_box_outlined, color: AppTheme.primaryColor, size: 28),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search your menu items',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                children: [
                  _buildMenuItem(context, 'Cheese Burger', '₱30.00', true, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200'),
                  _buildMenuItem(context, 'Fried Chicken', '₱50.00', true, 'https://images.unsplash.com/photo-1562967914-608f82629710?w=200'),
                  _buildMenuItem(context, 'Orange Juice', 'Sold out', false, 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=200'),
                  _buildMenuItem(context, 'Spaghetti', '₱70.00', true, 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=200'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String name, String price, bool isAvailable, String imageUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: TextStyle(
                    color: isAvailable ? AppTheme.secondaryColor : Colors.grey,
                    fontWeight: isAvailable ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            onChanged: (v) {},
            activeColor: AppTheme.primaryColor,
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
