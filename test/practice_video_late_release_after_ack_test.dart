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
  test('seen exact ACK plus late native release closes on two reads', () async {
    final port = FakePracticeAudioPort()..waitForNativeVideoRelease = true;
    final owner = PracticeVideoSessionOwner(
      port: port,
      operationTimeout: const Duration(milliseconds: 30),
    );
    expect(
      await owner.open(_Player(), isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );

    expect(await owner.close(), isFalse);
    expect(port.videoDisposeConfirmations, [true]);
    expect(owner.blocked, isTrue);
    port.releaseNativeVideoForTest();
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.confirmedClosed,
    );
    expect(port.videoDisposeCalls, 1);
    expect((await port.readAllAudioState()).allClear, isTrue);
  });
}
