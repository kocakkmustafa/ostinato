# D8 — İkon adayları (2026-08-16, O-158)

**Aile dili:** tek-renk zemin + tek beyaz glif (`YAYIN-YOLU-OSTINATO.md`:
*"lacivert zemin + beyaz glif (metronom/nota silueti)"*). Zemin: `#161C38`.

| Aday | Glif | Not |
|---|---|---|
| `A-note.png` | Çeyrek nota | Talimatın harfi harfine karşılığı; bayraklı (eighth-note) biçim küçük ikonda dengesiz çıktı, bayraksız çeyrek notaya sadeleştirildi |
| `B-metronome.png` | Metronom silueti | Talimatın ikinci seçeneği; temiz, tanınır, ama jenerik — sayısız pratik/metronom uygulaması aynı motifi kullanıyor |
| `C-posture-CHOSEN.png` | **SEÇİLDİ** — Ostinato'nun kendi postür figürü | Onboarding'de ZATEN kullanılan motifin AYNISI (omuz-gövde-kalça çizgisi + baş) — jenerik "müzik" değil, Ostinato'nun asıl farkı (postür) ile birebir |

## Neden C

Talimat "metronom/nota silueti" ÖNERİYORDU, KESİN ŞART koymuyordu. C, kendi
üründe zaten var olan bir görsel dili (bu turda çekilen `docs/store/
screenshots/`da her onboarding ekranında görünür) tekrar kullanıyor —
kurumsal kimlik + ürün-içi tutarlılık ikisi birden. A/B talimata daha
literal sadık alternatifler olarak burada duruyor; kurucu takas hakkını
saklı tutuyor (`orkestratör, D8 mesajı`).

**Uygulanan:** iOS AppIcon (15 dosya) + LaunchImage (3 dosya, storyboard
`backgroundColor`ı da navy'ye çevrildi) + Android `ic_launcher` (5 yoğunluk)
+ Android `launch_background.xml` (2 varyant, yeni `launch_image.png` +
`colors.xml`). Kanıt: `tools/validate_template_assets.py` — 25/25 varlık
Flutter'ın stok görsellerinden MD5-farklı, `run_gates.sh`a kalıcı gate
olarak eklendi.
