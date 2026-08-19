import 'dart:typed_data';

/// Sabit kapasiteli, YALNIZ RAM'de dairesel örnek tamponu.
///
/// Roadmap §7 madde 1: "Ring buffer RAM'de; session exit/permission
/// revoke/background'da sıfırlanır." Bu sözleşmenin dosya-kalıntısı yarısı
/// (raw PCM diske YAZILMAZ) bu sınıfın hiçbir satırında `dart:io` olmamasıyla
/// KANITLANIR — bir testin "dosyaya yazmadı" demesiyle değil, koddaki
/// importların kendisiyle (kod-incelemesi kanıtı, `AudioBufferPrivacyTest`
/// bu yokluğu ayrıca doğrular).
///
/// Sınırsız büyüyen bir liste DEĞİL: [push] kapasiteyi aşan örneği en ESKİ
/// örneğin üstüne yazar. Bu "veri kaybı" değil YAPI — tampon bir tarihçe
/// değil, pitch/onset dedektörlerinin ihtiyaç duyduğu SABİT boyutlu bir
/// pencere (bkz. `PitchSource.analyze` — sabit uzunlukta `List<double>`
/// bekler).
final class AudioRingBuffer {
  AudioRingBuffer({required this.capacitySamples})
      : assert(capacitySamples > 0, 'kapasite sıfır/negatif olamaz'),
        _data = Float64List(capacitySamples);

  final int capacitySamples;
  final Float64List _data;
  int _length = 0;
  int _writeIndex = 0;

  /// Şu an tamponda tutulan örnek sayısı (`clear()` sonrası veya ilk
  /// `push()`e kadar `capacitySamples`den az olabilir).
  int get length => _length;

  bool get isFull => _length == capacitySamples;

  /// [samples] eklenir. Tampon dolarsa en eski örnekler sessizce üstüne
  /// yazılır — bu bir hata YOLU değil, tamponun NORMAL çalışma biçimi.
  void push(List<double> samples) {
    for (final double s in samples) {
      _data[_writeIndex] = s;
      _writeIndex = (_writeIndex + 1) % capacitySamples;
      if (_length < capacitySamples) _length++;
    }
  }

  /// Şu anki pencereyi KRONOLOJİK sırada döner — en eski örnek `[0]`.
  /// Kopyadır: çağıran döneni mutasyona uğratsa bile tamponun kendi durumu
  /// bozulmaz.
  List<double> snapshot() {
    if (_length < capacitySamples) {
      return _data.sublist(0, _length);
    }
    final int start = _writeIndex;
    return <double>[
      ..._data.sublist(start, capacitySamples),
      ..._data.sublist(0, start),
    ];
  }

  /// Roadmap §7 madde 1'in "sıfırlanır" fiili — yalnız `_length=0` YETMEZ.
  ///
  /// `_length`i sıfırlamak örnekleri tamponun PUBLIC API'sinden erişilemez
  /// kılar ama alttaki `Float64List`in baytlarını DEĞİŞTİRMEZ — bir sonraki
  /// `snapshot()` onları göremez, ama bellek dökümü/GC'den önceki bir çapraz
  /// referans hâlâ görebilir. `clear()` gerçekten sıfırlar: session
  /// exit/permission revoke/background üçü de bunu çağırır (kablolama:
  /// `AudioInputController`), "gösterilmiyor" ile "yok" arasındaki farkı
  /// kapatır.
  void clear() {
    _data.fillRange(0, capacitySamples, 0.0);
    _length = 0;
    _writeIndex = 0;
  }

  /// YALNIZ test için: `_length`in gizlediği bölge dahil TÜM alttaki diziyi
  /// döner.
  ///
  /// Neden var: `snapshot()` her zaman `[0, _length)` dilimini okur — bu
  /// yüzden `clear()`teki `fillRange` satırı **`push`/`snapshot`/`length`
  /// genel API'sinden asla gözlemlenemez** (silinse bile hiçbir dış test
  /// kırılmaz, MUT-A'nın hayatta kalan bir mutasyonu olurdu). Bu erişimci
  /// olmadan "gerçekten sıfırlıyor" iddiası, ölçülmeden yazılmış bir yorumdan
  /// ibaret kalırdı.
  List<double> debugRawBackingStoreForTest() => List<double>.unmodifiable(_data);
}
