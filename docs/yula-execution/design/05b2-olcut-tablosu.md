# OST-UX-05b2 ölçüt tablosu (bayrak KAPALI; sahne bayrağın arkasında)

Test dosyası: `test/stage_home_test.dart`, grup `05b2 open points (a)(b)(e)`.

| Nokta | Test adı | Önce kırmızı / sonra yeşil | PNG |
|---|---|---|---|
| (a) üye: ücretli next gösterilir | `(a) member: the paid next lesson (s2+) is shown` | kırmızı (üyelik yok sayılınca `gtr-s1-m01-07`) / yeşil | - |
| (a) ücretsiz: ücretli next düşer, güvenli yedek | `(a) free user: ...NOT shown`, `(a) no access check wired` | koruma zaten vardı; yeşil kalır | - |
| (b) Çal görünür+dokunulabilir, 6 durum | `(b) Play visible and tappable: <boyut>, shelf closed/open` | 6/6 kırmızı (eski kod) / 6/6 yeşil | `evidence/ux-05b2/cal-*.png` (`tool/ux_05b2_render_evidence_test.dart`) |
| (e) yarım koşu sonrası akort kartı yok | `(e) half run, back: the tuning card does not return` | kırmızı / yeşil | - |

Tam suit (son koşu, baş `f62f0ea`, `ux05b2-fulltest2.log`): +2173, 0 başarısız, EXIT 0 (taban +2154, +19 yeni test: 3 (a) + 6 (b) + 1 (e) + 6 `ostinato_has_paid_access_test.dart` [oturum yok/hata/kullanıcı değişimi/aktif/aktif değil/satış kapalı] + 3 sahne [kontrol fırlatır, 4 sn zaman aşımı → ücretsiz ders + Çal aktif, `AccountScope` yolu]). İlk koşu: +2164.
Not: PNG'lerdeki kare glifler test yazı tipinin eksik simgeleridir (önceki kanıtlarla aynı).

## Bayrak açılmadan önce
  - (i) Sahne Çal'da `admitV1Lesson` çağırmaz; üyelik yalnız `_load`'da bir kez sorulur. Oturum ortasında üyelik biterse ücretli ders Çal'da açık kalır: Çal'da yeniden doğrulama ya da bilinçli kabul kararı gerekir.
  - (ii) Güvenlik satırı ("Ağrı, uyuşma…") kaydırılan gövdede, Çal gövdenin dışında: 360x640 + yazı 1.3 + raf açıkken ilk ekranda görünmez, kaydırmayla erişilir.
  - (iii) `onStarted` mikrofon izni reddedilse de akort kartını oturum boyunca gizler; sahnede akortçuya başka yol olmayabilir ('Ayar' tutamağının işlevi doğrulanamadı).
