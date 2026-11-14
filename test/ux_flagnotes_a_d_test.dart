// OST-UX-BAYRAK-ONCESI-NOTLAR: 05c Tur 2 notlari A ve D.
// A: guard (beforeStart) false doner, CAL tekrar basilir, guard ikinci kez
//    sorulur. D: baslatma penceresinde ek dokunus ikinci `_begin` baslatmaz.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/mic_permission_gate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';

import 'support/practice_host.dart';
import 'support/ux_05f_rig.dart';

V1Lesson _lesson() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

Future<Rig05f> _screen(
  WidgetTester t, {
  required Future<bool> Function() beforeStart,
  required void Function() onStarted,
}) async {
  final rig = Rig05f();
  await boot05f(
    t,
    practiceHost(
      PracticeLoopScreen(
        lesson: _lesson(),
        progress: Mem05f(),
        seed: 1,
        controllerFactory: rig.factory,
        onStarted: onStarted,
        beforeStart: beforeStart,
      ),
    ),
    size: const Size(420, 2400),
  );
  return rig;
}

Future<void> _tap(WidgetTester t) async {
  await t.tap(find.byKey(const Key('practice-start')));
  await t.pump();
  await t.pump();
}

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  testWidgets('A: guard false, CAL tekrar basilir, guard ikinci kez sorulur', (
    t,
  ) async {
    var asked = 0;
    var started = 0;
    final rig = await _screen(
      t,
      beforeStart: () async {
        asked++;
        return false;
      },
      onStarted: () => started++,
    );
    await _tap(t);
    expect(asked, 1);
    await _tap(t);
    expect(asked, 2, reason: '_starting sifirlandi, ikinci dokunus sorar');
    expect(started, 0);
    await dispose05f(t, rig);
  });

  testWidgets('D: izin penceresinde ek dokunus ikinci _begin baslatmaz', (
    t,
  ) async {
    final dialog = Completer<PermissionStatus>();
    var requests = 0;
    MicPermissionGate.status = () async => PermissionStatus.denied;
    MicPermissionGate.request = () {
      requests++;
      return dialog.future;
    };
    MicPermissionGate.knownGranted = false;
    addTearDown(() {
      MicPermissionGate.resetForTest();
      MicPermissionGate.knownGranted = true;
    });
    var started = 0;
    final rig = await _screen(
      t,
      beforeStart: () async => true,
      onStarted: () => started++,
    );
    await _tap(t);
    expect(started, 1);
    expect(requests, 1, reason: 'izin penceresi acik');
    expect(find.byKey(const Key('practice-start')), findsOneWidget);
    await _tap(t);
    await _tap(t);
    expect(requests, 1, reason: 'ikinci izin istegi yok');
    expect(started, 1, reason: 'ek dokunuslar _begin tekrarlamaz');
    dialog.complete(PermissionStatus.denied);
    await t.pump();
    await t.pump();
    await dispose05f(t, rig);
  });
}
