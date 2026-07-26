# Ostinato — Pilot Çekim Günü Paketi (v1)

**Tarih:** 2026-07-26 · **Statü:** HAZIR — koordinatörün birleşik "çekim günü" planına Ostinato girdisi (protokol: `data-collection-protocol.md` v1.1, kurucu-onaylı). Pilot = 6 klip, ~yarım gün; amaç protokolün gerçekle testi + Ek-C etiket yönergesi örnek kareleri.
**Not (v1.1 kapsamı):** pilot klipleri **detector-eğitim verisi** içindir (kendi çekimimiz şart); skorlama referansları ayrı hatta (ReferenceBuilder pilotu, `../g3-prep/referencebuilder-pilot-plan.md`).

## 1. Malzeme kontrol listesi (çıkmadan önce)

- [ ] Tripod (lens yüksekliği 90-110cm'e ayarlanabilir) + telefon tutucu
- [ ] Birincil telefon (4K30 destekli) + İKİNCİ cihaz (orta-segment Android — cihaz çeşitliliği hücresi pilotta başlasın)
- [ ] Şarj + yedek depolama (4K ~1GB/3dk; 6 klip × 2 cihaz ≈ 8-10GB boş alan)
- [ ] Mezura (kamera mesafesi 2.5-3.5m + yükseklik ölçümü — manifest'e yazılacak)
- [ ] Çello + yay + reçine; sandalye (kolçaksız)
- [ ] Basılı rıza formu (Ek-A; pilotta katılımcı kurucu/yakın çevre ise de form doldurulur — süreç provası)
- [ ] Klip planlama sayfası (aşağıda §3, basılı veya telefonda)
- [ ] "Adversarial" sahne malzemesi: arka plana dikey çizgili nesneler (süpürge sapı / perde çubuğu / kitaplık önü)

## 2. Sahne kurulumu (her klipten önce 2dk kontrol)

1. Kamera: sağ-ön çapraz ~30-45°, mesafe 2.5-3.5m, lens göğüs hizası (~90-110cm). Ölç, NOT ET.
2. Kadraj: gövde + çello tamamı + yayın TÜM stroku + sandalye/ayaklar içeride; baş üstünde ~%10 pay.
3. **AE/AF kilidi AÇIK** (iPhone: kadraja uzun bas → "AE/AF Kilidi"; Android: odak kilidi) — ışık dalgalanması etiketi bozar.
4. Video: 4K30 (destek yoksa 1080p30); ses AÇIK kalır (çift kullanım: ileride audio-fixture türetimi).
5. Çekim başı sesli slate: "OST-pilot, klip #, koşul" (eşleştirme kolaylığı).

## 3. Pilot klip planı (6 klip; her satır çekildikçe işaretle)

| # | İçerik | Koşul | Süre | Doldur: cihaz/mesafe/ışık |
|---|---|---|---|---|
| P1 | Açık tel uzun yay (D teli), DOĞRU teknik | standart açı, düz duvar, gündüz | 40-60sn | ______ |
| P2 | Açık tel uzun yay, DOĞRU | standart açı, İKİNCİ cihazla aynı sahne | 40-60sn | ______ |
| P3 | Sahnelenmiş hata: E-BOW-SKEW (yay köprüye eğik) | standart açı | 30-45sn | ______ |
| P4 | Sahnelenmiş hata: E-POST-SHOULDER-RAISE + E-BOW-SHORT birlikte | standart açı | 30-45sn | ______ |
| P5 | ADVERSARIAL: doğru teknik + arka planda dikey çizgiler | `validity:adversarial` | 30-45sn | ______ |
| P6 | ADVERSARIAL: loş ışık + hafif kadraj kaçığı (yay ucu ara ara dışarı) | `validity:adversarial` | 30-45sn | ______ |

## 4. Çekim sonrası (aynı gün, ~30dk)

1. Dosya adlandırma: `OST-20260726-P#.mp4` → `data/pilot/` (şifreli disk).
2. Her klip için manifest JSON iskeleti doldur (protokol §1.3; `consentId` dahil).
3. `CONSENT-LEDGER.md` ilk kaydı (süreç provası).
4. Oturuma haber ver → etiketleme provası: her klipten 5-8 kare örneklenir, Ek-C yönergesi bu karelerle DOLDURULUR (protokol §7.1 çıktısı) + protokol v1.2 revizyon notları (açı/kadraj/ışık talimatı gerçekte işledi mi).

## 5. Ek-C etiket yönergesi İSKELETİ (pilot kareleriyle dolacak)

Her sınıf için yazılacak: tanım cümlesi + 1 net örnek kare + 1 sınır-vakası karesi + "etiketleme kuralı" (ör. `bow` bbox'ı kıl+çubuk dahil topuk vidası hariç mi? `bow_tip/frog` tam uç mu, bant hizası mı? `fingerboard` köprüye kadar mı?). Occlusion kuralı: görünen kısmı etiketle + `occluded` bayrağı. `bridge_region`: köprü ±1 yay-genişliği — pilot karesinde piksel örneğiyle netleşecek. Çift-etiketleme provası: P1'den 5 kare iki kez etiketlenir (kurucu + oturum-yönergesiyle ikinci geçiş), IoU uyumu ölçülür.
