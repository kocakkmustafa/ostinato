#!/bin/bash
# Gerçek piyano fixture'larını (Iowa MIS) indirir ve SHA-256'sını DOĞRULAR —
# `fetch_pose_model.sh`ın ses karşılığı, AYNI disiplin.
#
# NİYE İNDİRİLİYOR, NİYE COMMIT EDİLMİYOR: aile kuralı `.task` ikilileri
# için ne diyorsa (`.gitignore`, fetch+SHA-256 build kapısı) bu dosyalar
# için de geçerli — 10 gerçek piyano notası ~40MB, her klonda taşınmaz.
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
# A6/C7/A7/B7: C8'in kök-nedeni (O-177) TEŞHİS edildi ama tek data noktasına
# göre yin.dart eşiğini ayarlamak ilkesiz sayılıp ERTELENMİŞTİ (O-178/O-182/
# O-183 boyunca tekrarlanan aynı disiplin) — bu 4 nota C6(geçti)-C8(kaldı)
# arasına ARA veri noktaları katıyor (semitone: A6=+9, C7=+12, A7=+21,
# B7=+23 — C8=+24'e en yakını B7), TEK bir başarısızlığa göre fit etmek
# yerine bir EĞİLİM görmeyi mümkün kılıyor. Diyez notalar (Fs7 vb.) Iowa
# sunucusunda 404 verdi — yalnız DOĞAL notalarla (bu okta aralığında zaten
# 6 tane var) devam edildi, sahte bir isim İCAT edilmedi.
NOTES="A1 C3 C4 A4 C6 A6 C7 A7 B7 C8"

sha_for() {
  case "$1" in
    A1) echo "d14886420f9d94df12ba213062ed7068753876bde26539c72592a677deb789de" ;;
    C3) echo "b39ff5e129df5557996dbdbadd1f2622cf33425d33714d70af16fd4f209355b5" ;;
    C4) echo "1a7d8ddea94a3639fa58d79ebcc0b09b170b9c324811d2b705f97e278fdefac2" ;;
    A4) echo "800a6be43a44125bda75f7907aba2f6299287b4060d67e85efcf32a226757563" ;;
    C6) echo "897480810c72f06e4fc89cfe555925a344a7413230bd374d374a1796ae88acee" ;;
    A6) echo "e5b2cc6e9894e7fbc4090bd961eb457362eda9d4e138d5fca7cf624b37d8b9d6" ;;
    C7) echo "dc6dbb6fde60ac3349330285a5467cc7a045d246615c713d96c409fe0ea5ada7" ;;
    A7) echo "0632cf6f140c40c70ac91a78264a831e05d708a8526a5d9fc37c434322c1922f" ;;
    B7) echo "035fa4571d299c4f279a5a46efbbf59ccef1a202f5e2358c085e72ecb4baaced" ;;
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

echo "→ 10/10 ham AIFF hazır: $RAW_DIR/"
echo "Sıradaki adım: dart run tool/prepare_audio_fixtures.dart"
