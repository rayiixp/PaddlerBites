import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import '../core/voice_log.dart';
import '../models/models.dart';
import 'voice_recorder.dart';

/// Gemini model that listens to the recording. Override at build time with
/// `--dart-define=GEMINI_MODEL=<model>` when Google retires this one.
/// (Gemini 1.5 models were shut down in 2025; current Flash models take
/// audio input natively.)
const String kVoiceOrderModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.5-flash');

/// Used after the main model is busy (503/429/timeouts).
const String kVoiceOrderFallbackModel = String.fromEnvironment('GEMINI_FALLBACK_MODEL', defaultValue: 'gemini-3.6-flash');

/// Gemini API key, read at build time from `.env` (git-ignored):
///   flutter run --dart-define-from-file=.env
/// When empty, the parser uses Firebase AI Logic instead, which needs no key.
const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// One recognised menu item and how many the customer asked for.
class VoiceOrderLine {
  final FoodModel food;
  final int quantity;
  const VoiceOrderLine({required this.food, required this.quantity});

  VoiceOrderLine copyWith({int? quantity}) => VoiceOrderLine(food: food, quantity: quantity ?? this.quantity);
}

class VoiceOrderResult {
  /// What Gemini heard, written out (shown to the customer to confirm).
  final String transcript;
  final List<VoiceOrderLine> lines;

  /// Things the customer asked for that aren't on any open stall's menu.
  final List<String> unmatched;

  const VoiceOrderResult({required this.transcript, required this.lines, this.unmatched = const []});
}

/// Sends the customer's recorded voice straight to Gemini, which listens to
/// it and maps it to menu items: no on-phone speech-to-text, so accents and
/// mixed English/Tagalog/Bisaya ("usa ka burger") are understood from the
/// audio itself. Calls Gemini directly with [kGeminiApiKey] when set,
/// otherwise through Firebase AI Logic.
class VoiceOrderParser {
  static const int maxQuantity = 20;

  /// Kept short on purpose: every word adds latency. Tested with English
  /// and Bisaya recordings ("duha ka cheese burger ug usa ka fries").
  static const String systemPrompt = '''
You take food orders by voice at a university campus in the Philippines. Listen to the attached audio: the customer may speak English, Tagalog, Bisaya or a mix. Match what they ask for to items from the menu, allowing for accents and mispronunciations (e.g. "burger" -> "Cheese Burger").
Numbers: 1 one/isa/isang/usa/uno; 2 two/dalawa/dalawang/duha/dos; 3 three/tatlo/tatlong/tulo/tres; 4 four/apat/upat; 5 five/lima; 6 six/anim/unom; 7 seven/pito; 8 eight/walo; 9 nine/siyam; 10 ten/sampu/napulo.
Ignore counting and filler words: ka, ka buok, kabuok, buok, piraso, pcs, palihug, please, pls, gusto ko, I want.
Rules: use only menuId values from the menu; quantity defaults to 1; add up repeated items; if a stall is named, prefer its item; put anything not on the menu in "unmatched"; "transcript" is what the customer said, written as heard. If there is no speech, return an empty transcript and empty lists.
''';

  /// Short ids (M1, M2, ...) keep the prompt small and are easy for the model to copy exactly.
  static Map<String, FoodModel> indexMenu(List<FoodModel> menu) => {
        for (var i = 0; i < menu.length; i++) 'M${i + 1}': menu[i],
      };

  /// The text sent alongside the audio.
  static String buildMenuPrompt(Map<String, FoodModel> menu) {
    final lines = menu.entries.map((e) {
      final food = e.value;
      return '${e.key} | ${food.name} | ${food.stallName}${food.category.isEmpty ? '' : ' | ${food.category}'}';
    }).join('\n');
    return 'MENU (menuId | name | stall | category):\n$lines';
  }

  /// Validates the model's JSON against the menu: unknown ids are dropped,
  /// repeated items are merged and quantities are clamped to 1–[maxQuantity].
  static VoiceOrderResult interpret(String json, Map<String, FoodModel> menu) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final quantities = <String, int>{};
    for (final raw in (data['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final id = '${raw['menuId']}'.trim().toUpperCase();
      if (!menu.containsKey(id)) continue;
      final qty = (raw['quantity'] as num?)?.round() ?? 1;
      quantities[id] = ((quantities[id] ?? 0) + (qty < 1 ? 1 : qty)).clamp(1, maxQuantity);
    }
    return VoiceOrderResult(
      transcript: '${data['transcript'] ?? ''}'.trim(),
      lines: [for (final e in quantities.entries) VoiceOrderLine(food: menu[e.key]!, quantity: e.value)],
      unmatched: [for (final u in (data['unmatched'] as List? ?? const [])) if ('$u'.trim().isNotEmpty) '$u'.trim()],
    );
  }

  VoiceOrderParser({http.Client? httpClient, String? apiKey})
      : _httpClient = httpClient,
        _apiKey = apiKey ?? kGeminiApiKey;

  final http.Client? _httpClient;
  final String _apiKey;

  /// Called before each retry with a short note for the UI.
  void Function(String note)? onRetry;

  /// Attempts in order: the main model, the same model again, then the
  /// fallback model. Only temporary failures (503/429/5xx, timeouts,
  /// network) move on to the next attempt.
  static const _attempts = [
    (model: kVoiceOrderModel, delay: Duration.zero),
    (model: kVoiceOrderModel, delay: Duration(milliseconds: 700)),
    (model: kVoiceOrderFallbackModel, delay: Duration(milliseconds: 1200)),
  ];

  /// Per-attempt limit; listening to a short order takes about 5 s.
  static const attemptTimeout = Duration(seconds: 20);

  final _random = math.Random();

  /// Lets Gemini listen to [recording] and map it to items from [menu].
  Future<VoiceOrderResult> parseAudio(VoiceRecording recording, List<FoodModel> menu) async {
    if (menu.isEmpty) throw VoiceException('No stalls are open right now, so there\'s nothing to order.');

    final indexed = indexMenu(menu);
    final menuPrompt = buildMenuPrompt(indexed);
    final menuIds = indexed.keys.toList();
    voiceLog('Sending ${(recording.bytes.length / 1024).toStringAsFixed(1)} KB of ${recording.mimeType} '
        '(${(recording.duration.inMilliseconds / 1000).toStringAsFixed(1)} s) to Gemini · ${menu.length} menu items · '
        '${_apiKey.isNotEmpty ? 'API key from .env (…${_apiKey.length > 4 ? _apiKey.substring(_apiKey.length - 4) : ''})' : 'no API key → Firebase AI Logic'}');

    _GeminiFailure? lastFailure;
    // Models that answered 429 (quota/rate limit): retrying them within a
    // second can't help, so their remaining attempts go to the fallback.
    final quotaExhausted = <String>{};
    for (var i = 0; i < _attempts.length; i++) {
      final attempt = _attempts[i];
      if (quotaExhausted.contains(attempt.model)) {
        voiceLog('Skipping attempt ${i + 1}: ${attempt.model} is over its quota');
        continue;
      }
      if (i > 0) {
        final wait = lastFailure?.retryAfter ?? _withJitter(attempt.delay);
        voiceLog('Retry $i/${_attempts.length - 1} with ${attempt.model} in ${wait.inMilliseconds} ms');
        onRetry?.call(i == 1 ? 'The assistant is busy, trying again…' : 'Still busy, trying a backup assistant…');
        await Future.delayed(wait);
      }
      final watch = Stopwatch()..start();
      try {
        final text = _apiKey.isNotEmpty
            ? await _generateWithApiKey(attempt.model, recording, menuPrompt, menuIds)
            : await _generateWithFirebase(attempt.model, recording, menuPrompt, menuIds);
        voiceLog('Gemini (${attempt.model}) replied in ${watch.elapsedMilliseconds} ms: ${_short(text)}');
        if (text == null || text.trim().isEmpty) throw VoiceException('Couldn\'t understand the order. Please try again.');
        try {
          return interpret(text, indexed);
        } catch (e) {
          voiceLog('Gemini reply was not the expected JSON', e);
          throw VoiceException('Couldn\'t understand the order. Please try again.');
        }
      } on _GeminiFailure catch (failure) {
        voiceLog('Attempt ${i + 1} with ${attempt.model} failed after ${watch.elapsedMilliseconds} ms: '
            '${failure.status ?? '-'} ${failure.detail}');
        if (!failure.retryable) throw VoiceException(failure.userMessage);
        if (failure.status == 429) quotaExhausted.add(attempt.model);
        lastFailure = failure;
      }
    }
    throw VoiceException(lastFailure?.userMessage ?? 'The voice assistant is busy right now. Please try again in a moment.');
  }

  Duration _withJitter(Duration base) =>
      Duration(milliseconds: (base.inMilliseconds * (0.8 + _random.nextDouble() * 0.4)).round());

  static String _short(String? text) {
    if (text == null) return '(no text)';
    final flat = text.replaceAll(RegExp(r'\s+'), ' ');
    return flat.length > 300 ? '${flat.substring(0, 300)}…' : flat;
  }

  /// Strict response shape (Gemini REST schema): menuId can only be one of
  /// the ids we sent, so the model can't invent items.
  static Map<String, dynamic> responseSchema(List<String> menuIds) => {
        'type': 'OBJECT',
        'properties': {
          'transcript': {'type': 'STRING'},
          'items': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'menuId': {'type': 'STRING', 'enum': menuIds},
                'quantity': {'type': 'INTEGER'},
              },
              'required': ['menuId', 'quantity'],
            },
          },
          'unmatched': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
        },
        'required': ['transcript', 'items', 'unmatched'],
      };

  /// Calls the Gemini API directly with [kGeminiApiKey]: audio as inline
  /// data, followed by the menu text.
  Future<String?> _generateWithApiKey(String model, VoiceRecording recording, String menuPrompt, List<String> menuIds,
      {bool minimalThinking = true}) async {
    final client = _httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt}
                ]
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {
                      'inline_data': {'mime_type': recording.mimeType, 'data': base64Encode(recording.bytes)}
                    },
                    {'text': menuPrompt},
                  ],
                }
              ],
              'generationConfig': {
                'temperature': 0,
                'responseMimeType': 'application/json',
                'responseSchema': responseSchema(menuIds),
                // Matching a short order needs no reasoning; default
                // "thinking" is slower and the part that returns 503 under load.
                if (minimalThinking) 'thinkingConfig': {'thinkingLevel': 'minimal'},
              },
            }),
          )
          .timeout(attemptTimeout);

      voiceLog('Gemini HTTP ${response.statusCode} ($model)');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) return null;
        final parts = (candidates.first['content']?['parts'] as List?) ?? const [];
        return parts.map((p) => p is Map ? (p['text'] ?? '') : '').join();
      }
      // A model override that doesn't support minimal thinking: ask again without it.
      if (response.statusCode == 400 && minimalThinking && response.body.toLowerCase().contains('thinking')) {
        voiceLog('$model does not support minimal thinking; retrying without it');
        return _generateWithApiKey(model, recording, menuPrompt, menuIds, minimalThinking: false);
      }
      throw _GeminiFailure.fromStatus(response.statusCode, response.body, response.headers['retry-after']);
    } on _GeminiFailure {
      rethrow;
    } on TimeoutException {
      throw _GeminiFailure(null, 'timed out after ${attemptTimeout.inSeconds} s', retryable: true,
          userMessage: 'The voice assistant took too long to answer. Please try again.');
    } catch (e) {
      throw _GeminiFailure(null, '$e', retryable: true,
          userMessage: 'Couldn\'t reach the voice assistant. Check your connection and try again.');
    } finally {
      if (_httpClient == null) client.close();
    }
  }

  /// Calls Gemini through Firebase AI Logic (no key in the app).
  Future<String?> _generateWithFirebase(String model, VoiceRecording recording, String menuPrompt, List<String> menuIds) async {
    final generativeModel = FirebaseAI.googleAI().generativeModel(
      model: model,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0,
        responseMimeType: 'application/json',
        thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.minimal),
        responseSchema: Schema.object(properties: {
          'transcript': Schema.string(),
          'items': Schema.array(
            items: Schema.object(properties: {
              'menuId': Schema.enumString(enumValues: menuIds),
              'quantity': Schema.integer(),
            }),
          ),
          'unmatched': Schema.array(items: Schema.string()),
        }),
      ),
    );
    try {
      final response = await generativeModel
          .generateContent([
            Content.multi([InlineDataPart(recording.mimeType, recording.bytes), TextPart(menuPrompt)]),
          ])
          .timeout(attemptTimeout);
      return response.text;
    } on TimeoutException {
      throw _GeminiFailure(null, 'timed out after ${attemptTimeout.inSeconds} s', retryable: true,
          userMessage: 'The voice assistant took too long to answer. Please try again.');
    } on FirebaseAIException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('not been used') || message.contains('disabled') || message.contains('not enabled')) {
        throw _GeminiFailure(null, e.message, retryable: false,
            userMessage: 'Voice ordering isn\'t set up yet. Ask the admin to enable Firebase AI Logic.');
      }
      final temporary = ['503', '429', '500', 'unavailable', 'overloaded', 'high demand', 'resource_exhausted', 'deadline']
          .any(message.contains);
      throw _GeminiFailure(null, e.message, retryable: temporary,
          userMessage: temporary
              ? 'The voice assistant is busy right now. Please try again in a moment.'
              : 'Couldn\'t reach the voice assistant. Please try again.');
    }
  }
}

/// A failed Gemini attempt; [retryable] ones move on to the next attempt.
class _GeminiFailure implements Exception {
  final int? status;
  final String detail;
  final bool retryable;
  final String userMessage;
  final Duration? retryAfter;

  _GeminiFailure(this.status, this.detail, {required this.retryable, required this.userMessage, this.retryAfter});

  factory _GeminiFailure.fromStatus(int status, String body, String? retryAfterHeader) {
    final seconds = int.tryParse(retryAfterHeader ?? '');
    // Honour short Retry-After hints only; longer waits would stall the sheet.
    final retryAfter = seconds != null && seconds > 0 && seconds <= 5 ? Duration(seconds: seconds) : null;
    final detail = body.replaceAll(RegExp(r'\s+'), ' ');
    final short = detail.length > 200 ? '${detail.substring(0, 200)}…' : detail;
    switch (status) {
      case 429:
      case 500:
      case 502:
      case 503:
      case 504:
        return _GeminiFailure(status, short, retryable: true, retryAfter: retryAfter,
            userMessage: 'The voice assistant is busy right now. Please try again in a moment.');
      case 400 when body.contains('API key'):
      case 401:
      case 403:
        return _GeminiFailure(status, short, retryable: false,
            userMessage: 'Voice ordering isn\'t set up correctly (the Gemini API key was rejected).');
      case 404:
        return _GeminiFailure(status, short, retryable: true, // the fallback model may still work
            userMessage: 'The voice assistant model isn\'t available. Update GEMINI_MODEL.');
      default:
        return _GeminiFailure(status, short, retryable: false,
            userMessage: 'The voice assistant had a problem ($status). Please try again.');
    }
  }
}
