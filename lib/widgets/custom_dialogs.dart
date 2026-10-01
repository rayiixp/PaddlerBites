import 'package:flutter/material.dart';
import '../core/errors.dart';
import '../core/app_theme.dart';

class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onDismiss;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText = 'Got it!',
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.black, size: 40),
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onDismiss();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}


/// Yes/no confirmation in the same style as [SuccessDialog]. Resolves to true on confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      padding: EdgeInsets.zero,
                      backgroundColor: isDestructive ? Colors.redAccent : AppTheme.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(
                      confirmText,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Single text field dialog used for quick profile edits. Resolves to the
/// trimmed value, or null when cancelled.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String hint = '',
  TextInputType keyboardType = TextInputType.text,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : null));
}

void showComingSoon(BuildContext context, String feature) {
  showAppSnackBar(context, '$feature is coming soon.');
}


/// Runs a Firestore write started from a tap (toggle, favourite, quick edit)
/// and reports failures instead of leaving an unhandled error. Returns
/// whether it succeeded.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success, String? errorPrefix}) async {
  try {
    await action();
    if (success != null && context.mounted) showAppSnackBar(context, success);
    return true;
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, errorPrefix == null ? friendlyError(e) : '$errorPrefix ${friendlyError(e)}', isError: true);
    }
    return false;
  }
}
