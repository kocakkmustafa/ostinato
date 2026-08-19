#!/usr/bin/env python3
"""Gerçek gitar fixture'larını (GuitarSet) İNDİRİR — `fetch_audio_fixtures.sh`
+ `fetch_pose_model.sh`ın AYNI deseni: SHA-256 pinlenir, ikilikler
.gitignore'da, `fixtures/audio-real/raw/`e yazılır.

NEDEN TAM ARŞİV İNDİRİLMİYOR: GuitarSet'in tek mono-mic ses arşivi 657MB
(Zenodo record 3371780) — Iowa MIS'in aksine tek dosyalar ayrı ayrı
adreslenebilir DEĞİL, hepsi bir ZIP'in içinde. Ama Zenodo HTTP Range
isteklerini DESTEKLİYOR (doğrudan test edildi, `curl -r` ile 206 Partial
Content döndü) — bu script ZIP'in merkezi dizinini (birkaç KB) + yalnız
İSTENEN dosyaların sıkıştırılmış baytlarını çeker, `zipfile`in KENDİ
seek/read soyutlamasını sahte bir HTTP-range dosya nesnesiyle besleyerek.
Ölçüldü: hedef dosya + JAMS notu için toplam ~1MB ağ trafiği — arşivin
%0,15'i. `zipfile.read()`in çözümü DETERMİNİSTİK (standart DEFLATE, bu
makinenin bir aracına bağlı DEĞİL — `afconvert`in aksine) — bu yüzden
ÇIKAN dosyanın SHA-256'sı (afconvert-türetilmiş piyano WAV'larından
FARKLI olarak) burada GÜVENLE pinlenir, iki ayrı koşumda birebir aynı
çıktığı doğrulandı.

LİSANS: GuitarSet, CC BY 4.0 (Zenodo record 3371780 kendi sayfası,
doğrulandı — docs/research/2026-08-18-w1-audio-golden-fixture-kaynaklari.md
§2). Ticari kullanım SERBEST, atıfla. Rutin mühendislik kararı (Iowa MIS
emsaliyle aynı sınıf, OST-P0-003 Step 1) — ATIF metni bu dosyanın
docstring'inde + fixture JSON'larının `recordingMeta.license` alanında
taşınıyor, ayrıca bir hukuk kapısı GEREKTİRMEDİ.

ATIF (CC BY 4.0 şartı): Xu, Q., Salamon, J., Bittner, R., Wang, X., Bello,
J.P. "GuitarSet: A Dataset for Guitar Transcription", ISMIR 2018.
"""
import hashlib
import io
import os
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, "fixtures", "audio-real", "raw")

AUDIO_ZIP_URL = "https://zenodo.org/records/3371780/files/audio_mono-mic.zip"
ANNOTATION_ZIP_URL = "https://zenodo.org/records/3371780/files/annotation.zip"

# Hedef: 00_BN1-129-Eb_comp — Bossa Nova stili, akor eşliği (comping), 3
# ayrı gerçek majör akor içeriyor (D#:maj / G#:maj / A#:maj, JAMS'ın kendi
# basit-akor katmanından — doğrulandı, elle yazılmadı, bkz.
# prepare_guitarset_fixtures.py).
TARGETS = [
    {
        "zip_url": AUDIO_ZIP_URL,
        "entry": "00_BN1-129-Eb_comp_mic.wav",
        "dest": "guitarset_00_BN1-129-Eb_comp_mic.wav",
        "sha256": "59e1e3c9bebdabd48afe28050a2c031e6cf36e5697268301cdf2e74bc66b71f1",
    },
    {
        "zip_url": ANNOTATION_ZIP_URL,
        "entry": "00_BN1-129-Eb_comp.jams",
        "dest": "guitarset_00_BN1-129-Eb_comp.jams",
        "sha256": "cd79564c51d0dec7d04e010d31525e9f7d2b9d41cf6116118a66ac5a8c181007",
    },
]


class HttpRangeFile(io.RawIOBase):
    """`zipfile.ZipFile`in seek/read beklediği minimal dosya-benzeri nesne —
    her okuma bir HTTP Range isteğine çevrilir, ARŞİV HİÇ TAMAMEN İNMEZ."""

    def __init__(self, url):
        self.url = url
        self.pos = 0
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=30) as resp:
            self.size = int(resp.headers["Content-Length"])
        self.fetched_bytes = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self.pos = offset
        elif whence == io.SEEK_CUR:
            self.pos += offset
        elif whence == io.SEEK_END:
            self.pos = self.size + offset
        return self.pos

    def tell(self):
        return self.pos

    def readinto(self, b):
        length = len(b)
        if length == 0:
            return 0
        end = min(self.pos + length, self.size) - 1
        if end < self.pos:
            return 0
        req = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{end}"}
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
        b[: len(data)] = data
        self.pos += len(data)
        self.fetched_bytes += len(data)
        return len(data)


def verify(path, expected_sha):
    if not os.path.exists(path):
        return False
    got = hashlib.sha256(open(path, "rb").read()).hexdigest()
    return got == expected_sha


def fetch_entry(zip_url, entry_name, dest_path, expected_sha):
    if verify(dest_path, expected_sha):
        print(f"zaten yerinde + doğrulandı: {dest_path}")
        return
    print(f"çekiliyor: {entry_name}  (kaynak: {zip_url})")
    f = HttpRangeFile(zip_url)
    zf = zipfile.ZipFile(f)
    data = zf.read(entry_name)
    with open(dest_path, "wb") as out:
        out.write(data)
    got = hashlib.sha256(data).hexdigest()
    if got != expected_sha:
        print(f"⛔ SHA UYUŞMUYOR: {dest_path}")
        print(f"   beklenen: {expected_sha}")
        print(f"   bulunan : {got}")
        sys.exit(1)
    print(f"✓ SHA doğrulandı ({f.fetched_bytes/1e6:.2f} MB ağdan çekildi, "
          f"arşivin %{f.fetched_bytes/f.size*100:.3f}'i): {dest_path}")


if __name__ == "__main__":
    os.makedirs(RAW_DIR, exist_ok=True)
    for t in TARGETS:
        fetch_entry(t["zip_url"], t["entry"], os.path.join(RAW_DIR, t["dest"]), t["sha256"])
    print(f"→ {len(TARGETS)}/{len(TARGETS)} GuitarSet dosyası hazır: {RAW_DIR}/")
