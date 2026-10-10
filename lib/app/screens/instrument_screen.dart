import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import '../content.dart';
import '../app_locale.dart';
import '../catalog_copy_tr.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'course_screen.dart';
import 'guitar_journey_screen.dart';
import 'piano_beginner_screen.dart';

/// Çalgı sayfası — dürüstlük kutusu ürünün vitrini (§7). Tam genişlik,
/// kurs listesinin ÜSTÜNDE, katlanabilir DEĞİL.
class InstrumentScreenRoute extends StatelessWidget {
  const InstrumentScreenRoute({super.key, required this.discipline});
  final Discipline discipline;

  @override
  Widget build(BuildContext context) {
    final InstrumentHue hue = InstrumentHues.of(discipline.id);
    final PostureContract? contract =
        ContentRepositoryScope.of(context).contractOrNull(discipline.id);

    return Scaffold(
      backgroundColor: OstinatoColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(gradient: hue.gradient),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      GlassIconButton(
                        icon: '‹',
                        semanticLabel: localized(context, 'Back to library', 'Kütüphaneye dön'),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 22),
                      Text(catalogName(context, discipline.id, discipline.displayName),
                          style: hankenText(
                              size: 30,
                              weight: FontWeight.w600,
                              color: OstinatoColors.inkSoft)),
                      const SizedBox(height: 9),
                      if (contract != null)
                        Text(
                          localized(
                            context,
                            '${contract.teacherCount} TEACHERS · AGREE TO '
                                '${contract.dispersionMedianDeg.toStringAsFixed(2)}°',
                            '${contract.teacherCount} '
                                '${catalogSourceClass(context, contract.sourceClass)} · '
                                '${contract.dispersionMedianDeg.toStringAsFixed(2)}° UYUM',
                          ),
                          style: monoText(color: hue.ink),
                        ),
                      const SizedBox(height: 14),
                      Text(catalogBlurb(context, discipline.id, discipline.blurb),
                          style: hankenText(
                              size: 14.5,
                              color: OstinatoColors.inkSoft.withValues(alpha: .85))),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(localized(context, 'Posture reference notes', 'Duruş referansı notları'),
                              style: hankenText(
                                  size: 18, weight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                              localized(context, 'Written courses support self-guided practice. Camera assessment '
                                  'and posture scoring are unavailable in this version.',
                                  'Yazılı kurslar öz denetimli çalışmayı destekler. Bu sürümde '
                                  'kamera değerlendirmesi ve duruş puanlaması kapalı.'),
                              style: hankenText(
                                  size: 13, color: OstinatoColors.textMuted)),
                          const SizedBox(height: 16),
                          kicker(localized(context, 'Recorded references', 'Kayıtlı referanslar'), color: hue.ink),
                          const SizedBox(height: 10),
                          _HonestyRow(
                              text: localized(context,
                                  'Recorded teaching examples provide posture references. '
                                  'They are not a measurement of your practice.',
                                  'Kaydedilmiş eğitim örnekleri duruş referansı sunar. '
                                  'Bunlar senin çalışmanın ölçümü değildir.'),
                              filled: true),
                          const SizedBox(height: 6),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          // ÇERÇEVE DÜZELTİLDİ (O-069 · JabLab J-153).
                          // Başlık "Not measured" idi ve TEK bir sebep ilan
                          // ediyordu: "ölçmeye çalıştık, olmadı" — yani
                          // TEKNİK KISIT. Teknik kısıt örtük bir VAAT taşır
                          // ("daha iyi teknoloji çözer"); kasıtlı bir karar
                          // taşımaz. Ölçüldü: bu listedeki 27 sınır EN AZ
                          // DÖRT ayrı sınıftan — alet yok · kabuk eksik ·
                          // referans yok · KARAR bize ait değil. Hiçbir
                          // cümle yalan söylemiyordu; kusur CÜMLE düzeyinde
                          // görünmüyordu, çünkü çerçeve KÜMENİN KENDİSİ
                          // hakkında bir iddiaydı ve hiçbir öğesinde yazılı
                          // değildi.
                          kicker(localized(context, 'What we do not judge — and why', 'Neyi değerlendirmiyoruz ve neden')),
                          const SizedBox(height: 8),
                          Text(
                            localized(
                              context,
                              'These are not all the same kind of gap. Some '
                                  'need a tool we do not have, some need teacher '
                                  'data nobody has collected, some are simply not '
                                  'built here, and at least one is not a data '
                                  'problem at all — it is a judgement we do not '
                                  'think is ours to make. Each line says which.',
                              'Bu sınırların nedenleri farklıdır: eksik araç, '
                                  'toplanmamış eğitmen verisi, burada kurulmayan '
                                  'özellikler veya bize ait olmayan bir değerlendirme. '
                                  'Her satır kendi nedenini açıklar.',
                            ),
                            key: const Key('not-measured-frame'),
                            style: hankenText(
                                size: 12,
                                height: 1.5,
                                color: OstinatoColors.textMuted),
                          ),
                          const SizedBox(height: 10),
                          for (var i = 0; i < discipline.notMeasured.length; i++)
                            _HonestyRow(
                                text: catalogCopy(context,
                                    '${discipline.id}.notMeasured.$i',
                                    discipline.notMeasured[i]),
                                filled: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    kicker(localized(context, 'Courses', 'Kurslar')),
                    const SizedBox(height: 10),
                    if (discipline.id == 'piano')
                      ListTile(
                        key: const Key('piano-beginner-entry'),
                        title: Text(localized(context, 'Piano / keyboard: written beginner course', 'Piyano / klavye: yazılı başlangıç kursu')),
                        subtitle: Text(localized(context, '16 original lessons · self-observation', '16 özgün ders · öz gözlem')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PianoBeginnerScreen())),
                      ),
                    if (discipline.id == 'guitar') ...<Widget>[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('guitar-journey-entry'),
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GuitarJourneyScreen(),
                            ),
                          ),
                          child: Ink(
                            padding: const EdgeInsets.all(17),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: hue.softGradient,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .8),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        localized(
                                          context,
                                          'Guitar: first sound to independent playing',
                                          'Gitar: ilk sesten bağımsız çalmaya',
                                        ),
                                        style: hankenText(
                                          size: 19,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: OstinatoColors.textFaint,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  localized(
                                    context,
                                    '10 MODULES · 60 LESSONS · SELF-GUIDED',
                                    '10 MODÜL · 60 DERS · KENDİ ÇALIŞMAN',
                                  ),
                                  style: monoText(color: hue.ink),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  localized(
                                    context,
                                    'A complete original learning path with practice and two final performances. Progress is your own report; automatic note scoring is off.',
                                    'Çalışmalar ve iki bitirme performansıyla tam özgün öğrenme yolu. İlerleme kendi beyanındır; otomatik nota puanı kapalıdır.',
                                  ),
                                  style: hankenText(
                                    size: 13.5,
                                    color: OstinatoColors.textBody,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final Course c in discipline.courses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => CourseScreenRoute(
                                        discipline: discipline, course: c))),
                            child: Ink(
                              padding: const EdgeInsets.all(17),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: hue.softGradient,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .8)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      // Bugün "Foundations" (kısa) ama sabit
                                      // genişlikli chevron'un yanında Expanded
                                      // olmadan aynı taşma sınıfı bekliyor
                                      // (bkz. live_screen.dart başlık düzeltmesi).
                                      Expanded(
                                        child: Text(catalogName(context, c.id, c.displayName),
                                            style: hankenText(
                                                size: 19,
                                                weight: FontWeight.w600)),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: OstinatoColors.textFaint),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                      '${catalogTag(context, c.level)} · '
                                      '${c.estimatedMinutes} ${localized(context, 'MIN', 'DK')} · '
                                      '${c.lessons.length} ${localized(context, 'LESSONS', 'DERS')}',
                                      style: monoText(color: hue.ink)),
                                  const SizedBox(height: 11),
                                  Text(catalogGoal(context, c.id, c.goal),
                                      style: hankenText(
                                          size: 13.5,
                                          color: OstinatoColors.textBody)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (discipline.comingSoon.isNotEmpty ||
                        discipline.outOfScopeDerived.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      // DÜZELTME (koordinatör, 2026-08-07, M-F-186): "yet"
                      // çıkarıldı. Bu başlığın altındaki liste KAPSAM-DIŞI
                      // kalemler (`comingSoon`) — kapsam-dışı bir şey için
                      // "henüz" demek, gelmeyecek olana geleceğini vaat
                      // etmek olurdu.
                      kicker(localized(context, 'Not here — and why',
                          'Burada bulunmayanlar ve nedenleri')),
                      const SizedBox(height: 10),
                      for (final entry in <MapEntry<String, String>>[
                        for (var i = 0; i < discipline.comingSoon.length; i++)
                          MapEntry('${discipline.id}.comingSoon.$i',
                              discipline.comingSoon[i]),
                        // TÜRETİLEN kalemler elle yazılanlardan SONRA gelir:
                        // ikisi ayrı sınıf ama kullanıcı için aynı soru
                        // ("burada ne yok ve neden"), o yüzden tek başlık
                        // altında tek liste — ayrım KAYITTA, yüzeyde bir
                        // ayraç gürültüsü değil.
                        for (var i = 0; i < discipline.outOfScopeDerived.length; i++)
                          MapEntry('${discipline.id}.outOfScopeDerived.$i',
                              discipline.outOfScopeDerived[i]),
                      ])
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .65)),
                          ),
                          child: Text(catalogCopy(context, entry.key,
                                  entry.value),
                              style: hankenText(
                                  size: 13, color: OstinatoColors.textMuted)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HonestyRow extends StatelessWidget {
  const _HonestyRow({required this.text, required this.filled});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: filled
                  ? const _Dot(filled: true)
                  : const _Dot(filled: false),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: hankenText(
                        size: 13.5,
                        height: 1.5,
                        color: filled
                            ? OstinatoColors.inkSoft
                            : const Color(0xFF5C5569)))),
          ],
        ),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled});
  final bool filled;
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? OstinatoColors.ink : Colors.transparent,
          border: filled
              ? null
              : Border.all(color: const Color(0x572A2533), width: 1.5),
        ),
      );
}
