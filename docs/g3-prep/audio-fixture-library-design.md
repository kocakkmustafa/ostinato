# Ostinato G3-Hazırlık — Ses Fixture Kütüphanesi Tasarımı (v1)

**Tarih:** 2026-07-26 · **Statü:** TASARIM (G3'ün ses yarısının reçetesi; üretim kodu yok — implementasyon G3/G4'te)
**Bağlayıcı girdiler:** audio-dsp reference §8 (üç katman + metrikler) · motion-core katalog §6 fixture sözleşmesi · G1-C ön-ölçüm bulguları (`../g1/tech-premeasure-report.md`) · plan §16 test stratejisi.
**İlke:** Ses motoru fixture'ları KAMERADAN BAĞIMSIZ yeşile çekilir (Ostinato stratejisinin temeli — roadmap G3.1); her fixture üretim boru hattıyla birebir aynı formatta yürür.

---

## 1. Fixture şeması (somutlaştırma — audio-dsp ref §8 üstüne)

```json
{
  "schemaVersion": "ostinato-audiofix-1",
  "fixtureId": "AF-###",
  "kind": "synthetic | real-clean | real-target",
  "audio": "AF-###.wav",                     // 48kHz mono float32; kaynak stereo ise L+R mix
  "recordingMeta": {
    "source": "generated | iowa-mis-2012 | own-recording",
    "device": null, "room": null, "micDistanceM": null,   // real-* için zorunlu
    "license": "generated | Iowa-without-restrictions | own-consent-C###"
  },
  "expected": {
    "f0Hz": 65.406,                          // sabit-nota fixture'ları için
    "noteEvents": [{"tStart": 0.5, "tEnd": 2.4, "midi": 36, "f0Hz": 65.406}],
    "clickTimes": [0.0, 0.5, 1.0],           // metronom-hiza fixture'ları için
    "onsetTimes": [0.52, 1.03],
    "silences": [{"tStart": 2.4, "tEnd": 2.9}],
    "shouldJudge": true                       // false = güven kapısı SUSMALI (negatif fixture)
  },
  "tolerances": { "centsMedian": 25, "centsP95": 60, "onsetMs": 50, "octaveRate": 0.05 },
  "labels": { "annotator": "synthetic|manual", "confidence": "high|medium" }
}
```

Şema kararları:
- `shouldJudge:false` NEGATİF fixture sınıfı: düşük SNR / konuşma / başka enstrüman / TTS-koç-sesi-karışması kayıtları — motorun HÜKÜM VERMEMESİ gereken durumlar. False-judgment oranı = 0 şartı buradan test edilir (audio-dsp ref §8 metriği). Pozitif doğruluk kadar önemli.
- Toleranslar fixture-içinde: eşik değişimi = şema-versiyonlu veri değişikliği, kod değişikliği değil (versiyonlu-config ilkesi).
- `midi` + `f0Hz` birlikte: 12-TET dışı referans (447Hz akort vb.) ileride desteklenebilsin diye f0 esas, midi kolaylık.

## 2. Katman planı ve ilk set (hedef: ~40 fixture)

| Katman | İçerik | Adet | Kaynak/reçete |
|---|---|---|---|
| **L1 sentetik** | 4 açık tel × {temiz, vibrato, SNR10, SNR0, hp120, hp120+SNR10} | 24 | `bench_pitch.py`'deki üretici (harmonik seri + yay-atağı + gürültü) fixture-üreticiye dönüştürülür; ground-truth kusursuz |
| **L2 real-clean** | Iowa MIS arco ff: 4 açık tel + her telde 2 ek nota (kromatik +1/+2) | 12 | `bench_real.py` segmentasyon reçetesi (highpass-segmentasyon dersi UYGULANIR); etiketler G1-C ölçümünden tohumlanır, elle doğrulanır |
| **L3 negatif** | konuşma (TTS örneği) · oda gürültüsü · iki-nota-aynı-anda (çift tel) · seviye-yetersiz | 4+ | shouldJudge:false; TTS örneği kendi sistem-TTS çıktımızdan (koç-sesi-karışması gerçek senaryosu) |
| **L4 real-target** (G1-A pilotu sonrası) | kendi çekimlerimiz: oda yankısı + uzak mikrofon + pp dinamik + acemi cızırtısı | pilot→+8 | G1-C §1.4 kalan risklerin kapatıcısı; rıza-temiz |

## 3. Metronom-hiza fixture alt-seti

- Click-track üretimi sentetik (bilinen `clickTimes`), üstüne L1/L2 nota sesi mikslenir; `onsetTimes` kayması bilinçli parametre (0ms / +30ms / +80ms / rushing-pattern / dragging-pattern).
- Metrik: tespit-edilen-onset ↔ en yakın click sapma histogramı; tolerans `onsetMs` fixture-içi.
- Yaylı yumuşak-onset gerçeği (audio-dsp ref §4): recall değil HİZA metriği esas — "onset kaçırdı" tek başına kırmızı değil; `shouldJudge` mantığı segment-düzeyinde.

## 4. Koşum sözleşmesi (G4'te CI'a girecek)

1. Replay harness fixture klasörünü tarar → her fixture için motor çıktısı ↔ `expected` karşılaştırması → tek JSON rapor (`fixture-report.json`).
2. Yeşil tanımı: tüm `shouldJudge:true` fixture'larda tolerans içi + tüm `shouldJudge:false` fixture'larda hüküm sayısı 0.
3. Motor koduna dokunan her değişiklik ses seti koşar (kamera setinden bağımsız — hızlı kalır, <30sn hedef).
4. Fixture EKLEME serbest, DEĞİŞTİRME şema-versiyon artırımı ister (geriye-uyum: eski motor eski setle yeşil kalmalı).

## 5. Sonraki adımlar (kuyruk)

- [ ] G3 açılınca: L1 üreticisini fixture-üretici olarak yaz (bench_pitch.py'den türet) + L2 segment/etiket çıkarımı + L3 kayıtları.
- [ ] TTS-karışması fixture'ı için sistem-TTS örneği üret (G6 sesli-koç hattıyla ortak).
- [ ] `PitchSource` soyutlamasının test arayüzü bu şemayı doğrudan tüketecek şekilde tasarlanır (G4 ADR'ine not).
