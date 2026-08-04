import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// Üretilen varlıkları okuyan ince depo — `library.json` (dürüstlük kapılarından
/// geçmiş) ve `posture-contract.json` (artefaktlardan üretilmiş).
///
/// Kabuk bu sayıların HİÇBİRİNİ kendi içinde tutmaz. Tuttuğu an, regen sonrası
/// ekranda "7 eğitmen" yazarken artefaktın başka bir şey söylediği durum doğar
/// — O-029'un (vitrin korumasızdı) canlı-yüzey hâli.
final class ContentRepository {
  ContentRepository._(this.disciplines, this._contracts);

  final List<Discipline> disciplines;
  final Map<String, PostureContract> _contracts;

  PostureContract contractFor(String instrument) => _contracts[instrument]!;

  static Future<ContentRepository> load() async {
    final String libRaw = await rootBundle.loadString('assets/content/library.json');
    final String contractRaw =
        await rootBundle.loadString('assets/config/posture-contract.json');
    final Map<String, dynamic> lib = jsonDecode(libRaw) as Map<String, dynamic>;
    final List<Discipline> ds = <Discipline>[
      for (final dynamic d in lib['disciplines'] as List<dynamic>)
        Discipline._fromJson(d as Map<String, dynamic>),
    ];
    return ContentRepository._(ds, <String, PostureContract>{
      for (final Discipline d in ds)
        if (d.status == 'live')
          d.id: PostureContract.fromJson(contractRaw, d.id),
    });
  }
}

final class Discipline {
  const Discipline._(this.id, this.displayName, this.status, this.blurb,
      this.measured, this.notMeasured, this.lessons);

  final String id;
  final String displayName;
  final String status;
  final String blurb;
  final List<String> measured;

  /// Dürüstlük kutusunun "ölçmediklerimiz" yarısı. Ekranda küçük gri dipnot
  /// DEĞİL: ürünün en somut iddiası bu listede duruyor.
  final List<String> notMeasured;
  final List<Lesson> lessons;

  static Discipline _fromJson(Map<String, dynamic> m) {
    final List<Lesson> lessons = <Lesson>[];
    for (final dynamic c in (m['courses'] as List<dynamic>? ?? <dynamic>[])) {
      for (final dynamic l in (c as Map<String, dynamic>)['lessons'] as List<dynamic>) {
        lessons.add(Lesson._fromJson(l as Map<String, dynamic>));
      }
    }
    final Map<String, dynamic> honesty = m['honesty'] as Map<String, dynamic>;
    return Discipline._(
      m['id'] as String,
      m['displayName'] as String,
      m['status'] as String,
      m['blurb'] as String? ?? '',
      List<String>.from(honesty['measured'] as List<dynamic>? ?? <dynamic>[]),
      List<String>.from(honesty['notMeasured'] as List<dynamic>? ?? <dynamic>[]),
      lessons,
    );
  }
}

final class Lesson {
  const Lesson._(this.id, this.displayName, this.status, this.lockedReason,
      this.demoOnlyReason, this.showsCue);

  final String id;
  final String displayName;

  /// `open` · `locked` · `demoOnly` — üçü AYRI yüzey. Kilitli ders hiçbir
  /// hüküm göstermez; demoOnly ölçüm gösterir, puan göstermez.
  final String status;
  final String? lockedReason;
  final String? demoOnlyReason;
  final bool showsCue;

  static Lesson _fromJson(Map<String, dynamic> m) => Lesson._(
        m['id'] as String,
        m['displayName'] as String,
        m['status'] as String? ?? 'open',
        m['lockedReason'] as String?,
        m['demoOnlyReason'] as String?,
        (m['observationCues'] as List<dynamic>? ?? <dynamic>[]).isNotEmpty,
      );
}
