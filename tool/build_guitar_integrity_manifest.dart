import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:motion_content/motion_content.dart';

const String _coursePath = 'assets/content/guitar_journey.v1.json';
const String _manifestPath = 'assets/motion_content/manifest.json';

/// Generates an integrity envelope for the existing authored guitar course.
/// Lesson semantics stay in the course JSON, rather than being copied here.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 ||
      !<String>{'--write', '--check'}.contains(arguments.single)) {
    stderr.writeln('Use --write or --check from the Ostinato app root.');
    exitCode = 64;
    return;
  }

  final Map<String, Object?> source = <String, Object?>{
    'schemaVersion': 1,
    'contentVersion': '1.0.0',
    'appId': 'com.yulalab.ostinato',
    'minimumCoreContract': currentMotionContentContract.toString(),
    'locales': <String>['tr', 'en'],
    'courses': <Object?>[],
    'lessons': <Object?>[],
    'models': <Object?>[],
    'assets': <Object?>[
      <String, String>{'id': 'guitar-course-json', 'path': _coursePath},
    ],
  };
  final Uint8List expected = await ManifestBuilder().build(
    sourceBytes: Uint8List.fromList(utf8.encode(jsonEncode(source))),
    root: Directory.current,
  );
  final File manifest = File(_manifestPath);
  if (arguments.single == '--write') {
    await manifest.parent.create(recursive: true);
    await manifest.writeAsBytes(expected, flush: true);
    stdout.writeln('Wrote $_manifestPath for $_coursePath');
    return;
  }

  if (!await manifest.exists()) {
    stderr.writeln('Missing generated manifest: $_manifestPath');
    exitCode = 1;
    return;
  }
  final Uint8List actual = await manifest.readAsBytes();
  if (!_sameBytes(actual, expected)) {
    stderr.writeln('Stale generated manifest: $_manifestPath');
    exitCode = 1;
    return;
  }
  stdout.writeln('Verified $_manifestPath against $_coursePath');
}

bool _sameBytes(Uint8List actual, Uint8List expected) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}
