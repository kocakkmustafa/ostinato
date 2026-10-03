import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _Player implements PracticeVideoPlayerPort {
  NativeAudioPermit? permit;

  @override
  Future<void> initialize(NativeAudioPermit value) async {
    permit = value;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('old proof cannot ACK a second claim or a replacement engine', () async {
    final port = FakePracticeAudioPort()..dropNextVideoDisposeRequest = true;
    final owner = PracticeVideoSessionOwner(port: port);
    final player = _Player();
    expect(
      await owner.open(player, isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );
    final originalPermit = player.permit!;
    expect(await owner.close(), isFalse);
    expect(port.videoDisposePermits.single, same(originalPermit));

    // Adversarial fake overwrites the held lease with a newer claim. Native
    // arbitration must reject this too; Dart must not even send its old ACK.
    final newer = await port.reserve(PracticeAudioSide.video, 'c' * 32);
    expect(newer.leaseGeneration, isNot(originalPermit.leaseGeneration));
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(port.videoDisposeCalls, 1);

    port.replaceEngineForTest();
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(port.videoDisposeCalls, 1);
    expect(owner.blocked, isTrue);
  });
}
