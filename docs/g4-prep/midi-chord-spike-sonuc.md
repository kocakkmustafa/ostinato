# MIDI-girişli akor tanıma spike'ı — sonuç (M-F-103)

**Tarih:** 2026-07-29 · **İstek:** koordinatör, `open_chord_drill`e MIDI-girişli alternatif yol fizibilitesi (M-O-33'ten beri bekleyen soru, kromagram spike'ıyla lisans bacağı kapandıktan sonra sıradaydı).

## Sonuç özet

**Teknik olarak triviyal, ürün önceliği olarak DÜŞÜK** — donanım hedef kitleye ulaşmıyor.

## 1. Teknik fizibilite — ÇÖZÜLDÜ, 8/8

`packages/ostinato_audio/lib/src/harmony/midi_chord_detector.dart`: kromagram
detektörünün (`ChordDetector`) AYNI `ChordTemplate` sözlüğünü (E A D G C Am
Em Dm) tüketir, ikinci bir akor tanımı icat etmez. Fark: kromagram
sinyaldeki BELİRSİZLİĞİ yönetir (harmonik sızıntı, oktav karışıklığı,
gürültü tabanı) — MIDI'de bu belirsizlik YOK, hex-pickup'lı bir MIDI
gitarda her tel ayrı bir MIDI notası üretir, hangi perdenin basıldığı
DOĞRUDAN veridir. Detektör bu yüzden gürültü-payı yerine TAM KAPSAMA oranı
kullanır (`minCoverage: 0.75`).

**Kanıt (gerçek MIDI nota numaralarıyla, standart EADGBE akort E2=40
A2=45 D3=50 G3=55 B3=59 E4=64, standart açık-pozisyon parmak dizilişi,
müzik teorisiyle çapraz kontrollü):**

| Akor | Perde dizilişi | MIDI notaları | Sonuç |
|---|---|---|---|
| E | 022100 | 40,47,52,56,59,64 | ✅ |
| A | x02220 | 45,52,57,61,64 | ✅ |
| D | xx0232 | 50,57,62,66 | ✅ |
| G | 320003 | 43,47,50,55,59,67 | ✅ |
| C | x32010 | 48,52,55,60,64 | ✅ |
| Am | x02210 | 45,52,57,60,64 | ✅ |
| Em | 022000 | 40,47,52,55,59,64 | ✅ |
| Dm | xx0231 | 50,57,62,65 | ✅ |

8/8 doğru, tam skor (1.0 — DSP tahmini olmadığından skor bir olasılık değil
bir kapsama oranı). Sınır durumları da doğru reddediyor: boş küme · tek nota
(kapsama 1/3) · yabancı nota (yanlış tel/perde — "yaklaşık doğru" SAYILMAZ,
extra nota varsa 0 puan) · eksik nota (kapsama eşiğin altında) · göreli
majör/minör (Am↔C) karışmıyor (paylaşılan notalar C/E, ayırt edici G/A
yine de doğru okunuyor). 6/6 test yeşil, `dart analyze` temiz.

## 2. Donanım gerçekliği — ARAŞTIRILDI, ÜRÜN ÖNCELİĞİNİ BELİRLEDİ

MIDI gitar girişi gerektiren donanım (WebSearch, 2026-07-29):

- **Fishman TriplePlay** — kablosuz hex-pickup + alıcı, ~$220-400.
  Köprüye monte edilir, kuruluma ihtiyaç var.
- **Roland GK-3 / GK-5** — dijital pickup, GR serisi dönüştürücüyle
  birlikte kullanılır, benzer fiyat aralığı.

İkisi de "yazılım enstrümanı kontrol et, DAW'a MIDI kaydet, notasyon
üret" hedefli pazarlanıyor — yani **kompozisyon/prodüksiyon kullanıcısı**,
`open_chord_drill`in hedef kitlesi (AÇIK AKOR ÖĞRENEN YENİ BAŞLAYAN) DEĞİL.
Beginner-sahiplik oranına dair veri bulunamadı (arama sonuçlarında yok) —
ama bu niş/pahalı/kurulum-gerektiren donanımın yeni başlayan bir gitaristte
bulunma ihtimali yapısal olarak düşük: $200-400 ek yatırım + montaj,
"ilk üç ay içinde temel akorları öğrenen" profiliyle uyuşmuyor.

## Karar önerisi (uygulanmadı, koordinatöre/kurucuya bırakıldı)

Kod ÜCRETSİZ tutulabilir (120 satır, mevcut `ChordTemplate` sözlüğünü
reuse ediyor, bakım yükü düşük) — MEVCUT donanıma sahip ileri-seviye
kullanıcı için opsiyonel bir yol olarak paket içinde durabilir. Ama:

- **Varsayılan/birincil yol OLMAMALI** — kromagram (ses) zaten "engine"
  durumunda ve gerçek kullanıcı donanımına (telefon mikrofonu) dayanıyor.
- **Pazarlama/UI'da öne çıkarılmamalı** — "MIDI gitarınla da çalışır"
  notu yeterli, "MIDI moduna geç" akışı kurmaya değmez (kimse geçmeyecek).
- Dördüncü/beşinci canlılık sorusu bağlamında: bu, "teknik olarak
  kusursuz ama gerçek kullanıcıya ulaşmayan özellik" sınıfının erken
  teşhisi — inşa ETMEDEN önce yakalandı, inşa ettikten SONRA değil.

## Kayıt

DEFTER: M-O-33 (Basic Pitch lisans sorusu, artık tamamen kapalı — kromagram
yetti) · M-O-34 (flutter_midi_command BSD-temiz) · bu turun bulgusu ayrı
girdi olarak DEFTER'e.

**Kaynaklar:**
[Fishman TriplePlay — Sweetwater](https://www.sweetwater.com/store/detail/TriplePlayPU--fishman-tripleplay-wireless-midi-pickup/reviews) ·
[Roland GK2 — Equipboard](https://equipboard.com/items/roland-gk2-midi-pickup) ·
[MIDI Guitars & Pickups — Sweetwater](https://www.sweetwater.com/c593--MIDI_Guitars_and_Pickups)
