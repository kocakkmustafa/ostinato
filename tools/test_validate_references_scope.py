"""Regression for optional guitar observer versus legacy posture setup refs."""
import unittest
import validate_references as refs


class ReferenceScopeTests(unittest.TestCase):
    def test_observer_floor_does_not_claim_legacy_setup_is_live(self):
        self.assertEqual(refs.RUNTIME_REFS['setup.roomFloorDb']['status'], 'blocked')
        self.assertEqual(refs.sweep(), [])

    def test_unscoped_observer_would_be_detected_as_a_false_setup_promotion(self):
        spec = refs.RUNTIME_REFS['setup.roomFloorDb']
        saved = spec['excludedProducerPaths']
        try:
            spec['excludedProducerPaths'] = []
            self.assertTrue(any('setup.roomFloorDb' in p and 'ÜRETİCİSİ' in p for p in refs.sweep()))
        finally:
            spec['excludedProducerPaths'] = saved


if __name__ == '__main__':
    unittest.main()
