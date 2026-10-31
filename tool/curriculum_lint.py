"""Lint the v1 curriculum plan tables and reproduce their engine counts.

The plan lives in docs/v1-curriculum/{10,20,30,40}-*.md as one table row per
lesson (contract: 00-ders-format-sozlesmesi.md). This checks ids, headings,
code vocabularies and the counts quoted in 70-motor-bagimliligi.md, which are
pinned in docs/v1-curriculum/counts.v1.json.

  python3 tool/curriculum_lint.py            # lint + print counts
  python3 tool/curriculum_lint.py --check    # lint + counts must equal pin
  python3 tool/curriculum_lint.py --write    # lint + rewrite the pin
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
PLAN = APP / 'docs' / 'v1-curriculum'
PIN = PLAN / 'counts.v1.json'
CONTENT = APP / 'content' / 'v1'
COURSE_FILES = {
    'gtr': '10-gitar.md',
    'voc': '20-ses.md',
    'pno': '30-piyano.md',
    'ear': '40-kulak-muzisyenlik.md',
}
HEADER = ['id', 'Başlık (EN / TR)', 'Hedef', 'Ölçülen pratik', 'Ölçüm',
          'Motor', 'Ref/Güv', 'Mevcut']
ID_RE = re.compile(
    r'^(gtr|voc|pno|ear)-s([1-4])-(?:m(\d{2})(a|b)?-(\d{2})|test(?:-(a|b))?)$')
LEVEL_RE = re.compile(r'^## S([1-4]) — .+\((\d+)[^)]*\)\s*$')
MODULE_RE = re.compile(r'^### M(\d{2})(A|B)? .+\((\d+)\)\s*$')
MEASURE = {'M', 'M!', 'M~', 'MIDI', 'K', 'Ö', 'D'}
# Order in which engine steps become available (contract §4.1); A7 runs in
# parallel and is assumed ready in the cumulative table, as in 70-… §2.
STEP_ORDER = ['A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A6p']
STEPS = set(STEP_ORDER) | {'A7'}
REF = {'—', 'S', 'SE', 'DR', 'KL'}
SAFETY = {'Ç', 'G1', 'G2', 'G3', 'V1', 'V2', 'V3', 'V4', 'V5', 'P1', 'P2',
          'E1'}
COURSES = ['gtr', 'voc', 'pno', 'ear']
COURSE_SAFETY = {'gtr': {'Ç', 'G1'}, 'voc': {'Ç', 'V1'}, 'pno': {'Ç', 'P1'},
                 'ear': {'Ç', 'E1'}}


class LintError(ValueError):
    pass


@dataclass(frozen=True)
class Lesson:
    id: str
    course: str
    level: int
    module: str | None  # 'm03', 'm19a'; None for a level test
    measure: tuple[str, ...]
    steps: tuple[str, ...]
    refs: tuple[str, ...]
    title_en: str
    title_tr: str
    source: str  # file:line

    @property
    def gate(self) -> str:
        """Fallback class from contract §4.2 (what a late engine does)."""
        if 'M!' in self.measure:
            return 'held'
        if 'M~' in self.measure:
            return 'experimental'
        if 'M' in self.measure:
            return 'selfCheck'
        if 'K' in self.measure:
            return 'camera'
        return 'noEngine'

    @property
    def opening_step(self) -> str:
        if self.steps == ('A7',):
            return 'A7'
        ordered = [s for s in self.steps if s != 'A7']
        return max(ordered, key=STEP_ORDER.index)


def _cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip('|').split('|')]


def parse_course(course: str, text: str, name: str) -> list[Lesson]:
    lessons: list[Lesson] = []
    errors: list[str] = []
    level = module = None
    level_claim: dict[int, int] = {}
    module_claim: dict[tuple[int, str], int] = {}
    in_table = False
    for n, line in enumerate(text.splitlines(), 1):
        where = f'{name}:{n}'
        if m := LEVEL_RE.match(line):
            level, module = int(m[1]), None
            level_claim[level] = int(m[2])
            continue
        if m := MODULE_RE.match(line):
            module = f'm{m[1]}{(m[2] or "").lower()}'
            module_claim[(level, module)] = int(m[3])
            continue
        if line.startswith('### '):
            module = None  # level test sections
            continue
        if not line.startswith('|'):
            in_table = False
            continue
        cells = _cells(line)
        if cells[:1] == ['id']:
            if cells != HEADER:
                errors.append(f'{where}: lesson table header {cells}')
            in_table = True
            continue
        if not in_table or set(line) <= set('|-: '):
            continue
        if len(cells) != len(HEADER):
            errors.append(f'{where}: {len(cells)} cells, expected 8')
            continue
        lid, title, _goal, _practice, measure, motor, refs, _legacy = cells
        m = ID_RE.match(lid)
        if not m:
            errors.append(f'{where}: bad id {lid!r}')
            continue
        if m[1] != course:
            errors.append(f'{where}: {lid} is not a {course} lesson')
        if level is None or int(m[2]) != level:
            errors.append(f'{where}: {lid} is under level S{level}')
        row_module = None if 'test' in lid else f'm{m[3]}{m[4] or ""}'
        # Track tests (test-a/-b) sit at the end of their track's table.
        if row_module is not None and row_module != module:
            errors.append(f'{where}: {lid} is under module {module}')
        if ' / ' not in title:
            errors.append(f'{where}: title needs "EN / TR"')
            en = tr = title
        else:
            en, tr = (s.strip() for s in title.split(' / ', 1))
        codes = tuple(c.strip() for c in re.split(r'[+/]', measure) if c.strip())
        steps = tuple(s.strip() for s in motor.split('+') if s.strip())
        ref = tuple(r.strip() for r in refs.split(',') if r.strip())
        for code in codes:
            if code not in MEASURE:
                errors.append(f'{where}: measurement {code!r}')
        if not codes:
            errors.append(f'{where}: empty measurement')
        for step in steps:
            if step not in STEPS:
                errors.append(f'{where}: engine step {step!r}')
        if not steps:
            errors.append(f'{where}: empty engine step')
        if 'A0' in steps and len(steps) > 1:
            errors.append(f'{where}: A0 cannot be combined')
        if ('A0' in steps) != (set(codes) <= {'D', 'Ö'}):
            errors.append(f'{where}: A0 iff measurement is D/Ö only')
        for r in ref:
            if r not in REF | SAFETY:
                errors.append(f'{where}: ref/safety code {r!r}')
        lessons.append(Lesson(lid, course, int(m[2]), row_module, codes,
                              steps, ref, en, tr, where))
    for lv, claimed in level_claim.items():
        got = sum(1 for x in lessons if x.level == lv)
        if got != claimed:
            errors.append(f'{name}: S{lv} heading says {claimed}, rows {got}')
    for (lv, mod), claimed in module_claim.items():
        # Module headings count lessons only, not the track test.
        got = sum(1 for x in lessons if x.level == lv and x.module == mod)
        if got != claimed:
            errors.append(f'{name}: S{lv} {mod} heading says {claimed}, rows {got}')
    if errors:
        raise LintError('\n'.join(errors))
    return lessons


def load(plan: Path = PLAN) -> list[Lesson]:
    lessons: list[Lesson] = []
    errors: list[str] = []
    for course, name in COURSE_FILES.items():
        try:
            lessons += parse_course(course, (plan / name).read_text('utf-8'), name)
        except LintError as e:
            errors.append(str(e))
    seen: dict[str, str] = {}
    for x in lessons:
        if x.id in seen:
            errors.append(f'{x.source}: duplicate id {x.id} (first {seen[x.id]})')
        seen.setdefault(x.id, x.source)
    if errors:
        raise LintError('\n'.join(errors))
    return lessons


def counts(lessons: list[Lesson]) -> dict:
    def per_course(pred) -> dict[str, int]:
        row = {c: sum(1 for x in lessons if x.course == c and pred(x))
               for c in COURSES}
        row['total'] = sum(row.values())
        return row

    gtr_branch_b = sum(1 for x in lessons if x.course == 'gtr' and (
        (x.module or '').endswith('b') or x.id.endswith('test-b')))
    gates = {g: sum(1 for x in lessons if x.gate == g)
             for g in ['selfCheck', 'noEngine', 'camera', 'experimental',
                       'held']}
    cumulative = {}
    for i, last in enumerate(STEP_ORDER):
        ready = set(STEP_ORDER[:i + 1]) | {'A7'}
        cumulative[last] = per_course(lambda x: set(x.steps) <= ready)
    return {
        'lessons': per_course(lambda x: True),
        'studentPath': len(lessons) - gtr_branch_b,
        'shippableWithoutEngine': len(lessons) - gates['held'],
        'fallback': gates,
        'heldByCourse': per_course(lambda x: x.gate == 'held'),
        'dependsOn': {s: per_course(lambda x, s=s: s in x.steps)
                      for s in STEP_ORDER + ['A7']},
        'opensAt': {s: per_course(lambda x, s=s: x.opening_step == s)
                    for s in STEP_ORDER + ['A7']},
        'measuredWhenReady': cumulative,
    }


BANNED = re.compile(r'\b(wrong|yanlış\w*)', re.IGNORECASE)


def _banned_words(value: object) -> list[str]:
    if isinstance(value, str):
        return BANNED.findall(value)
    if isinstance(value, dict):
        return [w for v in value.values() for w in _banned_words(v)]
    if isinstance(value, list):
        return [w for v in value for w in _banned_words(v)]
    return []


def check_content(lessons: list[Lesson], root: Path = CONTENT) -> dict:
    """Tie every content/v1/<course>/<id>.json to its plan row.

    Field shapes are the Dart model's job (test/v1_lesson_content_test.dart);
    this checks only what the plan row fixes: id, title, codes, references,
    safety and the late-engine fallback.
    """
    plan = {x.id: x for x in lessons}
    errors: list[str] = []
    written = {c: 0 for c in COURSES}
    for path in sorted(root.glob('*/*.json')) if root.exists() else []:
        where = str(path.relative_to(root))
        try:
            body = json.loads(path.read_text('utf-8'))
        except json.JSONDecodeError as e:
            errors.append(f'{where}: {e}')
            continue
        lid = body.get('id')
        row = plan.get(lid)
        if row is None:
            errors.append(f'{where}: id {lid!r} is not in the plan')
            continue
        if path.parent.name != row.course or path.stem != lid:
            errors.append(f'{where}: must be {row.course}/{lid}.json')
        title = body.get('title') or {}
        if (title.get('en'), title.get('tr')) != (row.title_en, row.title_tr):
            errors.append(f'{where}: title differs from plan row {row.source}')
        practice = body.get('practice') or {}
        if tuple(practice.get('measurement') or ()) != row.measure:
            errors.append(f'{where}: measurement differs from plan {row.measure}')
        if tuple(practice.get('engineSteps') or ()) != row.steps:
            errors.append(f'{where}: engineSteps differ from plan {row.steps}')
        if body.get('fallback') != row.gate:
            errors.append(f'{where}: fallback must be {row.gate}')
        safety = set(body.get('safety') or ())
        need = COURSE_SAFETY[row.course] | (set(row.refs) & SAFETY)
        if not need <= safety:
            errors.append(f'{where}: safety misses {sorted(need - safety)}')
        kinds = set((body.get('referenceAudio') or {}).get('kinds') or ())
        refs = set(row.refs) & (REF - {'—'})
        metered = any(c.startswith('M') for c in row.measure)
        expected = refs or ({'S'} if metered else set())
        if not expected <= kinds:
            errors.append(f'{where}: referenceAudio misses {sorted(expected - kinds)}')
        for word in _banned_words(body):
            errors.append(f'{where}: use "different note", not {word!r} (§5.4)')
        written[row.course] += 1
    if errors:
        raise LintError('\n'.join(errors))
    written['total'] = sum(written.values())
    return written


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--write', action='store_true')
    args = ap.parse_args(argv)
    try:
        lessons = load()
        got = counts(lessons)
        written = check_content(lessons)
    except LintError as e:
        print(e, file=sys.stderr)
        return 1
    print(f'content/v1 written: {written}', file=sys.stderr)
    text = json.dumps(got, ensure_ascii=False, indent=2) + '\n'
    if args.write:
        PIN.write_text(text, 'utf-8')
    elif args.check:
        if PIN.read_text('utf-8') != text:
            print(f'{PIN.relative_to(APP)} is stale; plan counts changed.\n'
                  'Update 70-motor-bagimliligi.md and rerun with --write.',
                  file=sys.stderr)
            return 1
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
