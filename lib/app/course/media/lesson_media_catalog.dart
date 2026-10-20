import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:motion_content/motion_content.dart';

import '../../flutter_bundle_content_asset_reader.dart';
import '../../guitar_journey.dart';
import 'ostinato_source_projection_pin.dart';

// Closed app-only education QA source identity. These pins are not media acceptance roots.
const ostinatoMediaManifestSha256 =
    OstinatoSourceProjectionPin.sourceManifestSha256;
const ostinatoMediaSourceCatalogSha256 =
    '469b187a110db399d2b6a2967d4084efb7a7acd8aa6394fb8486393907a1f5f2';
const _sourceCatalogPath =
    'assets/motion_content/ostinato_source_pins_v2k.json';
const _opsSourceCatalogSha256 = OstinatoSourceProjectionPin.sourceCatalogSha256;
const _sourceProofSha256 =
    '272fd56aeab1477f7a27eb7666728e7a8ce85a88878f68309b2e997c3c4ea087';
const _courseSourceSha256 = OstinatoSourceProjectionPin.courseSha256;
const _coursePath = OstinatoSourceProjectionPin.coursePath;
const _mediaRoot = 'assets/content/media/';
const _maxVideoBytes = 64 * 1024 * 1024;
const _maxCaptionBytes = 1024 * 1024;
const _maxTotalBytes = 512 * 1024 * 1024;
final _sha = RegExp(r'^[0-9a-f]{64}$');

/// One exact QA source row from the app-only education source catalog.
/// There are no media candidates in the shipping catalog.
@immutable
final class LessonMediaSourcePin {
  const LessonMediaSourcePin({
    required this.app,
    required this.assetId,
    required this.lessonId,
    required this.sceneId,
    required this.variantStem,
    required this.courseSourceSha256,
    required this.lessonCanonicalSha256,
    required this.productionSpecSha256,
    required this.sourceCueSha256,
    required this.idempotencyKey,
    required this.productionState,
    required this.sourcePinSha256,
  });

  final String app, assetId, lessonId, sceneId, variantStem;
  final String courseSourceSha256, lessonCanonicalSha256;
  final String productionSpecSha256, sourceCueSha256;
  final String idempotencyKey, productionState, sourcePinSha256;

  String get key => '$lessonId\u0000$sceneId\u0000$variantStem';
}

@immutable
final class LessonMediaFile {
  const LessonMediaFile({
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  final String path, sha256;
  final int bytes;
}

/// Staging candidate only: byte validity is not educator/rights acceptance.
@immutable
final class LessonMediaCandidate {
  LessonMediaCandidate({
    required this.source,
    required this.manifestSha256,
    required this.video,
    required this.durationMs,
    required Map<String, LessonMediaFile> captions,
  }) : captions = Map<String, LessonMediaFile>.unmodifiable(captions);

  final LessonMediaSourcePin source;
  final String manifestSha256;
  final LessonMediaFile video;
  final int durationMs;
  final Map<String, LessonMediaFile> captions;

  bool get releaseEligible => false;
  bool get visible => false;
  int get progressEffect => 0;
}

/// An inspected test candidate never grants playback or lesson completion.
@immutable
final class InspectedLessonMedia {
  const InspectedLessonMedia(this.candidate, this.locale);

  final LessonMediaCandidate candidate;
  final String locale;

  bool get releaseEligible => false;
  bool get visible => false;
  int get progressEffect => 0;
}

typedef MediaDurationProbe = Future<int?> Function(Uint8List videoBytes);

/// Offline inspection seam. A signed release root and an audio-safe player
/// need a separate implementation before an inspected candidate is displayed.
final class LessonMediaCatalog {
  const LessonMediaCatalog.empty() : _candidates = const [];

  @visibleForTesting
  LessonMediaCatalog.synthetic({required List<LessonMediaCandidate> candidates})
    : _candidates = List.unmodifiable(candidates);

  final List<LessonMediaCandidate> _candidates;

  bool get isEmpty => _candidates.isEmpty;

  Future<InspectedLessonMedia?> inspect({
    required AssetBundle bundle,
    required String lessonId,
    required String sceneId,
    required String variantStem,
    required String locale,
    MediaDurationProbe? durationProbe,
  }) async {
    if (kReleaseMode ||
        _candidates.isEmpty ||
        (locale != 'en' && locale != 'tr') ||
        durationProbe == null) {
      return null;
    }
    final key = '$lessonId\u0000$sceneId\u0000$variantStem';
    final matches = _candidates.where((entry) => entry.source.key == key);
    if (matches.length != 1 || !_catalogSizeIsSafe()) {
      return null;
    }
    final candidate = matches.single;
    if (candidate.manifestSha256 != ostinatoMediaManifestSha256 ||
        !_fileShape(candidate.video, '$variantStem.mp4', _maxVideoBytes) ||
        candidate.durationMs <= 0 ||
        candidate.captions.keys.toSet().difference({'tr', 'en'}).isNotEmpty ||
        candidate.captions.length != 2) {
      return null;
    }
    for (final language in const ['tr', 'en']) {
      final caption = candidate.captions[language];
      if (caption == null ||
          !_fileShape(
            caption,
            '$variantStem.$language.vtt',
            _maxCaptionBytes,
          )) {
        return null;
      }
    }

    try {
      final pin = await _pinnedSource(bundle, candidate);
      if (pin == null ||
          !_sameSource(candidate.source, pin) ||
          !_validSourcePin(pin) ||
          _computedSourcePin(candidate) != pin.sourcePinSha256) {
        return null;
      }
      final course = await GuitarJourneyCourse.load(bundle: bundle);
      if (course.lessons.where((lesson) => lesson.id == lessonId).length != 1) {
        return null;
      }
      final reader = FlutterBundleContentAssetReader(bundle: bundle);
      final sourceBytes = await reader.read(_coursePath);
      if (computeSha256Hex(sourceBytes) != pin.courseSourceSha256 ||
          !_canonicalLessonMatches(
            sourceBytes,
            lessonId,
            pin.lessonCanonicalSha256,
          )) {
        return null;
      }
      final video = await reader.read(candidate.video.path);
      if (!_bytesMatch(video, candidate.video, _maxVideoBytes) ||
          !_mp4Signature(video) ||
          await durationProbe(video) != candidate.durationMs) {
        return null;
      }
      for (final language in const ['tr', 'en']) {
        final file = candidate.captions[language]!;
        final bytes = await reader.read(file.path);
        if (!_bytesMatch(bytes, file, _maxCaptionBytes) ||
            !_validVtt(bytes, language, candidate.durationMs)) {
          return null;
        }
      }
      return InspectedLessonMedia(candidate, locale);
    } catch (_) {
      // Missing, changed or unmeasurable media never blocks the written lesson.
      return null;
    }
  }

  bool _catalogSizeIsSafe() {
    var total = 0;
    final keys = <String>{};
    final paths = <String>{};
    for (final candidate in _candidates) {
      if (!keys.add(candidate.source.key)) return false;
      final stem = candidate.source.variantStem;
      if (candidate.durationMs <= 0 ||
          candidate.captions.length != 2 ||
          !_fileShape(candidate.video, '$stem.mp4', _maxVideoBytes)) {
        return false;
      }
      for (final language in const ['tr', 'en']) {
        final caption = candidate.captions[language];
        if (caption == null ||
            !_fileShape(caption, '$stem.$language.vtt', _maxCaptionBytes)) {
          return false;
        }
      }
      for (final file in [candidate.video, ...candidate.captions.values]) {
        if (!paths.add(file.path) || file.bytes <= 0) return false;
        total += file.bytes;
        if (total > _maxTotalBytes) return false;
      }
    }
    return true;
  }
}

bool _sameSource(LessonMediaSourcePin a, LessonMediaSourcePin b) =>
    a.app == b.app &&
    a.assetId == b.assetId &&
    a.lessonId == b.lessonId &&
    a.sceneId == b.sceneId &&
    a.variantStem == b.variantStem &&
    a.courseSourceSha256 == b.courseSourceSha256 &&
    a.lessonCanonicalSha256 == b.lessonCanonicalSha256 &&
    a.productionSpecSha256 == b.productionSpecSha256 &&
    a.sourceCueSha256 == b.sourceCueSha256 &&
    a.idempotencyKey == b.idempotencyKey &&
    a.productionState == b.productionState &&
    a.sourcePinSha256 == b.sourcePinSha256;

bool _validSourcePin(LessonMediaSourcePin source) =>
    source.app == 'ostinato' &&
    source.productionState == 'PREPRODUCTION_UNGENERATED' &&
    source.idempotencyKey == 'motion-media-v1:${source.productionSpecSha256}' &&
    _sha.hasMatch(source.courseSourceSha256) &&
    _sha.hasMatch(source.lessonCanonicalSha256) &&
    _sha.hasMatch(source.productionSpecSha256) &&
    _sha.hasMatch(source.sourceCueSha256) &&
    _sha.hasMatch(source.sourcePinSha256);

String _computedSourcePin(LessonMediaCandidate candidate) {
  final source = candidate.source;
  // Insertion order matches ops canonical JSON with sorted keys.
  final identity = <String, String>{
    'app': source.app,
    'assetId': source.assetId,
    'courseSourceSHA256': source.courseSourceSha256,
    'idempotencyKey': source.idempotencyKey,
    'lessonCanonicalSHA256': source.lessonCanonicalSha256,
    'lessonId': source.lessonId,
    'manifestSHA256': candidate.manifestSha256,
    'productionSpecSHA256': source.productionSpecSha256,
    'productionState': source.productionState,
    'sceneId': source.sceneId,
    'sourceCueSHA256': source.sourceCueSha256,
    'variantStem': source.variantStem,
  };
  return computeSha256Hex(
    Uint8List.fromList(utf8.encode(jsonEncode(identity))),
  );
}

Future<LessonMediaSourcePin?> _pinnedSource(
  AssetBundle bundle,
  LessonMediaCandidate candidate,
) async {
  final reader = FlutterBundleContentAssetReader(bundle: bundle);
  final bytes = await reader.read(_sourceCatalogPath);
  if (computeSha256Hex(bytes) != ostinatoMediaSourceCatalogSha256) {
    return null;
  }
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic> ||
      value['schemaVersion'] != 1 ||
      value['kind'] != 'OSTINATO_V2K_SOURCE_PINS_QA_ONLY' ||
      value['sourceCatalogSHA256'] != _opsSourceCatalogSha256 ||
      value['manifestSHA256'] != ostinatoMediaManifestSha256 ||
      value['sourceProofSHA256'] != _sourceProofSha256 ||
      value['courseSourceSHA256'] != _courseSourceSha256 ||
      value['visible'] != false ||
      value['releaseEligible'] != false ||
      value['progressEffect'] != 0 ||
      value['counts'] is! Map<String, dynamic> ||
      value['lessons'] is! List) {
    return null;
  }
  final counts = value['counts'] as Map<String, dynamic>;
  if (counts['lessons'] != 60 ||
      counts['scenes'] != 420 ||
      counts['variants'] != 420 ||
      counts['generatedMedia'] != 0 ||
      counts['qualifiedMedia'] != 0) {
    return null;
  }
  final source = candidate.source;
  final lessons = (value['lessons'] as List)
      .whereType<Map<String, dynamic>>()
      .where(
        (row) => row['app'] == 'ostinato' && row['lessonId'] == source.lessonId,
      );
  if (lessons.length != 1) return null;
  final lesson = lessons.single;
  if (lesson['membershipStatus'] != 'SOURCE_PINNED_TEST_ONLY' ||
      lesson['scenes'] is! List) {
    return null;
  }
  final scenes = (lesson['scenes'] as List)
      .whereType<Map<String, dynamic>>()
      .where((row) => row['sceneId'] == source.sceneId);
  if (scenes.length != 1) return null;
  final scene = scenes.single;
  if (scene['productionState'] != 'PREPRODUCTION_UNGENERATED' ||
      scene['variants'] is! List) {
    return null;
  }
  final variants = (scene['variants'] as List)
      .whereType<Map<String, dynamic>>()
      .where((row) => row['stem'] == source.variantStem);
  if (variants.length != 1) return null;
  final variant = variants.single;
  return LessonMediaSourcePin(
    app: lesson['app'] as String,
    assetId: lesson['assetId'] as String,
    lessonId: lesson['lessonId'] as String,
    sceneId: scene['sceneId'] as String,
    variantStem: variant['stem'] as String,
    courseSourceSha256: lesson['courseSourceSHA256'] as String,
    lessonCanonicalSha256: lesson['lessonCanonicalSHA256'] as String,
    productionSpecSha256: scene['productionSpecSHA256'] as String,
    sourceCueSha256: scene['sourceCueSHA256'] as String,
    idempotencyKey: scene['idempotencyKey'] as String,
    productionState: scene['productionState'] as String,
    sourcePinSha256: variant['sourcePinSHA256'] as String,
  );
}

bool _fileShape(LessonMediaFile file, String suffix, int maxBytes) {
  if (file.bytes <= 0 || file.bytes > maxBytes || !_sha.hasMatch(file.sha256)) {
    return false;
  }
  try {
    PathPolicy.validate(file.path);
  } catch (_) {
    return false;
  }
  return file.path == '$_mediaRoot$suffix';
}

bool _bytesMatch(Uint8List bytes, LessonMediaFile file, int maxBytes) =>
    bytes.isNotEmpty &&
    bytes.length <= maxBytes &&
    bytes.length == file.bytes &&
    computeSha256Hex(bytes) == file.sha256;

bool _canonicalLessonMatches(Uint8List bytes, String lessonId, String sha) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic> || decoded['modules'] is! List) {
    return false;
  }
  final lessons = <Map<String, dynamic>>[];
  for (final module in decoded['modules'] as List) {
    if (module is! Map<String, dynamic> || module['lessons'] is! List) {
      return false;
    }
    for (final lesson in module['lessons'] as List) {
      if (lesson is Map<String, dynamic> && lesson['id'] == lessonId) {
        lessons.add(lesson);
      }
    }
  }
  return lessons.length == 1 &&
      computeSha256Hex(
            Uint8List.fromList(
              utf8.encode(canonicalJsonEncode(lessons.single)),
            ),
          ) ==
          sha;
}

bool _mp4Signature(Uint8List bytes) =>
    bytes.length >= 12 &&
    bytes[4] == 0x66 &&
    bytes[5] == 0x74 &&
    bytes[6] == 0x79 &&
    bytes[7] == 0x70;

final _timing = RegExp(
  r'^(\d{2,}):([0-5]\d):([0-5]\d)\.(\d{3}) --> (\d{2,}):([0-5]\d):([0-5]\d)\.(\d{3})$',
);

bool _validVtt(Uint8List bytes, String locale, int durationMs) {
  final text = utf8.decode(bytes);
  if (text.contains('\r') ||
      text.contains('\ufeff') ||
      text.contains('\u0000')) {
    return false;
  }
  final header = 'WEBVTT - Motion locale=$locale\n\n';
  if (!text.startsWith(header)) return false;
  final body = text.substring(header.length).replaceFirst(RegExp(r'\n+$'), '');
  if (body.isEmpty) return false;
  var lastEnd = 0;
  for (final block in body.split('\n\n')) {
    final lines = block.split('\n');
    if (lines.length < 2 || lines.any((line) => line.trim().isEmpty)) {
      return false;
    }
    final match = _timing.firstMatch(lines.first);
    if (match == null) return false;
    int ms(int at) =>
        ((int.parse(match.group(at)!) * 60 + int.parse(match.group(at + 1)!)) *
                    60 +
                int.parse(match.group(at + 2)!)) *
            1000 +
        int.parse(match.group(at + 3)!);
    final start = ms(1), end = ms(5);
    if (end <= start || start < lastEnd || end > durationMs) return false;
    for (final line in lines.skip(1)) {
      if (line.contains('<') ||
          line.contains('>') ||
          line.contains('-->') ||
          line.runes.any((rune) => rune < 32 && rune != 9)) {
        return false;
      }
    }
    lastEnd = end;
  }
  return true;
}
