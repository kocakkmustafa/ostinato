"""Rebuild lib/app/app_message_ids.dart from reviewed EN/TR source pairs.

A message id is the first 16 hex digits of sha256(en + "\\0" + tr); the 14
locale catalogs (assets/l10n/<tag>.json) are keyed by that id. The original
generator was not kept in the repo; this one reproduces the checked-in table
byte for byte (--check) and can add new pairs from lesson sources.

  python3 tool/build_message_ids.py --check
  python3 tool/build_message_ids.py --pending content/v1   # ids not yet in the table
  python3 tool/build_message_ids.py --add content/v1       # add them to the table

Plural sources are hand-reviewed and kept verbatim. Adding a pair only adds
its id: translations for the 12 other locales are a separate, reviewed step
(--pending lists what each catalog is missing).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
TABLE = APP / 'lib' / 'app' / 'app_message_ids.dart'
L10N = APP / 'assets' / 'l10n'
HEADER = ('// Generated from reviewed source pairs; '
          'presentation IDs do not own progress.\n')
PAIR_RE = re.compile(r'^  \("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\): "([0-9a-f]{16})",$')
PLACEHOLDER_RE = re.compile(r'\{([A-Za-z]\w*)\}')


def message_id(en: str, tr: str) -> str:
    return hashlib.sha256(f'{en}\0{tr}'.encode('utf-8')).hexdigest()[:16]


def _unescape(s: str) -> str:
    return re.sub(r'\\(.)', lambda m: '\n' if m[1] == 'n' else m[1], s)


def _escape(s: str) -> str:
    return (s.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$')
            .replace('\n', '\\n'))


def parse(text: str) -> tuple[dict[tuple[str, str], str], str]:
    """Return the id table and the verbatim plural-source block."""
    lines = text.split('\n')
    if lines[0] + '\n' != HEADER or lines[1] != \
            'const appMessageIds = <(String, String), String>{':
        raise ValueError('unexpected table header')
    pairs: dict[tuple[str, str], str] = {}
    i = 2
    while lines[i] != '};':
        m = PAIR_RE.match(lines[i])
        if not m:
            raise ValueError(f'line {i + 1}: not a pair entry')
        pairs[(_unescape(m[1]), _unescape(m[2]))] = m[3]
        i += 1
    plural_start = text.index('const appMessagePluralSources')
    return pairs, text[plural_start:]


def placeholders(pairs: dict[tuple[str, str], str]) -> dict[str, dict[str, int]]:
    out = {}
    for (en, _tr), mid in pairs.items():
        # Counter keeps first-appearance order, which the table follows.
        names = Counter(PLACEHOLDER_RE.findall(en))
        if names:
            out[mid] = dict(names)
    return out


def render(pairs: dict[tuple[str, str], str], plural_block: str) -> str:
    rows = sorted(pairs.items(), key=lambda kv: kv[1])
    out = [HEADER, 'const appMessageIds = <(String, String), String>{\n']
    out += [f'  ("{_escape(en)}", "{_escape(tr)}"): "{mid}",\n'
            for (en, tr), mid in rows]
    out.append('};\n\nconst appMessagePlaceholders = <String, Map<String, int>>{\n')
    for mid, names in sorted(placeholders(pairs).items()):
        body = ', '.join(f'"{k}": {v}' for k, v in names.items())
        out.append(f'  "{mid}": {{{body}}},\n')
    out.append('};\n\n')
    return ''.join(out) + plural_block


def source_pairs(root: Path) -> dict[tuple[str, str], str]:
    """Every {en, tr} object in the JSON files under root."""
    found: dict[tuple[str, str], str] = {}

    def walk(value: object) -> None:
        if isinstance(value, dict):
            if isinstance(value.get('en'), str) and isinstance(value.get('tr'), str):
                found[(value['en'], value['tr'])] = message_id(value['en'], value['tr'])
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    for path in sorted(root.rglob('*.json')):
        walk(json.loads(path.read_text('utf-8')))
    return found


def check(text: str) -> list[str]:
    pairs, plural = parse(text)
    errors = [f'{mid}: id does not match sha256 of its pair'
              for (en, tr), mid in pairs.items() if message_id(en, tr) != mid]
    if len(set(pairs.values())) != len(pairs):
        errors.append('duplicate ids')
    if render(pairs, plural) != text:
        errors.append('regenerated table differs from the checked-in file')
    return errors


def pending(pairs: dict[tuple[str, str], str], new: dict[tuple[str, str], str]) -> dict:
    """New ids, and for each locale catalog the ids it still lacks."""
    known = set(pairs.values())
    add = {mid: {'en': en, 'tr': tr} for (en, tr), mid in sorted(new.items(), key=lambda kv: kv[1])
           if mid not in known}
    wanted = {mid for mid in new.values()}
    missing = {}
    for catalog in sorted(L10N.glob('*.json')):
        locale = catalog.stem
        if locale in ('en', 'tr'):
            continue
        have = json.loads(catalog.read_text('utf-8'))['messages']
        missing[locale] = sorted(wanted - have.keys())
    return {'newIds': add, 'missingTranslations': missing}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--pending', type=Path)
    mode.add_argument('--add', type=Path)
    args = ap.parse_args(argv)
    text = TABLE.read_text('utf-8')
    if args.check:
        errors = check(text)
        for e in errors:
            print(e, file=sys.stderr)
        return 1 if errors else 0
    pairs, plural = parse(text)
    new = source_pairs(APP / (args.pending or args.add))
    if args.pending:
        json.dump(pending(pairs, new), sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write('\n')
        return 0
    clash = {mid for pair, mid in new.items() if mid in pairs.values() and pairs.get(pair) != mid}
    if clash:
        print(f'id collision: {sorted(clash)}', file=sys.stderr)
        return 1
    TABLE.write_text(render({**pairs, **new}, plural), 'utf-8')
    return 0


if __name__ == '__main__':
    sys.exit(main())
