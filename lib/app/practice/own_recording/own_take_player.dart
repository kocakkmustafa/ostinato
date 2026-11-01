import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app_theme.dart';
import '../../design/ostinato_theme.dart';
import '../../ui_copy.dart';
import 'own_recording.dart';
import 'own_recording_copy.dart';

/// FK2 on the result screen: shown only while [recorder] holds a take. The
/// player opens the local file on the first "Listen"; nothing is streamed.
class OwnTakeSection extends StatelessWidget {
  const OwnTakeSection({super.key, required this.recorder});
  final OwnRecorder recorder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: recorder,
    builder: (context, _) {
      final take = recorder.take;
      if (take == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _OwnTakePlayer(key: ValueKey(take.path), take: take),
      );
    },
  );
}

class _OwnTakePlayer extends StatefulWidget {
  const _OwnTakePlayer({super.key, required this.take});
  final File take;

  @override
  State<_OwnTakePlayer> createState() => _OwnTakePlayerState();
}

class _OwnTakePlayerState extends State<_OwnTakePlayer> {
  VideoPlayerController? _player;
  bool _failed = false;

  bool get _playing => _player?.value.isPlaying ?? false;

  Future<void> _toggle() async {
    try {
      var player = _player;
      if (player == null) {
        player = _player = VideoPlayerController.file(widget.take)
          ..addListener(_changed);
        await player.initialize();
      }
      if (player.value.isPlaying) {
        await player.pause();
      } else {
        if (player.value.position >= player.value.duration) {
          await player.seekTo(Duration.zero);
        }
        await player.play();
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) {
      player.removeListener(_changed);
      unawaited(player.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Container(
      key: const Key('own-take'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.controlSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kicker(uiText(context, OwnRecordingCopy.takeTitle)),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('own-take-toggle'),
            onPressed: _failed ? null : _toggle,
            child: Text(
              uiText(
                context,
                _playing ? OwnRecordingCopy.pause : OwnRecordingCopy.listen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            uiText(
              context,
              _failed ? OwnRecordingCopy.playFailed : OwnRecordingCopy.takeNote,
            ),
            style: hankenText(
              size: 11.5,
              color: _failed ? palette.warnInk : palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
