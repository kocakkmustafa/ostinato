# OST-UX-05c ölçüt tablosu (bayrak KAPALI; `ostinatoStageHomeEnabled` false, açılmadı)

Test dosyaları: `test/stage_home_test.dart` (gruplar `05c layers`, `05c ek i`, `05c ek c`), `test/stage_suggestion_test.dart`, `test/ux_05c_render_evidence_test.dart`. PNG: `docs/yula-execution/design/evidence/ux-05c/` (`UX_RENDER=1` ile yazılır; yalnız `01-katman` ve `03-akort` içerik kanıtıdır; `02-kulak` PNG'leri gerçek kulak listesinin yükleme anını gösterir, liste içeriği NOT_TESTED).

| # | Ölçüt | Test (dosya) | Kırmızı kanıt | Sonuç | Ekran |
|---|---|---|---|---|---|
| 1 | İkinci katman birinciyi kapatır; GlassLayer <= 2 | `criterion 1: a second layer closes the first; glass <= 2` (stage_home_test) | Derleme kırmızısı (StageLayerManager yoktu); sabotaj: yöneticideki `_open.clear()` satırı çıkarılınca `Expected: [path] Actual: [other, path]` kırmızı, geri konunca yeşil | yeşil | - |
| 2 | Katman <= %60, üst şerit >= %40 (360x640, 412x915) | `criterion 2: ...` x2 (stage_home_test); render testi içinde de assert | İlk koşuda ölçüm katmanın dış Align kutusunu aldı (640 > 384), katman gövdesine (FractionallySizedBox) düzeltildi | yeşil | 01-katman-390x844/360x640-acik/koyu |
| 3 | Öneri satırı deterministik, kayıt yoksa gizli, >= 5 durum | `stage_suggestion_test.dart` (5 test) + `criterion 3: suggestion line shows only with records` | Derleme kırmızısı (dosya yoktu); yeşil 5/5 + widget | yeşil. `missFromSummary` için birim test YOK (PracticeRunSummary kurulumu ağır), yalnız koddan | 01-katman (öneri satırı görünür) |
| 4 | Kulak <= 2 dokunuş; Akort tam ekran, geri = sahne, koşu/durum bozulmaz | `criterion 4: ear opens in two taps; the tuner ...` | Derleme kırmızısı (`earScreenBuilder/tunerOpener` yoktu) | yeşil (test saplama ekranla; gerçek TunerScreen cihazda NOT_TESTED) | 02-kulak (yükleme anı), 03-akort |
| 5 | Gitar ve kulak açık; "Yakında" çalgılar mevcut kural | `criterion 5: guitar and ear are open; ...` | Derleme kırmızısı | yeşil (diğer çalgı -> `ComingSoonInstrumentScreen`) | 01-katman |
| 6 | Odak: açılınca ilk öğe, kapanınca tutamak | `criterion 6: focus goes into the layer, back to the handle` | Derleme kırmızısı; ilk koşuda odak yardımcısı hatalıydı, düzeltildi | yeşil (`Semantics.focused` değil, birincil odak düğümü) | - |
| 7 | Çalarken tutamak/katman açılmaz | `criterion 7: while playing nothing opens ...` + 05b `olcut4` testleri | Derleme kırmızısı | yeşil | - |
| ek c | ReferenceListenBar koşulu; RangeSlider rafta; varsayılan 1-2 | `05c ek c` (4 test) | 2 kırmızı (derece dizisinde bar görünüyordu; `stage-loop-range` yoktu) | yeşil | - |
| ek i | ÇAL'da `admitV1Lesson` yeniden doğrulanır | `05c ek i` (4 test) | 3 kırmızı (guard hiç sorulmuyordu) | yeşil. Fail-closed: hata -> koşu başlamaz. Zaman aşımı: guard `admitV1Lesson`dır (üyelik sayfası açabilir), bu yüzden zaman aşımı konmadı | - |
| l10n | 4 yeni çift, 14 katalog | `olcut5 copy and l10n` (2 test), `app_locale_preferences_test` 8756 | İlk koşuda kırmızı (id/katalog yoktu) | yeşil; `build_message_ids.py --check` rc=0 | - |

Cihaz ölçümü (TalkBack/VoiceOver odak, gerçek Akort): NOT_TESTED.
Eski testte değişiklik: `handles show and call the injected callback` tutamak sırası (katman tutamakları örter), `seen.toSet()` karşılaştırması.
Worktree notu: `assets/models/pose_landmarker_full.v1.task` testlerin derlenmesi için kopyalandı (gitignored, diff'te yok).
