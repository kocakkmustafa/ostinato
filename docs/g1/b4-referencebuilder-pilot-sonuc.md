# B4 — ReferenceBuilder Pilotu: İlk Ölçüm

**Tarih:** 2026-07-29 · **Araç:** `tools/dart_pilot` (motion_core-v0.2.1 tag-pinli) · **Veri:** 11 hasat fixture'ı (kabul edilen havuz), her birinden en durağan 90 kare (~3 sn)
**Soru:** Eğitmen videoları bizim standart açımızda çekilmiyor (ölçüldü: 0/11 sağ-ön-çapraz). O hâlde **hangi metrik hangi açı sınıfından beslenebilir** ve tolerans nereden gelir?

## 1. Yöntem

`ReferenceBuilder` üç şey yapıyor: aynalama konsensüsü, medoid seçimi (zaman tabanı), ve eğitmenler-arası **dağılım** hesabı. Bu son madde asıl mesele: **tolerans, eğitmenlerin birbirinden ne kadar ayrıştığıdır** — bizim uydurduğumuz bir sayı değil.

Konum `world` uzayından alındı (J-028/M-O-08 kararı), görünürlük ham `lm` girdisinden (world dizisi güven taşımıyor, güven kapısı onsuz çalışmaz).

## 2. Sonuç — eğitmenler arası medyan sapma

| Eklem | Sapma | Yorum |
|---|---|---|
| **trunk_tilt** | **3.0°** | En sıkı uzlaşma. Gövde dikliği üzerinde eğitmenler gerçekten hemfikir |
| left_upper_arm | 12.5° | Kullanılabilir |
| left_shoulder | 13.3° | Kullanılabilir |
| right_shoulder | 15.4° | Kullanılabilir |
| right_upper_arm | 25.0° | Sınırda |
| left_elbow | 29.6° | Sınırda |
| right_forearm | 31.7° | Sınırda |
| **right_elbow** | **39.2°** | ⚠️ güvenilmez |
| **left_forearm** | **58.8°** | ⚠️ güvenilmez |

**Çekirdeğin hükmü:** `right_elbow` ve `left_forearm` **güvenilmez** (>35°). Bu eklemlerde kullanıcıya hüküm verilmez — eğitmenler kendi aralarında anlaşamıyorsa tolerans uydurmak dürüstlük ihlalidir.

## 3. Bunun anlamı (yorum, ölçüm değil)

Sayılar tek başına "bu eklem kötü" demiyor; **bu havuzun** ne söyleyebileceğini söylüyor:

1. **Gövde dikliği W1'in en sağlam metriği.** 3° sapma, `voice@0.1.0-draft`'taki postür kurallarının veri temeli olabileceği anlamına geliyor — üstelik bu, üç farklı çalgının eğitmenlerinden gelen bir uzlaşma.
2. **Kol/önkol açıları bu havuzdan referans üretemez.** Beklenen bir sonuç: videolar farklı çalgılara ait (şan ayakta, piyano oturarak, gitar kucakta) ve kollar doğal olarak farklı yerlerde. **Doğru okuma: havuzu çalgı-başına ayırmadan kol metriği çıkarılamaz.** Şu anki havuz karışık olduğu için bu ölçüm, "çalgı-bağımsız kol referansı" fikrinin ölçümle reddidir.
3. **Sağ/sol asimetrisi anlamlı:** `left_forearm` 58.8° vs `right_forearm` 31.7°. Gitar/piyanoda iki el farklı işler yapar; bu, aynalama-agnostik kural yazma gereğinin (M-F-06) veri tarafındaki karşılığı.

## 4. Sonraki adım

- **Havuzu çalgı-başına ayır** ve pilotu tekrar koş; kol metriklerinin çalgı içinde uzlaşıp uzlaşmadığı asıl soru.
- Açı sınıfı ayrımı (B4'ün özü) şu an test edilemedi: havuzda **0 sağ-ön-çapraz** var; frontal (8) ve profil (3) karşılaştırması çalgı ayrımından sonra anlamlı olur.
- Hasat sürüyor; havuz büyüdükçe bu tablo yenilenir (araç tekrar koşulabilir: `dart run bin/pilot.dart`).

## 5. Süreç notu — kendi hatam

Pilot dosyaları ilk yazımda **paylaşımlı motion-core ağacına** düştü (kabuk cwd'si beklediğimden farklıydı). Fark edip taşıdım ve kaynağı sildim; motion-core'da iz kalmadı (`git status` temiz). Bu, ailenin M-016/M-O-03 sınıfının aynısı: paylaşımlı ağaca yabancı dosya bırakmak. Ders: paylaşımlı ağaç söz konusuysa **mutlak yol** kullan, göreli yola güvenme.
