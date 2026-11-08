// OST-P0-05 — the first-three-minutes flow (behind a closed flag): three
// choices, tapping asks for NO microphone permission, voice path permission
// outcomes, honest summary, no network, flag-off behaviour unchanged.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/audio/mic_permission_gate.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/first_minutes/first_minutes_controller.dart';
import 'package:ostinato/app/first_minutes/first_minutes_copy.dart';
import 'package:ostinato/app/first_minutes/first_three_minutes_screen.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/reference_listen.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/ui_copy.dart';
import 'package:ostinato/main.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/fake_practice_audio_port.dart';
import 'support/localized_widget_ready.dart';

final class _Port implements ReferencePlaybackPort {
  _Port(this.lease);
  final PracticeAudioLease lease;
  final staged = <int>[];

  @override
  Future<String?> stage(Float32List samples, int sampleRate) async {
    staged.add(samples.length);
    return 'ref-${staged.length}';
  }

  @override
  Future<PracticeAudioTicket?> open(String assetId) async =>
      (await lease.acquire(
        PracticeAudioSide.output,
        context: lease.captureContext(),
        assetId: assetId,
      )).ticket;

  @override
  Future<void> release(PracticeAudioTicket ticket) => lease.release(ticket);
}

final class _EgressGuard extends HttpOverrides {
  int clients = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    throw StateError('EGRESS: HttpClient opened');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareRootTranslations);

  late _Port port;
  var clockUs = 0;
  var library = 0;
  var micStatusCalls = 0;
  var channelCalls = <String>[];
  var micRequestCalls = 0;
  var micStatus = PermissionStatus.denied;
  var micAfterRequest = PermissionStatus.denied;

  setUp(() {
    final b = TestWidgetsFlutterBinding.ensureInitialized();
    b.platformDispatcher.views.first.physicalSize = const Size(375, 812);
    b.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(b.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(b.platformDispatcher.views.first.resetDevicePixelRatio);
    port = _Port(PracticeAudioLease(port: FakePracticeAudioPort()));
    clockUs = 0;
    library = 0;
    micStatusCalls = 0;
    channelCalls = <String>[];
    // The real platform permission channel: any call to it is recorded.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async {
            channelCalls.add(call.method);
            return call.method == 'checkPermissionStatus' ? 0 : <int, int>{};
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            null,
          ),
    );
    micRequestCalls = 0;
    micStatus = PermissionStatus.denied;
    micAfterRequest = PermissionStatus.denied;
    MicPermissionGate.status = () async {
      micStatusCalls++;
      return micStatus;
    };
    MicPermissionGate.request = () async {
      micRequestCalls++;
      return micAfterRequest;
    };
    addTearDown(MicPermissionGate.resetForTest);
  });

  Widget host({
    String language = 'en',
    Brightness brightness = Brightness.light,
    ReferencePlaybackPort? Function(BuildContext)? ports,
    double textScale = 1,
  }) => MaterialApp(
    locale: Locale(language),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    theme: OstinatoThemes.forBrightness(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: FirstThreeMinutesScreen(
      onOpenLibrary: () => library++,
      portBuilder: ports ?? (_) => port,
      nowUs: () => clockUs,
    ),
  );

  String en(UiCopy c) => c.$1;

  Future<void> boot(WidgetTester t, Widget w, {String tag = 'en'}) async {
    await t.pumpWidget(w);
    await waitForLocalizedFixture(
      t,
      languageTag: tag,
      anchor: find.byKey(const Key('fm-choice-title')),
      reason: 'first minutes',
    );
  }

  /// Starts a round and taps beats [beatIdx] of the clip with [offsetsMs].
  Future<void> playRound(
    WidgetTester t,
    List<int> beatIdx,
    List<int> offsetsMs,
  ) async {
    clockUs = 0;
    await t.tap(find.byKey(const Key('fm-start-beat')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('fm-tap-pad')), findsOneWidget);
    for (var i = 0; i < beatIdx.length; i++) {
      clockUs = beatIdx[i] * 750000 + offsetsMs[i] * 1000;
      await t.tap(find.byKey(const Key('fm-tap-pad')));
      await t.pump();
    }
    await t.pump(const Duration(seconds: 9));
  }

  testWidgets('three choices are visible and nothing was asked yet', (t) async {
    await boot(t, host());
    expect(find.text(en(FirstMinutesCopy.tapTitle)), findsOneWidget);
    expect(find.text(en(FirstMinutesCopy.voiceTitle)), findsOneWidget);
    expect(find.text(en(FirstMinutesCopy.instrumentTitle)), findsOneWidget);
    expect(micStatusCalls + micRequestCalls, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('Tap the rhythm: whole flow asks for no microphone permission', (
    t,
  ) async {
    await boot(t, host());
    await t.tap(find.byKey(const Key('fm-choice-tap')));
    await t.pump();
    expect(find.text(en(FirstMinutesCopy.rhythmIntro)), findsOneWidget);
    await playRound(t, [4, 5, 6, 7], [10, -12, 8, 0]);
    expect(find.byKey(const Key('fm-variation-title')), findsOneWidget);
    expect(find.text(en(FirstMinutesCopy.summarySteady)), findsOneWidget);
    expect(port.staged, hasLength(1));
    await t.tap(find.byKey(const Key('fm-variation-go')));
    await t.pump();
    await playRound(t, [4, 5, 7], [-8, 15, 0]);
    expect(find.byKey(const Key('fm-summary-title')), findsOneWidget);
    expect(find.text(en(FirstMinutesCopy.summaryTitle)), findsOneWidget);
    expect(find.byKey(const Key('fm-summary-line')), findsOneWidget);
    expect(find.text(en(FirstMinutesCopy.compareSimilar)), findsOneWidget);
    // The microphone seam was never touched on this path.
    expect(micStatusCalls, 0);
    expect(micRequestCalls, 0);
    expect(channelCalls, isEmpty, reason: 'no platform permission call');
    // Take playback comes from memory through the same output path.
    await t.ensureVisible(find.byKey(const Key('fm-listen-0')));
    await t.tap(find.byKey(const Key('fm-listen-0')));
    await t.pump();
    await t.pump();
    expect(port.staged, hasLength(3));
    await t.pump(const Duration(seconds: 6));
    await t.ensureVisible(find.byKey(const Key('fm-summary-library')));
    await t.tap(find.byKey(const Key('fm-summary-library')));
    expect(library, 1);
    expect(micStatusCalls + micRequestCalls, 0);
    expect(channelCalls, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('too few taps: "could not measure", no verdict', (t) async {
    await boot(t, host());
    await t.tap(find.byKey(const Key('fm-choice-tap')));
    await t.pump();
    await playRound(t, [4], [0]);
    expect(find.text(en(FirstMinutesCopy.summaryNotMeasured)), findsOneWidget);
    await t.tap(find.byKey(const Key('fm-variation-go')));
    await t.pump();
    await playRound(t, [], []);
    expect(find.text(en(FirstMinutesCopy.summaryNotMeasured)), findsOneWidget);
    expect(find.text(en(FirstMinutesCopy.compareNone)), findsOneWidget);
    final text = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => (w.data ?? '').toLowerCase())
        .join(' ');
    expect(text, isNot(contains('wrong')));
    expect(text, isNot(contains('error')));
  });

  testWidgets('no output path: honest message, retry and library stay', (
    t,
  ) async {
    await boot(t, host(ports: (_) => null));
    await t.tap(find.byKey(const Key('fm-choice-tap')));
    await t.pump();
    await t.tap(find.byKey(const Key('fm-start-beat')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('fm-beat-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('fm-retry')), findsOneWidget);
    await t.tap(find.byKey(const Key('fm-unavailable-library')));
    expect(library, 1);
  });

  test(
    'disposing while the permission answer is pending does not throw',
    () async {
      final gate = Completer<PermissionStatus>();
      MicPermissionGate.status = () => gate.future;
      final c = FirstMinutesController();
      final done = c.requestVoice();
      c.dispose();
      gate.complete(PermissionStatus.granted);
      await done;
      expect(c.voiceBusy, isFalse);
    },
  );

  testWidgets('Use your voice: granted', (t) async {
    micAfterRequest = PermissionStatus.granted;
    await boot(t, host());
    await t.tap(find.byKey(const Key('fm-choice-voice')));
    await t.pump();
    expect(micRequestCalls, 0, reason: 'asked only on the explicit button');
    await t.tap(find.byKey(const Key('fm-voice-allow')));
    await t.pump();
    await t.pump();
    expect(micRequestCalls, 1);
    expect(find.text(en(FirstMinutesCopy.voiceGranted)), findsOneWidget);
    await t.tap(find.byKey(const Key('fm-voice-library')));
    expect(library, 1);
  });

  testWidgets('Use your voice: denied returns to tapping without blame', (
    t,
  ) async {
    micAfterRequest = PermissionStatus.denied;
    await boot(t, host());
    await t.tap(find.byKey(const Key('fm-choice-voice')));
    await t.pump();
    await t.tap(find.byKey(const Key('fm-voice-allow')));
    await t.pump();
    await t.pump();
    expect(micRequestCalls, 1);
    expect(find.text(en(FirstMinutesCopy.voiceDenied)), findsOneWidget);
    await t.tap(find.byKey(const Key('fm-voice-fallback')));
    await t.pump();
    expect(find.text(en(FirstMinutesCopy.rhythmIntro)), findsOneWidget);
    expect(find.byKey(const Key('fm-start-beat')), findsOneWidget);
  });

  testWidgets('Use your voice: permanently denied never prompts again', (
    t,
  ) async {
    micStatus = PermissionStatus.permanentlyDenied;
    await boot(t, host());
    await t.tap(find.byKey(const Key('fm-choice-voice')));
    await t.pump();
    await t.tap(find.byKey(const Key('fm-voice-allow')));
    await t.pump();
    await t.pump();
    expect(micRequestCalls, 0);
    expect(find.text(en(FirstMinutesCopy.voicePermanent)), findsOneWidget);
    await t.tap(find.byKey(const Key('fm-voice-fallback')));
    await t.pump();
    expect(find.byKey(const Key('fm-start-beat')), findsOneWidget);
  });

  testWidgets('I have an instrument and Skip go to the existing library', (
    t,
  ) async {
    await boot(t, host());
    await t.tap(find.byKey(const Key('fm-choice-instrument')));
    await t.ensureVisible(find.byKey(const Key('fm-skip')));
    await t.tap(find.byKey(const Key('fm-skip')));
    expect(library, 2);
    expect(micStatusCalls + micRequestCalls, 0);
  });

  testWidgets('no network client is opened by the whole flow', (t) async {
    final guard = _EgressGuard();
    final prev = HttpOverrides.current;
    HttpOverrides.global = guard;
    addTearDown(() => HttpOverrides.global = prev);
    await boot(t, host());
    await t.tap(find.byKey(const Key('fm-choice-tap')));
    await t.pump();
    await playRound(t, [4, 5, 6, 7], [0, 0, 0, 0]);
    await t.tap(find.byKey(const Key('fm-variation-go')));
    await t.pump();
    await playRound(t, [4, 5, 7], [0, 0, 0]);
    await t.ensureVisible(find.byKey(const Key('fm-listen-1')));
    await t.tap(find.byKey(const Key('fm-listen-1')));
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    expect(guard.clients, 0);
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'narrow ${width.toInt()} / ${brightness.name} / 1.6x text: steps build '
        'without overflow and keep their labels',
        (t) async {
          t.view.physicalSize = Size(width, 640);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final handle = t.ensureSemantics();
          await boot(t, host(brightness: brightness, textScale: 1.6));
          expect(t.takeException(), isNull);
          expect(find.bySemanticsLabel(RegExp('Tap the rhythm')), findsWidgets);
          await t.tap(find.byKey(const Key('fm-choice-tap')));
          await t.pump();
          // The step scrolls: the button may start below the fold.
          await t.ensureVisible(find.byKey(const Key('fm-start-beat')));
          await t.tap(find.byKey(const Key('fm-start-beat')));
          await t.pump();
          await t.pump();
          expect(
            find.bySemanticsLabel(en(FirstMinutesCopy.tapPadLabel)),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(en(FirstMinutesCopy.gridLabel)),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await t.pump(const Duration(seconds: 9));
          expect(t.takeException(), isNull);
          handle.dispose();
        },
      );
    }
  }

  testWidgets('Turkish shows the Turkish pairs', (t) async {
    await boot(t, host(language: 'tr'), tag: 'tr');
    expect(find.text(FirstMinutesCopy.tapTitle.$2), findsOneWidget);
    expect(find.text(FirstMinutesCopy.voiceTitle.$2), findsOneWidget);
  });

  group('flag', () {
    late ContentRepository repo;
    late CueTextResolver cueText;
    setUpAll(() async {
      repo = await ContentRepository.load();
      cueText = await CueTextResolver.load();
    });

    Widget home({bool? flag, bool onboarded = false}) => ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: flag == null
            ? OstinatoHome(
                repo: repo,
                cueText: cueText,
                store: InMemoryOnboardingStore(),
                alreadyOnboarded: onboarded,
              )
            : OstinatoHome(
                repo: repo,
                cueText: cueText,
                store: InMemoryOnboardingStore(),
                alreadyOnboarded: onboarded,
                firstThreeMinutesOpen: flag,
                firstMinutesPortBuilder: (_) => port,
              ),
      ),
    );

    Future<void> walkWelcome(WidgetTester t) async {
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(const Key('onboarding-primary')));
        await t.pump();
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the flag ships closed', (t) async {
      expect(ostinatoFirstThreeMinutesOpen, isFalse);
    });

    testWidgets('flag closed (default): welcome pages, then the library', (
      t,
    ) async {
      await t.pumpWidget(home());
      await walkWelcome(t);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(FirstThreeMinutesScreen), findsNothing);
    });

    testWidgets('flag explicitly closed: same as the default', (t) async {
      await t.pumpWidget(home(flag: false));
      await walkWelcome(t);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(FirstThreeMinutesScreen), findsNothing);
    });

    testWidgets('flag open: the choices come between welcome and library', (
      t,
    ) async {
      await t.pumpWidget(home(flag: true));
      await walkWelcome(t);
      expect(find.byType(FirstThreeMinutesScreen), findsOneWidget);
      expect(find.byType(LibraryScreen), findsNothing);
      await t.ensureVisible(find.byKey(const Key('fm-skip')));
      await t.tap(find.byKey(const Key('fm-skip')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('flag open does not touch a returning user', (t) async {
      await t.pumpWidget(home(flag: true, onboarded: true));
      await t.pump();
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(FirstThreeMinutesScreen), findsNothing);
    });
  });
}
