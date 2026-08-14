# ⏸️ BEKLEME MODU — DESIGN LİNKİ BEKLENİYOR (devir: 2026-08-05, koordinatör yazdı)

> **Bu blok en güncel talimattır ve altındaki her şeyden ÖNCELİKLİDİR.**
> Aşağıdaki eski bölüm (önceki oturumun devir promptu) teknik durum/sınırlar için
> GEÇERLİ — ama "kendi tasarımını sen yap" varsayımı **SÜPERSEDE** edildi (M-F-279).

## 🎨 Yeni model (kurucu kararı 2026-08-05)
Tasarımlar **TEK design-orkestrasyonu oturumunda** üretilir (Remotion + Claude design
paneli), sonra sana **tasarım linki + giydirme brief'i** olarak gelir. Her uygulama
KENDİ dilinde, birbirinden TAMAMEN FARKLI tasarlanacak.

**BU OTURUMDA YAPMAYACAKLARIN:**
- ❌ Tasarım kararı üretme (renk/tipografi/düzen/akış dili) — yön koordinatörden gelir.
- ❌ Kendi başına design turu başlatma, UI yeniden yazma, "cila" turu koşma.
- ❌ Kurucuya doğrudan tasarım sorusu sorma (M-F-77; koordinatörden geçer).

**BU OTURUMDA YAPACAKLARIN:**
1. Aşağıdaki okuma listesini bitir (bağlam kopukluğu olmasın).
2. Ağacı doğrula: `git -C ventures/ostinato/app status` + `git -C ventures/ostinato/app log -1` (**beyana değil ağaca güven**).
3. Kısa bir "hazırım" özeti yaz: okuduklarını + doğrulanan tepe commit'i + varsa
   ağaçta beklenmedik bir şey. **Sonra BEKLE.**
4. Giydirme brief'i gelince: tasarımı KENDİ yüzeyine uygula, dürüstlük sınırlarını
   ESNETMEDEN (aşağıda), kapılarını koştur, commit+push (kalıcı yetkin var).

## 📖 Okuma listesi (sırayla — bağlam bunlarda)
1. **Vault:** `knowledge/Yula Lab/20 Şirketler/Motion/🔄 Oturum Devri 2026-08-05 — Ostinato Kabuk Doğdu + Canlı Postür Yüzeyi.md (§6 gece-2 eki dahil)` — senin son turunun kaydı.
2. **Vault:** `📊 Durum Panosu — Motion.md` → **08-05 "GÜNCEL DURUM BU BLOK"** (altı tarihsel).
3. **Vault:** `🔄 Oturum Devri 2026-08-05 — Orkestratör Kamera Dalgası Kapanışı → Design Orkestrasyonu Devri.md` — §4 yeni model + §5 kalan işler.
4. `ventures/ostinato/workspace/DEFTER.md` + `PROGRESS.md` — **son bölüm** (kendi hükümlerin).
5. `ventures/motion-core/workspace/DEFTER.md` — **M-F-260 → M-F-279** (aile kuralları, bağlayıcı).
6. Bu dosyanın altındaki eski bölüm — teknik durum, ölçülmüş tuzaklar, bağlayıcı sınırlar.

## 📍 Senin durumun (2026-08-05, git-doğrulandı)
Kabuk + canlı postür yüzeyi CANLI, **gerçek kamera BAĞLI** — main `e7fd492`, push 0/0, izlenen-kirli 0 (3 untracked = iCloud artığı, DOKUNMA). ✅ **O-032 KAPANDI · TUR-2 KAPANDI · koordinatörün iki denetim kalemi KAPANDI.** Kod kuyruğun **BOŞ**.

> ⚠️ **Bu blok 2026-08-05 akşamı koordinatör tarafından güncellendi.** Önceki sürüm
> "SEN İSTİSNASIN — O-032 → tur-2" diyordu; o iş BİTTİ ve satır bayatladı (M-F-273 sınıfı).
> Aşağıdaki eski bölümde hâlâ "İLK İŞ = O-032" yazan yerlere rastlarsan: **onlar tarihsel**,
> bağlayıcı olan bu bloktur. Teknik reçeteler (platform duvarları, pub tam-40-SHA,
> sim çekişmesi, sert kurallar) aynen geçerli.

**Bu turda ne oldu (kalıcı, `08c5017` + `e7fd492`):**
- **O-032'nin cevabı düzeltme değil TEŞHİS: bug yoktu.** Yedi adayın hepsi elendi (son aday
  route sarmalayıcısı `route_path_test.dart` ile çürütüldü); canlı cold-launch koşumu işaretin
  5/5 pencerede ateşlediğini VE render edildiğini gösterdi. **Kod değişmedi.**
- Gerçek sebep: 30sn cooldown işareti pencerenin **%7,4**'ünde görünür kılıyor
  (aralıklar 30,06/33,30 sn ALTERNATİF, ort. 31,68 — 166,67 kare tamsayı olmadığı için
  32-karelik tur içinde iki faza düşüyor; deterministik, jitter değil).
- **🎓 O-035 → aileye terfi (M-F-281):** *"kasıtlı NADİR görünen UI öğesi tek-anlık gözlemle
  'kırık' sanılır"* — panzehir: zamanı kontrol eden deterministik test **ya da** bilinen-fazlı
  çoklu örnekleme. **M-F-277 "ekran kanıtı KAPIDIR" kuralının SINIRI budur.**
- Tur-2: `CameraPoseSource` + `CameraPostureAdapter`; açı geometrisi İCAT EDİLMEDİ
  (motion_core `StandardJoints.trunkTilt` + izotropik + `ConfidenceGate`).
  Kanıt sınıfı: *plumbing+izin+hâller sim-kanıtlı; gerçek görüntü cihaz-günü release-gate.*
- `cooldownUs` artık dayanağını taşıyor (**değer değişmedi**): kardeşinden zayıf olduğu,
  hiçbir artefakta bağlı olmadığı ve 20→30 geçişinin **kayıtsız** olduğu İSİMLE yazılı.

**İlk işin:** okuma listesi + ağaç doğrulaması + kısa "hazırım" özeti → **sonra BEKLE.**
Diğer dört hatla aynı moddasın; istisnan bitti.

**⛔ Design brief'inde AÇILACAK (şimdi dokunma):** *"gözlem işareti zamanın %7,4'ünde
görünmeli mi?"* — bu YÜZEY kararı (anti-nagging ↔ görünürlük dengesi). Değeri kendi başına
değiştirme; brief'te birlikte açılacak.

**⏳ Açık borcun (cihaz-günü, O-036 — İSİMLİ, kod işi değil):**
1. `CameraLens.front` seçimi cihazda sınanmadı (Gravita'nın **arka**-kamera kararından FARKLI).
2. M-O-08 açılı-oturuş sınırı (gitar/piyano diyagonal) gerçek görüntüyle ölçülmedi.

## 🚧 Tasarımda da ESNEMEYEN sınırlar (giydirme sırasında geçerli)
- **K8:** kalibre edilmemiş sayısal skor YOK ("bant, nokta değil").
- **M-F-186:** vaat dili (`comingSoon`/"yakında") YASAK · engelli özellik İSİMLİ
  gerekçeyle görünür · `measurementOnly` beyanı **yüzeyin TEPESİNDE** (konum içeriğin parçası).
- **Dürüst hâller birinci sınıf ekrandır** (izin · kamera-yok · kimse-yok · kadraj-dışı) —
  tasarım bunları "artık" gibi ele alamaz; hâl-başına ayrı render yolu korunur.
- **Türetimli listeler elle yazılmaz** · ham `detail`/hata kodu yüzeye sızmaz.
- **Ekran kanıtı KAPIDIR:** "testler metnin VARLIĞINI sınar, DOĞRULUĞUNU sınamaz"
  (95 yeşil test yanlış-anatomi metnini görmedi — Lissom P0 dersi).
- Yeni ölçü/kapı/eşik tasarımı veya dürüstlük-metriği hükmü → **koordinatöre**.

## ⚙️ Kalıcı kurallar
- commit + push + merge **KALICI YETKİLİ**; `ventures/motion-core/lib` paylaşımlı ağacında
  **dal değiştirmek YASAK** (M-F-22).
- **iCloud-altı repoda `git add -A` yerine DOSYA-İSİMLİ add** (0-bayt `index.lock` riski, M-F-273);
  başkasının untracked dosyasına dokunma (M-016; `* 2.plist`-sınıfı iCloud artıkları dahil).
- **Bağlam sıkışırsa İSİMLİ DURDUR** — sessiz kalite düşüşü yerine isimli duruş (aile standardı).
- **Cihaz-kanıtı vaat edilmez:** iOS sim'de kamera YOK; gerçek-kamera canlılığı cihaz gününe
  ertelendi (kurucu, tek oturum). Hiçbir yüzey "cihazda kanıtlı" demez.

---
---

# 🚀 Yeni Ostinato oturumu — kopyala-yapıştır prompt

> Üretildi: 2026-08-05, tur-1 (kamera entegrasyonu, kabuk) kapanışında.
> **İLK İŞ = O-032 → sonra TUR-2 (gerçek kamera).** Sonrası: tasarım turu.
>
> ⚠️ **Koordinatör oturum ID'si buraya YAZILMAZ.** Bir kimliği dosyaya yazmak,
> onu bayatlatmanın en hızlı yoludur — bu hat bir kez ölü ID'ye rapor etmeye
> çalıştı. Koordinatörü `list_sessions`'tan **başlığıyla** bul
> ("Motion Orchestration"), ID'yi o an kopyala.

```text
Ostinato oturumusun — Yula Motion ailesinin müzik-enstrüman app'i.
2026-08-05 kamera-entegrasyonu vardiyasının DEVAMISIN. Tur-1 (kabuk + canlı
postür yüzeyi) MÜHÜRLÜ; tur-2 (gerçek kamera) SENDE — ama ondan ÖNCE
kapatılacak bir şüphe var.

OKU (sırayla, iş almadan önce):
1. ventures/ostinato/workspace/PROGRESS.md — tur 54 (en üstteki giriş)
2. ventures/ostinato/workspace/DEFTER.md — O-032 (AÇIK) · O-033 · O-034
3. app/docs/evidence/README.md — 4 ekran kanıtı + O-032'nin tam anlatımı
4. ventures/motion-core/workspace/DEFTER.md — M-F-263 · M-F-264 · M-F-269

DURUM:
- app/main = f76da34, origin ile EŞİT, çalışma ağacı temiz.
- Kapılar: `./tools/run_gates.sh` → 16/16 (~5 dk).
  MUT-A ayrı tur: `python3 tools/gate_mutation_test.py` → 13/13.
- Üç çalgı LIVE (gitar 7 ders · şan 6 · piyano 6). Flutter kabuğu VAR:
  `lib/` + `ios/` + `android/`, iOS sim + Android debug derlemesi yeşil.
- Pin: `f13bdc9` — **TAM 40-SHA olarak** `f13bdc93b2eae2f741bfcdb4c9270a88e5d75e5d`
  (motion_core 0.11.0 + motion_camera 0.1.2). DEĞİŞTİRME.
- SessionStore ADOPTE EDİLMEZ: tüketici yüzeyi (pratik geçmişi) doğana dek
  yasak — kendi kuralımız, isimli erteleme sürüyor.

╔═ İLK İŞ: O-032 — kamera BAĞLANMADAN ÖNCE ═══════════════════════════════╗
Gözlem işareti ÇALIŞAN UYGULAMADA görünmüyor. Bu "screenshot alınamadı"
DEĞİL — ölçülen üç şey:
  (a) `PostureEvaluator` işareti ÜRETİYOR (demo senaryosu doğrudan
      geçirildi: index 15'te cue=true, sonrası cooldown'la bastırılıyor),
  (b) widget onu ÇİZİYOR (3 widget testi),
  (c) çalışan uygulamada, aralık-dışı pencerenin ORTASINDA da (21,0°) YOK.
Yakalama zamanlaması ELENDİ (pencere 7→15 kareye uzatıldı).
TEŞHİS TURU YAPILDI (2026-08-05) — ŞÜPHE ÇÜRÜTÜLDÜ, DÖRT ADAY ELENDİ:
`test/timer_path_test.dart` (2 test, ikisi YEŞİL) gösterdi ki gerçek
zamanlayıcıyla VE uygulamanın TAM senaryosuyla (null kareler dahil) işaret
DOĞUYOR. Elenenler: değerlendirici · widget çizimi · zamanlayıcı/akış yolu ·
demo senaryosu · yakalama zamanlaması · bayat ikili (uninstall→install).
KALAN TEK ADAY (yine TAHMİN): navigasyon/route sarmalayıcısı —
`MaterialPageRoute` builder'ı her yeniden-çizimde YENİ `FakePoseSource`
üretiyor, State ise `initState`te bağlandığı kaynağı dinliyor. Testlerde
route YOK: testlerin uğramadığı TEK fark bu.
SIRADAKİ DENEY: route'suz vs route'lu aynı ekranı karşılaştıran test, ya da
`flutter run` ile canlı log.
REPRODÜKSİYON REÇETESİ (birebir tekrarlanabilir):
  1. `flutter build ios --simulator --debug` → install → **cold** launch
     (`simctl terminate` sonra `launch`; sıcak launch eski değerlendirici
     durumunu korur ve cooldown'ı yanlış okutur).
  2. Gitar kartına dokun (nokta koordinatı ~219,173 · iPhone 17 Pro Max).
  3. Girişten ~2,7-4,5 sn sonra ekran yakala: demo senaryosu 180 ms/kare,
     aralık-dışı bölüm 13.-27. kareler → 2,34-5,04 sn penceresi.
  4. BEKLENEN: 3. sapmadan (index 15) itibaren işaret kutusu. GÖRÜLEN: yok.
Doğrulama araçları: `flutter run` ile canlı log/print · widget testini
GERÇEK zamanlayıcıyla (`t.pump(Duration(...))`) koşturan bir test ·
değerlendiriciyi doğrudan senaryodan geçiren küçük bir `bin/` betiği
(bu turda kullanıldı, `cue=true @ index 15` verdi).

İKİ KURAL:
· **TEŞHİS DOĞRULANMADAN ÜZERİNE KOD YAZILMAZ.** Yukarıdaki şüphe sınıfı
  TAHMİNDİR; önce hangi halkanın koptuğu ÖLÇÜLÜR, sonra düzeltilir. Tahmine
  göre yazılan düzeltme, arızayı taşıyıp yerini değiştirebilir.
· Kamerayı canlı yolu kanıtlanmamış bir yüzeye BAĞLAMA — iki belirsizlik
  üst üste binerse hangisinin bozuk olduğu ayrılamaz.
╚═════════════════════════════════════════════════════════════════════════╝

TUR-2 — gerçek kamera (O-032 kapandıktan SONRA):
· `motion_camera` plugin platform-kayıtları + izin akışı +
  `CameraController` → `PoseSource` adaptörü.
· Eşleme HAZIR: `CameraFailure.permissionDenied` → izin hâllerin ·
  `modelLoadFailed`/`noSuchCamera` → `SetupFailed(reason)` · landmark yok →
  `NoPersonVisible`. **Yüzey DEĞİŞMEYECEK** — kaynak `status` akışını
  doldurur, ekran aynı sealed hâlleri çizer.
· Sim'de GERÇEK GÖRÜNTÜ YOK (iOS): kanıt cümlesi DÜRÜST yazılır —
  "plumbing + izin + hâller sim-kanıtlı; gerçek görüntü cihaz-günü
  release-gate". Bağlandı ≠ canlı.
· [ops.] Android emülatör sanal-sahne smoke'u.

SONRASI: tasarım turu (kurucu-manuel). `app/docs/design/UI-BRIEF.md` eki
hazır; gözlem-işareti screenshot'ı oraya devredildi (O-032 kapanınca alınır).

⚙️ PLATFORM DUVARLARI — UYGULANDI, BOZMA:
· iOS deployment **14** (Podfile + pbxproj) — MediaPipe şartı.
· `use_frameworks! :linkage => :static` — MediaPipe statik xcframework;
  dinamikte kırılıyor.
· `LANG=en_US.UTF-8 pod install` — CocoaPods bunu ister.
· pub ref **TAM 40-SHA** olmalı: pub ref'leri ÇÖZMEZ, STRING karşılaştırır.
  Kısaltılmış ref TEK BAŞINA çözülür; arıza ancak İKİ TARAF anlaşmak
  zorundayken görünür (motion_camera tam-SHA pinliyor).
· iCloud: `build/` → `~/ostinato_buildout` symlink, İLK derlemeden ÖNCE.
· Sim çekişmesi: screenshot öncesi diğer app'leri `simctl terminate` →
  kendi app'ini `launch` → HEMEN screenshot. Makine paylaşımlı; kardeş
  oturumun app'i öne geçerse ÇEKİŞMEYE GİRME.

SERT KURALLAR (bu hatta ihlal edilmedi, edilmesin):
- EŞİK İCADI YOK. Her eşik artefakttan türer, türetimini makine-okunur
  taşır; sayı doğru olsa bile GEREKÇE bayatlayabilir (O-024).
- KABUK YALNIZ KABLOLAMA: her hüküm `packages/ostinato_posture`ta ve testte.
  Bir sayı widget'a sızarsa test edilemez hâle gelir.
- K8: SAYISAL SKOR YOK. `Measuring`de `score` alanı bilerek yok; bant konumu
  bir KONUM ve bant dışında `null` döner (1.0 döndürmek tavana yapışmış bir
  puana çevirirdi).
- MOTOR KULLANICI METNİ ÜRETMEZ: işaret templateId + yuva taşır; cümle
  golden katalogdan doldurulur (yasak-dil taramasından geçmiş).
- TEST-İKİZİ, TÜKETTİĞİ SÖZLEŞMEYİ İHLAL EDEMEZ (O-033): sahte kaynak
  monotonik saat yayar; ihlal ederse sessizce ölü bir özellik üretir.
- Bir ATIF bir VAATTİR: çözülmek yetmez, KENDİ çalgısının dünyasına
  çözülmeli (`tools/validate_references.py`).
- Her YOKLUK iddiasının pozitif ikizi olacak; kapı yazdıysan SABOTAJLA sına.
- Toplam oran girdi-başı arızayı ÖRTER (O-028): teşhis girdi başınadır.
- Yükseltme: yeni ölçü/kapı/eşik TASARIMI = KOORDİNATÖRE. Kurucuya soru
  YASAK (M-F-77) — dört istisna: harcama · store submission · nihai fiyat ·
  lisans-riski.

AÇIK BORÇ:
- **O-032 (P1, AÇIK)** — yukarıda; tur-2'nin ÖN KOŞULU.
- O-025 (P2): zamanlama motorunun 8,29 ms geometri sapması — kök neden
  ölçüldü, düzeltme 12× kanıtlandı, UYGULANMADI (mimari karar).
  Protokol: `app/docs/gates/O-025-TIMING-CALIBRATION-PROTOCOL.md`.
- Kurucu-bekleyen: 🎸 gerçek gitar kaydı → "Open chords" · 🎤 gerçek vokal
  kaydı → "Sustained note". İkisi de ~10 dk, ara mühendislik SIFIR.
- P-ELBOW-ANGLE · P-POST-SHOULDER-TENSION · G-* aspirational kodlar:
  hepsi isimli eksikle bloklu (alet ya da istatistik).
```
