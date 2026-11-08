// OST-P0-08 — recording retention. TEST_ONLY: in-process Dart evidence; no
// on-device proof. Encrypted storage and export are NOT built (OST-P0-08B).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/own_recording/own_recording.dart';
import 'package:ostinato/app/practice/own_recording/own_recording_preference.dart';
import 'package:ostinato/app/practice/own_recording/recording_retention_copy.dart';
import 'package:ostinato/app/practice/own_recording/recording_retention_policy.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

AudioChunk _chunk(int n) => AudioChunk(
  samples: List<double>.filled(n, .5),
  sampleRate: 48000,
  tStartUs: 0,
  clockDomain: AudioClockDomain.monotonic,
);

final class _Memory implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => const {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) => throw UnimplementedError();
}

final class _Pref implements OwnRecordingPreference {
  @override
  Future<bool> read() async => true;
  @override
  Future<void> write(bool enabled) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late Directory takes;
  OwnRecorder recorder() => OwnRecorder(temporaryRoot: () async => tmp);
  setUp(() {
    resetAudioCaptureCoordinatorForTest();
    tmp = Directory.systemTemp.createTempSync('ost_p0_08');
    takes = Directory('${tmp.path}/own_recording');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });
  List<FileSystemEntity> onDisk() =>
      takes.existsSync() ? takes.listSync() : const [];

  group('policy table', () {
    test('persistence is denied on every input combination', () {
      for (final audience in RetentionAudience.values) {
        for (final consent in [false, true]) {
          expect(
            RecordingRetentionPolicy.decide(
              purpose: RecordingPurpose.persistentArchive,
              audience: audience,
              explicitStorageConsent: consent,
            ),
            RetentionDecision.denied,
            reason: '$audience consent=$consent',
          );
        }
      }
      expect(RetentionDecision.values, [
        RetentionDecision.ephemeral,
        RetentionDecision.denied,
      ], reason: 'no persistent outcome exists');
    });

    test('own playback is ephemeral for adults only', () {
      for (final audience in RetentionAudience.values) {
        for (final consent in [false, true]) {
          expect(
            RecordingRetentionPolicy.decide(
              purpose: RecordingPurpose.ownPlayback,
              audience: audience,
              explicitStorageConsent: consent,
            ),
            audience == RetentionAudience.adult
                ? RetentionDecision.ephemeral
                : RetentionDecision.denied,
          );
        }
      }
    });

    test('gate closed: legacy behaviour for every audience', () {
      expect(ostinatoRecordingRetentionOpen, isFalse);
      for (final audience in RetentionAudience.values) {
        expect(
          RecordingRetentionPolicy.mayRecordOwnTake(
            retentionOpen: false,
            audience: audience,
          ),
          isTrue,
        );
      }
    });

    test('gate open: only adults may record', () {
      for (final audience in RetentionAudience.values) {
        expect(
          RecordingRetentionPolicy.mayRecordOwnTake(
            retentionOpen: true,
            audience: audience,
          ),
          audience == RetentionAudience.adult,
        );
      }
    });
  });

  group('no persistent file in any path', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    test(
      'every input combination touches only the temporary directory',
      () async {
        final calls = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return tmp.path;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        for (final open in [false, true]) {
          for (final audience in RetentionAudience.values) {
            for (final consent in [false, true]) {
              for (final purpose in RecordingPurpose.values) {
                final mayOwn = RecordingRetentionPolicy.mayRecordOwnTake(
                  retentionOpen: open,
                  audience: audience,
                );
                final decision = RecordingRetentionPolicy.decide(
                  purpose: purpose,
                  audience: audience,
                  explicitStorageConsent: consent,
                );
                // The recorder is the only writer; consent and purpose can
                // never add a second path.
                final r = OwnRecorder()..enabled = mayOwn;
                r.add(_chunk(4800));
                final f = await r.seal();
                if (f != null) {
                  expect(f.path.startsWith(tmp.path), isTrue);
                  expect(f.path, contains('/own_recording/'));
                }
                expect(
                  decision == RetentionDecision.ephemeral,
                  purpose == RecordingPurpose.ownPlayback &&
                      audience == RetentionAudience.adult,
                );
                await r.discard();
                r.dispose();
              }
            }
          }
        }
        expect(calls.toSet(), {'getTemporaryDirectory'}, reason: '$calls');
        expect(onDisk(), isEmpty);
        // Nothing but the own_recording folder was ever created.
        expect(tmp.listSync().map((e) => e.path).toList(), [takes.path]);
      },
    );

    test('source scan: recorder and policy use no persistent directory', () {
      for (final f in [
        'lib/app/practice/own_recording/own_recording.dart',
        'lib/app/practice/own_recording/recording_retention_policy.dart',
        'lib/app/practice/own_recording/recording_retention_copy.dart',
      ]) {
        final src = File(f)
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        for (final banned in [
          'getApplicationDocumentsDirectory',
          'getApplicationSupportDirectory',
          'getLibraryDirectory',
          'getExternalStorage',
          'getDownloadsDirectory',
        ]) {
          expect(src.contains(banned), isFalse, reason: '$f $banned');
        }
      }
    });
  });

  group('ephemeral cleanup', () {
    test('session end: discard removes buffer and file', () async {
      final r = recorder()..enabled = true;
      r.add(_chunk(4800));
      final f = await r.seal();
      expect(f!.existsSync(), isTrue);
      await r.discard();
      expect(f.existsSync(), isFalse);
      expect(r.take, isNull);
      expect(onDisk(), isEmpty);
    });

    test(
      'cancel mid-run: buffered audio is dropped, nothing written',
      () async {
        final r = recorder()..enabled = true;
        r.add(_chunk(4800));
        expect(r.hasPendingAudio, isTrue);
        await r.discard();
        expect(r.hasPendingAudio, isFalse);
        expect(await r.seal(), isNull);
        expect(onDisk(), isEmpty);
      },
    );

    test('app to background: take and buffer are discarded', () async {
      final r = recorder()..enabled = true;
      final guard = RecorderBackgroundGuard(r)..attach();
      addTearDown(guard.detach);
      r.add(_chunk(4800));
      final f = await r.seal();
      r.add(_chunk(4800)); // next run's buffer
      expect(f!.existsSync(), isTrue);
      expect(r.hasPendingAudio, isTrue);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await pumpEventQueue();
      expect(f.existsSync(), isFalse);
      expect(r.take, isNull);
      expect(r.hasPendingAudio, isFalse);
      expect(onDisk(), isEmpty);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    });

    test('resumed alone keeps the take (guard acts only on leaving)', () async {
      final r = recorder()..enabled = true;
      final guard = RecorderBackgroundGuard(r)..attach();
      addTearDown(guard.detach);
      r.add(_chunk(4800));
      final f = await r.seal();
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await pumpEventQueue();
      expect(f!.existsSync(), isTrue);
      await r.discard();
    });

    test('crash leftovers are swept', () async {
      takes.createSync(recursive: true);
      File('${takes.path}/take-7.wav').writeAsBytesSync([1, 2, 3]);
      File('${takes.path}/take-8.wav').writeAsBytesSync([4]);
      await recorder().sweep();
      expect(onDisk(), isEmpty);
    });

    test('delete all: current take and leftovers, folder ends empty', () async {
      final r = recorder()..enabled = true;
      r.add(_chunk(4800));
      final f = await r.seal();
      File('${takes.path}/take-99.wav').writeAsBytesSync([9, 9]);
      expect(onDisk(), hasLength(2));
      await r.deleteAll();
      expect(f!.existsSync(), isFalse);
      expect(onDisk(), isEmpty);
      expect(r.take, isNull);
    });
  });

  group('screen wiring', () {
    Future<bool> recorderEnabled(
      WidgetTester tester, {
      required bool open,
      required RetentionAudience audience,
    }) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final audio = AudioInputController(
        channel: FakeAudioCaptureChannel(),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final rec = recorder();
      await tester.pumpWidget(
        practiceHost(
          PracticeLoopScreen(
            lesson: V1Lesson.fromJson(
              jsonDecode(
                File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync(),
              ),
            ),
            progress: _Memory(),
            ownRecordingPreference: _Pref(),
            retentionOpen: open,
            audience: audience,
            controllerFactory: (score, tempo, criteria) =>
                PracticeSessionController(
                  score: score,
                  tempo: tempo,
                  audio: audio,
                  criteria: criteria,
                  analyzer: (r) async => judgeNote(r),
                  ownRecorder: rec,
                ),
          ),
        ),
      );
      for (var i = 0; i < 25; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final enabled = rec.enabled;
      await tester.pumpWidget(const SizedBox());
      return enabled;
    }

    testWidgets('flag closed: the setting alone decides (unchanged)', (
      tester,
    ) async {
      for (final a in RetentionAudience.values) {
        expect(
          await recorderEnabled(tester, open: false, audience: a),
          isTrue,
          reason: '$a',
        );
      }
    });

    testWidgets('flag open: child and unknown never record; adult does', (
      tester,
    ) async {
      for (final a in RetentionAudience.values) {
        expect(
          await recorderEnabled(tester, open: true, audience: a),
          a == RetentionAudience.adult,
          reason: '$a',
        );
      }
    });
  });

  test('copy promises no saving or export', () {
    final all = RecordingRetentionCopy.all
        .expand((c) => [c.$1, c.$2])
        .join(' ')
        .toLowerCase();
    for (final w in ['export', 'dışa aktar', 'save', 'kaydet', 'download']) {
      expect(all.contains(w), isFalse, reason: w);
    }
  });
}
