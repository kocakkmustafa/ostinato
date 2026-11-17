# FLAG #21 — gerçek cihaz ölçümü: kare süresi, bulanık katman, izin reddi "Başlat"

Durum: **YÖNTEM, ölçüm yok.** Kaynak: FLAG-CHECKLIST #21 (`docs/yula-execution/design/evidence/ux-05h/FLAG-CHECKLIST.md`, satır 27) ve #25 kararı (satır 31). Sonuçlar [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md) §3'e yazılır. Tur: [`TUR-LISTESI.md`](TUR-LISTESI.md).

İşaret kuralı: **önerilen** = bu belgenin önerisi, kurucu/Motion onayı bekler; işaretsiz olgular koddan okunmuştur.

## 1. Koddan olgular

- Kare ölçer: `lib/app/design/glass_layer.dart` (`FrameBudgetMonitor` arayüzü ve `TimingsFrameBudgetMonitor`, satır 49-93 civarı). Kare maliyeti = `buildDuration + rasterDuration`. Varsayılan bütçe 20 ms (`defaultBudget`), art arda 8 kare (`defaultConsecutiveFrames`), ilk 30 kare yok sayılır (`GlassLayerConfig.warmupFrames`). Eşik aşılınca "düşük donanım" bayrağı **bir kez** kalıcı kurulur (geri dönmez).
- Bulanık katman kararı (FLAG #25 sonrası): `GlassCard` (`lib/app/design/widgets.dart`) artık `BackdropFilter` çizmez; yarı saydam düz dolgudur. Ekrandaki tek blur katmanı `GlassLayer`'dır (`glass_layer.dart`): sigma 12, en çok 1 bulanık yüzey (`maxBlurSurfaces`), ekran yüksekliğinin en çok %60'ı kadar alan, çalma sırasında ve yüksek karşıtlık / yeniden saydamlık azaltma açıkken opak. Kodda başka `BackdropFilter` yalnız `lib/app/ux_prototype/ux_glass_layer.dart`'tadır (prototip, bayrak kapalı).
- **Bulgu:** üretimde `TimingsFrameBudgetMonitor` hiçbir yerde kurulmuyor. `StageHomeScreen` `GlassLayerBudget()`'ı monitörsüz oluşturur (`lib/app/stage/stage_home_screen.dart:201`); bu yüzden `lowHardware` üretimde hep `false`'tur ve zayıf cihazda otomatik opak düşüş **çalışmaz**. Cihaz günü ölçümü bu nedenle elle yapılır; "latch oldu mu" sorusu üretim derlemesinde gözlenemez. (Bu belge kodu değiştirmez; gerekirse ayrı bilet.)
- `GlassLayer` yalnız sahne ekranında kullanılır (`stage_home_screen.dart:1188`); sahne `ostinatoStageHomeEnabled` bayrağı kapalıyken görünmez. Bulanık katman ölçümü bu yüzden **`profil-acik` derlemesi** ister (K1, [`PROFIL-DERLEME.md`](PROFIL-DERLEME.md) §6).

## 2. Kare süresi ölçümü (profil modu)

Hata ayıklama (debug) kare süresi ölçüm sayılmaz; yalnız profil modu.

1. Cihazı bağla; profil modunda çalıştır (kurucu ya da gün sabahı):
   ```
   flutter run --profile -d <cihaz-kimliği>
   ```
   Cihaz kimliği: `flutter devices`. iOS kurulum önkoşulları: [`PROFIL-DERLEME.md`](PROFIL-DERLEME.md) §2.
2. Çıktıdaki DevTools adresini aç (`flutter run` "A Dart VM Service ... DevTools" satırı) → **Performance** sekmesi.
3. Kaydı başlat ve senaryoyu oynat: (a) sahne ekranını aç, katmanı (araç rafı / el tutamakları) aç-kapat, (b) pratikte **Çal / Başlat**, 2 dk çal, (c) kaydı bitir.
4. "Frame analysis" ve kare grafiğinden oku: UI (build) ve raster süreleri; kırmızı (jank) kare sayısı; en kötü kare. Ekran görüntüsünü `scratch/<tarih>-devday/<cihaz>/perf-<senaryo>.png` olarak kaydet (repo dışı).
5. Yenileme hızı: 60 Hz'de kare bütçesi ≈16,7 ms, 120 Hz'de ≈8,3 ms. Tabloya cihazın Hz değerini yaz.
6. İsteğe bağlı kanıt: ekran videosu (iOS: Denetim Merkezi kaydı; Android: ekran kaydı); bulanık katman açıkken ve kapalıyken görsel karşılaştırma.

**Önerilen kabul eşikleri** (kod bunları dayatmaz; kurucu/Motion onayı bekler):

| Ölçüt | Önerilen eşik |
|---|---|
| Kare maliyeti (build+raster) p95 | ≤ 16,7 ms (60 Hz) ya da ≤ 8,3 ms (120 Hz cihazda yalnız bilgi amaçlı) |
| 20 ms'yi aşan art arda kare (kodun kendi bütçesi) | 8 kareden az |
| Jank kare oranı (sahne + pratik) | < %1 |
| Bulanık katman açıkken ile kapalıyken fark | Bulanık açıkken p95 farkı ≤ 2 ms |

Eşik aşılırsa bulgu: cihaz, senaryo, ortanca/p95/en kötü, ekran görüntüsü; bayrak açma kararı Motion'a gider (bu belge karar vermez).

## 3. Bulanık katman kontrolü

- Sahnede katman açıkken en çok **bir** bulanık yüzey olmalı. Doğrulama: DevTools Widget Inspector'da `BackdropFilter` sayısı (profil modunda Inspector sınırlı olabilir; **doğrulanacak**) ya da hata ayıklama derlemesinde yalnız sayı kontrolü (ölçüm değil).
- Kartlar (GlassCard) bulanıksız, düz yarı saydam görünmeli (#25 görsel kanıtı: `flag25-once-kart-basina-blur.png` / `flag25-sonra-duz-dolgu.png`).
- Yüksek karşıtlık ya da yeniden saydamlık azaltma açıkken katman opak olmalı (`MediaQuery.highContrast`).
- Açık not (#25): desenli/hareketli zeminde kart arkası blur kalkınca daha okunur görünür; kontrast kapısı yalnız düz `shell` zeminini ölçer. Cihazda okunurluğu gözle kontrol et ve notla.

## 4. Mikrofon izni reddi → "Başlat" davranışı

Beklenti koddan çıkarılmıştır; cihazda aynen gözlenir.

**Kapı mantığı** (`lib/app/audio/mic_permission_gate.dart`, `startAfterPermission:50`, `run:67`):

1. İzin zaten verilmişse (`knownGranted` ya da durum granted) doğrudan başlar.
2. Kalıcı reddedilmiş ya da kısıtlıysa sistem penceresi **açılmaz**; başlatma çağrılır ve denetleyici reddi bildirir.
3. Henüz sorulmamışsa sistem penceresi açılır (`request`). Sonuç **reddedildiyse**: "denetleyici yeniden sorar (pencere çıkmaz) ve reddi gösterir" (kod yorumu); yani başlatma çağrılır, ölçüm başlamaz.
4. Sonuç **verildiyse**: uygulama ön planda ve yaşam döngüsü 800 ms sakin olana kadar beklenir (en çok 4 sn); bu sürede arka plana gidildiyse ya da ekran kapandıysa **hiçbir şey başlamaz, kullanıcı yeniden dokunur**. Bu ilk "İzin ver" sonrası bir kez yeniden dokunma gerektirebilir; olağan bir hata değil, kodun tasarımıdır.
5. Aynı anda ikinci çağrı (`_pending`) yok sayılır.

**Ekran davranışı (Başlat düğmesi):**

| Ekran | Dosya | Reddedince beklenen | Kalıcı reddedince beklenen |
|---|---|---|---|
| Pratik | `lib/app/practice/loop/practice_loop_screen.dart` (`practice-start`, `_begin`, `_failureText`) | Pratik "başarısız" aşamasına geçer (`_fail('permission')`); "mikrofon erişimi kapalı" bildirimi (`practice-failure`); **Başlat** düğmesi etkin kalır (yalnız 3 sn'lik önizlemede pasif) | Aynı bildirim; "Ayarlar'ı aç" düğmesi bu ekranda **kodda yok** (yalnız metin "Ayarlar'dan izin verebilirsin"). Cihazda böyle mi: **doğrulanacak** |
| Akort | `lib/app/tuner/tuner_screen.dart` (`tuner-start-stop`, satır 339-353; "Ayarları aç" düğmesi 355-357) | `permissionDenied` aşaması; "izin verilmedi, dersler mikrofonsuz çalışır, istersen yeniden dene" metni (`TunerCopy.phaseDenied`); **Başlat** yeniden etkin (`canStart`) | `permissionDeniedPermanent`; "Ayarlar'da kapalı" metni ve **Ayarları aç** düğmesi (`openAppSettings`) |

Cihaz günü kontrol listesi (her cihazda, iOS + Android):

- [ ] Reddet → bildirim çıktı mı, ölçüm başlamadı mı (seviye çubukları sabit)?
- [ ] Reddet sonrası **Başlat** yeniden dokunulabiliyor mu? Tekrar dokununca ne oluyor (pencere çıkmaması beklenir, ikinci kez reddedilmiş sayılır)?
- [ ] Kalıcı red (iOS: Ayarlar → Ostinato → Mikrofon kapalı; Android: ikinci reddi ya da "Bir daha sorma"): akortta "Ayarları aç" çıkıyor mu; pratikte yalnız metin mi?
- [ ] Ayarlardan izni aç, uygulamaya dön: **Başlat** çalışıyor mu (iOS/Android uygulamayı sonlandırabilir; sonlanırsa not et)?
- [ ] İzin ver sonrası ilk Başlat ölçümü hemen başlıyor mu, yoksa bir kez daha dokunmak gerekiyor mu (madde 4 beklentisi)?

Not: her cihaz için sonuç `GEÇTİ` / `TAKILDI` olarak tablonun "İzin reddi sonrası Başlat" sütununa yazılır.
