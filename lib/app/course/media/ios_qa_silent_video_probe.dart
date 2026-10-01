import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channelName = 'com.yulalab.ostinato/qa_silent_video_probe';
const _assetPrefix = 'assets/content/media/ostinato/';

/// QA-only metadata probe. A positive result does not enable the iOS video
/// factory or certify microphone coexistence.
@visibleForTesting
Future<bool> debugInspectIOSSilentBundledMp4(
  String assetName, {
  MethodChannel channel = const MethodChannel(_channelName),
  Duration deadline = const Duration(seconds: 3),
}) async {
  if (!kDebugMode ||
      defaultTargetPlatform != TargetPlatform.iOS ||
      !debugIsAllowedIOSSilentVideoAssetName(assetName)) {
    return false;
  }
  try {
    return await channel
            .invokeMethod<bool>('inspectBundledMp4', {'asset': assetName})
            .timeout(deadline) ==
        true;
  } catch (_) {
    return false;
  }
}

@visibleForTesting
bool debugIsAllowedIOSSilentVideoAssetName(String name) {
  if (name.length > 240 ||
      !name.startsWith(_assetPrefix) ||
      !name.endsWith('.mp4')) {
    return false;
  }
  final relative = name.substring(_assetPrefix.length);
  final components = relative.split('/');
  if (components.last.length <= 4) return false;
  final componentPattern = RegExp(r'^[A-Za-z0-9_.-]+$');
  return components.every(
    (component) =>
        component.isNotEmpty &&
        component != '.' &&
        component != '..' &&
        !component.startsWith('.') &&
        !component.endsWith('.') &&
        componentPattern.hasMatch(component),
  );
}
