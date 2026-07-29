# W1 spike'ları — lisans katalog-§0 denetimi

**Tarih:** 2026-07-29 · **Prosedür:** `motion-core docs/10-ARAC-KATALOGU.md §0`
(1) LICENSE birincil kaynaktan okunur → (2) §0 süzgeci → (3) DEFTER M-kaydı → (4) katalog güncellenir.
**Kapsam:** W1'in iki spike bağımlılığı. Katalog §4 pitch'i kapsıyor ama bu ikisini kapsamıyordu.

---

## Özet

| Bağımlılık | Kod lisansı | Ağırlık/veri | §0 hükmü |
|---|---|---|---|
| `flutter_midi_command` | **BSD 3-Clause** | — | ✅ **BENİMSENEBİLİR** |
| Spotify **Basic Pitch** | **Apache-2.0** | ⚠️ eğitim verisi **CC BY-NC-SA** | ⚠️ **KURUCU KARARI** |

---

## 1. `flutter_midi_command` — ✅ temiz

BSD 3-Clause ([LICENSE](https://raw.githubusercontent.com/InvisibleWrench/FlutterMidiCommand/master/LICENSE)):
copyleft yok, ticari kullanım kısıtsız, yalnız telif bildirimi + garanti reddi + isim-kullanmama şartı.
§0'ın güvenli listesi BSD'yi zaten sayıyor (camera/Pigeon ile aynı sınıf).

**Hüküm:** piyano MIDI modu spike'ı lisans açısından açık. Kalan sorular teknik
(iOS/Android MIDI cihaz keşfi, gecikme) ve spike'ın kendi işi.

---

## 2. Basic Pitch — kod temiz, **ağırlık zinciri değil**

### 2a. Kod: Apache-2.0 ✅
[LICENSE](https://raw.githubusercontent.com/spotify/basic-pitch/main/LICENSE) — ticari kullanım
serbest, atıf + değişiklik bildirimi şartı. §0 güvenli listesiyle uyumlu.

### 2b. Ağırlıklar: non-commercial veriyle eğitilmiş ⚠️

Model, ICASSP 2022 çalışmasında **Slakh, MAESTRO, MedleyDB stems, GuitarSet** ve vokal veriyle
eğitildiği belirtiliyor. Bunlardan **ikisi non-commercial**:

| Veri seti | Lisans |
|---|---|
| **MedleyDB** | **CC BY-NC-SA 4.0** — "non-commercial research use only" |
| **MAESTRO** | **CC BY-NC-SA 4.0** (Google LLC) |
| GuitarSet | CC BY (varyant teyit edilmedi — izin verici görünüyor) |
| Slakh | Lakh MIDI türevi (teyit edilmedi) |

README ne eğitim verisini ne de ağırlıklar için ayrı bir lisans şartını belirtiyor;
ağırlıkları paketin Apache-2.0 kapsamında sayıyor.

### 2c. §0 bunu tam olarak öngörmüş

> ⚠️ **Veri seti lisansı ≠ kod lisansı** — Fine-tune edilen model "türev eser" riski taşır.
> Non-commercial veri setiyle SHIP EDİLEN model eğitilmez.

Bu vaka LocateAnything-3B (M-F-14) ve SMPL kalıbının **daha ince** bir hâli: orada lisans
metni doğrudan "non-commercial" diyordu, burada **kod izin verici ama üretim zinciri
non-commercial veriye dayanıyor.** "Popüler = güvenli DEĞİLDİR" kuralının tam hedefi.

### 2d. Karşı argümanlar — dürüstlük gereği ikisini de yazıyorum

Bu vakayı tek yönlü sunmak yanlış olur; **aleyhte olmayan** noktalar:

- **Biz fine-tune ETMİYORUZ.** §0'ın yasağı "non-commercial veriyle SHIP EDİLEN model
  *eğitilmez*" diyor; burada Spotify'ın önceden eğitilmiş ağırlığını gömüyoruz.
- **Spotify ticari bir şirket** ve ağırlıkları bilerek Apache-2.0 ile yayımladı; yani
  dağıtma hakkını kendisi iddia ediyor.
- **Hukuki soru gerçekten yerleşik değil:** model ağırlığının eğitim verisinin "türev eseri"
  olup olmadığı tartışmalı bir alan. Kesin bir ihlal iddia etmiyorum.

Ama risk taşıyıcısı değişiyor: **Spotify kendi dağıtımı için karar verdi; biz gömersek onun
iddiasına yaslanmış oluruz.** §0'ın ruhu bu tür devri sessizce yapmamayı söylüyor ve
"para/lisans gerektiren her karar kurucuya" diyor.

### 2e. Kapsam bulgusu — spike'ın tanımı zaten yanlıştı

Kuyruktaki iş "**Basic Pitch TFLite/CoreML dönüşümü**" olarak yazılıydı. Oysa Basic Pitch
**dönüşümleri zaten yayınlıyor**: "the original TensorFlow model and the TensorFlow model
converted to CoreML, TensorFlowLite, and ONNX" (macOS'ta varsayılan CoreML, Linux'ta TFLite).

Yani spike'ın *dönüşüm* bacağı yok hükmünde. Gerçek açık sorular:
1. **lisans zinciri** (yukarıdaki kurucu kararı),
2. **cihaz-üstü performans** (çok-sesli çıkarım + pose/hand ile aynı anda — bütçe ölçülmedi),
3. **akor sınıflandırma doğruluğu** gitar aralığında ve gerçek oda kaydında.

Dönüşüm zamanını 2 ve 3'e aktarmak spike'ı ucuzlatır.

---

## 3. Kurucu kararı gerekirse — alternatif merdiveni

Kurucu Basic Pitch'i **istemezse** akor tanıma ölmez, ucuzlar:

1. **Kendi kromagram + akor-şablonu eşleştiricimiz** (ML yok, lisans sorunu yok, tamamen
   bizim). Klasik yöntem: 12-boyutlu kroma → majör/minör/7'li şablonlarıyla korelasyon.
   Doğruluk Basic Pitch'in altında ama **açık akor drill'i** için yeterli olabilir —
   V1 kapsamı zaten "open_chord_drill", tam polifonik transkripsiyon değil.
   Ölçmeden taahhüt yok; ses fixture setimiz (`ostinato-audiofix-1`) bunu sınamaya hazır.
2. **Kendi modelimizi ticari-kullanılabilir veriyle eğitmek** (GuitarSet CC BY ise uygun) —
   pahalı, W1 kapsamı dışı.
3. **Akor sınıfını V1'den çıkarmak.** `chord_correctness` metriği zaten
   `fixture_check`'te *aspirational* sınıfında; config söz veriyor, ürün bugün tutamıyor.
   Kesmek dürüst bir seçenek.

**Önerim:** kurucuya (1)'i ölçüp sonucu göstermek, sonra Basic Pitch kararını *gerekliyse*
sormak. Ölçmeden lisans riski devretmek, elde kanıt yokken risk almak olur.

---

## 4. Kayıt

- DEFTER: M-O-33 (Basic Pitch ağırlık zinciri) · M-O-34 (flutter_midi_command temiz + kapsam bulgusu)
- Katalog §4/§0 güncellemesi **koordinatörden istendi** — `motion-core/lib/docs` çekirdek alanı,
  buradan yazılmaz.

**Kaynaklar:**
[basic-pitch LICENSE](https://raw.githubusercontent.com/spotify/basic-pitch/main/LICENSE) ·
[basic-pitch README](https://github.com/spotify/basic-pitch) ·
[MedleyDB (Zenodo)](https://zenodo.org/records/1715175) ·
[MAESTRO](https://magenta.withgoogle.com/datasets/maestro) ·
[GuitarSet](https://github.com/marl/GuitarSet/blob/master/LICENSE) ·
[FlutterMidiCommand LICENSE](https://raw.githubusercontent.com/InvisibleWrench/FlutterMidiCommand/master/LICENSE)
