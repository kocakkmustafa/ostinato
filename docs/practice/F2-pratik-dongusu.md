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
  `latencyCorrectionUs` F4.2 kalibrasyonundan gelecek; sıfırken zamanlama
  öğrenciye gösterilmez (rozet: "Zamanlama için kalibrasyon yap").
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
