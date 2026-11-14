# Bayrak öncesi kontrol listesi (05h-3)

Bayraklar `ostinatoStageHomeEnabled` ve `ostinatoGhostScreenOpen` KAPALI. Bu liste bayrağı açmaz. Durum: KAPALI (çözüldü) · AÇIK · KURUCU (karar bekler). Kaynak: `04-backlog-ux-05.md` devir notları ve vault Görev Panosu.

| # | Nokta | Durum | Kaynak / not |
|---|---|---|---|
| 1 | 05b2 (i): Çal'da üyelik yeniden doğrulama | KAPALI (05c `beforeStart`, fail-closed) | 05c notu |
| 2 | 05b2 (ii): güvenlik satırı 360×640 + 1.3 + raf | KISMİ (05h-1 ölçüldü; hata mesajı gövdede, elle doğrulanmadı); 320×568 ve yatayda tam sığmaz, kaydırılır | 05h-1 |
| 3 | 05b2 (iii): mikrofon reddi sonrası akort kartı / "Ayar" yolu | KAPALI (05f) | 05f |
| 4 | 05c Tur 2 A: `_starting` sıfırlama testi yok, guard hiç dönmezse ÇAL sessiz | AÇIK | `05c-olcut-tablosu.md` Tur 2 |
| 5 | 05c Tur 2 B: oturum içi / yeniden açılış öneri satırı `passed` farkı | AÇIK (05d'ye devredilmişti; kapandığı doğrulanmadı) | aynı |
| 6 | 05c Tur 2 E: başlık oturum içinde güncellenmez | AÇIK | aynı |
| 7 | 05c: gerçek `openTuner` / `_earScreen` taklit | AÇIK (`NOT_TESTED`) | 05c notu |
| 8 | 05d: Core `requirePaidAccess`/`coreGate` zaman aşımsız (`MOTION-CORE-ZA-01`) | KURUCU | Görev Panosu 2026-11-11 |
| 9 | 05d: Yol/Geçmiş testleri uygulama sonrası yazıldı (sabotajla kırmızı) | KAPALI (bilinen sapma, kayıtlı) | Görev Panosu |
| 10 | 05f: Ayar/Cihaz katmanı 14 dil taşması | KAPALI (05h-1) | 05h-1 |
| 11 | 05g D4 Ek B (kapsam ima eden metin) | KAPALI (metin düzeltildi, test eklendi) | Görev Panosu 2026-11-12 |
| 12 | `ghost_store.dart`: bekçi `RETENTION_WRITERS` uzlaştırma, `deleteAccountData` bağı | AÇIK (karar kayıtlı; bu bilette yeniden doğrulanmadı) | Görev Panosu 2026-11-12 |
| 13 | 05g2/05g3: raf ↔ pratik uyumu (`preStartPreview`, `label`, `metronome`/`hint` kaldırıldı) | KAPALI (05g3) | 05g notları |
| 14 | `hint` ürün kararı: yardımlı koşunun ölçümdeki anlamı | KURUCU | 05g ADR |
| 15 | Kulak/ritim-only Hayalet'e girmez (ADR) | KAPALI (karar) | 05g ADR |
| 16 | 05e2: NextStep kısmi veriden öneri (eski akış) | AÇIK | 05g notu |
| 17 | Sahne yükleme hatası ile "ölçülen ders yok" aynı durum | AÇIK (ayrı bilet) | 05h-2 |
| 18 | Üyelik zaman aşımı yükte sessizce ücretsiz ders gösterir | KURUCU (05b2 kararı) | 05h-2 |
| 19 | Senkron/hesap yüzeylerinin "çevrimdışı" metni | AÇIK (Core işi) | 05h-2 |
| 20 | Ayarlar bayrakları (#70 OST-P0-06, #71 OST-P0-08) notları | AÇIK: bu bilette içerikleri okunmadı; Motion orchestration kontrol etmeli | Görev Panosu satır 41, 77–80 |
| 21 | Gerçek cihaz (kare süresi, bulanık katman; izin reddi "Başlat") | AÇIK (`NOT_TESTED`) | backlog satır 28, 89 |
| 22 | Ekran okuyucu (VoiceOver/TalkBack) elle doğrulama | AÇIK (yapılmadı) | 05h-1/05h-2 |
| 23 | T13 "ekran hatada durmaz": çalışırken hata testi yok | AÇIK | `INDEX.md` |
| 24 | 360×640 yazı 2.0'da sahne 30 px sağa taşar (gerçek ölçüm, ölçek uygulandığı kanıtlı) | AÇIK (BULGU, 3 test `skip`) | `ux_05h3_hardening_test.dart` |
| 25 | Eski `GlassCard` sahnede 4 `BackdropFilter` çizer (çalarken dahil) | AÇIK (ölçüldü, kararsız; değişiklik 05h-3 kapsamı dışı) | `INDEX.md` |
| 26 | Bekçi 14 dil: `assets/l10n/*.json` bekçi tarafından taranmıyor; 12 dilde 795 desen eşleşmesi | KURUCU/Motion: sınıflandır (`scratch/2026-11-14-ostinato-05h3/l10n-promise-hits.tsv`) | 05h-3 |
| 27 | İnsan kullanıcı testi | YAPILMADI (bilet kapsamı dışı) | kalem 9 |
