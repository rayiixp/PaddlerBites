import 'package:flutter/foundation.dart';

/// Debug logging for voice ordering. Every line starts with `[VoiceOrder]`
/// so it can be filtered in the debug console / logcat. Debug builds only:
/// release builds never log what customers say.
void voiceLog(String message, [Object? error, StackTrace? stack]) {
  if (!kDebugMode) return;
  final time = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.SSS
  debugPrint('[VoiceOrder $time] $message');
  if (error != null) debugPrint('[VoiceOrder $time]   ↳ $error');
  if (stack != null) debugPrint(stack.toString().split('\n').take(6).join('\n'));
}
