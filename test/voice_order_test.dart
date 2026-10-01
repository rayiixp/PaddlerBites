import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paddlerbites/models/models.dart';
import 'package:paddlerbites/services/voice_order_parser.dart';
import 'package:paddlerbites/services/voice_recorder.dart';
import 'package:paddlerbites/widgets/voice_order_sheet.dart';

final _burger = FoodModel(id: 'b1', stallId: 's1', name: 'Cheese Burger', stallName: 'Snackpreneurs', price: 30);
final _fries = FoodModel(id: 'f1', stallId: 's1', name: 'Fries', stallName: 'Snackpreneurs', price: 35);
final _menu = VoiceOrderParser.indexMenu([_burger, _fries]); // M1 = burger, M2 = fries

final _clip = VoiceRecording(
  bytes: Uint8List(3200),
  mimeType: VoiceRecorder.mimeType,
  duration: const Duration(seconds: 2),
);

/// Microphone stand-in: records instantly, the test controls loudness.
class FakeRecorder extends VoiceRecorder {
  final levelsController = StreamController<double>.broadcast();
  int starts = 0;
  int stops = 0;
  bool disposed = false;

  @override
  Future<void> ensureMicrophonePermission() async {} // granted

  @override
  Future<void> start() async => starts++;

  @override
  Stream<double> levels() => levelsController.stream;

  @override
  Future<VoiceRecording> stop() async {
    stops++;
    return _clip;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await levelsController.close();
  }
}

/// Microphone permanently denied.
class BlockedRecorder extends FakeRecorder {
  @override
  Future<void> start() async =>
      throw VoiceException('Microphone access is turned off for PaddlerBites.', needsSettings: true);
}

/// Recorder that never starts.
class HangingRecorder extends FakeRecorder {
  @override
  Future<void> start() => Completer<void>().future;
}

/// Gemini stand-in returning a fixed parse; [gate] lets a test hold it in "processing".
class FakeParser extends VoiceOrderParser {
  VoiceRecording? heard;
  Completer<void>? gate;
  @override
  Future<VoiceOrderResult> parseAudio(VoiceRecording recording, List<FoodModel> menu) async {
    heard = recording;
    await gate?.future;
    return VoiceOrderResult(
      transcript: 'duha ka cheese burger ug usa ka fries',
      lines: [
        VoiceOrderLine(food: _burger, quantity: 2),
        VoiceOrderLine(food: _fries, quantity: 1),
      ],
      unmatched: const ['pizza'],
    );
  }
}

Future<void> _pumpSheet(WidgetTester tester, VoiceOrderController controller) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: VoiceOrderSheet(controller: controller)),
  ),
);

void main() {
  group('parser output validation', () {
    test('maps ids to menu items, keeps quantities and the transcript', () {
      final r = VoiceOrderParser.interpret(
        '{"transcript":"duha ka cheese burger ug usa ka fries",'
        '"items":[{"menuId":"M1","quantity":2},{"menuId":"M2","quantity":1}],"unmatched":[]}',
        _menu,
      );
      expect(r.transcript, 'duha ka cheese burger ug usa ka fries');
      expect(r.lines.map((l) => '${l.quantity}x ${l.food.name}'), ['2x Cheese Burger', '1x Fries']);
    });

    test('merges repeats, drops unknown ids, clamps quantities', () {
      final r = VoiceOrderParser.interpret(
        '{"items":[{"menuId":"m1","quantity":1},{"menuId":"M1","quantity":2},{"menuId":"M9","quantity":1},'
        '{"menuId":"M2","quantity":500},{"menuId":"M2","quantity":0}],"unmatched":["pizza"," "]}',
        _menu,
      );
      expect(r.lines.firstWhere((l) => l.food.id == 'b1').quantity, 3);
      expect(r.lines.firstWhere((l) => l.food.id == 'f1').quantity, VoiceOrderParser.maxQuantity);
      expect(r.lines, hasLength(2)); // M9 isn't on the menu
      expect(r.unmatched, ['pizza']);
    });

    test('menu prompt lists items with their stalls', () {
      expect(VoiceOrderParser.buildMenuPrompt(_menu), contains('M1 | Cheese Burger | Snackpreneurs'));
    });

    test('system prompt teaches Bisaya and Tagalog numbers', () {
      for (final word in ['usa', 'isa', 'duha', 'dalawa', 'tulo', 'tatlo', 'napulo', 'sampu', 'ka buok']) {
        expect(VoiceOrderParser.systemPrompt, contains(word));
      }
    });
  });

  testWidgets('tap → timer → Send → loader → editable confirmation', (tester) async {
    final recorder = FakeRecorder();
    final parser = FakeParser()..gate = Completer();
    final controller = VoiceOrderController(
      recorder: recorder,
      parser: parser,
      menuLoader: () async => [_burger, _fries],
    );
    await _pumpSheet(tester, controller);

    controller.start(); // what the mic button does, alongside opening the sheet
    await tester.pump();
    await tester.pump();
    expect(recorder.starts, 1, reason: 'recording starts without a second tap');
    expect(find.text('Recording…'), findsOneWidget);
    expect(find.text('0:00 / 0:20'), findsOneWidget);

    recorder.levelsController.add(0.8);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(controller.soundLevel.value, greaterThan(0));
    expect(find.text('0:02 / 0:20'), findsOneWidget); // recording timer

    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorder.stops, 1);
    expect(find.text('Listening to your order…'), findsOneWidget); // loader while Gemini works

    parser.gate!.complete();
    await tester.pumpAndSettle();
    expect(parser.heard, same(_clip), reason: 'the audio itself goes to Gemini');
    expect(find.text('Confirm your order'), findsOneWidget);
    expect(find.text('Heard: “duha ka cheese burger ug usa ka fries”'), findsOneWidget);
    expect(find.text('Not on any open menu: pizza'), findsOneWidget);
    expect(find.text('₱95.00'), findsOneWidget); // 2×30 + 35

    // Remove the fries with the stepper; total updates.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Fries'), findsNothing);
    expect(find.text('₱60.00'), findsOneWidget);

    controller.dispose();
    expect(recorder.disposed, isTrue, reason: 'closing the sheet releases the mic');
  });

  testWidgets('tapping the mic again stops and sends; extra taps are ignored', (tester) async {
    final recorder = FakeRecorder();
    final parser = FakeParser()..gate = Completer();
    final controller = VoiceOrderController(
      recorder: recorder,
      parser: parser,
      menuLoader: () async => [_burger, _fries],
    );
    await _pumpSheet(tester, controller);

    controller.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.mic));
    controller.finishRecording(); // a nervous double tap
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorder.stops, 1);
    expect(find.text('Listening to your order…'), findsOneWidget);

    parser.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Confirm your order'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('stop before the mic is ready does nothing', (tester) async {
    final recorder = HangingRecorder();
    final controller = VoiceOrderController(
      recorder: recorder,
      parser: FakeParser(),
      menuLoader: () async => [_burger],
    );
    await _pumpSheet(tester, controller);
    controller.start();
    await tester.pump();
    expect(find.text('Getting the mic ready…'), findsOneWidget);
    await controller.finishRecording();
    await tester.pump();
    expect(recorder.stops, 0);
    expect(controller.stage, VoiceStage.recording);
    controller.dispose();
    await tester.pump(const Duration(seconds: 9)); // let the start timeout expire harmlessly
  });

  testWidgets('stops and sends automatically at the time limit', (tester) async {
    final recorder = FakeRecorder();
    final controller = VoiceOrderController(
      recorder: recorder,
      parser: FakeParser(),
      menuLoader: () async => [_burger, _fries],
    );
    await _pumpSheet(tester, controller);
    controller.start();
    await tester.pump();
    expect(find.text('Send'), findsOneWidget);

    await tester.pump(VoiceRecorder.maxDuration + const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(recorder.stops, 1);
    expect(find.text('Confirm your order'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('never stays on "Getting the mic ready…": gives up after 8 s', (tester) async {
    final controller = VoiceOrderController(
      recorder: HangingRecorder(),
      parser: FakeParser(),
      menuLoader: () async => [_burger],
    );
    await _pumpSheet(tester, controller);
    controller.start();
    await tester.pump();
    expect(find.text('Getting the mic ready…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Getting the mic ready…'), findsNothing);
    expect(find.textContaining("The microphone didn't start"), findsOneWidget);
    expect(find.text('Record again'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('blocked microphone shows an Open settings button', (tester) async {
    final controller = VoiceOrderController(
      recorder: BlockedRecorder(),
      parser: FakeParser(),
      menuLoader: () async => [_burger],
    );
    await _pumpSheet(tester, controller);
    await controller.start();
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.textContaining('Microphone access is turned off'), findsOneWidget);
    controller.dispose();
  });
}
