# 🚪 Ostinato G1/D3 Kapı Raporu — Kurucu Tek-Sayfa

**Tarih:** 2026-07-26 (gece oturumu) · **Kapı tanımı:** D3 — V0 = veri protokolü + öğretmen/B2B kanal doğrulaması, KOD DEĞİL. **Derin yatırım kararı B2B sinyaline bağlı** (00-AILE §3-D3).

## Durum özeti

| Parça | Durum | Kanıt |
|---|---|---|
| **A — Veri toplama protokolü** | ✅ TASARIM HAZIR → onayın + pilot bekliyor | `data-collection-protocol.md`: 6 sınıf + süperset yay etiketi (OK-1), 60-klip çeşitlilik matrisi, TR rıza formları (çocuk rejimi: yüz-bulanıklaştırma zorunlu, tanıtım-rızası çocukta YOK — OK-2) |
| **B — Öğretmen/B2B paketi** | ✅ HAZIR → görüşmeler SENİN bacağın | `teacher-channel-validation.md`: Mom-Test kılavuzu (25-30dk), tek-sayfa EN+TR, skor kartı S1-S6, **ölçüm-öncesi eşikler** (OK-3): GÜÇLÜ ≥%60 S1+S2 & ≥3 pilot & ≥1 B2B → derin yatırım; ZAYIF → PARK |
| **C — Ses ön-ölçümü** | ✅ **ŞARTLI GEÇTİ** (OK-5) → retrospektif onayın | `tech-premeasure-report.md`: YIN/pYIN/SwiftF0 × sentetik(120)+gerçek çello(Iowa 48 segment): med ≤19¢, oktav ~%0, telefon-mikrofon simülasyonuna dayanıklı; SwiftF0 lisansı MIT doğrulandı (O-003 KAPANDI) |
| **C — Kamera ön-ölçümü** | ⏳ protokol hazır → CİHAZ testi senin bacağın (~30-45dk) | rapor §2: MediaPipe örnek app'leri, eşikler ölçüm-öncesi yazıldı (OK-4: kombine ≥15fps → canlı akış) |

## Beyaz alan (konumlandırma) — CANLI DOĞRULANDI
Mağazada kamera+postür yapan müzik pratik uygulaması YOK (8-ajanlık canlı tarama). Yousician keman desteğini bile listeden çıkarmış; Trala keman-only/kamerasız; Tonara kapanmış. Tek yakın şey: **Purdue "Cello Evaluator" araştırma prototipi** (MediaPipe+YOLOv11, mağazada değil) → çeyreklik izlemede (O-008). Detay: `../research/2026-07-26-g0-canli-dogrulama.md`.

## Senden beklenenler (sıralı)
1. **OK-5 retrospektif onay** — ses bacağı "şartlı geçti" (gece protokolü).
2. **G1-B eşik onayı** (§4.2) → sonra 8-12 öğretmene davet mesajı (şablon pakette) → görüşmeler.
3. **G1-A protokol onayı** → pilot çekim (~yarım gün, 6 klip; sen + tripod + telefon).
4. **Cihaz fps testi** (~30-45dk; iPhone + orta-segment Android; adımlar rapor §2'de).
5. **URMP izin maili** gönderimi (taslak: `urmp-permission-email.md`; muhatap Zhiyao Duan).
6. **Git push onayı**: `feat/g0-g1-kickoff` (3 yerel commit) + main'deki roadmap commit'i (`cf5a9f5`).
7. (Eski gündem) Domain: getostinato.app — M-006.
8. ~~M-017 ana kararı~~ ✅ VERİLDİ (2026-07-26): **Dart `motion_core` kanonik** (84/84 test; StructuralValidator + ReferenceBuilder dahil); Python hatları yalnız video→fixture aracı. Ostinato'ya işlendi: ADR-001 güncellendi, O-010 daraldı, OK-8 yorumu deftere yazıldı. Kalan artık: JabLab Python araçları birleştirmesi (aile listesinde).
9. **YENİ — OK-8 retrospektif onayı:** §6.0'ın Ostinato uygulaması — bowing skorlama referansları kamu eğitmen videolarından (≥3, ReferenceBuilder); **detector eğitim verisi kendi çekimlerimizde KALDI** (§6.0 kapsam dışı sayıldı — kamu-video kareleriyle ship-edilen model eğitilmez). Bu ayrımı onaylıyor musun, yoksa detector eğitiminde de kamu videosu kullanımını hukuk görüşüne mi taşıyalım?

## Kapı hükmü
G1 **kurucu-bacağı beklemede**: teknik ön-koşullar yeşil; karar verisi (öğretmen görüşmeleri) sahadan gelecek. Görüşmeler bitince skorları derleyip kapı değerlendirmesini birlikte yaparız — **derin yatırım kararı o toplantının çıktısı** (O-001 kapanış yolu). Beklerken oturum kapıya-bağımlı-olmayan hattan ilerliyor (ses fixture tasarımı ✅, sınır-çizgisi ADR taslağı ✅, TR pedagoji taraması koşuyor).
