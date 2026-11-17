// Device-day defines guard: the two device-day flags must stay false without
// a --dart-define, and no store/release build path may mention the define
// names. Only the files in [_allowed] may contain the marker.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';

const String _marker = 'OSTINATO_DEVDAY';

/// Explicit allow list (relative paths, prefix match for directories).
const List<String> _allowed = <String>[
  'docs/device-day/',
  'lib/app/ostinato_release_policy.dart',
  'test/devday_defines_test.dart',
];

bool _isAllowed(String rel) => _allowed.any(rel.startsWith);

String _rel(File f) {
  final root = Directory.current.absolute.path;
  final abs = f.absolute.path;
  return abs.substring(root.length + 1).replaceAll('\\', '/');
}

String? _readText(File f) {
  try {
    return f.readAsStringSync();
  } on FileSystemException {
    return null;
  } on FormatException {
    return null; // binary file
  }
}

List<File> _filesUnder(String dir, {bool Function(File)? where}) {
  final d = Directory(dir);
  if (!d.existsSync()) return <File>[];
  return d
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => where == null || where(f))
      .toList();
}

bool _skipBuildDirs(File f) {
  final r = _rel(f);
  return !(r.contains('/build/') ||
      r.contains('/Pods/') ||
      r.contains('/.gradle/') ||
      r.contains('/.dart_tool/') ||
      r.contains('/Flutter/ephemeral/'));
}

/// Release/build related files: workflows, docs/store, scripts that call
/// `flutter build`, and native fastlane/Gradle/Xcode/script/plist/json files
/// under ios/ and android/ (build output and Pods excluded).
/// NOT scanned (see docs/device-day/PROFIL-DERLEME.md section 6.6):
/// `--dart-define-from-file`, .env/.json define files outside ios/ android/,
/// Makefile, codemagic.yaml, and the base64 DART_DEFINES inside
/// ios/Flutter/Generated.xcconfig.
Map<String, List<File>> _scanScope() {
  const nativeExt = <String>[
    '.gradle',
    '.kts',
    '.properties',
    '.xcscheme',
    '.pbxproj',
    '.xcconfig',
    '.yml',
    '.yaml',
    '.rb',
    '.sh',
    '.plist',
    '.json',
  ];
  bool isNative(File f) {
    final name = f.uri.pathSegments.last;
    return _skipBuildDirs(f) &&
        (nativeExt.any(name.endsWith) ||
            name == 'Fastfile' ||
            name == 'Appfile' ||
            name == 'Gymfile');
  }

  return <String, List<File>>{
    'workflows': _filesUnder(
      '.github/workflows',
      where: (f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'),
    ),
    'docs/store': _filesUnder('docs/store'),
    'scripts': <File>[..._filesUnder('tool'), ..._filesUnder('tools')].where((
      f,
    ) {
      if (!_skipBuildDirs(f)) return false;
      final t = _readText(f);
      return t != null && t.contains('flutter build');
    }).toList(),
    'native': <File>[
      ..._filesUnder('android', where: isNative),
      ..._filesUnder('ios', where: isNative),
    ],
  };
}

void main() {
  test('both device-day flags are false without a --dart-define', () {
    expect(ostinatoStageHomeEnabled, isFalse);
    expect(ostinatoGhostScreenOpen, isFalse);
  });

  test('scan scope is not empty and covers known files', () {
    final scope = _scanScope();
    final workflows = scope['workflows']!.map(_rel).toList();
    expect(workflows, isNotEmpty);
    expect(workflows, contains('.github/workflows/checks.yml'));
    expect(
      scope['docs/store']!.map(_rel),
      contains('docs/store/RELEASE-REVIEW.md'),
    );
    expect(
      scope['native']!.map(_rel),
      contains('android/app/build.gradle.kts'),
    );
    expect(
      scope['native']!.map(_rel),
      contains('ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'),
    );
    expect(scope['native']!.map(_rel), contains('ios/Runner/Info.plist'));
    // tool/ and tools/ may hold no `flutter build` caller; whatever is in the
    // list must really be one.
    for (final f in scope['scripts']!) {
      expect(_readText(f), contains('flutter build'), reason: _rel(f));
    }
  });

  test('no store/release build path mentions $_marker', () {
    final offenders = <String>[];
    var scanned = 0;
    for (final files in _scanScope().values) {
      for (final f in files) {
        final rel = _rel(f);
        if (_isAllowed(rel)) continue;
        final text = _readText(f);
        if (text == null) continue;
        scanned++;
        if (text.contains(_marker)) offenders.add(rel);
      }
    }
    expect(scanned, greaterThan(0));
    expect(offenders, isEmpty, reason: 'device-day define in: $offenders');
  });
}
