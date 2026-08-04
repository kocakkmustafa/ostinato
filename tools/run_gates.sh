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
run "eşik türetimi (artefakt↔config)" python3 tools/derive_posture_thresholds.py --check
run "uzman-bekleyen envanteri"        python3 tools/gen_expert_inventory.py
run "fixture envanteri"               python3 tools/fixture_check.py
run "replay (3 çalgı)"                python3 tools/replay_check.py
run "uçtan-uca oturum (3 çalgı)"      python3 tools/verify_end_to_end_session.py
run "ostinato_audio testleri"         bash -c 'cd packages/ostinato_audio && dart test'
run "dart analyze"                    bash -c 'cd packages/ostinato_audio && dart analyze'

printf '\n════════════════════════════════════\n'
if [ "$fail" -eq 0 ]; then
  printf '✅ TÜM KAPILAR YEŞİL\n'
else
  printf '⛔ EN AZ BİR KAPI KIRMIZI — yukarıda adıyla yazılı\n'
fi
exit "$fail"
