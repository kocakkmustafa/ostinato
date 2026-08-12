# DESIGN-AHEAD-OF-CODE — Ostinato giydirme turu (2026-08-06)

> Kaynak: `claude.ai/design` "Ostinato" projesi (`Ostinato.dc.html`, 1195
> satır, giydirme turunda `DesignSync` ile içe aktarıldı — tam proje UUID'si
> bu belgede İDDİA EDİLMİYOR, önceki turun aktarım kaydından TEYİTSİZ
> hatırlanıyordu; gerekirse `DesignSync list_projects` ile yeniden
> doğrulanabilir) vs bu turda
> giydirilen kod (`lib/app/screens/*.dart`, `lib/app/design/*.dart`,
> `lib/main.dart`).
>
> Bu bir kusur listesi DEĞİL — aşağıdakilerin hiçbiri tasarımda ya da kodda bir
> hata değil. Koordinatörün istediği envanter: tasarımın gösterdiği ama kodun
> karşılığı olmayan HER ŞEY, ve kodun taşıdığı ama tasarımın hiç değinmediği
> HER ŞEY — sonraki (inşa) turunun kapsamı hafızadan değil kanıttan
> kararlaştırılsın diye. Bağlam sıcakken (tasarım MCP'den yeniden içe
> aktarmak bedelsiz, `.dc.html`'i elle yeniden okuyup bu listeyi yeniden
> türetmek pahalı) yazıldı.
>
> Her kalem için: hangi ekran/bileşen · ne yapıyor · neden yok · inşa
> edilirse neye dokunur.

---

## 1. Tasarım > Kod (tasarımda VAR, kodda YOK)

### 1.1 🔴 Sesli antrenör göstergesi — ailenin çekirdek vaadi, kodda SIFIR

**Tasarım (`coachOn` + `toggleCoach`, Live ekranı, satır 543-553):** ölçüm
sırasında yüzen bir panel — animasyonlu 4-çubuklu "konuşma" göstergesi +
"Coach is speaking — the microphone is on and you can see it. Nothing is
being recorded to send." Sol panelde ayrı bir "Coach speaking · on/off"
geliştirici-anahtarıyla açılıp kapanıyor (satır 59) — `cueTreatment`/
`demoTreatment` gibi "Explorations" değil, kalıcı bir durum alanı
(`state.coach`).

**Kod:** hiçbir karşılığı yok. Ne bir TTS/ses çıkışı, ne "konuşuyor"
göstergesi, ne `coach` alanına benzer bir durum — `live_screen.dart`'ta
yalnız gözlem işareti (metin paneli) var.

**Neden yok:** giydirme turunun kapsamı GÖRSEL yeniden-giydirmeydi (var olan
ÖLÇÜLMÜŞ işlevselliğin — trunk_tilt, gözlem işareti — yüzeyini tasarıma
taşımak), yeni bir SES-AI yeteneği eklemek değil. `motion-core`nun aile
sözleşmesi (`00-AILE-MIMARISI.md` §1.1) "sesli antrenör-vaadi çekirdek; V1 =
sıra, tavan DEĞİL" diyor — bu göstergenin tasarımda bulunması, bu vaadin V1
sırasında beklendiğinin görsel kanıtı, ama Ostinato'nun bugünkü motoru
konuşan bir şey ÜRETMİYOR (yalnız golden-katalog metni, ekranda okunan
sessiz cümleler).

**İnşa edilirse neye dokunur:** bu KÜÇÜK bir UI-göstergesi eklemekten çok
daha büyük bir iş — gerçek bir TTS/ses hattı (motion-core seviyesinde, aile
geneli bir yetenek olması muhtemel), `PostureEvaluator`/`ObservationCue`
zincirinin sese de yayını, izin modeli (mikrofon zaten var ama ÇIKIŞ sesi
yeni), ve muhtemelen `motion-core`nun kendisinde bir karar (aile geneli mi,
app-özel mi). Bu turun ya da tek bir sonraki inşa turunun kapsamı değil —
koordinatör/kurucu kararı gerektiren bir ÇEKİRDEK yetenek sırası sorusu.

### 1.2 Library — "START HERE" çapraz-çalgı şeridi

**Tasarım (`starters`, satır 133-145 + 982-986):** üç enstrümanın HER
BİRİNDEN birer ders (Gitar "Camera and space" · Şan "How much teachers
actually differ" · Piyano "How you sit at the keyboard"), kendi renk-kimliği
ile, "START HERE" başlığı altında, instrument kartlarının HEMEN ALTINDA.

**✅ YAPILDI (2026-08-13, `O-117`).** Şerit `library_screen.dart`'ta;
`_StarterRow`, anahtar `starter-<disiplin>`.

**Açık bırakılan karar KAPANDI — türetildi, elle yazılmadı.** "Hangi 3 ders"
kimliği ekranda DEĞİL `library.json`'da: her canlı disiplin bir
`starterLessonId` + `_why_starter` bildiriyor, ekran yalnız çözüyor. Gerekçe
bu deponun kendi kuralından: `honesty.instrumentSpecificGap` aynı sebeple
veriye taşınmıştı — *seçim ekran kodunda gömülü olsaydı gözden geçirilemezdi.*
Üç kimliğin KAYNAĞI icat değil, onaylı `Ostinato.dc.html` (satır 133-145 +
982-986); `_why_starter` alanları o satırları adıyla taşıyor.

**Kapı:** `tools/validate_starters.py` (+ `--selftest`, 6 mutasyon + pozitif
ikiz) — ① canlı disiplin starter bildirir ② kimlik gerçekten vardır
③ starter `locked`/`demoOnly` OLAMAZ (*"Start here" bir çıkmaza işaret
edemez*) ④ **ekran kodu hiçbir ders kimliği taşımaz** ⑤ gerekçe boş olamaz.
Gerçek dosyada üç sabotaj da indi (ekrana kimlik gömme · starter'ı kilitli
derse çevirme · bildirimi silme).

**Test:** `test/library_starters_test.dart` (4 test) — beklenen değerlerin
hiçbiri elle yazılmadı, hepsi `repo`dan türüyor; gezinme tanığı
`NavigatorObserver` (ilk yazımda "şerit kayboldu mu" diye sormuştum ve test
haklı olarak düştü: `Navigator.push` önceki rotayı silmez, örter).

**⚠️ Ölçülen sınır, kaydı için:** şerit 375×812'de **katlamanın altında** —
tasarım onu kartların "HEMEN ALTINA" koyuyor ve en dar yaygın telefonda
oraya scroll'suz ulaşılmıyor. Bu bir kusur olarak DÜZELTİLMEDİ (tasarımın
yerleşimi korundu); yerleşim kararı olarak koordinatöre yazıldı.

### 1.3 Library — instrument kartı altında 0-24° ortak-ölçek bandı

**Tasarım (satır 125-127, 130):** her instrument kartının İÇİNDE, çalgı
adının hemen altında ince bir yatay çubuk — o çalginin öğretmen-bandının
0-24°'lik PAYLAŞILAN bir ölçek üzerindeki konumu/genişliği. Altında açıklama:
"The bar under each instrument is the range the teachers we recorded
actually occupy, on one shared scale of 0–24°. Piano's is narrow because
three teachers is also the thinnest evidence we hold."

**✅ YAPILDI (2026-08-12, `O-053`).** `_InstrumentCard` artık
`HorizontalBandTrack` taşıyor (anahtar `band-scale-<disiplin>`), altında
sayı satırı ve kartların altında paylaşılan-ölçek notu
(`library-band-scale-note`).

⚠️ **BU SATIR 2026-08-13'e kadar BAYAT DURDU** — inşa 08-12'de bitti, bu
belge hâlâ *"kart bunu taşımıyor"* diyordu. Bulan: §1.2'yi inşa etmek için
aynı dosyayı okuyan tur (O-117). Sınıf tanıdık: **artefaktın varlığı işin
durumunu güncellemez** — "tasarım>kod" listesi, kod yetiştiğinde ELDE
kapatılmazsa ters yönde yanıltır (yapılmış işi yapılmamış gösterir).

**Tasarımın açıklama cümlesi KASITLI YAZILMADI:** taslak, piyanonun dar
bandını "üç eğitmen en ince kanıt" diye açıklıyordu; bant genişliği ölçülen
ARALIKTAN gelir, kaynak SAYISINDAN değil — ikisini nedensel bağlamak
ölçmediğimiz bir ilişkiyi iddia etmek olurdu. Sayılar yan yana duruyor, bağı
kuran cümle yok.

### 1.4 Demo-lesson: "Begin" düğmesi HİÇBİR treatment'ta kodda yok

**Tasarım (Treatment A satır 356, Treatment B satır 396):** her iki
treatment da "Begin — same setup, no mark" düğmesiyle biter — `startSetup`'a
bağlı, yani demoOnly bir ders de (gitar/şan/piyano "kollar" dersi) Setup
Check → Live zincirine girilebiliyor tasarımda.

**Kod:** `lesson_demo_screen.dart` bir DEAD END — hiçbir düğme Setup
Check'e ya da Live'a götürmüyor. Kullanıcı bilgiyi okur, geri döner.

**Neden yok:** kısmen KASITLI, kısmen isimlendirilmemiş sınır. Canlı dirsek
açısı hiç ölçülmediği için (§1.1'in küçük kardeşi — bkz. §2.5) bir "Begin"
düğmesi kullanıcıyı Live ekranına götürse bile orada göreceği şey yalnız
GÖVDE bandı olurdu (kol verisi yok) — tasarımın "YOUR ELBOW ANGLE, LIVE"
52px'lik büyük canlı sayısını hiç gösteremezdi. Düğmeyi eklemenin kendisi
yalın (Setup Check zaten discipline-agnostic), ama SONUCU (Live ekranında ne
gösterileceği) bir dürüstlük kararı ister.

**İnşa edilirse neye dokunur:** `lesson_demo_screen.dart`'a `PrimaryButton`;
`live_screen.dart`'ın `_MeasuringFigure`'ının demoOnly ders için ne
göstereceğine karar (yalnız gövde bandı + "kol verisi yok" notu mu, yoksa
demoOnly dersler Live'a hiç girmesin mi — ikisi de savunulabilir, tek taraflı
karar verilmedi).

### 1.5 Review — "consent" + paylaşım akışı: tasarımda İNTERAKTİF, kodda STATİK not (zaten dürüstçe ele alınmış)

**Tasarım (satır 666-690):** gerçek bir onay kutusu (`toggleConsent`) +
"Send the skeleton report" düğmesi, onay yoksa devre dışı. Metin: "Raw video
never leaves this device... A shared report is a skeleton render and asks
for your consent each time."

**Kod:** `review_screen.dart`'ta `Key('review-sharing-gap-note')` — statik
metin: "Sharing a skeleton-render report is not wired in this build. Raw
video never leaves this device either way — there is simply no report to
send yet."

**Neden yok:** paylaşım altyapısı (rapor üretimi, gönderim kanalı) hiç
kurulmadı — bu bir GİYDİRME kararı değil, gerçek bir eksik yetenek.

**Not — bu KALEM örnek teşkil ediyor, yeni bulgu değil:** bu, tasarımın
interaktif bir akış gösterdiği ve kodun onu DÜRÜSTÇE isimlendirdiği (sahte
bir onay kutusu/düğme ÇİZMEDİ) bir örnek — §17 talimatının ("dürüstçe
uygulanamayan şeyi İSİMLE durdur, taklit etme") doğru uygulaması. Buraya
yalnız gelecek bir incelemenin bunu "atlanmış" sanmaması için yazıldı.

**İnşa edilirse neye dokunur:** rapor-üretim formatı (skeleton-render neyi
kapsar?), gönderim kanalı (email? dosya paylaşımı? bir sunucu mu?) — ürün
kararı, bu turun kapsamı değil.

---

## 2. Kod > Tasarım (kodda VAR, tasarımda YOK) — sinsi yön

### 2.1 🟡 Review "Neyi ölçemedik" — 4. kalem İNŞA EDİLDİ (2026-08-07, O-044); tasarımın SOMUT olay-kalemi hâlâ açık

**Tasarım (`gaps`, satır 1030-1035; `gapsHeadline: 'Four things, by
name.'`):**
1. "Landmark confidence below the bar — the light dropped when you turned. Nothing from this window was counted." (süre: 3.6s)
2. "Your left hip left the frame. There was no trunk line to measure, so there is no reading, not a zero." (süre: 1.2s) — SOMUT, tek bir olayı anlatıyor
3. **Çalgıya göre DEĞİŞEN üçüncü kalem** — gitar: "Everything below your hips, and your fingers on the fretboard"; piyano: "Wrists, fingers and hand shape... no hand landmarks at all"; şan: "Pitch and sustain. The engine ran, but it is unconfirmed on a real singing voice"
4. "Your arms. Measured throughout and shown to you live, but never marked — the teachers disagree by X to Y degrees."

**Kod (`review_screen.dart` satır 64-71, `'Three things, by name.'`):**
1. "Landmark confidence below the bar. Any window like that is not counted, not scored as zero." — tasarımın (1) ile eşleşir
2. "Anything outside what this lesson measures — trunk alignment only; no other joint carries a verdict here." — GENEL bir kapsam beyanı; tasarımın SOMUT "sol kalça çerçeve dışına çıktı" olayına da, çalgıya-özel üçüncü kaleme de KARŞILIK GELMİYOR
3. "Your arms..." — tasarımın (4) ile eşleşir

**Kayıp:** tasarımın SOMUT "hip left the frame" olayı VE çalgıya-özel üçüncü
kalem (gitar-fret/piyano-el/şan-perde) kodda hiç yok — kodun 2. kalemi
ikisinin YERİNE geçen genel bir cümle, ama ikisinin taşıdığı bilgiyi
taşımıyor.

**Neden bu fark hiç fark edilmedi:** giydirme turu bu bölümü "zorunlu +
eşit-ağırlıklı" kuralına (§6/⑫) göre denetledi — YAPISI (zorunlu, eşit
ağırlık, tek sonraki-adım) doğrulandı, İÇERİĞİN tasarımla satır-satır
örtüşmesi denetlenmedi.

**✅ YAPILDI (2026-08-07, `O-044`).** Çalgıya-özel 4. kalem inşa edildi ve
`gaps` 3→4 oldu. **Ekran kodunda dallanmadı** — metin `library.json`ın
`honesty.instrumentSpecificGap` alanından geliyor, `_instrumentSpecificGap_source`
her birinin hangi `notMeasured` satırından kısaltıldığını taşıyor. Gerekçe:
hangi boşluğun "bu çalgının kendi boşluğu" sayıldığı bir SEÇİMDİR; seçim ekran
kodunda gömülü olsaydı gözden geçirilemezdi, veride durunca denetlenebiliyor
(ve dördüncü çalgı eklendiğinde `if` zinciri unutulamaz).

**Aynı turda çıkan İKİNCİ kusur:** başlık `'Three things, by name.'` ELLE
yazılıydı, tam altındaki liste de elle yazılıydı — 4. kalem eklenince başlık
SESSİZCE bayatlayacaktı. O-029'un ("vitrin korumasızdı") canlı-yüzey hâli.
Sayı artık `gaps.length`ten türüyor (`_countWord`). Kilit: 
`test/review_gap_section_test.dart` (5 test) — MUT 2/2: başlık elle yazıldı →
kırmızı · çalgıya-özel kalem tek genel cümleye düştü → kırmızı.

**⛔ HÂLÂ AÇIK — tasarımın SOMUT olay-kalemi** ("Your left hip left the frame",
süre 1.2s). Bu bir içerik değil VERİ AKIŞI eksiği: `_LiveScreenRouteState._hist`
yalnız toplam `outCount`/`sampleCount` tutuyor, HANGİ pencerenin HANGİ sebepten
sayılmadığını tutmuyor. Süre etiketleri (3.6s/1.2s) de per-gap ölçüm ister.
Uydurulamaz, bu yüzden yazılmadı.

**İnşa edilirse neye dokunur:** ~~`gaps` listesi 3'ten 4'e çıkar~~; çalgıya-özel
4. kalem `discipline.id`e göre dallanır (gitar/piyano/şan farklı cümle) —
veri zaten `Discipline`/`Lesson` modelinde var, yeni ölçüm gerekmez, yalnız
içerik. Süre-etiketleri (3.6s/1.2s) GERÇEK bir oturumda per-gap ölçülen süre
gerektirir — bu YENİ bir veri akışı (`_LiveScreenRouteState`'in `_hist`i
şu an yalnız toplam `outCount`/`sampleCount` tutuyor, HANGİ pencerenin HANGİ
sebepten sayılmadığını değil).

### 2.2 Setup Check — "silence"/"noisy" tasarımda AKTİF durumlar, kodda TEK statik "henüz yok" kartı

**Tasarım (`setupStage`, 6 değer: `framing`/`framingError`/`lowLight`/
`silence`/`noisy`/`passed`):** `silence` GERÇEK bir 4 saniyelik geri-sayım
(`silenceT` 0→4, otomatik `passed`'a geçer), canlı 9-çubuklu bir ses-seviyesi
animasyonu (`noiseBars`) ile. `noisy` AYRI bir başarısızlık durumu — oda
yeterince sessiz değil.

**Kod (`_Stage` enum, 6 değer: `starting`/`framingError`/`lowLight`/`ok`/
`room`/`passed`):** `room` TEK bir statik `_RoomGapNotice` — "Not measured
in this build... there is no microphone input in this build." `noisy`
durumunun kodda hiç karşılığı yok (mikrofon girdisi olmadığı için
"yetersiz sessizlik" ölçülemez).

**Bu, koordinatörün önceden isimlendirdiği kalemin (oda gürültü-tabanı
adımı) İLK KEZ bu kadar KESİN ölçüldüğü yer** — eksik olan yalnız "bir adım"
değil, İKİ AYRI DURUM (aktif ölçüm + başarısızlık) ve bir görsel dil
(`noiseBars` animasyonu).

**İnşa edilirse neye dokunur:** gerçek bir mikrofon-girdi eklentisi
(`ostinato_audio`'nun `AudioConfidenceGate`i zaten var, bağlı değil);
`_Stage`a `noisy` eklenmesi; `PLACEHOLDER-REGISTER.md`'deki `flow` kaydı
zaten bu işi işaretliyor — bu bölüm onu SAYISALLAŞTIRIYOR.

### 2.3 `demoTreatment` A/B — tasarımın kendi çatalı, koordinatöre hiç taşınmadı

**Tasarım (`data-props`, satır 706; "Explorations" bölümü):** `cueTreatment`
(A/B) ile AYNI statüde, AYRI bir ikinci "Explorations" değişkeni. Treatment A
= gövde-ile-aynı-düzen, tek renkli kart, işaret büyük canlı sayı. Treatment B
= "parity by symmetry" — iki EŞİT kart ("WHAT YOU GET"/"WHAT YOU DON'T"),
ikisi de tam renkli, ikisi de aynı boyutta.

**Kod:** `lesson_demo_screen.dart` ikisinin de TAM karşılığı değil — Treatment
A'nın iskeletine yakın (rozet-başlık, TEK renkli kart, 3-bölümlü beyaz kart)
ama A'nın "52px büyük canlı sayı" öğesini TAŞIMIYOR (çünkü canlı veri yok —
bkz. §1.1/§1.4) ve B'nin "iki eşit kart" simetrisini hiç denemedi.

**Fark, giydirme raporunda NEDEN görünmedi:** orijinal 17 maddelik uyum
listesinin §15'i yalnız gözlem-işareti (`cueTreatment`) için "tam 2
görünürlük önerisi" istiyordu — `demoTreatment`'ın AYRI, PARALEL bir
Explorations değişkeni olduğu hiç fark edilmedi, bu yüzden koordinatöre
"A mı B mi" diye hiç sorulmadı; kod sessizce bir üçüncü, isimsiz hibrit
inşa etti.

**KARAR (koordinatör hükmü, 2026-08-06):** "isimsiz çıkış çıkış değildir" —
hibrit isimsiz kalamaz. **Treatment A seçildi**, geriye dönük olarak
isimlendirildi (`lesson_demo_screen.dart` başlık yorumu): kod zaten A'nın
iskeletine (rozet-başlık, TEK renkli kart, 3-bölümlü beyaz kart) sadıktı,
TEK sapma A'nın 52px canlı-sayı öğesiydi — bu bir tasarım tercihi değil,
veri kısıtı (§1.1/§1.4). Treatment B'nin "iki eşit kart" simetrisi hiç
denenmedi, DENENMEYECEK (A seçildiği için). Kod DEĞİŞMEDİ, yalnız kayıt
eklendi (DEFTER OK-13).

**İnşa edilirse neye dokunur:** canlı dirsek verisi gelirse (§1.1/§1.4),
A'nın 52px canlı-sayı öğesi eklenir — bu YENİ bir tasarım kararı GEREKTİRMEZ,
zaten seçilmiş Treatment A'nın eksik parçasını tamamlar.

### 2.4 Kilitli-ders yüzeyi — tasarımda VAR, kodda VAR, TAM eşleşme (koordinatörün adayı doğrulandı, açık bulunmadı)

**Tasarım (satır 293-318, "LESSON — LOCKED"):** rozet + başlık + "WHY IT IS
LOCKED" + gerekçe metni.

**Kod:** `lesson_locked_screen.dart` — bu turda inşa edildi, bu oturumda
canlı sim ekranında GÖZLE doğrulandı (Sustained note dersi).

**Sonuç:** koordinatörün "4 kilitli dersin gerekçe yüzeyleri" adayı — bu
kalem tasarımda VE kodda birebir örtüşüyor, açık bulunmadı. Buraya yalnız
sistematik olarak KONTROL EDİLDİĞİ kayda geçsin diye yazıldı.

### 2.5 Live durum uzayı — kodun 7 hâli tasarımın 3 hâlinden daha zengin (iyi yönde, aksiyon gerektirmez)

**Tasarım (`liveStage`, 3 değer):** `countdown`/`measuring`/`blind`.

**Kod (`SurfaceState` sealed class, 7 alt-tip):** `Starting` ·
`PermissionDeniedRetriable` · `PermissionDeniedPermanent` · `SetupFailed` ·
`CameraUnavailable` · `NoPersonVisible` · `Measuring`.

**Neden fark var:** tasarım aracı gerçek izin diyalogları/donanım hatalarını
simüle edemez (bir slider/buton demosu) — kodun GERÇEK cihazda dayanması
gereken hâller doğal olarak daha fazla. Bu bir eksiklik DEĞİL, beklenen
asimetri — sinsi yönün ZARARSIZ hâli (kod tasarımdan FAZLASINI taşıyor,
AZINI değil).

### 2.6 Çocuk rejimi — tasarımda da YOK (koordinatörün adayı: mutabık gaib, açık bulunmadı)

`Ostinato.dc.html`'de "child" geçen TEK bir satır yok. Kod da bilerek
taşımıyor (`settings_screen.dart` doc-yorumu + placeholder kaydı). Bu bir
"kod > tasarım" boşluğu DEĞİL — ikisi de KARŞILIKLI yok, tutarlı, ve
kasıtlı (kurucu kararı bekliyor, § "17 uygunluk maddesi").

---

## 3. Ayrıca ölçülenler (delta değil, ama kayda değer)

### 3.1 "Needs focus." — koordinatör hükmüyle değişen kelime, ASLINDA tasarımın kendi metniydi

`verdict` mantığı (satır 1022) tasarımda AYNEN şu: `insideShare > 0.66 ?
'Steady.' : (improving ? 'Improving.' : 'Needs focus.')` — bu turun ilk
teslimi tasarımı BİREBİR taşıdı. Koordinatörün 2026-08-06 HÜKÜM 2b'si bu
üçüncü kelimeyi ("hakem dili, öğretmen dili değil") "Mostly outside the
band."a çevirdi — bu, koddaki bir hatanın düzeltilmesi DEĞİL, tasarımın
KENDİ metninden BİLİNÇLİ bir sapma. Gelecekte ekran görüntüsünü mockup'la
yan yana koyan biri bunu "kaçırılmış" sanmasın diye buraya yazılıyor.

### 3.2 Kütüphane sayısı — tasarımın "3 çalgı" iddiası bugünkü `library.json` ile TAM örtüşüyor

Gravita/Choreia'nın kendi belgelerinde bulduğu "tasarımın X iddiası hiçbir
veri kaynağıyla tam örtüşmüyor" sınıfı Ostinato'da YOK — `library.json`
tam olarak 3 canlı çalgı taşıyor (gitar/şan/piyano), `coming_soon` yok, ve
tasarımın kendi `HUES` sabiti de aynı üç çalgıyı tanımlıyor. Tutarlı;
buraya yalnız NEGATİF sonucun da ölçüldüğü kayda geçsin diye yazılıyor.

### 3.3 Malzeme/renk dili — kardeş-ayrışma denetimi bu turda YAPILMADI (Gravita'nın §3.1'i burada YOK)

Gravita'nın belgesi JabLab'dan malzeme-ayrışmasını 5 eksende sayısal olarak
doğruladı. Bu belge o denetimi Ostinato için YAPMADI — orijinal 17 maddelik
uyum raporunun §16'sı ("Lissom/Referans-2 malzeme/renk dili tekrarlanmadı")
yalnız "kendi tasarım kaynağıma sadakat kontrol ettim, kardeş dosyalarla
birebir çapraz-diff yapmadım" diye NİTELEDİ — bu belirsizlik hâlâ AÇIK.
İstenirse ayrı bir tur bunu Gravita'nın yöntemiyle (dosyadan sayarak)
kapatabilir.

---

## Özet tablo

| # | Kalem | Yön | Kategori | Ekran/bileşen gerekir mi | Veri/asset boşluğu |
|---|---|---|---|---|---|
| 1.1 | Sesli antrenör göstergesi | tasarım>kod | **flow (çekirdek yetenek sırası)** | evet | TTS/ses hattı — aile-geneli karar |
| 1.2 | Library "START HERE" şeridi | **✅ YAPILDI (O-117, 2026-08-13)** | — | — | karar KAPANDI: türetildi (`starterLessonId` + kapı) |
| 1.3 | Library 0-24° bant çubuğu | **✅ YAPILDI (O-053, 2026-08-12)** | — | — | — |
| 1.4 | Demo-lesson "Begin" düğmesi | tasarım>kod | flow | hayır (düğme) + karar | Live'ın demoOnly'de ne göstereceği kararı |
| 1.5 | Review paylaşım/consent | tasarım>kod (zaten dürüstçe ele alındı) | flow | evet, ileride | rapor formatı + gönderim kanalı |
| 2.1 | Review "4 şey" içeriği | kod<tasarım (içerik eksik) | data | hayır (mevcut ekrana içerik) | çalgıya-özel 4. kalem + per-gap süre verisi |
| 2.2 | Setup silence/noisy | kod<tasarım (durum eksik) | flow (PLACEHOLDER kaydında zaten var) | hayır (mevcut ekrana durum) | gerçek mikrofon girdisi |
| 2.3 | demoTreatment A/B çatalı | **karar VERİLDİ: Treatment A** (2026-08-06) | — | hayır | canlı dirsek verisi gelince A'nın sayı-öğesi tamamlanır |
| 2.4 | Kilitli-ders yüzeyi | **eşleşme — açık YOK** | — | — | — |
| 2.5 | Live durum-uzayı zenginliği | kod>tasarım, zararsız | — | — | — |
| 2.6 | Çocuk rejimi | **karşılıklı yok — açık YOK** | — | — | — |

---

## Kaynaklar

`assets/content/library.json` · `assets/config/posture-contract.json` ·
`docs/design/PLACEHOLDER-REGISTER.md` · `docs/design/UI-BRIEF.md` ·
`docs/design/DESIGN-PANEL-PROMPT.md` · `ventures/motion-core/lib/docs/00-AILE-MIMARISI.md`
§1.1 · claude.ai/design "Ostinato" projesi (UUID doğrulanmadı, bkz. üstteki not).
