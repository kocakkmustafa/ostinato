# Ostinato — Karar kayıtları (ADR)

Biçim: ana talimat §14 "kritik sapma yetkisi". Her ADR beş maddeyi kaydeder: (1) hangi bilgi değişti, (2) hangi delil eski varsayımı çürüttü, (3) güvenlik/maliyet farkı, (4) geri dönüş, (5) hangi kullanıcı yararlanır.
Ölçüm tabanı: `origin/main` `dfd611465bc688a6a5bdafe43db09fcabd9b1e02`, `origin/release/1.0.2` `4f399e7f77a0b38cb59f2b419060f91b5f83374d`. Durum özeti: [`STATUS.md`](STATUS.md).

## ADR-001 — Kaynak gerçeği: gitar + kulak korunur ve geliştirilir
Tarih: 2026-11-08 · Durum: KABUL
Karar: Gitar ve kulak eğitimi korunur ve geliştirilir. Çello kamera koçu P2 araştırmadır. Şan W4 (`content/v1-w4-voice`) ayrı kurucu kararı gerektirir. Piyano içeriği main'de durur, uygulamada kapalı kalır. Gitar/kulak içeriği (`content/v1/gtr`, `content/v1/ear`) hiçbir belgeye bakarak silinmez.
1. Bilgi: Eski plan çelloyu önerir; kod ve mağaza gönderimi gitar + kulaktır (`ostinatoOpenInstruments={'guitar'}`, `ostinatoEarTrainingOpen=true`).
2. Delil: `content/v1/gtr` 240 ve `content/v1/ear` 50 dosya; çello için kamera dersi/kurs yok, yalnız `config/instruments.v1.json` planı ve bir ses fixture'ı. `instruments.v1.json`'daki 42 çalgı bir plandır, çalışan kapsam değil.
3. Güvenlik/maliyet: Fark yok; bayraklar (`ostinatoCameraLessonsOpen`, `ostinatoCameraPracticeAvailable`) kapalı kalır, yeni servis yok. Yasak alanlar (mağaza, fiyat, yayın) bu karardan etkilenmez.
4. Geri dönüş: Bu belge değiştirilerek; yeni kanıt (ör. çello kamera dersi koda girerse) yeni ADR ile bunu geçersiz kılar.
5. Kullanıcı: Gitar çalmayı öğrenen ve kulak eğitimi alan kullanıcı; mevcut ders ve ilerleme korunur.

## ADR-002 — "690 ders" iddiası yerine ölçülen dosya/ders sayıları
Tarih: 2026-11-08 · Durum: KABUL
Karar: Dosya ile ders ayrı yazılır (test dosyası = adında `-test` geçen). main: **450 dosya = 440 ders + 10 test** (gtr 240 = 235+5, pno 160 = 157+3, ear 50 = 48+2). Mağazada açık: **290 dosya = 283 ders + 7 test** (gitar+kulak). Şan W4 dalı (`content/v1-w4-voice`): 240 dosya = 236 ders + 4 test; yalnız EN+TR, 12 dilin çevirisi ve id tablosu eksik. "690 ders" iddiası aslında 450+240 = 690 DOSYA sayısıdır; ders olarak okunursa 676 (+14 test dosyası) ve yalnız şan dalı main'e girerse doğrudur.
1. Bilgi: 690 = 240 + 160 + 50 + 240 dosya; şan kalemi main'de yok.
2. Delil: `git ls-tree origin/main content/v1/<kurs>` dosya sayıları gtr 240, ear 50, pno 160, voc 0 (main ve release/1.0.2'de aynı); piyano `lib/app/screens/instrument_screen.dart` ile kapalı.
3. Güvenlik/maliyet: Olmayan içerik vaat edilmez; yanlış mağaza/site beyanı riski azalır. Maliyet farkı yok.
4. Geri dönüş: Şan dalı birleşip ölçüm yenilenirse bu ADR'nin sayıları güncellenir (yeni ADR).
5. Kullanıcı: Mağaza/site okuyucusu ve karar veren kurucu; dürüst kapsam.

## ADR-003 — README ve `docs/ostinato-plan.md` karar hiyerarşisinde eski kabul edilir
Tarih: 2026-11-08 · Durum: KABUL
Karar: `README.md` ("ilk motor: çello", "hazırlık aşaması") ve `docs/ostinato-plan.md` (Temmuz 2026, "çello önerilir") eski/yanlış kabul edilir; silinmez. Kodla çelişirse kod doğrudur. Hiyerarşi: imzalı build > aktif kaynak ve CI > config > `CLAUDE.md`/`AGENTS.md` > README > eski plan. README'ye eskime bandı eklemek AYRI iştir; bu PR README'ye dokunmaz.
1. Bilgi: Her iki belge kodun gerisinde.
2. Delil: Çello kamera kursu yok, kamera bayrakları kapalı, mağazada gitar + kulak var (ADR-001).
3. Güvenlik/maliyet: Eski belgeye bakarak yanlış kapsam kurma riski azalır; maliyet farkı yok.
4. Geri dönüş: Belgeler olduğu gibi durur; hiyerarşi bu ADR'yi geri alarak değişir.
5. Kullanıcı: Depoya giren ajan ve geliştirici; eski plan yüzünden doğrulanmış gitar işinin silinmesi önlenir.

## ADR-004 — Sürüm kaynağı ve düzeltme akışı
Tarih: 2026-11-08 · Durum: KABUL
Karar: main `pubspec.yaml` sürümü `1.0.1+10`'dur. Mağaza sürümü `1.0.2+11` yalnız `release/1.0.2`'dedir (`4f399e7`). 1.0.2 düzeltmeleri önce main'e girer, sonra release'e cherry-pick edilir. Kaynak: Ostinato oturum devri 2026-11-05 madde ⑥ (vault `20 Şirketler/Motion/🔄 Oturum Devri 2026-11-05 — Ostinato.md`); uygulama pratiği, kurucu emri değil. Kural uygulanmış: release-only c184e24 ve 7847c54, main'deki 710e6bb ve ce6aabb ile aynı başlıklı cherry-pick'lerdir. Sürüm numarasını değiştirmek açık talimat ister (`AGENTS.md`).
1. Bilgi: AUDIT-01 U4 ve bazı notlar main için "1.0.0+8" der; bu yanlıştır, gerçek `1.0.1+10`. Düzeltme burada kaydedildi.
2. Delil: `pubspec.yaml` `version: 1.0.1+10` (origin/main `dfd6114`); `git show origin/release/1.0.2:pubspec.yaml` `1.0.2+11`. main'de olup release'te olmayan 19, release'te olup main'de olmayan 4 commit.
3. Güvenlik/maliyet: Yanlış build/sürüm numarasıyla gönderim riski azalır; mağaza işleri ayrı kurucu onayında kalır.
4. Geri dönüş: Akış değişirse yeni ADR; release dalına bu PR ile dokunulmaz.
5. Kullanıcı: Mağazadaki 1.0.2 kullanıcısı; düzeltmeler main'de kaybolmaz.

## ADR-005 — Kayıt saklama: yalnız ephemeral; kalıcı/şifreli saklama ve export OST-P0-08B'ye ertelendi
Tarih: 2026-11-08 · Durum: KABUL (kapsam kararı Motion orchestration, OST-P0-08 engel yanıtı)
Karar: `RecordingRetentionPolicy` yalnız `ephemeral` | `denied` üretir. Kalıcı saklama isteği (onay ve yetişkin olsa da) her yolda `denied`. `RetentionAudience {adult, child, unknown}`: bayrak `ostinatoRecordingRetentionOpen` açıkken yalnız adult için mevcut ephemeral own_recording sürer; child/unknown'da kapalı. Uygulamada yaş sinyali yok; varsayılan `unknown`. Bayrak kapalıyken (varsayılan) FK2 davranışı birebir aynı. Açıkken ek olarak: uygulama arka plana gidince take ve RAM tamponu silinir (`RecorderBackgroundGuard`), "tümünü sil" (`OwnRecorder.deleteAll`) geçici klasörü boşaltır. Export yok.
Envanter (koddan): ses `OwnRecorder`'da RAM'de (en çok 180 sn, 16-bit PCM); tur özetlenince `getTemporaryDirectory()/own_recording/take-N.wav` olarak ŞİFRESİZ yazılır; sonraki tur, hata/iptal, ders ekranı kapanışı ve ders açılışındaki süpürme (çökme artığı) siler. Ağ API'si yok. Kalıcı dizin yalnız `ostinato.own_recording.v1.json` (açık/kapalı anahtarı, ses yok) için `getApplicationSupportDirectory`.
Şifreleme neden yapılmadı: doğrudan bağımlılıklarda (`pubspec.yaml`) şifreleme paketi yok; `pointycastle` ve `crypto` yalnız geçişli (doğrudan kullanmak yeni pub girdisi demek, `crypto` yalnız özet üretir) ve `lib/`te Keychain/Keystore anahtar deposu yok; anahtarı kayıtla aynı dizine koymak şifrelemeyi anlamsız kılar, elle şifre yazmak güvensiz. Bu yüzden OST-P0-08B ayrı bilet: bağımlılık/anahtar deposu kararı, şifreli cihaz-içi saklama, açık kullanıcı eylemiyle şifresiz export (child/unknown'da kapalı).
1. Bilgi: Kullanıcı metni yalnız "kayıt bu oturumda, cihazda kalır, oturum bitince silinir" der; saklama/export vaadi yok. 12 dilin çevirisi anadil kontrolünden geçmedi.
2. Delil: `test/ost_p0_08_recording_retention_test.dart` (15 test), `test/ost_p0_02_egress_test.dart` (yeni yol 0 istemci/0 soket + statik tarama).
3. Güvenlik/maliyet: Ham ses cihazdan çıkmaz, kalıcı dosya oluşmaz; yeni ücretli kaynak 0 USD.
4. Geri dönüş: Bayrak `false` kalır; OST-P0-08B yeni ADR ile bunu genişletir.
5. Kullanıcı: Yetişkin kullanıcı kendi turunu dinler; çocuk ve yaşı belirsiz kullanıcı kayıt almaz.
