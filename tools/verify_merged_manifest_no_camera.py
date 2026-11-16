#!/usr/bin/env python3
"""Birleşik (merged) Android manifestinde CAMERA izni ve zorunlu kamera
özelliği olmadığını doğrular. Kaynak manifestin `tools:node="remove"`
direktifi eklentilerin geri getirmesini engeller; bu betik BİRLEŞİK sonucu
okur.

Kullanım (önce manifesti üret):
  (cd android && ./gradlew :app:processReleaseMainManifest)
  python3 tools/verify_merged_manifest_no_camera.py [manifest-yolu]
Varsayılan yol: release varyantı. Yol yoksa hata verir (sessiz geçmez).
"""
import re
import sys
from pathlib import Path

DEFAULT = ("build/app/intermediates/merged_manifest/release/"
           "processReleaseMainManifest/AndroidManifest.xml")


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    if not path.exists():
        print(f"❌ birleşik manifest yok: {path} — önce gradle görevini koş")
        return 2
    xml = re.sub(r"<!--.*?-->", "", path.read_text(encoding="utf-8"),
                 flags=re.S)
    bad = []
    for el in re.findall(r"<uses-(?:permission|feature)\b[^>]*>", xml, re.S):
        if re.search(r'android:name="android\.permission\.CAMERA"', el):
            bad.append(f"CAMERA izni: {' '.join(el.split())}")
        if (re.search(r'android:name="android\.hardware\.camera[^"]*"', el)
                and 'android:required="false"' not in el):
            bad.append(f"zorunlu kamera özelliği: {' '.join(el.split())}")
    if 'android.permission.RECORD_AUDIO' not in xml:
        bad.append("RECORD_AUDIO yok (mikrofon izni beklenir)")
    if bad:
        print(f"❌ {path}")
        for b in bad:
            print("  -", b)
        return 1
    print(f"✅ {path}: CAMERA yok, zorunlu kamera özelliği yok, "
          f"RECORD_AUDIO var")
    return 0


if __name__ == "__main__":
    sys.exit(main())
