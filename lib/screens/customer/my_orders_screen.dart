import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors.dart';
import '../../models/order_summary.dart';
import '../../providers/cart_provider.dart';
import '../../services/catalog_service.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_dialogs.dart';
import '../../widgets/order_card.dart';

/// Customer order history split into Active / Past / Cancelled tabs.
///
/// By default it streams the signed-in customer's orders from Firestore.
/// [MyOrdersScreen.preview] shows [Order.samples] instead, to see every card
/// state without a backend.
class MyOrdersScreen extends StatefulWidget {
  /// Fixed orders to show instead of the live stream (preview mode).
  final List<Order>? orders;

  const MyOrdersScreen({super.key}) : orders = null;

  /// Dummy-data version for trying the UI.
  MyOrdersScreen.preview({super.key}) : orders = Order.samples;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late final Stream<List<Order>> _orders = widget.orders != null
      ? Stream.value(widget.orders!)
      : OrderService.customerOrders(UserService.uid).map((orders) => orders.map(Order.fromModel).toList());

  /// Orders whose Reorder button is currently working.
  final Set<String> _reordering = {};

  bool get _isPreview => widget.orders != null;

  // ------------------------------------------------------------- Actions

  void _track(Order order) {
    if (_isPreview) {
      showAppSnackBar(context, 'Preview: tracking opens for real orders.');
      return;
    }
    Navigator.pushNamed(context, '/order-tracking', arguments: order.id);
  }

  /// Puts the order's items back in the cart at today's prices, skipping
  /// anything that is sold out or no longer on the menu.
  Future<void> _reorder(Order order) async {
    if (_isPreview) {
      showAppSnackBar(context, 'Preview: ${order.summary} would be added to your cart.');
      return;
    }
    final cart = Provider.of<CartProvider>(context, listen: false);
    setState(() => _reordering.add(order.id));
    try {
      final stall = await CatalogService.getStall(order.stallId);
      if (stall == null || !stall.isApproved || !stall.isOpen) {
        throw StateError('${order.stallName} is closed right now. Try again later.');
      }
      final unavailable = <String>[];
      var added = 0;
      for (final line in order.items) {
        final food = line.itemId.isEmpty ? null : await CatalogService.getItem(line.itemId);
        if (food == null || !food.isAvailable) {
          unavailable.add(line.name);
          continue;
        }
        await cart.addToCart(food, qty: line.qty);
        added++;
      }
      if (!mounted) return;
      if (added == 0) {
        showAppSnackBar(context, 'None of these items are available right now.', isError: true);
      } else {
        showAppSnackBar(
          context,
          unavailable.isEmpty
              ? 'Added to your cart. Open the Cart tab to check out.'
              : 'Added to your cart. Unavailable: ${unavailable.join(', ')}.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not reorder. ${friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _reordering.remove(order.id));
    }
  }

  Future<void> _rate(Order order) async {
    final stars = await showDialog<int>(context: context, builder: (context) => _RateOrderDialog(order: order));
    if (stars == null || !mounted) return;
    if (_isPreview) {
      showAppSnackBar(context, 'Preview: rated $stars stars.');
      return;
    }
    await runGuarded(context, () => OrderService.rateOrder(order.id, stars), success: 'Thanks for rating ${order.stallName}!');
  }

  Future<void> _reportIssue(Order order) async {
    final message = await showTextInputDialog(
      context,
      title: 'Report an issue with ${order.shortId}',
      hint: 'What went wrong? (missing item, late, wrong order…)',
    );
    if (message == null || message.isEmpty || !mounted) return;
    if (_isPreview) {
      showAppSnackBar(context, 'Preview: issue reported.');
      return;
    }
    await runGuarded(context, () => OrderService.reportIssue(order.id, message),
        success: 'Issue reported. The PaddlerBites team will look into it.');
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: colors.surface.withValues(alpha: 0),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isPreview ? 'My Orders (preview)' : 'My Orders',
            style: theme.textTheme.titleLarge?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            indicatorColor: colors.primary,
            indicatorWeight: 3,
            labelColor: colors.onSurface,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.55),
            labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            unselectedLabelStyle: theme.textTheme.titleSmall,
            dividerColor: colors.onSurface.withValues(alpha: 0.08),
            tabs: const [Tab(text: 'Active'), Tab(text: 'Completed'), Tab(text: 'Cancelled')],
          ),
        ),
        body: StreamBuilder<List<Order>>(
          stream: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EmptyState(icon: Icons.error_outline, message: 'Could not load orders. ${friendlyError(snapshot.error!)}');
            }
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: colors.primary));
            }
            final orders = snapshot.data!;
            return TabBarView(
              children: [
                _OrdersTab(
                  orders: orders.where((o) => o.isActive).toList(),
                  empty: const _EmptyState(icon: Icons.kayaking, message: 'No active orders.\nHungry? Browse the stalls!'),
                  cardBuilder: _buildCard,
                ),
                _OrdersTab(
                  orders: orders.where((o) => o.isDelivered).toList(),
                  empty: const _EmptyState(icon: Icons.receipt_long_outlined, message: 'Delivered orders will show up here.'),
                  cardBuilder: _buildCard,
                ),
                _OrdersTab(
                  orders: orders.where((o) => o.isCancelled).toList(),
                  empty: const _EmptyState(icon: Icons.cancel_outlined, message: 'No cancelled orders.'),
                  cardBuilder: _buildCard,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(Order order) {
    return OrderCard(
      order: order,
      isReordering: _reordering.contains(order.id),
      onTrack: () => _track(order),
      onReorder: () => _reorder(order),
      onRate: () => _rate(order),
      onReportIssue: () => _reportIssue(order),
    );
  }
}

/// One tab's list of order cards.
class _OrdersTab extends StatelessWidget {
  final List<Order> orders;
  final Widget empty;
  final Widget Function(Order order) cardBuilder;

  const _OrdersTab({required this.orders, required this.empty, required this.cardBuilder});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return empty;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: orders.length,
      itemBuilder: (context, index) => cardBuilder(orders[index]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: muted),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: muted)),
          ],
        ),
      ),
    );
  }
}

/// 1–5 star picker; pops with the chosen number of stars.
class _RateOrderDialog extends StatefulWidget {
  final Order order;
  const _RateOrderDialog({required this.order});

  @override
  State<_RateOrderDialog> createState() => _RateOrderDialogState();
}

class _RateOrderDialogState extends State<_RateOrderDialog> {
  int _stars = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rate ${widget.order.stallName}',
                style: theme.textTheme.titleLarge?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.order.summary,
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                // Equal share of the width so five stars fit narrow phones.
                return Expanded(
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: '${i + 1} star${i == 0 ? '' : 's'}',
                    onPressed: () => setState(() => _stars = i + 1),
                    icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 36, color: filled ? colors.primary : colors.onSurface.withValues(alpha: 0.3)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _stars == 0 ? null : () => Navigator.pop(context, _stars),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: const StadiumBorder(),
              ),
              child: Text('Submit rating', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
          ],
        ),
      ),
    );
  }
}
