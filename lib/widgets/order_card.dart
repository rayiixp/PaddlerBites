import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/models.dart';
import '../models/order_summary.dart';

// All colours and text styles come from Theme.of(context) so the card follows
// the app theme and works in dark mode.

/// Order history card: stall + status header, order metadata, item summary,
/// and actions that depend on the status (track / reorder, rate, report).
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTrack;
  final VoidCallback? onReorder;
  final VoidCallback? onRate;
  final VoidCallback? onReportIssue;

  /// Shows progress on the Reorder button while it runs.
  final bool isReordering;

  const OrderCard({
    super.key,
    required this.order,
    this.onTrack,
    this.onReorder,
    this.onRate,
    this.onReportIssue,
    this.isReordering = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: order.isActive ? onTrack : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderHeader(order: order),
              const SizedBox(height: 14),
              // Order summary, e.g. "1x Burger"
              Text(
                order.summary,
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: colors.onSurface.withValues(alpha: 0.08)),
              const SizedBox(height: 8),
              _OrderFooter(
                order: order,
                onTrack: onTrack,
                onReorder: onReorder,
                onRate: onRate,
                onReportIssue: onReportIssue,
                isReordering: isReordering,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stall avatar, stall name, order id / date and the status badge.
class _OrderHeader extends StatelessWidget {
  final Order order;
  const _OrderHeader({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final initial = order.stallName.isEmpty ? '?' : order.stallName[0].toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Placeholder for the stall logo
        CircleAvatar(
          radius: 22,
          backgroundColor: colors.secondary.withValues(alpha: 0.12),
          child: Text(initial, style: theme.textTheme.titleMedium?.copyWith(color: colors.secondary, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stall name with the status badge on the right
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.stallName,
                      style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              // Metadata gets the full width under the name
              Text(
                'Order ${order.shortId} · ${formatDateTime(order.placedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Status pill with an icon. Colours use the theme's semantic container
/// pairs (e.g. errorContainer / onErrorContainer), which stay readable in
/// both light and dark mode.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    final displayText = status == OrderStatus.pending ? 'Confirming' : status;

    final (Color background, Color foreground, IconData icon) = switch (status) {
      OrderStatus.pending => (colors.secondaryContainer, colors.onSecondaryContainer, Icons.schedule),
      OrderStatus.preparing => (colors.surfaceContainerHighest, colors.onSurfaceVariant, Icons.soup_kitchen_outlined),
      OrderStatus.ready => (colors.surfaceContainerHighest, colors.onSurfaceVariant, Icons.shopping_bag_outlined),
      OrderStatus.pickedUp || OrderStatus.onTheWay => (colors.primaryContainer, colors.onPrimaryContainer, Icons.kayaking),
      OrderStatus.delivered => (colors.tertiaryContainer, colors.onTertiaryContainer, Icons.check_circle_outline),
      OrderStatus.cancelled => (colors.errorContainer, colors.onErrorContainer, Icons.cancel_outlined),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant, Icons.receipt_long_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(displayText, style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Total price plus the status-dependent actions.
class _OrderFooter extends StatelessWidget {
  final Order order;
  final VoidCallback? onTrack;
  final VoidCallback? onReorder;
  final VoidCallback? onRate;
  final VoidCallback? onReportIssue;
  final bool isReordering;

  const _OrderFooter({
    required this.order,
    this.onTrack,
    this.onReorder,
    this.onRate,
    this.onReportIssue,
    this.isReordering = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = Expanded(
      child: Text(
        formatPeso(order.total),
        style: theme.textTheme.titleMedium?.copyWith(color: colors.secondary, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );

    // Active orders (Pending, Preparing, Ready, Picked up, On the way): track them.
    if (order.isActive) {
      return Row(
        children: [
          total,
          TextButton(
            onPressed: onTrack,
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Track order', style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold)),
                Icon(Icons.chevron_right, size: 18, color: colors.onSurface),
              ],
            ),
          ),
        ],
      );
    }

    // Delivered: reorder is the main action; rate / report are secondary.
    if (order.isDelivered) {
      final subtle = colors.onSurface.withValues(alpha: 0.7);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              total,
              FilledButton.icon(
                onPressed: isReordering ? null : onReorder,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: const StadiumBorder(),
                ),
                icon: isReordering
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                    : const Icon(Icons.replay, size: 18),
                label: Text('Reorder', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Wrap(
            children: [
              if (order.rating > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text('Rated ${'★' * order.rating}', style: theme.textTheme.bodySmall?.copyWith(color: colors.secondary)),
                )
              else
                TextButton.icon(
                  onPressed: onRate,
                  style: TextButton.styleFrom(foregroundColor: subtle),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: Text('Rate', style: theme.textTheme.bodySmall?.copyWith(color: subtle)),
                ),
              TextButton.icon(
                onPressed: onReportIssue,
                style: TextButton.styleFrom(foregroundColor: subtle),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text('Report issue', style: theme.textTheme.bodySmall?.copyWith(color: subtle)),
              ),
            ],
          ),
        ],
      );
    }

    // Cancelled: price only.
    return Row(children: [total]);
  }
}
