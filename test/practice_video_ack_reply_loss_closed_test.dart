import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _Player implements PracticeVideoPlayerPort {
  @override
  Future<void> initialize(NativeAudioPermit permit) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  test('lost final ACK reply needs an exact native receipt contract', () async {
    final port = FakePracticeAudioPort()
      ..waitForNativeVideoRelease = true
      ..dropNextVideoDisposeReply = true;
    final owner = PracticeVideoSessionOwner(port: port);
    expect(
      await owner.open(_Player(), isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );

    expect(await owner.close(), isFalse);
    port.releaseNativeVideoForTest();
    expect((await port.readAllAudioState()).allClear, isTrue);
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(owner.blocked, isTrue);
    // The existing port exposes no exact ACK receipt after a cleared lease.
    // Native all-clear alone must not complete the Dart claim.
    expect(port.videoDisposeCalls, 1);
    expect(port.videoDisposeConfirmations, [true]);
  });
}
