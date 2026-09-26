/// Instrument-independent musical audio analysis for Ostinato.
///
/// Scope boundary (family contract, `00-AILE-MIMARISI` §2): audio analysis and
/// instrument detection belong to Ostinato, never to motion_core — the rest of
/// the family lives without them. What this package does *not* own: the beat
/// grid, output-latency calibration and the shared monotonic clock, all of
/// which come from motion_core so that a cue is timed the same way in a dance
/// app and a cello app.
///
/// Like motion_core, this is the **normative reference**: the realtime loop
/// runs natively for latency, and native ports are validated by replaying the
/// same fixtures against this implementation. When they disagree, this package
/// is right by definition.
library;

export 'src/capture/audio_route.dart';
export 'src/capture/audio_source.dart';
export 'src/capture/audio_surface_state.dart';
export 'src/capture/ring_buffer.dart';
export 'src/contract/guitar_chord_drill_contract.dart';
export 'src/fixture/synthetic.dart';
export 'src/gate/audio_confidence_gate.dart';
export 'src/gate/guitar_chord_drill_evaluator.dart';
export 'src/harmony/chord_detector.dart';
export 'src/harmony/chroma.dart';
export 'src/harmony/midi_chord_detector.dart';
export 'src/onset/onset_detector.dart';
export 'src/pitch/pitch_source.dart';
export 'src/pitch/guitar_single_note_evaluator.dart';
export 'src/pitch/guitar_pitch_observer.dart';
export 'src/pitch/yin.dart';
export 'src/rhythm/metronome_aligner.dart';
