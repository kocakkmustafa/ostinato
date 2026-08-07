import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import '../content.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'course_screen.dart';

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
                        semanticLabel: 'Back to library',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 22),
                      Text(discipline.displayName,
                          style: hankenText(
                              size: 30,
                              weight: FontWeight.w600,
                              color: OstinatoColors.inkSoft)),
                      const SizedBox(height: 9),
                      if (contract != null)
                        Text(
                          '${contract.teacherCount} TEACHERS · AGREE TO '
                          '${contract.dispersionMedianDeg.toStringAsFixed(2)}°',
                          style: monoText(color: hue.ink),
                        ),
                      const SizedBox(height: 14),
                      Text(discipline.blurb,
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
                          Text('What we actually measure',
                              style: hankenText(
                                  size: 18, weight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                              'And what we deliberately do not. Both halves '
                              'are the product.',
                              style: hankenText(
                                  size: 13, color: OstinatoColors.textMuted)),
                          const SizedBox(height: 16),
                          kicker('Measured', color: hue.ink),
                          const SizedBox(height: 10),
                          for (final String m in discipline.measured)
                            _HonestyRow(text: m, filled: true),
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
                          kicker('What we do not judge — and why'),
                          const SizedBox(height: 8),
                          Text(
                            'These are not all the same kind of gap. Some '
                            'need a tool we do not have, some need teacher '
                            'data nobody has collected, some are simply not '
                            'built here, and at least one is not a data '
                            'problem at all — it is a judgement we do not '
                            'think is ours to make. Each line says which.',
                            key: const Key('not-measured-frame'),
                            style: hankenText(
                                size: 12,
                                height: 1.5,
                                color: OstinatoColors.textMuted),
                          ),
                          const SizedBox(height: 10),
                          for (final String m in discipline.notMeasured)
                            _HonestyRow(text: m, filled: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    kicker('Courses'),
                    const SizedBox(height: 10),
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
                                        child: Text(c.displayName,
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
                                      '${c.level.toUpperCase()} · '
                                      '${c.estimatedMinutes} MIN · '
                                      '${c.lessons.length} LESSONS',
                                      style: monoText(color: hue.ink)),
                                  const SizedBox(height: 11),
                                  Text(c.goal,
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
                      kicker('Not here — and why'),
                      const SizedBox(height: 10),
                      for (final String c in <String>[
                        ...discipline.comingSoon,
                        // TÜRETİLEN kalemler elle yazılanlardan SONRA gelir:
                        // ikisi ayrı sınıf ama kullanıcı için aynı soru
                        // ("burada ne yok ve neden"), o yüzden tek başlık
                        // altında tek liste — ayrım KAYITTA, yüzeyde bir
                        // ayraç gürültüsü değil.
                        ...discipline.outOfScopeDerived,
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
                          child: Text(c,
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
