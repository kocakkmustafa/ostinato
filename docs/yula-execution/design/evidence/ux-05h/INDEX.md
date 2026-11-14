# OST-UX-05h kanıt dizini (T1–T14)

Kaynak senaryolar: `04-design.md` bölüm 13. Her satır, senaryonun kabul sonucunu sınayan mevcut/yeni test. Dosya yolları `test/` altındadır. T12 (erişilebilirlik) tek test değil; aşağıda ayrı bölüm.

| T | Senaryo | Test (dosya: ad) | Not |
|---|---|---|---|
| T1 | Pratiğe başlama | `stage_home_test.dart`: `no permission before Play; one request on the first tap` · `new user: next lesson, one Play, "just starting" line` | |
| T2 | Enstrümansız çalışma | `ux_prototype_test.dart`: `two taps reach the ear mode; no microphone, not counted` · `stage_home_test.dart`: `criterion 4: ear opens in two taps; the tuner opens full screen and back returns to the stage` | Gerçek `_earScreen`/`openTuner` taklit (05c notu) |
| T3 | Öğrenme yolculuğu | `ux_prototype_test.dart`: `level, module list and the next module with its reason` · `stage_home_test.dart`: `olcut1: levels and modules equal the catalog; …` | |
| T4 | Hatayı anlama | `ux_prototype_test.dart`: `different note, where, one correction, no verdict word` · `practice_result_test.dart`: `Turkish copy: different note, heard low, never "wrong"` | |
| T5 | Aynı bölümü tekrar | `ux_prototype_test.dart`: `Try again returns to the same section, ready` · `ux_05e_result_layer_test.dart`: `retry keeps the loop bars; a bar tap sets the loop` | |
| T6 | İlerleme geçmişi | `ux_prototype_test.dart`: `runs side by side, heard percent on its own line` · `stage_home_test.dart`: `olcut3: history shows the stored bests side by side, heard apart from accuracy; …` | |
| T7 | İzin yok | `ux_prototype_test.dart`: `listening-off mode: still playable, ear and setup reachable` · `a run with listening off is not measured and says so` · `ux_05f_listening_off_test.dart`: `05f-1a: denied -> "Dinleme kapalı" (tr)` | Sahne yolunda "ölçüm yok" kısmı yalnız prototipte sınanıyor |
| T8 | Kamera yok | `ux_05f_camera_zero_test.dart`: `05f-3b: stage + refusal asks for the camera 0 times` · `05f-3a: the camera flags ship closed` | |
| T9 | Hayalet, güvenilmez ölçüm | `ux_05g_ghost_stage_test.dart`: `05g-4: esik-1 / bagimsiz basamak: oneri YOK` · `05g-5: olculmeyen son kosu: "olculmedi", yetkinlik metni yok` | |
| T10 | Güvenilmez ölçüm | `ux_05e_result_layer_test.dart`: `unclear pitch: ◯ and its reason, nothing marked wrong` · `ux_prototype_test.dart`: `an unreliable run says it could not hear, gives no percent` | |
| T11 | Kulak ≠ enstrüman | `ux_05g_ghost_policy_test.dart`: `05g-7: kulak kosusu (course ear / ear-s id) Hayaleti etkilemez` · `ux_05g_ghost_run_test.dart`: `05g-int: kulak kosusu (ear) Hayaleti etkilemez` | |
| T12 | Erişilebilirlik | aşağıya bak | Tek test değil, kayıtlı el kontrolü gerekir |
| T13 | Çalarken | `ux_05g_ghost_stage_test.dart`: `05g-8: calarken raf/yardim yok; ayar degismez` · `ux_prototype_test.dart`: `one tap on Play; no handle, layer or glass while playing` | **EKSİK:** "ekran hatada durmaz" için çalışırken hata enjekte eden test yok (`stage_home_test.dart`: `a failed start: the screen does not stop` yalnız başlatma hatası). Eklenmedi; FLAG-CHECKLIST'te açık |
| T14 | Yarım koşu | `ux_05g_ghost_policy_test.dart`: `05g-5: yarim/dongulu kosu notMeasured; gecmeyen notCounted` · `ux_prototype_test.dart`: `stopping early is not measured` | |

## T12 (kalem 1–4 + el kontrolü)
- Kalem 1 (sıra, canlı bölge, tek düğüm, Kapat/dismiss): `ux_05h1_a11y_test.dart` (A–E).
- Kalem 2 (büyük metin 2.0): `ux_05h3_hardening_test.dart`: `05h-3 d` (yazı 2.0 uygulandığı testte assert edilir; mutasyon 1.0'da kırmızı: `d-mutation-scale1.txt`). 390×844 üç katman GEÇER. **360×640 üç test BEKLENEN-BAŞARISIZ (`skip`): sahne yazı 2.0'da 30 px sağa taşar** (`d-real-scale2.txt`); kaynak widget bulunamadı. Önceki tur-1 "sahte bulgu" notu geçersiz: asıl hata testin 1.0'da koşmasıydı, taşma gerçek.
- Kalem 3 (≥ 48 dp): ayrı bu bilette yeniden sınanmadı (05h-1 kapsamı).
- Kalem 4 (hareketi/saydamlığı azalt): aynı `05h-3 d` testleri `disableAnimations + highContrast` ile: katman tek karede açılır ve ek `BackdropFilter` eklemez. Sahnede eski `GlassCard` zaten 4 `BackdropFilter` çizer (SessionTuningGateCard vb.); ölçüldü, değiştirilmedi.
- Gizli şerit yer tutucusu: `ux_05h3_hardening_test.dart`: `05h-3 a …`.
- Kayıtlı el kontrolü (VoiceOver/TalkBack): **YAPILMADI.**

## Kalem 9
**Kullanıcı testi (insan) yapılmadı.** Bu bilet Aşama 6 prototipidir.
