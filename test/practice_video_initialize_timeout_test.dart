import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/native_audio_state.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _LateInitializingPlayer implements PracticeVideoPlayerPort {
  final Completer<void> initialized = Completer<void>();
  int disposals = 0;

  @override
  Future<void> initialize(NativeAudioPermit permit) => initialized.future;

  @override
  Future<void> dispose() async {
    ++disposals;
  }
}

void main() {
  test(
    'late initialization cannot earn a true disposal acknowledgement',
    () async {
      final port = FakePracticeAudioPort();
      final player = _LateInitializingPlayer();
      final owner = PracticeVideoSessionOwner(
        port: port,
        operationTimeout: const Duration(milliseconds: 20),
      );
      expect(
        await owner.open(player, isCurrent: () => true),
        PracticeVideoOpenStatus.blockedUnconfirmed,
      );
      expect(player.disposals, 1);
      expect(port.videoDisposeCalls, 1);
      expect(port.videoDisposeConfirmations, [false]);
      expect(owner.blocked, isTrue);
      expect(
        (await port.readAllAudioState()).activeSide,
        PracticeAudioSide.video,
      );
      player.initialized.complete();
      await Future<void>.delayed(Duration.zero);
      expect((await port.readAllAudioState()).allClear, isFalse);
      expect(await owner.close(), isFalse);
      expect(port.videoDisposeConfirmations, [false]);
    },
  );
}
