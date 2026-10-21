import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:motion_content/motion_content.dart';

/// Reviewed source membership. New courses require an explicit source change;
/// the generated manifest never selects its own inputs or supplied hashes.
const Map<String, String> courseIntegrityAssets = <String, String>{
  'guitar-course-json': 'assets/content/guitar_journey.v1.json',
  'piano-course-json': 'assets/content/piano_beginner.v1.json',
  'ukulele-course-json': 'assets/content/ukulele_beginner.v1.json',
  'bass-course-json': 'assets/content/bass_beginner.v1.json',
  'vocal-course-json': 'assets/content/vocal_beginner.v1.json',
};
const String _manifestPath = 'assets/motion_content/manifest.json';

/// Generates the canonical integrity envelope for all reviewed authored courses.
/// Lesson semantics stay in the course JSON, rather than being copied here.
Future<void> main(List<String> arguments) =>
    runCourseIntegrityManifestCli(arguments);

/// Runs the CLI with capturable diagnostics for strict machine-reporter tests.
/// Normal invocations retain stderr diagnostics and process exit codes.
Future<void> runCourseIntegrityManifestCli(
  List<String> arguments, {
  void Function(String)? writeError,
}) async {
  final void Function(String) emitError = writeError ?? stderr.writeln;
  if (arguments.length != 1 ||
      !<String>{'--write', '--check'}.contains(arguments.single)) {
    emitError('Use --write or --check from the Ostinato app root.');
    exitCode = 64;
    return;
  }

  final File manifest = File(_manifestPath);
  if (arguments.single == '--write') {
    final expected = await buildCourseIntegrityManifest(Directory.current);
    await manifest.parent.create(recursive: true);
    await manifest.writeAsBytes(expected, flush: true);
    stdout.writeln(
      'Wrote $_manifestPath for ${courseIntegrityAssets.length} authored courses',
    );
    return;
  }

  if (!await manifest.exists()) {
    emitError('Missing generated manifest: $_manifestPath');
    exitCode = 1;
    return;
  }
  if (!await courseIntegrityManifestIsCurrent(Directory.current)) {
    emitError('Stale generated manifest: $_manifestPath');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Verified $_manifestPath against ${courseIntegrityAssets.length} authored courses',
  );
}

/// Core computes real byte lengths/hashes through its bounded secure reader,
/// validates the schema/contract, and serializes canonical bytes unchanged.
Future<Uint8List> buildCourseIntegrityManifest(Directory root) async {
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
      for (final entry in courseIntegrityAssets.entries)
        <String, String>{'id': entry.key, 'path': entry.value},
    ],
  };
  return ManifestBuilder().build(
    sourceBytes: Uint8List.fromList(utf8.encode(jsonEncode(source))),
    root: root,
  );
}

/// Identical to the CLI check; a missing source still throws fail-closed.
Future<bool> courseIntegrityManifestIsCurrent(Directory root) async {
  final expected = await buildCourseIntegrityManifest(root);
  final manifest = File('${root.path}/$_manifestPath');
  return await manifest.exists() &&
      _sameBytes(await manifest.readAsBytes(), expected);
}

bool _sameBytes(Uint8List actual, Uint8List expected) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}
