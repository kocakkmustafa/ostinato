# Ders yazım kılavuzu (v1)

**Tarih:** 2026-10-31 · **Dayanak:** `00-ders-format-sozlesmesi.md` (alanlar ve kurallar), kurs listeleri `10…40`.

Bu belge plan satırından ders dosyasına geçişi tarif eder. Sözleşmedeki bir kural burada tekrar edilmez, yalnız atıf yapılır.

---

## 1. Dosya

- **Yol:** `content/v1/<kurs>/<id>.json`. Kurs kodları `gtr`, `voc`, `pno`, `ear`.
- **Bir dosya = bir ders.** Kimlik plan satırındaki `id` ile aynıdır.
- **Örnekler:**
  - `content/v1/gtr/gtr-s1-m02-02.json`: mikrofon dersi (A2+A3), mevcut dersten yeniden kullanım.
  - `content/v1/ear/ear-s1-m01-01.json`: alkış dersi (A3), eşlikli.
  - `content/v1/ear/ear-s1-m01-03.json`: ekranda yanıt dersi (D, A0), üretilen alıştırma.
- Dosyalar henüz uygulamaya paketlenmez. Model: `lib/app/curriculum/v1_lesson.dart`.

### 1.1 Alanlar (JSON)

| JSON | Sözleşme §2 | Not |
|---|---|---|
| `id`, `title` | 1, 2 | `title` plan satırındaki "EN / TR" ile **birebir** |
| `goal` | 3 | Gözlemlenebilir fiil; plan satırındaki hedefin cilalı hâli |
| `explanation` | 4 | 3–6 madde; TR toplamı ≤400 kelime |
| `referenceAudio.kinds` | 5 | `S`, `SE`, `DR`, `KL`; D/Ö dersinde boş liste. `brief`: neyin sentezleneceği |
| `practice.measurement`, `.engineSteps` | 7, 8 | Plan satırındaki kodlar, **aynı sırayla** (`D+M` → `["D","M"]`) |
| `practice.task` | 6 | Öğrenciye görev metni |
| `practice.sequence` | 6.1 | Bilimsel perde; gitar sesli perde; ses kursunda derece (`1-2-3-2-1`) |
| `practice.tempo` | 6.3 | `{open, target}`; serbest tempoda alan yazılmaz |
| `practice.pass` | 6.2 | `{"levelDefault": true}` ya da `{"levelDefault": false, "text": {…}}`; D'de `minCorrect` |
| `practice.drill` | 3 (D) | Yalnız D derslerinde: `type`, `count`, `params` (§3) |
| `fallback` | 9 | Ölçümden türer: `selfCheck` (M), `held` (M!), `experimental` (M~), `camera` (K), `noEngine` (D/Ö) |
| `safety` | 10 | Kurs varsayılanı (`Ç`+`G1`/`V1`/`P1`/`E1`) + satırdaki ek kodlar |
| `prerequisites` | 11 | Boş liste = varsayılan kural (§9); yalnız istisna yazılır |
| `selfCheck` | 12 | Ö içeren derste 3–5 madde; diğerlerinde Ö yedeği için önerilir |
| `commonErrors` | 13 | 1–3 adet `{error, fix}`; `error` bir **ölçüm sonucu** dilinde |
| `adaptation` | 14 | Tek kolaylaştırma yolu |
| `repertoire`, `legacy` | 15, 16 | Varsa |
| `minutes` | 17 | 2–30 |
| `expertPending` | 6.2 | Öğretmen onayına kadar `true` |

## 2. Yazım kuralları

1. **"Yanlış / wrong" kelimesi yok** (§5.4). Ölçüm dili: *Doğru*, *Farklı nota*, *Duyamadım*, *Doğru, geç / erken*. Denetleyici bu kelimeleri reddeder.
2. **`commonErrors.error` bir ölçüm sonucuyla başlar.** Uygulama sonucu bu satıra bağlar. Örnek: "Farklı nota, yarım ses yüksek." → fix: "Parmak bir perde yukarı kaymış…"
3. **Nota adları:**
   - EN harf + oktav (E2).
   - TR solfej + oktav (Mi2). Mevcut kursla aynı.
   - Almanca/Lehçe B/H farkı katalog çevirisinde korunur.
4. **Kısa cümle.** Bir madde bir kavram ya da bir hareket.
   - Öğrenciye "sen" diye hitap edilir. Mevcut kursun tonu.
   - Emir kipi kullanılır: "bas", "dinle".
5. **Öğrenci kaydı yok.**
   - "Kendini kaydet / kaydını dinle" yazılmaz.
   - Yerine referansla karşılaştırma ya da yeniden ölçme konur (§11).
6. **Tıbbi iddia yok.** Güvenlik metni kodlardan gelir (§8). Ders gövdesinde yalnız o derse özgü bir uyarı yazılır.
7. **Telifli içerik yok** (§12). Özgün dizi ya da `60-kamu-mali-repertuvar.md` listesi kullanılır. Kamu malı dersleri hukuk onayı bekler.
8. **EN ve TR birlikte yazılır.**
   - Diğer 12 dil katalogdan gelir.
   - Her `{en, tr}` çifti bir mesaj kimliği üretir. Aynı cümleyi farklı derslerde birebir aynı yazmak çeviriyi yeniden kullanır.

## 3. D alıştırma türleri (`practice.drill.type`)

Sorular çalışma anında `params`'tan üretilir. Dosyada cevap anahtarı yoktur.

| Tür | Ne sorar | Örnek `params` |
|---|---|---|
| `tempo_compare` | İkinci parça hızlı mı, yavaş mı, aynı mı | `baseBpm`, `deltaPercent`, `allowSame` |
| `pitch_direction` | İki sesten hangisi yüksek; üç notalık kontur | `range`, `minSemitones`, `notes` |
| `same_different` | İki ses ya da iki ritim aynı mı | `range`, `maxCents` |
| `interval_name` | Aralığın adı | `intervals`, `direction`, `cadence` |
| `triad_quality` | Majör / minör (/ artık / eksik) | `qualities`, `inversions` |
| `scale_degree` | Tonda hangi derece | `key`, `degrees`, `cadenceEachQuestion` |
| `key_signature` | Donanımdan ton | `keys` |
| `note_name` | Portedeki ya da klavyedeki nota | `clef`, `range` |
| `rhythm_dictation` | Duyulan ritmi dokunarak yaz | `values`, `bars`, `bpm` |
| `melodic_dictation` | Duyulan ezgiyi porteye yaz | `notes`, `range`, `key` |
| `symbol_match` | Sembol ↔ ad / anlam | `set` |
| `diagram_match` | Gitar/klavye diyagramı ↔ ad | `set` |
| `ordering` | Adımları sıraya koy | `items` |

**Rakip kanıtından gelen kurallar** (`scratch/2026-10-31-rakip-analizi/ostinato/RAPOR.tr.md` (f)):
- Tonal alıştırmada kadans **her soruda** çalınır (S1 varsayılanı; `cadenceEachQuestion: true`).
- Yanlış seçimde "senin cevabın / doğrusu" metni gösterilir ve iki ses de dinletilir. Bu davranışın ekran metni de "farklı" dilini kullanır.
- Süre puanı yok (S1).

Yeni tür gerekirse `V1Drill.types` listesine ve bu tabloya birlikte eklenir.

## 4. İş akışı

1. Plan satırını oku: kodlar, satırdaki referans ve güvenlik kodları, `Mevcut` sütunu.
2. Mevcut ders varsa (`R:` / `V:`), metnini `assets/content/*.json`'dan al. `R:` derslerinde açıklama korunur, ölçülen pratik eklenir.
3. Dosyayı yaz. Ardından kontrolleri çalıştır:
   ```
   python3 tool/curriculum_lint.py --check
   flutter test test/v1_lesson_content_test.dart
   python3 tool/build_message_ids.py --pending content/v1
   ```
   - İlki plan bağını ve yasak kelimeyi denetler.
   - İkincisi alan biçimini denetler.
   - Üçüncüsü yeni kimlikleri ve dillerin eksiklerini listeler.
4. Bir dalga (modül ya da seviye) bitince:
   - örneklem okuması: dersin %10'u, en az 3 ders;
   - rapor satırı: `scratch/2026-10-23-ekip-dagitimi/raporlar/ostinato.tr.md`.
5. Açık sorulara bağlı dersler (`README.md` "Açık sorular") kurucu kararına kadar yazılmaz.
