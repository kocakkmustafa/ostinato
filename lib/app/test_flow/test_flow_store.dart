import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../account_data_directory.dart';
import '../account_data_operations.dart';

/// One section's latest result in a test flow. A passed section stays passed;
/// a later different result never undoes it (only failed parts are retried).
final class TestSectionResult {
  const TestSectionResult({
    required this.index,
    required this.passed,
    required this.at,
  });

  final int index;
  final bool passed;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'index': index,
    'passed': passed,
    'at': at.toUtc().toIso8601String(),
  };

  factory TestSectionResult.fromJson(Map<String, dynamic> json) =>
      TestSectionResult(
        index: json['index'] as int,
        passed: json['passed'] as bool,
        at: DateTime.parse(json['at'] as String),
      );
}

abstract interface class TestFlowProgress {
  /// Section results of [lessonId] by section index.
  Future<Map<int, TestSectionResult>> load(String lessonId);

  Future<TestSectionResult> record(
    String lessonId,
    int index, {
    required bool passed,
    DateTime? at,
  });
}

/// `v1_test_flow.v1.json` beside the lesson checks in the account directory,
/// so the flow resumes at the first unfinished part after a restart. Local
/// only: no audio, no answers, only which part passed and when.
final class TestFlowStore implements TestFlowProgress {
  TestFlowStore({this.directoryProvider, this.accountUserId})
    : _operations = AccountDataOperations(() async {
        final root =
            await (directoryProvider ?? getApplicationSupportDirectory)();
        return accountDataDirectory(root, accountUserId);
      });

  static const String fileName = 'v1_test_flow.v1.json';

  final Future<Directory> Function()? directoryProvider;
  final String? accountUserId;
  final AccountDataOperations _operations;

  Future<T> _run<T>(
    Future<T> Function(File file) operation, {
    bool writing = false,
  }) => _operations.run(
    (directory) => operation(File('${directory.path}/$fileName')),
    writing: writing,
  );

  Future<Map<String, Map<int, TestSectionResult>>> _loadAll(File file) async {
    if (!await file.exists()) return {};
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported test flow schema');
    }
    final lessons = decoded['lessons'] as Map<String, dynamic>;
    return {
      for (final e in lessons.entries)
        e.key: {
          for (final r in e.value as List<dynamic>)
            (r as Map<String, dynamic>)['index'] as int:
                TestSectionResult.fromJson(r),
        },
    };
  }

  @override
  Future<Map<int, TestSectionResult>> load(String lessonId) =>
      _run((file) async => (await _loadAll(file))[lessonId] ?? {});

  @override
  Future<TestSectionResult> record(
    String lessonId,
    int index, {
    required bool passed,
    DateTime? at,
  }) => _run((file) async {
    if (lessonId.isEmpty || index < 0) throw ArgumentError('Invalid section');
    final all = await _loadAll(file);
    final sections = all[lessonId] ??= {};
    final old = sections[index];
    final next = mergeSectionResult(
      old,
      TestSectionResult(
        index: index,
        passed: passed,
        at: (at ?? DateTime.now()).toUtc(),
      ),
    );
    if (identical(next, old)) return next;
    sections[index] = next;
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'lessons': {
          for (final e in all.entries)
            e.key: [for (final r in e.value.values) r.toJson()],
        },
      }),
      flush: true,
    );
    await tmp.rename(file.path);
    return next;
  }, writing: true);
}

/// A pass is kept; anything else takes the latest result.
TestSectionResult mergeSectionResult(
  TestSectionResult? old,
  TestSectionResult next,
) => old != null && old.passed ? old : next;
