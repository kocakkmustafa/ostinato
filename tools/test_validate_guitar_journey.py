import copy
import json
import unittest

from tools.validate_guitar_journey import PATH, check


class GuitarJourneyValidationTest(unittest.TestCase):
    def setUp(self):
        self.course = json.loads(PATH.read_text())

    def test_shipped_course_passes(self):
        self.assertEqual(check(self.course), [])

    def test_missing_translation_or_source_fails(self):
        bad = copy.deepcopy(self.course)
        lesson = bad["modules"][0]["lessons"][0]
        lesson["practice"]["tr"] = ""
        lesson["sourceIds"] = ["missing"]
        result = check(bad)
        self.assertTrue(any("translation" in item for item in result))
        self.assertTrue(any("source" in item for item in result))

    def test_skipped_predecessor_or_sensor_claim_fails(self):
        bad = copy.deepcopy(self.course)
        lesson = bad["modules"][0]["lessons"][1]
        lesson["prerequisiteIds"] = []
        lesson["measurementMode"] = "audio_verified"
        result = check(bad)
        self.assertTrue(any("predecessor" in item for item in result))
        self.assertTrue(any("sensor scoring" in item for item in result))

    def test_duplicate_teaching_filler_fails(self):
        bad = copy.deepcopy(self.course)
        lessons = bad["modules"][0]["lessons"]
        lessons[1]["teachingSteps"][1] = lessons[0]["teachingSteps"][1]
        self.assertTrue(any("generic second" in item for item in check(bad)))


if __name__ == "__main__":
    unittest.main()
