# Ostinato — bugün gönderilebilir mi?

**Ölçüm: 2026-08-07 12:40 · `main` = `139e8a2` · ağaç temiz**

# ⛔ HAYIR.

## Yayını ENGELLEYENLER

| # | engel | sınıf | büyüklük |
|---|---|---|---|
| 1 | **Uygulama ikonu Flutter'ın varsayılan mavi logosu** (dosya açıldı, bakıldı) | içerik | saatler |
| 2 | **Açılış görseli varsayılan** — 68 baytlık boş beyaz PNG | içerik | saatler |
| 3 | **Uygulama hiç gerçek cihazda çalışmadı** | manuel/kurucu | **bilinmiyor** |
| 4 | Store metadata + ekran görüntüleri yok | manuel + içerik | gün |
| 5 | `PrivacyInfo.xcprivacy` yok (kamera + dosya yazımı var) | kod | saatler |
| 6 | ASC kaydı / sertifika durumu | **ölçülmemiş** | — |

### #3 neden en ağırı

Ürünün tek işi kameradan postür ölçmek. Simülatörde kamera yok.
Bugün bağımsız olarak ikinci kez doğrulandı: uygulamada **11 rota** var,
otomatik yürüyüş **8'ine** dokunarak gidebildi. Gidemediği **3'ü —
Kurulum Kontrolü · Canlı ölçüm · Özet — ürünün asıl deneyiminin tamamı**,
ve üçü de kamera arkasında.

**Bir seansın baştan sona çalıştığını hiç kimse görmedi.**

Uygulamanın kendi Ayarlar ekranı bunu kullanıcıya zaten söylüyor:
*"Nothing here has been verified on real hardware."*

## ⚠️ Yayını ZAYIFLATANLAR (engel değil)

- `google_fonts` yazı tiplerini ağdan indiriyor → ağsız ilk açılışta yazı tipi yok
- İçerik ince: 28 ders / 3 çalgı
- 1-8 kare arası ölçümde hâlâ hüküm veriliyor (eşik kararı kurucuda)
- İkon/emoji gerçek cihazda hiç doğrulanmadı

## ✅ Engel OLMAYANLAR — ölçüldü, varsayılmadı

- **Mikrofon:** kullanılmıyor, beyan edilmiyor, ve **hiçbir yüzey vaat
  etmiyor**. Kapatılmış bir sınır, engel değil. Store metni yazılırken de
  aynı koruma geçerli.
- **IAP/paywall yok** — ücretsiz uygulama meşru; iş kararı.
- **iOS release derleniyor** ✓ (45 MB, `flutter build ios --release`)
- **Vaat dili** ("yakında", "henüz") sevk edilen tüm yüzeyde **sıfır**
- **Poz modeli** yerinde (8 MB + indirme betiği)

---

## Bugün kapatabileceğim (kod/içerik, ≈ yarım gün)

1. Gerçek uygulama ikonu (tasarım kurucudan gelirse uygularım)
2. Gerçek açılış görseli
3. `PrivacyInfo.xcprivacy`
4. Yazı tiplerini uygulamaya gömmek (ağ bağımlılığını kaldırır)

## Kapatamayacağım (kurucuda)

1. **Cihaz günü** — telefonda bir seans, baştan sona
2. Store metadata (başlık, açıklama, anahtar kelime)
3. Ekran görüntüleri
4. ASC kaydı / sertifikalar

---

## Dürüst özet

Gece **kapı kurmaya** harcandı, yayın kalemlerine değil. O kapılar bugün
**14 gerçek kusur** buldu — sıfır ölçümle "iyi gidiyorsun" hükmü verilmesi,
veri yokken uydurma bir grafik çizilmesi, var olmayan bir veri saklama
iddiası dahil. Hepsi gerçekti ve kullanıcıya zarar verecekti.

**Ama hiçbiri ikon çizmedi, hiçbiri uygulamayı bir telefonda çalıştırmadı.**

Ostinato ailenin yayına en yakın hattıydı. **O da hazır değil** — aile için
tavan budur.
