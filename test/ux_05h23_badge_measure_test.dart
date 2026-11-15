// OST-UX-05h-23 (review): the calibration badge keeps one line next to the
// "Metronom hazir" label at the narrow sizes and text scales. Test only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

final class _Progress implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async =>
      V1PracticeRecord(lessonId: id).withRun(s, DateTime.utc(2026, 11, 1));
}

void main() {
  final lesson = V1Lesson.fromJson(
    jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
  );
  for (final size in <Size>[const Size(360, 640), const Size(390, 844)]) {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('rozet olcusu ${size.width.toInt()}x${size.height.toInt()} '
          'yazi $scale', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final audio = AudioInputController(
          channel: FakeAudioCaptureChannel(),
          requestMicrophonePermission: () async => PermissionStatus.granted,
        );
        await t.pumpWidget(
          practiceHost(
            locale: 'tr',
            Builder(
              builder: (c) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: PracticeLoopScreen(
                  lesson: lesson,
                  progress: _Progress(),
                  setupStore: MemorySetupProfileStore(),
                  openSetup: (_, _) async {},
                  controllerFactory: (score, tempo, criteria) =>
                      PracticeSessionController(
                        score: score,
                        tempo: tempo,
                        audio: audio,
                        criteria: criteria,
                      ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final badge = find.byKey(const Key('practice-calibration-badge'));
        final label = find.text('Metronom hazır');
        expect(badge, findsOneWidget);
        expect(label, findsOneWidget);
        final b = t.getSize(badge);
        final l = t.getSize(label);
        expect(t.takeException(), isNull, reason: 'tasma yok');
        // Olcum, duzeltmeden onceki main (71bec22) ile: 1.0'da rozet
        // yuksekligi main'dekinden buyuk olamaz (360: 42, 390: 56) ve
        // etiket dogal genisligini (173.6) korur; 2.0'da main'de rozet
        // 0 px genislikte 783 px yuksekti, simdi okunur.
        if (scale == 1.0) {
          expect(b.height, lessThanOrEqualTo(size.width == 360 ? 42 : 56));
          expect(l.width, closeTo(173.6, 0.5));
          expect(l.height, lessThanOrEqualTo(16.5), reason: 'etiket tek satir');
        } else {
          expect(b.width, greaterThanOrEqualTo(100));
          expect(b.height, lessThanOrEqualTo(180));
          expect(t.getRect(label).right, lessThanOrEqualTo(size.width));
        }
        expect(t.getRect(badge).right, lessThanOrEqualTo(size.width));
      });
    }
  }
}
