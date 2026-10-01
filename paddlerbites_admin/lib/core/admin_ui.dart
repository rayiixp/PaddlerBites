import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'user_roles.dart';

/// Shared colours and building blocks for the admin console, matching the
/// original dashboard design (white 16px cards, yellow accent, pill badges).
class AdminColors {
  static const accent = Color(0xFFFFD54F);
  static const background = Color(0xFFF5F6F8);
  static const panel = Color(0xFFF5F6F8);
}

/// Values of `users/{uid}.status` and `stalls/{id}.status`.
class AccountStatus {
  static const active = 'Active';
  static const pending = 'Pending Review';
  static const suspended = 'Suspended';
}

/// Order lifecycle used by the mobile app.
class OrderStatus {
  static const pending = 'Pending';
  static const preparing = 'Preparing';
  static const ready = 'Ready';
  static const pickedUp = 'Picked up';
  static const onTheWay = 'On the way';
  static const delivered = 'Delivered';
  static const cancelled = 'Cancelled';

  static const active = [pending, preparing, ready, pickedUp, onTheWay];
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

DateTime? toDate(dynamic value) => value is Timestamp ? value.toDate() : null;

String formatDate(dynamic value) {
  final date = value is DateTime ? value : toDate(value);
  if (date == null) return '—';
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatDateTime(dynamic value) {
  final date = value is DateTime ? value : toDate(value);
  if (date == null) return '—';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final ampm = date.hour < 12 ? 'AM' : 'PM';
  return '${_months[date.month - 1]} ${date.day}, $hour:${date.minute.toString().padLeft(2, '0')} $ampm';
}

String formatLongDate(DateTime date) => '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

String timeAgo(dynamic value) {
  final date = value is DateTime ? value : toDate(value);
  if (date == null) return 'Just now';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return formatDate(date);
}

bool isToday(dynamic value) {
  final date = value is DateTime ? value : toDate(value);
  final now = DateTime.now();
  return date != null && date.year == now.year && date.month == now.month && date.day == now.day;
}

String formatPeso(dynamic value) {
  final amount = value is num ? value.toDouble() : 0.0;
  final parts = amount.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₱$whole.${parts[1]}';
}

String shortOrderId(String id) => '#${id.substring(0, id.length < 4 ? id.length : 4).toUpperCase()}';

/// "2× Cheese Burger, 1× Fries"; early test orders stored plain strings.
String orderItemsSummary(dynamic items) {
  if (items is! List || items.isEmpty) return 'No items';
  return items.map((i) => i is Map ? '${i['qty'] ?? 1}× ${i['name'] ?? 'Item'}' : '$i').join(', ');
}

/// Coloured status badge used in every table.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  static (Color, Color) colorsFor(String status) {
    switch (status) {
      case AccountStatus.suspended:
      case RoleStatus.suspended:
      case RoleStatus.rejected:
      case OrderStatus.cancelled:
      case 'Closed':
        return (Colors.red.shade50, Colors.red.shade700);
      case AccountStatus.pending:
      case RoleStatus.pending:
      case OrderStatus.pending:
      case 'Delayed':
        return (Colors.amber.shade50, Colors.amber.shade800);
      case OrderStatus.preparing:
        return (Colors.blue.shade50, Colors.blue.shade700);
      case OrderStatus.ready:
        return (Colors.teal.shade50, Colors.teal.shade700);
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return (Colors.purple.shade50, Colors.purple.shade700);
      default:
        return (Colors.green.shade50, Colors.green.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      // Role statuses are stored lowercase ('pending'); show them capitalised.
      child: Text(RoleStatus.normalize(status) == status ? RoleStatus.label(status) : status,
          style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

/// Page title + subtitle with an optional search box on the right.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? searchHint;
  final ValueChanged<String>? onSearch;

  const PageHeader({super.key, required this.title, required this.subtitle, this.searchHint, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        if (onSearch != null)
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
            ),
            child: TextField(
              onChanged: (value) => onSearch!(value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }
}

/// White rounded panel used for tables and detail sections.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: child,
    );
  }
}

/// Black/white filter chips from the original Users screen.
class FilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, int> counts;

  const FilterChips({super.key, required this.options, required this.selected, required this.onSelected, this.counts = const {}});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected == option;
        final count = counts[option];
        return ChoiceChip(
          label: Text(count == null ? option : '$option ($count)'),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onSelected(option),
          selectedColor: Colors.black,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }
}

/// Grey label / bold value row used in detail panels.
class MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  const MetaRow(this.label, this.value, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 170, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.bold))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Mobile uploads fall back to Firestore when the project has no Storage
/// bucket; those images are stored as `firestore-image:<id>` references to
/// documents in the `images` collection.
const _firestoreImageScheme = 'firestore-image:';
final Map<String, Future<Uint8List?>> _firestoreImageCache = {};

Future<Uint8List?> _loadFirestoreImage(String reference) {
  return _firestoreImageCache.putIfAbsent(reference, () async {
    try {
      final doc = await FirebaseFirestore.instance.collection('images').doc(reference.substring(_firestoreImageScheme.length)).get();
      final data = doc.data()?['data'];
      return data is Blob ? data.bytes : null;
    } catch (_) {
      _firestoreImageCache.remove(reference);
      rethrow;
    }
  });
}

/// Network image for Firebase Storage URLs. On web it falls back to an HTML
/// <img> element so images load even without CORS configured on the bucket.
class AdminNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final IconData placeholderIcon;
  const AdminNetworkImage(this.url, {super.key, this.fit = BoxFit.cover, this.placeholderIcon = Icons.image_outlined});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AdminColors.panel,
      child: Center(child: Icon(placeholderIcon, size: 40, color: Colors.grey)),
    );
    if (url == null || url!.isEmpty) return placeholder;
    if (url!.startsWith(_firestoreImageScheme)) {
      // Photo saved in the `images` collection (project without a Storage bucket).
      return FutureBuilder<Uint8List?>(
        future: _loadFirestoreImage(url!),
        builder: (context, snapshot) => snapshot.data == null
            ? placeholder
            : Image.memory(snapshot.data!, fit: fit, errorBuilder: (context, error, stackTrace) => placeholder),
      );
    }
    return Image.network(
      url!,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

/// Full-screen zoomable image, e.g. to inspect a student ID.
void showImagePreview(BuildContext context, String url, {String title = 'Preview'}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 900,
        height: 650,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  const Text('Scroll or pinch to zoom', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.black87,
                child: InteractiveViewer(maxScale: 6, child: Center(child: AdminNetworkImage(url, fit: BoxFit.contain))),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation dialog. With [askReason] it shows a text box and resolves to
/// the entered reason ('' when left blank); otherwise to '' on confirm.
/// Resolves to null when cancelled.
Future<String?> showAdminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  bool isDestructive = false,
  bool askReason = false,
  String reasonHint = 'Reason (shown to the user)',
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: Colors.black87)),
            if (askReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: reasonHint,
                  filled: true,
                  fillColor: AdminColors.panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? Colors.red : AdminColors.accent,
            foregroundColor: isDestructive ? Colors.white : Colors.black,
            elevation: 0,
          ),
          child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void showAdminSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : null));
}

/// Centered grey message for empty tables.
class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
