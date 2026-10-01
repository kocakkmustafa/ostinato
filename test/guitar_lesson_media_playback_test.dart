import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/course/media/lesson_media_playback.dart';
import 'package:ostinato/app/course/media/lesson_media_slot.dart';

final class _CaptionBundle extends CachingAssetBundle {
  _CaptionBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('Missing QA caption');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

final class _FakeSilentVideo implements SilentLessonVideoHandle {
  _FakeSilentVideo(
    this.path,
    this.captions,
    this.events, {
    this.soundDisabled = true,
    this.playGate,
    this.closeFails = false,
  });

  final String path, captions;
  final List<String> events;
  final bool soundDisabled, closeFails;
  final Completer<void>? playGate;
  bool closed = false;

  @override
  final ValueNotifier<SilentLessonVideoFrame> frame = ValueNotifier(
    const SilentLessonVideoFrame(),
  );

  @override
  Future<void> initializeMuted() async {
    events.add('initializeMuted');
    frame.value = SilentLessonVideoFrame(
      initialized: true,
      audioOutputDisabled: soundDisabled,
    );
  }

  @override
  Future<void> play() async {
    events.add('play');
    await playGate?.future;
    if (closed) return;
    frame.value = SilentLessonVideoFrame(
      initialized: true,
      playing: true,
      audioOutputDisabled: soundDisabled,
      caption: captions.contains('locale=tr')
          ? 'Gitarı göster.'
          : 'Show the guitar.',
    );
  }

  @override
  Future<void> pause() async {
    events.add('pause');
    if (closed) return;
    frame.value = SilentLessonVideoFrame(
      initialized: true,
      audioOutputDisabled: soundDisabled,
    );
  }

  @override
  Future<void> close() async {
    events.add('close');
    if (closeFails) throw StateError('close not confirmed');
    closed = true;
    frame.dispose();
  }

  @override
  Widget buildVideo() => const ColoredBox(
    key: Key('ostinato.fakeSilentVideo'),
    color: Colors.black,
  );
}

const _tr = 'assets/content/media/ostinato/first.tr.vtt';
const _en = 'assets/content/media/ostinato/first.en.vtt';
const _fixture = LessonMediaPlaybackFixture(
  lessonId: 'guitar.journey.start.parts',
  videoAssetPath: 'assets/content/media/ostinato/first.mp4',
  captionAssetPaths: {'tr': _tr, 'en': _en},
);

_CaptionBundle _bundle() => _CaptionBundle({
  _tr:
      'WEBVTT - Motion locale=tr\n\n00:00:00.000 --> 00:00:00.800\nGitarı göster.\n',
  _en:
      'WEBVTT - Motion locale=en\n\n00:00:00.000 --> 00:00:00.800\nShow the guitar.\n',
});

Widget _host({
  required String? accountId,
  required DebugSilentVideoGate gate,
  required SilentLessonVideoFactory factory,
  String locale = 'tr',
  GlobalKey<NavigatorState>? navigatorKey,
  _CaptionBundle? bundle,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  home: AccountScope(
    connection: null,
    currentUserId: accountId,
    child: Scaffold(
      body: LessonMediaSlot.testingPlayback(
        lessonId: _fixture.lessonId,
        locale: locale,
        bundle: bundle ?? _bundle(),
        fixture: _fixture,
        videoFactory: factory,
        gate: gate,
      ),
    ),
  ),
);

void main() {
  test('QA gate grants only one waiting handle in FIFO order', () async {
    final gate = DebugSilentVideoGate();
    final first = await gate.take();
    expect(first, isNotNull);
    final order = <String>[];
    final secondFuture = gate.take().then((token) {
      order.add('second');
      return token;
    });
    final thirdFuture = gate.take().then((token) {
      order.add('third');
      return token;
    });
    await Future<void>.delayed(Duration.zero);
    expect(order, isEmpty);

    gate.release(first!, confirmed: true);
    final second = await secondFuture;
    expect(second, isNotNull);
    expect(order, ['second']);
    await Future<void>.delayed(Duration.zero);
    expect(order, ['second'], reason: 'third must wait for second close');

    gate.release(second!, confirmed: true);
    final third = await thirdFuture;
    expect(third, isNotNull);
    expect(order, ['second', 'third']);
    gate.release(third!, confirmed: true);
  });

  test('uncertain owner close denies every queued QA handle', () async {
    final gate = DebugSilentVideoGate();
    final owner = await gate.take();
    final second = gate.take();
    final third = gate.take();
    gate.release(owner!, confirmed: false);
    expect(await second, isNull);
    expect(await third, isNull);
    expect(await gate.take(), isNull);
    expect(gate.blocked, isTrue);
  });

  testWidgets('shipping slot remains invisible with an empty catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonMediaSlot.empty(lessonId: _fixture.lessonId, locale: 'tr'),
      ),
    );
    expect(find.byKey(const Key('ostinato.debugMediaToggle')), findsNothing);
    expect(find.byType(DebugSilentLessonPlayback), findsNothing);
    expect(
      tester
          .widget<LessonMediaSlot>(find.byType(LessonMediaSlot))
          .catalog
          .isEmpty,
      isTrue,
    );
  });

  testWidgets(
    'QA fixture starts silent only after user tap and shows caption',
    (tester) async {
      final events = <String>[];
      final videos = <_FakeSilentVideo>[];
      await tester.pumpWidget(
        _host(
          accountId: 'user-a',
          gate: DebugSilentVideoGate(),
          factory: (path, captions) {
            final video = _FakeSilentVideo(path, captions, events);
            videos.add(video);
            return video;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(videos, hasLength(1));
      expect(videos.single.path, _fixture.videoAssetPath);
      expect(videos.single.captions, contains('locale=tr'));
      expect(events, ['initializeMuted']);
      expect(
        find.text('Bu test gösterimi ders ilerlemesini değiştirmez.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ostinato.debugMediaToggle')));
      await tester.pump();
      expect(events, ['initializeMuted', 'play']);
      expect(find.text('Gitarı göster.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ostinato.debugMediaToggle')));
      await tester.pump();
      expect(events, ['initializeMuted', 'play', 'pause']);
    },
  );

  testWidgets('covering the route waits for play, then pauses and closes', (
    tester,
  ) async {
    final events = <String>[];
    final playGate = Completer<void>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _host(
        accountId: 'user-a',
        navigatorKey: navigator,
        gate: DebugSilentVideoGate(),
        factory: (path, captions) =>
            _FakeSilentVideo(path, captions, events, playGate: playGate),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ostinato.debugMediaToggle')));
    await tester.pump();
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('next'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
    expect(events, ['initializeMuted', 'play']);
    playGate.complete();
    await tester.pumpAndSettle();
    expect(events, ['initializeMuted', 'play', 'pause', 'close']);
  });

  testWidgets('account change revokes fixture and it stays closed', (
    tester,
  ) async {
    final events = <String>[];
    final gate = DebugSilentVideoGate();
    final bundle = _bundle();
    _FakeSilentVideo factory(String path, String captions) =>
        _FakeSilentVideo(path, captions, events);
    await tester.pumpWidget(
      _host(accountId: 'user-a', gate: gate, factory: factory, bundle: bundle),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _host(accountId: 'user-b', gate: gate, factory: factory, bundle: bundle),
    );
    await tester.pumpAndSettle();
    expect(events, ['initializeMuted', 'pause', 'close']);
    expect(find.byKey(const Key('ostinato.debugMediaToggle')), findsNothing);
  });

  testWidgets('background revokes fixture without reopening on resume', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _host(
        accountId: 'user-a',
        gate: DebugSilentVideoGate(),
        factory: (path, captions) => _FakeSilentVideo(path, captions, events),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(events, ['initializeMuted', 'pause', 'close']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ostinato.debugMediaToggle')), findsNothing);
  });

  testWidgets('a handle without disabled output never offers play', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _host(
        accountId: 'user-a',
        gate: DebugSilentVideoGate(),
        factory: (path, captions) =>
            _FakeSilentVideo(path, captions, events, soundDisabled: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(events, ['initializeMuted', 'pause', 'close']);
    expect(find.byKey(const Key('ostinato.debugMediaFailure')), findsOneWidget);
    expect(find.byKey(const Key('ostinato.debugMediaToggle')), findsNothing);
  });

  testWidgets('unconfirmed close poisons the shared QA gate', (tester) async {
    final gate = DebugSilentVideoGate();
    final events = <String>[];
    var created = 0;
    await tester.pumpWidget(
      _host(
        accountId: 'user-a',
        gate: gate,
        factory: (path, captions) {
          created++;
          return _FakeSilentVideo(path, captions, events, closeFails: true);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(gate.blocked, isTrue);
    await tester.pumpWidget(
      _host(
        accountId: 'user-b',
        gate: gate,
        factory: (path, captions) {
          created++;
          return _FakeSilentVideo(path, captions, events);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(created, 1);
    expect(find.byKey(const Key('ostinato.debugMediaFailure')), findsOneWidget);
  });
}
