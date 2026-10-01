import 'package:flutter/material.dart';
import '../app_locale.dart';
import '../catalog_copy_tr.dart';

import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../session_store.dart';
import 'review_copy_tr.dart';

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

  /// HİÇ okunabilir kare yoksa oran YOK — `null`.
  ///
  /// ⚠️ Önceki hâli `sampleCount == 0 ? 1 : …` idi (O-070). Bir BÖLME-SIFIR
  /// savunmasıydı ve sessizce **%100 bant-içi** anlamına geliyordu; oradan da
  /// `verdict` **"Steady."** üretiyordu. Yani kamera hiç okunamadığında
  /// (izin ortada reddedildi · sürekli karanlık · kadraj dışı) kullanıcı
  /// SIFIR ölçümle OLUMLU bir hüküm görüyordu.
  ///
  /// Bu, ürünün en sert kuralının ihlaliydi: *düşük güvende hüküm yok.*
  /// Live ekranı bunu zaten doğru yapıyor ("şu an göremiyorum"); Review
  /// yapmıyordu. Savunmacı bir varsayılan, ölçülmemiş bir iddiaya dönüştü.
  double? get insideShare =>
      sampleCount == 0 ? null : 1 - outCount / sampleCount;

  /// Okunabilir tek kare bile yok mu?
  bool get nothingReadable => sampleCount == 0;

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
    // DÖRDÜNCÜ HÂL (O-070): hüküm YOK. Üç betimleyici de bir ÖLÇÜME dayanır;
    // ölçüm yoksa dördüncüsü de bir betimleyici değil, bir YOKLUK beyanıdır.
    if (nothingReadable) return 'Nothing we could read.';
    if (insideShare! > 0.66) return 'Steady.';
    if (_improving()) return 'Improving.';
    return 'Mostly outside the band.';
  }

  bool _improving() {
    // ⚠️ Bu da bir savunma ve bir HÜKME besleniyor (O-071 taraması):
    // 8 kareden az geçmişte "iyileşiyor mu" sorusu cevaplanamaz, `false`
    // dönülür ve verdict "Mostly outside the band."a düşer. Yani AZ veriyle
    // olumsuz bir hükme varılabiliyor. O-070'in tersi yönü ve daha hafifi:
    // orada sıfır veri OLUMLU hüküm üretiyordu, burada az veri OLUMSUZ
    // hükmü elemiyor. Sıfır hâli artık `nothingReadable` ile kesiliyor;
    // 1-8 kare arası hâlâ hüküm alıyor — İSİMLİ SINIR, koordinatöre
    // taşındı (eşik kararı: kaç kare bir hükmü hak eder?).
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

String _countWordTr(int n) => const <int, String>{
      1: 'Bir', 2: 'İki', 3: 'Üç', 4: 'Dört', 5: 'Beş',
      6: 'Altı', 7: 'Yedi', 8: 'Sekiz', 9: 'Dokuz', 10: 'On',
    }[n] ?? '$n';

/// D14 (2026-08-16, O-153): "basit geçmiş listesi yeter" — tek satır,
/// tek kayıt. Hangi DERS olduğunu adlandırmaz (ContentRepository lookup
/// gerektirirdi, bu ekran onu almıyor); yalnız NE ZAMAN + NE OLDUĞU.
String _lastSessionLine(BuildContext context, PersistedSession s) {
  final Duration age = DateTime.now().difference(s.completedAt);
  final String when = age.inDays >= 2
      ? localized(context, '${age.inDays} days ago', '${age.inDays} gün önce')
      : age.inDays == 1
          ? localized(context, 'Yesterday', 'Dün')
          : age.inHours >= 1
              ? localized(context, '${age.inHours}h ago', '${age.inHours} saat önce')
              : localized(context, 'Earlier today', 'Bugün daha önce');
  if (s.sampleCount == 0) {
    return ReviewCopyTr.template(context, 'last.none',
        '{when} — nothing readable that time either.',
        <String, String>{'when': when});
  }
  final int share = ((1 - s.outCount / s.sampleCount) * 100).round();
  return ReviewCopyTr.template(context, 'last.readable',
      '{when} — inside the band in {share}% of readable samples; '
      '{secs}s elapsed.',
      <String, String>{
        'when': when,
        'share': '$share',
        'secs': '${s.elapsedSeconds}',
      });
}

/// Özet — "neyi ölçemedik" ZORUNLU ve EŞİT AĞIRLIKLI (§6/⑫).
class ReviewScreenRoute extends StatelessWidget {
  const ReviewScreenRoute({
    super.key,
    required this.discipline,
    required this.lesson,
    required this.hue,
    required this.summary,
    this.previousSession,
  });

  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;
  final SessionSummary summary;

  /// D14 (2026-08-16, O-153): İLK oturumda `null` çözülür — bir öncekinin
  /// YOKLUĞU, bilinmeyen bir değer DEĞİL, gerçek bir hâl (H-20 dersi:
  /// bu iki durum ekranda AYRI çizilmeli, "0" ile "hiç yok" aynı kutuya
  /// düşmemeli). H-45 (O-154): `Future` — bu ekran artık kendi depo
  /// okumasını BEKLEMEDEN doğar (`live_screen.dart`), okuma bittiğinde
  /// `FutureBuilder` kartı SONRADAN çizer; hata ile biterse kart hiç
  /// çizilmez (çökme yok, yalnız sessiz eksiklik — kabul edilen sınır
  /// aynı: geçmiş kartı SONUÇ yüzeyinin bir eklentisi, önkoşulu değil).
  final Future<PersistedSession?>? previousSession;

  @override
  Widget build(BuildContext context) {
    final int secs = summary.elapsedSeconds < 1 ? 1 : summary.elapsedSeconds;
    final List<String> gaps = <String>[
      ReviewCopyTr.text(context, 'gap.confidence',
          'Landmark confidence below the bar. Any window like that is not '
          'counted, not scored as zero.'),
      ReviewCopyTr.text(context, 'gap.scope',
          'Anything outside what this lesson measures — trunk alignment only; '
          'no other joint carries a verdict here.'),
      ReviewCopyTr.text(context, 'gap.arms',
          'Your arms. If shown live elsewhere, they are measured and never '
          'marked — the teachers we recorded disagree by too much to call '
          'a difference an error.'),
      // 4. kalem ÇALGIYA ÖZEL ve VERİDEN gelir (DESIGN-AHEAD-OF-CODE §2.1'in
      // eksik maddesi). Burada elle yazılsaydı üç çalgı için üç `if` olurdu
      // ve dördüncü çalgı eklendiğinde sessizce eksik kalırdı.
      if (discipline.instrumentSpecificGap.isNotEmpty)
        catalogCopy(context, '${discipline.id}.instrumentSpecificGap',
            discipline.instrumentSpecificGap),
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
                      semanticLabel: localized(context, 'Done', 'Bitti'),
                      onTap: () =>
                          Navigator.of(context).popUntil((Route<void> r) => r.isFirst)),
                  kicker(localized(context, 'Summary', 'ÖZET')),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 18),
              Text(catalogName(context, lesson.id, lesson.displayName),
                  style: hankenText(
                      size: 27, weight: FontWeight.w600, height: 1.15)),
              const SizedBox(height: 10),
              Text(
                  // O-070 (ikinci tur, KANITA BAKINCA): sıfır-ölçüm hâlinde
                  // bu satır "42 S MEASURED" diyordu ve gövde "tek kare
                  // okuyamadık" diyordu — AYNI EKRANDA çelişki. Geçen SÜRE
                  // ile ÖLÇÜLEN süre farklı şeyler; ikisini tek kelimeyle
                  // ("measured") anlatmak, ölçülmemiş süreyi ölçülmüş
                  // gösteriyordu.
                  '${summary.nothingReadable ? localized(context, "$secs S ELAPSED · NOTHING READ", "$secs SN GEÇTİ · ÖLÇÜM YOK") : localized(context, "$secs S ELAPSED · ${summary.sampleCount} READABLE SAMPLES", "$secs SN GEÇTİ · ${summary.sampleCount} OKUNABİLİR ÖRNEK")} · ${catalogUpperName(context, discipline.id, discipline.displayName)} · '
                  '${localized(context, 'NO SCORE', 'PUAN YOK')}',
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
                    kicker(localized(context, 'What we measured', 'ÖLÇTÜKLERİMİZ'), color: hue.ink),
                    const SizedBox(height: 6),
                    Text(ReviewCopyTr.verdict(context, summary.verdict),
                        key: const Key('review-verdict'),
                        style: hankenText(size: 25, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                        height: 60,
                        child: CustomPaint(
                            painter: _CurvePainter(history: summary.history))),
                    const SizedBox(height: 12),
                    // O-070: sıfır ölçümde bu cümle "%100 … 0 saniye" derdi.
                    // Yokluk kendi cümlesini taşır; ölçüm cümlesinin içine
                    // sıfır koymak, ölçülmemiş olanı ölçülmüş gibi biçimler.
                    Text(
                      summary.nothingReadable
                          ? ReviewCopyTr.text(context, 'body.none',
                              'We could not read a single frame this session, '
                              'so there is nothing to summarise — not a zero, '
                              'and not a verdict. The camera never gave us a '
                              'trunk line we trusted enough to measure.')
                          : ReviewCopyTr.template(context, 'body.readable',
                              'Your trunk stayed inside the teachers’ band in '
                              '{share}% of readable samples. That is the whole '
                              'of it: the share of readable samples inside '
                              'the band and the shape of the line above. No '
                              'weighting, no composite, nothing hidden behind '
                              'a single figure.',
                              <String, String>{
                                'share': '${(summary.insideShare! * 100).round()}',
                              }),
                      key: const Key('review-measured-body'),
                      style: hankenText(size: 13.5, height: 1.55),
                    ),
                  ],
                ),
              ),
              // D14/H-45 (2026-08-16, O-153/O-154): "son oturum" — İLK
              // oturumda ve okuma henüz çözülmemişken/hata ile bitmişken
              // hiç ÇİZİLMEZ (bir sayı değil bir kartın YOKLUĞU; H-20
              // dersi: "hiç kayıt yok" ile "kayıt var, sıfır" aynı
              // görünmemeli). `FutureBuilder`: bu kart SONUÇ yüzeyinin
              // doğuşunu BEKLETMEZ, yalnız hazır olunca sonradan belirir.
              if (previousSession != null)
                FutureBuilder<PersistedSession?>(
                  future: previousSession,
                  builder: (BuildContext context,
                      AsyncSnapshot<PersistedSession?> snapshot) {
                    final PersistedSession? prev = snapshot.data;
                    if (prev == null) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              kicker(localized(context, 'Last session', 'SON OTURUM'), color: hue.ink),
                              const SizedBox(height: 6),
                              Text(
                                _lastSessionLine(context, prev),
                                key: const Key('review-last-session-note'),
                                style: hankenText(size: 13.5, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // O-069 İKİNCİ TUR: bu başlığı ilk turda ATLADIM.
                    // Çalgı sayfasının başlığını düzeltip Review'da yalnız
                    // kapanış cümlesini değiştirmiştim — *bir kusuru bulduğun
                    // yüzeyde düzeltmek, onu ürünün geri kalanında düzeltmek
                    // değildir* (J-151), ve bu gece ÜÇÜNCÜ tekrarı. Kanıt
                    // karesine bakınca görüldü: `05-review.png` hâlâ
                    // "WHAT WE COULD NOT MEASURE" diyordu.
                    kicker(localized(context, 'What we did not judge — and why',
                        'NEYİ DEĞERLENDİRMEDİK, NEDEN?')),
                    const SizedBox(height: 6),
                    // Sayı LİSTEDEN türer. Elle yazılıydı ('Three things')
                    // ve tam altındaki liste de elle yazılıydı: dördüncü
                    // kalem eklenince başlık SESSİZCE bayatlardı — O-029'un
                    // ("vitrin korumasızdı") canlı-yüzey hâli, kullanıcıya
                    // görünen bir sayının saydığı şeye bağlı OLMAMASI.
                    Text(localized(context,
                            '${_countWord(gaps.length)} things, by name.',
                            '${_countWordTr(gaps.length)} alan, tek tek.'),
                        key: const Key('review-gap-headline'),
                        // hankenText() — ham `TextStyle` tipografi
                        // yardımcısını ATLIYORDU (O-052).
                        style: hankenText(
                            size: 25,
                            weight: FontWeight.w600,
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
                      // O-069: "aynı ağırlıkta" cümlesi doğruydu ama
                      // eksikti — bu kalemler aynı TÜRDEN de değil.
                      ReviewCopyTr.text(context, 'gap.footer',
                        'This half is not a disclaimer. It is the same size as '
                        'the half above because it carries the same weight — '
                        'and these are not all the same kind of gap: some are '
                        'missing tools, some are missing data, and some are '
                        'judgements we do not think are ours to make.'),
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
                    kicker(localized(context, 'One thing next', 'BİR SONRAKİ ADIM')),
                    const SizedBox(height: 8),
                    Text(
                      ReviewCopyTr.text(context, 'next.space',
                        'Next time, leave enough room between you and the '
                        'phone to keep both hips in frame throughout.'),
                      style: hankenText(size: 17.5, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(ReviewCopyTr.text(context, 'next.footer',
                        'One suggestion, not a list.'),
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
                  ReviewCopyTr.text(context, 'sharing',
                    'Sharing a skeleton-render report is not wired in this '
                    'build. Raw video never leaves this device either way — '
                    'there is simply no report to send.'),
                  // H-44 (2026-08-16): İNECEK KALEM — bir paylaşım/dışa
                  // aktarma yolu (skeleton-render'ı PNG/PDF olarak
                  // biriktirip göndermek) inşa edilirse bu cümle YALAN olur.
                  // O gün bu metin ADIYLA güncellenmeli, sessizce bırakılmaz.
                  key: const Key('review-sharing-gap-note'),
                  style: hankenText(size: 12.5, color: OstinatoColors.textMuted),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: localized(context, 'Done', 'Bitti'),
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
    // 🔴 O-071: burada `history.isEmpty ? const <double>[3, 3.4, 3.1] : history`
    // vardı — geçmiş BOŞKEN UYDURMA üç değer çizdiriyordu ve makul görünen
    // bir eğri üretiyordu. O-070'te "tek kare okuyamadık" cümlesini yazdım,
    // ve tam üstünde bu eğri çizilmeye devam ediyordu.
    //
    // Ailenin EN SERT kuralı: sahte veri YOK. Ve bu, O-070'in verdict
    // kusuruyla AYNI `? :` savunma deseninden doğdu — *aynı eksik yapı, iki
    // farklı kusur sınıfı* (koordinatör, J-156 sınıfı): biri ölçülmemişi
    // HÜKME çevirdi, öteki ölçülmemişi ÇİZGİYE çevirdi.
    //
    // Boş geçmiş artık HİÇBİR ŞEY çizmez. Yokluğun görseli boşluktur.
    if (history.isEmpty) return;
    final List<double> h = history;
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
