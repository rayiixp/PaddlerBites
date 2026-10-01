import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/campus_map.dart';
import '../../widgets/custom_dialogs.dart';
import 'my_orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _locationController = TextEditingController();
  late final Stream<QuerySnapshot> _cart = Provider.of<CartProvider>(context, listen: false).getCartStream();
  LatLng? _dropoff;
  bool _isPlacing = false;
  bool _placed = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDropoff() async {
    final point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => CampusLocationPicker(title: 'Pin your drop-off spot', initial: _dropoff)),
    );
    if (point != null) setState(() => _dropoff = point);
  }

  Future<void> _placeOrder(List<QueryDocumentSnapshot> cartDocs) async {
    final location = _locationController.text.trim();
    if (_dropoff == null) {
      showAppSnackBar(context, 'Please pin your drop-off spot on the campus map', isError: true);
      return;
    }
    if (location.isEmpty) {
      showAppSnackBar(context, 'Please enter the building / room for the rider', isError: true);
      return;
    }

    setState(() => _isPlacing = true);
    try {
      final userData = Provider.of<UserProvider>(context, listen: false).userData;
      final orderIds = await OrderService.placeOrders(
        cartDocs: cartDocs,
        customerId: UserService.uid,
        customerName: userData?['name'] ?? 'Customer',
        deliveryLocation: location,
        deliveryPoint: _dropoff!,
      );
      if (!mounted) return;
      setState(() => _placed = true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => SuccessDialog(
          title: orderIds.length == 1 ? 'Order Placed!' : '${orderIds.length} Orders Placed!',
          message: orderIds.length == 1
              ? 'Your order is being sent to the stall. You can track its progress in the tracking screen.'
              : 'Your cart had items from ${orderIds.length} stalls, so each stall got its own order.',
          buttonText: orderIds.length == 1 ? 'Track Order' : 'View My Orders',
          onDismiss: () {
            if (orderIds.length == 1) {
              Navigator.pushReplacementNamed(context, '/order-tracking', arguments: orderIds.first);
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyOrdersScreen()));
            }
          },
        ),
      );
    } on OrderException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Failed to place order. ${friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Checkout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cart,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final cartDocs = snapshot.data!.docs;
          if (_placed) return const SizedBox.shrink();
          if (cartDocs.isEmpty && !_isPlacing) {
            return const Center(child: Text('Your cart is empty', style: TextStyle(color: Colors.grey, fontSize: 18)));
          }

          // Group by stall: each stall becomes its own order with its own delivery fee.
          final byStall = <String, List<Map<String, dynamic>>>{};
          double subtotal = 0;
          for (final doc in cartDocs) {
            final data = doc.data() as Map<String, dynamic>;
            byStall.putIfAbsent(data['stallName'] ?? 'Stall', () => []).add(data);
            subtotal += ((data['price'] ?? 0) as num) * ((data['qty'] ?? 1) as num);
          }
          final deliveryFee = kDeliveryFee * byStall.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                for (final entry in byStall.entries) ...[
                  Text(entry.key, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ...entry.value.map((item) => CartItemSummary(
                        name: item['name'] ?? 'Item',
                        price: ((item['price'] ?? 0) as num).toDouble(),
                        qty: ((item['qty'] ?? 1) as num).toInt(),
                      )),
                  const SizedBox(height: 8),
                ],
                const Divider(height: 40),
                const Text('Deliver to', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildDropoffPicker(),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'Building / room (e.g. BSIT Building, Room 204)',
                    prefixIcon: const Icon(Icons.apartment_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const Divider(height: 40),
                const Text('Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.payments_outlined),
                      SizedBox(width: 12),
                      Expanded(child: Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.w600))),
                      Icon(Icons.check_circle, color: AppTheme.secondaryColor),
                    ],
                  ),
                ),
                const Divider(height: 40),
                SummaryRow(label: 'Subtotal', value: formatPeso(subtotal)),
                SummaryRow(
                  label: byStall.length > 1 ? 'Delivery Fee (${byStall.length} stalls)' : 'Delivery Fee',
                  value: formatPeso(deliveryFee),
                ),
                SummaryRow(label: 'Total', value: formatPeso(subtotal + deliveryFee), isTotal: true),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isPlacing ? null : () => _placeOrder(cartDocs),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isPlacing
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Place Order'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropoffPicker() {
    if (_dropoff == null) {
      return GestureDetector(
        onTap: _pickDropoff,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, color: Colors.grey.shade400),
              const SizedBox(width: 12),
              const Expanded(child: Text('Tap to pin your drop-off spot on campus', style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _pickDropoff,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 160,
          child: Stack(
            children: [
              // Preview only; taps open the full picker.
              IgnorePointer(child: CampusMap(dropoff: _dropoff)),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Change pin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
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
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
        child: Text('${qty}x', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(name),
      trailing: Text(formatPeso(price * qty)),
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
