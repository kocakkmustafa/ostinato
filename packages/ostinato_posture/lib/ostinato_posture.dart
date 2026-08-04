/// Ostinato'nun canlı postür yüzeyinin KARAR katmanı.
///
/// Sınır (Gravita G-100 deseni): burada Flutter YOK. Kabuk yalnız kablolama
/// olmalı — bir hüküm widget'ın içine sızarsa test edilemez hâle gelir ve
/// "ekranda doğru görünüyordu" savunması doğar.
///
/// Burada YAPILMAYAN üç şey, kasıtlı:
///  1. SAYISAL SKOR (K8/M-F-04): kalibrasyon kapısı geçilmeden sayı gösterilmez.
///     Bu katman bant ve gözlem üretir, puan üretmez — API'de puan alanı YOK.
///  2. KULLANICI METNİ (M-F-232 şart 2): motor VERİ üretir, app şablonu doldurur.
///     `ObservationCue` bir templateId + yuva taşır; cümle taşımaz.
///  3. EŞİK İCADI: bütün sayılar referans artefaktından türetilmiş config'ten
///     okunur (`PostureContract.fromJson`), kodda sabit yoktur.
library;

export 'src/contract.dart';
export 'src/evaluator.dart';
export 'src/pose_source.dart';
export 'src/surface_state.dart';
