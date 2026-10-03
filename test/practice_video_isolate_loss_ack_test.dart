import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

void main() {
  test('fresh isolate owner has no Dart proof for a native-only release', () async {
    // The native fake outlives the conceptual Dart isolate. No owner is
    // reconstructed from a native release or an all-clear-looking callback.
    final port = FakePracticeAudioPort()..waitForNativeVideoRelease = true;
    await port.reserve(PracticeAudioSide.video, 'b' * 32);
    port.releaseNativeVideoForTest();
    final freshOwner = PracticeVideoSessionOwner(port: port);

    expect(
      await freshOwner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(port.videoDisposeConfirmations, isEmpty);
    expect((await port.readAllAudioState()).activeSide, PracticeAudioSide.video);
  });
}
