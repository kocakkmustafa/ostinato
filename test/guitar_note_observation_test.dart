import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/guitar_note_observation_controller.dart';
import 'package:ostinato/app/guitar_session_preparation.dart';
import 'package:ostinato/app/screens/guitar_note_observation_screen.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'support/localized_widget_ready.dart';

GuitarObservationConfig config() => GuitarObservationConfig.fromJson(
  jsonDecode(
        File('assets/config/guitar-observation.v2.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);
const observed = GuitarNoteObservationResult(
  reason: GuitarSingleNoteReason.observed,
  totalWindows: 3,
  reliableWindows: 3,
  observation: GuitarNoteObservation(hz: 220, midi: 57, centsFromCenter: 0),
);

GuitarNoteObservationResult heldNote(int midi, double cents) =>
    GuitarNoteObservationResult(
      reason: GuitarSingleNoteReason.observed,
      totalWindows: 3,
      reliableWindows: 3,
      observation: GuitarNoteObservation(
        hz: 440 * math.pow(2, (midi - 69 + cents / 100) / 12).toDouble(),
        midi: midi,
        centsFromCenter: cents,
      ),
    );

/// One analysis per call: 16384 samples are past the 350 ms analysis interval.
Future<void> nextWindow(WidgetTester t, FakeAudioSource source) async {
  source.pushChunk(List.filled(16384, .2));
  await t.pump();
}

/// FakeAudioSource does not announce stop; the native source does.
final class AnnouncingAudioSource implements AudioSource {
  AnnouncingAudioSource({
    AudioRoute initialRoute = AudioRoute.speaker,
    this.stopGate,
  }) : fake = FakeAudioSource(initialRoute: initialRoute) {
    _statusSubscription = fake.status.listen(_statuses.add);
  }

  final FakeAudioSource fake;
  final Future<void>? stopGate;
  final StreamController<AudioSurfaceState> _statuses =
      StreamController<AudioSurfaceState>.broadcast();
  late final StreamSubscription<AudioSurfaceState> _statusSubscription;

  @override
  Stream<AudioChunk> get chunks => fake.chunks;

  @override
  Stream<AudioSurfaceState> get status => _statuses.stream;

  @override
  Future<void> start({required int sampleRate}) =>
      fake.start(sampleRate: sampleRate);

  @override
  Future<void> stop() async {
    if (stopGate != null) await stopGate;
    await fake.stop();
    _statuses.add(const AudioStopped());
  }

  Future<void> dispose() async {
    await _statusSubscription.cancel();
    await fake.dispose();
    await _statuses.close();
  }
}

Future<void> calibrate(WidgetTester t, FakeAudioSource source) async {
  source.pushChunk(List.filled(88200, .0001));
  await t.pump();
}

Future<void> window(WidgetTester t, FakeAudioSource source) async {
  source.pushChunk(List.filled(8192, .2));
  await t.pump();
}

Future<void> acknowledgeSession(WidgetTester t) async {
  final acknowledge = find.byKey(const Key('note-session-acknowledge'));
  await t.ensureVisible(acknowledge);
  await t.tap(acknowledge);
  await t.pump();
}

Future<void> startObservation(WidgetTester t) async {
  final start = find.byKey(const Key('observation-start-stop'));
  await t.ensureVisible(start);
  await t.tap(start);
  await t.pump();
}

final class _UiCloseChannel
    implements AudioCaptureChannel, AudioCaptureCloseControl {
  final _events = StreamController<RawAudioEvent>.broadcast();
  AudioCaptureCloseState state = const AudioCaptureCloseState.unknown();
  String? reportedAttemptId;
  int startCalls = 0, stopCalls = 0;
  @override
  String? get attemptId => reportedAttemptId ?? 'old-id';
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<AudioCaptureCloseState> readCloseState() async => state;
  @override
  Future<void> start({required int sampleRate}) async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    state = const AudioCaptureCloseState(
      phase: AudioCaptureClosePhase.clear,
      attemptId: null,
      attemptInFlight: false,
      resourcesReleased: true,
      requiresExplicitRetry: false,
    );
  }

  @override
  Future<void> stopAttempt(String id) => stop();
  @override
  Future<void> retryStopAttempt(String id) => stop();
}

void main() {
  setUpAll(prepareRootTranslations);
  setUp(resetAudioCaptureCoordinatorForTest);
  testWidgets('route disposal cancels an unanswered closeState deadline', (
    t,
  ) async {
    const method = MethodChannel('com.yulalab.ostinato/audio_capture');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final unanswered = Completer<Object?>();
    messenger.setMockMethodCallHandler(method, (call) {
      if (call.method == 'closeState') return unanswered.future;
      return Future<Object?>.value(null);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(method, null));
    await t.pumpWidget(const MaterialApp(home: GuitarNoteObservationScreen()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('observation-close-refresh')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump();
    expect(t.takeException(), isNull);
    // The platform Future is deliberately unanswered. The route has no
    // pending 3-second Dart watchdog after disposal.
  });
  testWidgets('unknown native close readback disables optional microphone', (
    t,
  ) async {
    final channel = _UiCloseChannel();
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await t.pumpWidget(
      MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
    );
    await t.pump();
    await acknowledgeSession(t);
    expect(controller.canStart, isFalse);
    expect(find.byKey(const Key('observation-close-refresh')), findsOneWidget);
    expect(channel.startCalls, 0);
    channel.state = const AudioCaptureCloseState.clear();
    await t.ensureVisible(find.byKey(const Key('observation-close-refresh')));
    await t.tap(find.byKey(const Key('observation-close-refresh')));
    await t.pump();
    expect(controller.canStart, isTrue);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    await source.dispose();
  });

  testWidgets('quiescent native close needs retry then separate start', (
    t,
  ) async {
    final channel = _UiCloseChannel()
      ..state = const AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.unconfirmedQuiescent,
        attemptId: 'old-id',
        attemptInFlight: false,
        resourcesReleased: false,
        requiresExplicitRetry: true,
      );
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await t.pumpWidget(
      MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
    );
    await t.pump();
    await acknowledgeSession(t);
    expect(controller.canStart, isFalse);
    await t.ensureVisible(find.byKey(const Key('observation-close-retry')));
    await t.tap(find.byKey(const Key('observation-close-retry')));
    await t.pump();
    expect(channel.stopCalls, 1);
    expect(channel.startCalls, 0);
    expect(controller.canStart, isTrue);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    await source.dispose();
  });

  testWidgets('previous running attempt offers close without auto-start', (
    t,
  ) async {
    final channel = _UiCloseChannel()
      ..state = const AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.running,
        attemptId: 'old-id',
        attemptInFlight: false,
        resourcesReleased: false,
        requiresExplicitRetry: false,
      );
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await t.pumpWidget(
      MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
    );
    await t.pump();
    expect(controller.canStart, isFalse);
    await t.ensureVisible(find.byKey(const Key('observation-close-retry')));
    await t.tap(find.byKey(const Key('observation-close-retry')));
    await t.pump();
    expect(channel.stopCalls, 1);
    expect(channel.startCalls, 0);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    await source.dispose();
  });
  testWidgets('foreign running attempt offers refresh but no close authority', (
    t,
  ) async {
    final channel = _UiCloseChannel()
      ..reportedAttemptId = 'new-id'
      ..state = const AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.running,
        attemptId: 'old-id',
        attemptInFlight: false,
        resourcesReleased: false,
        requiresExplicitRetry: false,
      );
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await t.pumpWidget(
      MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
    );
    await t.pump();
    expect(controller.canStart, isFalse);
    expect(find.byKey(const Key('observation-close-retry')), findsNothing);
    expect(find.byKey(const Key('observation-close-refresh')), findsOneWidget);
    expect(channel.stopCalls, 0);
    expect(channel.startCalls, 0);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    await source.dispose();
  });
  testWidgets('explicit start, denial and retry; no capture on construction', (
    t,
  ) async {
    final source = FakeAudioSource()..permissionGranted = false;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) async => observed,
    );
    expect(source.isRunning, isFalse);
    await controller.start();
    await t.pump();
    expect(controller.phase, NoteObservationPhase.permissionDenied);
    source.permissionGranted = true;
    await controller.start();
    await t.pump();
    expect(source.isRunning, isTrue);
    expect(controller.phase, NoteObservationPhase.calibrating);
    await controller.stop();
    expect(source.isRunning, isFalse);
    expect(controller.observation, isNull);
    controller.dispose();
    await source.dispose();
  });
  testWidgets(
    'calibration, observed note, fresh no-result and stop clear RAM',
    (t) async {
      final source = FakeAudioSource();
      var accepted = true;
      final controller = GuitarNoteObservationController(
        config: config(),
        source: source,
        analyzer: (_, _, _, _) async => accepted
            ? observed
            : const GuitarNoteObservationResult(
                reason: GuitarSingleNoteReason.multipleSources,
                totalWindows: 3,
                reliableWindows: 0,
              ),
      );
      await controller.start();
      await t.pump();
      await calibrate(t, source);
      await window(t, source);
      expect(controller.observation?.midi, 57);
      accepted = false;
      source.pushChunk(List.filled(16384, .2));
      await t.pump();
      source.pushChunk(List.filled(8192, .2));
      await t.pump();
      expect(controller.observation, isNull);
      expect(controller.phase, NoteObservationPhase.noResult);
      await controller.stop();
      expect(controller.bufferedSamples, 0);
      controller.dispose();
      await source.dispose();
    },
  );
  testWidgets('sustained tuning reads set session tuning with hysteresis', (
    t,
  ) async {
    final source = FakeAudioSource();
    // Raw tuning reads; A2 (45) carries a -3.8 cent open-string correction.
    double raw(double measured) => measured + 3.8;
    final reads = <GuitarNoteObservation?>[
      for (final m in [24.0, 26.0, 23.0]) heldNote(45, raw(m)).observation,
      for (final m in [21.0, 21.0, 21.0]) heldNote(45, raw(m)).observation,
      for (final m in [19.0, 19.0, 19.0]) heldNote(45, raw(m)).observation,
      for (final m in [17.0, 17.0, 17.0]) heldNote(45, raw(m)).observation,
      heldNote(50, 5).observation,
      null,
      for (final m in [36.0, 34.0, 35.0]) heldNote(45, raw(m)).observation,
      for (final m in [29.0, 29.0, 29.0]) heldNote(45, raw(m)).observation,
      for (final m in [10.0, -2.0, 4.0]) heldNote(45, raw(m)).observation,
    ];
    var call = 0;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) async => observed,
      tuningAnalyzer: (_, _, _, _) async => reads[call++],
    );
    final seen = <(NoteTuning, double?)>[];
    await controller.start();
    await t.pump();
    await calibrate(t, source);
    for (var i = 0; i < reads.length; i++) {
      await nextWindow(t, source);
      seen.add((
        controller.tuning,
        controller.tuningCents == null
            ? null
            : (controller.tuningCents! * 10).round() / 10,
      ));
    }
    expect(call, reads.length);
    expect(seen[1], (NoteTuning.unknown, null));
    expect(seen[2], (NoteTuning.check, 24));
    // 21 and 19 stay within 2 cents of the 20-cent boundary: no flip.
    expect(seen[5], (NoteTuning.check, 21));
    expect(seen[8], (NoteTuning.check, 19));
    expect(seen[11], (NoteTuning.inTune, 17));
    // A different note or a refusal breaks the run.
    expect(seen[13], (NoteTuning.inTune, 17));
    expect(seen[16], (NoteTuning.tuneFirst, 35));
    expect(seen[19], (NoteTuning.tuneFirst, 29));
    // More than 10 cents of spread is not a sustained-note measurement.
    expect(seen[22], (NoteTuning.tuneFirst, 29));
    expect(GuitarNoteObservationController.tuningCorrection(47), -3.8);
    expect(GuitarNoteObservationController.tuningCorrection(52), -3.9);
    expect(GuitarNoteObservationController.tuningCorrection(76), -2.9);
    await controller.stop();
    expect(controller.tuning, NoteTuning.unknown);
    expect(controller.tuningCents, isNull);
    controller.dispose();
    await source.dispose();
  });
  testWidgets('tune-first hides the note name; check shows the cents', (
    t,
  ) async {
    final source = FakeAudioSource();
    final reads = <GuitarNoteObservation?>[
      for (var i = 0; i < 3; i++) heldNote(45, 28.8).observation,
      for (var i = 0; i < 3; i++) heldNote(45, 43.8).observation,
    ];
    var call = 0;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) async => heldNote(45, 0),
      tuningAnalyzer: (_, _, _, _) async => reads[call++],
    );
    await t.pumpWidget(
      MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
    );
    await t.pump();
    await controller.start();
    await t.pump();
    await calibrate(t, source);
    for (var i = 0; i < 3; i++) {
      await nextWindow(t, source);
    }
    Text tuningText() =>
        t.widget<Text>(find.byKey(const Key('observation-tuning')));
    Text noteText() => t.widget<Text>(find.byKey(const Key('observed-note')));
    expect(controller.tuning, NoteTuning.check);
    expect(noteText().data, startsWith('A2'));
    expect(tuningText().data, contains('25 cents'));
    for (var i = 0; i < 3; i++) {
      await nextWindow(t, source);
    }
    expect(controller.tuning, NoteTuning.tuneFirst);
    expect(controller.observation?.midi, 45);
    expect(noteText().data, '—');
    expect(tuningText().data, startsWith('Tune first'));
    await t.pumpWidget(const SizedBox());
    await controller.stop();
    controller.dispose();
    await source.dispose();
  });
  test('the tuning pass widens only the centre limit', () {
    final c = config();
    expect(c.tuningPitch.maxCenterErrorCents, 50);
    expect(c.pitch.maxCenterErrorCents, 35);
    expect(c.tuningPitch.windowSize, c.pitch.windowSize);
    expect(c.tuningPitch.minPeriodicity, c.pitch.minPeriodicity);
  });
  testWidgets('late analysis after stale TTL cannot revive a note', (t) async {
    final source = FakeAudioSource();
    final pending = Completer<GuitarNoteObservationResult>();
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) => pending.future,
    );
    await controller.start();
    await t.pump();
    await calibrate(t, source);
    await window(t, source);
    await t.pump(const Duration(milliseconds: 1201));
    expect(controller.observation, isNull);
    expect(source.isRunning, isFalse);
    pending.complete(observed);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.phase, NoteObservationPhase.analysisTimedOut);
    controller.dispose();
    await source.dispose();
  });

  testWidgets(
    'hung analyzer closes capture and blocks restart until old work settles',
    (t) async {
      final source = AnnouncingAudioSource();
      final pending = Completer<GuitarNoteObservationResult>();
      List<double>? capturedSamples;
      var calls = 0;
      final controller = GuitarNoteObservationController(
        config: config(),
        source: source,
        analyzer: (samples, _, _, _) {
          capturedSamples = samples;
          calls++;
          return calls == 1 ? pending.future : Future.value(observed);
        },
      );
      await t.pumpWidget(
        MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
      );
      await acknowledgeSession(t);
      await startObservation(t);
      await calibrate(t, source.fake);
      await window(t, source.fake);
      expect(calls, 1);
      expect(source.fake.isRunning, isTrue);

      await t.pump(const Duration(milliseconds: 1201));
      await t.pump();
      expect(source.fake.isRunning, isFalse);
      expect(controller.phase, NoteObservationPhase.analysisTimedOut);
      expect(controller.observation, isNull);
      expect(controller.refusal, isNull);
      expect(controller.bufferedSamples, 0);
      expect(capturedSamples, everyElement(0));
      expect(controller.canStart, isFalse);
      expect(
        find.textContaining('Audio analysis did not finish'),
        findsOneWidget,
      );
      expect(find.textContaining('No clear single note'), findsNothing);
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const Key('observation-start-stop')),
            )
            .onPressed,
        isNull,
      );
      await controller.start();
      expect(source.fake.isRunning, isFalse);
      expect(calls, 1);

      pending.complete(observed);
      await t.pump();
      expect(controller.observation, isNull);
      expect(controller.phase, NoteObservationPhase.analysisTimedOut);
      expect(controller.canStart, isTrue);
      await startObservation(t);
      await calibrate(t, source.fake);
      await window(t, source.fake);
      expect(calls, 2);
      expect(controller.observation?.midi, 57);

      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      controller.dispose();
      await t.pump();
      await t.runAsync(source.dispose);
    },
  );

  testWidgets('manual stop waits for its old analysis before restart', (
    t,
  ) async {
    final source = AnnouncingAudioSource();
    final pending = Completer<GuitarNoteObservationResult>();
    var calls = 0;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) {
        calls++;
        return calls == 1 ? pending.future : Future.value(observed);
      },
    );
    await controller.start();
    await t.pump();
    await calibrate(t, source.fake);
    await window(t, source.fake);
    await controller.stop();
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    expect(controller.phase, NoteObservationPhase.analysisSettling);
    expect(controller.canStart, isFalse);
    await controller.start();
    expect(source.fake.isRunning, isFalse);
    expect(calls, 1);
    pending.complete(observed);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.phase, NoteObservationPhase.idle);
    expect(controller.canStart, isTrue);
    await controller.start();
    await t.pump();
    await calibrate(t, source.fake);
    await window(t, source.fake);
    expect(calls, 2);
    expect(controller.observation?.midi, 57);
    controller.dispose();
    await t.runAsync(source.dispose);
  });

  testWidgets('route change stops capture while old analysis is pending', (
    t,
  ) async {
    final source = AnnouncingAudioSource();
    final pending = Completer<GuitarNoteObservationResult>();
    var calls = 0;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) {
        calls++;
        return calls == 1 ? pending.future : Future.value(observed);
      },
    );
    await controller.start();
    await t.pump();
    await calibrate(t, source.fake);
    await window(t, source.fake);
    source.fake.simulateRouteChange(AudioRoute.bluetooth);
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    expect(controller.phase, NoteObservationPhase.analysisSettling);
    expect(controller.canStart, isFalse);
    pending.complete(observed);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.canStart, isTrue);
    source.fake.route = AudioRoute.speaker;
    await controller.start();
    await t.pump();
    await calibrate(t, source.fake);
    await window(t, source.fake);
    expect(calls, 2);
    expect(controller.observation?.midi, 57);
    controller.dispose();
    await t.runAsync(source.dispose);
  });

  testWidgets('sample-rate change cannot leave capture open on a hung job', (
    t,
  ) async {
    final source = AnnouncingAudioSource();
    final pending = Completer<GuitarNoteObservationResult>();
    var calls = 0;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) {
        calls++;
        return pending.future;
      },
    );
    await controller.start();
    await t.pump();
    await calibrate(t, source.fake);
    await window(t, source.fake);
    expect(calls, 1);
    source.fake.pushChunk(List<double>.filled(8192, .2), sampleRate: 48000);
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    expect(controller.phase, NoteObservationPhase.analysisSettling);
    expect(controller.bufferedSamples, 0);
    expect(controller.canStart, isFalse);
    await controller.start();
    expect(calls, 1);
    pending.complete(observed);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.canStart, isTrue);
    controller.dispose();
    await t.runAsync(source.dispose);
  });
  testWidgets(
    'continuous chunks do not retain an old note while next analysis hangs',
    (t) async {
      final source = FakeAudioSource();
      final pending = Completer<GuitarNoteObservationResult>();
      var calls = 0;
      final controller = GuitarNoteObservationController(
        config: config(),
        source: source,
        analyzer: (_, _, _, _) {
          calls++;
          return calls == 1 ? Future.value(observed) : pending.future;
        },
      );
      await controller.start();
      await t.pump();
      await calibrate(t, source);
      await window(t, source);
      expect(controller.observation, isNotNull);
      for (var i = 0; i < 7; i++) {
        source.pushChunk(List.filled(8192, .2));
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(controller.observation, isNull);
      pending.complete(observed);
      await t.pump();
      controller.dispose();
      await source.dispose();
    },
  );
  testWidgets('stop during analysis discards late result', (t) async {
    final source = FakeAudioSource();
    final pending = Completer<GuitarNoteObservationResult>();
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) => pending.future,
    );
    await controller.start();
    await t.pump();
    await calibrate(t, source);
    await window(t, source);
    await controller.stop();
    pending.complete(observed);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.phase, NoteObservationPhase.idle);
    expect(controller.bufferedSamples, 0);
    controller.dispose();
    await source.dispose();
  });
  testWidgets('route changes clear note and external input does not analyze', (
    t,
  ) async {
    final source = FakeAudioSource();
    var calls = 0;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) async {
        calls++;
        return observed;
      },
    );
    await controller.start();
    await t.pump();
    await calibrate(t, source);
    await window(t, source);
    source.simulateRouteChange(AudioRoute.bluetooth);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.phase, NoteObservationPhase.unsupportedInput);
    expect(source.isRunning, isFalse);
    await window(t, source);
    expect(calls, 1);
    controller.dispose();
    await source.dispose();
  });

  testWidgets('initial unknown route can resolve to built-in microphone', (
    t,
  ) async {
    final source = AnnouncingAudioSource(initialRoute: AudioRoute.unknown);
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) async => observed,
    );
    await controller.start();
    await t.pump();
    expect(source.fake.isRunning, isTrue);
    expect(controller.phase, NoteObservationPhase.checkingInput);
    source.fake.simulateRouteChange(AudioRoute.speaker);
    await t.pump();
    expect(controller.phase, NoteObservationPhase.calibrating);
    await t.pump(Duration(milliseconds: config().calibrationMs + 1));
    expect(source.fake.isRunning, isTrue);
    await calibrate(t, source.fake);
    await window(t, source.fake);
    expect(controller.observation?.midi, 57);
    controller.dispose();
    await t.runAsync(source.dispose);
  });

  testWidgets('unresolved initial route closes microphone after grace', (
    t,
  ) async {
    final source = AnnouncingAudioSource(initialRoute: AudioRoute.unknown);
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await controller.start();
    await t.pump();
    expect(controller.phase, NoteObservationPhase.checkingInput);
    await t.pump(Duration(milliseconds: config().calibrationMs + 1));
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    expect(controller.phase, NoteObservationPhase.unsupportedInput);
    expect(controller.observation, isNull);
    controller.dispose();
    await t.runAsync(source.dispose);
  });
  testWidgets('repeated unknown route keeps the first closure deadline', (
    t,
  ) async {
    final source = AnnouncingAudioSource(initialRoute: AudioRoute.unknown);
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await controller.start();
    await t.pump();
    final grace = config().calibrationMs;
    await t.pump(Duration(milliseconds: grace ~/ 2));
    source.fake.simulateRouteChange(AudioRoute.unknown);
    await t.pump();
    await t.pump(Duration(milliseconds: grace ~/ 4));
    source.fake.simulateRouteChange(AudioRoute.unknown);
    await t.pump();
    await t.pump(Duration(milliseconds: grace - grace ~/ 2 - grace ~/ 4 + 1));
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    expect(controller.phase, NoteObservationPhase.unsupportedInput);
    controller.dispose();
    await t.runAsync(source.dispose);
  });

  testWidgets('speaker resolution ends the old unknown-route deadline', (
    t,
  ) async {
    final source = AnnouncingAudioSource(initialRoute: AudioRoute.unknown);
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await controller.start();
    await t.pump();
    final halfGrace = Duration(milliseconds: config().calibrationMs ~/ 2);
    await t.pump(halfGrace);
    source.fake.simulateRouteChange(AudioRoute.speaker);
    await t.pump();
    await t.pump(halfGrace + const Duration(milliseconds: 1));
    expect(source.fake.isRunning, isTrue);
    source.fake.simulateRouteChange(AudioRoute.unknown);
    await t.pump();
    expect(controller.phase, NoteObservationPhase.checkingInput);
    await t.pump(halfGrace);
    expect(source.fake.isRunning, isTrue);
    await t.pump(halfGrace + const Duration(milliseconds: 1));
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    expect(controller.phase, NoteObservationPhase.unsupportedInput);
    controller.dispose();
    await t.runAsync(source.dispose);
  });

  testWidgets('timeout reports closure pending until delayed stop resolves', (
    t,
  ) async {
    final stopGate = Completer<void>();
    final source = AnnouncingAudioSource(stopGate: stopGate.future);
    final pending = Completer<GuitarNoteObservationResult>();
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) => pending.future,
    );
    final pendingNotifications = <bool>[];
    controller.addListener(() {
      if (controller.phase == NoteObservationPhase.analysisTimedOut &&
          source.fake.isRunning) {
        pendingNotifications.add(controller.isCaptureStopping);
      }
    });
    await t.pumpWidget(
      MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: GuitarNoteObservationScreen(controller: controller),
      ),
    );
    await acknowledgeSession(t);
    await startObservation(t);
    await calibrate(t, source.fake);
    await window(t, source.fake);
    await t.pump(const Duration(milliseconds: 1201));
    await t.pump();
    expect(source.fake.isRunning, isTrue);
    expect(pendingNotifications, isNotEmpty);
    expect(pendingNotifications, everyElement(isTrue));
    expect(controller.canStart, isFalse);
    final pendingCopy = t
        .widget<Text>(find.byKey(const Key('observation-status')))
        .data!;
    expect(pendingCopy, contains('closure has not been confirmed'));
    expect(pendingCopy, isNot(contains('microphone is off')));
    t.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.binding.platformDispatcher.clearLocalesTestValue);
    await t.pump();
    final pendingCopyTr = t
        .widget<Text>(find.byKey(const Key('observation-status')))
        .data!;
    expect(pendingCopyTr, contains('kapatıldığı doğrulanmadı'));
    expect(pendingCopyTr, isNot(contains('kapatıldığı doğrulandı')));
    t.binding.platformDispatcher.clearLocalesTestValue();
    await t.pump();
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('observation-start-stop')))
          .onPressed,
      isNull,
    );

    stopGate.complete();
    await t.pump();
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    final closedCopy = t
        .widget<Text>(find.byKey(const Key('observation-status')))
        .data!;
    expect(closedCopy, contains('microphone stop request finished'));
    expect(closedCopy, isNot(contains('microphone is off')));
    expect(controller.canStart, isFalse);
    pending.complete(observed);
    await t.pump();
    expect(controller.canStart, isTrue);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.dispose();
    await t.runAsync(source.dispose);
  });

  testWidgets('route settling cannot claim microphone off during stop', (
    t,
  ) async {
    final stopGate = Completer<void>();
    final source = AnnouncingAudioSource(stopGate: stopGate.future);
    final pending = Completer<GuitarNoteObservationResult>();
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) => pending.future,
    );
    await t.pumpWidget(
      MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
    );
    await acknowledgeSession(t);
    await startObservation(t);
    await calibrate(t, source.fake);
    await window(t, source.fake);
    source.fake.simulateRouteChange(AudioRoute.bluetooth);
    await t.pump();
    expect(controller.phase, NoteObservationPhase.analysisSettling);
    expect(source.fake.isRunning, isTrue);
    expect(controller.canStart, isFalse);
    final pendingCopy = t
        .widget<Text>(find.byKey(const Key('observation-status')))
        .data!;
    expect(pendingCopy, contains('closure has not been confirmed'));
    expect(pendingCopy, isNot(contains('microphone is off')));

    stopGate.complete();
    await t.pump();
    await t.pump();
    expect(source.fake.isRunning, isFalse);
    expect(
      t.widget<Text>(find.byKey(const Key('observation-status'))).data,
      contains('microphone stop request finished'),
    );
    pending.complete(observed);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.canStart, isTrue);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.dispose();
    await t.runAsync(source.dispose);
  });

  testWidgets('rejected stop cannot claim closure or offer a retry', (t) async {
    final stopGate = Completer<void>();
    final source = AnnouncingAudioSource(stopGate: stopGate.future);
    final pending = Completer<GuitarNoteObservationResult>();
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) => pending.future,
    );
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: GuitarNoteObservationScreen(controller: controller),
      ),
    );
    await acknowledgeSession(t);
    await startObservation(t);
    await calibrate(t, source.fake);
    await window(t, source.fake);
    await t.pump(const Duration(milliseconds: 1201));
    stopGate.completeError(StateError('stop rejected'));
    await t.pump();
    await t.pump();
    expect(source.fake.isRunning, isTrue);
    expect(controller.canStart, isFalse);
    final failedCopy = t
        .widget<Text>(find.byKey(const Key('observation-status')))
        .data!;
    expect(failedCopy, contains('kapatıldığı doğrulanamadı'));
    expect(failedCopy, isNot(contains('Mikrofon kapalı')));
    expect(failedCopy, contains('yeniden başlatılamaz'));
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: GuitarNoteObservationScreen(controller: controller),
      ),
    );
    expect(
      t.widget<Text>(find.byKey(const Key('observation-status'))).data,
      contains('Microphone closure could not be confirmed'),
    );
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('observation-start-stop')))
          .onPressed,
      isNull,
    );
    pending.complete(observed);
    await t.pump();
    expect(controller.canStart, isFalse);
    await controller.start();
    expect(source.fake.isRunning, isTrue);
    await source.fake.stop();
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.dispose();
    await t.runAsync(source.dispose);
  });
  testWidgets(
    'observation screen does not auto-start and route dispose stops capture',
    (t) async {
      final source = FakeAudioSource();
      final controller = GuitarNoteObservationController(
        config: config(),
        source: source,
        analyzer: (_, _, _, _) async => observed,
      );
      await t.pumpWidget(
        MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
      );
      expect(source.isRunning, isFalse);
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const Key('observation-start-stop')),
            )
            .onPressed,
        isNull,
      );
      await acknowledgeSession(t);
      expect(source.isRunning, isFalse);
      await startObservation(t);
      expect(source.isRunning, isTrue);
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pump();
      expect(source.isRunning, isFalse);
      controller.dispose();
      await source.dispose();
    },
  );
  testWidgets('account ID change stops capture and clears displayed note', (
    t,
  ) async {
    final source = FakeAudioSource();
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
      analyzer: (_, _, _, _) async => observed,
    );
    Widget app(String id) => MaterialApp(
      home: AccountScope(
        connection: null,
        currentUserId: id,
        child: GuitarNoteObservationScreen(controller: controller),
      ),
    );
    await t.pumpWidget(app('first'));
    await acknowledgeSession(t);
    await startObservation(t);
    await calibrate(t, source);
    await window(t, source);
    expect(controller.observation, isNotNull);
    await t.pumpWidget(app('second'));
    await t.pump();
    expect(source.isRunning, isFalse);
    expect(controller.observation, isNull);
    expect(controller.bufferedSamples, 0);
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('observation-start-stop')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('note-session-acknowledge')), findsOneWidget);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.dispose();
    await source.dispose();
  });
  testWidgets('permanent denial shows Settings and course remains optional', (
    t,
  ) async {
    final source = FakeAudioSource()
      ..permissionGranted = false
      ..permissionPermanentlyDenied = true;
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    await t.pumpWidget(
      MaterialApp(home: GuitarNoteObservationScreen(controller: controller)),
    );
    await acknowledgeSession(t);
    await startObservation(t);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(source.isRunning, isFalse);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.dispose();
    await source.dispose();
  });

  testWidgets('session reset and background stop optional note capture', (
    t,
  ) async {
    final source = FakeAudioSource();
    final controller = GuitarNoteObservationController(
      config: config(),
      source: source,
    );
    final preparation = GuitarSessionPreparation();
    await t.pumpWidget(
      MaterialApp(
        home: GuitarNoteObservationScreen(
          controller: controller,
          preparation: preparation,
        ),
      ),
    );
    final start = find.byKey(const Key('observation-start-stop'));
    expect(find.textContaining('real phone accuracy'), findsOneWidget);
    expect(
      find.textContaining('Audio stays in temporary memory'),
      findsOneWidget,
    );
    expect(t.widget<FilledButton>(start).onPressed, isNull);
    await acknowledgeSession(t);
    expect(source.isRunning, isFalse);
    await startObservation(t);
    expect(source.isRunning, isTrue);

    final afterBreak = find.byKey(const Key('note-session-after-break'));
    await t.ensureVisible(afterBreak);
    await t.tap(afterBreak);
    await t.pump();
    expect(source.isRunning, isFalse);
    expect(t.widget<FilledButton>(start).onPressed, isNull);

    await acknowledgeSession(t);
    await startObservation(t);
    expect(source.isRunning, isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(preparation.isAcknowledged, isFalse);
    expect(source.isRunning, isFalse);
    expect(t.widget<FilledButton>(start).onPressed, isNull);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.dispose();
    preparation.dispose();
    await source.dispose();
  });
}
