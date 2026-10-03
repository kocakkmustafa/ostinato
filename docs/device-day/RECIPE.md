# Cihaz günü reçetesi (F5, 2026-08-16, O-160)

> 2026-10-02: Bu belge eski 28-ders/mikrofonsuz sürümün tarihsel reçetesidir.
> Güncel ilk kurs 60 TR/EN gitar dersi ve isteğe bağlı cihaz üstü tek-nota
> gözlemidir. Aşağıdaki profil, cihaz, izin ve ekran ölçümleri güncel kabul
> sayılmaz; provisioning güncellemesi veya kurulum yetkisi vermez. Yayın haftası
> güncel source/native/provider/signed/store kapıları `workspace/PROGRESS.md`
> ve `scratch/2026-10-01-release-week-dispatch/lanes/ostinato/STATUS.md` içinde
> ayrı kaydedilir. Gerçek medya ve kurucunun tüm-ders kamera/mikrofon kabulü
> son toplu aşamadadır.

**Amaç:** kurucu telefonunu bağladığında beş dakikada yürünecek, üç adımlı
bir akış. **Kurulum** (adım 2) otomatik/betiklenebilir (D9) — **yürüyüş**
(adım 3) kurucunun elini ister (`H-9`: fiziksel cihazda dokunuş MCP ile
sürülemez, mobile-mcp yalnız simülatör listeler).

---

## 1 — Ön-uçuş (30 saniye, komut satırından)

```bash
python3 tools/device_day_preflight.py
```

Telefon USB ya da güvenilir Wi-Fi ile bağlıyken koş. Üç şeyi ölçer —
tahmin etmez: geçerli codesign kimliği var mı, `com.yulalab.ostinato`
profili var/güncel mi, **bağlı cihazın GERÇEK UDID'si** (`devicectl`'in
kendi eşleşme kimliği DEĞİL — `H-9`/`O-129` dersi, ikisi ayrı değer)
profilin `ProvisionedDevices` listesinde mi.

**Bugün ölçülen durum (2026-08-16, kurucunun eşleşmiş `Mustafa Kaan
iPhone` — 14 Pro Max):** ✅ TEMİZ. UDID `00008120-001804D83E13C01E`
zaten kayıtlı, profil `2027-08-13`e kadar geçerli. Cihaz günü bu profil
ve bu telefonla yapılırsa **tazeleme adımına gerek YOK.**

⚠️ Betik `✅ ÖN-UÇUŞ TEMİZ` DEMEZSE, aşağıdaki adım 2'ye geçme —
önce şu komutla profili tazele (Automatic signing kendi üretir, kod
değişmez):

```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination "id=<GERÇEK-UDID>" \
  -allowProvisioningUpdates build
```

## 2 — Kurulum (D9, tek komut)

```bash
flutter install --release -d <cihaz-adı-veya-id-öneki>
```

**Neden `--release`, `--debug` DEĞİL** (`H-9`/`O-130` ölçümü): Flutter
debug motoru cihazda JIT ister, iOS onu engelliyor — paket kurulur,
`devicectl device process launch` `EXIT 0`/"Launched application" bile
yazabilir, ama süreç anında `signal 11` ile ölür. Yalnız `--release`
(AOT derleme) cihazda GERÇEKTEN çalışır. `--release` zaten `flutter
install`ın VARSAYILANI — ekstra bayrak GEREKMEZ, ama yanlışlıkla
`--debug` yazılmasın diye burada adıyla uyarılıyor.

## 3 — Yürüyüş (kurucu eli ister — beklenen kanıt listesi)

| # | Ekran/eylem | Ne YAPILACAK | "Çalışıyor" NASIL görünür | Sorun işareti |
|---|---|---|---|---|
| 1 | Uygulama açılışı | Ana ekrandan `Ostinato` ikonuna dokun | Navy zemin + beyaz postür-figürü ile açılış ekranı bir an görünür, sonra "Measured, not chosen." onboarding kartı gelir | Beyaz ekran/kırpışma/çökme (debug paketiyse SIGNAL 11 burada olur) |
| 2 | Onboarding (3 kart) | "Continue" ile ilerlet | "Small, and honest about it" (3/28/10/3 sayıları) → "What we will ask for" (kamera/mikrofon-yok/tıbbi-değil kartları) | Sayılar ekranda 0 ya da boş görünüyorsa içerik paketi eksik demektir |
| 3 | Kütüphane | "Open the library"a dokun | START HERE şeridi (3 kart) katlamanın ÜSTÜNDE, altında Guitar/Voice/Piano kartları | START HERE görünmüyorsa/en altta ise D16 regresyonu |
| 4 | Bir çalgı seç → Setup Check | Guitar/Voice/Piano'dan birine dokun, "Start the lesson"a kadar ilerlet | Kamera izni İSTENİR (ilk kez) — sistem izin diyaloğu, uygulamanın kendi ekranı DEĞİL | İzin diyaloğu HİÇ çıkmazsa `NSCameraUsageDescription` sorunu |
| 5 | Kamera izni onayı | "Allow" | Canlı kamera görüntüsü + iskelet-çizim ÜZERİNE biner (omuz/kalça noktaları + gövde çizgisi) | Kare gelmiyor/donuk görüntü → kamera köprüsü canlılık sorunu (bu turda test EDİLMEDİ, ilk gerçek kanıt burada olacak) |
| 6 | Canlı ders | Telefonu tut, gövdeni eğ | Bant-içi/bant-dışı işareti (görsel + varsa ses işareti — mikrofon YOK, yalnız görsel) gerçek hareketle DEĞİŞİR | İşaret hareketle DEĞİŞMİYORSA ölçüm hattı kopuk |
| 7 | "Stop and see the summary" | Dersi bitir | Review ekranı: ölçülen bant + eğri + "What we did not judge" bölümü | Çökme/boş ekran → D14 session-store hattı sorunu |
| 8 | İkinci bir ders (aynı çalgı ya da farklı) | Adım 4-7'yi TEKRARLA | Review ekranında ARTIK "Last session" kartı GÖRÜNÜR (D14 — önceki oturumun özeti) | Kart hiç çıkmazsa yerel kayıt (`sessions.jsonl`) yazmıyor demektir |
| 9 | Ayarlar | Kütüphaneden dişli ikonuna dokun | Kamera/mikrofon-yok/paylaşım/build kartları — hepsi bugünkü GERÇEĞİ anlatıyor (D14 sonrası: "a short summary… is kept on this device") | Eski dil ("nothing is stored") görünüyorsa D14 metni geri almış demektir |
| 10 | Uygulamayı tamamen kapat, YENİDEN aç | Home'a dön, app switcher'dan kapat, yeniden aç | Onboarding TEKRAR ÇIKMAZ (bir kez tamamlandı, hatırlanır), doğrudan kütüphaneye düşer | Onboarding her seferinde çıkıyorsa `onboarding_store.dart` yazmıyor demektir |

**Bu turda YAPILMAYAN, cihaz günü İLK KEZ ölçülecek olanlar (adıyla,
belirsizlik gizlenmedi):** kamera köprüsünün canlılığı (madde 5-6) —
şimdiye kadar yalnız simülatörde, sahte/enjekte kaynakla test edildi
(`full_flow_test.dart`); GERÇEK bir telefon kamerasının GERÇEK bir
insan gövdesini okuyup okumadığı bu proje için **hiç ölçülmedi.** Cihaz
günü bunun ilk kanıtı olacak — reçete bunu bir "son kontrol" değil
**asıl soru** olarak çerçeveliyor.

---

## Kaynaklar

- Ön-uçuş betiği: `tools/device_day_preflight.py`
- İmza/kurulum dersi: kişisel hafıza `feedback-ios-cihaz-kurulum-imza.md`
  (`O-129`/`O-130`, aile çapında `H-9`)
- İçerik/dürüstlük zemini: bu reçete `docs/store/screenshots/
  ostinato-hatti-iphone17pro/` ile AYNI ekranları anlatır — simülatörde
  ÇEKİLENLERİN cihazda da GERÇEKTEN böyle davrandığını doğrulamak bu
  reçetenin işi.
