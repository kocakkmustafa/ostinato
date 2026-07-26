# Ostinato G4-Hazırlık — `cello@0.1.0-draft` Rule-Set Config Taslağı

**Tarih:** 2026-07-26 · **Statü:** TASLAK — hiçbir sayısal eşik nihai değil (`"expertPending": true` = çello öğretmeni doğrulaması şart, plan §16). Amaç: G4 motorunun yorumlayacağı config'in ŞEKLİNİ şimdi kilitlemek (versiyonlu-config ilkesi; içerik=paket, kod değil) + aile kurallarını (K8 · M-F-06/07/08/09 · guidance-hypothesis) yapıya gömmek.
**Tüketici:** çekirdek rule-set MOTORU (motion_core, kanonik Dart); bu dosya modül İÇERİĞİ (`modules/cello` paketi — ADR-001 §2.3).

```json
{
  "schemaVersion": "ostinato-ruleset-1",
  "module": "cello",
  "version": "0.1.0-draft",
  "provenanceRequired": ["modelVariant", "modelSha256", "rulesetVersion", "metricsConfigVersion", "calibrationProfileId"],

  "setupGate": {
    "hardInModes": ["assessment", "technique_drill"],
    "advisoryInModes": ["guided_practice"],
    "checks": ["framing_full_body_bow", "camera_angle_within_band", "lighting_floor", "audio_noise_floor_calibrated", "instrument_detected"],
    "note": "M-F-09: ölçüm modlarında sihirbaz geçilmeden analiz BAŞLAMAZ; serbest-pratikte uyarı bandı."
  },

  "sideIdentity": {
    "policy": "geometric_after_structural_clean",
    "note": "M-F-06: model left/right etiketine ham güven YOK; yay-eli/sol-el ayrımı kalibrasyon pozunda geometrik kurulur, StructuralValidator temiz değilken taraf raporlanmaz."
  },

  "scoreDisplay": {
    "numericScoresEnabled": false,
    "bandsUntilCalibration": ["steady", "improving", "needs_focus"],
    "note": "K8/M-F-04: kalibrasyon kapısı geçilmeden kullanıcıya SAYISAL skor gösterilmez; V1 Review = bant + eğri + süre."
  },

  "feedbackPolicy": {
    "maxConcurrentCues": 1,
    "priorityOrder": ["riskClass1", "riskClass3", "riskClass4"],
    "suppression": { "consecutiveOutOfBandBeforeCue": { "value": 3, "expertPending": true }, "cooldownSec": { "value": 20, "expertPending": true } },
    "fading": { "enabled": true, "note": "İlerledikçe cue sıklığı azalır (guidance hypothesis, pedagoji §3.4); takvim uzman-sonrası" },
    "noJudgeWindows": ["attack_ms_after_onset", "direction_change_window"],
    "childSessionCapMin": { "value": null, "expertPending": true, "note": "session_duration_cap_child — sayı uzmandan (pedagoji §5.7)" },
    "language": { "positiveFraming": true, "externalFocusPreferred": true, "bannedWordsList": "copy/wellness-banned.en.json (Lissom süzgeci deseni devralınır)" }
  },

  "rules": [
    { "code": "E-BOW-SKEW", "riskClass": 3, "v1": true, "observe": "camera",
      "metric": "bow_bridge_parallelism_deg",
      "toleranceProfile": "perString", "expertPending": true,
      "hardDependency": "toleranceBand",
      "suppressWhen": ["shortArm_A_string_extremes"],
      "note": "GÜVENLİK ŞARTI (O-009): bandsız/sabit-açı fallback ÜRETİME GİDEMEZ; kısa-kollu/çocuk + A-teli fixture'ı zorunlu test." },
    { "code": "E-BOW-REGION-DRIFT", "riskClass": 3, "v1": true, "observe": "camera",
      "metric": "contact_point_drift_ratio", "expertPending": true },
    { "code": "E-BOW-SHORT", "riskClass": 3, "v1": true, "observe": "camera",
      "metric": "bow_range_utilization_pct", "expertPending": true },
    { "code": "E-BOW-BUMPY-CHANGE", "riskClass": 3, "v1": true, "observe": "fusion",
      "metric": "direction_change_x_sustain_gap_ms", "expertPending": true,
      "note": "Ayırt edici füzyon bulgusu: kamera yön-değişimi × ses sürekliliği ARALIK kesişimi (tek-saat sözleşmesi)." },
    { "code": "E-ELBOW-BAD-HEIGHT", "riskClass": 3, "v1": true, "observe": "camera",
      "metric": "right_elbow_height_vs_phase", "toleranceProfile": "perStringPerPhase", "expertPending": true },
    { "code": "E-POST-SLOUCH", "riskClass": "1_if_sustained", "v1": true, "observe": "camera",
      "metric": "trunk_axis_deviation_deg", "sustainedSecForClass1": { "value": null, "expertPending": true } },
    { "code": "E-POST-HEAD-FWD", "riskClass": "1_if_sustained", "v1": true, "observe": "camera",
      "metric": "head_shoulder_alignment", "expertPending": true },
    { "code": "E-POST-SHOULDER-RAISE", "riskClass": "1_if_sustained", "v1": true, "observe": "camera",
      "metric": "shoulder_height_delta_norm", "expertPending": true },
    { "code": "E-POST-FEET", "riskClass": 3, "v1": true, "observe": "camera", "metric": "feet_ground_contact", "expertPending": true },
    { "code": "E-POST-CELLO-POS", "riskClass": 3, "v1": true, "observe": "camera",
      "metric": "instrument_bbox_torso_relation", "expertPending": true,
      "note": "Endpin-türevli açı AYRI ve v1:false (pedagoji §2.1 bölünmesi — kalibrasyonsuz hüküm sorusu uzmanda)." },
    { "code": "E-LH-WRIST-COLLAPSE", "riskClass": "1_if_sustained", "v1": true, "observe": "camera",
      "metric": "left_wrist_angle_deg", "expertPending": true },
    { "code": "E-LH-ELBOW-LOW", "riskClass": 3, "v1": true, "observe": "camera", "metric": "left_elbow_height", "expertPending": true },

    { "code": "E-POST-ENDPIN", "v1": false, "reason": "kalibrasyonsuz anlamsız — uzman sorusu §5.8" },
    { "code": "E-BOW-STEAK-KNIFE", "v1": "candidate", "reason": "hand-landmark güvenilirliği V0 benchmark'ına bağlı; plan §8 kapsam sorusu uzmanda (§5.9)" },
    { "code": "E-BOW-PINKY-COLLAPSE", "v1": "candidate", "reason": "aynı" },
    { "code": "E-BOW-FIST", "v1": "candidate", "reason": "aynı" },
    { "code": "E-LH-POSITION-DRIFT", "v1": "candidate", "reason": "fingerboard algılama olgunluğuna bağlı" },
    { "code": "E-BOW-DEATH-GRIP", "v1": false, "reason": "basınç görünmez — dürüstlük ilkesi (✗)" },
    { "code": "E-LH-THUMB-SQUEEZE", "v1": false, "reason": "başparmak çello arkasında — görünmez (✗)" }
  ],

  "audio": {
    "pitchSource": "abstracted (PitchSource: YIN-native | SwiftF0-ONNX — G4 kararı, G1-C: ikisi de eşik-içi)",
    "expectedNotePrior": true,
    "confidenceGates": { "snrFloorCalibrated": true, "attackNoJudgeMs": { "value": 100, "expertPending": false, "note": "G1-C ölçüm temelli başlangıç; fixture'la ayarlanır" } },
    "latencyCalibration": "consume motion-core audio-latency module (M-F-08) — route-başına; kendi implementasyon YOK"
  }
}
```

## Açık uçlar (bu taslağı nihaileştirecek girdiler)
1. Uzman turu (G1-B görüşmelerinden çıkan öğretmen + pedagoji §5 soruları) → tüm `expertPending` alanlar.
2. ReferenceBuilder pilotu (B3 ölçütü) → tolerans bantlarının veri-türevli kısmı (`CanonicalReference.toleranceAt` ile eğitmen-varyansından).
3. Çekirdek rule-set motoru şema sözleşmesi (koordinatör; M-O-01 talebi) → alan adları/formatın çekirdekle hizalanması. Bu taslak ŞEKİL önerisidir; çekirdek şeması farklıysa çekirdek kazanır.
