// Simulator 2026-11-02: the first start after "Allow" failed because the
// capture action was minted before the prompt, and the prompt's dismissal
// (inactive -> resumed) retired it. The learner had to tap Start twice.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/mic_permission_gate.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> log;
  late Completer<PermissionStatus> prompt;
  late bool mounted;

  setUp(() {
    log = [];
    mounted = true;
    prompt = Completer<PermissionStatus>();
    MicPermissionGate.knownGranted = false;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    MicPermissionGate.quiet = const Duration(milliseconds: 60);
    MicPermissionGate.timeout = const Duration(milliseconds: 600);
    MicPermissionGate.request = () {
      log.add('request');
      return prompt.future;
    };
  });
  tearDown(MicPermissionGate.resetForTest);

  Future<void> tap() => MicPermissionGate.run(
    mounted: () => mounted,
    mint: () {
      log.add('mint');
      return null;
    },
    start: (_) async => log.add('start'),
  );

  void lifecycle(AppLifecycleState s) =>
      binding.handleAppLifecycleStateChanged(s);

  test('granted already: mints and starts at once, no prompt', () async {
    MicPermissionGate.status = () async => PermissionStatus.granted;
    await tap();
    expect(log, ['mint', 'start']);
  });

  test('first grant: mints only after the dismissal bounce settles', () async {
    MicPermissionGate.status = () async => PermissionStatus.denied;
    final done = tap();
    await pumpEventQueue();
    expect(log, ['request']);
    prompt.complete(PermissionStatus.granted);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // The prompt's dismissal resigns and regains active after the grant.
    lifecycle(AppLifecycleState.inactive);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(log, ['request'], reason: 'nothing minted inside the bounce');
    lifecycle(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(log, ['request'], reason: 'still inside the quiet period');
    await done;
    expect(log, ['request', 'mint', 'start']);
  });

  test('background during the prompt: nothing starts', () async {
    MicPermissionGate.status = () async => PermissionStatus.denied;
    final done = tap();
    await pumpEventQueue();
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    prompt.complete(PermissionStatus.granted);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await done;
    expect(log, ['request']);
  });

  test('screen left during the prompt: nothing starts', () async {
    MicPermissionGate.status = () async => PermissionStatus.denied;
    final done = tap();
    await pumpEventQueue();
    mounted = false;
    prompt.complete(PermissionStatus.granted);
    await done;
    expect(log, ['request']);
  });

  test('denied: the controller path reports it', () async {
    MicPermissionGate.status = () async => PermissionStatus.denied;
    final done = tap();
    await pumpEventQueue();
    prompt.complete(PermissionStatus.permanentlyDenied);
    await done;
    expect(log, ['request', 'mint', 'start']);
  });

  test('a second tap while the prompt is open is ignored', () async {
    MicPermissionGate.status = () async => PermissionStatus.denied;
    final first = tap();
    await pumpEventQueue();
    await tap();
    expect(log, ['request']);
    prompt.complete(PermissionStatus.granted);
    await first;
    expect(log, ['request', 'mint', 'start']);
  });

  test('after a grant, later taps start synchronously', () async {
    MicPermissionGate.status = () async => PermissionStatus.granted;
    await tap();
    log.clear();
    MicPermissionGate.status = () => throw StateError('not asked again');
    final done = tap();
    expect(log, ['mint', 'start'], reason: 'no await before the start');
    await done;
  });

  test('no plugin: falls back to the old ordering', () async {
    MicPermissionGate.status = () => Future.error(MissingPluginException());
    await tap();
    expect(log, ['mint', 'start']);
  });
}
