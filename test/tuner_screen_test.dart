import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/tuner/session_tuning_gate.dart';
import 'package:ostinato/app/tuner/tuner_analysis.dart';
import 'package:ostinato/app/tuner/tuner_check_memory.dart';
import 'package:ostinato/app/tuner/tuner_controller.dart';
import 'package:ostinato/app/tuner/tuner_guidance.dart';
import 'package:ostinato/app/tuner/tuner_screen.dart';
import 'package:ostinato/app/tuner/tunings.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

const sr = 44100;

/// Scripted analyzer: returns the queued outcomes in order.
final class _Script {
  final List<TunerAnalysis> queue = [];
  int calls = 0;

  Future<TunerAnalysis> call(
    List<double> samples,
    int rate,
    double floor,
    PreciseTunerProfile profile,
  ) async {
    calls++;
    return queue.isEmpty
        ? const TunerAnalysis.refused(TunerRefusal.insufficientSamples)
        : queue.removeAt(0);
  }
}

TunerAnalysis heard(double hz, {bool confident = true}) =>
    TunerAnalysis.reading(TunerPitch(f0Hz: hz, confident: confident));

void main() {
  late FakeAudioSource source;
  late _Script script;
  late TunerCheckMemory memory;
  late TunerController controller;

  setUp(() {
    source = FakeAudioSource();
    script = _Script();
    memory = TunerCheckMemory();
    controller = TunerController(
      source: source,
      analyzer: script.call,
      memory: memory,
    );
  });

  tearDown(() async {
    controller.dispose();
    await source.dispose();
  });

  /// Calibrate, then feed 0.25 s chunks; each chunk past the buffer
  /// half-fill can trigger one analysis.
  Future<void> run(int chunks) async {
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    source.pushChunk(List<double>.filled(sr, 0.0005));
    for (var i = 0; i < chunks; i++) {
      source.pushChunk(List<double>.filled(sr ~/ 4, 0.001));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('calibrates, listens and applies the guidance rules', () async {
    script.queue.addAll([
      heard(midiToHz(45) * 0.99), // A string about −17 cents
    ]);
    await run(4);
    expect(controller.phase, TunerPhase.listening);
    expect(script.calls, greaterThan(0));
    expect(controller.readout.kind, TunerReadoutKind.measured);
    expect(controller.readout.stringIndex, 1);
    expect(controller.readout.direction, TuneDirection.tighten);
    expect(controller.session.states[1], StringTuneState.low);
    expect(controller.trace, isNotEmpty);
    expect(memory.today?.presetId, 'guitar.standard');
  });

  test('two in-tune readings tick a string; the screen state stays', () async {
    script.queue.addAll([heard(midiToHz(40)), heard(midiToHz(40))]);
    await run(8);
    expect(controller.session.states[0], StringTuneState.inTune);
    expect(controller.session.focus, 1);
    expect(memory.today!.inTune, 1);
    expect(memory.today!.notInTune, 5);
  });

  test('a waiting buffer keeps the last readout', () async {
    script.queue.addAll([
      heard(midiToHz(45) * 1.02),
      const TunerAnalysis.refused(TunerRefusal.insufficientSamples),
    ]);
    await run(8);
    expect(controller.readout.kind, TunerReadoutKind.measured);
  });

  test('a non-speaker route closes capture as unsupported', () async {
    source.route = AudioRoute.wiredHeadset;
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, TunerPhase.unsupportedInput);
    expect(controller.isActive, isFalse);
  });

  test('native order: start replies before the route; the tuner waits', () async {
    // Real iOS/Android: the start reply lands first (route still unknown),
    // the routeChanged event right after it.
    source.route = AudioRoute.unknown;
    script.queue.add(heard(midiToHz(45)));
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, TunerPhase.calibrating);
    source.simulateRouteChange(AudioRoute.speaker);
    await Future<void>.delayed(Duration.zero);
    source.pushChunk(List<double>.filled(sr, 0.0005));
    for (var i = 0; i < 4; i++) {
      source.pushChunk(List<double>.filled(sr ~/ 4, 0.001));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.phase, TunerPhase.listening);
    expect(controller.readout.stringIndex, 1);
  });

  test('a route that never resolves closes as unsupported', () async {
    source.route = AudioRoute.unknown;
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    source.pushChunk(List<double>.filled(sr, 0.0005));
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, TunerPhase.calibrating);
    source.pushChunk(List<double>.filled(sr, 0.0005));
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, TunerPhase.unsupportedInput);
    expect(controller.isActive, isFalse);
  });

  test('declined permission is reported without capture', () async {
    source.permissionGranted = false;
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, TunerPhase.permissionDenied);
    expect(source.isRunning, isFalse);
  });

  test('changing preset resets string progress', () async {
    script.queue.addAll([heard(midiToHz(40)), heard(midiToHz(40))]);
    await run(8);
    controller.setPreset(TuningPresets.guitarDropD);
    expect(controller.session.inTuneCount, 0);
    expect(controller.readout.kind, TunerReadoutKind.listening);
  });

  group('session tuning gate', () {
    test('unchecked → continued → checked', () {
      final m = TunerCheckMemory();
      expect(sessionTuningGateState(m), SessionTuningGateState.unchecked);
      m.continueWithoutTuning();
      expect(sessionTuningGateState(m), SessionTuningGateState.continued);
      m.record(presetId: 'guitar.standard', inTune: 3, total: 6);
      expect(sessionTuningGateState(m), SessionTuningGateState.untuned);
      m.record(presetId: 'guitar.standard', inTune: 6, total: 6);
      expect(sessionTuningGateState(m), SessionTuningGateState.tuned);
    });

    test('a check from yesterday does not count today', () {
      var now = DateTime(2026, 11, 2, 23, 50);
      final m = TunerCheckMemory(now: () => now);
      m.record(presetId: 'guitar.standard', inTune: 6, total: 6);
      expect(sessionTuningGateState(m), SessionTuningGateState.tuned);
      now = DateTime(2026, 11, 3, 0, 10);
      expect(sessionTuningGateState(m), SessionTuningGateState.unchecked);
    });

    testWidgets('gate card offers tune and continue', (tester) async {
      final m = TunerCheckMemory();
      var tuned = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionTuningGateCard(
              memory: m,
              onTune: (_) async => tuned++,
            ),
          ),
        ),
      );
      expect(find.textContaining('Tune before you start'), findsOneWidget);
      await tester.tap(find.byKey(const Key('session-tuning-gate-tune')));
      expect(tuned, 1);
      await tester.tap(find.byKey(const Key('session-tuning-gate-continue')));
      await tester.pump();
      expect(find.textContaining('Continuing without tuning'), findsOneWidget);
      m.record(presetId: 'guitar.standard', inTune: 4, total: 6);
      await tester.pump();
      expect(find.text('Strings not yet in tune: 2 of 6.'), findsOneWidget);
    });
  });

  testWidgets('tuner screen shows no number until a confident reading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TunerScreen(controller: controller)),
    );
    expect(find.byKey(const Key('tuner-cents')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('tuner-cents'))).data,
      '—',
    );
    expect(find.textContaining('±5 cents'), findsOneWidget);
    for (final label in ['Auto', 'Manual', 'Chromatic']) {
      expect(find.text(label), findsOneWidget);
    }
    // FK7 list for guitar is offered without a paywall.
    for (final name in [
      'Standard',
      'Drop D',
      'Half step down',
      'DADGAD',
      'Open G',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text('Bass'));
    await tester.pump();
    expect(find.text('4-string'), findsOneWidget);
    expect(find.byKey(const Key('tuner-string-3')), findsOneWidget);
    expect(find.byKey(const Key('tuner-string-4')), findsNothing);
    await tester.tap(find.text('5-string'));
    await tester.pump();
    expect(find.byKey(const Key('tuner-string-4')), findsOneWidget);
    expect(find.text('B0'), findsOneWidget);
    await tester.tap(find.text('Ukulele'));
    await tester.pump();
    expect(find.text('Standard (high G)'), findsOneWidget);
    expect(find.textContaining('wrong'), findsNothing);
  });

  testWidgets('tuner screen readouts follow the safety rules', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TunerScreen(controller: controller)),
    );
    Future<void> feed(TunerAnalysis a) async {
      script.queue.add(a);
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          source.pushChunk(List<double>.filled(sr ~/ 4, 0.001));
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();
    }

    await tester.runAsync(() async {
      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      source.pushChunk(List<double>.filled(sr, 0.0005));
      for (var i = 0; i < 3; i++) {
        source.pushChunk(List<double>.filled(sr ~/ 4, 0.001));
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
    String cents() =>
        tester.widget<Text>(find.byKey(const Key('tuner-cents'))).data!;
    String headline() =>
        tester.widget<Text>(find.byKey(const Key('tuner-headline'))).data!;

    await feed(heard(midiToHz(45) * 0.99));
    expect(cents(), '−17');
    expect(headline(), 'Tighten slowly');

    await feed(heard(midiToHz(45) * 0.99, confident: false));
    expect(cents(), '—');
    expect(headline(), 'Play again');

    await feed(heard(midiToHz(52)));
    expect(cents(), '—');
    expect(headline(), startsWith('Could not measure'));

    await tester.tap(find.byKey(const Key('tuner-string-0')));
    await tester.pump();
    await feed(heard(midiToHz(43)));
    expect(cents(), '—');
    expect(headline(), 'Too high — loosen');
    expect(find.textContaining('never tighten'), findsOneWidget);

    await tester.runAsync(controller.stop);
    await tester.pump();
  });

  testWidgets('openTuner returns today\'s check and never pops itself', (
    tester,
  ) async {
    TunerCheck? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await openTuner(
              context,
              controller: controller,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TunerScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('tuner-back')));
    await tester.pumpAndSettle();
    expect(find.byType(TunerScreen), findsNothing);
    expect(result, TunerCheckMemory.instance.today);
  });
}
