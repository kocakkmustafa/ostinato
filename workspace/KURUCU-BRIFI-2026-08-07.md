# Ostinato — Kurucu Brifi, 2026-08-07

**Soru:** *Ostinato bugün App Store'a gönderilebilir mi?*
**Ölçüm:** 15:00 · `main` = `de8735b` · ağaç temiz · 26/26 kapı yeşil

> ⚠️ **Bu raporun kendi öz-denetimi (2 düzeltme):**
>
> **①** *"Store metadata yok"* **fazla emin bir cümleydi** — depoda ekran
> görüntüsü olmadığını ÖLÇTÜM, ama store metni App Store Connect'te yaşıyor
> ve oraya BAKAMIYORUM. Bir kısmı ölçüldü, bir kısmı ölçülemedi.
>
> **②** *"Kod tarafında kalan tek iş: `PrivacyInfo.xcprivacy`"* **de fazla
> emindi.** Yazarken ölçtüm: uygulama kodu hiçbir *required-reason* API'si
> kullanmıyor, Flutter motoru ile `path_provider`/`permission_handler` kendi
> manifestlerini taşıyor. O kalem **hijyendi, engel değildi.** Yine de
> eklendi (`de8735b`) ve derlenmiş pakette varlığı doğrulandı — çünkü
> "hiçbir şey toplamıyoruz" beyanı bu üründe birinci sınıf bir dürüstlük
> yüzeyi. Ama **kod sınıfında yayın engeli artık YOK.**

# ⛔ HAYIR — 3 engel.

| # | engel | sınıf | büyüklük |
|---|---|---|---|
| **1** | **Uygulama hiç gerçek cihazda çalışmadı** | **sizde** (cihaz günü) | bilinmiyor |
| **2** | **İkon + açılış görseli Flutter varsayılanı** | **sizde** (tasarım) → sonra bende (uygulama) | saatler |
| **3** | **Store metadata + ekran görüntüleri** — depoda ekran görüntüsü YOK (ölçüldü); App Store Connect tarafını **göremiyorum** | **sizde** + `ölçülmemiş` | gün |

## Kod tarafında yayın engeli KALMADI

Bugün kapatıldı: gizlilik manifesti yazıldı ve derlenmiş pakette varlığı
doğrulandı. Üç engelin **üçü de sizde** — hiçbiri kodla çözülmüyor.

---

## #1 neden en ağırı

Ürünün tek işi kameradan postür ölçmek. Simülatörde kamera yok.

Bugün ölçtüm: uygulamada **11 ekran** var, otomatik yürüyüş **8'ine**
dokunarak gidebiliyor. Gidemediği **3'ü — Kurulum Kontrolü · Canlı ölçüm ·
Özet — ürünün asıl deneyiminin tamamı**, ve üçü de kameranın arkasında.

**Bir seansın baştan sona çalıştığını hiç kimse görmedi.**

Uygulamanın kendi Ayarlar ekranı bunu kullanıcıya şu an söylüyor:
*"Nothing here has been verified on real hardware."*

---

## ✅ Engel OLMAYANLAR — ölçüldü, varsayılmadı

- **iOS release derleniyor** (45 MB)
- **Mikrofon kullanılmıyor** ve hiçbir ekran onu vaat etmiyor — kapatılmış
  bir sınır, engel değil
- **IAP yok** — ücretsiz uygulama meşru, iş kararı
- **"Yakında" / "henüz" gibi vaat dili** tüm uygulamada **sıfır**
- **Poz modeli** yerinde (8 MB + indirme betiği)

## ⚠️ Zayıflatanlar (engel değil, ama bilin)

- Yazı tipleri açılışta internetten iniyor → ağsız ilk açılışta yazı yok
  (yarım saatlik iş, bugün kapatabilirim)
- İçerik ince: 28 ders, 3 çalgı
- İkonların gerçek telefonda nasıl göründüğü hiç görülmedi

---

## Dürüst özet

Gece **kalite kapıları kurmaya** harcandı. O kapılar bugün **14 gerçek
kusur** buldu — hiç ölçüm yokken kullanıcıya *"iyi gidiyorsun"* denmesi,
veri yokken uydurma bir grafik çizilmesi, olmayan bir veri saklama
iddiası. Hepsi gerçekti ve kullanıcıya zarar verecekti.

**Ama hiçbiri ikon çizmedi, hiçbiri uygulamayı bir telefonda çalıştırmadı.**

Ostinato ailenin yayına en yakın hattıydı. **O da hazır değil** — aile için
tavan budur.

**Sizden gelen üç şeyle (cihaz günü · ikon · store metni) yayına çok
yaklaşır.**
