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
  PostureContract? contractOrNull(String instrument) => _contracts[instrument];

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
      this.measured, this.notMeasured, this.comingSoon, this.courses);

  final String id;
  final String displayName;
  final String status;
  final String blurb;
  final List<String> measured;

  /// Dürüstlük kutusunun "ölçmediklerimiz" yarısı. Ekranda küçük gri dipnot
  /// DEĞİL: ürünün en somut iddiası bu listede duruyor.
  final List<String> notMeasured;

  /// "Not here — and why" — kapsam-dışı ama isimli-gerekçeli kalemler.
  /// (DÜZELTME 2026-08-07, M-F-186: "yet" çıkarıldı — bu liste zaten
  /// KAPSAM-DIŞI, "henüz" demek gelmeyecek olana vaat verirdi.)
  final List<String> comingSoon;

  final List<Course> courses;

  /// Geriye-uyum: tek kursluk bugünkü yapıda düz liste isteyen çağıranlar için.
  List<Lesson> get lessons =>
      <Lesson>[for (final Course c in courses) ...c.lessons];

  static Discipline _fromJson(Map<String, dynamic> m) {
    final List<Course> courses = <Course>[
      for (final dynamic c in (m['courses'] as List<dynamic>? ?? <dynamic>[]))
        Course._fromJson(c as Map<String, dynamic>),
    ];
    final Map<String, dynamic> honesty = m['honesty'] as Map<String, dynamic>;
    return Discipline._(
      m['id'] as String,
      m['displayName'] as String,
      m['status'] as String,
      m['blurb'] as String? ?? '',
      List<String>.from(honesty['measured'] as List<dynamic>? ?? <dynamic>[]),
      List<String>.from(honesty['notMeasured'] as List<dynamic>? ?? <dynamic>[]),
      List<String>.from(
          m['comingSoonInThisDiscipline'] as List<dynamic>? ?? <dynamic>[]),
      courses,
    );
  }
}

final class Course {
  const Course._(this.id, this.displayName, this.level, this.goal,
      this.estimatedMinutes, this.lessons);

  final String id;
  final String displayName;
  final String level;
  final String goal;
  final int estimatedMinutes;
  final List<Lesson> lessons;

  static Course _fromJson(Map<String, dynamic> m) => Course._(
        m['id'] as String,
        m['displayName'] as String,
        m['level'] as String? ?? '',
        m['goal'] as String? ?? '',
        m['estimatedMinutes'] as int? ?? 0,
        <Lesson>[
          for (final dynamic l in m['lessons'] as List<dynamic>)
            Lesson._fromJson(l as Map<String, dynamic>),
        ],
      );
}

/// Bir dersin gösterebileceği DÖRT görsel sınıf — tasarım paneli §4.
///
/// Türetim kuralı İCAT edilmedi, var olan iki alandan (`status` · `focus`)
/// OKUNUYOR: yeni bir sınıflandırma alanı eklemek yerine zaten `library.json`da
/// duran gerçeği yorumluyoruz.
enum LessonKind {
  /// Ölçüm iddiası YOK — saf yönerge dersi (ör. "Camera and space").
  guide,

  /// Ölçülür ve hüküm verilir — normal akış.
  scored,

  /// Ders görünür ama açılmaz; sebep EKSİK ÖLÇÜMÜN ADIYLA.
  locked,

  /// ⭐ Ölçülür ama puanlanmaz — "bilgi" tonu, "hata" tonu DEĞİL.
  demoOnly,
}

final class Lesson {
  const Lesson._(
    this.id,
    this.displayName,
    this.status,
    this.focus,
    this.minutes,
    this.lockedReason,
    this.demoOnlyReason,
    this.blockedBy,
    this.unblockedBy,
    this.ifBlockedStaysBlocked,
    this.showsCue,
  );

  final String id;
  final String displayName;

  /// `open` · `locked` · `demoOnly` — üçü AYRI yüzey. Kilitli ders hiçbir
  /// hüküm göstermez; demoOnly ölçüm gösterir, puan göstermez.
  final String status;

  /// `setup` · `posture` · `chords` · `pitch` · `timing` — ders içeriğinin
  /// ölçtüğü şey; `guide` sınıfının tek ayracı `focus == 'setup'` olmasıdır.
  final String focus;
  final int minutes;

  final String? lockedReason;
  final String? demoOnlyReason;

  /// `promotionPath` üçlüsü — yalnız demoOnly derslerde dolu.
  final String? blockedBy;
  final String? unblockedBy;
  final String? ifBlockedStaysBlocked;

  final bool showsCue;

  LessonKind get kind {
    if (status == 'locked') return LessonKind.locked;
    if (status == 'demoOnly') return LessonKind.demoOnly;
    if (focus == 'setup') return LessonKind.guide;
    return LessonKind.scored;
  }

  /// Kilit/demoOnly gerekçesinin İLK CÜMLESİ — kurs listesinde satır-içi
  /// gösterilir (merak tuzağı DEĞİL, bilgi taşır; §4 tasarım şartı ⑭).
  String get firstSentence {
    final String? full = lockedReason ?? demoOnlyReason;
    if (full == null || full.isEmpty) return '';
    final int i = full.indexOf('. ');
    return i == -1 ? full : full.substring(0, i + 1);
  }

  static Lesson _fromJson(Map<String, dynamic> m) {
    final Map<String, dynamic>? promo =
        m['promotionPath'] as Map<String, dynamic>?;
    return Lesson._(
      m['id'] as String,
      m['displayName'] as String,
      m['status'] as String? ?? 'open',
      m['focus'] as String? ?? '',
      m['minutes'] as int? ?? 0,
      m['lockedReason'] as String?,
      m['demoOnlyReason'] as String?,
      promo?['blockedBy'] as String?,
      promo?['unblockedBy'] as String?,
      promo?['ifItStaysBlocked'] as String?,
      (m['observationCues'] as List<dynamic>? ?? <dynamic>[]).isNotEmpty,
    );
  }
}
