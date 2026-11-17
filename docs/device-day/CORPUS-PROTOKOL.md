# QA-OST-01 — gerçek kayıt corpus protokolü

Durum: **PROTOKOL + KURU KOŞU; kayıt yapılmadı, tanıma sonucu yok.** Backlog kabulü: gerçek kayıt corpus'u; tanıma oranı + onset hatası raporu. Gün akışındaki yeri: corpus kaydı ≈40 dk ([`README.md`](README.md)). Kurucu çalar; Ostinato kayıtların doğru klasöre düşmesini sağlar. İşaret kuralı: **önerilen** = bu belgenin önerisi, onay bekler; **doğrulanacak** = kodla kapatılamadı.

## 1. Bugünkü durum (koddan ve dosyalardan okundu)

| Küme | Dosyalar | Kaynak | Ses dosyası |
|---|---|---|---|
| `AF-R001..R010` | `fixtures/audio-real/AF-R001-piano-a1.json` … `AF-R010-piano-b7.json` | Iowa MIS piyano (kamu verisi, "without restriction") | **git dışı**, indirilir |
| `AC-R001..R034` | `fixtures/audio-real/AC-R001-guitar-d-sharp-1.json` … `AC-R034-…` | GuitarSet, CC-BY-4.0 (kamu verisi) | **git dışı**, indirilir |

Yani mevcut `R` kümeleri **kurucunun kaydı değil, kamu verisidir**. Cihaz günü kaydı **yeni bir kümedir** ve mevcut JSON'lara dokunmaz (`D` = cihaz günü; `R` ile çakışmaz).

### Ses dosyaları git dışında nasıl tutulur (`.gitignore` 15-30, ilgili araçlar)

- `.gitignore`: `fixtures/audio-real/raw/`, `fixtures/audio-real/*.wav`, `fixtures/audio-real/*.aiff` ve yerel koşum çıktıları (`replay-report.json`, `snr-report.json`, `chord-report.json`, `chord-snr-report.json`) izlenmez; yalnız `fixtures/audio-real/*.json` (beklenen değer, tolerans, kaynak bilgisi) izlenir.
- Piyano: `tool/fetch_audio_fixtures.sh` ham AIFF'i indirir ve **kaynak AIFF'in SHA-256'sını betikte sabitlenmiş değerle doğrular**; `tool/prepare_audio_fixtures.dart` doğrulanmış AIFF'ten mono/kırpılmış WAV türetir (türetilmiş WAV'ın kendi özeti **sabitlenmez**, betik başlık notu).
- Gitar akoru: `tool/fetch_guitarset_fixtures.py` + `tool/prepare_guitarset_fixtures.dart`; kaynak ZIP girdileri SHA-256 ile sabitlenmiştir.
- `tools/fixture_check.py` ses özetlerini doğrulamaz (pose/metrik motoru sınıflandırması); bu iş için kullanılmaz.
- **Kurucu kaydı için doğrulayan araç yoktur** (kamu verisi gibi bir kaynak adresi yok). Önerilen: özet dosyası `fixtures/audio-real/DEVICE-DAY-SHA256.txt` (izlenir; yalnız özetler, ses değil), kayıttan hemen sonra `shasum -a 256 fixtures/audio-real/*-D*.wav > fixtures/audio-real/DEVICE-DAY-SHA256.txt` ile üretilir, doğrulama `shasum -a 256 -c fixtures/audio-real/DEVICE-DAY-SHA256.txt` (`.wav` dosyaları ignore'lu olduğu için git'e girmez). Asıl kayıtların kopyası repo dışında bir yedekte tutulur (yer: kurucu karar verir, **doğrulanacak**).

## 2. Klasör yapısı ve dosya adı kuralı

Hepsi `fixtures/audio-real/` içinde, mevcut düz yapıda (alt klasör yok; araçlar yalnız bu klasörü tarar).

Mevcut kalıp: `AF-Rnnn-<enstrüman>-<not>.wav` (piyano), `AC-Rnnn-<enstrüman>-<akor>.wav` (gitar akoru). Önerilen yeni kalıp **aynı biçim, `R` yerine `D`**, yüzler basamağı enstrüman:

| Önek | Anlam | Taranır mı | Örnek |
|---|---|---|---|
| `AF-D<e><nn>-<enstrüman>-<not>` | tek nota (akort) ve onset | `tool/audio_fixture_replay.dart` (`AF-*.json`) | `AF-D101-guitar-e2.wav` |
| `AC-D<e><nn>-<enstrüman>-<akor>` | akor | `tool/guitarset_chord_replay.dart` (`AC-*.json`) | `AC-D101-guitar-c-major.wav` |
| `AR-D<e><nn>-<enstrüman>-<desen>` | ritim (çok onset) | **Araç yok** (bkz. §4) | `AR-D101-guitar-q80.wav` |

`<e>`: 1 = birinci enstrüman, 2 = ikinci, 3 = üçüncü. Her WAV'ın yanında aynı adlı `.json` (izlenir). Dosya adı küçük harf, boşluk yok.

## 3. Örnek listesi: 3 enstrüman × 10 kısa örnek

Enstrüman seçimi: önerilen **1 gitar** (kurs açık; kodda `ostinatoOpenInstruments = {'guitar'}`), **2 piyano/klavye** (mevcut Iowa karşılaştırması için), **3 kurucunun getirdiği üçüncü çalgı (ör. ukulele)**. **Doğrulanacak: kurucu üç çalgıyı gün sabahı kesinleştirir**; ses (vokal) seçilirse akor satırları yapılmaz ve kısa bir nota satırıyla değiştirilir.

Her enstrüman için 10 örnek: 4 akort (tek nota), 3 ritim, 3 akor. Süre: tek nota ≈3 sn (mevcut `AF-R` ile aynı), akor ≈1,2 sn tutuş, ritim 8-10 sn.

| # | Tür | Örnek (enstrüman 1: gitar) | Önerilen kimlik | Mevcut JSON ile ilişki |
|---|---|---|---|---|
| 1-4 | Akort: açık teller E2, A2, D3, G3 | tek nota, serbest sönüm | `AF-D101..D104` | Yeni JSON gerekir. `AF-R` piyano notalarıyla çakışmaz; şema `ostinato-audiofix-1` |
| 5-7 | Ritim: dörtlük 80 bp/dk, dörtlük 120 bp/dk, sekizlik 100 bp/dk (metronom kulaklıkla) | tek vurgulu telin tekrarı | `AR-D101..D103` | Mevcut karşılığı yok; şema ve araç yok (§4) |
| 8-10 | Akor: C majör, G majör, A minör | tam akor, ≈1,2 sn | `AC-D101..D103` | `AC-R` kayıtları yalnız majör (GuitarSet); minör kapsamı yok, bu satır onu kapatır. Şema `ostinato-audiofix-chord-1`; minör için `expected.chordName` yazımı (ör. `Am`) **doğrulanacak** (`ChordTemplate.name`, `chord_detector.dart`) |

Enstrüman 2 (piyano): akort C3, A3, C4, A4 → `AF-D201..D204`; ritim → `AR-D201..D203`; akor C, G, Am → `AC-D201..D203`.
Enstrüman 3 (ör. ukulele): akort G4, C4, E4, A4 (açık teller) → `AF-D301..D304`; ritim → `AR-D301..D303`; akor C, G, Am → `AC-D301..D303`.

Not: `AF-R` notaları ve `AC-R` akorları kamu verisinden yeniden üretildiği için ilişki yalnız **karşılaştırmadır** (aynı motor, aynı tolerans); yeni kayıtlar onların yerine geçmez ve onların JSON'larını değiştirmez.

## 4. JSON içeriği ve sınırlar

- Her `AF-D…json` için `AF-R001-piano-a1.json` kalıbı: `schemaVersion: ostinato-audiofix-1`, `fixtureId`, `kind`, `audio`, `recordingMeta` (kaynak: `device-day`, cihaz, oda, mikrofon mesafesi, örnekleme hızı, lisans/sahiplik beyanı), `expected.f0Hz` (12-TET, A4=440 Hz, nota adından türetilir) ve `expected.onsetMs`, `tolerances`, `labels`.
- **Tolerans (JSON'dan doğrulandı, 10/10 `AF-R`):** `centsMedian = 10`, `centsP95 = 20`, `onsetMs = 30`. Yeni kayıtlar için aynı değerler kullanılır; gevşetmek bir karar işidir.
- **Onset referansı:** `expected.onsetMs` kayıttan elle işaretlenir (ses düzenleyicide dalga biçiminden). Aynı dedektörün çıktısından türetilirse ölçüm döngüsel olur; bu yüzden `labels.annotator` alanına yöntem yazılır. Önerilen.
- **Biçim:** `tool/audio_fixture_io.dart` yalnız **16-bit PCM WAV** okur (başka biçimde `FormatException`); 24-bit kayıt **önce 16-bit'e çevrilmelidir** (replay doğrudan çalışmaz). Örnekleme 44,1 ya da 48 kHz (uygulamanın akort denetleyicisi `{44100, 48000}` kabul eder); mono önerilir (stereoysa araç mono'ya indirir).
- **Piyano aralığı sınırı:** `audio_fixture_replay.dart` aralığı 25-4200 Hz'e sabitlemiştir; bu aralık dışındaki beklenen frekans `out_of_range` raporlanır (gitar/ukulele/piyano notaları içeridedir).
- **Ritim (`AR-D…`):** mevcut replay tek `onsetMs` karşılaştırır; çok onsetli desen için şema ve araç **yoktur**. Önerilen: ritim kayıtları gün içinde alınır ve WAV olarak saklanır; JSON'ları araç/şema belli olunca yazılır (gün sonrası ayrı bilet). Ritim satırlarının tanıma oranı raporda "ölçülemedi (araç yok)" yazılır.
- Fixture JSON'ları ve `DEVICE-DAY-SHA256.txt` izlenir; ses dosyaları ve `*-report.json` izlenmez.

## 5. Kayıt koşulları

Her koşulu kayıt başına JSON `recordingMeta` içine yaz.

| Koşul | Önerilen |
|---|---|
| Oda | Sessiz, halı/perde içeren oda; klima, buzdolabı kapalı; ölçülen gürültü tabanı (dBFS, 5 sn sessizlik kaydı) notlanır |
| Mikrofon | Birincil: uygulamanın dinleyeceği **telefonun dahili mikrofonu** (cihaz 1), cihaz modeli yazılır. İsteğe bağlı ikinci kayıt: harici mikrofon (referans) |
| Mesafe | Çalgı ağzı/kasası ile telefon alt kenarı arası 30 cm (gitar, ukulele); piyano için 50 cm; mesafe ölçülüp yazılır, her örnekte aynı |
| Biçim | 44,1 ya da 48 kHz, mono, **16-bit PCM WAV** (araç sınırı, §4); sıkıştırma yok, otomatik kazanç ve gürültü bastırma kapalı (iOS "Sesi Kaydet" yerine kayıt uygulamasının ham modu; ayar adı **doğrulanacak**) |
| Gürültü tabanı | Her kayıt oturumunda 5 sn "oda sessizliği" (`AF-002-room-noise-only` türünden) ayrıca alınır; ad: `NZ-D<e>00-<enstrüman>-roomnoise.wav` (önerilen; `NZ-` öneki replay araçlarının taramasına girmez, JSON'u olmaz) |
| Tekrar | Örnek başına bir iyi alış; bozuk alış yenilenir, bozuk dosya saklanmaz ya da ayrıca etiketlenir |
| Mahremiyet | Yalnız çalgı sesi; konuşma yok. Kayıtlar repoya girmez |

## 6. Rapor şablonu (tanıma oranı + onset hatası)

Dosya: `docs/device-day/reports/QA-OST-01-<tarih>.md`. Üretim: `dart run tool/audio_fixture_replay.dart` (tek nota; `fixtures/audio-real/replay-report.json`), `dart run tool/guitarset_chord_replay.dart` (akor; `chord-report.json`). Ham JSON raporları ignore'ludur; sayılar bu markdown'a taşınır.

```
# QA-OST-01 raporu — <tarih>
- Derleme/SHA, motor: YinPitchSource (ostinato_audio), AudioConfidenceGate
- Kayıt koşulu özeti: oda, cihaz, mesafe, örnekleme, gürültü tabanı

| Kimlik | Tür | Beklenen | pitch cents medyan | cents p95 | judged % | onset hatası ms | Sonuç |
|---|---|---|---|---|---|---|---|
| AF-D101-guitar-e2 | akort | 82,41 Hz | | | | | pass/fail/skipped |

Özet:
- Akort: geçti __ / kaldı __ / atlandı __ / aralık dışı __ (toplam 12)
- Tanıma oranı (akort) = geçti / (geçti + kaldı)  : __ %
- Akor: doğru akor oranı (pencere düzeyinde ve örnek düzeyinde): __ / __ (replay akor raporu)
- Onset: medyan |hata| __ ms, p95 __ ms, eşik 30 ms; eşik içi oran __ %
- Ritim: ölçülemedi (araç/şema yok)
- Eşikler: centsMedian 10, centsP95 20, onsetMs 30
- Başarısız örneklerin nedeni (oktav hatası, düşük güven, gürültü) ve çalınan ses dosyası yolu
```

Kabul eşiği (örnek sayısı, yüzde) bu belgede **belirlenmez**; kurucu/Motion koyar. Ham sayılar raporlanır.

## 7. Kuru koşu kanıtı (2026-11-18, bu çalışma ağacı)

Komut (depo kökünden, `flutter pub get` sonrası; sır yok, ağ yok):

```
dart run tool/audio_fixture_replay.dart
```

Sonuç: **çıkış kodu 0.** Çıktının kısaltılmış hâli:

```
⏭  AF-R001-piano-a1 — SKIP (ses dosyası yok, fetch/prepare koşulmadı)
...
⏭  AF-R010-piano-b7 — SKIP (ses dosyası yok, fetch/prepare koşulmadı)
→ 0 geçti · 0 kaldı · 0 desteklenmiyor · 10 atlandı (10 toplam)
→ öz-test (bilinçli bozguna tepki verdi mi): ✓ EVET
→ rapor: fixtures/audio-real/replay-report.json
```

`replay-report.json` özeti: `pass 0, fail 0, outOfRange 0, skipped 10, total 10, selfTestCaughtCorruption true`. Yani araç çalışıyor, 10 `AF-R` fixture'ı tarıyor ve ses dosyası olmadığı için hepsini adıyla `skipped` raporluyor; **tanıma sonucu yoktur**. Öz-test, probe ses dosyası (`AF-R003-piano-c4.wav`) olmadığında `true` döner (kodda öyle tanımlı); bu yüzden bu koşu kapının **kör olmadığını** kanıtlamaz, yalnız aracın başladığını ve kapandığını kanıtlar.

`git status`: oluşan `fixtures/audio-real/replay-report.json` `.gitignore:26` kuralıyla izlenmez ve commit'e girmez (`git check-ignore -v` ile doğrulandı). Akor aracı (`guitarset_chord_replay.dart`) ve yeni `D` kümesi için koşu **yapılmadı**.
