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

    def test_wrong_fret_changes_chord_quality(self):
        bad = copy.deepcopy(self.course)
        next(s for s in bad["chordShapes"] if s["id"] == "D")["frets6to1"][5] = 1
        self.assertTrue(any("D: chord pitch classes" in item for item in check(bad)))

    def test_movable_major_minor_cards_must_keep_their_chord_quality(self):
        for shape_id in ("G_barre", "Gm_barre", "B_barre", "Bm_barre"):
            with self.subTest(shape_id=shape_id):
                bad = copy.deepcopy(self.course)
                shape = next(s for s in bad["chordShapes"] if s["id"] == shape_id)
                shape["frets6to1"][3] += 1
                self.assertTrue(any(
                    f"{shape_id}: chord pitch classes" in item for item in check(bad)
                ))

    def test_movable_lesson_cannot_show_power_chords(self):
        bad = copy.deepcopy(self.course)
        lesson = next(l for m in bad["modules"] for l in m["lessons"]
                      if l["id"] == "guitar.journey.intermediate.movable_shape")
        lesson["shapeIds"] = ["E5", "A5"]
        self.assertTrue(any("movable_shape: lesson chord shapes" in item
                            for item in check(bad)))

    def test_power_chord_lesson_keeps_its_own_cards(self):
        bad = copy.deepcopy(self.course)
        lesson = next(l for m in bad["modules"] for l in m["lessons"]
                      if l["id"] == "guitar.journey.harmony.power_chords")
        lesson["shapeIds"] = ["G_barre", "Gm_barre"]
        self.assertTrue(any("power_chords: lesson chord shapes" in item
                            for item in check(bad)))

    def test_octave_error_in_tuning_reference_fails(self):
        bad = copy.deepcopy(self.course)
        bad["tuning"][0]["note"] = "E3"
        bad["tuning"][0]["hz"] *= 2
        self.assertTrue(any("tuning note or Hz" in item for item in check(bad)))

    def test_lab_missing_translation_or_reused_task_fails(self):
        bad = copy.deepcopy(self.course)
        lab = bad["modules"][0]["lessons"][0]["learningLab"]
        lab["earTraining"]["tr"] = ""
        lab["drills"][1]["task"] = lab["drills"][0]["task"]
        result = check(bad)
        self.assertTrue(any("translation" in item for item in result))
        self.assertTrue(any("distinct concrete drill" in item for item in result))

    def test_preserve_historical_progress_identity(self):
        bad = copy.deepcopy(self.course)
        bad["contentVersion"] = "reset-old-progress"
        self.assertTrue(any("progress contentVersion" in item for item in check(bad)))

    def test_unreleased_or_invalid_lesson_revision_cannot_reset_progress(self):
        for revision in ("materials_1", "bad|key", "", 17):
            with self.subTest(revision=revision):
                bad = copy.deepcopy(self.course)
                bad["modules"][0]["lessons"][0]["progressRevision"] = revision
                result = check(bad)
                self.assertTrue(any("accepted material release" in item for item in result))
                if revision != "materials_1":
                    self.assertTrue(any("invalid progress revision" in item for item in result))

    def test_lab_cannot_turn_product_dose_into_clinical_or_mastery_gate(self):
        bad = copy.deepcopy(self.course)
        lab = bad["modules"][0]["lessons"][0]["learningLab"]
        lab["suggestedGate"]["enforced"] = True
        lab["drills"][0]["dose_status"] = "scientifically_guaranteed"
        lab["retention"]["schedule_status"] = "guaranteed_spacing_effect"
        result = check(bad)
        self.assertTrue(any("optional product suggestion" in item for item in result))
        self.assertTrue(any("validated prescription" in item for item in result))
        self.assertTrue(any("guaranteed spacing" in item for item in result))

    def test_missing_lab_or_sensor_certification_fails(self):
        bad = copy.deepcopy(self.course)
        del bad["modules"][0]["lessons"][0]["learningLab"]
        bad["modules"][0]["lessons"][1]["learningLab"]["masteryEvidence"] = "camera_certified"
        result = check(bad)
        self.assertTrue(any("learning lab required" in item for item in result))
        self.assertTrue(any("cannot certify sensor mastery" in item for item in result))

    def test_first_read_score_cannot_be_removed_or_have_a_short_bar(self):
        bad = copy.deepcopy(self.course)
        connected = bad["modules"][-1]["lessons"][-1]["learningLab"]["drills"][1]
        del connected["firstReadScore"]
        self.assertTrue(any("must appear once" in item for item in check(bad)))

        bad = copy.deepcopy(self.course)
        connected = bad["modules"][-1]["lessons"][-1]["learningLab"]["drills"][1]
        connected["firstReadScore"]["bars"][0][0]["ticks"] = 1
        self.assertTrue(any("eight ticks" in item for item in check(bad)))

    def test_first_read_staff_events_must_match_both_language_cards(self):
        bad = copy.deepcopy(self.course)
        connected = bad["modules"][-1]["lessons"][-1]["learningLab"]["drills"][1]
        connected["firstReadScore"]["bars"][0][0]["sounding"] = "F4"
        result = check(bad)
        self.assertTrue(any("first-read en card text differs" in item for item in result))
        self.assertTrue(any("first-read tr card text differs" in item for item in result))

    def test_first_read_rejects_isolated_eighths_even_when_bar_is_full(self):
        bad = copy.deepcopy(self.course)
        connected = bad["modules"][-1]["lessons"][-1]["learningLab"]["drills"][1]
        connected["firstReadScore"]["bars"][2] = [
            {"sounding": "G3", "ticks": 2},
            {"sounding": "D4", "ticks": 1},
            {"sounding": "B3", "ticks": 2},
            {"sounding": "C4", "ticks": 1},
            {"sounding": "B3", "ticks": 2},
        ]
        self.assertTrue(any("unpaired eighth" in item for item in check(bad)))


if __name__ == "__main__":
    unittest.main()
