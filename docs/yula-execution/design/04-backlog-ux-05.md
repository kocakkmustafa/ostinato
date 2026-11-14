# UX-05a…h alt biletleri: kabul ölçütleri (OST-UX-03, teslimat 14)

Tarih: 2026-11-09 · Bağlı belge: [`04-design.md`](04-design.md) (ADR-UX-001 ve teslimat 1–13).
Bu belge talimat §7 Aşama 5 madde 14 "Uygulama backlog'u ve kabul kriterleri"dir. YALNIZ BELGE; bilet açmaz, kod yazmaz.

## Ortak kurallar (her alt bilet için geçerli)
| Kural | İçerik |
|---|---|
| Bayrak | Yeni davranış bayrak arkasında, **KAPALI varsayılan**: `ostinatoStageHomeEnabled` (a hariç b–f, h), `ostinatoGhostScreenEnabled` (g). Bu bilet bayrak değerini ÇEVİRMEZ; "bayrak AÇIK" yalnız test ortamında. Mevcut bayraklar (`ostinatoCameraPracticeAvailable`, `ostinatoCameraLessonsOpen`, `ostinatoListenTryFixRepeatOpen`, `ostinatoRecordingRetentionOpen`) KAPALI kalır. |
| Bayrak KAPALI regresyonu | Her bilette: bayrak KAPALIyken mevcut davranış ve mevcut testler aynen geçer (kök = `library_screen.dart`). |
| Değişmeyenler | Renk, tipografi, marka, kurs verisi, ölçüm eşikleri, `V1PracticeRecord` biçimi, ücretli koruma, yeni bağımlılık yok (0), yeni ücretli kaynak 0 USD, "yanlış/wrong" metni yok, ham ses cihazdan çıkmaz. |
| Kanıt biçimi | Test adı + sayı, `flutter analyze` temiz, ekran kanıtı yolu `docs/yula-execution/design/evidence/ux-05<harf>/` altında test render PNG (ya da simülatör) + commit SHA. "Yeşil sarmalayıcı kanıt değildir." |
| Test türleri | Birim (U), widget (W), golden/render (G), entegrasyon/simülatör (E), erişilebilirlik semantiği (A), cihaz ölçümü (C; kurucu cihazı gerektirirse bilet "NOT_TESTED" yazar). |
| Bağımlılık sırası | a → b → (c, d, e, f paralel) → g → h. g, e'nin dürüst-durum kurallarına dayanır. |

---

## UX-05a — Glass çekirdeği (`GlassLayer`, opak yedek)
**Kapsam:** Katman bileşeni; saydamlık ve hareket azaltma yolları; bulanıklık bütçesi; düşük donanım yedeği. Ekran yok.
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | Katman açıkken en çok 1 bulanık yüzey çizilir; çalarken (oynatma durumu) bulanıklık ve cam öğe sayısı 0 | W | — |
| 2 | Aynı anda en çok 2 cam öğe; üçüncü açma isteği reddedilir ya da birincisini kapatır (davranış testle sabit) | W | — |
| 3 | Sistem "saydamlığı azalt/kontrastı artır" = katman opak; "hareketi azalt" = geçiş anlık (`MediaQuery` simülasyonu) | W | G: açık/koyu, normal/azaltılmış, 4 render |
| 4 | Kontrast: katman metni ≥ 4.5:1, bileşenler ≥ 3:1, en kötü arka plan üzerinde (hesaplayan birim test; renkler mevcut tema belirteçlerinden) | U | G |
| 5 | Sigma ≤ 16 ve bulanık alan ≤ ~%60 (yapılandırma değerleri testte sabit) | U | — |
| 6 | Düşük donanım: kare süresi bütçesi aşımı simülasyonunda bulanıklık kapanır, katman opak kalır | W | — |
| 7 | Gerçek cihazda kare süresi ölçülür (bulanık katman açık/kapalı) ve kayda geçer; ölçülemezse `NOT_TESTED` | C | Sayı tablosu |
| 8 | Bayrak: yok (bileşen); hiçbir mevcut ekran bileşeni kullanmaz (bayrak KAPALI = davranış değişmez); mevcut `GlassCard` testleri geçer | W | — |

## UX-05b — Sahne kabuğu ve kök değişimi
**Kapsam:** `ostinatoStageHomeEnabled` KAPALI; AÇIK iken kök = sahne (devam edilen alıştırma, Çal, tempo, mikrofon durumu, tutamaklar, çalarken gizleme) ve opak araç rafı sarmalayıcısı (Metronom, Referans, Döngü, Yardım satırı yeri; kapalı başlar; mevcut parçaları yeniden kullanır, ekranı bölmez).
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | Bayrak KAPALI: kök `library_screen.dart`, mevcut kök testleri geçer | W | G: eski kök değişmedi |
| 2 | Bayrak AÇIK: karşılamadan sonra sahne; `V1CourseState.next` dersi, yoksa ilk ölçülü ders; tek "Çal" | W | G: sahne (devam var / yeni kullanıcı) |
| 3 | T1: Çal'a tek dokunuşla pratik başlar; mikrofon izni ilk Çal'da istenir | W | — |
| 4 | Çalarken üç tutamak gizli, hiçbir katman açılamaz; hatada ekran durmaz | W | G: çalarken |
| 5 | Mevcut pratik çekirdeği (şerit, ölçüm, geçit) davranışı değişmez: mevcut `practice_*` testleri aynen geçer | W | — |
| 6 | Araç rafı: bayrak KAPALIyken görünmez; AÇIKken kapalı başlar; çalarken kapalıdır/açılamaz (sabitlenen metronom, tamamen opak ve raftan bağımsız, hariç); mevcut `practice_*` testleri aynen geçer | W | G: raf kapalı/açık |
| 6a | Sabitlenen metronom: çalarken görünür, tamamen opak, cam öğe sayısına girmez; bayrak KAPALIyken yok | W | G: çalarken metronom görünür |
| 7 | Geri: katman açıkken katmanı kapatır, çıkış ekranından sahneye döner (iki test); yarım koşudan çıkış "tamamlanmadı = ölçülmedi" yazar ve geçit kaydı eklemez (kayıt deposu eleman sayısı aynı) | W | — |

## UX-05c — Katman yöneticisi ve "Başka çalış"
**Kapsam:** Katman yöneticisi (tek katman kuralı, odak yönetimi), "Başka çalış" (öneri satırı, aynı alıştırma, Gitar/Kulak seçimi, Akort kısayolu, son gelişim). Bayrak KAPALI varsayılan (`ostinatoStageHomeEnabled`).
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | Tek katman açıkken ikincisi açılırsa birincisi kapanır; cam öğe ≤ 2 | W | — |
| 2 | Katman yüksekliği ekran yüksekliğinin ≤ %60'ı; üstte şerit alanı ≥ %40 (360×640 ve 412×915 mantıksal piksel için yerleşim testi) | W | G: katman açık |
| 3 | Öneri satırı deterministik: aynı girdi (`V1CourseState.next` + son hata türü) → aynı öneri; kayıt yoksa satır gizlenir (birim test, ≥ 5 durum) | U | — |
| 4 | T2: Kulak (enstrümansız) en çok iki dokunuşta açılır; Akort tam ekran açılır, geri = sahne | W | G: iki durum |
| 5 | Çalgı seçimi: gitar ve kulak açık; "Yakında" çalgılar mevcut kural gibi (`ostinatoOpenInstruments`) | W | — |
| 6 | Odak: katman açılınca ilk öğeye, kapanınca tutamağa (semantik testi) | A | — |
| 7 | Çalarken tutamak/katman açılmaz (UX-05b ile aynı test, bu ekranlarda tekrar) | W | — |

## UX-05d — "Yolum" çekmecesi (Yol + Geçmiş)
**Kapsam:** Yol (seviye > modül > ders, "neden bu" satırı, liste eşdeğeri birincil), Geçmiş (önceki denemeler yan yana, `bestAccuracy/bestHeard/bestBpm` OKUMA, haftalık hedef düz satır). Veri modeli değişmez.
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | Yol, `v1_course_catalog.dart` ile birebir (seviye × modül × ders sayıları); kapı/ücretli/kilit işaretleri mevcut `ostinato_paid_access.dart` / kapı mantığıyla aynı (sayı eşleşme testi) | W | G: Yol |
| 2 | T3: Sıradaki ders ve "neden bu" satırı görünür; neden metni yalnız kayıtlı olgudan (geçit/tamamlama) | W | G |
| 3 | T6: Geçmiş önceki denemeleri yan yana gösterir; duyulan % doğruluktan AYRI; puan/rozet/seri baskısı yok | W | G: Geçmiş |
| 4 | Boş veri: "Bir kez çal; koşun burada görünür." metni; sayı/yetkinlik uydurulmaz | W | G: boş |
| 5 | Kulak sonuçları ayrı bölümde; enstrüman toplamına katılmaz (birim test) | U | — |
| 6 | `V1PracticeRecord` / `V1LessonCheck` JSON biçimi ve mevcut testler değişmeden geçer (şema değişmedi kanıtı: diff'te model dosyası yok) | U | — |
| 7 | Ekran okuyucu: Yol doğrusal listedir, harita bileşeni yok | A | — |

## UX-05e — Sonuç katmanı ve dürüst durum
**Kapsam:** `practice_result_screen.dart` yeniden düzenlenir; "duyamadım" ailesi; ölçülmedi etiketi. Bayrak KAPALI varsayılan (`ostinatoStageHomeEnabled`).
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | İçerik korunur: ✓/◆/◯ sayıları, hata haritası, geçit, "Tekrar dene/Sonraki"; mevcut `practice_result_*` testleri geçer | W | G |
| 2 | Altı `HearingReason` (noAttack, tooQuiet, tooLoud, unclear, appPlayback, skipped) her biri için nötr metin; hiçbir metinde "yanlış/wrong" geçmez (metin taraması testi) | U | G: altı durum |
| 3 | Duyulan % doğruluktan ayrı; doğruluk yalnız karar verilenler üzerinden (mevcut hesap aynen, test sabitli) | U | — |
| 4 | Duyulan < %80 → "kurulumu kontrol et" adımı (`NextStep.checkSetup`); eşikler (%80/%80) değişmez | U | — |
| 5 | Koşu yarım/döngülü/Bekle'li = "ölçülmedi" etiketi; geçidi açmaz (`GateIneligible` ile eşleşme; OST-P0-07 main'de birleştiyse onun testleriyle uyumlu) | U | G |
| 6 | Çok sesli/gürültülü giriş senaryosu: ◯ + sebep, yargı yok (mevcut OST-P0-04 korpus kuralları: 0 yanlış hüküm) | U | — |
| 7 | T4/T5: "Nerede oldu" çubuğu; Tekrar dene sahneyi aynı bölümde hazırlar; çubuğa dokun = döngü | W | — |
| 8 | Çalarken sonuç katmanı çıkmaz; yalnız Dur sonrası | W | — |

## UX-05f — İzin reddi, kurulum ve Ayar/Cihaz
**Kapsam:** "Dinleme kapalı" kipi; Ayar/Cihaz katmanı (mikrofon, gecikme/kalibrasyon, gürültü, erişilebilirlik, Ayarlar, Hesap/Üyelik); kamera akışı YOK. Bayrak KAPALI varsayılan (`ostinatoStageHomeEnabled`).
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | T7: Mikrofon reddi: sahne "Dinleme kapalı" kipi; şerit, metronom, "Şu hızda dinle", kulak çalışır; ✓◆◯ yok, sayaç "ölçülmüyor" (mevcut `mic_permission_gate_test.dart` geçer) | W | G: kip (`evidence/ux-05f/`) |
| 2 | "Ayarlara git" bağlantısı sürekli ama susturulabilir; susturma kaydı yerel | W | — |
| 3 | T8: Kamera bayrakları KAPALI; hiçbir akış kamera izni istemez (bayrak KAPALIyken hiçbir yol `Permission.camera` çağırmaz; çağrı sayısı = 0 testle sabit) | W | — |
| 4 | Ayar/Cihaz: mikrofon durumu, gecikme kalibrasyonu (`setup_wizard_screen.dart` aynen), ortam gürültüsü satırı; Ayarlar ve Hesap/Üyelik tam ekran çıkış, davranış değişmez (mevcut testler geçer) | W | G: Cihaz |
| 5 | Reddedilmiş iznin gerçek cihazda "Başlat" davranışı doğrulanır ve kayda yazılır; yapılamazsa `NOT_TESTED` | C | Ekran yolu |
| 6 | Ham ses cihazdan çıkmaz: ağ çağrısı ve kalıcı kayıt yok (`ostinatoRecordingRetentionOpen=false` varsayılan korunur; mevcut ephemeral testler geçer) | W | — |

## UX-05g — Hayalet Ekran (dört basamak)
**Kapsam:** Raf > Yardım; öğrenme, pekiştirme, hatırlama, bağımsız; elle seçim; ölçüm kapılı öneri; ayrı yerel store. Bayrak `ostinatoGhostScreenEnabled` KAPALI varsayılan.
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | Bayrak KAPALI: Yardım satırı hiç görünmez, pratik aynen | W | — |
| 2 | Dört basamak yardım matrisi (04-design Ek B) testle sabit: hangi öğe hangi basamakta görünür | W | G: dört basamak (`evidence/ux-05g/`) |
| 3 | Basamak yalnız elle değişir; hiçbir koşuda otomatik değişmez (birim test: yüksek başarılı koşu sonrası basamak aynı) | U | — |
| 4 | Öneri yalnız ölçülmüş, tam, döngüsüz, Bekle'siz, geçit geçen koşularla çıkar; `stoppedEarly/loopUsed/waitUsed` ve duyulan < %80 koşular öneri ÜRETMEZ (tablo testi ≥ 8 durum: her basamak geçişi için eşik−1, eşik, eşik+1 koşu sayısı ve dört güvenilmez-koşu türü dahil; geçiş sayıları: 1→2 bir koşu, 2→3 iki, 3→4 üç) | U | — |
| 5 | Güvenilmez ölçümde "yetkinlik kazanıldı" metni hiçbir yolda yok (metin taraması + durum testi); sonuç "ölçülmedi/değerlendirilemedi" | U | G |
| 6 | Basamak yeni ayrı yerel anahtarda; `V1PracticeRecord`, kapı ve eşikler değişmez; Hayalet kapıyı AÇMAZ | U | — |
| 7 | Kulak/ritim alıştırmaları Hayalet basamağını ve enstrüman geçidini ETKİLEMEZ; tersi de (birim test) | U | — |
| 8 | Çalarken yardım ayarı değişmez/açılmaz | W | — |

## UX-05h — Erişilebilirlik, yükleme/çevrimdışı/hata, test senaryoları ve geçiş kanıtı
**Kapsam:** teslimat 9, 10, 13'ün doğrulaması; hiçbir yeni özellik. Bayrak KAPALI varsayılan.
| # | Kabul ölçütü | Test türü | Ekran kanıtı |
|---|---|---|---|
| 1 | Ekran okuyucu: sahne sırası Çal → tutamaklar → durum; ✓◆◯ metin etiketi okunur; katman odak yönetimi (T12) | A | — |
| 2 | Büyük metin 2.0: sahne, katmanlar, sonuç taşmaz (render testi, telefon boyutu) | G | G: 2.0 ölçek, 4 ekran |
| 3 | Dokunma hedefi ≥ 48 dp: Çal, Dur, tutamaklar (ölçüm testi) | W | — |
| 4 | Hareketi/saydamlığı azalt ile dört ana yüzey kırılmaz ve opak/anlık (T12) | G | G |
| 5 | Çevrimdışı: pratik, kulak, akort, yerel kayıt çalışır; bulut/hesap yüzeyleri "çevrimdışı" der (uçak modu / ağsız test ortamı) | W+E | G: çevrimdışı |
| 6 | Hata: veri okuma/yazma hatasında sahne açık kalır, "tekrar dene" sunulur, kayıt sessizce kaybolmaz | W | G |
| 7 | T1–T14 (04-design bölüm 13): T12 hariç 13 senaryonun her biri için en az bir adlandırılmış test (adlar INDEX'te); T12 için kalem 1–4 ve kayıtlı el kontrolü | W+E | `evidence/ux-05h/INDEX.md` |
| 8 | Bayrak KAPALI regresyon turu: tüm mevcut test paketi aynen geçer; bayrak AÇIK turu: `flutter analyze` temiz ve yeni testler geçer; sayılar rapora yazılır | E | Test sayısı çıktısı |
| 9 | Kullanıcı testi (insan) bu bilette yapılmaz; Aşama 6 prototipidir. Bu bilet bunu "yapılmadı" diye yazar | — | — |

## Prototip devir notları (OST-UX-04)
Kod bu bilette değiştirilmedi; UX-05'te ele alınacak bilinen noktalar:
1. `_tryAgain` `_loop`'u sıfırlamıyor (`ux_prototype_screen.dart` ~143-146): "Bu ölçüyü döngüle"den sonra "Tekrar dene" hep ölçülmeyen koşu veriyor; döngüyü kapatma yolu yalnız "Sonraki".
2. `ux-ear-reveal` seçimle karşılaştırmadan hep "İkinci nota daha yüksekti" gösteriyor (~673).
3. "En fazla 2 cam" testi tek katmanı sınar ve `lessThanOrEqualTo(2)` totolojidir; ayrıca sekme/çip `Semantics(button: true)` çift düğüm riski doğrulanmadı.

## 05b devir notları
- COZULDU (05b2): Ücretli kullanıcı: sahne `next` dersini üye için gösterir (yan etkisiz `hasPaidAccess`), ücretsizde güvenli yedek kalır. Ders bitince veri yeniden yüklenmez, sonuç ekranına `hasNextLesson` geçilmez.
- COZULDU (05b2): Çal sahnede sabit alan; raf sınırlı yükseklikte kaydırılabilir; 390x844, 360x640 ve yazı 1.3'te raf kapalı/açık görünür. (Eski not: 390x844'te "Çal" yarı kesik, raf açıkken pratik alanı ~160 dp: akort kartı sahne dışına / raf açıkken "Çal" sabit (05c-f önünde karar).)
- COZULDU (05b2, bkz. yukarı): 360x640 ve büyük yazı ölçeğinde raf taşması doğrulanmadı; raf kaydırılabilir değil.
- Raf: referans çubuğu `hasPitches || isRhythmOnly` ve `Guide.referenceAudio` koşulsuz; döngü yalnız 1-2. ölçü, `RangeSlider` yok.
- Eski `GlassCard` (`widgets.dart:39`) çalarken de `BackdropFilter` kullanır: 05h.
- COZULDU (05b2): Yarım koşu sonrası sahne yeniden kurulur; akort kartı tekrar çıkmaz (`tuningCardSeen`).
- Bayrak açılmadan önce (05b2 reviewer notları):
  - (i) Sahne Çal'da `admitV1Lesson` çağırmaz; üyelik yalnız `_load`'da bir kez sorulur. Oturum ortasında üyelik biterse ücretli ders Çal'da açık kalır: Çal'da yeniden doğrulama ya da bilinçli kabul kararı gerekir.
  - (ii) Güvenlik satırı ("Ağrı, uyuşma…") kaydırılan gövdede, Çal gövdenin dışında: 360x640 + yazı 1.3 + raf açıkken ilk ekranda görünmez, kaydırmayla erişilir.
  - (iii) `onStarted` mikrofon izni reddedilse de akort kartını oturum boyunca gizler; sahnede akortçuya başka yol olmayabilir ('Ayar' tutamağının işlevi doğrulanamadı).

## 05c devir notları
- COZULDU (05c): Çal'da `admitV1Lesson` yeniden doğrulanır (`beforeStart`, fail-closed; ücretsiz derste çağrılmaz). Raf: ReferenceListenBar yalnız `hasPitches || isRhythmOnly` ve `Guide.referenceAudio` iken; Döngü `RangeSlider` rafta (`stage-loop-range`).
- Bayrak açılmadan önce (05c reviewer tur 2 düşük notları): ayrıntı `05c-olcut-tablosu.md` "Tur 2" (A: `_starting` sıfırlama testi yok, guard hiç dönmezse ÇAL sessiz; B: oturum içi ve yeniden açılış öneri satırı `passed` farkı; E: başlık oturum içinde güncellenmez).
- Hâlâ açık (05d–f): (ii) güvenlik satırı 360x640 + yazı 1.3 + raf açıkken ilk ekranda; (iii) mikrofon reddi sonrası akort kartı gizli kalır, "Ayar" tutamağı akortçu yolu 05f'te. Ölçüt 4 testlerinde `tunerOpener`/`earScreenBuilder` taklit: gerçek `openTuner`/`_earScreen` NOT_TESTED.


## 05g devir notları
- ADR (Motion orchestration, 2026-11-12): Kulak/ritim-only dersler Hayalet'e girmez. Gerekçe: Hayalet görsel nota/tab desteğini kademeli kaldırır; kulak/ritim derslerinde kaldırılacak görsel yoktur. Açık: seçilen basamağın pratik ekranındaki nota/tab/vuruş görünürlüğüne uygulanması OST-UX-05g2'dir (bayrak açılmadan önce zorunlu); eski akışta NextStep'in kısmi veriden öneri üretmesi OST-UX-05e2'dir (eski sonuç ekranında da 'Ölçülmedi' koşusunda öneri yok).
- COZULDU (05g2, PR #89): seçilen basamak pratik ekranında nota+tab şeridi ve vuruş göstergesine uygulanır (Öğrenme/Pekiştirme: var/var; Hatırlama: yok/var; Bağımsız: yok/yok). Depo yüklenene kadar pratik ekranına seviye geçilmez (main davranışı); ritim-only derslerde görünürlük değişmez. Bayrak `ostinatoGhostScreenOpen` KAPALI.
- Bayrak `ostinatoGhostScreenOpen` AÇILMADAN önce zorunlu takip (05g2 reviewer):
  - B1 → OST-UX-05g3 (uygula YA DA rafı uygulananlarla sınırla; ADR'li, test-önce, bayrak `ostinatoGhostScreenOpen` açılmadan önce zorunlu; #89 kapsamında değil): `tool_shelf.dart:281-290` ve `ghost_level_copy.dart:16-24` rafta "Bu basamağın yardımları" altında Hatırlama için "Başlamadan 3 sn nota" (`preStartPreview`), Bağımsız için "Metronom (isteğe bağlı)" (`metronome`) ve "İpucu" (`hint`) listeliyor; pratik ekranında bunlar uygulanmadı (`GhostItem.preStartPreview/metronome/hint` kodda yalnız `tool_shelf.dart`'ta geçiyor). Kullanıcı Hatırlama'yı seçince raf ön izleme vaat eder ama pratikte nota çıkmaz. → ÇÖZÜLDÜ (05g3), ADR aşağıda
  - B4: Öğrenme'deki `label` ("Etiket", Pekiştirme'de kalkar) öğesinin pratik ekranında karşılığı yok; B1 ile birlikte ele alınır (05g3). → ÇÖZÜLDÜ (05g3), ADR aşağıda
  - B2 → 05h: gizli şerit yer tutucusu `ghost-step-line-hidden` 190 dp, `Semantics` etiketi yok (ekran okuyucu boşluğu duymaz); 360×640 + yazı 1.3 testi yok.
- ADR (Ostinato 05g3, 2026-11-13): raf ↔ pratik ekranı uyumu. Kural: raf neyi vaat ediyorsa pratik ekranı onu yapar; rafta olmayan yardım ekranda yok.
  - `label` UYGULANDI: Öğrenme'de nota/tab şeridinde her nota işaretinin üstünde nota adı etiketi çizilir (başka basamakta ve `ghostLevel == null` iken yok).
  - `preStartPreview` UYGULANDI: Hatırlama'da Başlat'a basınca (mevcut `beforeStart` koruması sonrası) gizli nota şeridi sabit 3 sn görünür (mevcut "Başlamadan 3 sn nota" metni, canlı bölge), sonra koşu başlar; yeni zamanlama motoru yok, bu sürede ikinci Başlat yok sayılır.
  - `metronome` RAFTAN KALDIRILDI: pratik ekranındaki "Klik sesi" anahtarı her basamakta zaten var ve varsayılan açık; basamağa özgü bir yardım değil, rafta vaat etmek yanıltıcıydı. Anahtar değişmez.
  - `hint` RAFTAN KALDIRILDI: içeriği ve ölçümdeki anlamı (yardımlı koşu sayılır mı) tanımsız. İpucu ürün kararı: yardımlı koşunun ölçümdeki anlamı tanımlanınca ayrı biletle eklenir.
  - Sonuç: Öğrenme {nota, tab, vuruş, etiket}; Pekiştirme {nota, tab, vuruş}; Hatırlama {ön izleme, vuruş}; Bağımsız boş (raf yalnız "Bu basamakta ek yardım yok" der; bu tek yeni metin 14 kataloğa eklendi, `metronome`/`hint` metinleri kataloglardan düştü, id sayısı 8801 → 8800). Öğrenme/Pekiştirme farkı artık etiket.
  - Düzeltme: B1'deki "kodda yalnız `tool_shelf.dart`'ta geçiyor" ifadesi fazla iddialıydı; `GhostItem.preStartPreview/metronome/hint` `ghost_policy.dart:12,68-73` içinde de geçiyor (pratik ekranında kullanımı yoktu).

## 05h-1 devir notları
- Kapandı: sahne bildirimleri (`stage-run-not-completed`, `stage-start-unverified`, "Dinleme kapalı" bandı) tek düğümlü canlı bölge; 14 dilde Ayar/Cihaz katmanı taşması (`device_layer.dart` `_row`: etiket doğal genişlik, ipucu en çok %40 ve sarar).
- Güvenlik satırı: sahnede kaydırılan gövdenin dışında, Çal'ın hemen üstünde (mikrofon hata iletisi gövdenin başına taşındı; sabit alan yalnız satır + Çal). ÖLÇÜLEN: 360×640 yazı 1.3 raf açık/kapalı ve 14 dilin hepsinde satır tam görünür (kırpılmamış), Çal ekran içinde, çakışma yok; 412×915 (bant+hata+raf) aynı. 320×568 (bant+hata+Çal birlikte) ve yatay 640×360'ta satır TAM SIĞMAZ: kaydırılarak erişilir, Çal her boyutta tam ve ekranda.
- Gövde (nota/tab) görünür yüksekliği, bant+hata+raf varken: 360×640 ve 412×915'te ≥96 px; 320×568'de ve yatayda yalnız ≥16 px (ölçülen ~22–36 px): çalışır ama sınırlı kullanım, gövde kaydırılır. Sabitler: alt sabit alan en çok %85; yalnız ≤700 px'te Araçlar rafı %17 (bantla %10), bant %17 (daha küçük bant "Ayarlara git" bağlantısını gizledi, 05f testleri kırıldı); raf/bant sabitleri >700 px'te değişmedi; sabit alan dolgusu her boyutta daraldı (16,4,16,8→16,2,16,6; aralık 8→4), Çal ana dala göre ~2 px aşağıda.
- Scrim: katman açıkken tek erişilebilir "Kapat" düğmesi (`MaterialLocalizations.closeButtonLabel`, yeni metin YOK; `isButton`, `tap` + `dismiss`); ayrıca açık katmanı saran `container` düğümü `dismiss` taşır (satırdan yukarı ata zinciri); Cihaz ve Yol katmanında sınandı (Yol ata testi `stage-path-scroll` düğümüne dayanır); katman kapalıyken düğüm yok.
- Doğrulandı ama GERÇEK OLMAYAN riskler: Araçlar düğmesi, Yardım satırı, Hayalet seviye düğmeleri, Cihaz satırları (etiket+ipucu tek düğüm), bant (başlık+içerik) çift okuma. `stageMode:false` testi kırmızı olamaz (davranış değişmedi): koruma testidir.
- Test: `test/ux_05h1_a11y_test.dart` (A canlı bölge, B güvenlik satırı + koruma, C tek düğüm/Kapat/dismiss, D 14 dil, E sıkışık düzen). VoiceOver/TalkBack elle doğrulanmadı.
- Hata iletisi (`practice-failure`, sahnede gövdenin başında): yeni hata gelince gövde başa kayar (`ScrollController.jumpTo(0)`), ileti tek düğümlü canlı bölge; 360×640'ta ileti tam pencerede, 320×568'de yalnız başlangıcı (gövde ~35 px) — kalanı kaydırılır, ekran okuyucu tamamını okur.

## 05h-2 devir notları
- Kapandı (kalem 6 + yükleme): sahne yüklemesi `stageLoadTimeout` (10 sn, `const`) ile sınırlı; aşılırsa okuma hatasıyla aynı "yüklenemedi" durumu (sahne açık, tutamaklar duruyor, Çal pasif, "Tekrar dene"). İskelet tek düğüm "Yükleniyor…" (mevcut metin; yeni metin yok) taşır, Çal pasif. Hata: tek düğümlü canlı bölge `stage-load-error`; yeni metin "Your practice could not be loaded." / "Çalışman yüklenemedi." (14 dilde, id c0ca41654e6e1071, tablo 8800 → 8801). Geç dönen eski yükleme yeni sonucu ezmez (zaman aşımı sarmalayıcısı geç sonucu eler; testle sınandı). Zaman aşımına uğrayan `_load` İPTAL EDİLMEZ: arka planda bitene kadar koşar (yan etkisi yalnız `_ghostCatalog` atamasıdır, zararsız).
- Bulundu ve düzeltildi: `_retry` `setState(() => _data = ...)` ok işlevi Future döndürüyordu; debug/test modunda "setState() callback argument returned a Future" iddiası atıp "Tekrar dene" düğmesini kırıyordu (release'te iddia kapalı olduğundan çalışıyordu). Blok gövdeye çevrildi.
- Kanıtlandı (davranış değişmedi): kayıt yazma hatasında `PracticeLoopScreen._showResult` `record = null` yapar, sonuç ekranı "Bu sonuç cihaza kaydedilemedi." gösterir (`C3`). Yazım sessizce kaybolmuyor.
- Çevrimdışı — koddan çıkarım: sahnenin tek ağ bağımlılığı üyelik sorgusu (`hasPaidAccess`, yükte 4 sn sınırlı, hatada/zaman aşımında "üye değil" = ücretsiz ders; Çal'da `_admitPaid` hatada "Üyelik şu an doğrulanamadı…" bildirir, koşu başlamaz, yeniden denenebilir). Pratik, kulak, akort, kayıt, Yol yerel dosyadır, ağa gitmez. Hesap/üyelik sayfaları ve senkron Core/paylaşılan hesap koduna aittir (kapsam dışı). SocketException ile `D1–D3` sınandı. Sahte "çevrimdışı" metni EKLENMEDİ: mevcut "doğrulanamadı" ağ hatasını dürüstçe kapsıyor; "çevrimdışı" demek için bağlantı denetimi gerekir (yok; yeni özellik).
- Ölçüldü: 360×640 + yazı 1.3, 14 dilde iskelet, zaman aşımı ve hata durumu taşmaz; hata metni ve düğme ekran içinde, metin düğmenin üstünde (`E`).
- Açık: sahnenin yükleme hatası ile "ölçülen ders yok" (`_load` null) aynı durumu gösterir (ikincisi gerçekte olmaz; ayırt etmek istenirse ayrı bilet). Üyelik zaman aşımı (4 sn) yükte hâlâ sessizce ücretsiz dersi gösterir (05b2 kararı; kullanıcıya "üyelik doğrulanamadı" yükte söylenmez, yalnız Çal'da). Senkron/hesap yüzeylerinin çevrimdışı metni Core işidir. VoiceOver/TalkBack elle doğrulanmadı. Test: `test/ux_05h2_resilience_test.dart` (A yükleme, B zaman aşımı, C hata, D çevrimdışı, E 14 dil).
