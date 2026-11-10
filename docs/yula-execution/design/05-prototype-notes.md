# OST-UX-04 — etkileşimli prototip notları

Tarih: 2026-11-10 · Dayanak: [`04-design.md`](04-design.md) (ADR-UX-001, K1 "Tek Sahne" melezi, teslimat 5, 6, 9, Ek A–C), [`04-backlog-ux-05.md`](04-backlog-ux-05.md). Yeni ADR gerekmedi (`DECISIONS.md` değişmedi).

## Bayrak ve giriş
- Bayrak: `ostinatoUxPrototypeOpen = false` (`lib/app/ostinato_release_policy.dart`, dosyanın son bildirimi). Varsayılan KAPALI; testle kanıtlı (`test/ux_prototype_test.dart`).
- Giriş yolu TEK: Ayarlar ekranının başındaki "Open the prototype stage" düğmesi (`SettingsScreen.uxPrototypeOpen`, varsayılanı bayrak). Bayrak kapalıyken düğme hiç kurulmaz; prototipe `lib/` içinde başka hiçbir yer bağlanmaz (testli).
- Bayrak kapalıyken uygulama main ile aynıdır: mevcut ekranlar silinmedi ya da değiştirilmedi; tek değişiklik Ayarlar'daki koşullu düğme.
- Kod: `lib/app/ux_prototype/` (`ux_prototype_screen.dart`, `ux_glass_layer.dart`, `ux_prototype_model.dart`, `ux_prototype_copy.dart`, `ux_prototype_entry.dart`).

## Yedi yolculuk → ekran
| # | Yolculuk (§5.4) | Yüzey (`ux_prototype_screen.dart`) | Kanıt görüntüsü | Ana testler |
|---|---|---|---|---|
| 1 | Pratiğe başla | Sahne, "Play"; çalarken tutamak/katman/cam yok | 01 | journey 1 |
| 2 | Enstrümansız çalışma | "Another practice" > "Ear, no instrument" (kulak kipi, ekranda cevap) | 02 | journey 2 |
| 3 | Öğrenme yolculuğu | "My path" > Path (gerçek `V1CourseCatalog`: seviye > modül, sıradaki + neden) | 03 | journey 3 |
| 4 | Hata anlama | Sonuç katmanı (farklı nota, nerede, duyulan %, tek düzeltme) | 04 | journey 4 |
| 5 | Tekrar | Try again / Loop this bar; döngülü koşu ölçülmez | 05 | journey 5 |
| 6 | İlerleme geçmişi | "My path" > History (yan yana koşular; kulak ayrı) | 06 | journey 6 |
| 7 | İzin reddi | "Listening is off" kipi, kendin değerlendir, kulak, ayar | 07 | journey 7 |

## Kurallar ve nasıl sağlandı
- Cam: yalnız geçici katman (`UxGlassLayer`); sigma 12 (sınır 16), yüzey en az %94 opak; aynı anda tek katman (en çok iki kuralı içinde); çalarken 0 (katman açılamaz, cam çizilmez). Yüksek kontrast = opak, bulanıklık yok. Hareketi azalt = katman anında. Gövde metni kontrastı en kötü zeminde 4.5:1 (testli, açık ve koyu tema).
- "Yanlış/wrong" hiçbir metinde yok (testli, 14 dilden en/tr kontrol). İşaretler şekil + metin (doğru / farklı nota / duyamadım).
- `uxClassifyRun`: tam, döngüsüz, beklemesiz, duyulan >= %80 koşu ölçülür; kısmi/döngü/bekle = ölçülmedi; dinleme kapalı = ölçülmedi; çok az duyulan = "duyamadım" ailesi, yüzde yok.
- Ham ses, kamera, depolama, ağ yok: prototip bu paketleri import etmez (testli). Kamera bayraklarına dokunulmadı.

## Mock ("Prototype" etiketli) olan yerler
Ders başlığı, nota dizisi, koşu sonuçları (6 doğru, 1 farklı, 1 duyamadım), "dün" satırı, mikrofon durumu (Setup katmanındaki prototip seçici), kulak sorusu (çizilir, çalınmaz), katalog yüklenemezse örnek yol. Gerçek: kurs kataloğu (Path).

## Bilinen eksikler
Araç rafı (metronom/referans/döngü/Hayalet), Hayalet Ekran basamakları, akort çıkışı, tam Sonuç/Geçmiş için gerçek `V1PracticeRecord` okuma, ekran okuyucu ile elle test, cihazda cam performansı ölçümü, simülatör görüntüleri (BLOCKED_ACCESS), gerçek ses/ölçüm yolu yok.

## UX-05a–h ile ilişki
Prototip bunların ilk adımıdır; hiçbirini kapatmaz. a (GlassLayer): yüzeyin ilk taslağı burada, kalıcı bileşen değil. b–d (kök, katman yöneticisi, Yolum): kabuk davranışının prototipi. e (sonuç/dürüst durum): kural ve metinler burada denendi. f (izin reddi/Ayar): yolculuk 7. g (Hayalet): yok. h (erişilebilirlik/kanıt): bu PR'da yalnız temel kontroller.
