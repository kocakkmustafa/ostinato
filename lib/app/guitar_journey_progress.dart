import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'account_data_directory.dart';

/// A record of user actions, never a claim that pitch, technique or health was
/// measured. Version is carried per record so revised content cannot inherit
/// a completion with the same stable lesson ID silently.
final class GuitarLessonProgress {
  const GuitarLessonProgress({
    required this.lessonId,
    required this.contentVersion,
    this.seenAt,
    this.practicedAt,
    this.practiceCount = 0,
    this.selfReportedCompletedAt,
  });

  final String lessonId;
  final String contentVersion;
  final DateTime? seenAt;
  final DateTime? practicedAt;
  final int practiceCount;
  final DateTime? selfReportedCompletedAt;

  Map<String, Object?> toJson() => {
    'lessonId': lessonId,
    'contentVersion': contentVersion,
    'seenAt': seenAt?.toUtc().toIso8601String(),
    'practicedAt': practicedAt?.toUtc().toIso8601String(),
    'practiceCount': practiceCount,
    'selfReportedCompletedAt': selfReportedCompletedAt
        ?.toUtc()
        .toIso8601String(),
    'evidence': 'self_report_only',
  };

  factory GuitarLessonProgress.fromJson(Map<String, dynamic> json) {
    if (json['evidence'] != 'self_report_only') {
      throw const FormatException('Unknown guitar progress evidence');
    }
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    return GuitarLessonProgress(
      lessonId: json['lessonId'] as String,
      contentVersion: json['contentVersion'] as String,
      seenAt: date('seenAt'),
      practicedAt: date('practicedAt'),
      practiceCount: json['practiceCount'] as int,
      selfReportedCompletedAt: date('selfReportedCompletedAt'),
    );
  }
}

enum GuitarProgressAction { viewed, practiced, selfReportedCompleted }

final class GuitarJourneyProgressStore {
  const GuitarJourneyProgressStore({
    this.directoryProvider,
    this.accountUserId,
  });

  final Future<Directory> Function()? directoryProvider;
  final String? accountUserId;

  Future<File> _file() async {
    final root = await (directoryProvider ?? getApplicationSupportDirectory)();
    final account = accountDataDirectory(root, accountUserId);
    return File('${account.path}/guitar_journey_progress.v1.json');
  }

  Future<Map<String, GuitarLessonProgress>> load() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported guitar progress schema');
    }
    final records = decoded['records'] as List<dynamic>;
    final result = <String, GuitarLessonProgress>{};
    for (final item in records) {
      final record = GuitarLessonProgress.fromJson(
        item as Map<String, dynamic>,
      );
      final key = '${record.contentVersion}|${record.lessonId}';
      if (result.containsKey(key) || record.practiceCount < 0) {
        throw const FormatException(
          'Duplicate or invalid guitar progress record',
        );
      }
      result[key] = record;
    }
    return result;
  }

  Future<GuitarLessonProgress> record({
    required String lessonId,
    required String contentVersion,
    required GuitarProgressAction action,
    DateTime? at,
  }) async {
    if (lessonId.isEmpty || contentVersion.isEmpty || lessonId.contains('|')) {
      throw ArgumentError('Invalid course progress identity');
    }
    final records = await load();
    final key = '$contentVersion|$lessonId';
    final old =
        records[key] ??
        GuitarLessonProgress(
          lessonId: lessonId,
          contentVersion: contentVersion,
        );
    if (action == GuitarProgressAction.selfReportedCompleted &&
        old.practiceCount == 0) {
      throw StateError(
        'A practice entry is required before self-reporting completion',
      );
    }
    final now = (at ?? DateTime.now()).toUtc();
    final next = GuitarLessonProgress(
      lessonId: lessonId,
      contentVersion: contentVersion,
      seenAt: old.seenAt ?? now,
      practicedAt: action == GuitarProgressAction.practiced
          ? now
          : old.practicedAt,
      practiceCount:
          old.practiceCount +
          (action == GuitarProgressAction.practiced ? 1 : 0),
      selfReportedCompletedAt:
          action == GuitarProgressAction.selfReportedCompleted
          ? old.selfReportedCompletedAt ?? now
          : old.selfReportedCompletedAt,
    );
    records[key] = next;
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      '${jsonEncode({'schemaVersion': 1, 'records': records.values.map((r) => r.toJson()).toList()})}\n',
      flush: true,
    );
    await temp.rename(file.path);
    return next;
  }
}
