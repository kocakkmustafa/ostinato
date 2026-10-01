# Ostinato uygulama simgesi

## 2026-09-25 — koyu zemin düzeltmesi

Kurucu fiziksel iPhone'da açık lavanta dış zeminli rozetin yanlış olduğunu
belirtti: seçilen görünüm koyu mürdüm zeminde renkli vuruşları olan ritmik
`O`. Onaylı `D-rhythm-O-dark-selected-reference.png` görüntüsü değiştirilmeden
platform boyutlarına indirildi. iOS ana ekranı ve Android başlatıcı dış
köşeleri kendi simge maskeleriyle yumuşatır; dosyada açık renkli ikinci bir
dış zemin yoktur.

| Dosya | Kullanım |
|---|---|
| `D-rhythm-O-dark-selected-reference.png` | Onaylı 1254×1254 RGB kaynak |
| `D-rhythm-O-dark-App-Store-1024.png` | Güncel App Store 1024×1024 opak simge |
| `D-rhythm-O-dark-Google-Play-512.png` | Güncel Google Play 512×512 opak simge |

Bu kaynaktan iOS AppIcon kümesindeki 19 ve Android mipmap kümesindeki 5
dosya yeniden üretildi. Fiziksel cihaz ve mağaza geri okuması ayrıca gerekir.

## 2026-09-23 — tarihsel ara tasarım: ritmik O, açık dış zemin

Kurucu, ritmik O biçimini ve koyu mürdüm zeminli renk yönünü seçti. Son
görselde `O` işareti koyu mürdüm yuvarlak rozetin içindedir; dış köşeler
uygulamanın açık lavanta kabuk rengidir. Mağazaların kabul ettiği dosya
kare ve opaktır; yuvarlaklık görselin içindeki rozettir, platform maskesi
değildir. Şeftali, lila ve nane vuruşları üç çalgı kartının renk dilinden
gelir.

| Dosya | Kullanım |
|---|---|
| `D-rhythm-O-dark-selected-reference.png` | Seçilen koyu paletli ilk görsel; 1254×1254 RGB referans |
| `D-rhythm-O-round-master-1254.png` | Yuvarlak görünümlü kaynak görsel; 1254×1254 RGB |
| `D-rhythm-O-round-App-Store-1024.png` | App Store için 1024×1024 opak PNG |
| `D-rhythm-O-round-Google-Play-512.png` | Google Play için 512×512 opak PNG |

Bu ara görsel, 2026-09-24'te iOS AppIcon kümesindeki 19 ve Android mipmap
kümesindeki 5 simge dosyasına aktarılmıştı. 2026-09-25 koyu zemin düzeltmesi
bu aktarımın yerini aldı; mağaza yüklemesi ayrı doğrulama adımıdır.

## 2026-08-16 — D8 ikon adayları (O-158)

**Aile dili:** tek-renk zemin + tek beyaz glif (`YAYIN-YOLU-OSTINATO.md`:
*"lacivert zemin + beyaz glif (metronom/nota silueti)"*). Zemin: `#161C38`.

| Aday | Glif | Not |
|---|---|---|
| `A-note.png` | Çeyrek nota | Talimatın harfi harfine karşılığı; bayraklı (eighth-note) biçim küçük ikonda dengesiz çıktı, bayraksız çeyrek notaya sadeleştirildi |
| `B-metronome.png` | Metronom silueti | Talimatın ikinci seçeneği; temiz, tanınır, ama jenerik — sayısız pratik/metronom uygulaması aynı motifi kullanıyor |
| `C-posture-CHOSEN.png` | **SEÇİLDİ** — Ostinato'nun kendi postür figürü | Onboarding'de ZATEN kullanılan motifin AYNISI (omuz-gövde-kalça çizgisi + baş) — jenerik "müzik" değil, Ostinato'nun asıl farkı (postür) ile birebir |

## Neden C

Talimat "metronom/nota silueti" ÖNERİYORDU, KESİN ŞART koymuyordu. C, kendi
üründe zaten var olan bir görsel dili (bu turda çekilen `docs/store/
screenshots/`da her onboarding ekranında görünür) tekrar kullanıyor —
kurumsal kimlik + ürün-içi tutarlılık ikisi birden. A/B talimata daha
literal sadık alternatifler olarak burada duruyor; kurucu takas hakkını
saklı tutuyor (`orkestratör, D8 mesajı`).

**Uygulanan:** iOS AppIcon (15 dosya) + LaunchImage (3 dosya, storyboard
`backgroundColor`ı da navy'ye çevrildi) + Android `ic_launcher` (5 yoğunluk)
+ Android `launch_background.xml` (2 varyant, yeni `launch_image.png` +
`colors.xml`). Kanıt: `tools/validate_template_assets.py` — 25/25 varlık
Flutter'ın stok görsellerinden MD5-farklı, `run_gates.sh`a kalıcı gate
olarak eklendi.
