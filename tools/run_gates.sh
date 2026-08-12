#!/usr/bin/env bash
# Ostinato'nun TÜM kapıları, tek komut. Repo kökünden koşulur.
#
# Neden var: kapılar bugüne dek PROGRESS notlarından elle toplanıyordu. Bir
# kapı listeye yazılmayı unutulduğu an sessizce ölür — ve tam da "her şey
# yeşil" denen turda ölür. Koordinatör MOCORE regen'i sonrası eşiklerin
# yeniden teyidini istedi (2026-08-04); teyit tek komut olmazsa, yapılmaz.
#
# derive_posture_thresholds.py --check bu listenin KİLİT TAŞI: referans
# artefaktı yeniden üretildiğinde (regen) config'in hâlâ o artefaktla aynı
# sayıyı söylediğini sınar. Regen sonrası tek yapılacak: bu betiği koş.
set -uo pipefail
cd "$(dirname "$0")/.."

# Kendi-kurulum (A5, koordinatör sevki 2026-08-11): bu betik depoda İZLENİYOR
# ama onu commit'ten önce ÇAĞIRAN şey izlenmiyordu — kapı yalnız bu makinenin
# alışkanlığındaydı, taze klonda sıfırdı. Bu betik zaten her oturumda elle
# koşulduğu için kendi git-hook'unu burada, ilk koşumda, sessizce kurar.
# Farklı bir core.hooksPath ZATEN ayarlıysa EZİLMEZ — yalnız uyarılır.
_hooks_path="$(git config --get core.hooksPath || true)"
if [ -z "$_hooks_path" ]; then
  git config core.hooksPath tools/git-hooks
  printf '⚙️  core.hooksPath → tools/git-hooks (ilk koşum, commit kapısı otomatik kuruldu)\n'
elif [ "$_hooks_path" != "tools/git-hooks" ]; then
  printf '⚠️  core.hooksPath zaten "%s" — Ostinato commit kapısı KURULMADI (çakışmayı önce çöz)\n' "$_hooks_path"
fi

# build/ kendi-kurulumu (koordinatör sevki 2026-08-11 — üç hatta birden P0):
# bu sembolik bağlantı ESKİDEN İZLENİYORDU, makineye-özgü mutlak yol taşıyordu
# (başka makinede taze klon = sarkan bağlantı = flutter test tool-crash =
# ÜRÜN kusuru sanılan kapı kırmızısı). Artık izlenmiyor (.gitignore); her
# koşum kendi yerelini kurar/onarır. M-F-444: "ortam yok" ne sessizce
# atlanır ne opak kırmızıya düşer — ADIYLA söylenir.
_build_target="$HOME/ostinato_buildout/app"
if [ -L build ]; then
  if [ ! -e "$_build_target" ]; then
    # sembolik bağlantı VAR ama hedefi SARKMIŞ — onarımı SESSİZCE yapma,
    # ADIYLA söyle (M-F-444: onarım da bir durum değişikliğidir).
    mkdir -p "$_build_target"
    printf '⚙️  build hedefi eksikti (ORTAM TUZAĞI), onarıldı → %s\n' "$_build_target"
  fi
elif [ -e build ]; then
  printf '⚠️  ORTAM YOK: "build" beklenmeyen bir GERÇEK dizin/dosya (sembolik bağlantı değil) — elle çözün, otomatik kurulum ATLANDI\n'
else
  mkdir -p "$_build_target"
  ln -s "$_build_target" build
  printf '⚙️  build → %s (ilk koşum, iCloud dışı yerel kuruldu)\n' "$_build_target"
fi

fail=0
run() {
  local name="$1"; shift
  printf '\n──── %s\n' "$name"
  if "$@"; then
    printf '   ✅ %s\n' "$name"
  else
    printf '   ⛔ %s BAŞARISIZ\n' "$name"
    fail=1
  fi
}

run "ruleset şeması + linter"        python3 tools/validate_ruleset.py
run "kütüphane dürüstlük kuralları"  python3 tools/validate_library.py
run "içerik-atıf süpürmesi"        python3 tools/validate_references.py
run "START HERE şeridi (türetim)"    python3 tools/validate_starters.py
run "starter kapısı öz-testi"        python3 tools/validate_starters.py --selftest
run "koşum envanteri (kapsam)"       python3 tools/validate_runner_inventory.py
run "gizlilik manifesti ↔ kod"       python3 tools/validate_privacy_manifest.py
run "gizlilik kapısı öz-testi"       python3 tools/validate_privacy_manifest.py --selftest
run "release imzası (sessiz düşme)"  python3 tools/validate_release_signing.py
run "imza kapısı öz-testi"           python3 tools/validate_release_signing.py --selftest
run "çalışma-anı çekmesi (görünür)"  python3 tools/validate_runtime_fetch.py
run "çekme kapısı öz-testi"          python3 tools/validate_runtime_fetch.py --selftest
run "MUT-A (kapılar ısırıyor mu)"     python3 tools/gate_mutation_test.py
run "MUT-A log öz-testi (doluyor mu)" python3 tools/gate_mutation_test.py --selftest-log
run "pozitif ikiz (kapı desenleri)"   bash -c 'python3 tools/validate_surface_honesty.py --selftest && python3 tools/validate_color_tokens.py --selftest'
run "yüzey dürüstlüğü (vaat+yetenek)" python3 tools/validate_surface_honesty.py
run "renk token kapısı"               python3 tools/validate_color_tokens.py
run "kapsam-dışı listesi (türetim)"   python3 tools/gen_out_of_scope.py --check
run "öksüz-anahtar + şema sürümü"     python3 tools/validate_orphan_keys.py
run "canlı yüzey sözleşmesi"       python3 tools/gen_posture_contract.py --check
run "eşik türetimi (artefakt↔config)" python3 tools/derive_posture_thresholds.py --check
run "gözlem işareti sözleşmesi"     python3 tools/validate_observation_cues.py
run "uzman-bekleyen envanteri"        python3 tools/gen_expert_inventory.py
run "placeholder kaydı"               python3 tools/gen_placeholder_register.py --check
run "gezilebilirlik aday kümesi"     python3 tools/gen_screen_candidates.py --check
run "aday-kümesi öz-testi"           python3 tools/gen_screen_candidates.py --selftest
run "kapalı yol (iki yön)"           python3 tools/validate_closed_paths.py
run "kapalı yol öz-testi"            python3 tools/validate_closed_paths.py --selftest
run "DEFTER tazeliği"                python3 tools/defter_freshness.py
run "tazelik kapısı öz-testi"        python3 tools/defter_freshness.py --selftest
run "yer tutucu ↔ KULLANICI yüzeyi" python3 tools/validate_placeholder_surface.py
run "yer tutucu kapısı öz-testi"     python3 tools/validate_placeholder_surface.py --selftest
run "pozitif-ikiz denetimi"        python3 tools/positive_twin_audit.py
run "fixture envanteri"               python3 tools/fixture_check.py
run "replay (3 çalgı)"                python3 tools/replay_check.py
run "uçtan-uca oturum (3 çalgı)"      python3 tools/verify_end_to_end_session.py
run "ostinato_posture testleri"    bash -c 'cd packages/ostinato_posture && dart test'
run "kabuk widget testleri"        flutter test
run "ostinato_audio testleri"         bash -c 'cd packages/ostinato_audio && dart test'
run "dart analyze (audio+postür)"  bash -c 'cd packages/ostinato_audio && dart analyze && cd ../ostinato_posture && dart analyze'
run "flutter analyze (kabuk)"      flutter analyze lib test

printf '\n──── KAPSAM (bu koşum neyi kapsadı)\n'
python3 tools/validate_runner_inventory.py --kapsam
printf '   %s python kapisi · MUT-A mutasyon suiti · pozitif ikiz\n' "$(grep -c '^run .*python3' "$0")"
printf '   KAPSAM DISI: tools/evidence (elle tazelenir) · cihaz-duzeyi render (O-036)\n'
printf '\n════════════════════════════════════\n'
if [ "$fail" -eq 0 ]; then
  printf '✅ TÜM KAPILAR YEŞİL\n'
else
  printf '⛔ EN AZ BİR KAPI KIRMIZI — yukarıda adıyla yazılı\n'
fi
exit "$fail"
