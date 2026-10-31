"""Negative controls for the message-id table generator; no SDK required."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import build_message_ids as ids


class BuildMessageIdsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.text = ids.TABLE.read_text('utf-8')

    def test_checked_in_table_is_reproduced(self) -> None:
        self.assertEqual(ids.check(self.text), [])

    def test_known_pair_keeps_its_id(self) -> None:
        self.assertEqual(ids.message_id('Bass', 'Fa'), '00214a2c61b8d1a2')

    def test_tampered_id_is_rejected(self) -> None:
        bad = self.text.replace('"00214a2c61b8d1a2",', '"00214a2c61b8d1a3",', 1)
        self.assertIn('00214a2c61b8d1a3: id does not match sha256 of its pair',
                      ids.check(bad))

    def test_hand_edit_is_rejected(self) -> None:
        bad = self.text.replace('};\n', '  // note\n};\n', 1)
        with self.assertRaises(ValueError):
            ids.check(bad)

    def test_escapes_round_trip(self) -> None:
        pairs, plural = ids.parse(self.text)
        en, tr = 'Say "do"\nthen $1 \\ ok', 'Söyle "do"\nsonra $1 \\ tamam'
        pairs[(en, tr)] = ids.message_id(en, tr)
        again, _ = ids.parse(ids.render(pairs, plural))
        self.assertEqual(again[(en, tr)], ids.message_id(en, tr))

    def test_pending_lists_new_ids_and_missing_locales(self) -> None:
        pairs, _ = ids.parse(self.text)
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, 'a.json').write_text(json.dumps(
                {'title': {'en': 'Bass', 'tr': 'Fa'},
                 'goal': {'en': 'Brand new', 'tr': 'Yepyeni'}}), 'utf-8')
            out = ids.pending(pairs, ids.source_pairs(Path(tmp)))
        new = ids.message_id('Brand new', 'Yepyeni')
        self.assertEqual(list(out['newIds']), [new])
        self.assertEqual(len(out['missingTranslations']), 12)
        self.assertIn(new, out['missingTranslations']['de'])
        self.assertNotIn('00214a2c61b8d1a2', out['missingTranslations']['de'])


if __name__ == '__main__':
    unittest.main()
