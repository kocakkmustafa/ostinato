#!/bin/bash
# Pinli MediaPipe pose modelini indirir ve SHA-256'sını DOĞRULAR (J-072).
#
# NİYE İNDİRİLİYOR, NİYE COMMIT EDİLMİYOR: aile kuralı `.task` dosyalarını
# git dışında tutuyor (`motion-core/.gitignore:9`) ve yalnız `MODELS.md`'yi
# izliyor — 9,4 MB'lık bir ikili her klonda taşınmaz. Karşılığında pin
# URL + SHA olarak yaşar ve doğrulama BUILD KAPISI olur:
# "her build, buradaki SHA-256'yı doğrular; hash tutmuyorsa build durur."
#
# ⚠️ `latest` ASLA KULLANILMAZ. Ölçüldü (M-L-01): `full` varyantında
# `/float16/latest/` ile `/float16/1/` FARKLI (aynı boyut 9 398 198, farklı
# hash) — boyut değişmediği için fark gözden kaçar. Referans artefaktları
# `/1/` ile üretildi; başka bir bundle sessizce farklı eklem açıları verir
# ve eklem tablosu (J-061) artık o modele ait olmaz.
#
# Ostinato'nun aile-genel fetch_pose_model.sh kopyası (Gravita/JabLab ile
# BİREBİR aynı — aynı pinli model, aynı SHA-256).
set -euo pipefail

VARIANT="pose_landmarker_full"
VERSION="1"                # PİNLİ sürüm segmenti — 'latest' YASAK
SHA256="5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1"
DEST="assets/models/${VARIANT}.v1.task"
URL="https://storage.googleapis.com/mediapipe-models/pose_landmarker/${VARIANT}/float16/${VERSION}/${VARIANT}.task"

cd "$(dirname "$0")/.."

verify() {
  local got
  got=$(shasum -a 256 "$1" | awk '{print $1}')
  [ "$got" = "$SHA256" ] || { echo "⛔ SHA UYUŞMUYOR"; echo "   beklenen: $SHA256"; echo "   bulunan : $got"; return 1; }
  echo "✓ SHA doğrulandı: $SHA256"
}

# Aile hattında zaten indirilmişse KOPYALA — aynı pinli dosyayı ikinci kez
# indirmek ağ israfı, ve iki kopyanın hash'i zaten aynı olmak zorunda.
LOCAL="$HOME/Documents/YULAlab-AI/ventures/motion-core/lib/tools/fixture_pipeline/models/${VARIANT}.v1.task"
if [ -f "$DEST" ] && verify "$DEST" 2>/dev/null; then
  echo "model zaten yerinde: $DEST"; exit 0
fi
if [ -f "$LOCAL" ]; then
  echo "aile hattından kopyalanıyor: $LOCAL"
  cp "$LOCAL" "$DEST"
else
  echo "indiriliyor: $URL"
  curl -fsSL "$URL" -o "$DEST"
fi
verify "$DEST"
echo "→ $DEST"
