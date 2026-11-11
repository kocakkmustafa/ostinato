# OST-UX-05b — Ölçüt tablosu (Sahne kabuğu ve kök değişimi)

Test dosyası: `test/stage_home_test.dart` (25 test). Bayrak: `ostinatoStageHomeEnabled = false` (`lib/app/ostinato_release_policy.dart`); bu bilet bayrağı ÇEVİRMEZ. Test ortamında AÇIK = kurucu parametresi (`OstinatoHome(stageHomeOpen: true)`).

| # | Ölçüt | Test adı (grup) | Sonuç | Kanıt yolu |
|---|---|---|---|---|
| 1 | Bayrak KAPALI: kök `LibraryScreen`; eski kök testleri geçer | `olcut1`: "the flag ships closed", "default (flag closed): the root is the library", "stageHomeOpen:false gives the library, no stage", "stageHomeOpen:true after the welcome: the stage", "...before the welcome: still the welcome" | Varsayılan false; false iken LibraryScreen, sahne/raf/sabit metronom yok; AÇIKken karşılamadan sonra sahne | Render: `evidence/ux-05b/07-eski-kok-acik.png`, `07-eski-kok-koyu.png` ("eski kök değişmedi") |
| 2 | AÇIK: `V1CourseState.next` dersi, yoksa ilk ölçülü ders; tek "Çal" | `olcut2`: "new user...", "returning user...", "no usable next lesson: the first measured lesson", "three text-labelled handles at 48 dp" | Yeni kullanıcı: "Yeni başlıyorsun"; devam var: "Devam: n. seviye, m. modül"; tek `practice-start` ("Çal", "Başlat" yok) | `01-sahne-yeni-kullanici-{acik,koyu}.png`, `02-sahne-devam-var-{acik,koyu}.png` |
| 3 | Tek dokunuşla pratik; mikrofon izni ilk Çal'da | `olcut3`: "no permission before Play; one request on the first tap" | Çal öncesi 0, ilk dokunuşta 1 izin isteği; oturum çalışıyor | — |
| 4 | Çalarken tutamak gizli, katman açılamaz; hatada ekran durmaz | `olcut4`: "handles hidden, no layer can open, budget refuses", "handles show and call the injected callback (default no-op)", "a failed start: the screen does not stop" | `GlassLayerBudget.playing=true`, `tryOpen` false, `openCount` 0; reddedilen izinde `practice-failure` görünür, sahne/Çal/tutamaklar yerinde | `03-calarken-{acik,koyu}.png` |
| 5 | Mevcut pratik çekirdeği değişmez | Mevcut `practice_*` testleri aynen (tam suit) | Tam suit: +2154 geçti (taban +2129 + 25 yeni), 0 başarısız, EXIT 0 | `ux05b-fulltest2.log` |
| 6 | Araç rafı: kapalı başlar, çalarken yok, tamamen opak, parçaları yeniden kullanır | `olcut6`: "starts closed; opens opaque with the reused parts", "closed while playing; cannot be opened...", "the loop switch drives the session controller"; bayrak KAPALI: `olcut1` | Raf `Material` alfa 1.0, altında `BackdropFilter`/`GlassLayer` 0; `MetronomeBeatView`, `ReferenceListenBar`, döngü anahtarı (aynı denetleyici); çalarken raf yok | `04-raf-kapali-*.png`, `05-raf-acik-*.png` |
| 6a | Sabitlenen metronom: çalarken görünür, opak, cam sayısına girmez; KAPALIyken yok | `olcut6a`: "visible while playing, opaque, outside the glass budget", "not pinned: no metronome strip while playing"; KAPALI: `olcut1` | `Material` alfa 1.0, BackdropFilter 0, `openCount` 0 (öncesiyle aynı) | `06-calarken-metronom-{acik,koyu}.png` |
| 7 | Geri: katman açıkken katmanı kapatır; çıkış ekranından sahneye döner; yarım koşu "tamamlanmadı = ölçülmedi", kayıt eklemez | `olcut7`: "a layer is open: back closes the layer...", "an exit screen: back returns to the stage", "leaving a half run: says not measured, records nothing" | Katman kapanır (`openCount` 1→0); çıkış ekranından sahne; yarım koşuda "Koşu tamamlanmadı: ölçülmedi, geçit kaydı yok." ve `recordRun` 0 çağrı, `load().length` aynı | — |
| — | l10n | `olcut5`: "every stage pair has a message id", "the new pairs are in all 14 catalogs and promise nothing" | 7 yeni çift; 14 katalog 8752 anahtar; `build_message_ids --check` rc 0 | `assets/l10n/*.json` |

## Değişenler
- Yeni: `lib/app/stage/stage_home_screen.dart`, `tool_shelf.dart`, `stage_copy.dart`; `test/stage_home_test.dart`; `tool/ux_05b_render_evidence_test.dart`; `evidence/ux-05b/*.png` (14); bu dosya.
- Değişen: `lib/main.dart` (`stageHomeOpen`, `stageHomeBuilder`), `lib/app/ostinato_release_policy.dart` (bayrak), `lib/app/practice/loop/practice_loop_screen.dart` (yalnız opsiyonel `stageMode`, `onController`, `listenController`; varsayılanlar davranışı değiştirmez), `lib/app/app_message_ids.dart` (+7), 14 katalog (+7), `test/app_locale_preferences_test.dart` (8745 → 8752), `docs/practice/copy/practice-loop.copy.json` (+"Play/Çal"), `test/glass_layer_test.dart` (olcut8 muafiyeti: yalnız `lib/app/stage/stage_home_screen.dart`).
- Dokunulmayan: UX-04 prototipi, `glass_layer.dart`, bağımlılıklar.

Tam suit: `/private/tmp/claude-501/-Users-mustafakaankocak-Developer-YULAlab-AI/762aeb32-3a3d-40a8-90aa-556ff9bb1d1a/scratchpad/ux05b-fulltest2.log` — `+2154: All tests passed!`, `EXIT 0`.

## Yorum gerektiren noktalar
- `next` ölçülü değil ya da ücretli kapsamdaysa: ilk açık, bitmemiş, ücretsiz ölçülü ders seçilir (ücretli koruma atlanmaz).
- Sahne kurulum sihirbazını (Ayar tutamağı = 05c/f) çalıştırmaz; tutamak geri çağrıları varsayılan no-op.
- Çalarken geri: koşu kaydedilmeden sonlandırılır (uygulamadan çıkmaz), metin gösterilir.
- Gömülü pratik ekranı kendi kaydırma alanında; küçük ekranda "Çal" kaydırma gerektirebilir (akort kartı + ayar kartı üstte).
- Yardım satırı yalnız yerini tutar (eylem yok).

## Açık noktalar (bayrak açılmadan önce)
- (a) Üye/ücretli kullanıcıda `next` dersi s2+ ise sahne ücretli dersi göstermez, ilk açık ücretsiz ölçülü dersi gösterir (`admitV1Lesson`/üyelik sorgusu yok). Ders bitince `_data` yeniden yüklenmez; sonuç ekranına `hasNextLesson` geçilmez.
- (b) 390x844'te "Çal" ilk ekranda yarı kesik (akort kartı + ayar kartı); raf açıkken pratik alanı ~160 dp ve "Çal" ekranda yok. Akort kartı sahne dışına ya da raf açıkken "Çal" sabit olmalı (ADR-UX-001 "Çal belirgin" niyeti). 360x640 ve büyük yazı ölçeğinde raf açıkken RenderFlex taşma riski doğrulanmadı; raf kaydırılabilir değil.
- (c) Rafta `ReferenceListenBar`, `hasPitches || isRhythmOnly` ve `Guide.referenceAudio` koşullarına bağlı değil. Döngü anahtarı yalnız 1-2. ölçüyü açar; `RangeSlider` `stageMode`'da yok.
- (d) Gömülü `PracticeLoopScreen`'deki eski `GlassCard` (`widgets.dart:39`) çalarken de `BackdropFilter` kullanır: 05h.
- (e) Yarım koşu sonrası sahne yeniden kurulur; akort kartı tekrar çıkar.
