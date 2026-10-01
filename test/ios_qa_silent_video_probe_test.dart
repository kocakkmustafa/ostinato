import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/course/media/ios_qa_silent_video_probe.dart';
import 'package:ostinato/app/course/media/native_silent_lesson_video.dart';

const _asset = 'assets/content/media/ostinato/course-a/lesson.v1.mp4';
const _channel = MethodChannel('com.yulalab.ostinato/qa_silent_video_probe');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test('valid bundled MP4 reaches QA native channel only', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return true;
    });
    expect(await debugInspectIOSSilentBundledMp4(_asset), isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'inspectBundledMp4');
    expect(calls.single.arguments, {'asset': _asset});
    // A probe receipt is never an iOS video-player enable switch.
    expect(
      () => createDebugAssetSilentLessonVideo(_asset, 'WEBVTT\n\n'),
      throwsStateError,
    );
  });

  test('invalid paths fail before invoking native code', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls++;
      return true;
    });
    for (final name in [
      '../lesson.mp4',
      'file:///tmp/lesson.mp4',
      'https://example.com/lesson.mp4',
      'assets/content/media/ostinato/../lesson.mp4',
      'assets/content/media/ostinato//lesson.mp4',
      'assets/content/media/ostinato/%2e%2e/lesson.mp4',
      'assets/content/media/ostinato/lesson.mov',
      'assets/content/media/other/lesson.mp4',
    ]) {
      expect(
        debugIsAllowedIOSSilentVideoAssetName(name),
        isFalse,
        reason: name,
      );
      expect(await debugInspectIOSSilentBundledMp4(name), isFalse);
    }
    expect(calls, 0);
  });

  test('unknown, error, and late native results fail closed', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async => null);
    expect(await debugInspectIOSSilentBundledMp4(_asset), isFalse);
    messenger.setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await debugInspectIOSSilentBundledMp4(_asset), isFalse);

    final pending = Completer<bool>();
    messenger.setMockMethodCallHandler(_channel, (call) => pending.future);
    expect(
      await debugInspectIOSSilentBundledMp4(
        _asset,
        deadline: const Duration(milliseconds: 10),
      ),
      isFalse,
    );
    pending.complete(true);
  });

  test('other platforms do not call the iOS channel', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls++;
      return true;
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await debugInspectIOSSilentBundledMp4(_asset), isFalse);
    expect(calls, 0);
  });
}
