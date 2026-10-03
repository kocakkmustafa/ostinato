import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

// This case intentionally leaves the isolate process owner quarantined.
// Keep it in its own test file/isolate so it cannot poison later assertions.
void main() {
  test('orphaned native release without Dart ACK stays blocked', () async {
    final user = ValueNotifier<String?>('A');
    final identity = ValueNotifier(MotionIdentityPhase.verified);
    final port = FakePracticeAudioPort();
    final video = PracticeVideoSessionOwner(port: port);
    final root = PracticeAudioRootOwner(
      userId: user,
      phase: identity,
      lease: PracticeAudioLease(port: port),
      videoOwner: video,
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowVideoAcquisitionForTest: true,
    );
    final observer = PracticeAudioRouteObserver(root);
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'lesson'),
      builder: (_) => const SizedBox(),
    );
    root.attachNavigator(observer);
    observer.didPush(route, null);
    await root.lastFenceForTest;
    port.waitForNativeVideoRelease = true;
    await port.reserve(PracticeAudioSide.video, 'd' * 32);
    port.releaseNativeVideoForTest();
    expect((await port.readAllAudioState()).allClear, isFalse);
    expect(await root.recover(), PracticeAudioReleaseStatus.blockedUnconfirmed);
    expect((await port.readAllAudioState()).allClear, isFalse);
    root.dispose();
    await root.lastFenceForTest;
    user.dispose();
    identity.dispose();
  });
}
