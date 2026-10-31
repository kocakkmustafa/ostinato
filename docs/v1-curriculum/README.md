# Ostinato v1 müfredat planı

**Tarih:** 2026-10-31 · **Durum:** taslak, kurucu + müzik öğretmeni + hukuk incelemesi bekliyor
**Dayanak:** Kurucu kararları (31 Eki 2026): tek uygulama odağı Ostinato; v1 kapsamı ~690 ders; birinci taraf kayıt yok; kamera yalnız S1 duruş; pratik ekranda, nota başına mikrofon geri bildirimi (doğru / farklı nota / duyamadım).
**Kaynak araştırma:** `scratch/2026-10-31-ostinato-derin/` (0 ürün önerisi, 1 talep ve müfredat §2–§5, 3 teknoloji §4). Mevcut dersler: `assets/content/*.v1.json`, `assets/content/library.json`.

Bu klasör yalnız **plan ve sözleşme** içerir: ders gövde metni, uygulama kodu ve içerik JSON'u yok.

---

## Sayılar

| Kurs | Seviye | Hedef | Yazılan ders | Öğrenci yolu | Mevcut içerikten | Yeni |
|---|---|---|---|---|---|---|
| Gitar | S1–S4 (S4'te Akustik/Fingerstyle ve Elektro/Lead kolları) | ~240 | **240** (40 · 60 · 60 · 80) | 221 (S4: 42 ortak + 19 kol) | 68 | 172 |
| Ses / Şan | S1–S4 | ~240 | **240** (40 · 60 · 60 · 80) | 240 | 24 | 216 |
| Piyano / Klavye | S1–S3 (mikrofonla ölçülebilir) | ~160 | **160** (40 · 60 · 60) | 160 | 28 | 132 |
| Kulak & Müzisyenlik | S1–S2 (ücretsiz giriş, ortak) | ~50 | **50** (25 · 25) | 50 | 0 | 50 |
| **Toplam** | | **~690** | **690** | **671** | **120** | **570** |

- Sayılar hedefle **birebir** aynı. Tek sapma kavramsal: gitarda "yazılan" (240) ile "öğrencinin gördüğü" (221) farklı, çünkü S4'te iki kol ayrı yazıldı. Gerekçe `10-gitar.md` başında.
- 15 seviye testi ders sayısına dahil (gitar 5, ses 4, piyano 3, kulak 2). Yerleştirme testi dahil değil.
- Mevcut 107 yazılı dersin 76'sı yeniden kullanıldı, 28'i revize edildi, 3'ü emekli. Kamera kurslarının 28 dersinin 20'si S1 kurulum derslerine birleşti, 8'i emekli.

## Ölçüm dağılımı

| Ölçüm | Gitar | Ses | Piyano | Kulak | Toplam |
|---|---|---|---|---|---|
| `M` mikrofon (Ö'ye düşebilir) | 209 | 200 | 122 | 24 | 555 |
| `M!` mikrofon, zorunlu (geçiş, test, kalibrasyon) | 27 | 24 | 16 | 7 | 74 |
| `M~` deneysel (piyano çok sesli; MIDI ile kesin) | — | — | 14 | — | 14 |
| `D` ekranda yanıt | 1 | 12 | 4 | 19 | 36 |
| `Ö` öz-kontrol | 1 | 3 | 2 | — | 6 |
| `K` kamera (yalnız S1) | 2 | 1 | 2 | — | 5 |

Mikrofonla ölçülen ders oranı **%93** (643/690). Motor adımlarına göre döküm: `70-motor-bagimliligi.md`.

## Dosyalar

| Dosya | İçerik |
|---|---|
| [00-ders-format-sozlesmesi.md](00-ders-format-sozlesmesi.md) | Ders format sözleşmesi: alanlar, ölçüm türleri, motor adımları, üç sonuç, geçiş ölçütleri, referans ses, güvenlik kodları, ön koşul, gizlilik |
| [10-gitar.md](10-gitar.md) | Gitar S1–S4, 240 ders |
| [20-ses.md](20-ses.md) | Ses S1–S4, 240 ders |
| [30-piyano.md](30-piyano.md) | Piyano S1–S3, 160 ders, "tek yeni nota" kuralı |
| [40-kulak-muzisyenlik.md](40-kulak-muzisyenlik.md) | Kulak & Müzisyenlik S1–S2, 50 ders, çalgı kurslarına bağlantılar |
| [50-seviye-ve-yerlestirme-testleri.md](50-seviye-ve-yerlestirme-testleri.md) | 15 seviye testi ve yerleştirme testi |
| [60-kamu-mali-repertuvar.md](60-kamu-mali-repertuvar.md) | Kamu malı eser listesi, besteci yaşam yılları, edisyon uyarıları |
| [70-motor-bagimliligi.md](70-motor-bagimliligi.md) | Motor adımı başına ders sayısı, gecikme senaryoları, motor gereksinimleri |
| [80-mevcut-ders-eslemesi.md](80-mevcut-ders-eslemesi.md) | Mevcut 135 dersin (107 yazılı + 28 kamera) R/V/X eşlemesi |

## Bu planda alınan tasarım kararları

1. **Ders kimliği** `<kurs>-s<seviye>-m<modül>-<sıra>`; mevcut kimlikler (`guitar.journey.*`, `piano-NN`, `vocal-NN`) ilerleme göçü için `legacy` alanında tutulur.
2. **`D` (ekranda yanıt) ölçüm türü eklendi.** Kulak/teori sorularını Ö'den ayırmak için (`00-…` §3).
3. **`M!` / `M` ayrımı** her derste motor gecikmesinde ne olacağını belirler: modül geçişleri, seviye testleri ve kalibrasyon dersleri bekletilir, diğerleri öz-kontrolle gönderilebilir.
4. **Göreli dinamik A3'e, gitar bend/vibrato A5'e bağlandı** (aynı sinyal işleme altyapısı).
5. **Piyanoda "tek yeni nota" kuralı:** mikrofonla ölçülen her pratikte aynı anda yalnız bir yeni atak. Çok sesli pratikler `M~` (kilitlemez) + MIDI.
6. **Ses kursunda kişisel ton:** diziler derece olarak yazılır, kullanıcının rahat menziline taşınır, oktav katlanmış ölçülür. Ses tipi sınıflandırması yok.
7. **Kayıt yok:** Ö dersleri kayıt dinlemeye dayanmaz; mevcut "kendi kaydını dinle" adımları tekrar-ölç adımına çevrildi.
8. **Kulak kursu çalgı kurslarında kopyalanmadı;** bağlantıyla gömüldü. Çalgıya özgü kulak dersleri (kulaktan telde bulmak, akor rengini çalmak) çalgı kursunda kaldı.

## Açık sorular

1. **Motor sırası:** A5 (ses perdesi) 238 dersi, A4 (gitar akor) 99 dersi açıyor. A5'in A4'ten önce ya da paralel gelmesi önerilir (`70-…` §5). Karar motor ekibi + kurucu.
2. **Ücretsiz kapsam:** Kulak S1–S2'nin tamamı mı, yalnız S1 mi ücretsiz? Çalgı kurslarında ücretsiz çekirdek (ör. her kursun S1 M01–M02) ne olacak?
3. **Amfisiz elektro gitar** mikrofonla test edilmedi. Elektro kol (`m19b`, 19 ders) amfi/kulaklık amfisi şartıyla mı açılsın, yoksa v1.x'e mi kalsın?
4. **Piyano alt frekans sınırı** bugün 70 Hz; S1–S3 C2'ye (65,4 Hz) iniyor. Motorun ≤60 Hz'e inmesi gerekiyor ya da pes dersleri (`pno-s1-m03-08`, sol el 2 oktav gamlar) C3 üstüne kaydırılmalı.
5. **Geçiş eşikleri** (`00-…` §6.2) pedagojik tahmin. Müzik öğretmeni incelemesi için bütçe/kişi kararı (ürün önerisi §6 madde 5) hâlâ açık.
6. **Hukuk:** kamu malı liste onayı; Türk halk ezgilerinde derleme hakkı; geleneksel ezgilerde "eski varyant" yeterliliği (`60-…` §7).
7. **Ses M18 armoni modülü** kulaklık olmadan güvenilir ölçülemez. Kulaklık şartı mı, Ö'ye düşüş mü?
8. **Kamera el/bilek uyarısı** bugün yok (mevcut referans yalnız gövde hizası). `gtr-s1-m01-03` ve `pno-s1-m01-02` bu yüzden v1'de fiilen Ö olabilir.
9. **Sayım konvansiyonu:** "~690" yazılan ders mi (bu plan), öğrencinin gördüğü ders mi (671)? Mağaza metninde hangisi kullanılacak?

## Sonraki adımlar (bu PR'ın kapsamı dışında)

- Sözleşmeyi içerik JSON şemasına çevirmek (mevcut `guitar_journey.v1.json` alanlarıyla eşleme `00-…` §2'de).
- Ders gövde metinleri (EN + TR), sonra 12 dil katalog çevirisi.
- Özgün egzersiz havuzu (seviye testi başına bileşen başına ≥6 varyant).
- Müzik öğretmeni incelemesi: sıra, tempo hedefleri, ses sağlığı notları.
