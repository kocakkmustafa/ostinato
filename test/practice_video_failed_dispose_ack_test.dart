import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _FailingPlayer implements PracticeVideoPlayerPort {
  @override
  Future<void> initialize(NativeAudioPermit permit) async {}

  @override
  Future<void> dispose() async {
    throw StateError('dispose failed');
  }
}

void main() {
  test('failed dispose and native release cannot create Dart ACK', () async {
    final port = FakePracticeAudioPort()..waitForNativeVideoRelease = true;
    final owner = PracticeVideoSessionOwner(port: port);
    expect(
      await owner.open(_FailingPlayer(), isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );

    expect(await owner.close(), isFalse);
    expect(port.videoDisposeConfirmations, [false]);
    port.releaseNativeVideoForTest();
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(port.videoDisposeConfirmations, [false]);
    expect((await port.readAllAudioState()).allClear, isFalse);
    expect(owner.blocked, isTrue);
  });
}
