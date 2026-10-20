import 'package:flutter/widgets.dart';

import '../app_locale.dart';

/// Reviewed copy for the Review screen's measured facts and named limits.
/// The English claim remains authoritative. A changed claim, or a new copy
/// identity, stays in English until its Turkish wording is reviewed again.
abstract final class ReviewCopyTr {
  static String verdict(BuildContext context, String source) =>
      text(context, switch (source) {
        'Nothing we could read.' => 'verdict.none',
        'Steady.' => 'verdict.steady',
        'Improving.' => 'verdict.improving',
        'Mostly outside the band.' => 'verdict.outside',
        _ => 'verdict.unknown',
      }, source);

  static String text(BuildContext context, String id, String source) {
    final _Reviewed? copy = _copies[id];
    return copy != null && copy.source == source
        ? localized(context, source, copy.turkish)
        : source;
  }

  static String template(
    BuildContext context,
    String id,
    String source,
    Map<String, Object?> values,
  ) {
    final copy = _copies[id];
    return localized(
      context,
      source,
      copy != null && copy.source == source ? copy.turkish : source,
      values: values,
    );
  }

  static const Map<String, _Reviewed> _copies = <String, _Reviewed>{
    'verdict.none': _Reviewed(
      'Nothing we could read.',
      'Okunabilir ölçüm yok.',
    ),
    'verdict.steady': _Reviewed('Steady.', 'Ölçümlerin çoğu bant içinde.'),
    'verdict.improving': _Reviewed(
      'Improving.',
      'Son bölümde gövde eğimi azaldı.',
    ),
    'verdict.outside': _Reviewed(
      'Mostly outside the band.',
      'Ölçümlerin çoğu bant dışında.',
    ),
    'body.none': _Reviewed(
      'We could not read a single frame this session, so there is nothing '
          'to summarise — not a zero, and not a verdict. The camera never '
          'gave us a trunk line we trusted enough to measure.',
      'Bu oturumda tek bir okunabilir kare alamadık. Özetlenecek bir ölçüm '
          'veya hüküm yok; bu sıfır puan değildir. Kamera, ölçüme yetecek '
          'güvenilirlikte bir gövde çizgisi sağlayamadı.',
    ),
    'body.readable': _Reviewed(
      'Your trunk stayed inside the teachers’ band in {share}% of readable '
          'samples. That is the whole of it: the share of readable samples '
          'inside the band and the shape of the line above. No weighting, '
          'no composite, nothing hidden behind a single figure.',
      'Gövdeniz okunabilir örneklerin %{share} kadarında eğitmen bandı '
          'içindeydi. Bu sonuç yalnızca bant içindeki okunabilir örneklerin '
          'oranını ve yukarıdaki çizginin biçimini anlatır. Ağırlıklandırma '
          'veya birleşik puan yoktur.',
    ),
    'gap.confidence': _Reviewed(
      'Landmark confidence below the bar. Any window like that is not '
          'counted, not scored as zero.',
      'Vücut noktaları yeterince güvenilir okunmadığında o pencere sayılmaz; '
          'sıfır puan olarak da değerlendirilmez.',
    ),
    'gap.scope': _Reviewed(
      'Anything outside what this lesson measures — trunk alignment only; '
          'no other joint carries a verdict here.',
      'Bu dersin ölçüm kapsamı dışındaki alanlar. Burada yalnız gövde hizası '
          'değerlendirilir; diğer eklemler için hüküm verilmez.',
    ),
    'gap.arms': _Reviewed(
      'Your arms. If shown live elsewhere, they are measured and never '
          'marked — the teachers we recorded disagree by too much to call '
          'a difference an error.',
      'Kollarınız. Başka bir ekranda canlı gösterilseler bile puanlanmazlar; '
          'kaydettiğimiz eğitmenler arasındaki fark, bir hareketi hata '
          'saymak için fazla büyüktür.',
    ),
    'gap.footer': _Reviewed(
      'This half is not a disclaimer. It is the same size as the half above '
          'because it carries the same weight — and these are not all the '
          'same kind of gap: some are missing tools, some are missing data, '
          'and some are judgements we do not think are ours to make.',
      'Bu bölüm bir dipnot değildir. Yukarıdaki ölçüm kadar önemlidir. '
          'Eksiklerin nedenleri de aynı değildir: bazılarında araç, '
          'bazılarında veri yoktur; bazı konularda hüküm vermek doğru olmaz.',
    ),
    'next.space': _Reviewed(
      'Next time, leave enough room between you and the phone to keep both '
          'hips in frame throughout.',
      'Bir sonraki çalışmada iki kalçanızın da sürekli kadrajda kalacağı '
          'kadar telefonla aranızda mesafe bırakın.',
    ),
    'next.footer': _Reviewed(
      'One suggestion, not a list.',
      'Tek öneri; uzun bir liste değil.',
    ),
    'sharing': _Reviewed(
      'Sharing a skeleton-render report is not wired in this build. Raw '
          'video never leaves this device either way — there is simply no '
          'report to send.',
      'Bu sürümde iskelet çizimi raporu paylaşma özelliği bağlı değildir. '
          'Ham video cihazınızdan çıkmaz; gönderilecek bir rapor da yoktur.',
    ),
    'last.none': _Reviewed(
      '{when} — nothing readable that time either.',
      '{when} — o oturumda da okunabilir ölçüm yoktu.',
    ),
    'last.readable': _Reviewed(
      '{when} — inside the band in {share}% of readable samples; '
          '{secs}s elapsed.',
      '{when} — okunabilir örneklerin %{share} kadarı bant içindeydi; '
          '{secs} sn geçti.',
    ),
  };
}

final class _Reviewed {
  const _Reviewed(this.source, this.turkish);

  final String source;
  final String turkish;
}
