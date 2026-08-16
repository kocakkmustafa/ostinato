# Ekran görüntüleri — `ostinato-hatti` (2026-08-16, O-156, D6)

**Cihaz:** `ostinato-hatti` simülatörü, `DAE5E512-F2DD-46AA-9FB0-5147EE8009BA`, iPhone 17 Pro.
**Alınış yolu:** `xcrun simctl io <UDID> screenshot` DOĞRUDAN (`H-46`: `attach`/`detach`
ÇAĞRILMADI — panel `launch` çağrısının yan etkisiyle bir kez açıldı, kapatılmadı da
kasıtlı: `detach` de yasak, kapatmak başka bir oturumun görüşünü kesebilirdi).
**Durum çubuğu:** `xcrun simctl status_bar override` ile 9:41/dolu pil/tam çubuk (App Store
sözleşmesi). **Build:** `flutter build ios --debug --simulator` + `debugShowCheckedModeBanner:
false` (bu turda eklendi, `lib/main.dart` — DEBUG kurdelesi olmadan çekilebilsin diye;
simülatörde `--release`/`--profile` desteklenmiyor, ölçüldü: ikisi de `flutter build`dan hata
verdi).

## Boyut — AÇIK DOĞRULAMA maddesi

Ham çıktı **1206×2622px** (iPhone 17 Pro'nun doğal @3x çözünürlüğü). Bu klasörün adı
BİLEREK bir ASC boyut-kategorisi ("6.9-inch" vb.) iddia ETMİYOR — o eşleşme bu turda
doğrulanmadı (Apple'ın güncel yükleme boyut tablosuna karşı kontrol edilmedi). **Gerçek
gönderim öncesi:** ASC'nin o günkü kabul ettiği piksel boyutlarına karşı bu dosyalar
ölçülmeli; uymuyorsa `xcrun simctl io screenshot` yine kullanılır, yalnız farklı bir cihaz
tipiyle (`xcrun simctl list devicetypes`) yeniden alınır.

## Kalemler

| Dosya | Ekran | Neden seçildi |
|---|---|---|
| `01-welcome.png` | Onboarding 1 — "Measured, not chosen." | İlk izlenim; "band, not a point" felsefesi tek cümlede |
| `02-honest-stats.png` | Onboarding 2 — "Small, and honest about it." | 3 çalgı / 28 ders / 10 kilitli / 3 puansız — `listing.json`ın kendisinin dayandığı sayılar, ekranda BİREBİR |
| `03-library.png` | Kütüphane (D16 sonrası — START HERE katlama üstünde) | Genişlik + dürüstlük tek ekranda; mikrofon-yok cümlesi burada da tekrar ediyor |
| `04-piano-lesson-band.png` | Piyano dersi — "How you sit at the keyboard" | Bandın kendisi sayılarla görünür (1.9°-2.8°, 3 piyano öğretmeni) — `listing.json`daki "measured against real teachers" iddiasının GÖRSEL kanıtı |

## Ne YAPILMADI (bilerek, bu turda)

- Canlı kamera oturumu / Review ekranı: kamera izni + gerçek/sahte poz kaynağı gerektirir,
  bu turun kapsamı DEĞİL (D6 = statik ekranlar). Ayrı bir tur konusu.
- Android ekran görüntüleri: Play mağazası tarafı bu turda hiç ele alınmadı.
- Karanlık mod / farklı cihaz boyutları: yalnız tek cihaz, tek tema (varsayılan) bu turda.
