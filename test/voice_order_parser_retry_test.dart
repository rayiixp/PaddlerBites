import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paddlerbites/models/models.dart';
import 'package:paddlerbites/services/voice_order_parser.dart';
import 'package:paddlerbites/services/voice_recorder.dart';

final _clip = VoiceRecording(bytes: Uint8List.fromList([1, 2, 3, 4]), mimeType: 'audio/wav', duration: const Duration(seconds: 2));
final _menu = [FoodModel(id: 'b1', stallId: 's1', name: 'Cheese Burger', stallName: 'Snackpreneurs', price: 30)];

http.Response _ok(String json) => http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': json}
              ]
            }
          }
        ]
      }),
      200,
    );

http.Response _error(int status, String message) =>
    http.Response(jsonEncode({'error': {'code': status, 'message': message}}), status);

void main() {
  test('503 twice → retries, then succeeds on the fallback model', () async {
    final models = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      models.add(request.url.pathSegments.last.split(':').first);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return models.length < 3
          ? _error(503, 'This model is currently experiencing high demand.')
          : _ok('{"items":[{"menuId":"M1","quantity":1}],"unmatched":[]}');
    });
    final notes = <String>[];
    final parser = VoiceOrderParser(httpClient: client, apiKey: 'test-key')..onRetry = notes.add;

    final result = await parser.parseAudio(_clip, _menu);

    expect(result.lines.single.food.name, 'Cheese Burger');
    expect(models, [kVoiceOrderModel, kVoiceOrderModel, kVoiceOrderFallbackModel]);
    expect(notes, hasLength(2));
    // Every attempt asks for minimal thinking (fast, and not the overloaded path).
    for (final body in bodies) {
      expect(body['generationConfig']['thinkingConfig'], {'thinkingLevel': 'minimal'});
      // The recording itself travels inline, base64-encoded, next to the menu.
      final parts = body['contents'][0]['parts'] as List;
      expect(parts.first['inline_data'], {'mime_type': 'audio/wav', 'data': base64Encode([1, 2, 3, 4])});
      expect(parts.last['text'], contains('Cheese Burger'));
    }
  });

  test('gives up with a friendly message after all attempts are busy', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return _error(503, 'high demand');
    });
    final parser = VoiceOrderParser(httpClient: client, apiKey: 'test-key');
    await expectLater(
      parser.parseAudio(_clip, _menu),
      throwsA(isA<VoiceException>().having((e) => e.message, 'message', contains('busy'))),
    );
    expect(calls, 3); // first try + 2 retries
  });

  test('a rejected API key is not retried', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return _error(400, 'API key not valid. Please pass a valid API key.');
    });
    final parser = VoiceOrderParser(httpClient: client, apiKey: 'bad-key');
    await expectLater(parser.parseAudio(_clip, _menu), throwsA(isA<VoiceException>()));
    expect(calls, 1);
  });

  test('model without minimal thinking → same request again without thinkingConfig', () async {
    final thinking = <Object?>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      thinking.add(body['generationConfig']['thinkingConfig']);
      return thinking.length == 1
          ? _error(400, 'Thinking level MINIMAL is not supported for this model.')
          : _ok('{"items":[{"menuId":"M1","quantity":2}],"unmatched":[]}');
    });
    final result = await VoiceOrderParser(httpClient: client, apiKey: 'k').parseAudio(_clip, _menu);
    expect(result.lines.single.quantity, 2);
    expect(thinking, [
      {'thinkingLevel': 'minimal'},
      null,
    ]);
  });

  test('429 quota on the main model → goes straight to the fallback model', () async {
    final models = <String>[];
    final client = MockClient((request) async {
      final model = request.url.pathSegments.last.split(':').first;
      models.add(model);
      return model == kVoiceOrderModel
          ? _error(429, 'You exceeded your current quota.')
          : _ok('{"items":[{"menuId":"M1","quantity":1}],"unmatched":[]}');
    });
    final result = await VoiceOrderParser(httpClient: client, apiKey: 'k').parseAudio(_clip, _menu);
    expect(result.lines, hasLength(1));
    expect(models, [kVoiceOrderModel, kVoiceOrderFallbackModel]); // no pointless second try
  });
}
