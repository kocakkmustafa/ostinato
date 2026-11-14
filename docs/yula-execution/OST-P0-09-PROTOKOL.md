# OST-P0-09 — 20 başlangıç performansı, 5 cihaz ortamı: ölçüm protokolü

Tarih: 2026-11-08 · Taban: `origin/main` `22616a8f3e1172ee1e284874873dcf61065dd2e7` (`STATUS.md` ölçüm tabanı eskidir; bu belge main `22616a8` üzerinde yazıldı) · Durum: **BLOCKED_ACCESS** (yalnız belge) · Durum özeti: [`STATUS.md`](STATUS.md) · Karar kayıtları: [`DECISIONS.md`](DECISIONS.md)
Dayanak: Dört Ürün Ana Talimatı (2026-11-08) §7.2 (sinyal sözleşmesi), §7.4 `OST-P0-09`, §7.5 (doğrulama eşiği), G1/G2 kapıları, §12.3–12.4.
Kod durumu: **CS** = CONFIRMED_SOURCE (main'de kaynakta var) · **DO** = DOCUMENTED_ONLY (yalnız belgede/ana talimatta tanımlı, main'de doğrulanmadı) · **UK** = UNKNOWN. Bir yüzeyin `CS` olması "çalışıyor" demek değildir; yalnız "kaynakta var, ölçülebilir" demektir.

## 1. Kapsam ve durum

- Bu belge **protokoldür, ölçüm sonucu değildir.** Hiçbir hücrede ölçülmüş sayı, başarı oranı ya da gecikme değeri yoktur. Sonuç alanları `BLOCKED_ACCESS` ya da `NOT_TESTED` ile başlar.
- Bağımlı biletler (`OST-P0-03` … `OST-P0-08`) **merge sonrası dolacak**: ölçülecek yüzeylerin son hâli, ham ölçüm raporları ve kayıt politikasıyla ilgili ayrıntılar o zaman bu belgeye işlenir. Bu belge birleşmemiş hiçbir çalışmaya dayanmaz; yüzey sütunu yalnız `origin/main`'deki kaynağa bakar.
- Bu PR cihaz/insan kaydı başlatmaz, pilot başlatmaz, ham ses ya da kişisel veri içermez. Uzman kimliği, cihaz modeli ve ölçüm değeri **uydurulmaz**.
- Bu belge kamera bayraklarına (`ostinatoCameraLessonsOpen`, `ostinatoCameraPracticeAvailable`; `lib/app/ostinato_release_policy.dart`) dokunmaz; kamera P2'dir ve kapsam dışıdır.
- Kullanıcıya gösterilecek metin önerisi içermez; tek istisna, §3'te talimat §7.2'den alıntılanan beklenen davranış metnidir. Ürün kuralı değişmez: düşük güvende hüküm verilmez; kullanıcıya "yanlış/wrong" gösterilmez (aşağıda §4'teki `yanlış-pozitif` gibi etiketler yalnız iç kayıt sınıfıdır).

## 2. Test matrisi

### 2.1 Cihaz ortamları (E1…E5)

Hangi cihazların elde olduğu **bilinmiyor**. Kurucu ya da oturum cihaz bildirince bu tablo doldurulur; o zamana dek hiçbir satır uydurulmaz. Ortam başına kayıt, §7.2'deki gereksinimi (cihaz modeli, OS, sample rate, hoparlör/kulaklık, mikrofon mesafesi, arka plan sesi) karşılar.

| Ortam | Cihaz modeli | OS sürümü | Sample rate (44,1 / 48 kHz) | Çıkış (hoparlör / kulaklık) | Mikrofon mesafesi | Arka plan sesi (sessiz / oda / gürültülü) | Erişim durumu |
|---|---|---|---|---|---|---|---|
| E1 | _doldurulmadı_ | _doldurulmadı_ | _ölçülecek_ | _doldurulmadı_ | _doldurulmadı_ | _doldurulmadı_ | erişim: BİLİNMİYOR → `BLOCKED_ACCESS` |
| E2 | _doldurulmadı_ | _doldurulmadı_ | _ölçülecek_ | _doldurulmadı_ | _doldurulmadı_ | _doldurulmadı_ | erişim: BİLİNMİYOR → `BLOCKED_ACCESS` |
| E3 | _doldurulmadı_ | _doldurulmadı_ | _ölçülecek_ | _doldurulmadı_ | _doldurulmadı_ | _doldurulmadı_ | erişim: BİLİNMİYOR → `BLOCKED_ACCESS` |
| E4 | _doldurulmadı_ | _doldurulmadı_ | _ölçülecek_ | _doldurulmadı_ | _doldurulmadı_ | _doldurulmadı_ | erişim: BİLİNMİYOR → `BLOCKED_ACCESS` |
| E5 | _doldurulmadı_ | _doldurulmadı_ | _ölçülecek_ | _doldurulmadı_ | _doldurulmadı_ | _doldurulmadı_ | erişim: BİLİNMİYOR → `BLOCKED_ACCESS` |

Doldurma talimatı: cihaz bildirildiğinde ilgili satırın modeli, OS sürümü ve erişim durumu yazılır; sample rate cihazdan **okunur** (varsayılmaz); iOS ve Android'in ikisi de ortam listesinde yer almalıdır (Android için `android/app/src/main/kotlin/com/yulalab/ostinato/AudioCaptureStreamer.kt`, iOS için `ios/Runner/AudioCaptureStreamer.swift` yakalama yolları ayrıdır). Erişim `VAR` olana dek ortamın tüm hücreleri `BLOCKED_ACCESS` kalır.

### 2.2 Performanslar (P01…P20)

Yalnız main'de var olan ya da ana talimat §7.3'te tanımlı yüzeyler. `Kod` sütunu, o yüzeyin main'deki durumudur.

| ID | Performans | Giriş türü | Yüzey (main'deki yer) | Kod |
|---|---|---|---|---|
| P01 | Boş 6. tel (düşük E), tek nota | gitar, mikrofon | `lib/app/screens/guitar_note_observation_screen.dart`, `lib/app/audio/guitar_note_observation_controller.dart` | CS |
| P02 | Boş 5. tel (A), tek nota | gitar, mikrofon | aynı | CS |
| P03 | Boş 4. tel (D), tek nota | gitar, mikrofon | aynı | CS |
| P04 | Boş 3. tel (G), tek nota | gitar, mikrofon | aynı | CS |
| P05 | Boş 2. tel (B), tek nota | gitar, mikrofon | aynı | CS |
| P06 | Boş 1. tel (ince e), tek nota | gitar, mikrofon | aynı | CS |
| P07 | Perdeli tek nota (örn. 3. perde); çoklu ses sınıfı için akor varyantı (P0 dışı, `duyamadım` beklenir) | gitar, mikrofon | aynı; akor varyantı: `packages/ostinato_audio/lib/src/harmony/chord_detector.dart` | CS (tek nota) / CS kütüphane, ürün yüzeyi UK (akor) |
| P08 | Sürekli (sustain) nota, akort durumu okuması | gitar, mikrofon | `NoteTuning` (`lib/app/audio/guitar_note_observation_controller.dart`) | CS |
| P09 | Akort aracıyla tel akordu | gitar, mikrofon | `lib/app/tuner/tuner_screen.dart`, `lib/app/tuner/tuner_controller.dart` | CS |
| P10 | Aynı notanın hızlı tekrarı (onset ayrımı) | gitar, mikrofon | `packages/ostinato_audio/lib/src/onset/onset_detector.dart` | CS |
| P11 | Metronomla düşük tempoda gitar ritmi | gitar + metronom, mikrofon | `lib/app/practice/loop/practice_session_controller.dart`, `lib/app/practice/loop/metronome.dart`, `lib/app/practice/loop/practice_judge.dart` | CS |
| P12 | Metronomla orta tempoda gitar ritmi | gitar + metronom, mikrofon | aynı | CS |
| P13 | Tempo merdiveni (tempo kademeli artar) | gitar + metronom, mikrofon | `lib/app/practice/loop/practice_tempo_ladder.dart` | CS |
| P14 | Gecikme kalibrasyonu (kurulum) | metronom/ipucu + mikrofon | `lib/app/practice/setup/latency_calibration.dart`, `lib/app/practice/setup/setup_wizard_screen.dart` | CS |
| P15 | Mikrofon izni reddi; mikrofonsuz içerik sürer mi | izin akışı | `lib/app/audio/mic_permission_gate.dart` (`permissionDenied`, `permissionDeniedPermanent` aşamaları) | CS |
| P16 | Kulak eğitimi alıştırmaları (ekranda, mikrofonsuz; alkış dersleri mikrofonludur, bkz. P19) | dokunma/seçim | `content/v1/ear`, `lib/app/screens/library_screen.dart` | CS |
| P17 | Referansı dinle, sonra dene | ses çıkışı + mikrofon | `lib/app/practice/loop/reference_listen.dart`, `lib/app/practice/loop/reference_listen_bar.dart` | CS |
| P18 | Kendi kaydımı dinle (opt-in, geçici) | mikrofon, çalma | `lib/app/practice/own_recording/own_recording.dart` | CS |
| P19 | Alkış dersleri (mikrofonlu; alkış onset olarak dinlenir) | alkış, mikrofon | `lib/app/practice/loop/v1_practice_catalog.dart` (`clapSequence`, `_isClapLine`), `lib/app/practice/loop/v1_course_copy.dart` | CS |
| P20 | Enstrümansız `Ritme dokun` (mikrofonsuz dokunma, §7.3) | dokunma | main'de doğrulanmadı | DO |

Notlar:
- P01–P08 aynı gözlem yüzeyini farklı tel/nota koşuluyla çalıştırır; gerçek fark kaynağı tel ve perde olduğundan ayrı satırdır.
- P20 (`Ritme dokun`), main'de bir yüzeye bağlanana dek `BLOCKED_ACCESS` kalır; yüzey main'e girince `CS` olarak güncellenir.
- P07'nin akor varyantı "doğru sınıfı bulur" için değil, "bulamadığında dürüstçe `duyamadım` der" için ölçülür; çoklu ses P0'da başarı kriteri değildir (§7.2). Matris 20 satırda kalır; akor ayrı satır değil P07 varyantıdır.

### 2.3 Sonuç ızgarası (P × E)

**`BA` = `BLOCKED_ACCESS`** (cihaz erişimi bilinmiyor). Ortam erişimi doğrulanıp koşu yapılana dek her hücre `BA` kalır; koşulmuş ama sonuçlanmamış hücre `NOT_TESTED` yazılır.

| ID | E1 | E2 | E3 | E4 | E5 |
|---|---|---|---|---|---|
| P01 | BA | BA | BA | BA | BA |
| P02 | BA | BA | BA | BA | BA |
| P03 | BA | BA | BA | BA | BA |
| P04 | BA | BA | BA | BA | BA |
| P05 | BA | BA | BA | BA | BA |
| P06 | BA | BA | BA | BA | BA |
| P07 | BA | BA | BA | BA | BA |
| P08 | BA | BA | BA | BA | BA |
| P09 | BA | BA | BA | BA | BA |
| P10 | BA | BA | BA | BA | BA |
| P11 | BA | BA | BA | BA | BA |
| P12 | BA | BA | BA | BA | BA |
| P13 | BA | BA | BA | BA | BA |
| P14 | BA | BA | BA | BA | BA |
| P15 | BA | BA | BA | BA | BA |
| P16 | BA | BA | BA | BA | BA |
| P17 | BA | BA | BA | BA | BA |
| P18 | BA | BA | BA | BA | BA |
| P19 | BA | BA | BA | BA | BA |
| P20 | BA | BA | BA | BA | BA |

Toplam: 20 performans × 5 ortam = **100 hücre; 100'ü `BLOCKED_ACCESS`; 0 koşuldu.**

### 2.4 Hücre kayıt alanları

Her koşulan hücre için (hücreler ayrı kayıt satırıdır; ham ses repoya girmez, bkz. §4):

```yaml
cell: P01xE1            # performans x ortam
kosuldu_mu: false       # true | false
sonuc: BLOCKED_ACCESS   # BLOCKED_ACCESS | NOT_TESTED | KOSULDU
sonuc_ozeti: ""         # serbest ama sayı yalnız ölçülmüşse; kaynak/yöntem ile
senaryo_sinifi: []      # §3 sınıflarından hangileri uygulandı
tarih: ""               # YYYY-MM-DD, koşu günü
kayit_yolu: ""          # §4 kayıt dosyası ya da özet yolu; ham ses yolu YASAK
not: ""
```

Ortam başına ek alanlar: OS sürümü, uygulama sürümü/build ve commit SHA, çıkış yolu (hoparlör/kulaklık), mikrofon mesafesi, oda gürültü seviyesinin etiketi (sessiz/oda/gürültülü).

## 3. Senaryo sınıfları ve beklenen ürün davranışı

Her sınıf, uygun performanslara (§2.2) uygulanır. Ortak kural (§7.2): güven düşükse **kırmızı hata değil** "Bu sesi güvenle ayırt edemedim; tekrar dener misin?" yönünde yumuşak, tekrar isteyen bir durum beklenir; ürün çalınan notaya yanlış/wrong hükmü göstermez.

| Sınıf | Ne yapılır | Beklenen ürün davranışı |
|---|---|---|
| Gürültü | Oda ya da gürültülü arka planda (konuşma, fan, trafik) çalınır | Gürültü tabanı yükselince ya sinyal ayırt edilir ya da `duyamadım`/tekrar dene yolu. Gürültüden uydurma nota ya da ritim hükmü çıkmaz. Yanlış-pozitif (yok olan notayı bulma) kayda geçer. |
| Tek ses (monofonik) | Temiz, tek nota, tek tel | P0'ın desteklenen durumu: tek nota ve (varsa) akort durumu okunur. Kötü sinyalde tahmin yerine `duyamadım` tercih edilir. |
| Sessizlik | Mikrofon açık, hiçbir şey çalınmaz | Nota/ritim hükmü çıkmaz; "ses bulunamadı" türü yumuşak durum (ör. `noResult`) ve tekrar daveti. Sessizlikten hüküm = yanlış-pozitif. |
| Mikrofon reddi | İzin reddedilir (bir kez ve kalıcı) | Mikrofonsuz içerik (ritim dokunuşu hedefi, kulak eğitimi, okuma) çalışmaya devam eder; ses gerektiren adım dürüstçe anlatılır, ayarlara yönlendirilir; çökme/boş ekran yok; ham ses hiçbir yere gitmez. |
| Çoklu ses (P0 dışı) | Akor, iki tel ya da üst üste ses | Başarı iddiası yok. Beklenen: `duyamadım`. Tek notaymış gibi hüküm vermek yanlış-pozitiftir ve kayda geçer. |
| Echo / hoparlör geri beslemesi | Metronom/referans hoparlörden çalarken mikrofon kayıtta; sonra kulaklıkla tekrar | Hoparlör sesinin kullanıcı performansı sanılması (metronomun "vuruş" sayılması) beklenmez; sapma kalibrasyonla (`lib/app/practice/setup/latency_calibration.dart`) ele alınır; geri besleme belirsizse `duyamadım`. Hoparlör/kulaklık farkı ayrı kayıt. |

## 4. Yanlış-pozitif kayıt biçimi

Kayıtlar yalnız **özet ve etiket** taşır. **Ham ses (WAV/PCM/m4a vb.) repoya KONMAZ**; kayıt dosyasında yalnız ürün çıktısı, beklenen çıktı, etiketler ve yol/kimlik bulunur. Saklama kuralı: cihaz dışına çıkan her kayıt **kullanıcı izni olmadan yoktur**; izin yoksa ses cihazda kalır, oturum bitince geçici buffer temizlenir (ana talimat §7.5). Kişisel veri (isim, hesap, konum) kayda girmez; kaynak etiketi anonim kısa kimliktir.

### 4.1 Şema (CSV başlığı ve alan sözlüğü)

```csv
id,performans,ortam,giris_turu,urun_ciktisi,beklenen_cikti,hukum_sinifi,guven,pedagojik_etki,kanit_yolu,tarih
```

| Alan | Değerler |
|---|---|
| `id` | `FP-<YYYYMMDD>-<sıra>` |
| `performans` | `P01`…`P20` |
| `ortam` | `E1`…`E5` |
| `giris_turu` | `tek-nota`, `bos-tel`, `ritim+mikrofon`, `dokunma`, `alkis`, `sessizlik`, `gurultu`, `akor`, `izin-reddi`, `echo` |
| `urun_ciktisi` | ürünün gösterdiği/verdiği durum (ör. "nota bulundu: ?", `duyamadım`, "hüküm yok") |
| `beklenen_cikti` | referansa göre doğru çıktı |
| `hukum_sinifi` | `doğru` · `yanlış-pozitif` · `yanlış-negatif` · `duyamadım-uygun` · `duyamadım-gereksiz` |
| `guven` | ürünün bildirdiği güven (0–1) ya da `bilinmiyor`; ürün göstermiyorsa `gösterilmiyor` |
| `pedagojik_etki` | `yok` · `kafa karıştırıcı` · `yanlış yönlendirici` |
| `kanit_yolu` | özet/etiket dosyası ya da ekran görüntüsü yolu (ses dosyası değil) |
| `tarih` | `YYYY-MM-DD` |

Sınıf tanımları: `yanlış-pozitif` = olmayan şeyi bulma ya da yanlış hükmü doğru gibi verme; `yanlış-negatif` = olan ve duyulabilir şeyi bulamama; `duyamadım-uygun` = sinyal gerçekten kötü/yoksa ürün çekimser kaldı; `duyamadım-gereksiz` = sinyal yeterliyken ürün çekimser kaldı. Pedagojik etki, kullanıcının sonraki davranışını bozma düzeyidir; `yanlış yönlendirici` olan her kayıt açık iş olarak kaldırılır.

### 4.2 Örnek satırlar

**ŞEMA ÖRNEĞİ — gerçek ölçüm değil.** Aşağıdaki iki satır alanların nasıl doldurulacağını gösterir; cihaz, değer ve tarih uydurmadır.

```csv
id,performans,ortam,giris_turu,urun_ciktisi,beklenen_cikti,hukum_sinifi,guven,pedagojik_etki,kanit_yolu,tarih
FP-ORNEK-001,P07,E1,akor,"tek nota bulundu: ?","duyamadım",yanlış-pozitif,0.41,yanlış yönlendirici,"(örnek; dosya yok)",0000-00-00
FP-ORNEK-002,P01,E2,gurultu,"duyamadım","duyamadım",duyamadım-uygun,gösterilmiyor,yok,"(örnek; dosya yok)",0000-00-00
```

## 5. Uzman denetim şablonu

Amaç: enstrümana özgü teknik geri bildirimlerin bağımsız bir uzmanca değerlendirilmesi. **Uzman kimliği doldurulmaz** (bu belgede kişi/ad/kurum yoktur); uzman bulunup rıza verince bir kopya doldurulur. Uzman doğrulaması yokken ürün sinyalleri "ölçüm sonucu" değil "pilot gözlem" olarak anılır.

### 5.1 Kör değerlendirme formu

Değerlendirici, ürünün çıktısını görmeden **kaydı/performansı** puanlar; ürün çıktısı sonra açılır ve ikisi karşılaştırılır.

```yaml
degerlendirme_id: ""          # UZ-<YYYYMMDD>-<sıra>
uzman_kodu: ""                # anonim kod; kimlik bu dosyada yok
enstruman_alani: ""           # gitar | ritim
performans_ref: ""            # P01…P20 ve kayıt kimliği
kor: true                     # ürün çıktısı puanlamadan önce gösterilmedi
puanlar:                      # 1 (çok zayıf) … 5 (çok iyi); 0 = değerlendirilemez
  ritim_dogrulugu: 0
  perde_temizligi: 0
  sureklilik: 0
  geri_bildirimin_pedagojik_uygunlugu: 0   # ürün çıktısı açıldıktan sonra
serbest_not: ""
karsilastirma:                # ürün çıktısı açıldıktan sonra
  urun_ile_uyum: ""           # uyumlu | kısmen | uyumsuz
  uyumsuzluk_nedeni: ""
tarih: ""
```

Rubrik (1–5): **ritim doğruluğu** = vuruşların hedef ritme göre oturması; **perde temizliği** = notanın temiz ve entonasyonlu çıkması (telin çınlaması, perde gıcırtısı dahil); **süreklilik** = notanın/ritmin kesintisiz ve dengeli sürmesi; **geri bildirimin pedagojik uygunluğu** = ürünün söylediğinin (ya da suskun kaldığının) öğrenciye faydası. Ölçekte ara değer yok; 0 yalnız "değerlendirilemez".

### 5.2 Bağımsızlık ve çıkar çatışması beyanı (taslak)

> Bu değerlendirmeyi Yula Lab'dan ücret ya da başka bir çıkar beklemeden, Ostinato'nun geliştirilmesine bağımsız olarak yaptığımı beyan ederim. Yula Lab ile ticari, ailevi ya da başka bir bağım var ise aşağıda belirtirim: ______. Değerlendirmeyi ürünün çıktısını görmeden (kör) yaptım. Puanlarımın ürün pazarlamasında kişisel olarak benimle ilişkilendirilmeden kullanılmasına: ☐ izin veriyorum ☐ vermiyorum.

Beyan eksik/imzasızsa değerlendirme kanıt sayılmaz.

### 5.3 Rıza metni (taslak, ses paylaşımı yalnız rıza ile)

> Yula Lab, Ostinato'nun ses analizini değerlendirmek için bir ses kaydı paylaşmamı rica ediyor. Kaydın yalnız bu değerlendirme için kullanılacağını, kimliğimle ilişkilendirilmeden saklanacağını ve istediğim zaman silinmesini isteyebileceğimi anladım. Kaydı vermek zorunda değilim; vermezsem hiçbir şey kaybetmem. Kaydın Yula Lab dışına çıkmasına ☐ izin veriyorum ☐ vermiyorum. İmza/tarih: ______.

Kurallar: rıza yoksa ses hiçbir yere aktarılmaz; yalnız rıza veren katılımcı kaydı değerlendirilir; reşit olmayanlar için bu şablon kullanılmaz (ayrı veli rızası ve hukuki inceleme gerekir); rıza geri çekilince kayıt ve türev etiketler silinir.

### 5.4 Pazarlama kuralı

**Uzman doğrulaması yoksa "AI teknik yanlış tespit ediyor" pazarlaması yapılmaz.** Doğrulama yalnız §5.1 ve §5.2 eksiksiz doldurulmuş en az bir bağımsız uzman değerlendirmesiyle mevcut sayılır; o zaman bile iddia, değerlendirilen performans/ortam kapsamıyla sınırlı yazılır. Ana talimat §7.3 ve §7.5 aynı kuralı taşır.

## 6. G1/G2 kanıt satırı ve DONE koşulları

### 6.1 Backlog/STATUS satır biçimi

Bu PR'dan sonra tek satır (STATUS.md'ye eklendi):

```text
- [bilet:: OST-P0-09] [durum:: BLOCKED_ACCESS] Protokol belgesi (yalnız belge) — ölçüm 03…08 merge sonrası; durum BLOCKED_ACCESS · [PR:: #72] [CI:: yok/koşulmadı] [ölçüm-raporu:: yok (03…08 merge sonrası)] [cihaz-ortam:: 0/5] [BLOCKED_ACCESS:: 100/100] · [`OST-P0-09-PROTOKOL.md`](OST-P0-09-PROTOKOL.md)
```

Ölçüm başladığında aynı satır güncellenir: `[durum::` `TESTING` ya da hâlâ `BLOCKED_ACCESS`), `[ölçüm-raporu:: <yol>]`, `[cihaz-ortam:: <erişimli>/5]`, `[BLOCKED_ACCESS:: <kalan>/100]`. Sayılar yalnız §2.3 ızgarasından türetilir.

### 6.2 §12.3 DONE şartları: belge mi, ölçüm mü

| Şart (§12.3) | Bu belge ile | Ölçüm gerekir |
|---|---|---|
| Dört şey net (kazanç, kod değişikliği, test, sınırlar) | Kısmen: kazanç ve sınırlar (§1) yazıldı; kodda değişiklik yok; test koşmadı | Test/sonuç kısmı |
| PR/commit/kaynak gösterildi; başka ajan inceledi | PR ve SHA yazılır; inceleme `REVIEW_PENDING` | İnceleme |
| Test/CI + tarih + sonuç + ortam | Karşılanmaz (belge, test yok) | Evet → şimdilik `NOT_TESTED` |
| Geri alma yolu, flag/migration | Karşılanır: PR revert; flag/migration yok | — |
| Yeni maliyet, veri akışı, izinler | Karşılanır: 0 USD, yeni veri akışı yok; ses cihazda kalır; ölçümde rıza kuralları §4–§5 | — |
| UI değiştiyse mobil/desktop/locale/boş-hata-yükleme/dark-light/klavye | Uygulanmaz (UI değişmedi) | — |
| Dış etkiyi onay olmadan yapmama | Karşılanır: cihaz/insan kaydı ve pilot başlatılmadı | Ölçüm için kurucu onayı ve rıza gerekir |

Hüküm: bu bilet bu PR ile **`DONE` DEĞİLDİR.** Mevcut durum `BLOCKED_ACCESS` (cihaz erişimi bilinmiyor); ölçülmüş bir şey olmadığından `TEST_ONLY` bile iddia edilmez. Ölçüm başlayıp yalnız sentetik/mock veriyle sonuç alınırsa en çok `TEST_ONLY` yazılır (§12.4: mock geçişi `TEST_ONLY`'den yukarı çıkarmaz).

### 6.3 Ostinato G1/G2 kanıt kapıları

**G1 — "anlaşılır niyet → sonuç"** (Ostinato için): kullanıcı bir performansta niyeti (ör. "bu boş teli çalacağım") ve ürünün sonucunu (nota/ritim gözlemi ya da dürüst `duyamadım`) açıkça görür; yetki/masraf sürprizi yok. Kanıt: (1) en az bir performans için kaydedilmiş manuel test (§2.4 hücre kaydı + ekran görüntüsü yolu); (2) izin reddi yolu (P15) kaydı; (3) ham ses cihaz dışına çıkmadı beyanı. Şimdiki durum: **kanıt yok → `BLOCKED_ACCESS`.**

**G2 — "oyna → ölç → tek düzeltme → tekrar"**: (1) bir performans için tek tur: oyna, ölç, tek düzeltme önerisi, tekrar (P11/P12 tipi); (2) **hata güven seviyesi**: düşük güvende kırmızı hata yerine tekrar daveti (§3 davranışları, §4 kayıtları); (3) **ekran ipucu kaybolma** deneyimi: bu `OST-P0-07`'nin konusudur ve main'de doğrulanmadı (DO); ölçümü o iş merge olunca eklenir; (4) **en az bir akustik referans seti**: ölçüm ortamı, donanım ve referans yöntemi ile adlandırılmış, ham ses içermeyen özet (§4) ve §5 uzman değerlendirmesi. Şimdiki durum: **hiçbiri ölçülmedi → `BLOCKED_ACCESS`/`NOT_TESTED`.**

## 7. §7.5 sayıları: yalnız pilot test hedefi

Aşağıdaki sayılar **pilot test hedefidir, başarı iddiası değildir.** Bu belgede ölçülmüş hiçbir değer yoktur.

- Temiz monofonik referansta beklenen notanın tanınma oranı için ön hedef `>= %90`. Sonuç raporlanırken ses/enstrüman/tolerans ayrımı önceden yazılır; kötü sinyalde tahmin yerine `duyamadım` tercih edilir.
- Basit metronom ritminde onset referans hatası **kaynağa göre raporlanır**. Kalibre edilmemiş mutlak bir gecikme garantisi **verilmez**; bu belge hiçbir ms değerini zincir garantisi olarak yazmaz. Pencere geometrisi nedeniyle öngörülebilir sapma beklenir (bkz. `docs/gates/O-025-TIMING-CALIBRATION-PROTOCOL.md`); giriş/çıkış yolu, buffer ve DSP penceresi ayrı ölçülür.
- Kullanıcı izin vermediğinde ham ses/video hiçbir sunucuya gitmez; oturum bitince geçici buffer temizlenir. Bu bir tasarım kuralıdır; ağ tarafı testi ayrıca yapılmadıkça (`STATUS.md`: ağ testi NI) kanıtlanmış sayılmaz.
- "Gerçek öğrenme" ölçümü bu protokolün kapsamı değildir (`OST-P1-05`); skor oyunu testi bunun yerine geçmez.
- Her yeni enstrüman için enstrüman özel uzman kabul seti ve desteklenen cihaz/ses sınıfları ayrıca gerekir.
