import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

/// OST-P0-002 kabul testleri: roadmap §12 Task OST-P0-002 Step 1'in beş
/// senaryosu — izin reddi/geri alma, arka plan, route değişimi, tampon
/// temizliği, desteklenmeyen sample rate. Hepsi [FakeAudioCaptureChannel] +
/// enjekte edilmiş izin fonksiyonuyla DONANIMSIZ kanıtlanır — "gerçek
/// mikrofon çalışıyor" iddiası TAŞIMAZ (bkz. `AudioInputController` dosya-başı
/// notu, cihaz-günü release-gate ayrı kalır).
void main() {
  // `AudioLifecycleObserver.attach()` `WidgetsBinding.instance`e erişir —
  // düz `test()` bunu OTOMATİK kurmaz (yalnız `testWidgets()` kurar). Bu
  // dosyada `testWidgets` YOK (bilerek — yukarı bkz.), o yüzden binding'i
  // burada elle başlatmak GEREKİR; `flutter test`in kendi önerdiği satır.
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PermissionStatus> granted() async => PermissionStatus.granted;
  Future<PermissionStatus> deniedRetriable() async => PermissionStatus.denied;
  Future<PermissionStatus> deniedPermanent() async =>
      PermissionStatus.permanentlyDenied;

  group('İzin reddi/geri alma', () {
    test('retriable denial reaches PermissionDeniedRetriable and never starts the channel', () async {
      final channel = FakeAudioCaptureChannel();
      final controller = AudioInputController(
        channel: channel,
        requestMicrophonePermission: deniedRetriable,
      );
      final states = <AudioSurfaceState>[];
      final sub = controller.status.listen(states.add);

      await controller.start(sampleRate: 44100);
      await pumpEventQueue();

      expect(states, [isA<AudioStarting>(), isA<AudioPermissionDeniedRetriable>()]);
      expect(channel.isRunning, isFalse);
      expect(controller.bufferedSampleCountForTest, 0);

      await sub.cancel();
      await controller.dispose();
    });

    test('permanent denial is a distinct, named state — not lumped with retriable', () async {
      final channel = FakeAudioCaptureChannel();
      final controller = AudioInputController(
        channel: channel,
        requestMicrophonePermission: deniedPermanent,
      );
      final states = <AudioSurfaceState>[];
      final sub = controller.status.listen(states.add);

      await controller.start(sampleRate: 44100);
      await pumpEventQueue();

      expect(states.last, isA<AudioPermissionDeniedPermanent>());
      expect(channel.isRunning, isFalse);

      await sub.cancel();
      await controller.dispose();
    });

    test(
      'permission revoked mid-session (channel reports an interruption) stops '
      'capture and clears the buffer — revoke is not distinguishable from any '
      'other native interruption at this layer, both fail closed the same way',
      () async {
        final channel = FakeAudioCaptureChannel();
        final controller = AudioInputController(
          channel: channel,
          requestMicrophonePermission: granted,
        );
        await controller.start(sampleRate: 44100);
        channel.pushChunk(List.filled(512, 0.2), sampleRate: 44100, tNativeUs: 0);
        await pumpEventQueue();
        expect(controller.bufferedSampleCountForTest, greaterThan(0));

        channel.pushInterruption('permission_revoked');
        await pumpEventQueue();

        expect(controller.bufferedSampleCountForTest, 0);
        expect(channel.isRunning, isFalse);
        await controller.dispose();
      },
    );
  });

  group('Desteklenmeyen sample rate', () {
    test('an unsupported rate is named, not silently substituted, and never buffers', () async {
      final channel = FakeAudioCaptureChannel(supportedSampleRates: {44100, 48000});
      final controller = AudioInputController(
        channel: channel,
        requestMicrophonePermission: granted,
      );
      final states = <AudioSurfaceState>[];
      final sub = controller.status.listen(states.add);

      await controller.start(sampleRate: 96000);
      await pumpEventQueue();

      final unavailable = states.last as AudioUnavailable;
      expect(unavailable.reason, 'unsupported_sample_rate:96000');
      expect(channel.isRunning, isFalse);
      expect(controller.bufferedSampleCountForTest, 0);

      await sub.cancel();
      await controller.dispose();
    });
  });

  group('Route değişimi → kalibrasyona dönüş (roadmap §7 madde 2)', () {
    test('a route change while streaming re-emits Calibrating with the mapped route', () async {
      final channel = FakeAudioCaptureChannel();
      final controller = AudioInputController(
        channel: channel,
        requestMicrophonePermission: granted,
      );
      final states = <AudioSurfaceState>[];
      final sub = controller.status.listen(states.add);

      await controller.start(sampleRate: 44100);
      channel.pushRouteChange('ios:BluetoothHFP');
      await pumpEventQueue();

      final calibrating = states.last as AudioCalibrating;
      expect(calibrating.route, AudioRoute.bluetooth);

      await sub.cancel();
      await controller.dispose();
    });

    test('an unrecognised route tag maps to unknown, never guessed as a known route', () async {
      final channel = FakeAudioCaptureChannel();
      final controller = AudioInputController(
        channel: channel,
        requestMicrophonePermission: granted,
      );
      final states = <AudioSurfaceState>[];
      final sub = controller.status.listen(states.add);

      await controller.start(sampleRate: 44100);
      channel.pushRouteChange('ios:CarAudio');
      await pumpEventQueue();

      final calibrating = states.last as AudioCalibrating;
      expect(calibrating.route, AudioRoute.unknown);

      await sub.cancel();
      await controller.dispose();
    });
  });

  group('Tampon temizliği (roadmap §7 madde 1)', () {
    test('chunks accumulate in the ring buffer while streaming', () async {
      final channel = FakeAudioCaptureChannel();
      final controller = AudioInputController(
        channel: channel,
        requestMicrophonePermission: granted,
        ringBufferCapacitySamples: 44100,
      );
      await controller.start(sampleRate: 44100);
      channel.pushChunk(List.filled(1000, 0.3), sampleRate: 44100, tNativeUs: 0);
      await pumpEventQueue();

      expect(controller.bufferedSampleCountForTest, 1000);
      await controller.dispose();
    });

    test('stop() unconditionally zeroes the buffer, success or not', () async {
      final channel = FakeAudioCaptureChannel();
      final controller = AudioInputController(
        channel: channel,
        requestMicrophonePermission: granted,
      );
      await controller.start(sampleRate: 44100);
      channel.pushChunk(List.filled(2000, 0.4), sampleRate: 44100, tNativeUs: 0);
      await pumpEventQueue();
      expect(controller.bufferedSampleCountForTest, greaterThan(0));

      await controller.stop();

      expect(controller.bufferedSampleCountForTest, 0);
      expect(channel.isRunning, isFalse);
      await controller.dispose();
    });

    test('stop() clears the buffer even when nothing was ever streamed', () async {
      final controller = AudioInputController(
        channel: FakeAudioCaptureChannel(),
        requestMicrophonePermission: deniedRetriable,
      );
      await controller.start(sampleRate: 44100); // reddedilir, hiç akmaz
      await controller.stop(); // yine de güvenle çağrılabilir olmalı
      expect(controller.bufferedSampleCountForTest, 0);
      await controller.dispose();
    });
  });

  group('Arka plan geçişi (roadmap §7 madde 1 — background)', () {
    test('AudioLifecycleObserver fires onBackground on paused and on detached, not on resumed', () {
      var calls = 0;
      final observer = AudioLifecycleObserver(onBackground: () => calls++)..attach();

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(calls, 0, reason: 'foreground dönüşü tampon temizlemeyi TETİKLEMEMELİ');

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(calls, 1);

      observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(calls, 2);

      observer.detach();
    });

    // Not: `AudioInputController`ın kendisini GERÇEK `WidgetsBinding`
    // yaşam-döngüsü olayıyla uçtan uca sınamak (`tester.binding.
    // handleAppLifecycleStateChanged`) BİLEREK burada YOK — bu API'nin
    // sürümler arası görünürlüğü belirsiz, yanlış varsayım bir derleme
    // hatasına mal olurdu. Bunun yerine İKİ parça AYRI kanıtlanıyor: yukarıda
    // `AudioLifecycleObserver`ın çağrı KURALI (paused/detached'ta tetikler,
    // resumed'da tetiklemez) ve aşağıda `stop()`ın tamponu koşulsuz
    // sıfırladığı — `_onBackground`ın `stop()`u çağırdığı tek satırlık
    // kablolama (`audio_input_controller.dart`) kod-incelemesiyle doğrulanır.
  });

  group('Kanal hatası → isimli sebep, ham istisna metni değil', () {
    test('a PlatformException other than unsupported-rate becomes a named SetupFailed', () async {
      final failing = _ThrowingCaptureChannel(
        PlatformException(code: 'engine_start_failed', message: 'boom'),
      );
      final controller = AudioInputController(
        channel: failing,
        requestMicrophonePermission: granted,
      );
      final states = <AudioSurfaceState>[];
      final sub = controller.status.listen(states.add);

      await controller.start(sampleRate: 44100);
      await pumpEventQueue();

      final failed = states.last as AudioSetupFailed;
      expect(failed.reason, 'engine_start_failed');

      await sub.cancel();
      await controller.dispose();
    });
  });

  group('Dosya/ağ kalıntısı yok (roadmap OST-P0-002 Step 4) — kaynak taraması', () {
    // `AudioRingBuffer.clear()`in "gerçekten sıfırlar" testi (capture_test.dart)
    // ve `AudioInputController`ın "her stop() zeroize eder" testi (yukarıda)
    // DAVRANIŞI kanıtlıyor. Bu grup FARKLI bir soruyu kanıtlıyor: yakalama
    // kod yolunun HİÇBİR YERİNDE diske yazma veya ağa çıkma API'si YOK —
    // `validate_runtime_fetch.py`/`validate_surface_honesty.py`nin kendi
    // kaynak-tarama desenini ödünç alır (ölçüm koddan, davranıştan DEĞİL).
    const capturePaths = <String>[
      'lib/app/audio/audio_input_controller.dart',
      'lib/app/audio/audio_capture_channel.dart',
      'lib/app/audio/audio_route_state.dart',
      'lib/app/audio/guitar_note_observation_controller.dart',
      'packages/ostinato_audio/lib/src/pitch/guitar_pitch_observer.dart',
    ];

    // Paket sınırı: `packages/ostinato_audio/lib/src/capture/` da aynı
    // taramaya girer — normative-reference paket olsa da ring buffer'ın
    // "RAM-only" iddiası TAM olarak burada yaşıyor.
    const packageCapturePaths = <String>[
      'packages/ostinato_audio/lib/src/capture/audio_source.dart',
      'packages/ostinato_audio/lib/src/capture/ring_buffer.dart',
      'packages/ostinato_audio/lib/src/capture/audio_surface_state.dart',
    ];

    const forbiddenDiskWrite = <String>[
      'File(', 'FileMode.write', '.writeAsBytes', '.writeAsString', '.writeAsBytesSync', '.openWrite',
    ];
    const forbiddenNetwork = <String>[
      'HttpClient(', "'package:http", '.post(', '.get(Uri', 'WebSocket',
    ];

    for (final path in [...capturePaths, ...packageCapturePaths]) {
      test('$path never writes to disk', () {
        final source = File(path).readAsStringSync();
        for (final pattern in forbiddenDiskWrite) {
          expect(source.contains(pattern), isFalse,
              reason: '$path source içeriyor: "$pattern" — roadmap §7 madde 1 '
                  '"raw PCM diske yazılmaz" iddiasını çiğner');
        }
      });

      test('$path never opens a network client', () {
        final source = File(path).readAsStringSync();
        for (final pattern in forbiddenNetwork) {
          expect(source.contains(pattern), isFalse,
              reason: '$path source içeriyor: "$pattern" — roadmap §9 "raw '
                  'mic upload yok" iddiasını çiğner');
        }
      });
    }

    test(
      'self-test: the scan itself catches a real violation, not just an '
      'absence it never checked (M-F-634-style: prove the gate bites)',
      () {
        final decoy = Directory.systemTemp.createTempSync('audio-privacy-selftest');
        final decoyFile = File('${decoy.path}/decoy.dart')
          ..writeAsStringSync("void x() { File('leak.pcm').writeAsBytes([1,2,3]); }");
        addTearDown(() => decoy.deleteSync(recursive: true));

        final source = decoyFile.readAsStringSync();
        final caught = forbiddenDiskWrite.any(source.contains);
        expect(caught, isTrue,
            reason: 'tarama deseni kasıtlı bir ihlali bile göremiyorsa kör bir kapı');
      },
    );
  });
}

/// `start()`in KENDİSİ (kanal-kurulum aşaması, olay akışı değil) native
/// istisna fırlattığında `AudioInputController`ın PlatformException →
/// AudioSetupFailed eşlemesini sınamak için — `FakeAudioCaptureChannel`
/// yalnız sample-rate reddini simüler, bu ikizi GENEL bir kurulum
/// hatası için ayrı tutuyoruz (tek-amaçlı sahte, `FakeAudioCaptureChannel`ı
/// şişirmek yerine).
final class _ThrowingCaptureChannel implements AudioCaptureChannel {
  _ThrowingCaptureChannel(this._error);
  final PlatformException _error;

  @override
  Stream<RawAudioEvent> get events => const Stream.empty();

  @override
  Future<void> start({required int sampleRate}) async => throw _error;

  @override
  Future<void> stop() async {}
}
