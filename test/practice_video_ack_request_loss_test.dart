import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _Player implements PracticeVideoPlayerPort {
  NativeAudioPermit? permit;
  int disposals = 0;

  @override
  Future<void> initialize(NativeAudioPermit value) async {
    permit = value;
  }

  @override
  Future<void> dispose() async {
    ++disposals;
  }
}

void main() {
  test('lost ACK request retries only the original successful disposal', () async {
    final port = FakePracticeAudioPort()
      ..waitForNativeVideoRelease = true
      ..dropNextVideoDisposeRequest = true;
    port.onVideoDisposeAcknowledged = port.releaseNativeVideoForTest;
    final owner = PracticeVideoSessionOwner(port: port);
    final player = _Player();

    expect(
      await owner.open(player, isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );
    final originalPermit = player.permit!;
    expect(await owner.close(), isFalse);
    expect(owner.blocked, isTrue);
    expect(player.disposals, 1);
    expect(port.videoDisposeConfirmations, [true]);
    expect((await port.readAllAudioState()).activeSide, PracticeAudioSide.video);

    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.confirmedClosed,
    );
    expect(port.videoDisposeConfirmations, [true, true]);
    expect(
      port.videoDisposePermits.every(
        (permit) => identical(permit, originalPermit),
      ),
      isTrue,
    );
    expect(player.disposals, 1);
    expect(owner.blocked, isFalse);
    expect((await port.readAllAudioState()).allClear, isTrue);
  });
}
