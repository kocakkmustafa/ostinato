import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'ostinato_theme.dart';

/// Camsı/yarı-saydam kart — Ostinato'nun malzeme imzası (Lissom'un mat kili
/// DEĞİL). `sigma` küçük tutulur: gerçek cihazda blur ucuz değil.
class GlassCard extends StatelessWidget {
  /// Varsayılan cam gradyanı — ADLANDIRILDI ki kontrast kapısı
  /// (`test/contrast_test.dart`) onu ELLE kopyalamak zorunda kalmasın.
  /// Elle kopyalanan bir zemin, temanın rengi değişince sessizce bayatlar
  /// ve kapı ölçmediği bir pikseli ölçmeye devam eder.
  static const List<Color> defaultGradient = <Color>[
    Color(0xEBFFFFFF),
    Color(0x8FFFFFFF),
  ];

  const GlassCard({
    super.key,
    required this.child,
    this.gradientColors = defaultGradient,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
  });

  final Widget child;
  final List<Color> gradientColors;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .85)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF40305A).withValues(alpha: .16),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Dokuz-nokta üst-gövde iskeleti — tasarım panelinin SVG şeması (viewBox
/// 200×216) Flutter'a birebir taşındı. `tiltDeg`: gövde `(100,200)` etrafında
/// döner (Live ekranı). `bandLowDeg/bandHighDeg` dolu olduğunda arkada
/// eğitmen bandının kama-dilimi çizilir; `markerDeg` doluysa kesik çizgiyle
/// bir açı imlenir (eşik ya da "sen" çizgisi).
class SkeletonFigurePainter extends CustomPainter {
  const SkeletonFigurePainter({
    this.tiltDeg = 0,
    this.color = OstinatoColors.ink,
    this.bandLowDeg,
    this.bandHighDeg,
    this.bandColor,
    this.markerDeg,
    this.markerColor = const Color(0x662A2533),
    this.dim = false,
  });

  final double tiltDeg;
  final Color color;
  final double? bandLowDeg;
  final double? bandHighDeg;
  final Color? bandColor;
  final double? markerDeg;
  final Color markerColor;

  /// Kadraj-hatası hâlinde kalça noktaları soluklaşır (setup check).
  final bool dim;

  static const double _viewW = 200, _viewH = 216;
  static const Offset _hipMid = Offset(100, 200);

  Offset _angle(double deg, double radius) {
    final double r = deg * math.pi / 180;
    return Offset(100 + radius * math.sin(r), 200 - radius * math.cos(r));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewW, size.height / _viewH);

    if (bandLowDeg != null && bandHighDeg != null) {
      final Paint wedge = Paint()
        ..color = bandColor ?? const Color(0x332A2533)
        ..style = PaintingStyle.fill;
      final Path path = Path()..moveTo(_hipMid.dx, _hipMid.dy);
      final Offset p1 = _angle(bandLowDeg!, 150);
      final Offset p2 = _angle(bandHighDeg!, 150);
      path.lineTo(p1.dx, p1.dy);
      path.arcToPoint(p2, radius: const Radius.circular(150));
      path.close();
      canvas.drawPath(path, wedge);
    }

    // Dikey referans çizgisi.
    final Paint dash = Paint()
      ..color = const Color(0x282A2533)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(100, 200), const Offset(100, 60), dash);

    if (markerDeg != null) {
      final Offset m = _angle(markerDeg!, 148);
      canvas.drawLine(const Offset(100, 200), m,
          Paint()
            ..color = markerColor
            ..strokeWidth = 1.4);
    }

    canvas.translate(100, 200);
    canvas.rotate(tiltDeg * math.pi / 180);
    canvas.translate(-100, -200);

    final Paint limb = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final Paint limbFaint = Paint()
      ..color = color.withValues(alpha: .32)
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    void line(Offset a, Offset b, Paint p) => canvas.drawLine(a, b, p);
    void dot(Offset c, double r, Paint p) => canvas.drawCircle(c, r, p);

    // Kesikli çizgi — yalnız kol segmentleri için (aşağıya bkz.). Düz
    // `drawLine`dan BİLEREK farklı bir çizgi STİLİ, yalnız daha soluk bir
    // ton değil: "izleniyor" ile "izlenmiyor" arasındaki fark opaklıkla
    // karışabilir, çizgi TÜRÜyle karışmaz.
    void dashedLine(Offset a, Offset b, Paint p,
        {double dash = 3.4, double gap = 3}) {
      final double total = (b - a).distance;
      if (total == 0) return;
      final Offset dir = (b - a) / total;
      double covered = 0;
      while (covered < total) {
        final double segEnd = math.min(covered + dash, total);
        canvas.drawLine(a + dir * covered, a + dir * segEnd, p);
        covered = segEnd + gap;
      }
    }

    const Offset neck = Offset(100, 78);
    const Offset ls = Offset(72, 92), rs = Offset(128, 92);
    Offset lh = const Offset(82, 200), rh = const Offset(118, 200);
    // Dirsek/bilek noktaları — koordinatör hükmü (2026-08-06): gövde
    // ÇİZGİSİ (hipMid→neck, omuz-omuz, kalça-kalça) `tiltDeg` ile CANLI
    // döner; bu dört nokta İSE motor tarafından hiç ölçülmez, yalnız
    // gövdeyle birlikte RİJİT taşınır. Kullanıcı gövdenin canlı döndüğünü
    // görünce figürün TAMAMINI canlı okur — kollar SESSİZCE donuk kalırsa
    // bu, ailenin "yokluk kendi anlatısını taşır" kuralının ihlalidir
    // (kısmi canlılık, tam sahtelikten daha ikna edici olduğu için daha
    // tehlikelidir). Çözüm B uygulandı: kollar KESİKLİ çizilir ve
    // eklem-noktası (dot) TAŞIMAZ — dot bu figürde "bulunan gerçek
    // landmark" anlamına gelir (kalça/boyun/omuz), kollar bunu hak
    // etmiyor. Canlı dirsek-açısı ölçümü hâlâ YOK (bkz.
    // lesson_demo_screen.dart aynı sınır, `data` kaydı) — o gelirse Çözüm
    // A'ya (gerçek açıyla pozlamak) geçilir; o güne dek bu render kendi
    // yokluğunu SÖYLER, gizlemez.
    const Offset le = Offset(56, 142), re = Offset(144, 142);
    const Offset lw = Offset(76, 180), rw = Offset(124, 180);

    line(_hipMid, neck, limb);
    line(ls, rs, limb);
    line(lh, rh, limb);
    dashedLine(ls, le, limbFaint);
    dashedLine(le, lw, limbFaint);
    dashedLine(rs, re, limbFaint);
    dashedLine(re, rw, limbFaint);

    final Paint hipPaint = dim
        ? (Paint()
          ..color = color.withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6)
        : (Paint()..color = color);
    if (dim) {
      canvas.drawCircle(lh, 4.4, hipPaint);
      canvas.drawCircle(rh, 4.4, hipPaint);
    } else {
      dot(lh, 4.4, Paint()..color = color);
      dot(rh, 4.4, Paint()..color = color);
    }

    dot(neck, 4.4, Paint()..color = color);
    dot(ls, 4.4, Paint()..color = color);
    dot(rs, 4.4, Paint()..color = color);
    // Dirsek/bilek landmark NOKTASI taşımaz (bkz. yukarıdaki şerh) — bir
    // dot bu figürde "burada gerçek bir nokta bulundu" der, kollar için
    // bu doğru değil.

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SkeletonFigurePainter old) =>
      old.tiltDeg != tiltDeg ||
      old.color != color ||
      old.markerDeg != markerDeg ||
      old.dim != dim;
}

/// Yatay bant şeridi — Live ekranının alt izleyicisi (eğitmen aralığı + "sen"
/// imleyicisi). Sayı değil KONUM gösterir; puanlamaz.
class HorizontalBandTrack extends StatelessWidget {
  const HorizontalBandTrack({
    super.key,
    required this.lowDeg,
    required this.highDeg,
    required this.maxDeg,
    this.youDeg,
    required this.color,
    this.height = 12,
  });

  final double lowDeg;
  final double highDeg;
  final double maxDeg;
  /// "Sen" imleyicisi — NULL olabilir. Kütüphane kartında canlı bir ölçüm
  /// YOKTUR; oraya bir imleyici çizmek, olmayan bir ölçümü ima ederdi.
  final double? youDeg;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints c) {
      double x(double deg) => (deg.clamp(0, maxDeg) / maxDeg) * c.maxWidth;
      return SizedBox(
        height: height,
        child: Stack(children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white.withValues(alpha: .9)),
              ),
            ),
          ),
          Positioned(
            left: x(lowDeg),
            top: 0,
            bottom: 0,
            width: (x(highDeg) - x(lowDeg)).clamp(2, c.maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
          if (youDeg != null)
            Positioned(
              key: const Key('you-marker'),
              left: (x(youDeg!) - 1.5).clamp(0, c.maxWidth - 3),
              top: -4,
              bottom: -4,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: OstinatoColors.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

/// Original 38px glass visual inside a 48px native button target.
/// IconButton retains keyboard focus and one accessible action.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton(
      {super.key, required this.icon, required this.onTap, this.semanticLabel});
  final String icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? icon;
    return SizedBox(
      width: 48,
      height: 48,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: IconButton(
          onPressed: onTap,
          iconSize: 38,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.standard,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
            maximumSize: WidgetStatePropertyAll(Size(48, 48)),
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          // IconButton owns the single tap/focus/disabled semantics action.
          // Only its label is contributed here; the glyph is decorative.
          icon: Semantics(
            label: label,
            excludeSemantics: true,
            child: SizedBox(
              width: 38,
              height: 38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: hankenText(
                      size: 17,
                      color: OstinatoColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Birincil eylem düğmesi — koyu, tam-genişlik.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key, required this.label, required this.onPressed, this.dim = false});
  final String label;
  final VoidCallback? onPressed;
  final bool dim;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor:
                dim ? const Color(0x1A2A2533) : OstinatoColors.ink,
            foregroundColor: dim ? OstinatoColors.textFaint : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17)),
          ),
          child: Text(label, style: hankenText(size: 16, weight: FontWeight.w500,
              color: dim ? OstinatoColors.textFaint : Colors.white)),
        ),
      );
}
