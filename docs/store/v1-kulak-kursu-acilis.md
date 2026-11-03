# Kulak eğitimi kursunu açma — metin değişiklikleri (kurucu onayına)

Tarih: 2026-11-03. Kurucu kararı: "Önce mikrofon ölçümü, sonra aç." Bu belge, kursu açma PR'ındaki
uygulama metnini ve aynı işle gelen mağaza ve site metnini en/tr olarak bir arada gösterir. Diğer
12 dilin çevirisi aynı anlamla yapıldı; her dil kendi mağaza metnindeki terimi korur (ör. pt-BR
"percepção musical", ja "耳のトレーニング").

## 1. Uygulama (bu PR)

| Yer | Önce | Sonra |
|---|---|---|
| Açılış, ana metin (son cümle) | Guitar is open in this release; the other courses follow. / Bu sürümde gitar açık; diğer kurslar sırayla eklenecek. | Guitar and ear training are open in this release; voice and piano follow. / Bu sürümde gitar ve kulak eğitimi açık; ses ve piyano sırayla eklenecek. |
| Açılış, "Neler var?" (yeni satır) | — | Ear training — on-screen drills, clapping with the click and part-by-part tests. / Kulak eğitimi — ekran alıştırmaları, klikle alkış ve bölüm bölüm testler. |
| Ana sayfa giriş (son cümle) | Voice and piano courses open in turn. / Ses ve piyano kursları sırayla açılacak. | Ear training is open too; voice and piano courses open in turn. / Kulak eğitimi de açık; ses ve piyano kursları sırayla açılacak. |
| Ana sayfa, yeni kart | — | **Ear training / Kulak eğitimi** · "Ear training open · next lesson: {ders}" / "Kulak eğitimi açık · sıradaki ders: {ders}" |
| Kurs listesi başlığı | — | Ear training course / Kulak eğitimi kursu |
| Kurs listesi giriş | — | All 50 lessons of the ear training course, by level and module. Drills run on the screen and check your answers; clapping lessons listen to your claps. Singing is not measured: you check it yourself and it is saved as self-reported. … / Kulak eğitimi kursunun 50 dersinin tamamı, seviye ve modüle göre. Alıştırmalar ekranda çalışır ve cevaplarını kontrol eder; alkış dersleri alkışlarını dinler. Şarkı söyleme ölçülmez: kendin kontrol edersin ve kendi beyanı olarak kaydedilir. … |
| Ücretsiz kapsam | (gitarla aynı) | Level 1 is free · later levels need a membership / Seviye 1 ücretsiz · sonraki seviyeler üyelik gerektirir (kulak S1 = 25 ders) |
| Ders çipi (alıştırması hazır derslerde) | Reading · on-screen exercise coming soon / Okuma · ekran alıştırması yakında | On-screen drill / Ekran alıştırması |
| Yalnız alıştırma olan kulak dersi | This lesson has an on-screen drill. … the playing part is not measured yet. | This lesson is an on-screen drill. Passing it saves the lesson as done. / Bu ders bir ekran alıştırmasıdır. Geçince ders yapıldı olarak kaydedilir. |
| Alıştırma + şarkı (ear-s2-m06-06) | aynı "playing part" metni | … the singing part is not measured, so check it yourself. / … şarkı söyleme bölümü ölçülmez, onu kendin kontrol et. |
| Kulak dersinde genel öz-kontrol maddeleri | "…with the guitar in front of me", "…on the guitar", "notes rang without buzzing" | I worked through the whole task. / Görevi baştan sona yaptım. · I can explain each point … in my own words. / Anlatımdaki her maddeyi kendi sözlerimle açıklayabiliyorum. · I kept the target tempo, ♩={v0}. / Hedef tempoyu, ♩={v0}, korudum. |

## 2. Mağaza metni (14 dil)

Kaynak: `scratch/2026-11-02-ostinato-magaza/listing-v1/` (konsola giren taslak; değişiklik
öncesi kopya `listing-v1.before-ear-2026-11-03/`). `check.py` PASS (uzunluk, zorunlu ve yasak
sözcükler). Ad, alt başlık ve anahtar kelimeler değişmedi.

- **Tanıtım metni (App Store):** 690 lessons; guitar and ear training are open now. Play along and see every note marked: correct, different note or couldn't hear. Voice and piano are coming soon. / 690 ders; gitar ve kulak eğitimi şimdi açık. Sen çalarken her nota işaretlenir: doğru, farklı nota ya da duyamadım. Ses ve piyano kursları yakında.
- **Kısa açıklama (Play):** 690 lessons; guitar and ear training are open now. The app listens as you play. / 690 ders; gitar ve kulak eğitimi şimdi açık. Uygulama sen çalarken dinler.
- **Açıklama, 2. paragraf:** … All 240 guitar lessons and all 50 ear training lessons are available now. Voice and piano are coming soon; they are not part of this release. / … 240 gitar dersinin ve 50 kulak eğitimi dersinin tamamı şimdi açık. Ses ve piyano yakında; bu sürümde yer almıyor.
- **Açıklama, yeni bölüm (PRATİK NASIL İŞLER'den sonra):**
  - EAR TRAINING · On-screen drills on intervals, chords, scales, rhythm and melody. Each answer is checked on the screen. · Clapping lessons listen to your claps along with the click. · Level tests go part by part; you repeat only the part you haven't passed yet. Singing is not measured: you check it yourself, and it is labelled as self-reported.
  - KULAK EĞİTİMİ · Aralık, akor, gam, ritim ve melodi üzerine ekran alıştırmaları. Her cevap ekranda kontrol edilir. · Alkış dersleri, klikle birlikte alkışlarını dinler. · Seviye testleri bölüm bölüm ilerler; yalnız henüz geçmediğin bölümü tekrarlarsın. Şarkı söyleme ölçülmez: onu kendin kontrol edersin ve kendi beyanın olarak işaretlenir.
- **Üyelik, ilk cümle:** Level 1 of the guitar course (40 lessons) and level 1 of ear training (25 lessons) are free, with no account needed. / Gitar kursunun Seviye 1'i (40 ders) ve kulak eğitiminin Seviye 1'i (25 ders) ücretsizdir; hesap gerekmez.
- **İnceleme notu (REVIEW-NOTES.en.md):** 690 lessons: all 240 guitar and 50 ear training lessons open; voice and piano are coming soon. Ear training: on-screen drills; clap lessons time claps on device. Singing is self-reported.

## 3. Site (yulalab.com — Yulalab oturumunun reposu; bu PR değiştirmez)

Öneri, `site/messages/{en,tr}.json` → `product.ostinato`:

| Anahtar | Sonra (en) | Sonra (tr) |
|---|---|---|
| `lede` | Learn guitar from your first note, at your own pace, with measured practice, and train your ear with drills and clapping. Voice and piano are coming soon, and your practice stays on your device. | Gitarı ilk sesten itibaren kendi temponda, ölçülü pratikle öğren; kulağını alıştırmalar ve alkışla eğit. Şan ve piyano yakında; pratiğin cihazında kalır. |
| `pitch3Title` | Guitar and ear training; the programme grows to 690 lessons. | Gitar ve kulak eğitimi; program 690 derse büyüyor. |
| `pitch3Body` | The guitar course is open with 240 lessons across four levels and ear training with 50 lessons across two; voice and piano follow in turn. … (rest unchanged) | Gitar kursu dört seviyede 240 dersle, kulak eğitimi iki seviyede 50 dersle açık; şan ve piyano sırayla geliyor. … (kalanı aynı) |
| `a1Title` | Guitar and ear training are open. | Gitar ve kulak eğitimi açık. |
| `a1Body` | Guitar runs from your first sound to advanced: 240 lessons across four levels. Ear training has 50 lessons: on-screen drills, clapping with the click and part-by-part tests. Voice and piano are coming soon; the programme grows to 690 lessons. | Gitar ilk sesten ileri seviyeye, dört seviyede 240 ders. Kulak eğitimi 50 ders: ekran alıştırmaları, klikle alkış ve bölüm bölüm testler. Şan ve piyano yakında; program 690 derse büyüyor. |
| `a2Title` | Level 1 of each course is free. | Her kursun ilk seviyesi ücretsiz. |
| `a2Body` | Guitar level 1 (40 lessons) and ear training level 1 (25 lessons) are free and work without an account. … (rest unchanged) | Gitarın ilk seviyesi (40 ders) ve kulak eğitiminin ilk seviyesi (25 ders) ücretsizdir ve hesap açmadan çalışır. … (kalanı aynı) |
| `r1v` | Guitar level 1 (40 lessons) · ear training level 1 (25 lessons) · no account | Gitar 1. seviye (40 ders) · kulak eğitimi 1. seviye (25 ders) · hesapsız |

## 4. Kurucuya açık sorular

1. **Mikrofon izin metni** (Info.plist, 14 dil; kurucu 1 Kasım'da onayladı): bugün "to hear the notes you play during practice and tuning" diyor. Alkış dersleri de mikrofonu kullanıyor. Öneri: "to hear the notes you play and the rhythms you clap during practice and tuning". Bu PR'da **değiştirilmedi**; onaylanırsa ayrı küçük PR.
2. **Alt başlık** "Guitar practice that listens" / "Seni dinleyen gitar pratiği" — değiştirilmedi (30 karakter sınırı).
