import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/native_audio_state.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _HangingPlayer implements PracticeVideoPlayerPort {
  final Completer<void> disposal = Completer<void>();

  @override
  Future<void> initialize(NativeAudioPermit permit) async {}

  @override
  Future<void> dispose() => disposal.future;
}

void main() {
  test('timed-out disposal cannot release video for a late callback', () async {
    final port = FakePracticeAudioPort();
    final player = _HangingPlayer();
    final owner = PracticeVideoSessionOwner(
      port: port,
      operationTimeout: const Duration(milliseconds: 20),
    );
    expect(
      await owner.open(player, isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );
    expect(await owner.close(), isFalse);
    expect(owner.blocked, isTrue);
    expect(port.videoDisposeCalls, 1);
    expect(port.videoDisposeConfirmations, [false]);
    expect((await port.readAllAudioState()).allClear, isFalse);
    player.disposal.complete();
    await Future<void>.delayed(Duration.zero);
    expect(
      (await port.readAllAudioState()).activeSide,
      PracticeAudioSide.video,
    );
    expect(await owner.close(), isFalse);
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(port.videoDisposeConfirmations, [false]);
  });
}
