// FK2 — "listen to my own recording" (founder, 2026-11-01): off by default,
// kept only on the device, deleted at the end of the session, never uploaded
// and never used for analysis. These tests prove each of those clauses.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/own_recording/own_recording.dart';
import 'package:ostinato/app/practice/own_recording/own_recording_preference.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import 'practice_session_test.dart' show Rig, performance;
import 'support/localized_widget_ready.dart';

AudioChunk chunkOf(int n, {double value = .5, int rate = 48000}) => AudioChunk(
  samples: List<double>.filled(n, value),
  sampleRate: rate,
  tStartUs: 0,
  clockDomain: AudioClockDomain.monotonic,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late Directory takes;
  OwnRecorder recorder({int maxSeconds = 180}) =>
      OwnRecorder(temporaryRoot: () async => tmp, maxSeconds: maxSeconds);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('own_recording_test');
    takes = Directory('${tmp.path}/own_recording');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  List<String> filesOnDisk() => takes.existsSync()
      ? takes.listSync().map((e) => e.path).toList()
      : const [];

  test('WAV: 16-bit mono PCM header around the samples', () {
    final pcm = Uint8List.fromList([1, 0, 2, 0, 3, 0]);
    final wav = encodeWav(pcm, 48000);
    final b = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(b.getUint32(4, Endian.little), 36 + 6);
    expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
    expect(b.getUint16(20, Endian.little), 1, reason: 'PCM');
    expect(b.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(b.getUint32(24, Endian.little), 48000);
    expect(b.getUint16(34, Endian.little), 16);
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(b.getUint32(40, Endian.little), 6);
    expect(wav.sublist(44), pcm);
  });

  group('off by default', () {
    test('a new recorder keeps nothing and writes nothing', () async {
      final r = recorder();
      expect(r.enabled, isFalse);
      r.add(chunkOf(4800));
      expect(r.hasPendingAudio, isFalse);
      expect(await r.seal(), isNull);
      expect(filesOnDisk(), isEmpty);
      r.dispose();
    });

    test('the setting reads off when missing or damaged', () async {
      final pref = FileOwnRecordingPreference(directory: tmp);
      expect(await pref.read(), isFalse);
      File(
        '${tmp.path}/ostinato.own_recording.v1.json',
      ).writeAsStringSync('{not json');
      expect(await pref.read(), isFalse);
      File(
        '${tmp.path}/ostinato.own_recording.v1.json',
      ).writeAsStringSync('{"schemaVersion":2,"enabled":true}');
      expect(await pref.read(), isFalse, reason: 'unknown schema stays off');
      await pref.write(true);
      expect(await pref.read(), isTrue);
      await pref.write(false);
      expect(await pref.read(), isFalse);
    });
  });

  group('kept on this device, deleted at the end of the session', () {
    test(
      'seal writes one WAV in the temporary folder; discard deletes it',
      () async {
        final r = recorder()..enabled = true;
        r.add(chunkOf(4800));
        r.add(chunkOf(4800, value: -.5));
        final take = await r.seal();
        expect(take, isNotNull);
        expect(take!.path, startsWith(takes.path));
        expect(take.lengthSync(), 44 + 9600 * 2);
        expect(r.take, take);
        await r.discard();
        expect(take.existsSync(), isFalse);
        expect(r.take, isNull);
        expect(filesOnDisk(), isEmpty);
        r.dispose();
      },
    );

    test('the next run (reset) deletes the previous take', () async {
      final r = recorder()..enabled = true;
      r.add(chunkOf(480));
      final first = (await r.seal())!;
      await r.reset();
      expect(first.existsSync(), isFalse);
      r.add(chunkOf(480));
      final second = (await r.seal())!;
      expect(filesOnDisk(), [second.path]);
      r.dispose();
      await pumpEventQueue();
      expect(second.existsSync(), isFalse, reason: 'dispose deletes too');
    });

    test('a reset while the take is being written leaves no file', () async {
      final r = recorder()..enabled = true;
      r.add(chunkOf(4800));
      final sealing = r.seal();
      await r.discard();
      expect(await sealing, isNull);
      expect(filesOnDisk(), isEmpty);
      r.dispose();
    });

    test('sweep removes takes a crash left behind', () async {
      takes.createSync(recursive: true);
      File('${takes.path}/take-7.wav').writeAsBytesSync([0]);
      await recorder().sweep();
      expect(takes.existsSync(), isFalse);
    });

    test(
      'RAM is bounded: a long run keeps only its first maxSeconds',
      () async {
        final r = recorder(maxSeconds: 1)..enabled = true;
        for (var i = 0; i < 15; i++) {
          r.add(chunkOf(4800));
        }
        final take = (await r.seal())!;
        expect(take.lengthSync(), 44 + 48000 * 2);
        r.dispose();
      },
    );
  });

  group('wired into the practice run', () {
    setUp(resetAudioCaptureCoordinatorForTest);

    Future<(Rig, OwnRecorder)> run({required bool enabled}) async {
      final r = recorder()..enabled = enabled;
      final rig = Rig('E2 F2 G2 F2', ownRecorder: r);
      await rig.play(
        performance(11, {5000000: 40, 6000000: 41, 7000000: 43, 8000000: 41}),
      );
      // seal() writes with real file IO after the run finishes.
      for (var i = 0; i < 100 && enabled && r.take == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await pumpEventQueue();
      return (rig, r);
    }

    test('setting off: a finished run leaves no file', () async {
      final (rig, r) = await run(enabled: false);
      expect(rig.controller.summary, isNotNull);
      expect(r.take, isNull);
      expect(filesOnDisk(), isEmpty);
      await rig.close();
    });

    test(
      'setting on: the finished run has a take; leaving deletes it',
      () async {
        final (rig, r) = await run(enabled: true);
        expect(rig.controller.summary, isNotNull);
        final take = r.take;
        expect(take, isNotNull);
        expect(take!.existsSync(), isTrue);
        await rig.close(); // the lesson screen closes
        await pumpEventQueue();
        expect(take.existsSync(), isFalse);
        expect(filesOnDisk(), isEmpty);
      },
    );
  });

  group('settings switch', () {
    Widget host(OwnRecordingPreference p) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(body: OwnRecordingSettingCard(preference: p)),
    );
    Switch sw(WidgetTester t) => t.widget<Switch>(
      find.byKey(const Key('settings-own-recording-switch')),
    );

    testWidgets('starts off, turning it on is saved', (tester) async {
      final p = _MemoryPreference();
      await tester.pumpWidget(host(p));
      await waitForLocalizedFixture(
        tester,
        languageTag: 'en',
        anchor: find.byKey(const Key('settings-own-recording')),
        reason: 'FK2 setting card',
      );
      await tester.pump();
      expect(sw(tester).value, isFalse);
      expect(p.stored, isNull, reason: 'opening the screen writes nothing');
      await tester.tap(find.byKey(const Key('settings-own-recording-switch')));
      await tester.pumpAndSettle();
      expect(sw(tester).value, isTrue);
      expect(p.stored, isTrue);
    });

    testWidgets('a failed save flips back to off and says so', (tester) async {
      final p = _MemoryPreference()..failWrite = true;
      await tester.pumpWidget(host(p));
      await waitForLocalizedFixture(
        tester,
        languageTag: 'en',
        anchor: find.byKey(const Key('settings-own-recording')),
        reason: 'FK2 setting card',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings-own-recording-switch')));
      await tester.pumpAndSettle();
      expect(sw(tester).value, isFalse);
      expect(
        find.text('The setting could not be saved. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('never uploaded, never analysed', () {
    final ownFiles = Directory(
      'lib/app/practice/own_recording',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));

    test('the FK2 files use no network or account API', () {
      final network = RegExp(
        r'HttpClient|package:http|dart:html|Socket|WebSocket|supabase|'
        r'motion_core|motion_account|sendMessage|upload\(',
        caseSensitive: false,
      );
      for (final f in ownFiles) {
        final code = f
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(network.hasMatch(code), isFalse, reason: f.path);
      }
    });

    test('takes are written only under the temporary directory', () {
      final source = File(
        'lib/app/practice/own_recording/own_recording.dart',
      ).readAsStringSync();
      expect(source, contains('getTemporaryDirectory'));
      expect(source, isNot(contains('getApplicationSupportDirectory')));
      expect(source, isNot(contains('getApplicationDocumentsDirectory')));
    });

    test('analysis and capture code never reads the recorder', () {
      final readers = [
        'lib/app/practice/loop/practice_judge.dart',
        'lib/app/audio/audio_input_controller.dart',
        'lib/app/audio/audio_capture_channel.dart',
        'lib/app/audio/audio_route_state.dart',
        'lib/app/audio/guitar_note_observation_controller.dart',
        'packages/ostinato_audio/lib/src/pitch/guitar_pitch_observer.dart',
        'packages/ostinato_audio/lib/src/capture/audio_source.dart',
        'packages/ostinato_audio/lib/src/capture/ring_buffer.dart',
      ];
      for (final path in readers) {
        final code = File(path).readAsStringSync();
        expect(code, isNot(contains('own_recording')), reason: path);
        expect(code, isNot(contains('OwnRecorder')), reason: path);
      }
      // The controller only feeds it chunks and lifecycle calls.
      final controller = File(
        'lib/app/practice/loop/practice_session_controller.dart',
      ).readAsStringSync();
      final uses = RegExp(
        r'ownRecorder\??\.(\w+)',
      ).allMatches(controller).map((m) => m[1]).toSet();
      expect(uses, {'reset', 'add', 'seal', 'discard'});
    });
  });
}

final class _MemoryPreference implements OwnRecordingPreference {
  bool? stored;
  bool failWrite = false;
  @override
  Future<bool> read() async => stored ?? false;
  @override
  Future<void> write(bool enabled) async {
    if (failWrite) throw const FileSystemException('disk full');
    stored = enabled;
  }
}
