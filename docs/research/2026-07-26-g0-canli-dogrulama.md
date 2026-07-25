# Ostinato G0 — Rakip Canlı Doğrulama + Lisans Hattı Sentezi

**Tarih:** 2026-07-26 · **Yöntem:** 8 paralel web-araştırma ajanı (WebSearch/WebFetch; her iddia URL'li; birincil kaynak > blog). Ham bulgu listesi Ek'te (mekanik döküm — özet için bu sayfa yeter).
**Statü:** Konumlandırma iddiası ve lisans kararları için KANIT TABANI; roadmap §2 tablosunun 2026-07-26 canlı hali.

---

## 1. ANA SONUÇ — beyaz alan DOĞRULANDI (nüanslı)

**2026-07-26 itibarıyla mağazada satışta, kamera-tabanlı postür/yay analizi yapan keman/çello pratik uygulaması BULUNAMADI.** Kamera+ses birleşik koçluk boşluğu gerçek. İki nüans:

1. **⚠️ Purdue "Cello Evaluator" (AI4Musicians/AIM, NSF destekli):** MediaPipe+YOLOv11 ile telefondan gerçek-zamanlı çello postürü değerlendiren ARAŞTIRMA PROTOTİPİ — birebir bizim konsept. Mağazada yok; Şubat 2026'da kullanıcı çalışması planlıyorlardı; ticari lansman işareti yok. → **İzleme görevi DEFTER'e (O-008):** çeyreklik kontrol; yayın/lansman sinyali çıkarsa konumlandırma hızı kritikleşir. Ayrıca yöntembilimsel altın: onların yayınları çıktıkça okunacak.
2. ROLI AI Music Coach: kamera değil kızılötesi donanım (Airwave), PİYANO, hâlâ beta — rakip değil, "teknik geri bildirim" kategorisinin varlık kanıtı.

Pazarlama dili kuralı (00-AILE §7): "**no camera-based practice app for strings exists in the app stores today**" formu KULLANILABİLİR (mağaza-sınırlı, tarih-damgalı); "hiç kimse yapmıyor" formu KULLANILMAZ (Purdue var).

## 2. Rakip tablosu — 2026-07-26 canlı durum (roadmap §2 güncellemesi)

| Rakip | Canlı durum | Roadmap'ten FARK |
|---|---|---|
| **Trala** | Keman-only (çello YOK); mikrofon-only — kendi kullanıcı yorumları "bowing/postür veremiyor" doğruluyor; Learnfield GmbH (Skoove) bünyesinde; App Store IAP: $19.99/ay · $119.99/yıl (ikincil kaynaklar $9.99/ay diyor — çelişki, teyit gerek) | Fiyat roadmap'te $9.99/ay yazıyordu → muhtemelen ESKİ; $19.99 güncel görünüyor |
| **Yousician** | Instruments menüsü: Guitar, Bass, Piano, Ukulele, Singing — **keman ARTIK LİSTEDE YOK**; çello hiç yok; mikrofon-only (resmî SSS); Premium $19.99/ay-$119.99/yıl, Premium+ $29.99/ay | Roadmap "keman sığ" diyordu → gerçek daha iyi: keman desteği görünürde kalkmış; yaylı boşluğu BÜYÜMÜŞ |
| **Simply (JoyTunes)** | Piano/Guitar/Sing/Draw (+Tune akort: yalnız gitar ailesi); yaylı YOK; Individual $24.95/ay-$119.99/yıl, Family $34.95/ay-$179.99/yıl → bundle oranı ~1.4-1.5× | Roadmap 1.24× diyordu → güncel ölçüm 1.4-1.5× (G9 fiyat girdisi güncellendi) |
| **SmartMusic** | 2022'de **MakeMusic Cloud**'a dönüşmüş; ses-tabanlı score-following; kurumsal | İsim güncellendi |
| **Tonara** | **2023'te KAPANMIŞ** | Roadmap tablosundan düşülecek (pratik-takip kategorisinde Modacity kaldı — aktif, ses-only) |

**Fiyat koridoru etkisi (G9 girdisi):** güncel emsaller ($19.99-29.99 Yousician, $19.99 Trala, $24.95 Simply) katalog §8 koridorunun ($9.99-14.99) ÜSTÜNDE seyrediyor — koridorun alt-agresif kaldığı G9'da yeniden değerlendirilecek not olarak kaydedildi (karar o fazda; kurucu-nihai).

## 3. Lisans hattı sonuçları

| Konu | Sonuç | Eylem |
|---|---|---|
| **SwiftF0** | ✅ **MIT doğrulandı** (LICENSE ham dosyadan; Copyright 2025 Lars Nieradzik). Aralık 46.875-2093.75 Hz (C2 ✓), iç 16kHz. ⚠️ Native mobil export YOK (Python+WASM only); tek-yazar, 3 issue, release-tag'siz | Pilot İZNİ açık (katalog §4 şerhi kapandı); mobil taşıma = kendi işimiz; benchmark'ımızda en isabetli aday çıktı (G1-C raporu) |
| **URMP** | Resmî sayfada bağlayıcı lisans YOK (yalnız atıf ricası + form); **Dryad kopyası CC0-1.0 beyan ediyor** (çelişkili sinyal); 10/44 parçada çello; bochen.li Rochester'dan ayrılmış (ByteDance) → doğru muhatap **Zhiyao Duan (PI, zhiyao.duan@rochester.edu)** | İzin maili taslağı hazır (`docs/g1/urmp-permission-email.md`) — gönderim kurucu |
| **Iowa MIS** | ✅ Kurumun kendi beyanı "without restrictions" (1997'den beri) — SPDX/CC değil, kurum cümlesi; büyük ölçekli ticari kullanımda hukukçu şerhi düşüldü | Benchmark fixture olarak KULLANILDI (G1-C); ship edilen ürüne gömülmeyecek |
| **TinySOL** | ✅ CC BY 4.0 (Zenodo) | Fixture yedek kaynağı; atıf listesine |
| **Philharmonia** | Custom permissive (satış/as-is dağıtım hariç serbest); "CC BY-SA" iddiası resmî sayfada YOK (mirror söylentisi) | Kullanılırsa custom metne göre; BY-SA varsayma |
| **Freesound** | Dosya-başına lisans (CC0/BY/BY-NC karışık); API ticari kullanımı ayrı izin | Yalnız tek-tek lisans-doğrulanmış CC0 dosyalar; API otomasyonu YOK |
| **good-sounds** | Dataverse (birincil): CC BY 4.0 (bazı özetler yanlışlıkla BY-NC diyor) | Kullanılırsa Dataverse metnine dayan |

## 4. Konumlandırma cümlesinin kanıt zinciri

Roadmap §2 iddiası: *"kamera+ses BİRLEŞİK koçluk — pazarda YOK."* Kanıt durumu:
- Trala kamera yok ✅ (resmî sayfa sessiz + kullanıcı yorumları "ayna kullan" diyor)
- Yousician kamera yok ✅ (resmî SSS: "listens with your device's microphone"); ikincil blogun "kamera postür" iddiası resmî kaynakta YOK → çöp
- Simply/MakeMusic/Modacity kamera yok ✅
- Store aramaları ("cello posture app" vb.) ticari sonuç vermedi ✅
- Tek istisna sınıfı: araştırma prototipi (Purdue) — mağazada değil
**Hüküm: iddia, mağaza-sınırlı ve tarih-damgalı formuyla YAYINLANABİLİR düzeyde kanıtlı.** (Yayın öncesi G10'da bir kez daha canlı tarama — standart tazeleme.)

## 5. Açık uçlar / bayraklar (öne çıkanlar)

1. Trala fiyat çelişkisi ($19.99 vs $9.99/ay) — ASC listing $19.99 gösteriyor; kesinleşme G9'da yeterli.
2. Purdue Cello Evaluator izleme ritmi (O-008).
3. Play Store tarafı (Yousician/Trala/Simply) bot-koruması nedeniyle tam doğrulanamadı — iOS + resmî web yeterli sayıldı; Android fiyatları G9'da elle bakılır.
4. CelloBello 403 (pedagoji dokümanında da bayraklı) — elle tarama kurucu-listesinde değil; ilk içerik sprintinde (G6) tarayıcı oturumuyla yapılır.
5. Ek ham bulgu dökümü: `g0-canli-dogrulama-ek-ham-bulgular.json` (8 ajan × summary+findings+flags, URL'leriyle — mekanik kopya, tekil doğruluk kaynağı olarak Ek esas alınmaz, sayfadaki sentez esastır).
