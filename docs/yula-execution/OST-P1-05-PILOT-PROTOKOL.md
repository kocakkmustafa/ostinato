# OST-P1-05 — 14/30/90 gün öğrenme pilotu: ekransız, rubrikli, kör değerlendirmeli protokol

Tarih: 2026-11-17 · Taban: `origin/main` · Durum: **PROTOKOL TASLAĞI — pilot BAŞLATILMADI** (yalnız belge) · Durum özeti: [`STATUS.md`](STATUS.md) · Karar kayıtları: [`DECISIONS.md`](DECISIONS.md) · Önceki protokol: [`OST-P0-09-PROTOKOL.md`](OST-P0-09-PROTOKOL.md)

## 1. Amaç ve sınır

- Amaç: Ostinato ile düzenli çalışan az sayıda katılımcıda, 14, 30 ve 90. günde **öğrenme kazanımına dair gözlem** toplamak ve bunu bağımsız uzmanlarca kör değerlendirmeyle karşılaştırmak. Çıktı "pilot gözlem"dir; kanıt iddiası değildir (§10).
- Bu belge **yalnız protokoldür.** Pilot başlatmaz, katılımcı çağırmaz, kayıt toplamaz, ölçüm sonucu içermez. Hiçbir hücrede ölçülmüş sayı yoktur; sonuç alanları `NOT_STARTED` ile başlar.
- **Pilotu başlatmak dış etkidir ve kurucu onayı ister** (§13 onay satırı). Katılımcıya ulaşmak, rıza almak, uzman çağırmak, mağaza dağıtımı ya da sürüm yayını bu belgenin işi değildir.
- Bu belge kullanıcıya gösterilecek metin üretmez. Rıza metni P0-09 §5.3'ten **atıfla** alınır; yeni kullanıcı metni burada yazılmaz.
- Kamera bayraklarına (`ostinatoCameraLessonsOpen`, `ostinatoCameraPracticeAvailable`; `lib/app/ostinato_release_policy.dart`) dokunulmaz; kamera kapsam dışıdır.
- Marka metinlerde "Yula Lab". Kullanıcıya olumsuz nota/ritim hükmü gösterilmez; düşük güvende hüküm verilmez (ürün kuralı P0-09 §1 ile aynıdır).

## 2. Katılımcı seçimi ve rıza

| Konu | Kural (öneri; kurucu onayı bekler) |
|---|---|
| Kapsam | Gitar kursu (kodda desteklenen yüzey). Mikrofonsuz içerik ayrı izlenmez. |
| Boyut | Hedef küçük bir grup; kesin sayı kurucu onayında yazılır: `N = ____`. Bu belge sayı uydurmaz. |
| Dahil olma | Yetişkin, gönüllü, pilot süresince ana çalışma aracı olarak Ostinato'yu kullanmayı kabul eden, kayıt olmadan da katılabilen kişi. |
| Dışlama | Reşit olmayanlar (ayrı veli rızası ve hukuki inceleme gerekir; bu protokol kapsamaz), Yula Lab ile ticari/ailevi bağı olan kişiler, değerlendirici olarak da görev alacak kişiler. |
| Yaş sinyali | Uygulamada yaş sinyali yoktur (ADR-005: `RetentionAudience` varsayılan `unknown`). Yetişkinlik **beyanla** alınır; uygulamadan çıkarılmaz. |
| Rıza | P0-09 §5.3 rıza metni **yeniden kullanılır**, iki ek ayrı onay kutusuyla: (a) pilot ölçüm özetinin paylaşılması, (b) ses kaydı paylaşımı. (b) isteğe bağlıdır; verilmezse katılım sürer. |
| Çekilme | Katılımcı her an çekilir; kayıt ve türev etiketler silinir (§9). Çekilmenin bedeli yoktur. |
| Kimlik | Katılımcı anonim kısa kodla anılır (`K01`…). Eşleme tablosu veri dosyalarından ayrı ve erişimi kısıtlı tutulur; değerlendiricilere gösterilmez. |

## 3. Ölçüm noktaları: 14 / 30 / 90 gün

Gün sayısı, katılımcının **rıza gününden** (`G0`) başlar.

| Nokta | Gün | Ne toplanır |
|---|---|---|
| Başlangıç | G0 | Çalışma geçmişi beyanı (süre, daha önce enstrüman), tanı amaçlı kısa standart çalış-ve-kaydet görevi (§6.2), katılımcı ön beyanı. |
| Ara 1 | G14 | Cihazda hesaplanan özet göstergeler (§5) + standart görev. |
| Ara 2 | G30 | Aynı. |
| Son | G90 | Aynı + katılımcı kapanış beyanı. |

Kurallar: ölçüm penceresi nominal günün ± 3 günüdür (**önerilen; kurucu onayı bekler**); dışına çıkan ölçüm `kapsam-dışı` etiketlenir ve birincil analize girmez. Eksik ölçüm doldurulmaz, tahmin edilmez; `eksik` yazılır ve çekilme/devamsızlık oranı ayrıca raporlanır.

## 4. Ekransız ilke ve veri sınırı

- **Kamera yok, ekran kaydı yok, ekran görüntüsü toplama yok.** Pilot hiçbir görüntü verisi üretmez.
- **Ham ses cihazdan çıkmaz** (ADR-005: ses yalnız cihaz içi, geçici; kalıcı saklama ve export yok; `ostinatoRecordingRetentionOpen` varsayılan `false`). Pilotta da bu değişmez.
- Cihazdan yalnız **cihazda hesaplanan özet göstergeler** çıkabilir (§5). Çıkış yolu **bu belgede tasarlanmaz**; mevcut durumda uygulama içi dışa aktarma ya da senkron yoktur (`ostinatoProgressSyncAvailable = false`, `lib/app/ostinato_release_policy.dart:91`; export yokluğu ADR-005). Veri toplama yolu açık sorudur (§12, R1) ve ayrı bir bilet gerektirir.
- Ses incelemesi (kör değerlendirme için) yalnız (a) katılımcının ayrı ve açık rızasıyla, (b) katılımcının kendi eliyle verdiği kayıtla, (c) pilot dışı kanalda yapılır; uygulamanın kayıt politikası bunun için gevşetilmez. Rıza yoksa kör değerlendirme yapılmaz ve katılımcı yalnız özet göstergelerle analiz edilir.

## 5. Ölçütler

Göstergeler uygulamanın mevcut alanlarından türetilir. Kaynak: `lib/app/practice/loop/practice_outcome.dart` (`PracticeRunSummary`, `PassGate`, `NoteOutcome`) ve `lib/app/practice/loop/practice_progress_store.dart` (`V1PracticeRecord`). Alan adları koddan alınmıştır; kodda yeni alan varsayılmaz.

### 5.0 Kalıcılık sınırı (kodla doğrulanmış; ölçüt seçimini belirler)

- `V1PracticeRecord` (`practice_progress_store.dart`) yalnız **ömür boyu en iyi** değerleri tutar: `bestAccuracy`, `bestHeard`, `bestBpm` yalnız artar. `bestBpm` yalnız `gate.passed` olan koşuda güncellenir (`:102`); ders hiç geçilmediyse `null`'dır. Bu kayıttan **gerileme** ve **koşu-başı doğruluk değişimi gözlenemez**; yalnız "en iyi değer en az şu kadar oldu" okunur.
- `medianTimingMs`, `timingCalibrated`, `errorBars`, `shownStep` dağılımı ve `ineligible` oranı **kalıcı değildir**; yalnız koşu sonucu ekranında (`PracticeRunSummary`) bulunur, `V1PracticeRecord`'a yazılmaz.
- Bu yüzden gerileme, koşu-başı ölçüm ve yukarıdaki kalıcı olmayan göstergeler **ayrı bir koşu-başı kayıt gerektirir**: kod değişikliği ya da katılımcının elle kaydı. Bu **R1 sınıfı açık iştir, ayrı bilet** (§12, R1 ve R11); bu belge kodu değiştirmez. Bilet açılmadan o göstergeler "ölçülemiyor" diye işaretlenir ve hiçbir sonuç cümlesine girmez.

### 5.1 Birincil ölçütler

| Ölçüt | Türetme (gerçek alanlar) | Not |
|---|---|---|
| **Doğruluk / ritimde zamanında oran** | `PracticeRunSummary.accuracy` = `correct / (correct + different)` (koşu sonucunda); kalıcı karşılığı yalnız `V1PracticeRecord.bestAccuracy` (ömür boyu en iyi, §5.0); ritim hatlarında `PassGate.criteria.onTimeMs` doluysa aynı oran "zamanında oran" anlamına gelir | `different` = farklı nota işareti (`PracticeMark.differentNote`). `couldNotHear` paya girmez. |
| **Duyulma oranı (ölçümün geçerliliği)** | `PracticeRunSummary.heard` = `(correct + different) / total` | `PassCriteria.minHeard` varsayılanı .8; altı olan koşu ölçüm sayılmaz (`heardTooLow`). Kodda `heard < minHeard` koşu **`eligible` kalır** (`heardTooLow` bir kapı kontrolüdür, `ineligible` listesine girmez); bu yüzden analiz kuralı §5.3'te `heard`'ı ayrıca ister. Düşük duyulmada kazanım iddia edilmez. |
| **Tempo kazanımı** | `PracticeRunSummary.bpm` (koşu temposu), `openBpm`, `targetBpm`; kayıtta `V1PracticeRecord.bestBpm`, `passedBpm`, `completedBpm` | Kazanım = G0 ile ölçüm noktası arasında, **aynı derste** `bestBpm` farkı; `bestBpm` yalnız geçilen koşuda güncellendiği için ders hiç geçilmediyse `null`'dır ve kazanım `ölçülemiyor` yazılır. Farklı derslerde karşılaştırma yapılmaz. |
| **Kapı geçişi** | `PassGate.passed`, `PassGate.completed`; kayıtta `passedAt`, `completedAt` | Geçiş ölçüleri `PassCriteria.expertPending = true` ile işaretlidir: eşikler uzman doğrulaması beklemektedir (§7 kör değerlendirme bunu sınar). |

### 5.2 İkincil ölçütler

| Ölçüt | Türetme | Not |
|---|---|---|
| Tekrar / çalışma sayısı | `V1PracticeRecord.runs`, `lastRunAt` | Süreklilik göstergesi; tek başına öğrenme değildir. |
| Zamanlama sapması | `PracticeRunSummary.medianTimingMs` (mutlak değerlerin ortancası), `timingCalibrated` | **Kalıcı değil** (§5.0). Yalnız `timingCalibrated = true` ise karşılaştırılır; kalibrasyonsuz değerler ayrı etiketlenir. |
| Tutarlılık | Aynı derste ardışık koşuların `accuracy` dağılımı (ortanca ve en küçük–en büyük) | **Kalıcı değil** (§5.0): `bestAccuracy` ömür boyu en iyidir, dağılım vermez; koşu-başı dağılım ayrı kayıt gerektirir (R11). |
| Hata kümesi | `PracticeRunSummary.errorBars` (sayı olarak) | Ölçü numarası değil, **yalnız adet** çıkar; içerik kimliği taşımaz. **Kalıcı değil** (§5.0). |
| Önerilen sonraki adım | `PracticeRunSummary.shownStep` (`NextStep`) dağılımı | Ürün yönlendirmesinin davranışını gözlemek için. **Kalıcı değil** (§5.0). |
| Koşu uygunluğu | `PassGate.ineligible` (`stoppedEarly`, `loopUsed`, `waitUsed`) oranı | Ölçülmüş koşu / ölçülmemiş koşu ayrımı. **Kalıcı değil** (§5.0). |

### 5.3 Analiz kuralı

Birincil analize yalnız `PassGate.eligible && heard >= PassCriteria.minHeard` (varsayılan .8) olan koşular girer; diğerleri ikincil dağılımda ayrı sayılır. Eşleştirme ders düzeyinde yapılır (`lessonId`). Koşu düzeyinde süzme (`eligible`, `heard`) ancak koşu-başı kayıt varsa uygulanabilir (§5.0); yoksa yalnız ömür boyu en iyi değerler karşılaştırılır ve bu kısıt raporda yazılır.

## 6. Veri toplama düzeni

### 6.1 Cihazda hesaplanan özet kaydı (öneri şeması)

```csv
katilimci_kodu,olcum_noktasi,tarih,ders_id,kosu_sayisi,en_iyi_dogruluk,en_iyi_duyulma,en_iyi_bpm,gecis_bpm,tamamlama_bpm,ortanca_zamanlama_ms,kalibre,uygun_kosu_orani,sonraki_adim_dagilimi,not
```

Alanlar §5'teki alanlardan türer; **kaynakları eşit değildir**: `kosu_sayisi`, `en_iyi_*`, `gecis_bpm`, `tamamlama_bpm` `V1PracticeRecord`'dan okunabilir (ömür boyu en iyi, §5.0). `ortanca_zamanlama_ms`, `kalibre`, `uygun_kosu_orani`, `sonraki_adim_dagilimi` kalıcı değildir: kaynakları **kod değişikliği ya da elle kayıt gerektirir, ayrı bilet** (R1/R11); o zamana dek bu sütunlar `ölçülemiyor` kalır. Ses, görüntü, kişisel veri, konum, hesap bilgisi yoktur. `katilimci_kodu` anonimdir. `en_iyi_*` alanları `V1PracticeRecord` içindeki `bestAccuracy`, `bestHeard`, `bestBpm`; `gecis_bpm` = `passedBpm`; `tamamlama_bpm` = `completedBpm`.

### 6.2 Standart görev (kör değerlendirme girdisi)

Her ölçüm noktasında, katılımcının kendi cihazında, **aynı sırayla** ve yönlendirme olmadan tek bir standart parça çalınır (parça ve tempo kurucu onayında sabitlenir; G0'da seçilen derse bağlı olabilir ve 90 gün boyunca değişmez). Ses kaydı yalnız §4'teki rıza koşuluyla ve katılımcının eliyle teslim edilir. Rıza yoksa bu adım atlanır. **Açık soru:** katılımcının standart görevi kaydetme ve teslim aracı belirsizdir. Uygulama ham sesi cihazdan çıkarmaz ve kalıcı saklamaz (§4), bu yüzden kaydın hangi aracla (örn. cihazın kendi ses kaydedicisi) alınıp hangi kanalla teslim edileceği kurucu kararı ve ayrı bilet bekler; o karar yoksa kör değerlendirme yapılamaz.

## 7. Kör değerlendirme

Biçim P0-09 §5.1 (kör değerlendirme formu), §5.2 (bağımsızlık beyanı) ile uyumludur; burada pilot için genişletilmiştir.

### 7.1 Düzen

- **Kör**: değerlendirici kaydın hangi ölçüm noktasından (G0/G14/G30/G90) geldiğini, hangi katılımcıya ait olduğunu ve ürünün çıktısını bilmez. Kayıtlar rastgele sıraya konur ve kodlanır; kod anahtarı değerlendiricilerden ayrı tutulur.
- **Bağımsızlık**: değerlendirici Yula Lab ile ticari, ailevi ya da başka çıkar bağı olmayan, eğitimli bir enstrüman uzmanıdır. P0-09 §5.2 beyanı **imzalı ve eksiksiz** olmalıdır; aksi halde değerlendirme kanıt sayılmaz. Katılımcıyı tanıyan değerlendirici o kaydı puanlamaz.
- **İki değerlendirici**: her kayıt, birbirinden bağımsız çalışan **iki** değerlendiriciyle puanlanır; birbirlerinin puanını görmezler.
- **Tutarsızlıkta üçüncü**: iki değerlendirici bir boyutta **2 ya da daha fazla puan** ayrışırsa o kayıt, ilk ikinin puanını görmeyen **üçüncü** değerlendiriciye gider; nihai puan üç puanın ortancasıdır. Üçüncü de bağımsızlık beyanı verir. (Eşik 2 puan önerilir; kurucu onayı bekler.)
- Ürün çıktısı, yalnız tüm puanlar kilitlendikten sonra açılır ve karşılaştırma ayrı bir adımdır.

### 7.2 Form (YAML)

```yaml
degerlendirme_id: ""          # PL-<YYYYMMDD>-<sıra>
degerlendirici_kodu: ""       # anonim; kimlik bu dosyada yok
sira: 1                       # 1 | 2 | 3 (üçüncü yalnız tutarsızlıkta)
kayit_kodu: ""                # rastgele kod; nokta/katılımcı bilgisi içermez
kor: true                     # nokta, katılımcı ve ürün çıktısı bilinmeden puanlandı
puanlar:                      # 1…5; 0 = değerlendirilemez
  ritim_dogrulugu: 0
  perde_temizligi: 0
  sureklilik: 0
  akicilik_ve_kontrol: 0
serbest_not: ""
tarih: ""
```

Pilotta P0-09 rubriğinin üç boyutu aynen korunur; **akıcılık ve kontrol** boyutu pilot için eklenmiştir (zaman içindeki gelişimi yakalamak için). Geri bildirimin pedagojik uygunluğu pilotta puanlanmaz; çünkü değerlendirici ürün çıktısını görmez.

### 7.3 Ankerli rubrik (1–5, ara değer yok)

| Puan | Ritim doğruluğu | Perde temizliği | Süreklilik | Akıcılık ve kontrol |
|---|---|---|---|---|
| **1** | Vuruşların çoğu hedef ritimden belirgin kopuk; pulse izlenemiyor | Notaların çoğu belirsiz, çınlama/gıcırtı baskın | Sık duraklama ya da kopma; parça tamamlanmıyor | Hareketler denetimsiz; tempo sürekli dalgalanıyor |
| **2** | Yarıdan azı oturuyor; sapma tekrarlayan | Temiz notalar azınlıkta | Duraklamalar parçanın akışını bozuyor | Denetim kısa süreli; sık toparlanma gerekiyor |
| **3** | Çoğu vuruş oturuyor; arada belirgin sapma var | Notaların çoğu temiz; kimi çınlama/entonasyon sorunu | Bir ya da iki duraklama; parça sonuna ulaşıyor | Tempo çoğunlukla sabit; zorlanan yerde denetim düşüyor |
| **4** | Neredeyse tümü oturuyor; sapmalar küçük ve seyrek | Temiz; yalnız tek tük kusur | Kesintisiz; çok küçük tereddüt | Rahat ve denetimli; küçük dalgalanma |
| **5** | Tüm parça hedef ritimle tutarlı | Her nota temiz ve entonasyonlu | Kesintisiz ve dengeli | Akıcı, rahat, tempo sabit |
| **0** | Değerlendirilemez (kayıt kullanılamaz/ses yok/parça farklı) | | | |

Not: Bu rubrik bir **öneridir**; değerlendiricilerle bir kalibrasyon oturumunda (üç örnek kayıtla, puanlar tartışılarak) sabitlenir ve gerekirse tanımlar sıkılaştırılır. Kalibrasyon kayıtları pilot verisine girmez.

### 7.4 Uyum ölçümü

- İki değerlendirici arasında boyut başına **ağırlıklı kappa** (kuadratik) ve **tam + ±1 uyum yüzdesi** raporlanır.
- Önerilen kabul: ağırlıklı kappa ≥ 0,6 ve ±1 uyum ≥ %80 (**önerilen; kurucu onayı bekler**). Altındaysa rubrik yeniden kalibre edilir ve etkilenen kayıtlar yeniden puanlanır; sonuç, uyum sağlanana dek bulgu sayılmaz.
- Yanlılığı gözlemek için değerlendirici başına ortalama puan ayrıca raporlanır.

## 8. Analiz

- **Birincil**: her katılımcıda G0'dan G14/G30/G90'a, (a) `bestAccuracy` değişimi (yalnız artış gözlenebilir, §5.0), (b) aynı derste `bestBpm` değişimi, (c) kör rubrik puanının ortanca değişimi. Üç gösterge **birbirini doğrulamalıdır**; yalnız cihaz göstergesi ya da yalnız rubrik tek başına kazanım iddiasına dönüşmez.
- **Uyum sorusu**: cihaz göstergesi ile kör uzman puanı aynı yönde mi? Ayrışma ürün sinyalinin güvenilirliği hakkında bulgudur (ürünün `PassCriteria.expertPending` eşiklerini uzman verisiyle sınar).
- **Betimleyici**: küçük örnekte çıkarımsal istatistik (p-değeri) raporlanmaz; katılımcı bazında çizgi/tablo ve aralıklar verilir. Gerileme ve koşu-başı değişim bu kayıttan gözlenemez (§5.0). Rastgele kontrol grubu yoktur; bu nedenle nedensellik iddiası yapılmaz (§10).
- Eksik ve çekilen katılımcılar analizden sessizce atılmaz; sayıları açıkça yazılır.

## 9. Veri saklama ve silme

| Veri | Yer | Süre | Silme |
|---|---|---|---|
| Ham ses (uygulama içi) | Yalnız cihaz, geçici | Oturum bitene dek (ADR-005) | Tur/ders kapanışında ve sonraki ders açılışındaki süpürmeyle silinir. Arka plana geçişte silme ve "tümünü sil" temizliği yalnız `ostinatoRecordingRetentionOpen` **açıkken** geçerlidir (varsayılan kapalı) |
| Katılımcının rıza ile teslim ettiği standart görev kaydı | Kısıtlı erişimli tek yer | Değerlendirme bitip rapor kabul edilene dek; **en çok 180 gün** (öneri) | Rıza geri çekilince 7 gün içinde; süre dolunca |
| Özet gösterge kaydı (§6.1) | Kısıtlı erişimli dosya | Rapor kabulünden sonra 12 ay (öneri) | Çekilmede ilgili katılımcı satırları silinir |
| Kod anahtarı / kimlik eşlemesi | Veri dosyalarından ayrı, kısıtlı | Pilot bitişinden sonra en çok 30 gün | Süre dolunca ya da çekilmede silinir |
| Değerlendirme formları | Kısıtlı | Rapor ile birlikte | Çekilen katılımcı için ilgili kayıt kodunun formu silinir |

Kurallar: repoya ses, kimlik ya da kişisel veri **konmaz**; yalnız toplulaştırılmış, anonim rapor repoya girebilir. Süreler öneridir ve kurucu onayı bekler. Silme işlemi yapılınca silme tarihi ve kapsamı (içerik değil) bir kayıt satırıyla işlenir.

## 10. Başarı ve başarısızlık eşikleri — **önerilen, kurucu onayı bekler**

Bu eşikler uydurma kesinlik taşımaz; küçük örnek ve kontrol grubu yokluğu nedeniyle **ön gözlem** için önerilmiştir. Hiçbiri onaylanmadan karar verilmez.

| Sonuç | Önerilen koşul (üçü birlikte, tamamlayan katılımcılar içinde) |
|---|---|
| **Olumlu sinyal** | (a) Tamamlayanların çoğunda `bestAccuracy` G0→G90'da artış ya da aynı derste `bestBpm` artışı; (b) kör rubrik ortanca puanı G0→G90'da en az +1; (c) iki değerlendirici uyumu §7.4 eşiğini geçiyor. |
| **Belirsiz** | Göstergeler çelişiyor, uyum eşiği geçilmedi ya da tamamlama oranı düşük. Sonuç: pilot genişletilmez, protokol gözden geçirilir. |
| **Olumsuz sinyal** | Cihaz göstergesi ve kör puan birlikte artmıyor ya da kör puan geriliyor (cihaz göstergesi gerilemeyi göstermez, §5.0). Sonuç: öğrenme iddiası yapılmaz; ürün/eşik incelemesi açılır. |
| **Geçersiz** | Tamamlama oranı çok düşük, ya da duyulma oranı (`heard`) sık sık .8'in altında (ölçüm güvenilmez). Sonuç: ölçüm geçersiz ilan edilir; ortam ve kalibrasyon sorunları incelenir. |

Kesin sayısal sınırlar (tamamlama oranı, "çoğunda" için oran) kurucu onayında yazılır: `___`. Bu belge onlara sayı atamaz.

## 11. Etik ve pazarlama sınırı

- **Kanıtlanmadan "öğrenme kanıtlandı" denmez.** Bu pilot, kontrol grubu ve yeterli örneği olmayan gözlemsel bir çalışmadır; en iyi ihtimalle "ön gözlem" olarak anılır.
- P0-09 §5.4 geçerlidir: §5.1/§5.2 eksiksiz doldurulmuş en az bir bağımsız uzman değerlendirmesi yoksa uzman doğrulamasına dayanan hiçbir pazarlama iddiası yapılmaz; yapıldığında iddia değerlendirilen kapsamla sınırlı yazılır.
- Katılımcı verisi pazarlamada kişiye bağlanarak kullanılmaz; yalnız anonim toplulaştırma, ve yalnız rıza varsa.
- Katılımcıya ödeme/teşvik, ürün karşılığı ya da kamuya açık paylaşım **bu belgenin kapsamı dışındadır** ve ayrı kurucu onayı ister.
- Katılımcıya düşük performansı için hüküm ya da karşılaştırma gösterilmez; ürün kuralı (düşük güvende hüküm verilmez) pilotta da aynıdır.

## 12. Riskler

| Kod | Risk | Etki | Önlem |
|---|---|---|---|
| R1 | Cihazdan özet çıkarma yolu yok (dışa aktarma ve senkron kapalı) | Veri toplanamaz | Ayrı bilet: katılımcının elle ilettiği özet kart ya da ayrı onaylı, ağsız dışa aktarma kararı; **bu belge çözmez** |
| R2 | Küçük örnek, kontrol grubu yok | Kazanım diğer çalışmalardan ayrıştırılamaz | Nedensellik iddiası yok; betimleyici rapor |
| R3 | Katılımcı kaybı (90 gün uzun) | Önyargı | Çekilme sayısı raporlanır; erken yedek katılımcı havuzu kurucu kararıyla |
| R4 | Değerlendirici bağımsızlığının bozulması | Kanıt değeri düşer | P0-09 §5.2 beyanı zorunlu; tanıma durumunda kayıt atlanır |
| R5 | Kör düzenin sızması (tarih/ortam ipucu kayıtta) | Önyargı | Kayıtlar yeniden adlandırılır; üst veri temizlenir |
| R6 | Eşiklerin uzman doğrulaması bekliyor olması (`expertPending`) | Ürün kapısı ile kör puan ayrışabilir | Ayrışma bulgu sayılır (§8) |
| R7 | Mikrofon/cihaz ortamı farkları (echo, gürültü; bkz. P0-09 §3) | Ölçüm gürültüsü | Standart görevde ortam etiketi; `timingCalibrated` ayrı |
| R8 | Ses kaydı rızasının geri çekilmesi | Veri kaybı | Çekilme meşrudur; eksik olarak raporlanır |
| R9 | Reşit olmayan katılım ihtimali | Hukuki risk | Yetişkin beyanı + dışlama; yaş sinyali yok (ADR-005) |
| R10 | Ürün sürümünün pilot sırasında değişmesi | Ölçümler karşılaştırılamaz | Pilot boyunca sürüm/build sabit ya da her ölçümde build ve commit SHA kaydı |
| R11 | Kalıcı kayıt yalnız ömür boyu en iyi değer tutar; gerileme ve koşu-başı ölçüm gözlenemez | Zayıf kanıt, gizli gerileme | Ayrı bilet: koşu-başı kayıt (kod değişikliği ya da elle kayıt); o zamana dek ilgili göstergeler `ölçülemiyor` |

## 13. Bir sonraki adım ve onay

Bir sonraki adım: kurucu bu protokolü ve §10 eşiklerini inceler; R1 (veri toplama yolu) için ayrı bilet açılır. Pilot yalnız aşağıdaki onaydan sonra başlar. **Onay yoksa hiçbir katılımcı çağrılmaz ve hiçbir veri toplanmaz.**

Onay satırı (kurucu kendi sözleriyle doldurur; bir oturumun mesajı onay değildir):

- [ ] Protokol (§1–§12) ve önerilen eşikler (§10) onaylandı; pilot başlatılabilir. Katılımcı sayısı `N = ____`; standart görev: `____`; onay tarihi: `____`; onay alıntısı: "`____`".
