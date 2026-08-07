import 'package:flutter/material.dart';

import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';

/// Bir oturumun ÖLÇÜLMÜŞ özeti — Live ekranından taşınır, İCAT EDİLMEZ.
/// `verdict`in "steady/improving/needs_focus" üçlüsü g4-prep ruleset'in
/// `scoreDisplay.bandsUntilCalibration` ile AYNI sözcükler (K8/M-F-04).
final class SessionSummary {
  const SessionSummary({
    required this.elapsedSeconds,
    required this.sampleCount,
    required this.outCount,
    required this.history,
  });

  final int elapsedSeconds;
  final int sampleCount;
  final int outCount;
  final List<double> history;

  double get insideShare =>
      sampleCount == 0 ? 1 : 1 - outCount / sampleCount;

  /// Sunum-katmanı özeti — ÖLÇÜM eşiği değil, ekranda üç betimleyici
  /// arasında seçim yapan bir kural. Değerler (0.66 / 0.6°) tasarım
  /// panelinin kendi seçimiyle AYNI.
  ///
  /// KARAR (koordinatör, 2026-08-06, HÜKÜM 2b): üçüncü kelime önce
  /// "Needs focus." idi — TÜRETİLMEMİŞ bir kesme noktasının kullanıcıya
  /// HÜKÜM CÜMLESİ üretmesiydi ve ailenin ton kuralını ("öğretmen gibi,
  /// hakem gibi değil") ihlal ediyordu: "Steady." ÖLÇÜLEN OLGUYU betimler
  /// (kabul edildi), "Needs focus." KİŞİYİ yargılar (hakem dili). Eşik
  /// KALDI (üç betimleyici arasında seçim yapan sunum kuralı olarak), yalnız
  /// kelime OLGUYA döndü: bandın DIŞINDA geçirilen süre, kullanıcının neye
  /// "ihtiyacı" olduğuna dair bir hüküm DEĞİL.
  String get verdict {
    if (insideShare > 0.66) return 'Steady.';
    if (_improving()) return 'Improving.';
    return 'Mostly outside the band.';
  }

  bool _improving() {
    if (history.length <= 8) return false;
    final int half = history.length ~/ 2;
    double avg(List<double> a) => a.isEmpty
        ? 0
        : a.map((double v) => v.abs()).reduce((double x, double y) => x + y) /
            a.length;
    return avg(history.sublist(half)) < avg(history.sublist(0, half)) - 0.6;
  }
}

/// Başlıktaki sayıyı yazıyla verir. Rakama düşmek ("4 things") bu ekranın
/// geri kalanının tonundan kopardı; sınır isimli: on üstü rakama düşer,
/// çünkü bugünkü liste hiçbir çalgıda dörtten fazla olamaz ve olursa bu
/// fonksiyon uydurmak yerine rakam gösterir.
String _countWord(int n) => const <int, String>{
      1: 'One', 2: 'Two', 3: 'Three', 4: 'Four',
      5: 'Five', 6: 'Six', 7: 'Seven', 8: 'Eight', 9: 'Nine', 10: 'Ten',
    }[n] ?? '$n';

/// Özet — "neyi ölçemedik" ZORUNLU ve EŞİT AĞIRLIKLI (§6/⑫).
class ReviewScreenRoute extends StatelessWidget {
  const ReviewScreenRoute({
    super.key,
    required this.discipline,
    required this.lesson,
    required this.hue,
    required this.summary,
  });

  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final int secs = summary.elapsedSeconds < 1 ? 1 : summary.elapsedSeconds;
    final List<String> gaps = <String>[
      'Landmark confidence below the bar. Any window like that is not '
          'counted, not scored as zero.',
      'Anything outside what this lesson measures — trunk alignment only; '
          'no other joint carries a verdict here.',
      "Your arms. If shown live elsewhere, they are measured and never "
          "marked — the teachers we recorded disagree by too much to call "
          "a difference an error.",
      // 4. kalem ÇALGIYA ÖZEL ve VERİDEN gelir (DESIGN-AHEAD-OF-CODE §2.1'in
      // eksik maddesi). Burada elle yazılsaydı üç çalgı için üç `if` olurdu
      // ve dördüncü çalgı eklendiğinde sessizce eksik kalırdı.
      if (discipline.instrumentSpecificGap.isNotEmpty)
        discipline.instrumentSpecificGap,
    ];

    return Scaffold(
      backgroundColor: OstinatoColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  GlassIconButton(
                      icon: '✕',
                      semanticLabel: 'Done',
                      onTap: () =>
                          Navigator.of(context).popUntil((Route<void> r) => r.isFirst)),
                  kicker('Summary'),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 18),
              Text(lesson.displayName,
                  style: hankenText(
                      size: 27, weight: FontWeight.w600, height: 1.15)),
              const SizedBox(height: 10),
              Text(
                  '$secs S MEASURED · ${discipline.displayName.toUpperCase()} · '
                  'NO SCORE',
                  style: monoText()),
              const SizedBox(height: 18),
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
                    kicker('What we measured', color: hue.ink),
                    const SizedBox(height: 6),
                    Text(summary.verdict,
                        key: const Key('review-verdict'),
                        style: hankenText(size: 25, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                        height: 60,
                        child: CustomPaint(
                            painter: _CurvePainter(history: summary.history))),
                    const SizedBox(height: 12),
                    Text(
                      'Your trunk stayed inside the teachers’ band for '
                      '${(summary.insideShare * 100).round()}% of the $secs '
                      'seconds we could read it. That is the whole of it: '
                      'share of time inside the band, and the shape of the '
                      'line above. No weighting, no composite, nothing '
                      'hidden behind a single figure.',
                      style: hankenText(size: 13.5, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker('What we could not measure'),
                    const SizedBox(height: 6),
                    // Sayı LİSTEDEN türer. Elle yazılıydı ('Three things')
                    // ve tam altındaki liste de elle yazılıydı: dördüncü
                    // kalem eklenince başlık SESSİZCE bayatlardı — O-029'un
                    // ("vitrin korumasızdı") canlı-yüzey hâli, kullanıcıya
                    // görünen bir sayının saydığı şeye bağlı OLMAMASI.
                    Text('${_countWord(gaps.length)} things, by name.',
                        key: const Key('review-gap-headline'),
                        style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            color: OstinatoColors.ink)),
                    const SizedBox(height: 14),
                    for (final String g in gaps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(g,
                            style: hankenText(
                                size: 13.5,
                                height: 1.55,
                                color: OstinatoColors.inkSoft)),
                      ),
                    Text(
                      'This half is not a disclaimer. It is the same size '
                      'as the half above because it carries the same '
                      'weight.',
                      style: hankenText(size: 12.5, color: OstinatoColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: .75)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker('One thing next'),
                    const SizedBox(height: 8),
                    Text(
                      'Next time, sit a little further from the phone so '
                      'both hips stay in frame the whole way through.',
                      style: hankenText(size: 17.5, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text('One suggestion, not a list.',
                        style: hankenText(
                            size: 12.5, color: OstinatoColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x0D2A2533),
                  borderRadius: BorderRadius.circular(16),
                ),
                // DÜZELTME (koordinatör, 2026-08-06, M-F-186): "yet"
                // çıkarıldı — bir zaman taahhüdüydü. Kalan cümle bugünün
                // OLGUSUNU söylüyor, gelecek vaat etmiyor.
                child: Text(
                  'Sharing a skeleton-render report is not wired in this '
                  'build. Raw video never leaves this device either way — '
                  'there is simply no report to send.',
                  key: const Key('review-sharing-gap-note'),
                  style: hankenText(size: 12.5, color: OstinatoColors.textMuted),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () =>
                    Navigator.of(context).popUntil((Route<void> r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  const _CurvePainter({required this.history});
  final List<double> history;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> h = history.isEmpty ? const <double>[3, 3.4, 3.1] : history;
    final double maxAbs = h.map((double v) => v.abs()).fold(1.0, (double a, double b) => a > b ? a : b);
    final Path path = Path();
    for (int i = 0; i < h.length; i++) {
      final double x = h.length <= 1 ? 0 : (i / (h.length - 1)) * size.width;
      final double y = size.height -
          (h[i].abs() / (maxAbs < 1 ? 1 : maxAbs)).clamp(0, 1) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = OstinatoColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => old.history != history;
}
