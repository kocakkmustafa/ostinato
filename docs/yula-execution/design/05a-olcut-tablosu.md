# OST-UX-05a — Ölçüt tablosu (Glass çekirdeği)

Test dosyası: `test/glass_layer_test.dart` (29 test, hepsi geçer). Bileşen: `lib/app/design/glass_layer.dart`. Bayrak yok; hiçbir mevcut ekran kullanmaz.

| # | Ölçüt | Test adı (grup) | Sonuç | Kanıt yolu |
|---|---|---|---|---|
| 1 | En çok 1 bulanık yüzey; çalarken 0 | `olcut1`: "two open layers draw one BackdropFilter", "playing: zero blur and zero glass items", "a layer mounted while playing stays empty" | 2 açık katman = 1 BackdropFilter; `playing=true` = 0 BackdropFilter, 0 cam öğe, yeni açma reddedilir | `test/glass_layer_test.dart` |
| 2 | En çok 2 cam öğe; 3. reddedilir | `olcut2`: "budget: third tryOpen returns false, first stays", "widgets: third layer renders nothing" | Davranış sabit: üçüncü istek REDDEDİLİR (`tryOpen` false), birinci kapanmaz; monte katman bekleyen istektir: slot boşalınca (`review fixes`: "rejected third layer is admitted when a slot frees") ve oynatma bitince ("playing true -> false: mounted layer comes back") yeniden kabul edilir; "unmount returns the slot", "budget swap closes the slot on the old budget" | `test/glass_layer_test.dart` |
| 3 | Saydamlık azalt = opak; hareket azalt = anlık | `olcut3`: normal, highContrast, injected reduceTransparency, disableAnimations, motion on (220 ms) | highContrast ve enjekte `reduceTransparency` = alfa 1, blur yok; `disableAnimations` = opaklık 1 ilk karede | Render: `docs/yula-execution/design/evidence/ux-05a/01-acik-normal.png`, `02-acik-azaltilmis.png`, `03-koyu-normal.png`, `04-koyu-azaltilmis.png` (prototip/test render; `tool/ux_05a_render_evidence_test.dart`) |
| 4 | Kontrast metin ≥ 4.5, bileşen ≥ 3, en kötü arka plan | `olcut4`: light/dark × opaque/translucent (4 test) | Hepsi geçer (siyah ve beyaz uç arka plan; metin 5 renk, onPrimary/primary, primary/controlBorder/outline/focus) | `test/glass_layer_test.dart`; görsel: yukarıdaki 4 PNG (siyah-beyaz şerit arka plan) |
| 5 | Sigma ≤ 16, alan ≤ %60 | `olcut5`: "sigma <= 16 and area <= 60%", "area fraction is clamped to the ceiling" | sigma 12 (tavan 16), alan 0.6, alfa 0.94; 1.0 istenirse 0.6'ya kırpılır | `GlassLayerConfig` sabitleri |
| 6 | Düşük donanım: bütçe aşımı = blur kapanır, opak kalır | `olcut6`: "monitor latches after N consecutive slow frames", "monitor reads FrameTiming build + raster", "over budget: blur closes, layer stays, opaque" | ilk 30 kare yok sayılır (`warmupFrames`), sonra 8 ardışık kare > 20 ms = kalıcı bayrak (sıfırlanmaz); bayrakla 0 BackdropFilter, katman görünür, alfa 1 ("over budget: layer is fully opaque, no blur", "monitor ignores the warm-up frames", "monitor registers and unregisters the timings callback") | `test/glass_layer_test.dart` |
| 7 | Gerçek cihazda kare süresi | — | `NOT_TESTED` (neden: cihaz/kurucu gerekli, BLOCKED_ACCESS) | — |
| 3a | Erişilebilirlik (A) | `review fixes`: "semantics: container with caller label; none when closed" | Semantics container + çağıranın etiketi; blur yokken aynı; oynatmada düğüm yok | `test/glass_layer_test.dart` |
| 8 | Bayrak yok; mevcut ekran kullanmaz; GlassCard testleri geçer | `olcut8`: "only its own file references glass_layer" | lib/ altında 0 başka dosya içe aktarır; tam suit: +2129 geçti, 0 başarısız, EXIT 0 (`ux05a-fulltest3.log`) | `test/glass_layer_test.dart`, `/private/tmp/claude-501/-Users-mustafakaankocak-Developer-YULAlab-AI/762aeb32-3a3d-40a8-90aa-556ff9bb1d1a/scratchpad/ux05a-fulltest3.log` |

## Değişenler
- Yeni: `lib/app/design/glass_layer.dart` (`GlassLayer`, `GlassLayerBudget`, `GlassLayerConfig`, `FrameBudgetMonitor`, `TimingsFrameBudgetMonitor`)
- Yeni: `test/glass_layer_test.dart`
- Yeni: `tool/ux_05a_render_evidence_test.dart`, `docs/yula-execution/design/evidence/ux-05a/*.png` (4)
- Yeni: bu dosya
- Dokunulmayan: UX-04 prototipi (`ux_glass_layer.dart` aynen), `GlassCard`, l10n, bağımlılıklar.
- Not: iOS "Reduce Transparency" Flutter'da ayrı sinyal değil; `MediaQuery.highContrast` + enjekte edilebilir `reduceTransparency` girdisi kullanıldı.
