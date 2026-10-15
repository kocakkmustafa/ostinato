"""Store keyword byte boundaries and other fields' character limits."""

import copy
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import validate_store_listing_limits as validator


class StoreListingLimitsTest(unittest.TestCase):
    def errors_for(self, keywords):
        listing = copy.deepcopy(validator._ok_listing())
        listing['appStore']['keywords'] = keywords
        return validator.check(listing, validator.BASE_LIMITS)

    def test_ascii_keywords_at_100_bytes_are_accepted(self):
        self.assertEqual(self.errors_for('a' * 100), [])

    def test_ascii_keywords_over_100_bytes_are_rejected(self):
        self.assertTrue(any('appStore/keywords' in e for e in self.errors_for('a' * 101)))

    def test_multibyte_keywords_at_100_bytes_are_accepted(self):
        self.assertEqual(self.errors_for('ü' * 50), [])

    def test_multibyte_keywords_at_102_bytes_are_rejected(self):
        errors = self.errors_for('ü' * 51)
        self.assertEqual(len(errors), 1)
        self.assertIn('appStore/keywords', errors[0])
        self.assertIn('102 UTF-8 byte', errors[0])
        self.assertIn('100 (+2)', errors[0])

    def test_commas_count_toward_the_keyword_byte_limit(self):
        self.assertEqual(self.errors_for('ü' * 49 + ',a'), [])
        self.assertTrue(self.errors_for('ü' * 49 + ',ü'))

    def test_other_fields_keep_character_limits(self):
        listing = copy.deepcopy(validator._ok_listing())
        listing['appStore']['name'] = 'ü' * 30
        listing['playStore']['shortDescription'] = 'ğ' * 80
        self.assertEqual(validator.check(listing, validator.BASE_LIMITS), [])
        listing['appStore']['name'] += 'ü'
        errors = validator.check(listing, validator.BASE_LIMITS)
        self.assertEqual(len(errors), 1)
        self.assertIn('31 karakter', errors[0])

    def run_main(self, turkish_keywords='ü' * 50, missing_turkish=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            english = root / 'listing.json'
            turkish = root / 'listing.tr-TR.json'
            limits = root / 'limits.md'
            limits.write_text('\n'.join(
                f'| `{key}` | **{value}** |' for key, value in validator.BASE_LIMITS.items()),
                encoding='utf-8')
            listing = validator._ok_listing()
            english.write_text(json.dumps(listing), encoding='utf-8')
            listing['appStore']['keywords'] = turkish_keywords
            if not missing_turkish:
                turkish.write_text(json.dumps(listing), encoding='utf-8')
            output = io.StringIO()
            with patch.object(validator, 'LISTINGS', (english, turkish)), \
                    patch.object(validator, 'LIMITS_MD', limits), \
                    patch.object(validator.sys, 'argv', ['validator']), \
                    contextlib.redirect_stdout(output):
                result = validator.main()
            return result, output.getvalue()

    def test_default_command_checks_both_locales(self):
        result, output = self.run_main()
        self.assertEqual(result, 0)
        self.assertIn('listing.json MEKANİK', output)
        self.assertIn('listing.tr-TR.json MEKANİK', output)

    def test_default_command_rejects_turkish_keyword_overflow(self):
        result, output = self.run_main('ü' * 51)
        self.assertEqual(result, 1)
        self.assertIn('listing.tr-TR.json: ⛔ UZUNLUK', output)
        self.assertIn('102 UTF-8 byte', output)

    def test_missing_turkish_listing_does_not_silently_pass(self):
        result, output = self.run_main(missing_turkish=True)
        self.assertEqual(result, 1)
        self.assertIn('beklenen dosya yok:', output)
        self.assertIn('listing.tr-TR.json', output)


if __name__ == '__main__':
    unittest.main()
