import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../audio/audio_input_controller.dart';
import '../audio/practice_audio_root.dart';
import '../tuner/tuner_controller.dart';
import '../tuner/tunings.dart';
import 'debug/debug_fake_mic_channel.dart';
import 'loop/practice_score.dart';

/// `--dart-define=OSTINATO_FAKE_MIC=1` (or `mixed`) / `clean`.
const String _fakeMicDefine = String.fromEnvironment('OSTINATO_FAKE_MIC');

/// The simulated microphone (`debug/debug_fake_mic_channel.dart`) for the
/// simulator. Both operands are compile-time constants and `kDebugMode` is
/// false in profile and release, so there the branches below are dead code
/// and the fake is not compiled in. Never a setting the user can reach.
const bool kFakeMicEnabled =
    kDebugMode && _fakeMicDefine != '' && _fakeMicDefine != '0';

FakeMicMode get _fakeMicMode =>
    _fakeMicDefine == 'clean' ? FakeMicMode.clean : FakeMicMode.mixed;

/// What the practice screen is about to play: read by the debug fake only.
typedef PracticeLessonTimeline = ({
  PracticeScore score,
  int countInBeats,
  ({double start, double end})? loop,
  int? heldMidi,
});

/// Capture controller for the practice loop and the setup wizard.
/// [lesson] tells the debug fake what to play (ignored otherwise).
AudioInputController createPracticeAudioInput({
  PracticeLessonTimeline Function()? lesson,
}) {
  if (kFakeMicEnabled) {
    return debugFakeMicInput(
      mode: _fakeMicMode,
      performance: lesson == null
          ? null
          : () {
              final l = lesson();
              return FakeMicPerformance(
                score: l.score,
                countInBeats: l.countInBeats,
                loop: l.loop,
                heldMidi: l.heldMidi,
              );
            },
    );
  }
  return AudioInputController();
}

/// The capture action for this route, or null with the debug fake (it has
/// no native capture to claim; the unused action is retired).
PracticeAudioCaptureAction? practiceCaptureActionFor(BuildContext context) {
  final action = PracticeAudioCaptureScope.actionFor(context);
  if (kFakeMicEnabled) {
    action?.retire();
    return null;
  }
  return action;
}

/// A tuner controller on the debug fake, or null (production tuner).
TunerController? debugFakeTunerController(TuningPreset preset) {
  if (kFakeMicEnabled) {
    return TunerController(
      preset: preset,
      source: debugFakeMicInput(mode: FakeMicMode.clean),
    );
  }
  return null;
}
