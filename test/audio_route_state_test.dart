import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_route_state.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

void main() {
  group('mapIosPortType — never guesses, unknown stays unknown', () {
    final cases = <String, AudioRoute>{
      'Speaker': AudioRoute.speaker,
      'BuiltInMic': AudioRoute.speaker,
      'Headphones': AudioRoute.wiredHeadset,
      'HeadsetMic': AudioRoute.wiredHeadset,
      'BluetoothHFP': AudioRoute.bluetooth,
      'BluetoothA2DP': AudioRoute.bluetooth,
      'USBAudio': AudioRoute.usbOrOther,
    };

    cases.forEach((raw, expected) {
      test('"$raw" → $expected', () => expect(mapIosPortType(raw), expected));
    });

    test('an unrecognised iOS port type is unknown, not guessed as speaker', () {
      expect(mapIosPortType('CarAudio'), AudioRoute.unknown);
      expect(mapIosPortType(''), AudioRoute.unknown);
    });
  });

  group('mapAndroidDeviceType — never guesses, unknown stays unknown', () {
    final cases = <String, AudioRoute>{
      'TYPE_BUILTIN_MIC': AudioRoute.speaker,
      'TYPE_BUILTIN_SPEAKER': AudioRoute.speaker,
      'TYPE_WIRED_HEADSET': AudioRoute.wiredHeadset,
      'TYPE_BLUETOOTH_SCO': AudioRoute.bluetooth,
      'TYPE_BLE_HEADSET': AudioRoute.bluetooth,
      'TYPE_USB_DEVICE': AudioRoute.usbOrOther,
    };

    cases.forEach((raw, expected) {
      test('"$raw" → $expected', () => expect(mapAndroidDeviceType(raw), expected));
    });

    test('an unrecognised Android device type is unknown, not guessed', () {
      expect(mapAndroidDeviceType('TYPE_FM_TUNER'), AudioRoute.unknown);
      expect(mapAndroidDeviceType(''), AudioRoute.unknown);
    });
  });

  group('mapPlatformRouteTag — dispatches on the tag\'s own prefix, not the test host', () {
    test('an "ios:" tag always goes through the iOS table, even on a macOS test host', () {
      expect(mapPlatformRouteTag('ios:BluetoothHFP'), AudioRoute.bluetooth);
      expect(mapPlatformRouteTag('ios:Speaker'), AudioRoute.speaker);
    });

    test('an "android:" tag always goes through the Android table', () {
      expect(mapPlatformRouteTag('android:TYPE_WIRED_HEADSET'), AudioRoute.wiredHeadset);
      expect(mapPlatformRouteTag('android:TYPE_BLUETOOTH_SCO'), AudioRoute.bluetooth);
    });

    test('a missing separator is unknown, not a crash', () {
      expect(mapPlatformRouteTag('BluetoothHFP'), AudioRoute.unknown);
      expect(mapPlatformRouteTag(''), AudioRoute.unknown);
    });

    test('an unrecognised platform prefix is unknown', () {
      expect(mapPlatformRouteTag('windows:Speakers'), AudioRoute.unknown);
    });
  });
}
