# OST-UX-01 ekran görüntüsü dizini

Üç ayrı kaynak vardır; birbirinin yerine geçmez. Hiçbiri gerçek cihaz görüntüsü değildir. Belgeler görüntülere dayanarak değiştirilmedi; görüntüler yalnız eşlik eder.

## (A) Güncel simülatör, 2 görüntü
Ayrıntı: [simulator/INDEX.md](simulator/INDEX.md). iOS 27.0 simülatör, main `1fa8b93` derlemesi. Giriş engeli: `MOTION_SUPABASE_*` tanımları verilmedi, bu yüzden uygulama içi ekranlara geçilemedi.

| Dosya | Ekran |
|---|---|
| [simulator/01-acilis-splash.png](simulator/01-acilis-splash.png) | Açılış |
| [simulator/02-giris-engeli.png](simulator/02-giris-engeli.png) | Giriş engeli ekranı |

## (B) Test render, sahte veri, 11 görüntü
Ayrıntı ve sahte kurulum: [render/INDEX.md](render/INDEX.md). Etiket: test render, sahte veri; `tool/ux_01_render_evidence_test.dart` ile üretildi; gerçek yazı tipi yüklü, ama simge glifleri kutu çıkar.

| Dosya | Ekran |
|---|---|
| [render/01-onboarding-karsilama.png](render/01-onboarding-karsilama.png) | Onboarding 1 |
| [render/02-onboarding-kapsam.png](render/02-onboarding-kapsam.png) | Onboarding 2 |
| [render/03-onboarding-sensorler.png](render/03-onboarding-sensorler.png) | Onboarding 3 |
| [render/04-studyo-kutuphane.png](render/04-studyo-kutuphane.png) | Stüdyo / kütüphane |
| [render/05-calgi-gitar.png](render/05-calgi-gitar.png) | Çalgı sayfası |
| [render/06-kurs-ders-listesi.png](render/06-kurs-ders-listesi.png) | Kurs ders listesi |
| [render/07-ders-okuyucu.png](render/07-ders-okuyucu.png) | Ders okuyucu |
| [render/08-pratik-ekrani.png](render/08-pratik-ekrani.png) | Pratik ekranı |
| [render/09-pratik-mikrofon-izni-reddi.png](render/09-pratik-mikrofon-izni-reddi.png) | Mikrofon izni reddi |
| [render/10-sonuc-ekrani.png](render/10-sonuc-ekrani.png) | Sonuç ekranı |
| [render/11-ayarlar.png](render/11-ayarlar.png) | Ayarlar |

## (C) Tarihsel kanıt, güncel build değil
Etiket: tarihsel kanıt, güncel build değil. Dosyalar kopyalanmadı; repoda `docs/evidence/` altındadır. Tarih = dosyaya dokunan son commit tarihi (`git log -1`); görüntünün hangi sürümden alındığı bilinmiyor. `.txt` eşi = aynı adlı açıklama dosyası.

| Dosya | .txt eşi | Tarih |
|---|---|---|
| `docs/evidence/01-demo-lesson-guitar.png` | var | 2026-08-07 |
| `docs/evidence/01-library.png` | yok | 2026-08-05 |
| `docs/evidence/02-in-band-cue-silent.png` | yok | 2026-08-05 |
| `docs/evidence/02-scored-lesson-guitar-posture.png` | var | 2026-08-16 |
| `docs/evidence/03-no-person.png` | yok | 2026-08-05 |
| `docs/evidence/04-outside-range.png` | yok | 2026-08-05 |
| `docs/evidence/04a-live-measuring-inband.png` | var | 2026-08-07 |
| `docs/evidence/04b-live-observation-cue.png` | var | 2026-08-07 |
| `docs/evidence/05-observation-cue.png` | yok | 2026-08-05 |
| `docs/evidence/05-review.png` | var | 2026-08-07 |
| `docs/evidence/06-settings.png` | var | 2026-08-16 |
| `docs/evidence/06-tur2-camera-permission-honest-state.png` | yok | 2026-08-05 |
| `docs/evidence/07-onboarding-1-welcome.png` | var | 2026-08-07 |
| `docs/evidence/08-onboarding-2-scope.png` | var | 2026-08-07 |
| `docs/evidence/09-onboarding-3-sensors.png` | var | 2026-08-16 |
| `docs/evidence/10-locked-lesson-chords-beyond-eight.png` | var | 2026-08-07 |
| `docs/evidence/11-library-shared-band-scale.png` | var | 2026-08-16 |
| `docs/evidence/12-instrument-honesty-box.png` | var | 2026-08-07 |
| `docs/evidence/13-course-lesson-list.png` | var | 2026-08-07 |
| `docs/evidence/14-review-nothing-readable.png` | var | 2026-08-07 |
| `docs/evidence/15-tur3-device-walk-setupcheck.png` | var | 2026-08-13 |
| `docs/evidence/17-tur5-walk-1-onboarding-welcome.png` | yok | 2026-08-16 |
| `docs/evidence/18-tur5-walk-2-onboarding-scope.png` | yok | 2026-08-16 |
| `docs/evidence/19-tur5-walk-3-onboarding-sensors.png` | yok | 2026-08-16 |
| `docs/evidence/20-tur5-walk-4-library.png` | yok | 2026-08-16 |
| `docs/evidence/21-tur5-walk-5-guitar-instrument.png` | yok | 2026-08-16 |
| `docs/evidence/22-tur5-walk-6-guitar-foundations-course.png` | yok | 2026-08-16 |
| `docs/evidence/23-tur5-walk-7-sitting-posture.png` | yok | 2026-08-16 |
| `docs/evidence/24-tur5-walk-8-setupcheck-camera-denied.png` | yok | 2026-08-16 |

Ayrıca `docs/evidence/16-gercek-cihaz-kurulumu.txt` PNG'siz metin kanıttır.
