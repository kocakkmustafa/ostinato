#!/bin/bash
# Gerçek piyano fixture'larını (Iowa MIS) indirir ve SHA-256'sını DOĞRULAR —
# `fetch_pose_model.sh`ın ses karşılığı, AYNI disiplin.
#
# NİYE İNDİRİLİYOR, NİYE COMMIT EDİLMİYOR: aile kuralı `.task` ikilileri
# için ne diyorsa (`.gitignore`, fetch+SHA-256 build kapısı) bu dosyalar
# için de geçerli — 6 gerçek piyano notası ~32MB, her klonda taşınmaz.
# Yalnız bu betik + fixture JSON'ları (`fixtures/audio-real/*.json`) izlenir.
#
# LİSANS: University of Iowa Electronic Music Studios, "without restriction"
# (kurumun kendi sayfası, doğrulandı — `docs/research/2026-08-18-w1-audio-
# golden-fixture-kaynaklari.md` §2). Ticari kullanım SERBEST. Rutin
# mühendislik kararı (roadmap OST-P0-003 Step 1) — GuitarSet gibi atıf-
# şartlı bir lisans DEĞİL, yeniden dağıtım/hukuk kapısı GEREKTİRMEZ.
#
# ⚠️ Kaynak dosyalar STEREO 16-bit big-endian AIFF, 44100 Hz (ölçüldü,
# `afinfo` ile 6/6 doğrulandı). Bu betik SHA-256'yı HAM AIFF üstünde
# pinler (Iowa'nın sunucusundan bayt-bayt aynı) — mono'ya indirgenmiş/
# kırpılmış türetilmiş WAV'ın kendi hash'i pinlenmez (o adım bu makinenin
# `afconvert`ine bağlı, deterministik ama üçüncü-taraf-sabit DEĞİL;
# `tool/prepare_audio_fixtures.dart` doğrulanmış AIFF'ten türetir).
set -euo pipefail

cd "$(dirname "$0")/.."

RAW_DIR="fixtures/audio-real/raw"
mkdir -p "$RAW_DIR"

# note -> beklenen f0Hz (12-TET, A4=440Hz) ve pinli SHA-256, ölçülüp
# 2026-08-19'da doğrudan Iowa sunucusundan indirilerek sabitlendi.
NOTES="A1 C3 C4 A4 C6 C8"

sha_for() {
  case "$1" in
    A1) echo "d14886420f9d94df12ba213062ed7068753876bde26539c72592a677deb789de" ;;
    C3) echo "b39ff5e129df5557996dbdbadd1f2622cf33425d33714d70af16fd4f209355b5" ;;
    C4) echo "1a7d8ddea94a3639fa58d79ebcc0b09b170b9c324811d2b705f97e278fdefac2" ;;
    A4) echo "800a6be43a44125bda75f7907aba2f6299287b4060d67e85efcf32a226757563" ;;
    C6) echo "897480810c72f06e4fc89cfe555925a344a7413230bd374d374a1796ae88acee" ;;
    C8) echo "4b32b00da510fc38359a98061b99334acb4d53b39d7fd0413d26ee9fed5034ef" ;;
    *) echo ""; ;;
  esac
}

verify() {
  local got
  got=$(shasum -a 256 "$1" | awk '{print $1}')
  [ "$got" = "$2" ] || { echo "⛔ SHA UYUŞMUYOR: $1"; echo "   beklenen: $2"; echo "   bulunan : $got"; return 1; }
}

for note in $NOTES; do
  aiff="$RAW_DIR/Piano.mf.${note}.aiff"
  expected_sha=$(sha_for "$note")
  if [ -f "$aiff" ] && verify "$aiff" "$expected_sha" 2>/dev/null; then
    echo "zaten yerinde + doğrulandı: $aiff"
    continue
  fi
  url="https://theremin.music.uiowa.edu/sound%20files/MIS/Piano_Other/piano/Piano.mf.${note}.aiff"
  echo "indiriliyor: $url"
  curl -fsSL "$url" -o "$aiff"
  verify "$aiff" "$expected_sha"
  echo "✓ SHA doğrulandı ($note): $expected_sha"
done

echo "→ 6/6 ham AIFF hazır: $RAW_DIR/"
echo "Sıradaki adım: dart run tool/prepare_audio_fixtures.dart"
