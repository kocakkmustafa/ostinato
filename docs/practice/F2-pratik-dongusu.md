# F2.2–F2.5 — Pratik döngüsü

Durum: dal `feat/practice-loop`, **gerçek cihazda doğrulanmadı**; native kod
**derlenmedi** (makine yükü kuralı). Kaynak: `PLAN-ONERISI.tr.md` §2 F2, §7b;
ekran kararları `RAPOR.tr.md` (f), yerleşim `4-rakip-arayuzleri.md` §6.5–6.6.

## F2.2 Metronom

**Saf Dart başvuru:** `lib/app/practice/loop/metronome.dart`.

- `MetronomePlan`: vuruş `n` = akışın `n * framesPerBeat` numaralı örneği.
  `framesPerBeat` tam sayıya yuvarlanır (tempo hatası < %0,003); zaman
  çizelgesi aynı tam sayıyı kullandığı için ızgara ile akış hiç kaymaz.
- Klik: 6 kHz, zarflı kısa patlama (vurgu 22 ms / 0,8; vuruş 14 ms / 0,5).
  E50 M1 kararı: dedektör bandının (≤4 kHz) **üstünde** klik. Testte enerjinin
  >%97'si 6±1,5 kHz'de, `OnsetDetector` klik akışında hiç atak bulmuyor.
  Ders sözleşmesindeki "±15 ms onset maskesi" **uygulanmadı** (E49/E50:
  zamanında notayı siliyor).
- `ClickTrackRenderer`: sonsuz akışın herhangi bir aralığını üretir; native
  portların (iOS bar döngüsü, Android blok yazıcı) normatif karşılığı.
- `MetronomeTimeline`: vuruş ↔ ölçüm saati (`AudioChunk.tStartUs` ile aynı
  saat). `anchorUs + outputLatencyUs + latencyCorrectionUs` = duyulan vuruş.
  `latencyCorrectionUs` F4.2 kalibrasyonundan gelir (rota başına
  gidiş-dönüş − `outputLatencyUs`, `calibrated` bayrağı); kalibrasyon yokken
  zamanlama öğrenciye gösterilmez (rozet: "Zamanlama için kalibrasyon yap").
- `MetronomeBeatState`: görsel vuruş + ön sayım (1–2 ölçü).
- `CaptureClockEstimator`: parçalar arasında "şimdi"yi ölçüm saatinde tahmin
  eder, geri gitmez.
- `MetronomeBeatView`: ölçü başına nokta, vurgu büyük; ön sayımda sayı.

**Native akış (F2.1 deseni):** arbiter'a yeni sahip yok; akış çal+dinle
denemesinin içindedir, yakalamayı kapatan her yol (durdurma, arka plan, rota,
kesinti, motor değişimi) akışı da durdurur.

| | iOS | Android |
|---|---|---|
| Yöntem | Ayrı `AVAudioPlayerNode`, tek ölçülük tampon `.loops`, `play(at: hostTime)` | Yazıcı iş parçacığında sürekli 256 örneklik bloklar (`MetronomeStreamRenderer`) |
| Çapa | `play(at:)` host zamanı (yakalama ile aynı saat) + `outputLatency` ayrı alan | `AudioTrack.getTimestamp` → frame 0'ın sunum zamanı (`System.nanoTime`) |
| İpucu (`playCue`) | Ayrı düğüm, karışır | Metronom çalarken kuyruğa **eklenmez**, akışa **karıştırılır** (ekleme sonraki klikleri kaydırırdı) |
| `playbackActive` | Klik işaretlemez (bant dışı); ipuçları işaretler | Aynı; karışan ipucu bitişi + 300 ms |

Tel: `startMetronome {attemptId, sampleRate, framesPerBeat, beatsPerBar,
accent, beat, leadInMs}`, `stopMetronome {attemptId}`; olay
`{type: metronomeAnchor, attemptId, anchorUs, sampleRate, framesPerBeat,
outputLatencyUs}`. Hata kodları ipucu kodlarıyla aynı; metronom hatası
yakalamayı durdurmaz. Native yoksa ya da çapa gelmezse pratik **sessiz
ızgarayla** (`MetronomeAnchorSource.silent`) sürer: görsel vuruş ve ölçüm
çalışır, klik duyulmaz.

**Derlenmedi:** `ios/Runner/AudioCaptureStreamer.swift`,
`ios/Runner/PracticeAudioArbiter.swift` (`outputLatencySeconds`),
`android/.../MetronomeStream.kt`, `PracticeDuplexAudio.kt`,
`AudioCaptureCoordinator.kt`, `AudioCaptureStreamer.kt`.

**Cihazda doğrulanacak:**
1. 6 kHz klik telefon hoparlöründen yeterince duyuluyor mu (bazı küçük
   hoparlörlerde zayıf olabilir); kulaklıkta rahatsız edici mi.
2. iOS: çalışan motora düğüm bağlamak (`attach/connect` çalışırken) rota
   bildirimi üretiyor mu (üretirse arbiter oturumu kapatır).
3. iOS: `play(at:)` host zamanı + `outputLatency` gerçek duyulma anına ne
   kadar yakın (E50 kalibrasyonu farkı ölçecek).
4. Android: `getTimestamp` ilk geçerli değere ne zaman ulaşıyor; yakalama
   zaman damgası (`System.nanoTime - okunan süre`) ile aynı saat mi, sapma ne.
5. Android: 256 örneklik blokla alt akış (underrun) oluyor mu. Olursa
   sonraki klikler kayar; yazıcı çapayı ~2 sn'de bir yeniden ölçer ve 1 ms'den
   büyük farkta yeni `metronomeAnchor` gönderir (Dart en sonuncuyu kullanır).

## F2.3 Akan notasyon

- `practice_score.dart`: `practice.sequence` ayrıştırıcı. Perde (`E2`,
  `C#4:h`), ritim (`q h. ee qr h~q`), derece (`1-3-5`), ölçü öneki (`3/4:`),
  `×N` tekrar. Her `|` parçası sonraki ölçü çizgisinde başlar (gitar
  dersindeki `E2 F2 G2 F2 E2 | …` iki ölçü olur). Yazılmış bütün v1 dersleri
  ayrıştırılıyor (testte denetlenir).
- Tab konumu: standart akort, sesli perde; 0–4. perdeler içinde en düşük
  perde (önce boş tel), yoksa en düşük perde.
- `practice_transport.dart`: ders vuruşu `L = m − ön sayım − kaydırma`.
  Döngü (ölçü aralığı) her turda notaları yeniden bildirir; "Beni bekle"
  notada durur, duyulunca bir sonraki notayı **sonraki bir klike** oturtur
  (ızgara bozulmaz). Tempo: hedefin %40–120'si, açılış tempo varsayılan,
  ±5 BPM merdiveni.
- `practice_tab_strip.dart`: sabit ŞİMDİ çizgisi, notalar akar; tab'da 1. tel
  üstte. Farklı notada duyulan konum hayalet ◆ olarak kendi telinde.
  Ekran okuyucu: "Şimdi: Fa2, 1. perde, 6. tel". Gitar dışı dersler için tek
  çizgili ritim şeridi (ses/piyano rulosunun temeli).
- Tema kancası (F2.7 için): `PracticeVisualTheme(leftHanded, colorBlindSafe)`
  + `PracticeVisualThemeScope`. Durumlar şekil + renk + etiket: dolu daire ✓,
  eşkenar dörtgen ◆, kesik çizgili daire ?. Kırmızı yok (testte denetlenir);
  renk körü paleti mavi/turuncu/gri. Solak modu şeridi yatay aynalar (ŞİMDİ
  çizgisi sağda). Ayarlara bağlanması F2.7'nin işi.

## F2.4 Doğrulayıcı bağlantısı

- `practice_judge.dart` (saf): `CaptureBuffer` (yalnız RAM, ~8 sn, temizlikte
  sıfırlanır), 6 kHz kliği dışarıda tutan süzgeç (4,8 kHz 4. derece alçak
  geçiren + 6 kHz çentik; testte klik ≥20 dB bastırılıyor), `judgeNote`.
- Kurallar: pencerede atak yoksa **duyamadım** (sessizlik asla "doğru"
  değil); pencerede `playbackActive` varsa **duyamadım / uygulama sesi**
  (düşük güven, hüküm yok); perde notaları `GuitarNoteVerifier`'a (atak
  `AttackLocator` ile, beklenen zamana en yakın); şüphe "duyamadım"a düşer.
  Ritim notaları atak varlığıyla; derece notaları (ses) bu turda motor yok →
  duyamadım.
- Pencere: beklenen (duyulan) zamanın −160/+260 ms'i, komşu notaya olan
  aralığın yarısını aşmaz; analiz notanın içinde kalır (en çok 320 ms).
  Gecikme kalibrasyonu yokken zamanlama hükmü verilmez, gösterilmez.
- "Beni bekle": nota tutulur, son 1,5 sn'deki en yeni atak dinlenir; doğru
  gelince bırakılır. İlk kesin sonuç (doğru ya da farklı) kaydedilir.
  4 sn → ipucu balonu, 8 sn → [Atla] [Bu notayı dinle]; kilit yok.
  "Bu notayı dinle" beklenen notayı cihazda sentezler (tel modeli; kayıt
  değil) ve `playCue` ile çalar; çaldığı sürece ölçüm düşük güvenlidir.
- `HearingMonitor`: mikrofon şeridi (Sessiz / Seni duyuyorum / Duyuyorum ama
  ayırt edemiyorum), oda tabanı ön sayımdan (medyan), üst üste 3 "duyamadım"
  ya da 8+ notada >%25 → kurulum kartı; kapatılınca 5 dk tekrar etmez.
- `practice_session_controller.dart`: çal+dinle yakalama, metronom akışı,
  çapa (1,2 sn içinde gelmezse sessiz ızgara), taşıyıcı, analiz kuyruğu
  (üretimde `Isolate.run`), rota/saat değişiminde tur iptal
  (`input_changed`). Tur sonunda `activeDuration` (dinleme süresi) tutulur.
- `PracticeSessionFinished` (`practice_outcome.dart`): seri/haftalık hedef
  (PR #12) için "oturum bitti" olayı: `lessonId`, `course`, `activeDuration`,
  `heardEvents` (duyamadım hariç), özet. Bu dal yalnız olayı verir; PR #12'ye
  bağımlılık yok.
- Akort kapısı (sözleşme §5 kural 2) bu döngüde **yok**: F4.1 akort ekranı
  ayrı iştir; doğrulayıcı ±50 c toleransla çalışır.

## F2.5 Sonuç ekranı ve geçiş kapısı

- `practice_outcome.dart`: ✓/◆/◯ sayaçları; **doğruluk = doğru / (doğru +
  farklı)** ("duyamadım" paydada yok), **duyulma = (doğru + farklı) / tümü**.
- Kapı şemadaki `pass`'tan: `levelDefault` → sözleşme §6.2 seviye doğruluğu
  (S1 %80, S2–S3 %85, S4 %90) + duyulma ≥%80 + hedef tempo; `minCorrect`
  varsa ek koşul; özel kural metni (`levelDefault: false`) ekranda aynen
  gösterilir, makinece denetlenen kısmı seviye varsayılanı + `minCorrect`'tir.
  `expertPending` ise "eşikler öğretmen incelemesi bekliyor" yazar.
- Kapı yalnız **tam tek turda** ölçülür: döngü, "Beni bekle" ya da yarıda
  durdurma → "Pratik turu" (sayaçlar var, kapı yok).
- **Tempo (F4.2 turunda düzeltildi, sözleşme §6.3):** açılış temposunda (ya
  da üstünde) geçiş sıradaki dersi açar; hedef tempoda geçiş dersi
  "tamamlandı" yapar; açılışın altı pratiktir. `M!` dersleri yalnız hedef
  tempoda geçer. Ayrıntı: `F4.2-kurulum-sihirbazi.md`.
- Önerilen tek adım: geçti → "Sonraki derse geç"; duyulma düşük →
  "Kurulumu kontrol et" ("Puanın değil, mikrofonun takıldı…"); doğruluk
  düşük → "Bu ölçüleri %70 tempoda döngüle"; tempo altında → "+5"; pratik
  turu → "Tüm diziyi hedef tempoda çal".
- Hata haritası: ölçü başına işaretler; ölçüye dokununca o ölçü döngülenir;
  farklı notalarda "Fa2 duydum · Sol2 bekleniyordu ↑".
- `practice_progress_store.dart`: hesap başına yerel dosya
  `v1_practice_progress.v1.json`, `evidence: measured_practice` (gitar
  yolculuğunun öz beyan deposundan ayrı; ona dokunulmadı). Yalnız sayılar;
  ses yok. Açma kuralı: sıradaki ilk ders açık; her ders öncekinin ölçülen
  geçişiyle açılır. Geçişte "Sıradaki ders açıldı" ve doğrudan açılır.
- `v1_practice_catalog.dart` + `pubspec.yaml`: `content/v1/gtr/` paketlendi;
  katalog M/M! + perde dizisi olan gitar dersleri (bugün 1 ders:
  `gtr-s1-m02-02`; sıradaki ders yazılınca kendiliğinden kilitli görünür).
- Giriş: gitar yolculuğu ekranında "Ölçülü pratik" kartı → ders listesi →
  pratik ekranı (`practice_loop_screen.dart`: tempo, döngü, Beni bekle, klik
  sesi, akan tab, görsel vuruş, mikrofon şeridi + sayaçlar, kurulum kartı,
  bekleme balonu) → sonuç.
- **Tam gitar kursu (2026-11-02, `feat/v1-full-guitar-course`):** liste artık
  240 gitar dersinin tamamını seviye → modül → ders olarak gösterir
  (`v1_course_catalog.dart`). Her ders bu sürümdeki durumuna göre sınıflanır:
  ölçülü (A2/A3 tek nota dizisi → pratik ekranı), akort aleti (yalnız A1),
  öz-kontrol (`M` ama motor/dizi yok: A4 akor, A5 bend/vibrato, teknik yazımı,
  ritim-yalnız ya da dizisiz), öz-kontrol dersi (`Ö`), kamera kontrol listesi
  (`K`), ekran alıştırması yakında (`D`), bekletilen geçiş (`M!` ölçülemiyor).
  Ölçülü olmayanlar ders okuyucusunda açılır (`v1_lesson_reader_screen.dart`);
  öz-kontrol tamamlaması `v1_lesson_checks.v1.json`a `self_report` olarak,
  akort dersi `tuner_check` olarak yazılır (ölçülen pratik dosyasından ayrı).
  Açma kuralı sözleşme §6.4/§9: modülün ilk dersi önceki modülün geçiş
  dersiyle açılır, modül içi kilit yok; bekletilen geçiş öz-kontrolle
  çalışılınca sonraki modül **"ölçülmedi"** etiketiyle açılır (§4.2'deki
  seviye testi kuralının modül geçişine uygulanması). Eski ölçülü
  ilerlemesi olan modül açık kalır.
- Seri/haftalık hedef (PR #12) için `onSessionFinished` →
  `PracticeSessionFinished(lessonId, course: guitar, activeDuration,
  heardEvents, summary)`; bağlantıyı iki dal birleşince Yönetim yapar.

## Metinler

Yeni kullanıcı metinleri `localized(context, en, tr)` ile; liste
`docs/practice/copy/practice-loop.copy.json` (86 çift; senkronu
`test/practice_copy_test.dart` denetler). Kimlik tablosuna **eklenmedi**:
mevcut test (`app_locale_preferences_test`) tablodaki her kimliğin 14
katalogda da olmasını şart koşuyor. 81 metin yeni; 12 dilde (ar, de,
es-419, fr, hi, id, it, ja, ko, pl, pt-BR, zh-Hans) **81 metin eksik**, o
dillerde şimdilik İngilizce görünür. Çeviri adımı:
`python3 tool/build_message_ids.py --pending docs/practice/copy`, sonra
`--add` ve 12 katalog.
