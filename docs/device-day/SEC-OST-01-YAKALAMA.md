# SEC-OST-01 — ağ yakalama tarifi ve "ham ses isteği 0" ölçütü

Durum: **TARİF + RAPOR ŞABLONU; yakalama yapılmadı.** Kabul (Backlog): proxy/ağ yakalamalı 1 oturum, **ham ses içeren istek 0**, rapor `docs/` altında. Gün akışındaki yeri: cihaz 1, ≈20 dk ([`README.md`](README.md)). Cihaz tablosu: [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md).

Araç: **mitmproxy** (ücretsiz, açık kaynak). Bu belge aracı kurmaz; Mac'e kurulum gün sabahı çalıştırılacak adımdır. Ücretli araç kullanılmaz.

## 1. Mac'e kurulum (gün sabahı, kurucu ya da Ostinato)

```
brew install mitmproxy
mitmdump --version
```

`brew info mitmproxy` 12.3.1'i gösteriyordu (2026-11-18, kurulu değil). Kurulum başarısızsa ENGEL olarak bildir; ücretli alternatife geçilmez.

## 2. Yakalama yöntemi ve başlatma (Mac)

**Önemli sınır (koddan):** Flutter'ın `dart:io` HTTP istemcisi **sistem proxy ayarını kullanmaz**. Depoda `lib/`, `android/app/src`, `ios/Runner`, `packages/` içinde `findProxy` / `HttpOverrides` yoktur; ağ paketleri `http` (1.6.0) ve `supabase_flutter` (2.17.2)'dir (`pubspec.yaml`). Bu yüzden telefonda Wi-Fi proxy'si açık olsa bile uygulamanın **kendi** trafiği mitmproxy'ye uğramayabilir; "Safari'de sayfa göründü" uygulamanın yakalandığını **göstermez**. Yöntem seçimi buna göre yapılır:

1. **Birincil: WireGuard modu.** `mitmdump --mode wireguard` mitmproxy 9'dan beri vardır (kurulu sürüm 12.3.1, `brew info mitmproxy`); telefona WireGuard profili (QR/yapılandırma) verilir ve **tüm trafik** tünelden geçer, uygulama proxy ayarını okusa da okumasa da yakalanır. Çıktıdaki yapılandırmanın biçimi ve 12.3.1'de bayrak adı **doğrulanacak** (resmi belge: mitmproxy "Modes" sayfası, WireGuard bölümü; gün sabahı `mitmdump --help` ile de bakılır). Telefonda resmi WireGuard uygulaması gerekir (ücretsiz; kurulum cihaz sahibi kurucudadır, bu belge kurmaz).
2. **İkincil: elle proxy modu** (aşağıda §3). Yalnız WireGuard çalışmazsa denenir; sonuç §5 "kendi trafiği kanıtı" şartına tabidir.

Telefon ve Mac **aynı Wi-Fi**'de olmalı (WireGuard modunda Mac'in UDP portu erişilebilir olmalı). Mac'in yerel IP'sini bul (`ipconfig getifaddr en0`; Wi-Fi arayüzü farklıysa `en1`).

```
mkdir -p scratch/<tarih>-devday/capture
# birincil
mitmdump --mode wireguard \
  -w scratch/<tarih>-devday/capture/cihaz1.flows \
  --set hardump=scratch/<tarih>-devday/capture/cihaz1.har
# ikincil (elle proxy)
mitmdump --listen-port 8080 \
  -w scratch/<tarih>-devday/capture/cihaz1.flows \
  --set hardump=scratch/<tarih>-devday/capture/cihaz1.har
```

- `-w` ham akış dosyasını yazar; `hardump` aynı oturumu HAR olarak dışa aktarır (çıkışta, Ctrl+C ile durdurunca yazılır). `hardump` seçeneğinin sürüm 12.3.1'de bu biçimde çalıştığı **doğrulanacak**; çalışmazsa `mitmweb` arayüzünden File → Save → HAR dışa aktarımı ya da `.flows` dosyasından `mitmdump -nr cihaz1.flows --set hardump=cihaz1.har` denenir.
- **HAR'da multipart:** mitmproxy'nin HAR'ı `postData.params.fileName` alanını her zaman doldurmaz; betik bu yüzden ham `postData.text` içinde de `filename="....wav"` ve ses başlığı kalıplarını arar. Ham gövde HAR'a hiç yazılmadıysa (büyük/ikili gövde) betik göremez: HAR'da gövde boyutunu (`bodySize`) ve alan adlarını da gözden geçir.
- Yakalama dosyaları `scratch/` altındadır, repoya girmez. HAR ham istek gövdesi içerebilir: dışarıya (sohbet, bilet) eklenmez, yalnız özet rapor paylaşılır.
- macOS güvenlik duvarı gelen bağlantıyı soruyorsa izin ver (kurucu).

## 3. Telefon ayarı

**iPhone (cihaz 1, birincil).** Birincil yöntemde (WireGuard) önce tünel kurulur (adım 0); proxy adımı (1) yalnız ikincil yöntemde uygulanır. Sertifika adımları (2-4) iki yöntemde de gerekir (HTTPS içeriği için).

0. WireGuard uygulamasında mitmproxy'nin verdiği yapılandırmayı (QR) içe aktar ve tüneli aç (ayrıntı **doğrulanacak**, §2).

1. (yalnız ikincil yöntem) Ayarlar → Wi-Fi → bağlı ağın (i) simgesi → **Proxy'yi Yapılandır → Elle**: Sunucu = Mac IP'si, Port = 8080, kimlik doğrulama kapalı.
2. Safari'de `http://mitm.it` aç → iOS için sertifikayı indir ("Profil indirildi").
3. Ayarlar → Genel → **VPN ve Aygıt Yönetimi** → indirilen profili **Yükle**.
4. Ayarlar → Genel → **Hakkında → Sertifika Güven Ayarları** → mitmproxy sertifikası için **tam güveni aç**. Bu adım atlanırsa HTTPS içeriği çözülmez.
5. Kontrol: Safari'de bir https sayfası aç; mitmdump çıktısında satır akmalı. Bu kontrol **yalnız tarayıcıyı** kanıtlar; uygulamanın kendi trafiği için §5'teki kanıt şartı geçerlidir.
6. Gün sonunda ters sırayla temizle: WireGuard tünelini kapat ve profili sil, proxy'yi Kapat, profili kaldır (Ayarlar → Genel → VPN ve Aygıt Yönetimi), güven anahtarı kendiliğinden kalkar.

Sertifika kurmak ve güven vermek cihaz ayarıdır; **kurucu yapar** (karar ve parola ona aittir).

**Android (cihaz 2, isteğe bağlı) ve sınır, açıkça:**

- WireGuard uygulaması ile tünel (birincil) ya da Wi-Fi ağı → Gelişmiş → Proxy → Elle (Mac IP, 8080; ikincil). Sertifika: tarayıcıdan `http://mitm.it` → Android → indir → Ayarlar → Güvenlik → Şifreleme ve kimlik bilgileri → **CA sertifikası yükle**.
- **Sınır:** Android 7 (API 24) ve sonrasında uygulamalar, kendi ağ güvenlik yapılandırmasında izin vermedikçe **kullanıcı sertifikalarına güvenmez**; bu uygulamanın hedef SDK'sı 37'dir (`android/app/build.gradle.kts:73`). Koddan okunan durum: `android/` altında `networkSecurityConfig` / `network_security_config` yoktur ve manifestte `usesCleartextTraffic` tanımlı değildir, yani **varsayılan güven politikası geçerlidir ve kullanıcı CA'sı yok sayılır**. Sonuç: mitmproxy Android'de Ostinato'nun HTTPS **içeriğini çözemez**. Bağlantı düzeyinde ne kaydedileceği (alan adı, TLS hata girdisi, bayt sayısı) yöntem ve mitmproxy ayarına bağlıdır ve **doğrulanacak**; bu bilgiye güvenilmez. İçerik çözülmeden "ham ses 0" **denemez** (sonuç KANITSIZ).
- Sertifika sabitleme (pinning): `lib/`, `packages/`, `ios/Runner`, `android/app/src` içinde sabitleme koduna rastlanmadı (grep: `badCertificateCallback`, `setTrustedCertificates`, `SecurityContext`, `CertificatePinner`, `SecTrust`; sonuç boş). Üçüncü taraf paketlerin kendi sabitlemesi **doğrulanmadı**.
- Android'de içerik görmek için uygulamaya kullanıcı CA'sını tanıtan bir ağ güvenlik yapılandırması gerekir. Bu **kod değişikliğidir** ve bu belgenin kapsamında değildir; gerekirse ayrı bilet ve kurucu/Motion onayı. Bu durumda Android için kabul: yalnız alan adı listesi + (varsa) şifreli bağlantı sayısı raporlanır, ham ses iddiası **yalnız iPhone yakalamasına** dayandırılır.

## 4. Oturum senaryosu (cihaz 1, ≈10 dk pratik + kendi kaydını dinleme)

1. Yakalamayı başlat; uygulamayı **temiz kurulumdan** aç (karşılamadan itibaren ağa ne gittiği de kaydedilir).
2. [`TUR-LISTESI.md`](TUR-LISTESI.md) adım 3-6'yı oyna; en az 10 dakika pratik. Ayarlar'da "kendi kaydım" anahtarını **aç** ve sonuç ekranında **Dinle**'ye en az bir kez dokun (kayıt yolunun ağa çıkmadığını ölçmek için).
3. Akortu da bir kez çalıştır (`tuner/tuner_screen.dart`).
4. **Zorunlu (kendi trafiği kanıtı):** Ayarlar → Hesap sayfasını aç ve birkaç saniye bekle; backend alan adına en az bir istek görülmelidir (§5). Oturum açma yapılmaz.
5. Yakalamayı Ctrl+C ile durdur; telefon proxy'sini kapat.

## 5. Ölçüt ve analiz

**Ölçüt:** Uygulamadan çıkan isteklerde **ham ses içeren istek = 0**. Şüpheli bulunursa sayı 0 değildir; kabul sağlanmaz, bulgu açılır.

**Uygulamanın kendi trafiği kanıtı (şart):** yakalamada uygulamanın **kendi backend alan adlarına en az bir istek** görülmelidir. Görülmezse uygulamanın trafiği yakalanmamış olabilir (§2 sınırı) ve sonuç **KANITSIZ**'dır; "ham ses 0" denmez. Kanıtı üretmek için senaryoda Ayarlar → Hesap sayfasını aç (hesap/üyelik sorguları backend'e gider; hangi alan adı: derleme tanımındaki Supabase adresi, `MOTION_SUPABASE_URL`, **doğrulanacak**; değer okunmadı). Backend alan adı bilinmiyorsa alan adı listesinden gözle belirlenir.

```
python3 tools/har_audio_check.py scratch/<tarih>-devday/capture/cihaz1.har \
  --expect-domain <backend-alan-adi> [--expect-domain <ikinci-alan-adi>]
```

Çıkış kodu: `0` şüpheli yok ve kanıt yeterli · `1` şüpheli var (neden listelenir) · `2` girdi hatası (bozuk/beklenmeyen JSON, dosya yok, >200 MB) · `3` KANITSIZ (HAR boş ya da beklenen alan adlarının hiçbiri yok) · `4` yalnız `--selftest` başarısız. Betik kendini de sınar: `python3 tools/har_audio_check.py --selftest` (main()'i uçtan uca 0/1/2/3 ile sınar).

Şüphe kalıpları (yalnız **istek** gövdesi/başlığı): `Content-Type: audio/*`; `application/octet-stream` ve gövde ≥ 8 KB (önerilen eşik); URL ya da multipart dosya adında `.wav .m4a .aac .mp3 .caf .aiff .aif .flac`; multipart parçasının ses türü; gövdede base64 başlık `UklGR` (RIFF), `Y2FmZg` (caff, küçük harf `caff`), `ZkxhQw` (fLaC), `T2dnUw` (OggS), `SUQz` (ID3), ftyp; ham başlıklar RIFF....WAVE, caff, fLaC, OggS, ftyp, ID3; multipart gövde metninde `filename="....wav"` ve `Content-Type: audio/`; tek istek gövdesi > 64 KB (**önerilen** eşik; 8 KB octet-stream eşiği de öyle).

Sınırlar: betik kural eşleyicidir; şifrelenmemiş ya da çözülmüş içerik varsayar. HTTPS çözülemediyse (Android, güveni açılmamış iOS) ya da uygulamanın kendi trafiği yakalamada görülmediyse "0 şüpheli" ses yok demek **değildir** (betik yalnız boş HAR ve `--expect-domain` için çıkış 3 verir; çözülemeyen TLS'i kendisi bilemez); raporda "çözülemeyen bağlantı" sayısını ayrıca yaz. Sıkıştırılmış ya da özel kodlanmış (ör. gzip içinde, özel ikili) ses bu kalıplarla yakalanmayabilir; bu nedenle toplam istek sayısı ve alan adı listesi de rapora girer ve bir insan gözden geçirir.

## 6. Rapor şablonu

Dosya: `docs/device-day/reports/SEC-OST-01-<tarih>.md` (gün sonu Ostinato yazar; bu şablon doldurulmadan kabul sayılmaz).

```
# SEC-OST-01 raporu — <tarih>
- Cihaz (model, OS):
- Derleme SHA ve bayrak durumu:
- Yakalama aracı ve sürümü (mitmdump --version):
- Yakalama başlangıç / bitiş, süre (dk):
- Yöntem: WireGuard / elle proxy; sertifika güveni açık mıydı (iOS tam güven): evet / hayır
- Uygulamanın kendi trafiği kanıtı: backend alan adı __ , istek sayısı __ (yoksa sonuç KANITSIZ)
- HTTPS çözüldü mü: evet / kısmen / hayır (ne kadar bağlantı çözülemedi: __)
- Toplam istek sayısı:
- Alan adları (adet ile):
- Ses içeren (şüpheli) istek sayısı (har_audio_check.py --expect-domain ...): __   çıkış kodu: __
- Şüpheli varsa: istek, neden, gövde boyutu
- Senaryo kapsamı: 10 dk pratik [ ] · kendi kaydını dinle [ ] · akort [ ] · karşılama (temiz kurulum) [ ]
- Sonuç: GEÇTİ (ses isteği 0, HTTPS çözüldü, kendi trafiği kanıtı var) / GEÇMEDİ / KANITSIZ (HTTPS çözülemedi, kendi trafiği görülmedi ya da HAR boş)
- Ekler: capture/cihaz1.har (repoya konmaz), betik çıktısı (metin)
```

## 7. Kimin ne yapacağı

| Adım | Kim |
|---|---|
| `brew install mitmproxy` | Kurucu ya da gün sabahı Ostinato oturumu (terminalde) |
| Telefonda proxy, sertifika kurma, güven açma, gün sonu temizliği | Kurucu |
| Yakalama başlatma/durdurma, betik çalıştırma, rapor | Ostinato (gün içi) |
| Android için ağ güvenlik yapılandırması (gerekirse) | Ayrı bilet; kurucu/Motion kararı |
