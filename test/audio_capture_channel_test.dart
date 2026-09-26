import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';

const method = MethodChannel('com.yulalab.ostinato/audio_capture');
const events = MethodChannel('com.yulalab.ostinato/audio_capture/events');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(events, (call) async {
      calls.add('event:${call.method}');
      return null;
    });
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call.method);
      return call.method == 'ready' ? true : null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(events, null);
    messenger.setMockMethodCallHandler(method, null);
  });
  Future<void> send(Object value) async {
    messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope(value),
      (_) {},
    );
    await pumpEventQueue();
  }

  test(
    'subscription ready handshake precedes native start and stop cancels events',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      final received = <RawAudioEvent>[];
      final sub = channel.events.listen(received.add);
      await channel.start(sampleRate: 44100);
      expect(calls.indexOf('ready'), lessThan(calls.indexOf('start')));
      await send({'type': 'routeChanged', 'route': 'ios:BuiltInMic'});
      await send({
        'type': 'chunk',
        'samples': Float64List.fromList([.1, .2]),
        'sampleRate': 44100,
        't': 12,
      });
      expect(received.first, isA<RawRouteChangedEvent>());
      expect((received.last as RawAudioChunkEvent).samples, [.1, .2]);
      await channel.stop();
      expect(calls, containsAll(['event:cancel', 'stop']));
      await sub.cancel();
    },
  );
  test(
    'invalid native envelope becomes interruption instead of an uncaught cast',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      final received = <RawAudioEvent>[];
      final sub = channel.events.listen(received.add);
      await channel.start(sampleRate: 44100);
      await send({'type': 'chunk', 'samples': 'invalid'});
      expect(
        (received.single as RawInterruptedEvent).reason,
        'invalid_capture_event',
      );
      await channel.stop();
      await sub.cancel();
    },
  );
}
