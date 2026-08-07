import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/design/widgets.dart';

/// Kontrast kapısı — O-048 (JabLab J-114 aktarımı).
///
/// **Neden var.** Ölçüldü (2026-08-07): `WCAG`/`contrastRatio` bu ağaçta
/// yalnız `docs/design/UI-BRIEF.md` ve `DESIGN-PANEL-PROMPT.md` içinde
/// geçiyordu — yani **brief kontrastı İSTİYOR, kod ölçmüyordu.** Bu, aynı
/// gecenin O-040'ının görsel eksendeki hâli: *bir şeyin belgede yazılı
/// olması, üründe karşılığı olduğunu kanıtlamaz.*
///
/// JabLab'ın bulduğu kusur (`1.80:1` bir dürüst-hâl ikonu) bir cümleyle
/// özetlendi ve bu dosyanın gerekçesi odur:
/// ***"Görünmeyen bir dürüst hâl, susmakla aynı şeydir."***
///
/// **İki yöntem notu, ikisi de burada uygulanıyor:**
///
/// ① **Kontrast, ekranda GERÇEKTEN oluşan renkten hesaplanır.** Yarı saydam
///    bir rengin kendi parlaklığını ölçmek, ölçülmeyen bir pikseli ölçmektir.
///    Ostinato'da bu özellikle kritik: tema dili camsı çok-renkli gradyan,
///    neredeyse her yüzey alfa ile çiziliyor. Burada alfa zemine BİNDİRİLİYOR
///    ([over]).
/// ② **Zemin sabit değil.** Gradyanın en açık ve en koyu ucunda iki ayrı sayı
///    çıkar; kapı **en kötü noktadan** ölçer ([worst]).
///
/// **Eşik icat DEĞİL:** WCAG 2.2 dış bir standart. 1.4.3 küçük metin için
/// 4.5:1, 1.4.11 metin-dışı için 3.0:1. Formül standardın kendisi.
///
/// ⚠️ **Kapının SINIRI, isimli:** WCAG *"iki renk ayırt edilebilir mi"*
/// sorusunu ölçmez, **luminans** ölçer. Bu kapı GÖRÜNÜRLÜĞÜ kapatır,
/// AYIRT EDİLEBİLİRLİĞİ değil — iki farklı ton aynı luminansta olup ikisi de
/// eşiği geçebilir ve yine de birbirinden ayrılmayabilir. O ayrı bir soru ve
/// bu dosya onu çözdüğünü İDDİA ETMİYOR.
void main() {
  // ── WCAG 2.2, göreli luminans (formülün kendisi standarttan).
  double channel(int c) {
    final double s = c / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  double luminance(Color c) =>
      0.2126 * channel((c.r * 255).round()) +
      0.7152 * channel((c.g * 255).round()) +
      0.0722 * channel((c.b * 255).round());

  double contrast(Color a, Color b) {
    final double la = luminance(a), lb = luminance(b);
    final double hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Alfayı zemine bindirir — "ekranda gerçekten oluşan renk".
  Color over(Color fg, Color bg) {
    final double a = fg.a;
    int mix(double f, double b) => ((f * 255) * a + (b * 255) * (1 - a)).round();
    return Color.fromARGB(255, mix(fg.r, bg.r), mix(fg.g, bg.g), mix(fg.b, bg.b));
  }

  /// Bir metin renginin, verilen TÜM zeminler arasındaki EN KÖTÜ oranı.
  double worst(Color fg, List<Color> backgrounds) => backgrounds
      .map((Color bg) => contrast(fg, bg))
      .reduce((double a, double b) => math.min(a, b));

  // ── Gerçek zemin yığınları. Hiçbiri elle yazılmış hex DEĞİL: hepsi temanın
  // kendi sabitlerinden türüyor, yani tema kayarsa kapı da kayar.
  final Color glassLight = over(GlassCard.defaultGradient.first, OstinatoColors.shell);
  final Color glassDark = over(GlassCard.defaultGradient.last, OstinatoColors.shell);

  final List<Color> lightSurfaces = <Color>[
    OstinatoColors.shell,
    OstinatoColors.surface,
    glassLight,
    glassDark,
  ];

  group('WCAG 1.4.3 AA — küçük metin, 4.5:1', () {
    const double aa = 4.5;

    test('kicker (textMono) — uygulamadaki HER bölüm etiketi', () {
      // En pahalı kalem: "LOCKED" · "WHY IT IS LOCKED" · "WHAT WOULD OPEN IT"
      // · "THE MICROPHONE IS NOT WIRED" — dürüst hâlleri ADLANDIRAN metin.
      expect(worst(OstinatoColors.textMono, lightSurfaces),
          greaterThanOrEqualTo(aa));
    });

    test('textFaint — kilitli dersin "yapabileceğin bir şey yok" dipnotu', () {
      expect(worst(OstinatoColors.textFaint, lightSurfaces),
          greaterThanOrEqualTo(aa));
    });

    test('textMuted', () {
      expect(worst(OstinatoColors.textMuted, lightSurfaces),
          greaterThanOrEqualTo(aa));
    });

    test('textBody ve ink — gövde metni', () {
      expect(worst(OstinatoColors.textBody, lightSurfaces),
          greaterThanOrEqualTo(aa));
      expect(worst(OstinatoColors.ink, lightSurfaces), greaterThanOrEqualTo(aa));
      expect(worst(OstinatoColors.inkSoft, lightSurfaces),
          greaterThanOrEqualTo(aa));
    });

    test('warnInk — kadraj hatası / ışık yetersiz (DÜRÜST HÂLLER)', () {
      // Setup Check'in uyarı kartı: bu iki hâl kullanıcının en çok
      // karşılaşacağı başarısızlık yüzeyi.
      expect(contrast(OstinatoColors.warnInk, const Color(0xFFFFECE2)),
          greaterThanOrEqualTo(aa));
    });

    test('kamera sahnesinde beyaz metin — izin reddi / kamera yok', () {
      // Koyu gradyanın İKİ ucu da ölçülür.
      expect(
          worst(const Color(0xFFFFFFFF),
              <Color>[const Color(0xFF3A3348), const Color(0xFF241F2E)]),
          greaterThanOrEqualTo(aa));
    });

    test('birincil düğme — koyu zeminde beyaz etiket', () {
      expect(contrast(const Color(0xFFFFFFFF), OstinatoColors.ink),
          greaterThanOrEqualTo(aa));
    });
  });

  group('çalgı kimlikleri — kart yüzeyinde başlık', () {
    // Her çalgının `ink` tonu KENDİ gradyanının üstünde okunur (§13: renk
    // kartın, zemin nötr). Gradyanın iki ucu da ölçülür.
    for (final (String name, InstrumentHue hue) in <(String, InstrumentHue)>[
      ('guitar', InstrumentHues.guitar),
      ('voice', InstrumentHues.voice),
      ('piano', InstrumentHues.piano),
    ]) {
      test('$name — kart başlığı kendi gradyanında okunur', () {
        final List<Color> onCard = hue.grad
            .map((Color c) => over(c, OstinatoColors.shell))
            .toList();
        // Başlık 22px w600 — WCAG "büyük metin" (≥18.66px bold) sınıfı,
        // eşik 3.0. Sınıfı BURAYA yazıyoruz ki gevşetme sessiz olmasın.
        expect(worst(hue.ink, onCard), greaterThanOrEqualTo(3.0),
            reason: '$name kart başlığı kendi gradyanında görünmüyor');
      });
    }
  });

  test('kapının kendisi çalışıyor mu — bilinen iki değerle sınandı', () {
    // Kapı, ölçtüğünü ölçtüğünü göstermeden kapı değildir.
    expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01));
    expect(contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
        closeTo(4.48, 0.02));
  });
}
