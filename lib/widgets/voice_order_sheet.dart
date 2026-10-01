import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../core/app_theme.dart';
import '../core/voice_log.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../services/catalog_service.dart';
import '../services/voice_order_parser.dart';
import '../services/voice_recorder.dart';
import 'app_image.dart';
import 'premium_paddling_boat.dart';

enum VoiceStage { recording, processing, confirm, error }

/// State machine behind the voice-order sheet:
/// recording → processing (Gemini listens to the audio) → confirm, or error.
class VoiceOrderController extends ChangeNotifier {
  VoiceOrderController({VoiceRecorder? recorder, VoiceOrderParser? parser, Future<List<FoodModel>> Function()? menuLoader})
      : _recorder = recorder ?? VoiceRecorder(),
        _parser = parser ?? VoiceOrderParser(),
        _menuLoader = menuLoader ?? _loadOrderableMenu;

  final VoiceRecorder _recorder;
  final VoiceOrderParser _parser;
  final Future<List<FoodModel>> Function() _menuLoader;

  VoiceStage stage = VoiceStage.recording;

  /// False while the microphone is still starting ("Getting the mic ready…").
  bool isRecording = false;

  /// What Gemini heard (after processing).
  String transcript = '';
  List<VoiceOrderLine> lines = [];
  List<String> unmatched = [];
  String errorMessage = '';
  bool errorNeedsSettings = false;
  bool isAdding = false;

  /// Shown under the loader while Gemini is retrying (e.g. "busy, trying again").
  String? processingNote;

  /// Smoothed microphone loudness 0..1 and time recorded so far. Separate
  /// notifiers so only the mic and timer redraw, not the whole sheet.
  final ValueNotifier<double> soundLevel = ValueNotifier(0);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  Future<List<FoodModel>>? _menu;
  StreamSubscription<double>? _levels;
  Timer? _ticker;
  bool _disposed = false;

  int get itemCount => lines.fold(0, (total, l) => total + l.quantity);
  double get total => lines.fold(0, (total, l) => total + l.food.price * l.quantity);

  void _set(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  /// Starts recording immediately; the menu loads in parallel.
  Future<void> start() async {
    voiceLog('▶ Voice order: start recording');
    _set(() {
      stage = VoiceStage.recording;
      isRecording = false;
      transcript = '';
      lines = [];
      unmatched = [];
      errorMessage = '';
      errorNeedsSettings = false;
      processingNote = null;
    });
    soundLevel.value = 0;
    elapsed.value = Duration.zero;
    _menu ??= _loadMenuWithLogging();

    try {
      // The permission dialog may take a while; starting the mic must not.
      await _recorder.ensureMicrophonePermission();
      await _recorder.start().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      voiceLog('Microphone did not start within 8 s');
      await _recorder.cancel();
      _fail('The microphone didn\'t start. Tap "Record again".');
      return;
    } catch (e, stack) {
      voiceLog('Could not start recording', e, stack);
      _fail(friendlyError(e), needsSettings: e is VoiceException && e.needsSettings);
      return;
    }
    if (_disposed) return;

    HapticFeedback.selectionClick(); // "recording now"
    _levels = _recorder.levels().listen((level) {
      // Ease toward each reading so the animation glides instead of jittering.
      soundLevel.value = soundLevel.value * 0.6 + level * 0.4;
    });
    // `tick` counts every elapsed period, even ones a busy frame skipped.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final time = const Duration(milliseconds: 100) * timer.tick;
      elapsed.value = time;
      if (time >= VoiceRecorder.maxDuration) {
        voiceLog('Reached ${VoiceRecorder.maxDuration.inSeconds} s: sending automatically');
        finishRecording();
      }
    });
    _set(() => isRecording = true);
    voiceLog('Stage: recording');
  }

  /// Stops recording and lets Gemini listen to it ("Send", tapping the mic
  /// again, or the time limit). Extra taps are ignored.
  Future<void> finishRecording() async {
    if (_disposed || stage != VoiceStage.recording || !isRecording) return;
    _stopRecordingUi();
    _set(() {
      isRecording = false;
      stage = VoiceStage.processing;
      processingNote = null;
    });
    HapticFeedback.lightImpact(); // "got it"
    try {
      final recording = await _recorder.stop();
      await _process(recording);
    } catch (e, stack) {
      voiceLog('Recording failed', e, stack);
      _fail(friendlyError(e));
    }
  }

  void _stopRecordingUi() {
    _ticker?.cancel();
    _ticker = null;
    _levels?.cancel();
    _levels = null;
    soundLevel.value = 0;
  }

  /// Available items from open, approved stalls — the only things the
  /// customer can actually order right now.
  static Future<List<FoodModel>> _loadOrderableMenu() async {
    final stalls = await CatalogService.customerStalls().first;
    final openStallIds = stalls.where((s) => s.isOpen).map((s) => s.id).toSet();
    final items = await CatalogService.availableItems().first;
    return items.where((f) => openStallIds.contains(f.stallId)).toList();
  }

  Future<List<FoodModel>> _loadMenuWithLogging() async {
    final watch = Stopwatch()..start();
    try {
      final menu = await _menuLoader();
      voiceLog('Menu loaded: ${menu.length} orderable items from open stalls (${watch.elapsedMilliseconds} ms)');
      return menu;
    } catch (e, stack) {
      voiceLog('Menu failed to load', e, stack);
      _menu = null; // let "Record again" reload it instead of reusing the failure
      rethrow;
    }
  }

  /// Opens the app's system settings (microphone blocked).
  Future<void> openSettings() => _recorder.openSettings();

  Future<void> _process(VoiceRecording recording) async {
    voiceLog('Stage: processing ${recording.duration.inMilliseconds} ms of audio');
    _parser.onRetry = (note) => _set(() => processingNote = note);
    final menu = await (_menu ??= _loadMenuWithLogging());
    final result = await _parser.parseAudio(recording, menu);
    voiceLog('Heard "${result.transcript}" → ${result.lines.map((l) => '${l.quantity}x ${l.food.name}').join(', ')}'
        '${result.unmatched.isEmpty ? '' : ' | not on menu: ${result.unmatched.join(', ')}'}');
    transcript = result.transcript;
    if (result.lines.isEmpty) {
      if (result.transcript.isEmpty) {
        _fail('I couldn\'t hear an order. Hold the mic closer and say it again.');
      } else {
        final missing = result.unmatched.isEmpty ? '' : ' (${result.unmatched.join(', ')})';
        _fail('Couldn\'t find that on any open stall\'s menu$missing. Try saying the item name as it appears on the menu.');
      }
      return;
    }
    _set(() {
      lines = result.lines;
      unmatched = result.unmatched;
      stage = VoiceStage.confirm;
    });
    voiceLog('Stage: confirm (${lines.length} lines)');
  }

  void _fail(String message, {bool needsSettings = false}) {
    if (_disposed) return; // sheet already closed
    voiceLog('Stage: error: $message');
    _stopRecordingUi();
    _set(() {
      isRecording = false;
      errorMessage = message;
      errorNeedsSettings = needsSettings;
      stage = VoiceStage.error;
    });
  }

  void changeQuantity(int index, int delta) => _set(() {
        final next = lines[index].quantity + delta;
        if (next < 1) {
          lines = [...lines]..removeAt(index);
        } else {
          lines = [...lines]..[index] = lines[index].copyWith(quantity: next.clamp(1, VoiceOrderParser.maxQuantity));
        }
      });

  /// Adds the confirmed items to the cart; returns how many were added.
  Future<int> addToCart(CartProvider cart) async {
    _set(() => isAdding = true);
    try {
      for (final line in lines) {
        await cart.addToCart(line.food, qty: line.quantity);
      }
      voiceLog('Added $itemCount item(s) to the cart');
      return itemCount;
    } catch (e, stack) {
      voiceLog('Adding to cart failed', e, stack);
      rethrow;
    } finally {
      _set(() => isAdding = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopRecordingUi();
    _parser.onRetry = null;
    _recorder.dispose();
    soundLevel.dispose();
    elapsed.dispose();
    super.dispose();
  }
}

/// Voice ordering bottom sheet. Tapping the mic button opens it already
/// recording; tapping "Send" (or the mic again) sends the recording.
class VoiceOrderSheet extends StatelessWidget {
  final VoiceOrderController controller;
  const VoiceOrderSheet({super.key, required this.controller});

  /// Starts recording and opens the sheet. Resolves to the number of items
  /// added to the cart, or null if the customer closed it.
  static Future<int?> show(BuildContext context, VoiceOrderController controller) {
    controller.start();
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => VoiceOrderSheet(controller: controller),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              // Scrolls on short screens / large text instead of overflowing.
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      // Fade + slight rise between stages instead of a hard cut.
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: switch (controller.stage) {
                        VoiceStage.recording => _RecordingView(key: const ValueKey('record'), controller: controller),
                        VoiceStage.processing => _ProcessingView(key: const ValueKey('process'), note: controller.processingNote),
                        VoiceStage.confirm => _ConfirmView(key: const ValueKey('confirm'), controller: controller),
                        VoiceStage.error => _ErrorView(key: const ValueKey('error'), controller: controller),
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Stages
// -----------------------------------------------------------------------------

class _RecordingView extends StatelessWidget {
  final VoiceOrderController controller;
  const _RecordingView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final recording = controller.isRecording;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            recording ? 'Recording…' : 'Getting the mic ready…',
            key: ValueKey(recording),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Say your order in English, Tagalog or Bisaya', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: recording ? controller.finishRecording : null,
          child: _RecordingMic(active: recording, level: controller.soundLevel),
        ),
        const SizedBox(height: 16),
        _RecordingTimer(elapsed: controller.elapsed, active: recording),
        const SizedBox(height: 16),
        Text(
          'Try: “Duha ka cheese burger ug usa ka fries”',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: 'Send', onPressed: recording ? controller.finishRecording : null),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// "● 0:04 / 0:20" with a thin progress bar toward the time limit.
class _RecordingTimer extends StatelessWidget {
  final ValueListenable<Duration> elapsed;
  final bool active;
  const _RecordingTimer({required this.elapsed, required this.active});

  static String _format(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: elapsed,
      builder: (context, time, _) {
        final progress = (time.inMilliseconds / VoiceRecorder.maxDuration.inMilliseconds).clamp(0.0, 1.0);
        return Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BlinkingDot(active: active),
                const SizedBox(width: 8),
                Text(
                  '${_format(time)} / ${_format(VoiceRecorder.maxDuration)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.grey.shade200,
                  color: progress > 0.8 ? Colors.red : AppTheme.secondaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final bool active;
  const _BlinkingDot({required this.active});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: widget.active ? Colors.red : Colors.grey.shade400, shape: BoxShape.circle),
    );
    return widget.active ? FadeTransition(opacity: Tween(begin: 0.3, end: 1.0).animate(_blink), child: dot) : dot;
  }
}

/// Yellow mic that "breathes" while recording: two soft rings ripple
/// outwards continuously, and an inner glow swells with the voice.
/// Honours the system "reduce motion" setting.
class _RecordingMic extends StatefulWidget {
  final bool active;
  final ValueListenable<double> level;
  const _RecordingMic({required this.active, required this.level});

  @override
  State<_RecordingMic> createState() => _RecordingMicState();
}

class _RecordingMicState extends State<_RecordingMic> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_RecordingMic oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.active && !reduceMotion) {
      if (!_ripple.isAnimating) _ripple.repeat();
    } else {
      _ripple.stop();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    const button = 80.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Two rings, half a cycle apart, expanding and fading out.
          if (widget.active)
            for (final offset in [0.0, 0.5])
              AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) {
                  final t = (_ripple.value + offset) % 1.0;
                  final grown = button + (size - button) * Curves.easeOut.transform(t);
                  return Opacity(
                    opacity: (1 - t) * 0.35,
                    child: Container(
                      width: grown,
                      height: grown,
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.6), shape: BoxShape.circle),
                    ),
                  );
                },
              ),
          // Glow that follows the (smoothed) loudness of the voice.
          ValueListenableBuilder<double>(
            valueListenable: widget.level,
            builder: (context, level, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: button + 36 * level,
              height: button + 36 * level,
              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.35), shape: BoxShape.circle),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: button,
            height: button,
            decoration: BoxDecoration(
              color: widget.active ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: const Icon(Icons.mic, size: 38, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

/// While Gemini listens to the recording: the paddling boat as the loader.
class _ProcessingView extends StatelessWidget {
  final String? note;
  const _ProcessingView({super.key, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const PremiumPaddlingBoatAnimation(size: 88),
          const SizedBox(height: 20),
          const Text('Listening to your order…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Matching it to the open stalls\' menus', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          const SizedBox(
            width: 160,
            child: LinearProgressIndicator(minHeight: 3, color: AppTheme.primaryColor, backgroundColor: Color(0xFFEEEEEE)),
          ),
          const SizedBox(height: 12),
          // Retry notes fade in only when Gemini is busy.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              note ?? '',
              key: ValueKey(note),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ConfirmView extends StatelessWidget {
  final VoiceOrderController controller;
  const _ConfirmView({super.key, required this.controller});

  Future<void> _confirm(BuildContext context) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    try {
      final added = await controller.addToCart(cart);
      if (context.mounted) Navigator.pop(context, added);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add to cart. ${friendlyError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = controller.lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Confirm your order',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          controller.transcript.isEmpty ? '' : 'Heard: “${controller.transcript}”',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: lines.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, i) => _LineRow(
              line: lines[i],
              onMinus: controller.isAdding ? null : () => controller.changeQuantity(i, -1),
              onPlus: controller.isAdding ? null : () => controller.changeQuantity(i, 1),
            ),
          ),
        ),
        if (controller.unmatched.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Not on any open menu: ${controller.unmatched.join(', ')}', style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '${controller.itemCount} item${controller.itemCount == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            Text(
              formatPeso(controller.total),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          label: lines.isEmpty ? 'Nothing to add' : 'Add to cart',
          isLoading: controller.isAdding,
          onPressed: lines.isEmpty || controller.isAdding ? null : () => _confirm(context),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: controller.isAdding ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton.icon(
          onPressed: controller.isAdding ? null : controller.start,
          icon: const Icon(Icons.mic_none, color: Colors.black54, size: 18),
          label: const Text('Record again', style: TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  final VoiceOrderLine line;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const _LineRow({required this.line, this.onMinus, this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppNetworkImage(url: line.food.imageUrl, width: 48, height: 48),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${line.food.stallName} · ${formatPeso(line.food.price)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Same stepper style as the cart
          _StepButton(icon: line.quantity == 1 ? Icons.delete_outline : Icons.remove, onTap: onMinus),
          SizedBox(
            width: 36,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          _StepButton(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black87, width: 1),
        ),
        child: Icon(icon, size: 18, color: onTap == null ? Colors.grey : Colors.black),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoiceOrderController controller;
  const _ErrorView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.mic_off_outlined, color: Colors.orange, size: 34),
        ),
        const SizedBox(height: 20),
        const Text('Let\'s try that again', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          controller.errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        if (controller.transcript.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Heard: “${controller.transcript}”', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 24),
        if (controller.errorNeedsSettings) ...[
          _PrimaryButton(label: 'Open settings', onPressed: controller.openSettings),
          TextButton(
            onPressed: controller.start,
            child: const Text('Try again', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ] else
          _PrimaryButton(label: 'Record again', onPressed: controller.start),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  const _PrimaryButton({required this.label, this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
            ),
    );
  }
}
