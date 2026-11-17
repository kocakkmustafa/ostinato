# FLAG #22 — VoiceOver / TalkBack elle doğrulama

Durum: **KONTROL LİSTESİ, boş.** Kaynak: FLAG-CHECKLIST #22 (`docs/yula-execution/design/evidence/ux-05h/FLAG-CHECKLIST.md`, satır 28). Otomatik test bunun yerine geçmez; bir insan gerçek cihazda ana akışı ekran okuyucuyla baştan sona geçer. Sıra [`TUR-LISTESI.md`](TUR-LISTESI.md) ile aynıdır. Sonuçlar bu dosyadaki kutulara ve [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md) §4'e yazılır.

## Hazırlık

- iOS: Ayarlar → Erişilebilirlik → VoiceOver (kapatma kısayolu: yan düğmeye üç kez bas; önce ayarla). Android: Ayarlar → Erişilebilirlik → TalkBack.
- Dokunma yerine kaydırma: sağa/sola kaydır = sonraki/önceki öğe, çift dokun = etkinleştir. iOS iki parmakla "Z" = geri/kapat; Android geri hareketi.
- Her satırda üç kutu: **geçti** (öğe okundu, anlamlı, etkinleştirilebildi) · **takıldı** (not zorunlu: ne okundu / okunmadı, ekran, cihaz) · **not**.
- Kodda semantik kullanımı (grep ile, sayılar bilgi amaçlı; ekran-öğe doğrulaması cihazda yapılır): karşılama adım göstergesi `Semantics(label: "{n} / {m} adım")`; pratikte `liveRegion` ve `ExcludeSemantics` kullanılıyor; sonuç ekranında rozetlerde `semanticLabel`; ayarlarda `Semantics` ve `MergeSemantics`. `own_take_player.dart` içinde `Semantics`/`semanticLabel` yok (varsayılan düğme etiketi kullanılır). Kütüphane/kurs/ders ekranlarında yalnız `semanticLabel` (geri düğmesi) var.

## Cihazlar

| Okuyucu | Cihaz | OS | Tamamlayan |
|---|---|---|---|
| VoiceOver | | | |
| TalkBack | | | |

## Ekran ekran

| # | Ekran (dosya) | Kontrol | geçti | takıldı | not |
|---|---|---|---|---|---|
| 1 | Karşılama 1-3 (`screens/onboarding_screen.dart`) | Adım göstergesi "n / 3 adım" olarak okunuyor; başlıklar sırayla okunuyor; sayfa kaydırılınca odak yeni sayfanın başına geçiyor; "Devam et" / "Kütüphaneyi aç" düğmesi etiketli | [ ] | [ ] | |
| 2 | Karşılama 3 kartları (mikrofon / kamera / sağlık / ilerleme) | Her kart tek öğe olarak anlamlı okunuyor; dekoratif simge okunmuyor | [ ] | [ ] | |
| 3 | İlk üç dakika, yalnız bayrak açık derlemede (`first_minutes/first_three_minutes_screen.dart`) | Üç seçenek kartı düğme olarak okunuyor; "Ritme dokun" ekranında dokunma alanı ekran okuyucuyla kullanılabiliyor (dokunma-zamanlama ölçümü ekran okuyucu modunda anlamlı mı: **doğrulanacak**); sonuç değişiklikleri canlı bölge (`liveRegion`) ile duyuruluyor | [ ] | [ ] | |
| 4 | Kök ekran: kütüphane (`screens/library_screen.dart`) ya da sahne (`stage/stage_home_screen.dart`, bayrak açıksa) | Kartlar/çalgılar okunuyor; "yakında" olan çalgılar öyle duyuruluyor; sahnede "Çal" düğmesi ve üç tutamak etiketli; katman açılınca odak katmana geçiyor, kapatma (iOS iki parmak Z / Android geri) çalışıyor | [ ] | [ ] | |
| 5 | Gitar kursu ve ders listesi (`screens/instrument_screen.dart`, `screens/course_screen.dart`, `practice/loop/v1_practice_list_screen.dart`) | Ders satırları ad + durum (kilitli, sıradaki) ile okunuyor; "sıradaki" çipi okunuyor (`nextChipSemantics`); geri düğmesi "Geri" | [ ] | [ ] | |
| 6 | Ders okuma (`practice/loop/v1_lesson_reader_screen.dart`) | Metin sırayla okunuyor; nota/ritim görselinin metin karşılığı var | [ ] | [ ] | |
| 7 | Pratik: öncesi (`practice/loop/practice_loop_screen.dart`) | **Başlat** (sahnede **Çal**) etiketli; tempo kaydırıcısı değer okuyor ve ± düğmeleri çalışıyor; metronom sesi anahtarı etiketli | [ ] | [ ] | |
| 8 | Pratik: mikrofon izni penceresi | Sistem penceresi okuyucuyla yanıtlanabiliyor; izin sonrası odak uygulamaya dönüyor | [ ] | [ ] | |
| 9 | Pratik: çalarken | Seviye/sayaçlar gürültü çıkarmadan duyuruluyor (aşırı sık duyuru yok); durdur düğmesi bulunabiliyor; hata/izin bildirimi (`practice-failure`) canlı bölge olarak duyuruluyor (sahne modunda `liveRegion`) | [ ] | [ ] | |
| 10 | Pratik: izin reddi sonrası (bkz. [`FLAG-21-OLCUM.md`](FLAG-21-OLCUM.md) §4) | Bildirim okunuyor; **Başlat** yeniden bulunup etkinleştirilebiliyor | [ ] | [ ] | |
| 11 | Sonuç ekranı (`practice/loop/practice_result_screen.dart`) | Özet sayılar ve rozetler okunuyor (rozet `semanticLabel`); bir önerilen sonraki adım düğme olarak okunuyor; geri düğmesi etiketli | [ ] | [ ] | |
| 12 | Kendi kaydını dinle (`practice/own_recording/own_take_player.dart`) | **Dinle / Duraklat** düğmesi okunuyor ve durumu (çalıyor/durdu) değişince yeni etiket duyuruluyor; başlık okunuyor. Bu dosyada ayrı semantik yok: varsayılan düğme etiketi yeterli mi, cihazda bak | [ ] | [ ] | |
| 13 | Ayarlar (`screens/settings_screen.dart`) | Kartlar sırayla; "kendi kaydım" anahtarı durumu (açık/kapalı) ile okunuyor; Hesap düğmesi etiketli | [ ] | [ ] | |
| 14 | Akort (`tuner/tuner_screen.dart`) | Çalgı ve ayar seçici (`SegmentedButton`) durumla okunuyor; **Başlat/Durdur** düğmesi; kalıcı redde "Ayarları aç" | [ ] | [ ] | |

## Genel gözlemler

- [ ] Odak sırası görsel sırayla uyuşuyor mu (her ekranda)?
- [ ] Okunmayan ya da "düğme" diye okunan etiketsiz öğe var mı (not: ekran, öğe)?
- [ ] Yazı boyutu büyük (sistem ayarı) + ekran okuyucu birlikte taşma/kesilme yapıyor mu?
- [ ] Çökme ya da donma var mı?

Takılan her öğe için bulgu: cihaz, okuyucu, ekran, beklenen ile okunan, ekran görüntüsü ya da kayıt yolu. Bilet ve bayrak kararı Motion orchestration'da verilir.
