# Kromagram akor tanıma spike'ı — sonuç

**Tarih:** 2026-07-29 · **Bağlam:** M-O-33 (Basic Pitch ağırlık zinciri non-commercial) →
kurucuya lisans sorusu gitmeden önce **ölç** kararı (koordinatör onaylı, M-F-64).
**Soru:** `open_chord_drill` için lisans zinciri olmayan, tamamen bizim olan bir yöntem yeter mi?

## Kısa cevap

**Sentetik malzemede yetiyor** — 8/8, dört koşulda, geniş marjla. Gerçek gitarda
kanıtlanmadı. Yani **kurucuya lisans sorusu şimdilik GEREKMİYOR**, ama "gerekmez" demek için
gerçek kayıt lazım.

## Ne yapıldı

`packages/ostinato_audio/lib/src/harmony/` — kromagram + akor şablonu eşleştirme (Fujishima).
ML yok, model ağırlığı yok, lisans zinciri yok.

**Tasarım kararı — dönüşümü tam nota frekanslarında değerlendirmek.** Doğrusal FFT ızgarası
`sampleRate/frameSize` aralıklı (onlarca Hz); gitarın alt ucunda ayırmamız gereken semitonlar
~5 Hz aralıklı. O ızgarada alçak nota binler ARASINA düşer, sızıntısı kare kare kayar, okuma
titrer — **O-019'un bir gece kaybettiren kusurunun ta kendisi.** Doğrudan her semitonun
frekansında değerlendirmek bu ızgarayı ortadan kaldırıyor. Bedeli daha uzun pencere
(~200 ms); akorlar tutulduğu için burada karşılanabilir, onset zamanlamasında olmazdı.

## Ölçüm — 8 açık akor (E A D G C Am Em Dm)

| Koşul | Doğru | Red | **Yanlış** |
|---|---|---|---|
| temiz | 8/8 | 0 | **0** |
| 20 dB SNR | 8/8 | 0 | **0** |
| 10 dB SNR | 8/8 | 0 | **0** |
| 5 dB SNR | 8/8 | 0 | **0** |
| telefon mikrofonu (120 Hz highpass) | 8/8 | 0 | **0** |

Yanlış hüküm sayısının sıfır olması en önemli sütun: **öğrenci yapmadığı hatayı düzeltmez.**

### Rakip nerede — endişelendiğim yerde değilmiş

Şablon eşleştiricinin klasik zayıflığı sanılan **göreli majör/minör** (C↔Am) değil, asıl rakip
her zaman **aynı kökün 7'li akoru** çıktı (E→E7, A→A7 …). Sebep yapısal: dominant 7'li şablonu
majör üçlünün **üst-kümesi**. Bu yüzden majör marjları (0.117–0.129) minörlerin yarısı
kadar (0.188–0.237) — minörün rakibi paralel majör, yani gerçek bir ayrım.

### Alanı daraltmanın ölçülen bedeli-kazancı

Drill 7'li akor öğretmiyor; şablon setini 8 akora daraltınca:

| akor | 36 şablon | 8 drill akoru | kazanç |
|---|---|---|---|
| G | 0.127 | 0.284 | **2.2×** |
| D | 0.129 | 0.246 | 1.9× |
| E | 0.122 | 0.189 | 1.6× |
| A | 0.117 | 0.160 | 1.4× |
| C | 0.123 | 0.131 | 1.1× |
| Am/Em/Dm | — | değişmedi | 1.0× |

C'nin kazanmaması tutarlı: onun rakibi göreli minörü Am ve o drill setinde kalıyor.
Minörler zaten paralel majörle yarışıyordu, o da sette.

### Reddetmesi gerekeni reddediyor

- tek nota → RED ✅ · iki notalık aralık → RED ✅
- 100 ms pencere → RED ✅ (alçak register ayrışmaz; bulanık kromagram yine de
  *emin görünen* bir kazanan üretirdi — bu reddin sebebi tam olarak bu)

### Cihaz bütçesi

| | akor başına | 30 fps bütçesinin |
|---|---|---|
| ilk hâl (semiton başına sin/cos) | 19,9 ms | %60 |
| **Goertzel + pencere bir kez** | **3,8 ms** | **%11** |

5,2× kazanç; pencere semiton döngüsünün İÇİNDE kuruluyordu, yani aynı 45 kosinüs süpürmesi
her analizde tekrarlanıyordu.

**Mimari sonuç:** akor tanıma **onset-tetiklemeli** koşmalı, kare-başına değil. Kare-başına
%11 bile poz+el hattıyla yarışırken pahalı; akor başına bir kez ise ihmal edilebilir.
⚠️ Bu masaüstü JIT ölçümü — mobil AOT + orta-segment Android çarpanı **bilinmiyor** (G8).

## Ne KANITLANMADI (dürüstlük sınırı)

Sentetik akorlarda tam intonasyon var, tel gıcırtısı yok, ölü tel tıkırtısı yok, çınlayan
komşu tel yok, perde vızıltısı yok. **Gerçek gitar bunların hepsinde daha zor.** Bu ölçüm
algoritmanın AYIRT ETME gücünü sabitler, gerçek dünya doğruluğunu değil — ses fixture
setinin kendi beyanıyla aynı sınır (`ostinato-audiofix-1`: "motorun DAVRANIŞINI sabitler").

**Sıradaki kanıt adımı:** birkaç gerçek açık-akor kaydı (kurucunun kendi gitarı yeter —
8 akor × 3 tekrar, telefonla). O ölçüm iyi çıkarsa `chord_correctness` V1'e girer ve Basic
Pitch sorusu hiç sorulmaz. Kötü çıkarsa soru **karşılaştırma verisiyle** kurucuya gider.

## Durum değişikliği

`chord_correctness`: **aspirational → engine.** Motoru var ve testli (61/61 paket testi,
9'u akor); girdisi ses olduğu için poz fixture'ında görünmüyor. "live" DEĞİL — o, gerçek
kayıt ölçümünü bekliyor.
