import 'package:flutter/material.dart';

/// Ostinato'nun görsel kimliği — Claude Design paneli çıktısının (2026-08-05,
/// proje `4352ea41-…`) sabitleri. Renk/malzeme İCAT edilmedi: panelin ürettiği
/// hex değerler birebir taşındı; buradaki tek "hüküm" hangi rengin hangi
/// çalgıya ait olduğu, bir ölçüm eşiği değil.
///
/// Kardeş ayrışması (bağlayıcı, DESIGN-PANEL-PROMPT §1): camsı/yarı-saydam
/// gradyan kart — Lissom'un mat kili DEĞİL; temiz sans + mono meta — Lissom'un
/// serifi DEĞİL; çok-renkli spektrum — Referans-2'nin kırmızısı DEĞİL.
abstract final class OstinatoColors {
  static const Color ink = Color(0xFF2A2533);
  static const Color inkSoft = Color(0xFF3E3849);
  static const Color textBody = Color(0xFF4E4759);
  // ⚠️ ÜÇ TON KOYULAŞTIRILDI (2026-08-07, O-048 — JabLab J-114 aktarımı).
  // Panelin ürettiği değerler WCAG 1.4.3 AA'nın (4.5:1, küçük metin) ALTINDA
  // kalıyordu ve bu ÖLÇÜLDÜ, tahmin edilmedi — kontrast ekranda GERÇEKTEN
  // oluşan renkten hesaplandı (alfa zemine bindirilerek, camsı gradyanın
  // hem en açık hem en koyu ucunda, en kötü nokta alınarak).
  //   textMono  #9B95A8 → #6E667D   (en kötü oran 2.41 → 4.54)
  //   textFaint #8B8497 → #6E677A   (3.00 → 4.51)
  //   textMuted #6E6880 → #6D677E   (4.43 → 4.50)
  // TON ve DOYGUNLUK korundu, yalnız parlaklık düşürüldü (HLS L) — tasarımın
  // rengi değil, okunabilirliği düzeltildi. Eşik İCAT DEĞİL: WCAG dış bir
  // standart, formül standardın kendisi.
  // `textMono` en pahalısıydı: `kicker()` uygulamadaki HER bölüm etiketi
  // ("LOCKED" · "WHY IT IS LOCKED" · "WHAT WOULD OPEN IT" · "THE MICROPHONE
  // IS NOT WIRED"), yani dürüst hâlleri ADLANDIRAN metin, uygulamanın en
  // okunmaz metniydi. Görünmeyen bir dürüst hâl, susmakla aynı şeydir.
  static const Color textMuted = Color(0xFF6D677E);
  static const Color textFaint = Color(0xFF6E677A);
  static const Color textMono = Color(0xFF6E667D);
  static const Color shell = Color(0xFFEDE9F0);
  static const Color surface = Color(0xFFF4F1F6);
  static const Color warnInk = Color(0xFF9A5A46);
}

/// Bir çalgının gradyan kimliği — kart yüzeyleri/başlıkları sahiplenir,
/// kabuk/zemin nötr kalır (§13).
final class InstrumentHue {
  const InstrumentHue({
    required this.grad,
    required this.gradAlt,
    required this.soft,
    required this.chip,
    required this.band,
    required this.ink,
  });

  final List<Color> grad;
  final List<Color> gradAlt;
  final List<Color> soft;
  final Color chip;
  final Color band;
  final Color ink;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: grad,
  );
  LinearGradient get gradientAlt => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: gradAlt,
  );
  LinearGradient get softGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: soft,
  );
}

/// ⚠️ `ink` TONLARI KOYULAŞTIRILDI (2026-08-07, O-049 — JabLab J-116'nın
/// "örüntüyü değil örneği düzelttim" dersi). O-048'de nötr metin tonlarını
/// düzelttim ve DURDUM; oysa `kicker(color: hue.ink)` YEDİ çağrı yerinde
/// çalgı tonunu KÜÇÜK metin olarak (9.5px mono) kullanıyor — yani eşiği
/// 4.5, benim O-048'de sınadığım 3.0 (büyük başlık) DEĞİL. Ölçüldü:
///   guitar #9A4E3E → 4.04 ⛔ · piano #2E7566 → 4.14 ⛔ · voice 4.68 ✅
/// Kendi gradyanlarının EN KÖTÜ durağında. Düzeltme yine ton+doygunluk
/// korunarak, yalnız parlaklık: #8F483A (4.53) · #2B6F60 (4.50). Voice
/// zaten geçiyordu, DOKUNULMADI — geçen bir değeri "tutarlılık" için
/// değiştirmek, ölçmediğin bir şeyi değiştirmektir.
abstract final class InstrumentHues {
  static const InstrumentHue guitar = InstrumentHue(
    grad: <Color>[Color(0xF2FFD9BE), Color(0xCCF8C6D4)],
    gradAlt: <Color>[Color(0xE6F8C6D4), Color(0xC7FFDECD)],
    soft: <Color>[Color(0x80FFD9BE), Color(0x57F8C6D4)],
    chip: Color(0xB3FFD9BE),
    band: Color(0x389A4E3E),
    ink: Color(0xFF8F483A),
  );
  static const InstrumentHue voice = InstrumentHue(
    grad: <Color>[Color(0xF2DACDF6), Color(0xCCC3DDF8)],
    gradAlt: <Color>[Color(0xE6C3DDF8), Color(0xC7DED3F8)],
    soft: <Color>[Color(0x80DACDF6), Color(0x57C3DDF8)],
    chip: Color(0xB3DACDF6),
    band: Color(0x335F4CA0),
    ink: Color(0xFF5F4CA0),
  );
  static const InstrumentHue piano = InstrumentHue(
    grad: <Color>[Color(0xF2C4EADB), Color(0xCCC9E3F1)],
    gradAlt: <Color>[Color(0xE6C9E3F1), Color(0xC7CAEEE0)],
    soft: <Color>[Color(0x80C4EADB), Color(0x57C9E3F1)],
    chip: Color(0xBFC4EADB),
    band: Color(0x332E7566),
    ink: Color(0xFF2B6F60),
  );

  static InstrumentHue of(String disciplineId) => switch (disciplineId) {
    'guitar' => guitar,
    'voice' => voice,
    'piano' => piano,
    _ => guitar,
  };
}

/// Yalnız görsel kimlik — ölçüm değeri taşımaz. Şu an bu üç sabitin kaynağı
/// tasarım paneli değil GERÇEK dürüstlük kutusu metninden (library.json)
/// okunan sayılardır (§16 kol-açısı borcu, aşağıya bkz).
final class ArmRangeHint {
  const ArmRangeHint(this.lowDeg, this.highDeg);
  final double lowDeg;
  final double highDeg;
}

/// Kol/önkol açısı aralığı — dürüstlük kutusu metninden OKUNAN sayılar
/// (`notMeasured` metninde "39 to 105 degrees" gibi geçiyor). Makine-okunur
/// bir kontrat alanı DEĞİL — metinden ayrıştırılmadı, elle taşındı ve
/// KAYITLI: canlı bir kol-açısı ölçümü YOK (bkz `lesson_demo_screen.dart`
/// üstündeki not). Yalnız STATİK bant çizimi için kullanılır.
abstract final class ArmRangeHints {
  static const Map<String, ArmRangeHint> byDiscipline = <String, ArmRangeHint>{
    'guitar': ArmRangeHint(39, 105),
    'voice': ArmRangeHint(43, 88),
    'piano': ArmRangeHint(20, 77),
  };
}

TextStyle hankenText({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: 'Hanken Grotesk',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

TextStyle monoText({
  double size = 9.5,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double letterSpacing = 1.4,
}) => TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
);

/// Uygulamanın TEK `ThemeData`sı.
///
/// `main.dart`ta private bir statik olarak duruyordu ve kanıt üreteci
/// (`tools/evidence/`) kendi `MaterialApp`ini TEMASIZ kuruyordu. Sonuç
/// ÖLÇÜLDÜ (2026-08-07, O-052): ham `TextStyle` kullanan metin gerçek
/// uygulamada `textTheme`den Hanken alıyor, kanıt karesinde ise varsayılan
/// test yazı tipine düşüp BLOK GLİF olarak çiziliyordu. Yani kanıt aracı
/// tipografide SADIK DEĞİLDİ — ve bir kanıt aracının verdiği güven,
/// sadakati kadardır.
///
/// Buraya taşındı ki iki yer AYNI nesneyi kullansın; elle kopyalanan bir
/// tema, ilk değişiklikte sessizce ayrışır.
ThemeData ostinatoTheme() => ThemeData(
  colorSchemeSeed: const Color(0xFF5F4CA0),
  scaffoldBackgroundColor: OstinatoColors.shell,
  fontFamily: 'Hanken Grotesk',
);

/// Bölüm başlığı — "SCREENS" / "YOUR INSTRUMENTS" tarzı mono kicker.
Widget kicker(String text, {Color? color}) => Builder(
  builder: (context) => Text(
    text.toUpperCase(),
    style: monoText(
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);
