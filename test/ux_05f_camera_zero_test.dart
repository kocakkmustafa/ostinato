// OST-UX-05f criterion 3 (T8): stage / permission / setup paths never ask
// for the camera while the camera flags are closed. The permission_handler
// platform channel is counted for the camera permission (value 1).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/ux_05f_rig.dart';

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  var cameraCalls = 0;
  void install() {
    cameraCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async {
            final a = call.arguments;
            final ids = a is List ? a.cast<int>() : <int>[if (a is int) a];
            if (ids.contains(Permission.camera.value)) cameraCalls++;
            return switch (call.method) {
              'requestPermissions' => {for (final i in ids) i: 0},
              'checkPermissionStatus' => 0,
              _ => null,
            };
          },
        );
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
  });

  test('05f-3a: the camera flags ship closed', () {
    expect(ostinatoCameraPracticeAvailable, isFalse);
  });

  testWidgets('05f-3b: stage + refusal asks for the camera 0 times', (t) async {
    install();
    final rig = Rig05f(permission: PermissionStatus.denied);
    await boot05f(t, stage05f(rig, catalog));
    await play05f(t);
    expect(cameraCalls, 0);
    await dispose05f(t, rig);
  });

  testWidgets(
    '05f-3c: refusal + Setup/Device layer open: camera 0 times, layer reached',
    (t) async {
      install();
      final rig = Rig05f(permission: PermissionStatus.denied);
      await boot05f(t, stage05f(rig, catalog));
      await play05f(t);
      await t.tap(find.byKey(const Key('stage-handle-setup')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stage-device-layer')), findsOneWidget);
      expect(cameraCalls, 0);
      await dispose05f(t, rig);
    },
  );
}
