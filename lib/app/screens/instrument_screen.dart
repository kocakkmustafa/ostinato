import '../app_theme.dart';
import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import '../content.dart';
import '../app_locale.dart';
import '../catalog_copy_tr.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../ostinato_release_policy.dart';
import 'course_screen.dart';
import 'feedback_availability.dart';
import 'guitar_journey_screen.dart';
import 'piano_beginner_screen.dart';
import 'v1_home_copy.dart';
import '../ui_copy.dart';

/// Çalgı sayfası — dürüstlük kutusu ürünün vitrini (§7). Tam genişlik,
/// kurs listesinin ÜSTÜNDE, katlanabilir DEĞİL.
class InstrumentScreenRoute extends StatelessWidget {
  const InstrumentScreenRoute({super.key, required this.discipline});
  final Discipline discipline;

  @override
  Widget build(BuildContext context) {
    final InstrumentHue hue = OstinatoPalette.of(
      context,
    ).instrument(discipline.id);
    final PostureContract? contract = ContentRepositoryScope.of(
      context,
    ).contractOrNull(discipline.id);

    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).surface,
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
                        semanticLabel: localized(
                          context,
                          'Back to library',
                          'Kütüphaneye dön',
                        ),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        catalogName(
                          context,
                          discipline.id,
                          discipline.displayName,
                        ),
                        style: hankenText(
                          size: 30,
                          weight: FontWeight.w600,
                          color: OstinatoPalette.of(context).inkSoft,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (contract != null)
                        Text(
                          localized(
                            context,
                            "{v0} {v1} · AGREE TO {v2}°",
                            "{v0} {v1} · {v2}° UYUM",
                            values: {
                              "v0": contract.teacherCount,
                              "v1": catalogSourceClass(
                                context,
                                contract.sourceClass,
                              ),
                              "v2": AppDecimal(contract.dispersionMedianDeg, 2),
                            },
                          ),
                          style: monoText(color: hue.ink),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        catalogBlurb(context, discipline.id, discipline.blurb),
                        style: hankenText(
                          size: 14.5,
                          color: OstinatoPalette.of(
                            context,
                          ).inkSoft.withValues(alpha: .85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FeedbackAvailability(instrumentId: discipline.id),
                    if (discipline.id == 'guitar') ...<Widget>[
                      const MeasuredPracticeCard(),
                      const SizedBox(height: 14),
                    ],
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            localized(
                              context,
                              'Posture reference notes',
                              'Duruş referansı notları',
                            ),
                            style: hankenText(
                              size: 18,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            localized(
                              context,
                              'Written courses support self-guided practice. Camera assessment '
                                  'and posture scoring are unavailable in this version.',
                              'Yazılı kurslar öz denetimli çalışmayı destekler. Bu sürümde '
                                  'kamera değerlendirmesi ve duruş puanlaması kapalı.',
                            ),
                            style: hankenText(
                              size: 13,
                              color: OstinatoPalette.of(context).textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          kicker(
                            localized(
                              context,
                              'Recorded references',
                              'Kayıtlı referanslar',
                            ),
                            color: hue.ink,
                          ),
                          const SizedBox(height: 10),
                          _HonestyRow(
                            text: localized(
                              context,
                              'These notes describe historical posture references. '
                                  'Playable teaching demonstrations are not included.',
                              'Bu notlar tarihsel duruş referanslarını açıklar. '
                                  'Oynatılabilir öğretim gösterimleri eklenmedi.',
                            ),
                            filled: true,
                          ),
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
                          kicker(
                            localized(
                              context,
                              'What we do not judge — and why',
                              'Neyi değerlendirmiyoruz ve neden',
                            ),
                          ),
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
                              color: OstinatoPalette.of(context).textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (
                            var i = 0;
                            i < discipline.notMeasured.length;
                            i++
                          )
                            _HonestyRow(
                              text: catalogCopy(
                                context,
                                '${discipline.id}.notMeasured.$i',
                                discipline.notMeasured[i],
                              ),
                              filled: false,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    kicker(localized(context, 'Courses', 'Kurslar')),
                    const SizedBox(height: 10),
                    if (discipline.id == 'piano' &&
                        ostinatoLegacyWrittenCoursesVisible)
                      ListTile(
                        key: const Key('piano-beginner-entry'),
                        title: Text(
                          localized(
                            context,
                            'Piano / keyboard: written beginner course',
                            'Piyano / klavye: yazılı başlangıç kursu',
                          ),
                        ),
                        subtitle: Text(
                          localized(
                            context,
                            '16 original lessons · self-observation',
                            '16 özgün ders · öz gözlem',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PianoBeginnerScreen(),
                          ),
                        ),
                      ),
                    // v1: the v1 course opens from the measured-practice card
                    // above; the pre-v1 60-lesson journey is not linked. The
                    // note tool that lived on the journey page moves here.
                    if (discipline.id == 'guitar' &&
                        !ostinatoLegacyWrittenCoursesVisible) ...<Widget>[
                      const NoteObservationCard(),
                      const SizedBox(height: 10),
                    ],
                    if (discipline.id == 'guitar' &&
                        ostinatoLegacyWrittenCoursesVisible) ...<Widget>[
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
                                color: OstinatoPalette.of(
                                  context,
                                ).controlSurface,
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
                                    Icon(
                                      Icons.chevron_right,
                                      color: OstinatoPalette.of(
                                        context,
                                      ).textFaint,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  uiText(context, V1HomeCopy.writtenLabel),
                                  style: monoText(color: hue.ink),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  uiText(context, V1HomeCopy.writtenBody),
                                  style: hankenText(
                                    size: 13.5,
                                    color: OstinatoPalette.of(context).textBody,
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
                                  discipline: discipline,
                                  course: c,
                                ),
                              ),
                            ),
                            child: Ink(
                              padding: const EdgeInsets.all(17),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: hue.softGradient,
                                border: Border.all(
                                  color: OstinatoPalette.of(
                                    context,
                                  ).controlSurface,
                                ),
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
                                        child: Text(
                                          catalogName(
                                            context,
                                            c.id,
                                            c.displayName,
                                          ),
                                          style: hankenText(
                                            size: 19,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: OstinatoPalette.of(
                                          context,
                                        ).textFaint,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    courseMetadata(
                                      context,
                                      c.level,
                                      c.estimatedMinutes,
                                      c.lessons.length,
                                    ),
                                    style: monoText(color: hue.ink),
                                  ),
                                  const SizedBox(height: 11),
                                  Text(
                                    catalogGoal(context, c.id, c.goal),
                                    style: hankenText(
                                      size: 13.5,
                                      color: OstinatoPalette.of(
                                        context,
                                      ).textBody,
                                    ),
                                  ),
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
                      kicker(
                        localized(
                          context,
                          'Not here — and why',
                          'Burada bulunmayanlar ve nedenleri',
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final entry in <MapEntry<String, String>>[
                        for (var i = 0; i < discipline.comingSoon.length; i++)
                          MapEntry(
                            '${discipline.id}.comingSoon.$i',
                            discipline.comingSoon[i],
                          ),
                        // TÜRETİLEN kalemler elle yazılanlardan SONRA gelir:
                        // ikisi ayrı sınıf ama kullanıcı için aynı soru
                        // ("burada ne yok ve neden"), o yüzden tek başlık
                        // altında tek liste — ayrım KAYITTA, yüzeyde bir
                        // ayraç gürültüsü değil.
                        for (
                          var i = 0;
                          i < discipline.outOfScopeDerived.length;
                          i++
                        )
                          MapEntry(
                            '${discipline.id}.outOfScopeDerived.$i',
                            discipline.outOfScopeDerived[i],
                          ),
                      ])
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: OstinatoPalette.of(context).controlSurface,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: OstinatoPalette.of(context).controlSurface,
                            ),
                          ),
                          child: Text(
                            catalogCopy(context, entry.key, entry.value),
                            style: hankenText(
                              size: 13,
                              color: OstinatoPalette.of(context).textMuted,
                            ),
                          ),
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
          child: filled ? const _Dot(filled: true) : const _Dot(filled: false),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: hankenText(
              size: 13.5,
              height: 1.5,
              color: filled
                  ? OstinatoPalette.of(context).inkSoft
                  : OstinatoPalette.of(context).textMuted,
            ),
          ),
        ),
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
      color: filled ? OstinatoPalette.of(context).ink : Colors.transparent,
      border: filled
          ? null
          : Border.all(color: OstinatoPalette.of(context).outline, width: 1.5),
    ),
  );
}
