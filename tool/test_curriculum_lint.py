"""Negative controls for the v1 curriculum plan linter; no SDK required."""
from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import curriculum_lint as lint


class CurriculumLintTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        for name in lint.COURSE_FILES.values():
            shutil.copy(lint.PLAN / name, self.tmp / name)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp)

    def edit(self, name: str, old: str, new: str) -> None:
        path = self.tmp / name
        text = path.read_text('utf-8')
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, 1), 'utf-8')

    def reject(self, pattern: str) -> None:
        with self.assertRaisesRegex(lint.LintError, pattern):
            lint.load(self.tmp)

    def test_plan_matches_pinned_counts(self) -> None:
        self.assertEqual(lint.main(['--check']), 0)
        counts = lint.counts(lint.load())
        self.assertEqual(counts['lessons']['total'], 690)
        self.assertEqual(counts['studentPath'], 671)
        self.assertEqual(counts['shippableWithoutEngine'], 616)

    def test_duplicate_id_is_rejected(self) -> None:
        self.edit('40-kulak-muzisyenlik.md', '| ear-s1-m01-02 |', '| ear-s1-m01-01 |')
        self.reject('duplicate id ear-s1-m01-01')

    def test_unknown_codes_are_rejected(self) -> None:
        self.edit('40-kulak-muzisyenlik.md', '| M | A3 | SE |', '| X | A3 | SE |')
        self.reject("measurement 'X'")
        self.tearDown(); self.setUp()
        self.edit('40-kulak-muzisyenlik.md', '| M | A3 | SE |', '| M | A9 | SE |')
        self.reject("engine step 'A9'")
        self.tearDown(); self.setUp()
        self.edit('40-kulak-muzisyenlik.md', '| M | A3 | SE |', '| M | A3 | ZZ |')
        self.reject("ref/safety code 'ZZ'")

    def test_heading_count_must_match_rows(self) -> None:
        self.edit('40-kulak-muzisyenlik.md',
                  'Pulse and tempo (6)', 'Pulse and tempo (7)')
        self.reject('m01 heading says 7, rows 6')

    def test_lesson_must_sit_under_its_module(self) -> None:
        self.edit('40-kulak-muzisyenlik.md', '| ear-s1-m01-02 |', '| ear-s1-m02-99 |')
        self.reject('ear-s1-m02-99 is under module m01')

    def test_a0_only_for_screen_or_self_check(self) -> None:
        self.edit('40-kulak-muzisyenlik.md', '| D | A0 | — | — |', '| M | A0 | — | — |')
        self.reject('A0 iff measurement is D/Ö only')

    def test_title_needs_both_languages(self) -> None:
        self.edit('40-kulak-muzisyenlik.md', 'Find the pulse / Vuruşu bul', 'Find the pulse')
        self.reject('title needs "EN / TR"')

    def test_content_must_match_plan_row(self) -> None:
        lessons = lint.load()
        content = self.tmp / 'content'
        (content / 'ear').mkdir(parents=True)
        src = lint.CONTENT / 'ear' / 'ear-s1-m01-03.json'
        body = src.read_text('utf-8')
        target = content / 'ear' / 'ear-s1-m01-03.json'
        target.write_text(body, 'utf-8')
        self.assertEqual(lint.check_content(lessons, content)['ear'], 1)
        for old, new, pattern in [
            ('"Faster or slower?"', '"Faster?"', 'title differs'),
            ('"noEngine"', '"held"', 'fallback must be noEngine'),
            ('"A0"', '"A3"', 'engineSteps differ'),
            ('"Ç", "E1"', '"Ç"', "safety misses \\['E1'\\]"),
            ('Compare only the beat.', 'The wrong answer is busier.',
             'not \'wrong\''),
        ]:
            target.write_text(body.replace(old, new, 1), 'utf-8')
            with self.assertRaisesRegex(lint.LintError, pattern):
                lint.check_content(lessons, content)

    def test_fallback_classes_follow_contract(self) -> None:
        lessons = {x.id: x for x in lint.load()}
        self.assertEqual(lessons['gtr-s1-m01-04'].gate, 'held')       # M!
        self.assertEqual(lessons['gtr-s1-m02-02'].gate, 'selfCheck')  # M
        self.assertEqual(lessons['ear-s1-m01-03'].gate, 'noEngine')   # D
        self.assertEqual(lessons['gtr-s1-m02-02'].opening_step, 'A3')


if __name__ == '__main__':
    unittest.main()
