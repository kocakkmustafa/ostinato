import 'dart:io';
import 'dart:typed_data';

/// Minimal PCM WAV oku/yaz — OST-P0-003 gerçek fixture hattı için.
///
/// Neden `package:wav` gibi bir bağımlılık DEĞİL: `ostinato_audio` bilerek
/// bağımlılıksız kalıyor (kendi pubspec'inin gerekçesi: "stays free of core
/// so it can be tested standalone") ve bu araç yalnız ONA girdi HAZIRLIYOR
/// (üretim koduna asla girmez — mikrofon gerçek örnekleri native taraftan
/// gelir, dosyadan DEĞİL). Standart PCM WAV'ı ayrıştırmak ~80 satır; bir
/// paket eklemenin bakım/tedarik-zinciri maliyeti bunun altında kalmaz.
///
/// Yalnız DESTEKLENEN: `RIFF/WAVE`, `fmt ` (PCM, tag 1), 16-bit little-endian
/// imzalı tamsayı örnekler. Yazarken de aynı biçimi üretir — okuyan/yazan
/// birbirinin tersini doğrular (round-trip testi bunu kanıtlar).
final class PcmWav {
  const PcmWav({
    required this.sampleRate,
    required this.channels,
    required this.samples, // [-1, 1] aralığında, mono ise tek dizi, çok kanallıysa INTERLEAVED
  });

  final int sampleRate;
  final int channels;
  final List<double> samples;

  /// Mono'ya indirger — kanal ortalaması. `AudioCaptureStreamer.swift`teki
  /// AYNI kural: "mono float örnekler" sözleşmesi kaynaktan bağımsız TEK.
  List<double> toMono() {
    if (channels == 1) return samples;
    final int frameCount = samples.length ~/ channels;
    final List<double> mono = List<double>.filled(frameCount, 0);
    for (int i = 0; i < frameCount; i++) {
      double sum = 0;
      for (int ch = 0; ch < channels; ch++) {
        sum += samples[i * channels + ch];
      }
      mono[i] = sum / channels;
    }
    return mono;
  }

  static PcmWav readFile(String path) => decode(File(path).readAsBytesSync());

  static PcmWav decode(Uint8List bytes) {
    final ByteData bd = ByteData.sublistView(bytes);
    if (_ascii(bytes, 0, 4) != 'RIFF' || _ascii(bytes, 8, 4) != 'WAVE') {
      throw FormatException('RIFF/WAVE başlığı yok — geçerli bir PCM WAV değil');
    }

    int offset = 12;
    int? sampleRate;
    int? channels;
    int? bitsPerSample;
    int? audioFormat;
    int? dataOffset;
    int? dataLength;

    // Genel amaçlı chunk yürüyücü — `fmt `/`data` sırası/aradaki chunk'lar
    // (LIST/fact vb., afconvert çıktısında görülebilir) VARSAYILMAZ.
    while (offset + 8 <= bytes.length) {
      final String chunkId = _ascii(bytes, offset, 4);
      final int chunkSize = bd.getUint32(offset + 4, Endian.little);
      final int bodyStart = offset + 8;
      if (chunkId == 'fmt ') {
        audioFormat = bd.getUint16(bodyStart, Endian.little);
        channels = bd.getUint16(bodyStart + 2, Endian.little);
        sampleRate = bd.getUint32(bodyStart + 4, Endian.little);
        bitsPerSample = bd.getUint16(bodyStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = bodyStart;
        dataLength = chunkSize;
      }
      offset = bodyStart + chunkSize + (chunkSize.isOdd ? 1 : 0); // RIFF chunk'ları çift-hizalı
    }

    if (sampleRate == null || channels == null || dataOffset == null || dataLength == null) {
      throw FormatException('fmt / data chunk bulunamadı');
    }
    if (audioFormat != 1) {
      throw FormatException('yalnız PCM (tag 1) desteklenir, bulunan: $audioFormat');
    }
    if (bitsPerSample != 16) {
      throw FormatException('yalnız 16-bit desteklenir, bulunan: $bitsPerSample');
    }

    final int sampleCount = dataLength ~/ 2;
    final List<double> samples = List<double>.filled(sampleCount, 0);
    for (int i = 0; i < sampleCount; i++) {
      final int raw = bd.getInt16(dataOffset + i * 2, Endian.little);
      samples[i] = raw / 32768.0;
    }
    return PcmWav(sampleRate: sampleRate, channels: channels, samples: samples);
  }

  /// [samples] `[-1, 1]` aralığında, MONO varsayılır (bu aracın tükettiği
  /// tüm fixture'lar mono — `toMono()` sonrası yazılır).
  static void writeMonoFile(String path, {required int sampleRate, required List<double> samples}) {
    final int dataLength = samples.length * 2;
    final Uint8List bytes = Uint8List(44 + dataLength);
    final ByteData bd = ByteData.sublistView(bytes);

    void ascii4(int off, String s) {
      for (int i = 0; i < 4; i++) {
        bytes[off + i] = s.codeUnitAt(i);
      }
    }

    ascii4(0, 'RIFF');
    bd.setUint32(4, 36 + dataLength, Endian.little);
    ascii4(8, 'WAVE');
    ascii4(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // fmt chunk size
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little); // byteRate = rate * blockAlign
    bd.setUint16(32, 2, Endian.little); // blockAlign
    bd.setUint16(34, 16, Endian.little); // bitsPerSample
    ascii4(36, 'data');
    bd.setUint32(40, dataLength, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final double clamped = samples[i].clamp(-1.0, 1.0);
      final int raw = (clamped * 32767.0).round();
      bd.setInt16(44 + i * 2, raw, Endian.little);
    }

    File(path).writeAsBytesSync(bytes);
  }

  static String _ascii(Uint8List bytes, int start, int len) =>
      String.fromCharCodes(bytes.sublist(start, start + len));
}
