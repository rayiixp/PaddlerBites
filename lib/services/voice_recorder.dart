import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../core/voice_log.dart';

/// Thrown when recording can't start or produced nothing usable; [message]
/// is shown to the user. [needsSettings] means only system Settings can fix it.
class VoiceException implements Exception {
  final String message;
  final bool needsSettings;
  VoiceException(this.message, {this.needsSettings = false});
  @override
  String toString() => message;
}

/// A finished voice order recording, ready to send to Gemini.
class VoiceRecording {
  final Uint8List bytes;
  final String mimeType;
  final Duration duration;
  const VoiceRecording({required this.bytes, required this.mimeType, required this.duration});
}

/// Records the customer's spoken order to a temporary WAV file.
///
/// 16 kHz mono WAV is small (~32 KB/s) and is an audio format Gemini accepts
/// directly, so no on-phone speech recognition is involved: Gemini hears the
/// customer's own voice, accents and dialect included.
class VoiceRecorder {
  /// Longest order we record; the sheet stops and sends automatically.
  static const maxDuration = Duration(seconds: 20);

  /// Anything shorter is almost certainly an accidental tap.
  static const minDuration = Duration(milliseconds: 700);

  static const mimeType = 'audio/wav';

  late final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  DateTime? _startedAt;
  Future<void>? _starting;
  Future<VoiceRecording>? _stopping;

  /// True from a successful [start] until [stop] or [cancel].
  bool get isRecording => _startedAt != null;

  /// Asks for the microphone at runtime (first use shows the system dialog).
  Future<void> ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    voiceLog('Microphone permission: $status');
    if (status.isGranted) return;
    if (!status.isPermanentlyDenied) {
      voiceLog('Requesting microphone permission…');
      status = await Permission.microphone.request();
      voiceLog('Microphone permission after request: $status');
      if (status.isGranted) return;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      throw VoiceException(
        'Microphone access is turned off for PaddlerBites. Open Settings → Permissions → Microphone and allow it.',
        needsSettings: true,
      );
    }
    throw VoiceException('Voice ordering needs the microphone. Tap "Record again" and choose Allow.');
  }

  Future<void> openSettings() => openAppSettings();

  /// Starts recording immediately (first tap). Calling it again while it is
  /// starting or recording does nothing, so a double tap can't open two files.
  Future<void> start() {
    if (isRecording) return Future.value();
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    await ensureMicrophonePermission();
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_order_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000, // speech doesn't need more; keeps uploads small
        numChannels: 1,
        noiseSuppress: true, // canteens are noisy
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition, // tuned for speech
          manageBluetooth: false, // no Bluetooth permission prompt
        ),
      ),
      path: _path!,
    );
    _startedAt = DateTime.now();
    voiceLog('Recording started → $_path');
  }

  /// Microphone loudness 0..1, roughly every 100 ms while recording.
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      // dBFS: about -50 is quiet room noise, 0 is the loudest possible.
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  /// Stops and returns the WAV audio (second tap). A repeated call while
  /// stopping gets the same result. Throws if the recording is too short or empty.
  Future<VoiceRecording> stop() => _stopping ??= _stop().whenComplete(() => _stopping = null);

  Future<VoiceRecording> _stop() async {
    await _starting; // stopped while the mic was still starting
    if (!isRecording) throw VoiceException('Nothing was recorded. Tap the mic and say your order.');
    final duration = DateTime.now().difference(_startedAt!);
    _startedAt = null;
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) throw VoiceException('Nothing was recorded. Tap the mic and say your order.');

    final file = File(path);
    final bytes = await file.readAsBytes();
    await file.delete().catchError((_) => file);
    voiceLog('Recording stopped: ${duration.inMilliseconds} ms, ${(bytes.length / 1024).toStringAsFixed(1)} KB');

    if (duration < minDuration) {
      throw VoiceException('That was too short. Tap the mic, say your order, then tap stop.');
    }
    if (bytes.length <= 44) {
      // A WAV header with no audio: the microphone gave us nothing.
      throw VoiceException('No sound was recorded. Check that no other app is using the microphone.');
    }
    return VoiceRecording(bytes: bytes, mimeType: mimeType, duration: duration);
  }

  /// Stops without keeping anything (sheet closed).
  Future<void> cancel() async {
    _startedAt = null;
    _path = null;
    if (await _recorder.isRecording()) {
      voiceLog('Recording cancelled');
      await _recorder.cancel(); // also deletes the file
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
