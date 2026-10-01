const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// ₱1,240.00 (or ₱1,240 with [decimals] = 0).
String formatPeso(num value, {int decimals = 2}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '₱$whole.${parts[1]}' : '₱$whole';
}

String greeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 18) return 'Good afternoon,';
  return 'Good evening,';
}

String formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today, 9:20 AM", "Yesterday, 3:12 PM" or "Sep 6, 11:05 AM".
String formatDateTime(DateTime? time) {
  if (time == null) return 'Just now';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, ${formatTime(time)}';
  if (diff == 1) return 'Yesterday, ${formatTime(time)}';
  return '${_months[time.month - 1]} ${time.day}, ${formatTime(time)}';
}

String timeAgo(DateTime? time) {
  if (time == null) return 'Just now';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return formatDateTime(time);
}

bool isSameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}
