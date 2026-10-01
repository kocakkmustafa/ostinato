import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/native_audio_state.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _PendingPlayer implements PracticeVideoPlayerPort {
  final Completer<void> entered = Completer<void>();
  final Completer<void> initialized = Completer<void>();
  int disposals = 0;

  @override
  Future<void> initialize(NativeAudioPermit permit) {
    entered.complete();
    return initialized.future;
  }

  @override
  Future<void> dispose() async {
    ++disposals;
  }
}

void main() {
  test('context change during initialize never returns ready', () async {
    final port = FakePracticeAudioPort();
    final owner = PracticeVideoSessionOwner(port: port);
    final player = _PendingPlayer();
    final opening = owner.open(player, isCurrent: () => true);

    await player.entered.future;
    expect(
      (await port.readAllAudioState()).activeSide,
      PracticeAudioSide.video,
    );
    // The engine remains identical and Dart gets no root callback.
    port.advanceContextForTest();
    player.initialized.complete();

    expect(await opening, PracticeVideoOpenStatus.blockedUnconfirmed);
    expect(player.disposals, 1);
    expect(port.videoDisposeCalls, 0);
    expect(owner.blocked, isTrue);
    expect((await port.readAllAudioState()).allClear, isFalse);
  });
}
