# FK1 — Referans ses ("önce dinle")

**Durum:** tasarım, 2026-11-03. Rakip analizi PLAN-ONERISI FK1 satırı; Yönetim sıralaması 2026-11-03 (FK1 → F2.6 → K8 → FK3).

## Sorun

- 240 gitar dersinin 213'ü yazılı nota dizisi (`practice.sequence`) ve tempo taşır; 315 gitar dersinin `referenceAudio.kinds` alanı dolu.
- Ders okuma ekranı her derste "referans ses yakında" yazar (`V1CourseCopy.readerReferenceSoon`).
- Pratik ekranında yalnız "bu notayı dinle" vardır: tek nota, 1,2 s tel modeli (`referenceNote`).
- Kulak kursu (50 ders, S1 ücretsiz) hiç ses çalmaz.

## Bugünkü sınırlar (kod)

- `playCue` en çok 2 s çalar (`kMaxCueSeconds = 2`; Swift `maxCueSeconds = 2`).
- Yalnız açık bir çal+kaydet denemesi içinde çalar, yani mikrofon oturumu ister. 4 ölçülük bir satır ♩=60'ta 16 s sürer.

## Seçenekler

| | Yol | Artı | Eksi |
|---|---|---|---|
| A | `playCue` sınırını ~40 s'ye çıkar | Tel aynı, az kod | Dinlemek için mikrofon oturumu gerekir; durdurma yok; 2 s sözleşmesi bozulur |
| B | Ayrı, yalnız çalan yerel oynatıcı: `playReference` / `stopReference` (iOS `AVAudioPlayerNode`, Android `AudioTrack` MODE_STATIC). Mikrofon yok; sentez Dart'ta | Okuma ekranı, pratik ekranı (koşu dışı) ve kulak drill'i (F2.6) aynı yolu kullanır; cue sözleşmesi değişmez | İki platformda yerel kod; ses oturumu çakışmaları için arbiter'a kayıt |
| C | Sentezi yerelde yap | Kanaldan az bayt | Sentez iki kez yazılır, test edilemez |

**Seçim: B.** Sentez Dart'ta kalır: `SyntheticString` tel modeli ve gelecekteki basit piyano sentezi, test edilebilir ve belirlenimli. Yerel taraf yalnız hazır PCM'i çalar ve durdurur.

## Kapsam (ilk PR)

1. **Sentez:** `PracticeScore`'dan PCM üretimi.
   - Her nota olayı vuruş zamanında tel modeli tınısıyla çalınır; isteğe bağlı klik, ilk ölçüde ön sayım.
   - Hedef tempo ve yavaş tempo (`tempo.open`) seçilebilir.
   - Tavan 40 s; satır sığmazsa ilk N ölçü çalınır ve ekran bunu söyler.
   - Float32, 44,1/48 kHz, tepe ≤ 0,5.
2. **Yerel oynatıcı:** `com.yulalab.ostinato/reference_v1`, yöntemler `play {samples, sampleRate}` ve `stop`, olay `ended`.
   - iOS: `.playback` kategorisi yalnız mikrofon kapalıyken; kayıt oturumu açıksa `busy` hatası.
   - Android: `AudioTrack` USAGE_MEDIA.
   - Pratik koşusu sürerken referans çalınmaz.
3. **Arayüz:**
   - Okuma ekranındaki "yakında" satırının yerine Dinle / Durdur ve tempo seçimi gelir (yalnız `sequence` çözülebilen derslerde).
   - Pratik ekranında koşu başlamadan "Önce dinle".
   - Yeni metinler 14 katalogda message id ile.
4. **Testler:** sentez belirlenimliliği ve süre/tavan; tel sözleşmesi (geçersiz PCM reddi); okuma ekranı widget testi; kanal sahte uygulaması.

## Kapsam dışı

- Piyano/ses sentezi (piyano kursu yayında değil).
- `SE` eşlik döngüleri.
- `KL` klik-yalnız derslerin metronomla birleştirilmesi.
- Kulak drill ekranı (F2.6, ayrı PR; bu oynatıcıyı kullanır).

## Kabul

- Simülatörde okuma ve pratik ekranında Dinle / Durdur çalışır.
- Koşu sırasında referans başlamaz; mikrofon izni istenmez.
- Yerel testler ve `flutter test` yeşil; CI 3/3.
- Gerçek cihazda dinleme kurucu dogfooding'inde doğrulanır.
