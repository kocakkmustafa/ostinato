# F2.6 — Kulak drill ekranı (D bileşeni)

**Durum:** tasarım, 2026-11-03. PLAN-ONERISI F2.6; Yönetim sıralaması FK1 → F2.6 → K8 → FK3. FK1 (#39, #40, #42) referans çıkışını sağladı; drill sesi aynı yolu kullanır.

## Kapsam (içerikten sayım, main)

63 dersin `practice.drill` alanı var. Ders yazım kılavuzu §3, 13 tür tanımlar. Dosyada cevap anahtarı yoktur; sorular çalışma anında `params`'tan üretilir.

| Tür | gtr | ear | pno | S1 (ücretsiz) | Ses |
|---|---|---|---|---|---|
| diagram_match | 10 | 1 | 5 | gtr 3, pno 4 | ear: klavye notası |
| symbol_match | 3 | 2 | 4 | ear 2, pno 1 | yok |
| ordering | 1 | — | 1 | — | yok |
| note_name | — | 4 | 3 | ear 4, pno 2 | yok (porte) |
| pitch_direction | — | 3 | — | ear 3 | var |
| same_different | — | 1 | — | ear 1 | var |
| tempo_compare | — | 1 | — | ear 1 | var |
| interval_name | — | 5 | 2 | — | var |
| triad_quality | 1 | 1 | — | — | var |
| scale_degree | — | 1 | — | — | var + kadans |
| key_signature | — | 1 | — | — | yok (porte) |
| rhythm_dictation | — | 4 | — | — | var + dokunma girişi |
| melodic_dictation | — | 1 | — | — | var + porte girişi |

Kulak kursu uygulamada yok: yalnız `content/v1/gtr/` paketleniyor. Kulak kursunu açmak ayrı bir karardır (Yönetim, 2026-11-03: "ses ve drill gelince açılır") ve son dilimde sorulur.

## Ürün kuralları (kılavuz §3, rakip kanıtı)

- Tonal alıştırmada her soruda kadans çalınır.
- "Cevabımı çal": seçilen şık dinletilir.
- Farklı bir seçimde "senin cevabın / doğrusu" gösterilir, ikisi de dinletilir. Ekran metni "yanlış" demez; "farklı" dilini kullanır.
- Karıştırılan çift kuyruğu: karıştırılan çift (ör. M2/M3) oturumun sonunda tekrar sorulur.
- Süre puanı yok.
- Geçiş: oturumdaki ilk denemelerin %80'i (ders `pass.levelDefault`).

## Mimari

- **Üretici** (`lib/app/drill/`, saf Dart):
  - `DrillGenerator.forDrill(V1Drill, seed)` → `List<DrillQuestion>`.
  - Soru: istem, şıklar, doğru şık, şık başına ses tarifi.
  - Belirlenimli tohum; testte her tür için geçersiz `params` reddi.
- **Ses:** FK1 referans yolu (`ReferenceListenController` / staged output).
  - Tel modeli gitar sesleri için. Piyano sesi için basit sentez: toplanan harmonikler + ADSR, `reference_passage` gibi saf Dart.
  - Kadans I–IV–V–I.
- **Ekran:** `DrillScreen`: soru sayacı, Dinle / Tekrar, şıklar, geri bildirim, "cevabımı çal", sonuç ve geçiş. Sonuç `V1PracticeProgress`'e ölçülmüş drill olarak yazılır.
- **Kurs entegrasyonu:** `V1LessonAvailability.drillSoon` → `drill` (yalnız desteklenen türler).

## Dilimler (her biri ayrı PR; merge kuralı aynı)

1. **F2.6a:**
   - Üretici + ekran + sessiz görsel türler (`diagram_match`, `symbol_match`, `ordering`). Gitar kursunda 14 drill dersi açılır; gitar S1'den 3'ü.
   - Ses yok; çekirdek akış, geri bildirim dili ve ilerleme yazımı burada oturur.
2. **F2.6b:** sesli temel türler (`pitch_direction`, `same_different`, `tempo_compare`, `interval_name`, `triad_quality`).
   - Piyano sentezi, "cevabımı çal", karıştırılan çift kuyruğu.
   - Gitar `triad_quality` (gtr-s3) açılır.
3. **F2.6c:** porte türleri (`note_name`, `key_signature`), `scale_degree` + kadans.
4. **F2.6d:** dikte (`rhythm_dictation` dokunma girişi, `melodic_dictation` porte girişi).
5. **Kulak kursunun açılması:**
   - `content/v1/ear/` paketlenir, kurs listesi, ücretsiz S1. 14 katalog metni ayrıca.
   - Bu adım **Yönetim onayıyla** yapılır (mağaza/site metniyle tutarlılık).

## Kabul

- Her dilimde: üretici birim testleri (tohum, aralık, şık sayısı, cevap tekilliği), ekran widget testleri, 14 katalog, tam `flutter test`, simülatörde bir ders.
- Sesli türlerde gerçek cihazda duyulurluk dogfooding'e kalır.
