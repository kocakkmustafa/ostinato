// The practice screen's footer must not say "nothing is recorded" while
// "Listen to my own recording" is on: then this run IS kept on the device
// (OwnRecorder writes a temporary WAV until the next run or leaving the
// lesson). Found by the surface-honesty re-measurement of the new writers.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/own_recording/own_recording.dart';
import 'package:ostinato/app/practice/own_recording/own_recording_copy.dart';
import 'package:ostinato/app/practice/own_recording/own_recording_preference.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

const _off =
    'Stop for pain, numbness or tingling. Audio stays in memory on this device; nothing is recorded or sent.';

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
  _Pref(this.on);
  final bool on;
  @override
  Future<bool> read() async => on;
  @override
  Future<void> write(bool enabled) async {}
}

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  for (final on in [false, true]) {
    testWidgets('footer with own recording ${on ? 'on' : 'off'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final temp = Directory.systemTemp.createTempSync('own-rec-footer');
      addTearDown(() => temp.deleteSync(recursive: true));
      final audio = AudioInputController(
        channel: FakeAudioCaptureChannel(),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await tester.pumpWidget(
        practiceHost(
          PracticeLoopScreen(
            lesson: V1Lesson.fromJson(
              jsonDecode(
                File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync(),
              ),
            ),
            progress: _Memory(),
            ownRecordingPreference: _Pref(on),
            controllerFactory: (score, tempo, criteria) =>
                PracticeSessionController(
                  score: score,
                  tempo: tempo,
                  audio: audio,
                  criteria: criteria,
                  analyzer: (r) async => judgeNote(r),
                  ownRecorder: OwnRecorder(temporaryRoot: () async => temp),
                ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      if (on) {
        expect(find.text(OwnRecordingCopy.practiceFooterOn.$1), findsOneWidget);
        expect(find.text(_off), findsNothing);
      } else {
        expect(find.text(_off), findsOneWidget);
        expect(
          find.text(OwnRecordingCopy.practiceFooterOn.$1),
          findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
