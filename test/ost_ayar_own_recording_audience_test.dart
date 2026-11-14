import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/practice/own_recording/own_recording.dart';
import 'package:ostinato/app/practice/own_recording/own_recording_preference.dart';
import 'package:ostinato/app/practice/own_recording/recording_retention_policy.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import 'support/localized_widget_ready.dart';

final class _Pref implements OwnRecordingPreference {
  @override
  Future<bool> read() async => false;
  @override
  Future<void> write(bool enabled) async {}
}

AudioChunk _chunk(int n) => AudioChunk(
  samples: List<double>.filled(n, .5),
  sampleRate: 48000,
  tStartUs: 0,
  clockDomain: AudioClockDomain.monotonic,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(
    WidgetTester tester, {
    bool? retentionOpen,
    RetentionAudience? audience,
  }) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = (await tester.runAsync(ContentRepository.load))!;
    final cue = (await tester.runAsync(CueTextResolver.load))!;
    await tester.pumpWidget(
      ContentRepositoryScope(
        repo: repo,
        cueText: cue,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: retentionOpen == null
              ? SettingsScreen(ownRecordingPreference: _Pref())
              : SettingsScreen(
                  ownRecordingPreference: _Pref(),
                  retentionOpen: retentionOpen,
                  audience: audience ?? RetentionAudience.unknown,
                ),
        ),
      ),
    );
    await waitForLocalizedFixture(
      tester,
      languageTag: 'en',
      anchor: find.byType(SettingsScreen),
      reason: 'settings screen',
    );
    await tester.pump();
  }

  const key = Key('settings-own-recording-switch');

  group('settings: own-recording switch vs audience', () {
    for (final a in RetentionAudience.values) {
      testWidgets('flag closed + ${a.name}: card shown (FK2 unchanged)', (
        tester,
      ) async {
        await pumpSettings(tester, retentionOpen: false, audience: a);
        expect(find.byKey(key), findsOneWidget);
      });
    }

    testWidgets('defaults: card shown (today behaviour)', (tester) async {
      await pumpSettings(tester);
      expect(find.byKey(key), findsOneWidget);
    });

    for (final a in [RetentionAudience.child, RetentionAudience.unknown]) {
      testWidgets('flag open + ${a.name}: card and switch hidden', (
        tester,
      ) async {
        await pumpSettings(tester, retentionOpen: true, audience: a);
        expect(find.byKey(key), findsNothing);
        expect(find.byKey(const Key('settings-own-recording')), findsNothing);
      });
    }

    testWidgets('flag open + adult: card shown', (tester) async {
      await pumpSettings(
        tester,
        retentionOpen: true,
        audience: RetentionAudience.adult,
      );
      expect(find.byKey(key), findsOneWidget);
    });
  });

  group('RecorderBackgroundGuard.detach', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('ost_ayar'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('after detach, a lifecycle event never calls discard', () async {
      final r = OwnRecorder(temporaryRoot: () async => tmp)..enabled = true;
      final guard = RecorderBackgroundGuard(r)..attach();
      r.add(_chunk(4800));
      final take = (await r.seal())!;
      guard.detach();
      for (final s in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(s);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(take.existsSync(), isTrue, reason: s.name);
        expect(r.take, isNotNull, reason: s.name);
      }
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await r.discard();
    });

    test('control: while attached, paused does discard', () async {
      final r = OwnRecorder(temporaryRoot: () async => tmp)..enabled = true;
      final guard = RecorderBackgroundGuard(r)..attach();
      addTearDown(guard.detach);
      r.add(_chunk(4800));
      final take = (await r.seal())!;
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(take.existsSync(), isFalse);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    });
  });
}
