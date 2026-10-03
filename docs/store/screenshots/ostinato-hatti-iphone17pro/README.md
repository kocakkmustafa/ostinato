# Ekran görüntüleri — `ostinato-hatti` (2026-08-16, O-156, D6)

## Tarihsel set — 2026-10-02 kaynak uzlaştırması

Bu dört PNG, 2026-08-16 simülatör ekranlarını saklayan tarihsel bir settir.
28 ders, mikrofonsuz kütüphane ve piyano kamera bandı o kapsamı anlatır;
güncel 60 derslik gitar kursunun mağaza ekran seti veya fiziksel cihaz kabulü
değildir. Görseller korunmuştur; bu belge güncel ekran alınmış olduğunu iddia etmez.

Güncel kaynak `assets/content/guitar_journey.v1.json`: SHA-256
`bf553f62d91927be66b88210103b982bed17c357b4b643cb9b50f57a3e105a18`,
10 modül / 60 ders. Güncel gönderim hazırlığında bu sürümün gerçek arayüzünden
TR/EN kurs kataloğu, özgün metin dersleri ve kullanıcı beyanına dayalı yerel
ilerleme ekranları yeniden alınmalıdır. İsteğe bağlı mikrofon gözlemi
gösterilecekse açık Başlat/izin, yaklaşık tek nota ve puan/ustalık üretmeme
sınırı görünmelidir; ham ses kaydı veya upload iddiası eklenmez. Kursun
mikrofonsuz kullanılabilmesi korunur. Kamera duruş puanı ve abonelik satışı
ilk sürümde kapalıdır; tarihsel piyano bandı güncel gönderim için bu yeteneklerin
açık olduğu kanıtı olarak kullanılmaz. Kurs gösterim videosu ve onaylı AI
medyası mevcut değildir. Güncel ekran alımı, mağaza boyut kabulü ve fiziksel
mikrofon doğruluk/route kabulü ayrı, açık işlerdir.

## 2026-08-16 alım kaydı

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

## Tarihsel kalemler

| Dosya | 2026-08-16 ekranı | O günkü seçilme nedeni |
|---|---|---|
| `01-welcome.png` | Onboarding 1 — "Measured, not chosen." | İlk izlenim; "band, not a point" felsefesi tek cümlede |
| `02-honest-stats.png` | Onboarding 2 — "Small, and honest about it." | 3 çalgı / 28 ders / 10 kilitli / 3 puansız — 2026-08-16 liste kapsamının sayıları; güncel 60 derslik gitar kursunu temsil etmez |
| `03-library.png` | Kütüphane (D16 sonrası — START HERE katlama üstünde) | Genişlik + dürüstlük tek ekranda; mikrofon-yok cümlesi burada da tekrar ediyor |
| `04-piano-lesson-band.png` | Piyano dersi — "How you sit at the keyboard" | O günkü statik bandın sayıları görünür (1.9°-2.8°, 3 piyano öğretmeni); canlı ölçüm veya güncel kurs yeteneğinin kabul kanıtı değildir |

## Ne YAPILMADI (bilerek, bu turda)

- Canlı kamera oturumu / Review ekranı: kamera izni + gerçek/sahte poz kaynağı gerektirir,
  bu turun kapsamı DEĞİL (D6 = statik ekranlar). Ayrı bir tur konusu.
- Android ekran görüntüleri: Play mağazası tarafı bu turda hiç ele alınmadı.
- Karanlık mod / farklı cihaz boyutları: yalnız tek cihaz, tek tema (varsayılan) bu turda.
