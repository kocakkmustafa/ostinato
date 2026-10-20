import 'package:flutter/material.dart';

import '../content.dart';
import '../app_locale.dart';
import '../catalog_copy_tr.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';

/// Historical teacher-reference notes. This page has no camera input and
/// displays neither a body measurement nor a posture assessment.
class LessonDemoScreenRoute extends StatelessWidget {
  const LessonDemoScreenRoute(
      {super.key, required this.discipline, required this.lesson, required this.hue});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) {
    final ArmRangeHint? arm = ArmRangeHints.byDiscipline[discipline.id];
    return Scaffold(
      backgroundColor: OstinatoColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GlassIconButton(
                  icon: '‹',
                  semanticLabel: localized(context, 'Back', 'Geri'),
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: hue.chip, borderRadius: BorderRadius.circular(8)),
                child: Text(localized(context, 'REFERENCE · NO SCORING', 'REFERANS · PUAN YOK'),
                    key: const Key('state-lesson-demo'),
                    style: monoText(color: hue.ink)),
              ),
              const SizedBox(height: 13),
              Text(catalogName(context, lesson.id, lesson.displayName),
                  style: hankenText(
                      size: 27, weight: FontWeight.w600, height: 1.15)),
              const SizedBox(height: 11),
              Text('${lesson.minutes} ${localized(context, 'MIN', 'DK')} · ${catalogUpperName(context, discipline.id, discipline.displayName)}',
                  style: monoText()),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: hue.gradient,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: .85)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker(localized(context, 'Recorded teacher reference range',
                        'Kaydedilmiş eğitmen referansı aralığı'), color: hue.ink),
                    const SizedBox(height: 14),
                    if (arm != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            height: 34,
                            child: HorizontalBandTrack(
                              lowDeg: arm.lowDeg,
                              highDeg: arm.highDeg,
                              maxDeg: 120,
                              color: hue.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('0°', style: monoText(size: 9)),
                              Text(
                                  '${arm.lowDeg.toStringAsFixed(0)}–'
                                  '${arm.highDeg.toStringAsFixed(0)}°',
                                  style: monoText(size: 9)),
                              Text('120°', style: monoText(size: 9)),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Text(catalogCopy(context, '${lesson.id}.demoOnlyReason',
                            lesson.demoOnlyReason ?? ''),
                        key: const Key('demo-reason'),
                        style: hankenText(size: 15, height: 1.6)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker(localized(context, 'Why this is not a target',
                        'Bu aralık neden hedef değil')),
                    const SizedBox(height: 8),
                    Text(catalogCopy(context, '${lesson.id}.blockedBy',
                            lesson.blockedBy ?? ''),
                        style: hankenText(size: 13.5, height: 1.55)),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    kicker(localized(context, 'What research would be needed',
                        'Hangi araştırma gerekir')),
                    const SizedBox(height: 8),
                    Text(catalogCopy(context, '${lesson.id}.unblockedBy',
                            lesson.unblockedBy ?? ''),
                        style: hankenText(size: 13.5, height: 1.55)),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    kicker(localized(context, 'What this page offers',
                        'Bu sayfa ne sunuyor')),
                    const SizedBox(height: 8),
                    Text(catalogCopy(context, '${lesson.id}.ifItStaysBlocked',
                            lesson.ifBlockedStaysBlocked ?? ''),
                        style: hankenText(size: 13.5, height: 1.55)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x0D2A2533),
                  borderRadius: BorderRadius.circular(16),
                ),
                // PLACEHOLDER(data): yalnız statik kayıtlı referans aralığı.
                // Kamera kapalıdır; kullanıcıya ait ölçüm veya imleyici yoktur.
                // closedPaths: none-known
                // user-surface: demo-live-gap-note
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.info_outline,
                        size: 18, color: OstinatoColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        localized(
                          context,
                          'Camera assessment is disabled in this release. No live trunk or elbow angle is measured or displayed here. The range above comes from recorded references.',
                          'Bu sürümde kamera değerlendirmesi kapalıdır. Burada canlı gövde veya dirsek açısı ölçülmez ve gösterilmez. Yukarıdaki aralık kayıtlı referanslardan gelir.',
                        ),
                        key: const Key('demo-live-gap-note'),
                        style: hankenText(
                            size: 12.5, color: OstinatoColors.textMuted),
                      ),
                    ),
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
