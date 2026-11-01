import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import 'latency_calibration.dart';

/// F4.2 — what the phone's audio route and microphone settings are, read
/// without starting capture (iOS: `AVAudioSession.currentRoute`,
/// `AVCaptureDevice.preferredMicrophoneMode`; Android: `AudioManager`).
///
/// Read only: nothing is changed, no permission is asked. When the native
/// method is missing (older build, tests) everything is [unknown] and no
/// warning is shown; nothing is guessed.
final class AudioEnvironment {
  const AudioEnvironment({
    this.platform = '',
    this.inputPorts = const [],
    this.outputPorts = const [],
    this.micMode = MicMode.unknown,
  });

  static const unknown = AudioEnvironment();

  /// `ios` or `android` (empty when unknown).
  final String platform;

  /// Raw port names, the same vocabulary as the capture route tag
  /// (`BuiltInMic`, `HeadsetMic`, `TYPE_WIRED_HEADSET`, …).
  final List<String> inputPorts;
  final List<String> outputPorts;
  final MicMode micMode;

  bool get isKnown => platform.isNotEmpty;

  factory AudioEnvironment.fromWire(Object? raw) {
    if (raw is! Map) return unknown;
    List<String> names(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is String) e,
          ]
        : const [];
    final platform = raw['platform'];
    if (platform != 'ios' && platform != 'android') return unknown;
    return AudioEnvironment(
      platform: platform as String,
      inputPorts: names(raw['inputs']),
      outputPorts: names(raw['outputs']),
      micMode: switch (raw['micMode']) {
        'standard' => MicMode.standard,
        'voiceIsolation' => MicMode.voiceIsolation,
        'wideSpectrum' => MicMode.wideSpectrum,
        _ => MicMode.unknown,
      },
    );
  }
}

/// iOS Control Center "Mic Mode" (iOS 15+).
enum MicMode { unknown, standard, voiceIsolation, wideSpectrum }

/// Reads [AudioEnvironment] from the native side.
class AudioEnvironmentProbe {
  const AudioEnvironmentProbe({
    MethodChannel channel = const MethodChannel(channelName),
    this.deadline = const Duration(milliseconds: 600),
  }) : _channel = channel;

  static const channelName = 'com.yulalab.ostinato/audio_environment';

  final MethodChannel _channel;
  final Duration deadline;

  Future<AudioEnvironment> read() async {
    try {
      final raw = await _channel
          .invokeMethod<Object?>('read')
          .timeout(deadline);
      return AudioEnvironment.fromWire(raw);
    } on Object {
      return AudioEnvironment.unknown;
    }
  }
}

/// One-line setup warnings (`parcalar/ses.md` §7: rivals found these traps
/// late). Only what was actually detected is reported.
enum SetupWarning {
  /// iOS Mic Mode is Voice Isolation: the instrument is filtered as noise.
  voiceIsolation,

  /// iOS Mic Mode is Wide Spectrum: room sound is boosted.
  wideSpectrum,

  /// A wired headset microphone is the input, not the phone's.
  headsetMic,

  /// A Bluetooth headset microphone is the input (narrow band, processed).
  bluetoothMic,
}

List<SetupWarning> setupWarnings(AudioEnvironment env) {
  final inputs = [
    for (final p in env.inputPorts) mapPlatformInput(env.platform, p),
  ];
  return [
    if (env.micMode == MicMode.voiceIsolation) SetupWarning.voiceIsolation,
    if (env.micMode == MicMode.wideSpectrum) SetupWarning.wideSpectrum,
    if (inputs.contains(AudioRoute.wiredHeadset)) SetupWarning.headsetMic,
    if (inputs.contains(AudioRoute.bluetooth)) SetupWarning.bluetoothMic,
  ];
}

AudioRoute mapPlatformInput(String platform, String port) => switch (platform) {
  'ios' => _iosPort(port),
  'android' => _androidType(port),
  _ => AudioRoute.unknown,
};

AudioRoute _iosPort(String p) => switch (p) {
  'Speaker' ||
  'Receiver' ||
  'BuiltInMic' ||
  'MicrophoneBuiltIn' => AudioRoute.speaker,
  // Raw `AVAudioSession.Port` values are accepted too (`MicrophoneWired`,
  // `BluetoothA2DPOutput`): the capture route tag sends them unmapped.
  'Headphones' ||
  'HeadsetMic' ||
  'MicrophoneWired' ||
  'LineIn' ||
  'LineOut' => AudioRoute.wiredHeadset,
  'BluetoothHFP' ||
  'BluetoothA2DP' ||
  'BluetoothA2DPOutput' ||
  'BluetoothLE' => AudioRoute.bluetooth,
  'USBAudio' => AudioRoute.usbOrOther,
  _ => AudioRoute.unknown,
};

AudioRoute _androidType(String t) => switch (t) {
  'TYPE_BUILTIN_MIC' ||
  'TYPE_BUILTIN_SPEAKER' ||
  'TYPE_BUILTIN_EARPIECE' => AudioRoute.speaker,
  'TYPE_WIRED_HEADSET' || 'TYPE_WIRED_HEADPHONES' => AudioRoute.wiredHeadset,
  'TYPE_BLUETOOTH_SCO' ||
  'TYPE_BLUETOOTH_A2DP' ||
  'TYPE_BLE_HEADSET' ||
  'TYPE_BLE_SPEAKER' => AudioRoute.bluetooth,
  'TYPE_USB_DEVICE' ||
  'TYPE_USB_HEADSET' ||
  'TYPE_USB_ACCESSORY' => AudioRoute.usbOrOther,
  _ => AudioRoute.unknown,
};

/// Which stored calibration applies. The **output** decides the latency
/// (Bluetooth headphones are slow even with the phone's microphone), so the
/// output port wins; without native output information the capture's input
/// route is used. Unknown or USB → null: no calibration, the badge stays.
CalibrationRoute? calibrationRouteOf(
  AudioRoute inputRoute,
  AudioEnvironment env,
) {
  final outputs = [
    for (final p in env.outputPorts) mapPlatformInput(env.platform, p),
  ];
  AudioRoute route;
  if (outputs.contains(AudioRoute.bluetooth)) {
    route = AudioRoute.bluetooth;
  } else if (outputs.contains(AudioRoute.wiredHeadset)) {
    route = AudioRoute.wiredHeadset;
  } else if (outputs.contains(AudioRoute.speaker)) {
    route = AudioRoute.speaker;
  } else if (outputs.isNotEmpty) {
    return null;
  } else {
    route = inputRoute;
  }
  return switch (route) {
    AudioRoute.speaker => CalibrationRoute.speaker,
    AudioRoute.wiredHeadset => CalibrationRoute.wiredHeadset,
    AudioRoute.bluetooth => CalibrationRoute.bluetooth,
    _ => null,
  };
}
