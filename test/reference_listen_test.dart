// FK1 — "Önce dinle" denetleyicisi: hazırla → sahnele → çıkış izni → çal,
// kendiliğinden bırak; durdurma ve yarış durumları.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/reference_copy.dart';
import 'package:ostinato/app/practice/loop/reference_listen.dart';
import 'package:ostinato/app/practice/loop/reference_listen_bar.dart';
import 'package:ostinato/app/practice/loop/reference_passage.dart';

import 'support/fake_practice_audio_port.dart';

final class _Port implements ReferencePlaybackPort {
  _Port(this.lease);
  final PracticeAudioLease lease;
  final staged = <int>[];
  final released = <PracticeAudioTicket>[];
  bool refuse = false;
  Completer<void>? stageGate;

  @override
  Future<String?> stage(Float32List samples, int sampleRate) async {
    await stageGate?.future;
    staged.add(samples.length);
    return 'ref-${staged.length}';
  }

  @override
  Future<PracticeAudioTicket?> open(String assetId) async {
    if (refuse) return null;
    final r = await lease.acquire(
      PracticeAudioSide.output,
      context: lease.captureContext(),
      assetId: assetId,
    );
    return r.ticket;
  }

  @override
  Future<void> release(PracticeAudioTicket ticket) async {
    released.add(ticket);
    await lease.release(ticket);
  }
}

void main() {
  final score = PracticeScore.parse('E2 G2 A2 C3');
  Future<ReferencePassage> render(PracticeScore s, int bpm) async =>
      renderReferencePassage(s, bpm: bpm, sampleRate: 44100);

  testWidgets(
    'plays through an output lease and releases itself after the line',
    (tester) async {
      {
        final lease = PracticeAudioLease(port: FakePracticeAudioPort());
        final port = _Port(lease);
        final c = ReferenceListenController(render: render);
        final states = <ReferenceListenState>[];
        c.addListener(() => states.add(c.state));
        unawaited(c.play(port, score, 120));
        await tester.pump();
        expect(c.state, ReferenceListenState.playing);
        expect(lease.phase, PracticeAudioLeasePhase.outputActive);
        expect(port.staged, hasLength(1));
        // 4 count-in + 4 line beats at 0.5 s, 1.2 s tail, 0.3 s margin = 5.5 s.
        await tester.pump(const Duration(milliseconds: 5600));
        await tester.pump();
        expect(c.state, ReferenceListenState.idle);
        expect(port.released, hasLength(1));
        expect(states, [
          ReferenceListenState.preparing,
          ReferenceListenState.playing,
          ReferenceListenState.idle,
        ]);
        c.dispose();
      }
    },
  );

  test('stop releases at once; a refused grant says unavailable', () async {
    final lease = PracticeAudioLease(port: FakePracticeAudioPort());
    final port = _Port(lease);
    final c = ReferenceListenController(render: render);
    await c.play(port, score, 80);
    expect(c.state, ReferenceListenState.playing);
    await c.stop();
    expect(c.state, ReferenceListenState.idle);
    expect(port.released, hasLength(1));
    port.refuse = true;
    await c.play(port, score, 80);
    expect(c.state, ReferenceListenState.unavailable);
    await c.play(null, score, 80);
    expect(c.state, ReferenceListenState.unavailable);
    c.dispose();
  });

  test('a stop while preparing never opens the speaker', () async {
    final lease = PracticeAudioLease(port: FakePracticeAudioPort());
    final port = _Port(lease)..stageGate = Completer<void>();
    final c = ReferenceListenController(render: render);
    final playing = c.play(port, score, 80);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, ReferenceListenState.preparing);
    await c.stop();
    port.stageGate!.complete();
    await playing;
    expect(c.state, ReferenceListenState.idle);
    expect(lease.phase, PracticeAudioLeasePhase.idle);
    c.dispose();
  });

  testWidgets('bar offers each tempo once and switches to Stop', (
    tester,
  ) async {
    final lease = PracticeAudioLease(port: FakePracticeAudioPort());
    final port = _Port(lease);
    final c = ReferenceListenController(render: render);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferenceListenBar(
            controller: c,
            score: score,
            tempos: const [60, 40, 60],
            port: (_) => port,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('reference-listen-60')), findsOneWidget);
    expect(find.byKey(const Key('reference-listen-40')), findsOneWidget);
    expect(find.text(ReferenceCopy.synthesized.$1), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('reference-listen-40')));
      for (var i = 0; i < 20 && c.state != ReferenceListenState.playing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.byKey(const Key('reference-stop')), findsOneWidget);
    expect(
      find.text('Playing at ♩=40: one count-in bar, then the line.'),
      findsOneWidget,
    );
    await tester.runAsync(c.stop);
    await tester.pump();
    expect(find.byKey(const Key('reference-listen-60')), findsOneWidget);
    c.dispose();
  });
}
