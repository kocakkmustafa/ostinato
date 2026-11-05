# YULAlab — yerel Codex girişi

Önce [ortak bağlam girişini](../../../AGENTS.md), ardından [bu reponun tek yerel ürün/güvenlik kaynağını](CLAUDE.md) oku. CLAUDE.md içindeki yerel bilgiler Codex ve Claude için aynıdır; teknik yöntemi model seçer, dosya işlem yetkisi üretmez.

Bu bölümler Codex ve diğer kod ajanları içindir; kısa tutulur. Çelişkide CLAUDE.md doğrudur.

## Yığın
- Flutter (stable) / Dart `^3.11.0`; Supabase istemcisi (`supabase_flutter`). Durum yönetimi: yok; `ChangeNotifier`/`ValueNotifier`.
- Alt paketler: `packages/ostinato_audio`, `packages/ostinato_posture`. Ortak altyapı Motion Core'dan (git pini) gelir.
- Kurulum: `flutter pub get` · Analiz: `flutter analyze` · Test: `flutter test`
- Alt paket testleri: `(cd packages/ostinato_audio && flutter test)` ve `(cd packages/ostinato_posture && flutter test)`.
- CI'daki doğrulayıcılar (`.github/workflows/checks.yml`): `python3 tool/build_message_ids.py --check`, `python3 tool/curriculum_lint.py --check`, `python3 tools/validate_privacy_manifest.py`, `python3 tools/validate_surface_honesty.py`.

## Kurallar
- **Minimal diff:** yalnız istenen dosyalara dokun; biçimlendirme ya da yeniden adlandırma turu yapma.
- Yerelleştirme: metinler `assets/l10n/<dil>.json` (14 katalog); anahtar, EN+TR kaynak çiftinin message id'sidir. Yeni UI metnini id'ye bağla, 14 kataloğa çevirisiyle ekle; ardından `python3 tool/build_message_ids.py --check` geçmeli. Tek yerelleştirme mekanizması bu JSON katalogları ve message id tablosudur.
- Testler: uygulama testleri `test/*_test.dart`, alt paketlerde `packages/*/test/`, betik testleri `tool/test_*.py` ve `tools/test_*.py`. Yeni davranışa test ekle; mevcut testi silme ya da atlatma.
- Kullanıcıya "yanlış/wrong" gösterilmez. Düşük güvende hüküm verilmez; tıbbi iddia yoktur; ham video cihazda kalır (CLAUDE.md).
- Bitirmeden: analiz ve test temiz olmalı; çıktının son 5 satırını rapora koy.
- Ağır yerel kapılar (`core.hooksPath` ayarlıysa) atlanmaz; `--no-verify`, force push ve bypass yok.

## Dokunulmaz
- Sır dosyaları (`.env*`, anahtarlar, `~/.secrets`), imzalama yapılandırması, fiyat/abonelik kimlikleri, Supabase göçleri ve şeması — yalnız açık talimatla.
- Mağaza meta verisi ve sürüm numarası (`pubspec.yaml` `version`) — yalnız açık talimatla.
- Motion Core pini (`pubspec.yaml` ve alt paketlerdeki git `ref`) — yalnız açık talimatla; pin güncellemesinde Core PR'ı normal merge commit ile alınır (squash yasak).
- Kamera ve sürüm bayrakları (`lib/app/ostinato_release_policy.dart`: `ostinatoCameraLessonsOpen`, `ostinatoCameraPracticeAvailable`, `ostinatoMotionPlusOffered`) açılmaz.
- Kayıtlı ders içeriği ve ders sırası (`content/`) — yalnız açık talimatla.
- Burun Farkı ve Iron Bank projelerine dokunulmaz.
