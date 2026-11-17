# Cihaz kayıt tablosu (QA-OST-02)

Durum: **ŞABLON, boş.** En çok 5, en az 2 cihaz (1 iOS + 1 Android). Ortak simülatörler sayılmaz. Tur adımları: [`TUR-LISTESI.md`](TUR-LISTESI.md). Ölçüm yöntemi: [`FLAG-21-OLCUM.md`](FLAG-21-OLCUM.md). Ağ yakalama yalnız cihaz 1'de: [`SEC-OST-01-YAKALAMA.md`](SEC-OST-01-YAKALAMA.md).

Hücre değerleri: `GEÇTİ` · `TAKILDI` (not zorunlu) · `YAPILMADI` (neden zorunlu) · `NOT_TESTED` (başlangıç).

## 1. Cihaz envanteri

| # | Cihaz modeli | OS sürümü | Sahibi | Derleme türü | Derleme SHA (kısa) | Bayrak durumu (K1) | Yenileme hızı (Hz) |
|---|---|---|---|---|---|---|---|
| 1 | iPhone (kurucu) | | Kurucu | profil | | | |
| 2 | Android telefon | | | profil | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |

Derleme SHA: `git rev-parse --short HEAD` (yalnız belge dalıysa tek başına yeterli değildir; açık bayraklı yerel değişiklik varsa "yerel değişiklik: evet" yaz).

## 2. Tur sonuçları (6 adım)

| # | 1 Aç | 2 Yaş kapısı | 3 İlk ders | 4 Mikrofon izni ver / reddet | 5 2 dk pratik | 6 Sonuç + kendi kaydını dinle |
|---|---|---|---|---|---|---|
| 1 | NOT_TESTED | NOT_TESTED | NOT_TESTED | ver: NOT_TESTED / reddet: NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 2 | NOT_TESTED | NOT_TESTED | NOT_TESTED | ver: NOT_TESTED / reddet: NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |

## 3. Ölçümler ve gözlemler

| # | Kare süresi (build+raster, ms): ortanca / p95 / en kötü | Ölçüm yolu (profil + DevTools / ekran videosu) | İzin reddi sonrası "Başlat" | Ağ yakalama (yalnız cihaz 1): istek / ses şüpheli | Çökme / donma | Notlar |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | n/a | | |
| 3 | | | | n/a | | |
| 4 | | | | n/a | | |
| 5 | | | | n/a | | |

"İzin reddi sonrası Başlat" hücresine [`FLAG-21-OLCUM.md`](FLAG-21-OLCUM.md) §4'teki beklenen davranışla karşılaştırarak `GEÇTİ` / `TAKILDI` yaz; TAKILDI ise gördüğünü ve ekran görüntüsü yolunu notla.

## 4. Açık bulgular

| No | Cihaz | Adım | Gözlem | Kanıt (ekran görüntüsü / video yolu) | Bilet önerisi |
|---|---|---|---|---|---|
| B1 | | | | | |

## 5. Kabul özeti (gün sonunda doldurulur)

- Cihaz sayısı (en az 2, en çok 5): ____
- Ham ses içeren istek sayısı (SEC-OST-01 ile birleşik): ____ (hedef 0)
- Tur 6 adımın tamamı en az bir iOS ve bir Android cihazda koşuldu mu: evet / hayır
