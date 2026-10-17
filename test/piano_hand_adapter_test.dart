import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/piano/hand_source.dart';
import 'package:ostinato/app/piano/piano_hand_observer.dart';
import 'package:ostinato/app/piano/piano_hand_session.dart';
import 'package:ostinato/app/screens/piano_hand_support_notice.dart';

// Entirely isolated software fixture: no native camera, audio/model inference,
// first-party performance, teacher judgement, file, network or progress store.
final hand = HandProviderIdentity(
  id: 'test.hand.replay',
  version: '1.0.0',
  artifactSha256: '1' * 64,
  mode: HandEvidenceMode.replay,
  inputSchema: 'hand21.normalized_image.v1',
);
final audioProvider = HandProviderIdentity(
  id: 'test.audio.replay',
  version: '1.0.0',
  artifactSha256: '2' * 64,
  mode: HandEvidenceMode.replay,
  inputSchema: 'audio.monophonic_onset.v1',
);
HandCaptureBinding binding({
  bool mirrored = false,
  String id = 'capture-1',
  int rotation = 0,
  String clock = 'hand-clock',
  String camera = 'front',
  int width = 1000,
}) => HandCaptureBinding(
  captureId: id,
  cameraId: camera,
  clockId: clock,
  width: width,
  height: 800,
  rotationDegrees: rotation,
  mirrored: mirrored,
);
PianoKeyRegion region(int midi, double start, double end) => PianoKeyRegion(
  midi: midi,
  corners: [
    KeyboardPoint(start, .2),
    KeyboardPoint(end, .2),
    KeyboardPoint(end, .8),
    KeyboardPoint(start, .8),
  ],
);
PianoKeyboardMap map({
  HandCaptureBinding? capture,
  int version = 1,
  List<PianoKeyRegion>? regions,
}) => PianoKeyboardMap(
  schemaVersion: version,
  id: 'synthetic-map-v1',
  sha256: '3' * 64,
  provider: hand,
  binding: capture ?? binding(),
  minimumVisibility: .8,
  keys:
      regions ??
      [
        for (var i = 0; i < 5; i++)
          region([60, 62, 64, 65, 67][i], .1 + i * .15, .25 + i * .15),
      ],
);
PianoClockCalibration clock({
  String handClock = 'hand-clock',
  String audioClock = 'audio-clock',
  String audioCapture = 'audio-1',
  int version = 1,
  int until = 1000000,
}) => PianoClockCalibration(
  schemaVersion: version,
  id: 'synthetic-clock-v1',
  sha256: '4' * 64,
  handClockId: handClock,
  handCaptureId: 'capture-1',
  audioClockId: audioClock,
  audioCaptureId: audioCapture,
  audioProvider: audioProvider,
  audioMinusHandUs: 500,
  maximumSkewUs: 20000,
  maximumFrameGapUs: 100000,
  validFromHandUs: 0,
  validUntilHandUs: until,
  minimumAudioConfidence: .8,
);
HandFrame frame({
  int time = 10000,
  HandCaptureBinding? capture,
  PhysicalHand side = PhysicalHand.right,
  List<HandPoint>? points,
  HandProviderIdentity? provider,
  double thumbX = .175,
}) => HandFrame(
  provider: provider ?? hand,
  binding: capture ?? binding(),
  hand: side,
  tUs: time,
  points:
      points ??
      [for (var i = 0; i < 21; i++) HandPoint(i == 4 ? thumbX : .5, .5, 1)],
);
PianoAudioOnset onset({
  int time = 10500,
  int midi = 60,
  bool mono = true,
  double confidence = 1,
  String clockId = 'audio-clock',
  String capture = 'audio-1',
  String id = 'event-1',
  HandProviderIdentity? provider,
}) => PianoAudioOnset(
  provider: provider ?? audioProvider,
  captureId: capture,
  clockId: clockId,
  eventId: id,
  tUs: time,
  midi: midi,
  confidence: confidence,
  monophonic: mono,
);
PianoHandObserver observer({
  PianoKeyboardMap? keyboard,
  PianoClockCalibration? timing,
  bool noMap = false,
  bool noClock = false,
  HandEvidenceMode mode = HandEvidenceMode.replay,
}) => PianoHandObserver(
  provider: hand,
  expectedMode: mode,
  keyboardMap: noMap ? null : (keyboard ?? map()),
  clockCalibration: noClock ? null : (timing ?? clock()),
);

final class ReplayHandSource implements HandSource {
  ReplayHandSource({this.startGate});
  final Future<void>? startGate;
  final data = StreamController<HandFrame>.broadcast();
  final states = StreamController<HandSourceStatus>.broadcast();
  int starts = 0, stops = 0;
  @override
  HandProviderIdentity get identity => hand;
  @override
  Stream<HandFrame> get frames => data.stream;
  @override
  Stream<HandSourceStatus> get status => states.stream;
  @override
  Future<void> start() async {
    starts++;
    await startGate;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await data.close();
    await states.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('candidate preserves replay provenance and exact note/finger scope', () {
    final observed = observer().observe(
      frame(),
      targetMidi: 60,
      audio: onset(),
    );
    expect(observed.state, PianoHandState.contactCandidate);
    expect(observed.reason, PianoHandReason.projectedFingerAndIndependentOnset);
    expect(observed.mode, HandEvidenceMode.replay);
    expect(observed.midi, 60);
    expect(observed.finger, PianoFinger.thumb);
  });
  test('all five selected notes use their own visible finger and key', () {
    for (var i = 0; i < 5; i++) {
      final midi = [60, 62, 64, 65, 67][i], tip = i * 4 + 4;
      final points = [
        for (var j = 0; j < 21; j++)
          HandPoint(j == tip ? .175 + i * .15 : .5, .5, 1),
      ];
      final result = observer().observe(
        frame(points: points),
        targetMidi: midi,
        audio: onset(midi: midi),
      );
      expect(result.state, PianoHandState.contactCandidate);
      expect(result.finger, PianoFinger.values[i]);
    }
  });
  test(
    'production requirement rejects replay even with matching calibration',
    () {
      expect(
        observer(
          mode: HandEvidenceMode.production,
        ).observe(frame(), targetMidi: 60, audio: onset()).state,
        PianoHandState.unsupported,
      );
    },
  );
  test(
    'shipping source is unsupported and emits no fabricated frames',
    () async {
      final source = createProductionHandSource();
      expect(source.identity.mode, HandEvidenceMode.unavailable);
      expect(source.identity.artifactSha256, isNull);
      expect(await source.frames.toList(), isEmpty);
      expect(await source.status.single, HandSourceStatus.unsupported);
      await source.start();
      await source.stop();
      await source.dispose();
    },
  );
  for (final midi in [48, 61, 68, 72]) {
    test('unsupported target $midi cannot produce a candidate', () {
      expect(
        observer().observe(frame(), targetMidi: midi, audio: onset()).state,
        PianoHandState.unsupported,
      );
    });
  }
  test('another course/lesson cannot borrow the piano-05 observation', () {
    expect(
      observer()
          .observe(
            frame(),
            targetMidi: 60,
            selectedLessonId: 'piano-06',
            audio: onset(),
          )
          .state,
      PianoHandState.unsupported,
    );
    expect(
      observer()
          .observe(
            frame(),
            targetMidi: 60,
            selectedCourseId: 'guitar.journey',
            audio: onset(),
          )
          .state,
      PianoHandState.unsupported,
    );
  });
  test('missing maps and clock calibration abstain instead of scoring', () {
    expect(
      observer(
        noMap: true,
      ).observe(frame(), targetMidi: 60, audio: onset()).state,
      PianoHandState.calibrationRequired,
    );
    expect(
      observer(
        noClock: true,
      ).observe(frame(), targetMidi: 60, audio: onset()).state,
      PianoHandState.calibrationRequired,
    );
    expect(
      observer().observe(frame(), targetMidi: 60).state,
      PianoHandState.hover,
    );
  });
  for (final variant in [
    'camera',
    'rotation',
    'mirror',
    'capture',
    'clock',
    'dimensions',
  ]) {
    test(
      '$variant change retires the old calibration until a fresh observer',
      () {
        final b = binding(
          camera: variant == 'camera' ? 'back' : 'front',
          rotation: variant == 'rotation' ? 90 : 0,
          mirrored: variant == 'mirror',
          id: variant == 'capture' ? 'capture-2' : 'capture-1',
          clock: variant == 'clock' ? 'new-hand-clock' : 'hand-clock',
          width: variant == 'dimensions' ? 1200 : 1000,
        );
        final engine = observer();
        expect(
          engine
              .observe(frame(capture: b), targetMidi: 60, audio: onset())
              .state,
          PianoHandState.calibrationRequired,
        );
        expect(
          engine
              .observe(frame(time: 11000), targetMidi: 60, audio: onset())
              .state,
          PianoHandState.calibrationRequired,
        );
      },
    );
  }
  test(
    'explicitly matched mirrored map keeps physical right hand identity',
    () {
      final b = binding(mirrored: true);
      expect(
        observer(
          keyboard: map(capture: b),
        ).observe(frame(capture: b), targetMidi: 60, audio: onset()).state,
        PianoHandState.contactCandidate,
      );
    },
  );
  for (final side in [PhysicalHand.left, PhysicalHand.unknown]) {
    test('physical $side is unobservable for this right-hand task', () {
      expect(
        observer()
            .observe(frame(side: side), targetMidi: 60, audio: onset())
            .reason,
        PianoHandReason.wrongHand,
      );
    });
  }
  test(
    'required finger/wrist visibility loss blocks audio from inventing a finger',
    () {
      for (final index in [0, 1, 2, 3, 4]) {
        final points = List<HandPoint>.from(frame().points)
          ..[index] = const HandPoint(.175, .5, .1);
        expect(
          observer()
              .observe(frame(points: points), targetMidi: 60, audio: onset())
              .reason,
          PianoHandReason.lowVisibility,
        );
      }
    },
  );
  test(
    'partial, malformed or non-finite landmarks never produce a candidate',
    () {
      for (final points in [
        <HandPoint>[],
        List<HandPoint>.filled(20, const HandPoint(.1, .5, 1)),
        List<HandPoint>.from(frame().points)
          ..[4] = HandPoint(double.nan, .5, 1),
        List<HandPoint>.from(frame().points)..[4] = const HandPoint(1.1, .5, 1),
      ]) {
        expect(
          observer()
              .observe(frame(points: points), targetMidi: 60, audio: onset())
              .reason,
          PianoHandReason.invalidHandFrame,
        );
      }
    },
  );
  test('wrong key, border and outside keyboard abstain', () {
    expect(
      observer()
          .observe(frame(thumbX: .325), targetMidi: 60, audio: onset())
          .reason,
      PianoHandReason.wrongKey,
    );
    expect(
      observer()
          .observe(frame(thumbX: .25), targetMidi: 60, audio: onset())
          .reason,
      PianoHandReason.ambiguousKey,
    );
    expect(
      observer()
          .observe(frame(thumbX: .95), targetMidi: 60, audio: onset())
          .reason,
      PianoHandReason.outsideKeyboard,
    );
  });
  test(
    'invalid version, overlapping or degenerate keyboard maps stay closed',
    () {
      final invalid = [
        map(version: 2),
        map(
          regions: [
            for (final m in [60, 62, 64, 65, 67]) region(m, .1, .4),
          ],
        ),
        map(
          regions: [
            region(60, .1, .1),
            for (var i = 1; i < 5; i++)
              region([60, 62, 64, 65, 67][i], .1 + i * .15, .25 + i * .15),
          ],
        ),
      ];
      for (final candidate in invalid) {
        expect(candidate.valid, isFalse);
        expect(
          observer(
            keyboard: candidate,
          ).observe(frame(), targetMidi: 60, audio: onset()).state,
          PianoHandState.calibrationRequired,
        );
      }
    },
  );
  for (final variant in [
    'wrongNote',
    'polyphonic',
    'quiet',
    'nan',
    'outOfSync',
    'unknownProvider',
  ]) {
    test(
      'audio $variant contradicts a projected finger and cannot certify contact',
      () {
        final event = onset(
          midi: variant == 'wrongNote' ? 62 : 60,
          mono: variant != 'polyphonic',
          confidence: variant == 'quiet'
              ? .1
              : (variant == 'nan' ? double.nan : 1),
          time: variant == 'outOfSync' ? 50000 : 10500,
          provider: variant == 'unknownProvider' ? hand : null,
        );
        expect(
          observer().observe(frame(), targetMidi: 60, audio: event).state,
          PianoHandState.unobservable,
        );
      },
    );
  }
  for (final variant in ['audio-clock', 'audio-capture']) {
    test('$variant mismatch requires explicit recalibration', () {
      final event = onset(
        clockId: variant == 'audio-clock' ? 'wrong' : 'audio-clock',
        capture: variant == 'audio-capture' ? 'audio-2' : 'audio-1',
      );
      expect(
        observer().observe(frame(), targetMidi: 60, audio: event).state,
        PianoHandState.calibrationRequired,
      );
    });
  }
  test('expired or unknown timing calibration cannot create a candidate', () {
    for (final timing in [clock(version: 2), clock(until: 5000)]) {
      expect(
        observer(
          timing: timing,
        ).observe(frame(), targetMidi: 60, audio: onset()).state,
        PianoHandState.calibrationRequired,
      );
    }
  });
  test(
    'duplicate/reversed/gapped/negative hand clock latches calibration closed',
    () {
      for (final time in [10000, 9000, 200000, -1]) {
        final engine = observer();
        engine.observe(frame(), targetMidi: 60, audio: onset());
        expect(
          engine
              .observe(
                frame(time: time),
                targetMidi: 60,
                audio: onset(time: time + 500, id: 'e2'),
              )
              .state,
          PianoHandState.calibrationRequired,
        );
        expect(
          engine
              .observe(
                frame(time: 250000),
                targetMidi: 60,
                audio: onset(time: 250500, id: 'e3'),
              )
              .state,
          PianoHandState.calibrationRequired,
        );
      }
    },
  );
  test(
    'same onset cannot be consumed repeatedly; reverse audio requires recalibration',
    () {
      final engine = observer();
      expect(
        engine.observe(frame(), targetMidi: 60, audio: onset()).state,
        PianoHandState.contactCandidate,
      );
      expect(
        engine
            .observe(frame(time: 11000), targetMidi: 60, audio: onset())
            .reason,
        PianoHandReason.audioAlreadyUsed,
      );
      expect(
        engine
            .observe(
              frame(time: 12000),
              targetMidi: 60,
              audio: onset(time: 10400, id: 'e2'),
            )
            .state,
        PianoHandState.calibrationRequired,
      );
    },
  );
  test('provider model/version mismatch is not silently reused', () {
    final changed = HandProviderIdentity(
      id: hand.id,
      version: '2.0.0',
      artifactSha256: '5' * 64,
      mode: hand.mode,
      inputSchema: hand.inputSchema,
    );
    expect(
      observer()
          .observe(frame(provider: changed), targetMidi: 60, audio: onset())
          .state,
      PianoHandState.calibrationRequired,
    );
  });
  test('collections are immutable after calibration/frame construction', () {
    final points = List<HandPoint>.from(frame().points),
        f = frame(points: points);
    points.clear();
    expect(f.points, hasLength(21));
    expect(() => f.points.clear(), throwsUnsupportedError);
    expect(() => map().keys.clear(), throwsUnsupportedError);
    expect(() => map().keys.first.corners.clear(), throwsUnsupportedError);
  });
  test(
    'session stop clears cached onset and never restarts on resume',
    () async {
      final source = ReplayHandSource(), engine = observer();
      final session = PianoHandSession.connect(
        source: source,
        observer: engine,
        targetMidi: 60,
      );
      final observations = <PianoHandObservation>[];
      final sub = session.observations.listen(observations.add);
      await session.start();
      session.offerAudio(onset());
      source.data.add(frame());
      await pumpEventQueue();
      expect(observations.single.state, PianoHandState.contactCandidate);
      await session.stop();
      source.data.add(frame(time: 11000));
      await session.start();
      await pumpEventQueue();
      expect(observations, hasLength(1));
      expect(source.starts, 1);
      expect(
        engine
            .observe(frame(time: 12000), targetMidi: 60, audio: onset())
            .state,
        PianoHandState.calibrationRequired,
      );
      await sub.cancel();
      await session.dispose();
    },
  );
  test(
    'pending source start is drained before close resolves and cannot publish later',
    () async {
      final gate = Completer<void>(),
          source = ReplayHandSource(startGate: gate.future);
      final session = PianoHandSession.connect(
        source: source,
        observer: observer(),
        targetMidi: 60,
      );
      final observations = <PianoHandObservation>[];
      final sub = session.observations.listen(observations.add);
      final start = session.start();
      await pumpEventQueue();
      var closed = false;
      final stop = session.stop().then((_) => closed = true);
      await pumpEventQueue();
      expect(closed, isFalse);
      source.data.add(frame());
      gate.complete();
      await start;
      await stop;
      await pumpEventQueue();
      expect(observations, isEmpty);
      expect(source.stops, 2);
      await sub.cancel();
      await session.dispose();
    },
  );
  test(
    'stream error clears the session and rejects subsequent frames',
    () async {
      final source = ReplayHandSource();
      final session = PianoHandSession.connect(
        source: source,
        observer: observer(),
        targetMidi: 60,
      );
      final observations = <PianoHandObservation>[];
      final sub = session.observations.listen(observations.add);
      await session.start();
      session.offerAudio(onset());
      source.data.add(frame());
      await pumpEventQueue();
      expect(observations.single.state, PianoHandState.contactCandidate);
      source.data.addError(StateError('isolated stream fault'));
      await pumpEventQueue();
      expect(observations.last.state, PianoHandState.unsupported);
      source.data.add(frame(time: 11000));
      await pumpEventQueue();
      expect(observations, hasLength(2));
      await sub.cancel();
      await session.dispose();
    },
  );
  test(
    'production-mode observer blocks replay source before starting it',
    () async {
      final source = ReplayHandSource();
      final session = PianoHandSession.connect(
        source: source,
        observer: observer(mode: HandEvidenceMode.production),
        targetMidi: 60,
      );
      final observations = <PianoHandObservation>[];
      final sub = session.observations.listen(observations.add);
      await session.start();
      await pumpEventQueue();
      expect(source.starts, 0);
      expect(observations.single.state, PianoHandState.unsupported);
      await sub.cancel();
      await session.dispose();
    },
  );
  test(
    'production factory stays unsupported and never accepts a replay toggle',
    () async {
      final session = PianoHandSession.production(targetMidi: 60);
      final observations = <PianoHandObservation>[];
      final sub = session.observations.listen(observations.add);
      await session.start();
      await pumpEventQueue();
      expect(observations.single.state, PianoHandState.unsupported);
      await sub.cancel();
      await session.dispose();
    },
  );
  for (final language in ['en', 'tr']) {
    testWidgets('piano-05 support notice is honest at 320px 200% ($language)', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: const SingleChildScrollView(
                child: PianoHandSupportNotice(),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining(
          language == 'tr' ? 'temasını doğrulamaz' : 'does not verify',
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
}
