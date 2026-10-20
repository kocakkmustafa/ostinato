import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/guitar_note_observation_controller.dart';
import 'package:ostinato/app/guitar_session_preparation.dart';
import 'package:ostinato/app/screens/guitar_note_observation_screen.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

const _deliveryTimeout = Duration(milliseconds: 100);
const _observed = GuitarNoteObservationResult(
  reason: GuitarSingleNoteReason.observed,
  totalWindows: 3,
  reliableWindows: 3,
  observation: GuitarNoteObservation(hz: 220, midi: 57, centsFromCenter: 0),
);

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  testWidgets(
    'known-route PCM timeout waits for native close then enables a separate start',
    (tester) async {
      var analyses = 0;
      final harness = await _pumpObservation(
        tester,
        analyzer: (_, _, _, _) async {
          analyses++;
          return _observed;
        },
      );
      await harness.startThroughScreen(tester);

      await tester.pump(const Duration(milliseconds: 99));
      expect(harness.controller.phase, NoteObservationPhase.calibrating);
      expect(harness.controller.isActive, isTrue);
      expect(harness.channel.stopCalls, 0);

      await tester.pump(const Duration(milliseconds: 2));
      expect(harness.failureReasons, contains('capture_pcm_timeout'));
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.isActive, isFalse);
      expect(harness.controller.isCaptureStopping, isTrue);
      expect(harness.controller.captureClosePending, isTrue);
      expect(harness.controller.captureGateReady, isFalse);
      expect(harness.controller.canStart, isFalse);
      expect(_startButton(tester).onPressed, isNull);
      expect(_statusText(tester), contains('Capture stays disabled'));
      expect(harness.channel.stopCalls, 1);
      expect(harness.source.bufferedSampleCountForTest, 0);
      expect(analyses, 0);

      harness.channel.acknowledgeClose();
      await tester.pump();
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.isCaptureStopping, isFalse);
      expect(harness.controller.captureClosePending, isFalse);
      expect(harness.controller.captureGateReady, isTrue);
      expect(harness.controller.canStart, isTrue);
      expect(_startButton(tester).onPressed, isNotNull);
      expect(_statusText(tester), contains('Note observation stopped'));

      // A completed close makes a later user choice possible; it does not
      // turn a terminal transport failure into a successful observation.
      await tester.pump(const Duration(milliseconds: 500));
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.isActive, isFalse);
      expect(harness.channel.startCalls, 1);
      expect(harness.channel.stopCalls, 1);
      expect(harness.channel.retryCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stream-ended terminal clears a shown note and pending analysis without revival',
    (tester) async {
      final lateAnalysis = Completer<GuitarNoteObservationResult>();
      addTearDown(() {
        if (!lateAnalysis.isCompleted) lateAnalysis.complete(_observed);
      });
      var analyses = 0;
      List<double>? pendingSamples;
      final harness = await _pumpObservation(
        tester,
        analyzer: (samples, _, _, _) {
          analyses++;
          if (analyses == 1) return Future.value(_observed);
          pendingSamples = samples;
          return lateAnalysis.future;
        },
      );
      await harness.startThroughScreen(tester);

      final rate = harness.config.initialSampleRate;
      harness.channel.deliverPcm(
        (rate * harness.config.calibrationMs / 1000).ceil(),
        amplitude: .0001,
      );
      await tester.pump();
      expect(harness.controller.phase, NoteObservationPhase.listening);

      harness.channel.deliverPcm(harness.config.windowSamples);
      await tester.pump();
      expect(analyses, 1);
      expect(_noteText(tester), 'A3');
      expect(harness.controller.observation, isNotNull);

      // Keep timestamps contiguous while reaching the next analysis interval.
      // No synthetic wall-clock advance is needed to feed this native boundary.
      final advanceSamples =
          (rate * harness.config.analysisIntervalMs / 1000).ceil();
      harness.channel.deliverPcm(advanceSamples);
      await tester.pump();
      harness.channel.deliverPcm(harness.config.windowSamples);
      await tester.pump();
      expect(analyses, 2);
      expect(pendingSamples, isNotNull);
      expect(pendingSamples!, contains(.2));
      expect(harness.controller.bufferedSamples, harness.config.windowSamples);
      expect(harness.source.bufferedSampleCountForTest, greaterThan(0));

      // The raw EventChannel EOF-to-terminal translation is tested below this
      // layer. This fake emits that transport boundary's translated event.
      harness.channel.reportStreamEnded();
      await tester.pump();
      expect(harness.failureReasons, contains('capture_stream_ended'));
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.observation, isNull);
      expect(_noteText(tester), '—');
      expect(harness.controller.bufferedSamples, 0);
      expect(harness.source.bufferedSampleCountForTest, 0);
      expect(pendingSamples!, everyElement(0));
      expect(harness.controller.isCaptureStopping, isTrue);
      expect(harness.controller.canStart, isFalse);
      expect(_startButton(tester).onPressed, isNull);
      expect(harness.channel.stopCalls, 1);

      harness.channel.acknowledgeClose();
      await tester.pump();
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.observation, isNull);
      expect(_noteText(tester), '—');
      expect(harness.controller.isCaptureStopping, isFalse);
      expect(harness.controller.captureGateReady, isTrue);
      // Native closure alone cannot admit another job while the retired
      // analyzer still owns its one in-flight slot.
      expect(harness.controller.canStart, isFalse);
      expect(_startButton(tester).onPressed, isNull);
      expect(harness.channel.stopCalls, 1);
      expect(analyses, 2);

      lateAnalysis.complete(_observed);
      await tester.pump();
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.canStart, isTrue);
      expect(_startButton(tester).onPressed, isNotNull);
      expect(_noteText(tester), '—');
      expect(harness.channel.startCalls, 1);
      expect(harness.channel.stopCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stream-ended partial calibration cannot claim confirmed closure after stop error',
    (tester) async {
      final harness = await _pumpObservation(
        tester,
        analyzer: (_, _, _, _) async => _observed,
      );
      await harness.startThroughScreen(tester);
      harness.channel.deliverPcm(1024, amplitude: .0001);
      await tester.pump();
      expect(harness.controller.phase, NoteObservationPhase.calibrating);
      expect(harness.source.bufferedSampleCountForTest, 1024);

      harness.channel.reportStreamEnded();
      await tester.pump();
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.isCaptureStopping, isTrue);
      expect(harness.source.bufferedSampleCountForTest, 0);
      expect(_startButton(tester).onPressed, isNull);

      harness.channel.rejectClose();
      await tester.pump();
      expect(harness.controller.phase, NoteObservationPhase.unavailable);
      expect(harness.controller.isCaptureStopping, isFalse);
      expect(harness.controller.captureStopFailed, isTrue);
      expect(harness.controller.captureGateReady, isFalse);
      expect(harness.controller.canStart, isFalse);
      expect(_startButton(tester).onPressed, isNull);
      expect(_statusText(tester), contains('Capture remains disabled'));

      // A fresh read may offer explicit recovery, never a successful close or
      // an automatic new capture in response to the terminal stream event.
      final refresh = find.byKey(const Key('observation-close-refresh'));
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pump();
      expect(harness.controller.canRetryCaptureClose, isTrue);
      expect(harness.controller.captureGateReady, isFalse);
      expect(_startButton(tester).onPressed, isNull);
      expect(_statusText(tester), contains('closure needs an explicit retry'));
      expect(_statusText(tester), isNot(contains('microphone is off')));
      expect(_statusText(tester), isNot(contains('stop request finished')));
      expect(harness.controller.observation, isNull);
      expect(_noteText(tester), '—');
      expect(harness.controller.bufferedSamples, 0);
      expect(harness.channel.startCalls, 1);
      expect(harness.channel.stopCalls, 1);
      expect(harness.channel.retryCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

GuitarObservationConfig _config() => GuitarObservationConfig.fromJson(
  jsonDecode(
        File('assets/config/guitar-observation.v1.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);

FilledButton _startButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const Key('observation-start-stop')),
);

String _statusText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('observation-status')))
    .data!;

String _noteText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('observed-note'))).data!;

Future<_ObservationHarness> _pumpObservation(
  WidgetTester tester, {
  required NoteAnalyzer analyzer,
}) async {
  final config = _config();
  final channel = _NativeTerminalChannel();
  final source = AudioInputController(
    channel: channel,
    pcmDeliveryTimeout: _deliveryTimeout,
    requestMicrophonePermission: () async => PermissionStatus.granted,
  );
  final controller = GuitarNoteObservationController(
    config: config,
    source: source,
    analyzer: analyzer,
  );
  final preparation = GuitarSessionPreparation(
    now: () => DateTime(2026, 10, 19, 12),
  );
  final harness = _ObservationHarness(config, channel, source, controller);
  final statuses = source.status.listen((status) {
    if (status is AudioSetupFailed) harness.failureReasons.add(status.reason);
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    channel.acknowledgeClose();
    await controller.stop();
    controller.dispose();
    await statuses.cancel();
    await source.dispose();
    await channel.dispose();
    preparation.dispose();
    await tester.pump();
    resetAudioCaptureCoordinatorForTest();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      home: GuitarNoteObservationScreen(
        controller: controller,
        preparation: preparation,
      ),
    ),
  );
  await tester.pump();
  return harness;
}

final class _ObservationHarness {
  _ObservationHarness(this.config, this.channel, this.source, this.controller);

  final GuitarObservationConfig config;
  final _NativeTerminalChannel channel;
  final AudioInputController source;
  final GuitarNoteObservationController controller;
  final failureReasons = <String>[];

  Future<void> startThroughScreen(WidgetTester tester) async {
    final acknowledge = find.byKey(const Key('note-session-acknowledge'));
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pump();
    final start = find.byKey(const Key('observation-start-stop'));
    await tester.ensureVisible(start);
    expect(_startButton(tester).onPressed, isNotNull);
    await tester.tap(start);
    await tester.pump();
    expect(channel.startCalls, 1);
    channel.deliverBuiltInRoute();
    await tester.pump();
    expect(controller.phase, NoteObservationPhase.calibrating);
    expect(controller.isActive, isTrue);
  }
}

/// Only native delivery and the final close receipt are controlled here.
/// AudioInputController, GuitarNoteObservationController and the screen are real.
final class _NativeTerminalChannel
    implements AudioCaptureChannel, AudioCaptureCloseControl {
  final _events = StreamController<RawAudioEvent>.broadcast();
  final _closeReply = Completer<void>();
  AudioCaptureCloseState _state = const AudioCaptureCloseState.clear();
  String? _attemptId;
  String? _closedAttemptId;
  int _nextNativeUs = 0;
  int startCalls = 0, stopCalls = 0, retryCalls = 0;
  int _rate = 44100;

  @override
  String? get attemptId => _attemptId;
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<AudioCaptureCloseState> readCloseState() async => _state;

  @override
  Future<void> start({required int sampleRate}) async {
    startCalls++;
    _rate = sampleRate;
    _nextNativeUs = 0;
    _attemptId = 'terminal-$startCalls';
    _state = AudioCaptureCloseState(
      phase: AudioCaptureClosePhase.running,
      attemptId: _attemptId,
      attemptInFlight: false,
      resourcesReleased: false,
      requiresExplicitRetry: false,
    );
  }

  void deliverBuiltInRoute() =>
      _events.add(const RawRouteChangedEvent('ios:BuiltInMic'));

  void deliverPcm(int count, {double amplitude = .2}) {
    _events.add(
      RawAudioChunkEvent(
        samples: List<double>.filled(count, amplitude),
        sampleRate: _rate,
        tNativeUs: _nextNativeUs,
      ),
    );
    _nextNativeUs += (count * 1000000 / _rate).round();
  }

  void reportStreamEnded() =>
      _events.add(const RawInterruptedEvent('capture_stream_ended'));

  void acknowledgeClose() {
    if (!_closeReply.isCompleted) _closeReply.complete();
  }

  void rejectClose() {
    _closeReply.completeError(
      PlatformException(code: 'test_native_close_failed'),
    );
  }

  @override
  Future<void> stop() async {
    final id = _attemptId;
    if (id == null) return;
    stopCalls++;
    _state = AudioCaptureCloseState(
      phase: AudioCaptureClosePhase.closing,
      attemptId: id,
      attemptInFlight: true,
      resourcesReleased: false,
      requiresExplicitRetry: false,
    );
    try {
      await _closeReply.future;
    } on Object {
      _state = AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.unconfirmedQuiescent,
        attemptId: id,
        attemptInFlight: false,
        resourcesReleased: false,
        requiresExplicitRetry: true,
      );
      rethrow;
    }
    _closedAttemptId = id;
    _attemptId = null;
    _state = const AudioCaptureCloseState.clear();
  }

  @override
  Future<void> stopAttempt(String id) async {
    if (_attemptId != id && _closedAttemptId != id) {
      throw PlatformException(code: 'stale_capture_attempt');
    }
    await stop();
  }

  @override
  Future<void> retryStopAttempt(String id) async {
    retryCalls++;
    await stopAttempt(id);
  }

  Future<void> dispose() => _events.close();
}
