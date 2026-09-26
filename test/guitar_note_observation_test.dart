import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/audio/guitar_note_observation_controller.dart';
import 'package:ostinato/app/screens/guitar_note_observation_screen.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

GuitarObservationConfig config() => GuitarObservationConfig.fromJson(
  jsonDecode(
        File('assets/config/guitar-observation.v1.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);
const observed = GuitarNoteObservationResult(
  reason: GuitarSingleNoteReason.observed,
  totalWindows: 3,
  reliableWindows: 3,
  observation: GuitarNoteObservation(hz: 220, midi: 57, centsFromCenter: 0),
);
Future<void> calibrate(WidgetTester t, FakeAudioSource source) async {
  source.pushChunk(List.filled(88200, .0001));
  await t.pump();
}

Future<void> window(WidgetTester t, FakeAudioSource source) async {
  source.pushChunk(List.filled(8192, .2));
  await t.pump();
}

void main() {
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
    pending.complete(observed);
    await t.pump();
    expect(controller.observation, isNull);
    expect(controller.phase, NoteObservationPhase.noResult);
    controller.dispose();
    await source.dispose();
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
    await window(t, source);
    expect(calls, 1);
    controller.dispose();
    await source.dispose();
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
      await t.tap(find.byKey(const Key('observation-start-stop')));
      await t.pump();
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
    await t.tap(find.byKey(const Key('observation-start-stop')));
    await t.pump();
    await calibrate(t, source);
    await window(t, source);
    expect(controller.observation, isNotNull);
    await t.pumpWidget(app('second'));
    await t.pump();
    expect(source.isRunning, isFalse);
    expect(controller.observation, isNull);
    expect(controller.bufferedSamples, 0);
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
    await t.tap(find.byKey(const Key('observation-start-stop')));
    await t.pump();
    expect(find.text('Open Settings'), findsOneWidget);
    expect(source.isRunning, isFalse);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.dispose();
    await source.dispose();
  });
}
