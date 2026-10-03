"""Regression checks for the privacy gate's measured PASS declaration."""

import contextlib
import copy
import io
import plistlib
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import validate_privacy_manifest as validator


class PrivacyManifestSummaryTest(unittest.TestCase):
    def setUp(self):
        manifest = Path(__file__).resolve().parent.parent / "ios/Runner/PrivacyInfo.xcprivacy"
        self.current_manifest = plistlib.loads(manifest.read_bytes())

    def run_gate(self, manifest, source="final x = 1;"):
        in_memory_manifest = Mock()
        in_memory_manifest.exists.return_value = True
        in_memory_manifest.read_bytes.return_value = plistlib.dumps(manifest)
        shipped_source = Mock()
        shipped_source.read_text.return_value = source
        output = io.StringIO()
        with patch.object(validator, "MANIFEST", in_memory_manifest), \
                patch.object(validator, "_shipped_sources", return_value=[shipped_source] * 20) as source_scan, \
                patch.object(validator.Path, "read_text", return_value="dependencies:\n"), \
                contextlib.redirect_stdout(output):
            result = validator.main()
        self.source_scan_called = source_scan.called
        return result, output.getvalue()

    def assert_schema_rejected(self, manifest, field):
        result, output = self.run_gate(manifest)
        self.assertEqual(result, 1)
        self.assertIn("ŞEMA", output)
        self.assertIn(field, output)
        self.assertNotIn("✅ gizlilik manifesti", output)
        self.assertFalse(self.source_scan_called)

    def accessed_entry(self):
        return {
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
        }

    def test_account_manifest_reports_all_six_collected_types(self):
        self.assertEqual(len(self.current_manifest["NSPrivacyCollectedDataTypes"]), 6)
        result, output = self.run_gate(self.current_manifest)
        self.assertEqual(result, 0)
        self.assertIn("toplama 6 veri türü", output)
        self.assertNotIn("toplama yok", output)

    def test_empty_collection_is_reported_as_zero(self):
        manifest = copy.deepcopy(self.current_manifest)
        manifest["NSPrivacyCollectedDataTypes"] = []
        result, output = self.run_gate(manifest)
        self.assertEqual(result, 0)
        self.assertIn("toplama 0 veri türü", output)

    def test_used_declared_api_is_reported_as_one_category(self):
        manifest = copy.deepcopy(self.current_manifest)
        manifest["NSPrivacyAccessedAPITypes"] = [{
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
        }]
        result, output = self.run_gate(manifest, "UserDefaults.standard")
        self.assertEqual(result, 0)
        self.assertIn("required-reason API 1 kategori", output)
        self.assertNotIn("required-reason API yok", output)

    def test_tracking_declaration_is_not_reported_as_absent(self):
        manifest = copy.deepcopy(self.current_manifest)
        manifest["NSPrivacyTracking"] = True
        result, output = self.run_gate(manifest)
        self.assertEqual(result, 0)
        self.assertIn("beyan: izleme var", output)
        self.assertNotIn("beyan: izleme yok", output)

    def test_undeclared_api_still_rejects_without_pass_summary(self):
        result, output = self.run_gate(self.current_manifest, "UserDefaults.standard")
        self.assertEqual(result, 1)
        self.assertIn("NSPrivacyAccessedAPICategoryUserDefaults", output)
        self.assertNotIn("✅ gizlilik manifesti", output)

    def test_top_level_must_be_a_dictionary(self):
        for value in ("abcdef", [], 1):
            with self.subTest(value=value):
                self.assert_schema_rejected(value, "üst düzey")

    def test_missing_required_top_level_fields_reject_before_scan(self):
        for field in self.current_manifest:
            with self.subTest(field=field):
                manifest = copy.deepcopy(self.current_manifest)
                del manifest[field]
                self.assert_schema_rejected(manifest, field)

    def test_tracking_requires_an_exact_boolean(self):
        for value in ("false", 0, 1):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                manifest["NSPrivacyTracking"] = value
                self.assert_schema_rejected(manifest, "NSPrivacyTracking")

    def test_array_fields_reject_scalar_and_dictionary_values(self):
        for field in ("NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes",
                      "NSPrivacyAccessedAPITypes"):
            for value in ("abcdef", {}, 1):
                with self.subTest(field=field, value=value):
                    manifest = copy.deepcopy(self.current_manifest)
                    manifest[field] = value
                    self.assert_schema_rejected(manifest, field)

    def test_tracking_domains_require_nonempty_strings(self):
        for value in ([""], [" "], [7]):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                manifest["NSPrivacyTrackingDomains"] = value
                self.assert_schema_rejected(manifest, "NSPrivacyTrackingDomains")

    def test_collected_entries_require_complete_dictionaries(self):
        for value in ([{}], ["abcdef"], [[]]):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                manifest["NSPrivacyCollectedDataTypes"] = value
                self.assert_schema_rejected(manifest, "NSPrivacyCollectedDataTypes")

    def test_collected_type_requires_a_nonempty_string(self):
        for value in ("", " ", 7, []):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                manifest["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataType"] = value
                self.assert_schema_rejected(manifest, "NSPrivacyCollectedDataType")

    def test_collected_flags_require_exact_booleans(self):
        for field in ("NSPrivacyCollectedDataTypeLinked", "NSPrivacyCollectedDataTypeTracking"):
            for value in ("false", 0, 1):
                with self.subTest(field=field, value=value):
                    manifest = copy.deepcopy(self.current_manifest)
                    manifest["NSPrivacyCollectedDataTypes"][0][field] = value
                    self.assert_schema_rejected(manifest, field)

    def test_collected_purposes_require_a_nonempty_string_array(self):
        for value in ("AppFunctionality", [], [""], [" "], [7], ["purpose", ""]):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                manifest["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataTypePurposes"] = value
                self.assert_schema_rejected(manifest, "NSPrivacyCollectedDataTypePurposes")

    def test_duplicate_collected_types_reject(self):
        manifest = copy.deepcopy(self.current_manifest)
        manifest["NSPrivacyCollectedDataTypes"].append(
            copy.deepcopy(manifest["NSPrivacyCollectedDataTypes"][0]))
        self.assert_schema_rejected(manifest, "NSPrivacyCollectedDataType")

    def test_accessed_entries_require_complete_dictionaries(self):
        for value in ([{}], ["abcdef"], [[]]):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                manifest["NSPrivacyAccessedAPITypes"] = value
                self.assert_schema_rejected(manifest, "NSPrivacyAccessedAPITypes")

    def test_accessed_type_requires_a_nonempty_string(self):
        for value in ("", " ", 7, []):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                entry = self.accessed_entry()
                entry["NSPrivacyAccessedAPIType"] = value
                manifest["NSPrivacyAccessedAPITypes"] = [entry]
                self.assert_schema_rejected(manifest, "NSPrivacyAccessedAPIType")

    def test_accessed_reasons_require_a_nonempty_string_array(self):
        for value in ("CA92.1", [], [""], [" "], [7], ["CA92.1", ""]):
            with self.subTest(value=value):
                manifest = copy.deepcopy(self.current_manifest)
                entry = self.accessed_entry()
                entry["NSPrivacyAccessedAPITypeReasons"] = value
                manifest["NSPrivacyAccessedAPITypes"] = [entry]
                self.assert_schema_rejected(manifest, "NSPrivacyAccessedAPITypeReasons")

    def test_duplicate_accessed_types_reject(self):
        manifest = copy.deepcopy(self.current_manifest)
        manifest["NSPrivacyAccessedAPITypes"] = [self.accessed_entry(), self.accessed_entry()]
        self.assert_schema_rejected(manifest, "NSPrivacyAccessedAPIType")


if __name__ == "__main__":
    unittest.main()
