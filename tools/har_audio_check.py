#!/usr/bin/env python3
"""SEC-OST-01 — ağ yakalamasında ham ses içeren istek sayımı (cihaz günü).

mitmproxy'nin HAR dışa aktarımını (`--set hardump=<dosya>.har`) okur ve
İSTEK tarafında ses şüphesi taşıyanları sayar. Yanıtlar sayılmaz: ölçüt
"cihazdan çıkan ham ses 0"dır (bkz. docs/device-day/SEC-OST-01-YAKALAMA.md).

Şüphe nedenleri (her biri adıyla raporlanır):
  audio_mime      istek Content-Type'ı audio/*
  octet_large     application/octet-stream ve gövde >= 8 KB (önerilen eşik)
  audio_ext       URL yolu ya da multipart dosya adı .wav/.m4a/.aac/.mp3/
                  .caf/.aiff/.aif/.flac uzantılı
  multipart_audio params'ta ses türü/adı; ya da gövde metninde
                  `filename="....<ses uzantısı>"` / `Content-Type: audio/`
                  (mitmproxy HAR'ı params.fileName'i HER ZAMAN doldurmaz;
                  bu yüzden ham gövde metni de taranır)
  b64_<tür>       gövdede base64 başlık: RIFF 'UklGR', caff 'Y2FmZg',
                  fLaC 'ZkxhQw', OggS 'T2dnUw', ftyp (m4a/aac), ID3 'SUQz'
  raw_<tür>       gövdede ham başlık: RIFF....WAVE, caff, fLaC, OggS,
                  ftyp(M4A/isom/mp42), ID3
  body_gt_64kb    tek istek gövdesi > 64 KB (önerilen eşik; kod bunu
                  dayatmaz, kurucu/Motion onayı bekler)

Çıkış kodu:
  0  şüpheli yok ve kanıt yeterli
  1  şüpheli var
  2  girdi hatası (dosya yok, bozuk JSON, beklenmeyen tür, >200 MB, ...)
  3  KANITSIZ: HAR boş (0 giriş) ya da --expect-domain verilip hiçbiri
     yakalamada görülmedi; "0 şüpheli" burada "ses yok" anlamına GELMEZ
  4  --selftest başarısız (girdi hatasıyla karışmasın)
`--selftest`: gömülü sentetik HAR'larla main()'i uçtan uca sınar.
Yalnız standart kütüphane. Bu betik kural eşleyicidir: şifrelenmiş ya da
özel kodlanmış ses yakalanmayabilir; HTTPS çözülmediyse sonuç KANITSIZdır.
"""
from __future__ import annotations

import argparse
import base64
import json
import re
import sys
import tempfile
from collections import Counter
from pathlib import Path
from urllib.parse import urlsplit

AUDIO_EXTS = (".wav", ".m4a", ".aac", ".mp3", ".caf", ".aiff", ".aif", ".flac")
OCTET_MIN_BYTES = 8 * 1024          # önerilen eşik
BIG_BODY_BYTES = 64 * 1024          # önerilen eşik
MAX_FILE_BYTES = 200 * 1024 * 1024  # bundan büyük girdi: exit 2

EXIT_OK, EXIT_SUSPICIOUS, EXIT_INPUT, EXIT_UNPROVEN, EXIT_SELFTEST = 0, 1, 2, 3, 4

# Base64 başlıkları. Kısa olan 'SUQz' (ID3) yalnız bir değerin başında aranır.
B64_ANYWHERE = (("UklGR", "b64_riff"), ("Y2FmZg", "b64_caff"),
                ("ZkxhQw", "b64_flac"), ("T2dnUw", "b64_ogg"))
B64_FTYP = re.compile(r"[A-Za-z0-9+/]GZ0eXA")
B64_ID3 = re.compile(r"(?:^|[\"'=:,\s])SUQz")
RAW_PATTERNS = (
    (re.compile(r"RIFF[\s\S]{4}WAVE"), "raw_riff"),
    (re.compile(r"caff\x00\x01"), "raw_caff"),
    (re.compile(r"fLaC\x00"), "raw_flac"),
    (re.compile(r"OggS\x00"), "raw_ogg"),
    (re.compile(r"ftyp(?:M4A |M4B |isom|mp42|mp41)"), "raw_ftyp"),
    (re.compile(r"ID3[\x02-\x04]\x00"), "raw_id3"),
)
MULTI_FILENAME = re.compile(
    r"filename\*?=\"?[^\"\r\n;]*\.(?:wav|m4a|aac|mp3|caf|aiff?|flac)\b",
    re.IGNORECASE)
MULTI_AUDIO_TYPE = re.compile(r"content-type:\s*audio/", re.IGNORECASE)


def _need(value, kind, what):
    if not isinstance(value, kind):
        raise ValueError(f"beklenmeyen tür: {what} {kind.__name__} değil "
                         f"({type(value).__name__})")
    return value


def _headers(req: dict) -> list[dict]:
    headers = req.get("headers", [])
    if headers is None:
        return []
    _need(headers, list, "request.headers")
    for h in headers:
        _need(h, dict, "header öğesi")
    return headers


def _header(headers: list[dict], name: str) -> str:
    for h in headers:
        if str(h.get("name", "")).lower() == name:
            return str(h.get("value", ""))
    return ""


def _has_audio_ext(text: str) -> bool:
    return text.lower().endswith(AUDIO_EXTS)


def _post(req: dict) -> dict:
    post = req.get("postData")
    if post is None:
        return {}
    _need(post, dict, "request.postData")
    text = post.get("text")
    if text is not None:
        _need(text, str, "postData.text")
    params = post.get("params")
    if params is not None:
        _need(params, list, "postData.params")
        for p in params:
            _need(p, dict, "postData.params öğesi")
    return post


def _body_text_and_size(req: dict, headers: list[dict]) -> tuple[str, int]:
    post = _post(req)
    text = post.get("text") or ""
    size = len(text)
    if post.get("encoding") == "base64" and text:
        try:
            size = len(base64.b64decode(text, validate=False))
        except Exception:
            pass
    declared = req.get("bodySize")
    if isinstance(declared, int) and not isinstance(declared, bool) \
            and declared > size:
        size = declared
    cl = _header(headers, "content-length")
    if cl.isdigit() and int(cl) > size:
        size = int(cl)
    return text, size


def classify(req: dict) -> list[str]:
    """Bir HAR isteği için şüphe nedenleri listesi (boşsa temiz)."""
    _need(req, dict, "entry.request")
    headers = _headers(req)
    post = _post(req)
    reasons: list[str] = []
    ctype = (_header(headers, "content-type")
             or str(post.get("mimeType", ""))).lower()
    text, size = _body_text_and_size(req, headers)
    path = urlsplit(str(req.get("url", ""))).path

    if ctype.startswith("audio/"):
        reasons.append("audio_mime")
    if "application/octet-stream" in ctype and size >= OCTET_MIN_BYTES:
        reasons.append("octet_large")
    if _has_audio_ext(path):
        reasons.append("audio_ext")
    multipart = False
    for part in post.get("params") or []:
        pname = str(part.get("fileName", ""))
        ptype = str(part.get("contentType", "")).lower()
        if ptype.startswith("audio/") or _has_audio_ext(pname):
            multipart = True
            break
    if text and (MULTI_FILENAME.search(text) or MULTI_AUDIO_TYPE.search(text)):
        multipart = True
    if multipart:
        reasons.append("multipart_audio")
    if text:
        for marker, why in B64_ANYWHERE:
            if marker in text:
                reasons.append(why)
        if B64_FTYP.search(text):
            reasons.append("b64_ftyp")
        if B64_ID3.search(text):
            reasons.append("b64_id3")
        for pattern, why in RAW_PATTERNS:
            if pattern.search(text):
                reasons.append(why)
    if size > BIG_BODY_BYTES:
        reasons.append("body_gt_64kb")
    return reasons


def analyse(har: object) -> dict:
    log = _need(_need(har, dict, "HAR kökü").get("log"), dict, "log")
    entries = _need(log.get("entries"), list, "log.entries")
    hosts: Counter[str] = Counter()
    flagged: list[dict] = []
    for entry in entries:
        _need(entry, dict, "entry")
        req = _need(entry.get("request"), dict, "entry.request")
        host = (urlsplit(str(req.get("url", ""))).hostname
                or "(bilinmiyor)").lower()
        hosts[host] += 1
        reasons = classify(req)
        if reasons:
            _, size = _body_text_and_size(req, _headers(req))
            flagged.append({"method": req.get("method", "?"),
                            "url": req.get("url", ""),
                            "bytes": size, "reasons": reasons})
    return {"total": len(entries), "hosts": hosts, "suspicious": flagged}


def domain_seen(hosts: Counter, domain: str) -> bool:
    d = domain.lower().lstrip(".")
    return any(h == d or h.endswith("." + d) for h in hosts)


def report(result: dict, label: str, expect: list[str]) -> None:
    print(f"== {label}")
    print(f"toplam istek: {result['total']}")
    print("alan adları:")
    for host, n in sorted(result["hosts"].items()):
        print(f"  {host}  ({n})")
    if not result["hosts"]:
        print("  (yok)")
    for d in expect:
        print(f"beklenen alan adı {d}: "
              f"{'görüldü' if domain_seen(result['hosts'], d) else 'GÖRÜLMEDİ'}")
    print(f"ses şüpheli istek: {len(result['suspicious'])}")
    for f in result["suspicious"]:
        print(f"  {f['method']} {f['url']}  {f['bytes']} B  "
              f"neden: {', '.join(f['reasons'])}")


def run_file(path: Path, expect: list[str]) -> int:
    """Dosyayı çözümle, raporla, çıkış kodunu döndür."""
    try:
        if path.stat().st_size > MAX_FILE_BYTES:
            print(f"girdi hatası: dosya > {MAX_FILE_BYTES // (1024 * 1024)} MB",
                  file=sys.stderr)
            return EXIT_INPUT
        har = json.loads(path.read_text(encoding="utf-8"))
        result = analyse(har)
    except Exception as exc:  # noqa: BLE001 — çökme 1 ile karışmasın
        print(f"girdi hatası: {type(exc).__name__}: {exc}", file=sys.stderr)
        return EXIT_INPUT
    report(result, path.name, expect)
    if result["suspicious"]:
        return EXIT_SUSPICIOUS
    if result["total"] == 0:
        print("KANITSIZ: HAR'da 0 giriş var; 'ham ses 0' denemez.",
              file=sys.stderr)
        return EXIT_UNPROVEN
    if expect and not any(domain_seen(result["hosts"], d) for d in expect):
        print("KANITSIZ: beklenen alan adlarının hiçbiri yakalamada yok "
              "(uygulamanın kendi trafiği görülmedi); 'ham ses 0' denemez.",
              file=sys.stderr)
        return EXIT_UNPROVEN
    return EXIT_OK


# ---- selftest ------------------------------------------------------------
# Bağımsız literaller (betiğin sabitlerinden türetilmedi):
#   printf 'caff\000\001\000\000' | base64      -> Y2FmZgABAAA=
#   printf 'RIFF\044\000\000\000WAVEfmt ' | base64 -> UklGRiQAAABXQVZFZm10IA==
CAFF_B64_BODY = '{"take":"Y2FmZgABAAA="}'
RIFF_B64_BODY = '{"take":"UklGRiQAAABXQVZFZm10IA=="}'


def _req(url: str, ctype: str = "", text: str = "", size: int | None = None,
         params: list[dict] | None = None, method: str = "POST") -> dict:
    headers = [{"name": "Content-Type", "value": ctype}] if ctype else []
    post: dict = {"mimeType": ctype, "text": text}
    if params:
        post["params"] = params
    return {"request": {"method": method, "url": url, "headers": headers,
                        "bodySize": len(text) if size is None else size,
                        "postData": post}}


def _har(*entries: dict) -> dict:
    return {"log": {"entries": list(entries)}}


def selftest() -> int:
    ok = True

    def check(cond: bool, msg: str) -> None:
        nonlocal ok
        print(("ok   " if cond else "KALDI ") + msg)
        ok = ok and cond

    api = "https://api.example.test"
    clean_entries = [_req(f"{api}/v1/events", "application/json",
                          '{"event":"open"}'),
                     _req(f"{api}/v1/ping", method="GET")]

    # 1) Neden bazlı sınama (classify).
    dirty = {
        "audio_mime": _req("https://x.test/u", "audio/wav", "abc"),
        "octet_large": _req("https://x.test/u", "application/octet-stream",
                            "z" * 10, size=20000),
        "audio_ext": _req("https://x.test/take.m4a", "text/plain", "a"),
        "multipart_audio": _req(
            "https://x.test/u", "multipart/form-data", "",
            params=[{"name": "f", "fileName": "a.caf",
                     "contentType": "application/octet-stream"}]),
        "multipart_audio_text": _req(
            "https://x.test/u", "multipart/form-data",
            '--b\r\nContent-Disposition: form-data; name="f"; '
            'filename="take1.WAV"\r\n\r\nxx\r\n--b--'),
        "b64_riff": _req("https://x.test/u", "application/json",
                         RIFF_B64_BODY),
        "b64_caff": _req("https://x.test/u", "application/json",
                         CAFF_B64_BODY),
        "raw_riff": _req("https://x.test/u", "text/plain",
                         "RIFF\x24\x00\x00\x00WAVEfmt "),
        "raw_caff": _req("https://x.test/u", "text/plain",
                         "caff\x00\x01\x00\x00"),
        "raw_flac": _req("https://x.test/u", "text/plain", "fLaC\x00\x00"),
        "raw_ogg": _req("https://x.test/u", "text/plain", "OggS\x00\x02"),
        "raw_ftyp": _req("https://x.test/u", "text/plain",
                         "\x00\x00\x00\x20ftypM4A \x00"),
        "raw_id3": _req("https://x.test/u", "text/plain", "ID3\x04\x00\x00"),
        "body_gt_64kb": _req("https://x.test/u", "application/json", "{}",
                             size=70000),
    }
    for want, entry in dirty.items():
        got = classify(entry["request"])
        check(want.split("_text")[0] in got or want in got,
              f"neden {want} yakalandı {got}")
    check(classify(clean_entries[0]["request"]) == [], "temiz istek 0 neden")

    # 2) main() uçtan uca çıkış kodları (0/1/2/3).
    with tempfile.TemporaryDirectory() as tmp:
        def write(name: str, content: object) -> str:
            p = Path(tmp) / name
            p.write_text(content if isinstance(content, str)
                         else json.dumps(content), encoding="utf-8")
            return str(p)

        cases = [
            ("temiz -> 0", [write("c.har", _har(*clean_entries))], 0),
            ("temiz + beklenen alan görüldü -> 0",
             [write("c2.har", _har(*clean_entries)),
              "--expect-domain", "example.test"], 0),
            ("ses içeren -> 1",
             [write("d.har", _har(*clean_entries, dirty["audio_mime"]))], 1),
            ("gerçek caff b64 -> 1",
             [write("d2.har", _har(dirty["b64_caff"]))], 1),
            ("gerçek riff b64 -> 1",
             [write("d3.har", _har(dirty["b64_riff"]))], 1),
            ("boş HAR -> 3", [write("e.har", _har())], 3),
            ("beklenen alan yok -> 3",
             [write("c3.har", _har(*clean_entries)),
              "--expect-domain", "backend.invalid",
              "--expect-domain", "other.invalid"], 3),
            ("ses + beklenen alan yok -> 1 (şüpheli önce)",
             [write("d4.har", _har(dirty["audio_mime"])),
              "--expect-domain", "backend.invalid"], 1),
            ("entries dict -> 2",
             [write("b1.har", {"log": {"entries": {}}})], 2),
            ("entry dict değil -> 2",
             [write("b2.har", {"log": {"entries": ["x"]}})], 2),
            ("headers liste değil -> 2",
             [write("b3.har", {"log": {"entries": [
                 {"request": {"url": "https://a.test/", "headers": "x"}}]}})],
             2),
            ("postData liste -> 2",
             [write("b4.har", {"log": {"entries": [
                 {"request": {"url": "https://a.test/",
                              "postData": []}}]}})], 2),
            ("postData.text sayı -> 2",
             [write("b5.har", {"log": {"entries": [
                 {"request": {"url": "https://a.test/",
                              "postData": {"text": 5}}}]}})], 2),
            ("bozuk JSON -> 2", [write("b6.har", "{not json")], 2),
            ("kök liste -> 2", [write("b7.har", [])], 2),
            ("olmayan dosya -> 2", [str(Path(tmp) / "yok.har")], 2),
        ]
        for label, argv, want in cases:
            got = main(argv)
            check(got == want, f"main {label} (çıkış {got}, beklenen {want})")

    print("SELFTEST " + ("GEÇTİ" if ok else "KALDI"))
    return EXIT_OK if ok else EXIT_SELFTEST


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("har", nargs="?", help="mitmproxy HAR dosyası")
    ap.add_argument("--expect-domain", action="append", default=[],
                    metavar="ALAN",
                    help="uygulamanın kendi backend alan adı (birden çok "
                         "verilebilir); hiçbiri yakalamada yoksa çıkış 3")
    ap.add_argument("--selftest", action="store_true",
                    help="gömülü sentetik HAR ile kendini sına")
    try:
        args = ap.parse_args(argv)
    except SystemExit as exc:  # argparse hatası da girdi hatasıdır
        return EXIT_OK if exc.code in (0, None) else EXIT_INPUT
    if args.selftest:
        return selftest()
    if not args.har:
        ap.print_usage(sys.stderr)
        return EXIT_INPUT
    return run_file(Path(args.har), args.expect_domain)


if __name__ == "__main__":
    sys.exit(main())
