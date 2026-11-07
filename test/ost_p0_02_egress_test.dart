// OST-P0-02 — "ses cihazdan çıkmaz" egress kanıtı (üç katman).
//
//  1. ÇALIŞMA ZAMANI KAPISI: `HttpOverrides` + `IOOverrides` ile her
//     `HttpClient` oluşturma ve `Socket.connect` kaydedilir ve düşürülür; sahte
//     mikrofonla yakalama -> analiz -> (opt-in) kendi kaydı akışı koşar,
//     0 HTTP istemcisi ve 0 soket beklenir. Kayıt dosyası yalnız geçici
//     dizinde yaşar ve akış sonunda silinir.
//  2. KAYNAK KAPISI (statik): ses ve pratik kodunda ağ/hesap içe aktarımı yok.
//  3. MANIFEST: Android `INTERNET` izni mevcut durumda sabitlenir.
//
// Kendi-kaydım davranışının ayrıntıları `own_recording_test.dart`ta; burada
// yalnız ağ-yokluğu penceresi altında tekrar koşturulur (kopya değil).
//
// SINIRLAR: çalışma zamanı kapısı yalnız `HttpClient` ve
// `Socket.connect/startConnect` çağrılarını yakalar; `RawSocket`,
// `RawDatagramSocket`, `InternetAddress.lookup`, `HttpServer`, `Process`
// yakalanmaz. `Isolate.run` ile açılan izolatlarda override YOKTUR. Statik
// kapı yalnız doğrudan (package:/dart:) içe aktarmaları görür; göreli
// içe aktarmaları izlemez.
//
// TEST_ONLY: cihaz-üstü ağ yakalama (proxy/pcap) yapılmadı. Bu dosya Dart
// işlem içi `dart:io` çağrılarını ve kaynak metnini denetler; native
// (Swift/Kotlin) katmanı ve üçüncü taraf eklentilerin kendi trafiği KAPSAM
// DIŞIDIR. "Kanıtlandı" değil, "test ile korunuyor" iddiasıdır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/debug/debug_fake_mic_channel.dart';
import 'package:ostinato/app/practice/own_recording/own_recording.dart';
import 'package:ostinato/app/practice/setup/audio_environment.dart';
import 'package:ostinato/app/practice/setup/latency_calibration.dart';
import 'package:ostinato/app/practice/setup/setup_audio_controller.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:permission_handler/permission_handler.dart';

import 'practice_session_test.dart' show Rig, performance;

/// Records and fails every attempt to open a network client or socket.
final class _EgressGuard extends HttpOverrides {
  final List<String> httpClients = <String>[];
  final List<String> sockets = <String>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    httpClients.add(
      StackTrace.current.toString().split('\n').take(6).join('\n'),
    );
    throw StateError('EGRESS: HttpClient opened under the guard');
  }

  int get total => httpClients.length + sockets.length;
}

final class _SocketGuard extends IOOverrides {
  _SocketGuard(this.log);
  final List<String> log;

  @override
  Future<Socket> socketConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) async {
    log.add('connect $host:$port');
    throw StateError('EGRESS: Socket.connect under the guard');
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
  }) async {
    log.add('startConnect $host:$port');
    throw StateError('EGRESS: Socket.startConnect under the guard');
  }
}

/// Runs [body] with the guard installed; always restores the globals.
Future<_EgressGuard> _guarded(Future<void> Function() body) async {
  final guard = _EgressGuard();
  final prevHttp = HttpOverrides.current;
  final prevIo = IOOverrides.current;
  HttpOverrides.global = guard;
  IOOverrides.global = _SocketGuard(guard.sockets);
  try {
    await body();
  } finally {
    HttpOverrides.global = prevHttp;
    IOOverrides.global = prevIo;
  }
  return guard;
}

String _stripComments(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('1. çalışma zamanı kapısı', () {
    test(
      'positive control: the guard records and breaks HttpClient and Socket',
      () async {
        final guard = await _guarded(() async {
          expect(() => HttpClient(), throwsStateError);
          await expectLater(
            Socket.connect(InternetAddress.loopbackIPv4, 9),
            throwsStateError,
          );
          await expectLater(
            Socket.startConnect(InternetAddress.loopbackIPv4, 9),
            throwsStateError,
          );
        });
        expect(guard.httpClients, hasLength(1));
        expect(guard.sockets, hasLength(2));
        // Restored: the guard does not leak into other tests.
        expect(HttpOverrides.current, isNot(same(guard)));
      },
    );

    test(
      'capture -> analysis -> own recording (opt-in) opens 0 clients and 0 sockets; '
      'the take stays in the temp dir and is deleted at the end',
      () async {
        final tmp = Directory.systemTemp.createTempSync('ost_p0_02_egress');
        addTearDown(() {
          if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        });
        File? take;
        Rig? rigOut;
        final guard = await _guarded(() async {
          final recorder = OwnRecorder(temporaryRoot: () async => tmp)
            ..enabled = true;
          final rig = Rig('E2 F2 G2 F2', ownRecorder: recorder);
          rigOut = rig;
          await rig.play(
            performance(11, {
              5000000: 40,
              6000000: 41,
              7000000: 43,
              8000000: 41,
            }),
          );
          for (var i = 0; i < 100 && recorder.take == null; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await pumpEventQueue();
          expect(rig.controller.summary, isNotNull, reason: 'analysis ran');
          take = recorder.take;
          expect(take, isNotNull, reason: 'opt-in take was written');
          expect(take!.existsSync(), isTrue);
          expect(
            take!.path.startsWith(tmp.path),
            isTrue,
            reason: 'take lives under the temporary root only',
          );
          expect(take!.path, contains('/own_recording/'));
          await rig.close(); // the lesson screen closes
          await pumpEventQueue();
        });
        expect(rigOut, isNotNull);
        expect(take!.existsSync(), isFalse, reason: 'deleted at session end');
        expect(
          Directory('${tmp.path}/own_recording').existsSync()
              ? Directory('${tmp.path}/own_recording').listSync()
              : const <FileSystemEntity>[],
          isEmpty,
        );
        expect(guard.httpClients, isEmpty, reason: '${guard.httpClients}');
        expect(guard.sockets, isEmpty, reason: '${guard.sockets}');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'fake-mic latency calibration (E50) opens 0 clients and 0 sockets',
      () async {
        final guard = await _guarded(() async {
          var us = 0;
          final channel = DebugFakeMicChannel(
            mode: FakeMicMode.clean,
            clockUs: () => us,
            autoPump: false,
          );
          final audio = AudioInputController(
            channel: channel,
            requestMicrophonePermission: () async => PermissionStatus.granted,
            pcmDeliveryTimeout: const Duration(minutes: 5),
          );
          final c = SetupAudioController(
            audio: audio,
            store: MemorySetupProfileStore(),
            environment: const _NoNative(),
            estimator: (r) async => estimateRouteLatency(r),
          );
          await c.calibrateLatency();
          for (
            var i = 0;
            i < 750 &&
                c.phase != SetupAudioPhase.done &&
                c.phase != SetupAudioPhase.failed;
            i++
          ) {
            us += 40000;
            channel.pumpNow();
            await pumpEventQueue();
          }
          expect(c.failure, isNull);
          expect(c.latency, isA<LatencyMeasured>());
          c.dispose();
          await audio.dispose();
        });
        expect(guard.total, 0, reason: '${guard.httpClients} ${guard.sockets}');
      },
    );
  });

  group('2. kaynak kapısı (statik)', () {
    // Gerekçeli istisnalar — her biri açıkça yazılı; liste dışı = hata.
    //  * practice_audio_root.dart: `package:motion_account` yalnız hesap
    //    silme/çıkış sırasında ses kaynağını boşaltan KAYIT arayüzü
    //    (AccountResourceDrain*); kaynak içinde ağ çağrısı yok (aşağıdaki
    //    belirteç taraması bu dosyada da koşar).
    const importExceptions = <String>{
      'lib/app/audio/practice_audio_root.dart:package:motion_account/',
    };
    final roots = [
      'lib/app/audio',
      'lib/app/practice',
      'packages/ostinato_audio/lib',
    ];
    final files = <File>[
      for (final r in roots)
        ...Directory(r)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
    ];

    // Forbidden import prefixes (network / account / backend).
    final forbiddenImport = RegExp(
      r'''^\s*(?:import|export)\s+['"](?:'''
      r'dart:html|dart:js_interop|package:http/|package:http_parser/|'
      r'package:dio/|package:web_socket_channel/|package:web_socket/|'
      r'package:supabase|package:motion_account/|package:motion_core/|'
      r'package:firebase|package:cronet|package:cupertino_http|'
      r'package:url_launcher/|package:in_app_purchase|package:purchases_|'
      r'package:webview|package:connectivity|package:grpc|package:sentry)',
      multiLine: true,
    );
    // Forbidden tokens in code (comments stripped).
    final forbiddenToken = RegExp(
      r'\bHttpClient\b|\bHttpOverrides\b|\bSocket\.|\bRawSocket\b|'
      r'\bWebSocket\b|\bServerSocket\b|\bSupabase\b|\bDio\b|'
      r'\bRawDatagramSocket\b|\bSecureSocket\b|\bHttpServer\b|\bProcess\.|'
      r'''Uri\.parse\(\s*['"]https?:|['"]https?://''',
    );

    test('scan covers the real source tree (guards against an empty glob)', () {
      expect(files.length, greaterThan(40));
      expect(
        files.map((f) => f.path),
        containsAll([
          'lib/app/audio/audio_input_controller.dart',
          'lib/app/practice/own_recording/own_recording.dart',
          'packages/ostinato_audio/lib/src/rhythm/latency_estimator.dart',
        ]),
      );
    });

    test('no network, backend or account imports (except the listed ones)', () {
      for (final f in files) {
        final code = _stripComments(f.readAsStringSync());
        for (final m in forbiddenImport.allMatches(code)) {
          final hit = m.group(0)!.trim();
          final allowed = importExceptions.any((e) {
            final i = e.indexOf(':');
            return f.path == e.substring(0, i) &&
                hit.contains(e.substring(i + 1));
          });
          expect(allowed, isTrue, reason: '${f.path}: $hit');
        }
      }
    });

    test(
      'no HttpClient / Socket / WebSocket / hard-coded URL tokens in code',
      () {
        for (final f in files) {
          final code = _stripComments(f.readAsStringSync());
          final m = forbiddenToken.firstMatch(code);
          expect(m, isNull, reason: '${f.path}: ${m?.group(0)}');
        }
      },
    );

    test('dart:io is only used by the known local-file/Platform files', () {
      // Local files only (own take, stores, progress); never a network type.
      const allowed = <String>{
        'lib/app/practice/own_recording/own_take_player.dart',
        'lib/app/practice/own_recording/own_recording_preference.dart',
        'lib/app/practice/own_recording/own_recording.dart',
        'lib/app/practice/display/practice_display_preferences.dart',
        'lib/app/practice/setup/setup_profile_store.dart',
        'lib/app/practice/loop/practice_progress_store.dart',
      };
      final users = <String>{
        for (final f in files)
          if (RegExp(
            r'''^\s*import\s+['"]dart:io['"]''',
            multiLine: true,
          ).hasMatch(_stripComments(f.readAsStringSync())))
            f.path,
      };
      expect(
        users.difference(allowed),
        isEmpty,
        reason: 'new dart:io user: add it here only with a no-network reason',
      );
    });

    test('self-test: the scanners bite on a planted violation', () {
      const bad =
          "import 'package:http/http.dart' as http;\n"
          "void f() { HttpClient(); Socket.connect('x', 1); }\n"
          "final u = 'https://example.com';";
      expect(forbiddenImport.hasMatch(bad), isTrue);
      expect(forbiddenToken.hasMatch(bad), isTrue);
      for (final pkg in [
        'webview_flutter',
        'connectivity_plus',
        'grpc',
        'sentry_flutter',
      ]) {
        expect(
          forbiddenImport.hasMatch("import 'package:$pkg/$pkg.dart';"),
          isTrue,
          reason: pkg,
        );
      }
      for (final t in [
        'RawDatagramSocket.bind(a, 1)',
        'SecureSocket.connect(h, 1)',
        'RawSocket.connect(h, 1)',
        'HttpServer.bind(a, 1)',
        'Process.run(c, [])',
      ]) {
        expect(forbiddenToken.hasMatch(t), isTrue, reason: t);
      }
      expect(
        forbiddenToken.hasMatch('// HttpClient only in a comment'),
        isTrue,
      );
      expect(
        forbiddenToken.hasMatch(_stripComments('// HttpClient in a comment')),
        isFalse,
      );
    });
  });

  group('3. Android manifest', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    Set<String> perms() => RegExp(
      r'<uses-permission\s+android:name="([^"]+)"\s*/>',
    ).allMatches(manifest).map((m) => m.group(1)!).toSet();

    test('INTERNET is declared (account/subscription); RECORD_AUDIO too', () {
      // Pins today's state. INTERNET exists for the account/subscription
      // flows (`motion_account`), not for audio; the audio paths are fenced
      // by groups 1 and 2 above.
      expect(perms(), contains('android.permission.INTERNET'));
      expect(perms(), contains('android.permission.RECORD_AUDIO'));
    });
  });
}

final class _NoNative extends AudioEnvironmentProbe {
  const _NoNative();
  @override
  Future<AudioEnvironment> read() async => AudioEnvironment.unknown;
}
