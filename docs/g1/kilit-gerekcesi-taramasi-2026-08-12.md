# Kilit gerekçesi taraması — 10 kilitli ders (2026-08-12)

**Soru (koordinatör, JabLab emsali):** her kilitli dersin `lockedReason`ı
TEK engel mi yazıyor? O engel kalksa ders GERÇEKTEN açılır mı, yoksa
arkasında ikinci, adlandırılmamış bir mekanizma daha mı var?

**Yöntem:** her dersin `lockedReason` (prosa) ve `_why_locked_source` /
`_why_locked_detail` (yapısal iz, 8/10 derste var) alanları okundu.
İkincisi prosa metnin ARKASINDAKİ mekanik kaynağı taşıyor — burada asıl
bulgular bu alanlarda çıktı.

## 🔴 İki gerçek çift-engel bulundu

### `piano.foundations.five_finger`

`lockedReason` zaten iki engel sayıyordu (mikrofon yok + öğretmen
zamanlama verisi yok). Ama `_why_locked_detail` ÜÇÜNCÜ bir katman
açıyor:

> *"M-O-65: PLAY fazının note_timing_ms kalite kapısı İNDİRİLDİ. İki
> kusur üst üsteydi — (1) kapı ÜRETİLMEYEN bir metriğe bakıyordu, (2)
> bar (50ms) UYDURMAYDI. Şimdi metrik gerçekten ölçülüyor (AF-008) ama
> bar hâlâ yok: **postür referansı EKLEM ölçer, zamanlama ölçmez.**"*

**Anlamı:** mikrofon eklenip öğretmen zamanlama verisi toplansa BİLE,
bu ders açılamaz — çünkü tolerans bandını üretecek referans-inşa hattı
(bugün ben de piyano için koşturduğum `ReferenceBuilder`) yalnız EKLEM
AÇISI ölçer, ZAMANLAMA ölçmez. Zamanlama toleransı için ayrı bir
referans-inşa yolu gerekir — mevcut boru hattının bir uzantısı değil,
KATEGORİK olarak farklı bir ölçüm türü.

### `piano.foundations.shoulder_tension`

`lockedReason`: *"what we measure is an ANGLE"* (açı ölçüyoruz, ama
öğretmenler kendi aralarında anlaşamıyor). `_why_locked_source` bunun
ALTINDA farklı bir şey söylüyor:

> *"piano.honesty.notMeasured (shoulder tension, 5 kanal, 24 vs 5
> derece) + comingSoonInThisDiscipline[2] (**'needs a shoulder-height
> metric we do not have'**)."*

**Anlamı:** bugünkü B4 pilotu (O-093/O-094/O-095) tam olarak AÇI
uzlaşımını ölçtü — ve uzlaşım bulunamadı (heterojenlik açıklanamadı).
Ama bu alan, dersin GERÇEK ihtiyacının açı değil **YÜKSEKLİK** metriği
olduğunu söylüyor — sistemde HİÇ YOK, inşa edilmemiş, kategorik olarak
farklı bir ölçüm. **Yani bu ders İKİ bağımsız engel taşıyor: (a) mevcut
açı verisinde uzlaşım yok (bugün ölçüldü) VE (b) doğru metrik zaten açı
değil yükseklik — (a) çözülse bile (b) hâlâ dururdu.** Bugünkü pilot
çalışması (a)'yı test etti ve doğru sonucu buldu (uzlaşım yok), ama
dersin asıl kilidi muhtemelen (b)'dir — çift mekanizma, ikisi de ölü.

## ✅ Sekiz ders — tek mekanizma, ikinci gizli engel BULUNAMADI

| ders | kaynak | değerlendirme |
|---|---|---|
| `guitar.foot_support` | (yapısal iz YOK — yalnız prosa) | Tek stated engel (bacak landmark'ı yok); iz alanı eksik, ayrı bir bulgu (aşağı bkz.) |
| `guitar.open_chords` | (yapısal iz YOK — yalnız prosa) | Tek stated engel (gerçek sesle hiç sınanmamış); iz alanı eksik |
| `guitar.strum_timing` | `_why_locked_source` | **Zaten kendi metninde çift-engel diyor** ("Blocked twice over") — gizli değil, şeffaf |
| `guitar.chords_beyond_eight` | `_why_locked_source` | Tek engel (28/29 pencere ölçümü); "sayılar satırdan alındı, yeniden ölçülmedi" notu var ama ikinci BAĞIMSIZ engel değil |
| `voice.sustained_note` | `_why_locked_detail` | Tek engel (sentetik girdi, gerçek seste hiç sınanmamış) |
| `voice.vibrato` | `_why_locked_source` | İki kaynak ama kendi metni "ikisi de AYNI engeli söylüyor" diyor — tek mekanizma |
| `voice.knees_and_chin` | `_why_locked_source` | İki kaynak, aynı şekilde AYNI engel (eksik landmark) |
| `piano.hands_and_wrists` | `_why_locked_source` | İki kaynak, aynı engel (el landmark'ı yok) |

## ⚠️ Yan bulgu: iki dersin yapısal izi YOK

`guitar.foot_support` ve `guitar.open_chords` — 10 kilitli dersin
SEKİZİ `_why_locked_source`/`_why_locked_detail` taşırken bu ikisi
yalnız prosa `lockedReason`a sahip, makine-okur bir kaynağa
bağlanmıyor. Bu, ikinci bir gizli engel OLDUĞU anlamına gelmez — ama
iddianın izlenebilirliği diğer sekizden zayıf. Adıyla not edildi.

## Sonuç

10 kilitli dersin **2'sinde** (`five_finger`, `shoulder_tension`)
gerçek, önceden adlandırılmamış bir ikinci/üçüncü mekanizma bulundu —
ikisi de PİYANO'da, ikisi de "referans-inşa hattı yanlış METRİK
TÜRÜNÜ ölçüyor" sınıfında (zamanlama vs eklem, yükseklik vs açı).
**8'inde** ikinci mekanizma aranıp bulunamadı (ya zaten şeffaf çift-
engel ya da gerçekten tek engel). **2'sinde** (`foot_support`,
`open_chords`) izlenebilirlik eksik, ayrı not edildi.

Bu belge hiçbir dersi açmaz/kapatmaz — yalnız ölçüm.
