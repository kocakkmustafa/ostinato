#!/usr/bin/env python3
"""Fail closed on the shipped guitar path's structure and honesty contract."""

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "assets/content/guitar_journey.v1.json"
SOURCE_IDS = {
    "berklee-beginners", "berklee-fundamentals", "trinity-acoustic",
    "bapam-comfort", "nidcd-hearing", "berklee-notation", "fender-c-major",
    "abrsm-guitar", "rsl-electric", "berklee-chords", "berklee-scales",
    "piano-spacing-study", "music-interleaving-study",
}
SHAPE_PITCH_CLASSES = {
    "Em": {4, 7, 11}, "Am": {9, 0, 4}, "E": {4, 8, 11},
    "A": {9, 1, 4}, "D": {2, 6, 9}, "G": {7, 11, 2},
    "C": {0, 4, 7}, "Dm": {2, 5, 9}, "Fmaj7": {5, 9, 0, 4},
    "A7": {9, 1, 4, 7}, "F": {5, 9, 0}, "E5": {4, 11}, "A5": {9, 4},
    "G_barre": {7, 11, 2}, "Gm_barre": {7, 10, 2},
    "B_barre": {11, 3, 6}, "Bm_barre": {11, 2, 6},
}
EXPECTED_LESSON_SHAPES = {
    "guitar.journey.harmony.power_chords": ["E5", "A5"],
    "guitar.journey.intermediate.movable_shape": [
        "G_barre", "Gm_barre", "B_barre", "Bm_barre",
    ],
}

FIRST_READ_ID = "guitar.journey.independent.next_cycle"
FIRST_READ_PITCHES = {"E4", "F4", "G4", "B3", "C4", "D4", "G3"}
TURKISH_NOTES = {"C": "Do", "D": "Re", "E": "Mi", "F": "Fa", "G": "Sol", "A": "La", "B": "Si"}


def check_first_read_score(score, lesson, drill):
    errors = []
    if (not isinstance(score, dict) or set(score) != {"meter", "ticksPerQuarter", "pitchFrame", "bars"} or
        score.get("meter") != "4/4" or score.get("ticksPerQuarter") != 2 or
        score.get("pitchFrame") != "sounding" or not isinstance(score.get("bars"), list) or
        len(score["bars"]) != 4):
        return ["first-read score: four-bar sounding 4/4 header required"]

    def spelled(note, language):
        return note if language == "en" else TURKISH_NOTES[note[0]] + note[1:]

    card_lines = {"en": [], "tr": []}
    note_count = rest_count = 0
    for number, bar in enumerate(score["bars"], 1):
        if not isinstance(bar, list) or not bar:
            errors.append(f"first-read bar {number}: event list required")
            continue
        total = 0
        bar_valid = True
        entries = {"en": [], "tr": []}
        for event in bar:
            if not isinstance(event, dict) or type(event.get("ticks")) is not int or event["ticks"] not in (1, 2):
                errors.append(f"first-read bar {number}: invalid event ticks")
                bar_valid = False
                continue
            ticks = event["ticks"]
            total += ticks
            duration = "1" if ticks == 2 else "1/2"
            if set(event) == {"rest", "ticks"} and event["rest"] is True and ticks == 2:
                rest_count += 1
                entries["en"].append("Rest(1)")
                entries["tr"].append("Sus(1)")
            elif (set(event) == {"sounding", "ticks"} and
                  isinstance(event["sounding"], str) and event["sounding"] in FIRST_READ_PITCHES):
                note_count += 1
                for language in ("en", "tr"):
                    entries[language].append(f"{spelled(event['sounding'], language)}({duration})")
            else:
                errors.append(f"first-read bar {number}: invalid pitch or rest")
                bar_valid = False
        if total != 8:
            errors.append(f"first-read bar {number}: 4/4 requires eight ticks, got {total}")
        if bar_valid:
            start_tick = 0
            for index, event in enumerate(bar):
                if event["ticks"] == 1:
                    partner_index = index + 1 if start_tick % 2 == 0 else index - 1
                    if (partner_index < 0 or partner_index >= len(bar) or
                        bar[partner_index]["ticks"] != 1 or "sounding" not in bar[partner_index]):
                        errors.append(f"first-read bar {number}: unpaired eighth note at tick {start_tick}")
                start_tick += event["ticks"]
        for language in ("en", "tr"):
            card_lines[language].append(f"{number} | {' '.join(entries[language])}")
    if (note_count, rest_count) != (16, 2):
        errors.append(f"first-read score: expected 16 notes and 2 rests, got {note_count}/{rest_count}")
    for language in ("en", "tr"):
        score_text = "\n".join(card_lines[language])
        task_text = drill.get("task", {}).get(language, "")
        teaching_text = lesson.get("teachingSteps", [{}, {}])[1].get(language, "")
        if score_text not in task_text or score_text not in teaching_text:
            errors.append(f"first-read {language} card text differs from score events")
    return errors


def check(course):
    errors = []

    def require_text(value, path, minimum=12):
        if not isinstance(value, dict) or set(value) != {"en", "tr"}:
            errors.append(f"{path}: exact en/tr copy required")
        elif any(not isinstance(value[lang], str) or len(value[lang].strip()) < minimum for lang in ("en", "tr")):
            errors.append(f"{path}: empty or placeholder translation")

    if course.get("schemaVersion") != 1 or not isinstance(course.get("contentVersion"), str):
        errors.append("versioned course schema required")
    if course.get("id") != "guitar.journey":
        errors.append("unexpected course ID")
    require_text(course.get("title"), "title", 3)
    for key in ("summary", "completionStatement"):
        require_text(course.get(key), key)
    sources = {s.get("id"): s for s in course.get("sources", [])}
    if set(sources) != SOURCE_IDS or len(course.get("sources", [])) != len(sources) or any(not s.get("url", "").startswith("https://") for s in sources.values()):
        errors.append("source IDs and canonical URLs required")
    if course.get("contentVersion") != "2026.09.26.1":
        errors.append("stable lesson progress contentVersion must be preserved")
    if course.get("curriculumRevision") != "2026.09.27.comprehensive.1":
        errors.append("comprehensive curriculum revision required")
    require_text(course.get("progressSemantics"), "progressSemantics")
    expected_tuning = [(6, "E2", 40), (5, "A2", 45), (4, "D3", 50),
                       (3, "G3", 55), (2, "B3", 59), (1, "E4", 64)]
    tuning = course.get("tuning", [])
    if len(tuning) != 6:
        errors.append("six standard tuning references required")
    else:
        for got, (number, note, midi) in zip(tuning, expected_tuning):
            expected_hz = 440 * 2 ** ((midi - 69) / 12)
            if (got.get("string") != number or got.get("note") != note or
                not math.isclose(got.get("hz", 0), expected_hz, abs_tol=.01)):
                errors.append(f"string {number}: tuning note or Hz mismatch")
    shapes = {s.get("id"): s for s in course.get("chordShapes", [])}
    if set(shapes) != set(SHAPE_PITCH_CLASSES):
        errors.append("expected 17 unique example chord shapes")
    for sid, shape in shapes.items():
        require_text(shape.get("label"), f"shape.{sid}.label", 3)
        frets = shape.get("frets6to1", [])
        fingers = shape.get("exampleFingers6to1", [])
        if len(frets) != 6 or len(fingers) != 6 or any(
            (fret is not None and (not isinstance(fret, int) or not 0 <= fret <= 12)) or
            (finger is not None and (not isinstance(finger, int) or not 0 <= finger <= 4)) or
            ((fret is None) != (finger is None)) or (fret == 0 and finger != 0)
            for fret, finger in zip(frets, fingers)
        ):
            errors.append(f"{sid}: invalid fret/finger example")
        elif sid in SHAPE_PITCH_CLASSES:
            sounding = {(open_midi + fret) % 12 for open_midi, fret in
                        zip([40, 45, 50, 55, 59, 64], frets) if fret is not None}
            if sounding != SHAPE_PITCH_CLASSES[sid]:
                errors.append(f"{sid}: chord pitch classes do not match its quality")
    modules = course.get("modules", [])
    if len(modules) != 10:
        errors.append(f"expected 10 modules, got {len(modules)}")
    seen = set()
    previous = None
    capstones = []
    concrete_steps = set()
    enriched_copy = {key: set() for key in ("objective", "practice", "selfCheck", "commonError", "adaptation")}
    all_drill_ids = set()
    first_read_locations = []
    for module in modules:
        mid = module.get("id", "")
        if mid in seen or not mid.startswith("guitar.journey."):
            errors.append(f"duplicate or invalid module ID {mid}")
        seen.add(mid)
        require_text(module.get("title"), f"{mid}.title", 3)
        require_text(module.get("goal"), f"{mid}.goal")
        lessons = module.get("lessons", [])
        if len(lessons) != 6:
            errors.append(f"{mid}: expected 6 lessons")
        for lesson in lessons:
            lid = lesson.get("id", "")
            if "progressRevision" in lesson:
                revision = lesson["progressRevision"]
                if not isinstance(revision, str) or re.fullmatch(r"[A-Za-z0-9._-]{1,64}", revision) is None:
                    errors.append(f"{lid}: invalid progress revision")
                # No required audio task, approved media and device receipt is
                # in the shipped course yet. Fail closed until that contract
                # is validated here rather than resetting historical progress.
                errors.append(f"{lid}: progress revision requires an accepted material release")
            if lid in seen or not lid.startswith(mid + "."):
                errors.append(f"duplicate or invalid lesson ID {lid}")
            seen.add(lid)
            if lesson.get("prerequisiteIds") != ([] if previous is None else [previous]):
                errors.append(f"{lid}: unreachable, cyclic or skipped predecessor")
            previous = lid
            if not isinstance(lesson.get("minutes"), int) or lesson["minutes"] < 5:
                errors.append(f"{lid}: invalid duration")
            require_text(lesson.get("title"), f"{lid}.title", 3)
            for key in ("objective", "practice", "selfCheck", "commonError", "adaptation", "stopSignal"):
                require_text(lesson.get(key), f"{lid}.{key}")
                if key in enriched_copy and isinstance(lesson.get(key), dict):
                    value = lesson[key].get("en", "")
                    if value in enriched_copy[key]:
                        errors.append(f"{lid}: repeated generic {key}")
                    enriched_copy[key].add(value)
            steps = lesson.get("teachingSteps", [])
            if len(steps) < 2:
                errors.append(f"{lid}: two teaching steps required")
            for i, step in enumerate(steps):
                require_text(step, f"{lid}.teachingSteps[{i}]")
            if len(steps) > 1 and isinstance(steps[1], dict):
                detail = steps[1].get("en", "")
                if detail in concrete_steps:
                    errors.append(f"{lid}: repeated generic second teaching step")
                concrete_steps.add(detail)
            if lesson.get("measurementMode") != "self_report_only":
                errors.append(f"{lid}: sensor scoring lacks evidence")
            refs = lesson.get("sourceIds", [])
            if not refs or any(ref not in sources for ref in refs):
                errors.append(f"{lid}: missing source reference")
            lab = lesson.get("learningLab")
            if not isinstance(lab, dict):
                errors.append(f"{lid}: learning lab required")
            else:
                for key in ("technicalFocus", "earTraining", "sensorBoundary", "transfer"):
                    require_text(lab.get(key), f"{lid}.learningLab.{key}")
                if lab.get("masteryEvidence") != "self_report_only":
                    errors.append(f"{lid}: lab cannot certify sensor mastery")
                gate = lab.get("suggestedGate", {})
                if gate.get("enforced") is not False or gate.get("status") != "original_product_benchmark_not_validated_skill_certificate":
                    errors.append(f"{lid}: practice gate must remain an optional product suggestion")
                if lab.get("sourceIds") != refs:
                    errors.append(f"{lid}: lab source binding mismatch")
                criteria = lab.get("masteryCriteria", [])
                if not criteria:
                    errors.append(f"{lid}: concrete self-check criteria required")
                for criterion in criteria:
                    require_text(criterion, f"{lid}.learningLab.masteryCriteria")
                correction = lab.get("errorCorrection", {})
                for key in ("symptom", "action"):
                    require_text(correction.get(key), f"{lid}.learningLab.errorCorrection.{key}")
                if correction.get("possibleCauseStatus") != "instructional_hypothesis_not_diagnosis":
                    errors.append(f"{lid}: correction cannot claim medical diagnosis")
                retention = lab.get("retention", {})
                require_text(retention.get("task"), f"{lid}.learningLab.retention.task")
                if retention.get("schedule_status") != "original_optional_review_policy_not_guaranteed_spacing_effect":
                    errors.append(f"{lid}: unsupported guaranteed spacing effect")
                drills = lab.get("drills", [])
                if len(drills) != 3 or [d.get("stage") for d in drills] != ["foundation", "connected", "transfer"]:
                    errors.append(f"{lid}: three ordered lab stages required")
                tasks = set()
                for drill in drills:
                    did = drill.get("id")
                    if did in all_drill_ids or did != f"{lid}.lab.{drill.get('stage')}":
                        errors.append(f"{lid}: invalid or duplicate drill ID")
                    all_drill_ids.add(did)
                    require_text(drill.get("task"), f"{did}.task")
                    if isinstance(drill.get("task"), dict):
                        tasks.add(drill["task"].get("en"))
                    if "firstReadScore" in drill:
                        first_read_locations.append((lid, drill.get("stage")))
                        errors.extend(check_first_read_score(drill["firstReadScore"], lesson, drill))
                    dose = drill.get("suggested_minutes_range", [])
                    if len(dose) != 2 or any(type(v) is not int for v in dose) or not 1 <= dose[0] <= dose[1] <= 20:
                        errors.append(f"{did}: invalid flexible practice duration")
                    if drill.get("dose_status") != "original_flexible_product_pedagogy_not_scientifically_validated":
                        errors.append(f"{did}: dose cannot claim validated prescription")
                    if not 1 <= drill.get("suggested_rounds", 0) <= 5:
                        errors.append(f"{did}: invalid suggested rounds")
                if len(tasks) != 3:
                    errors.append(f"{lid}: distinct concrete drill tasks required")
            if any(sid not in shapes for sid in lesson.get("shapeIds", [])):
                errors.append(f"{lid}: unknown chord shape reference")
            expected_shapes = EXPECTED_LESSON_SHAPES.get(lid)
            if expected_shapes is not None and lesson.get("shapeIds") != expected_shapes:
                errors.append(f"{lid}: lesson chord shapes do not match its teaching")
            brief = lesson.get("mediaBrief", {})
            if brief.get("status") != "planned_original_ai_asset_teacher_review_required":
                errors.append(f"{lid}: unreviewed media cannot be marked ready")
            for key in ("shot", "sequence", "tempo", "errorToShow", "adaptation", "safety", "captions"):
                require_text(brief.get(key), f"{lid}.mediaBrief.{key}")
            if len(brief.get("verification", "")) < 60:
                errors.append(f"{lid}: missing human media acceptance")
            if lesson.get("capstone"):
                capstones.append((lid, lesson["capstone"]))
    if len(seen) != 70:
        errors.append(f"expected 70 unique module/lesson IDs, got {len(seen)}")
    if first_read_locations != [(FIRST_READ_ID, "connected")]:
        errors.append("first-read score must appear once in lesson 60 connected drill")
    if len(capstones) != 2 or any(kind != "original_performance" for _, kind in capstones):
        errors.append("exactly two original performance capstones required")
    return errors


def main():
    course = json.loads(PATH.read_text())
    errors = check(course)
    if errors:
        raise SystemExit("\n".join(errors))
    print("guitar journey valid: 10 modules, 60 original bilingual lessons, 2 capstones")


if __name__ == "__main__":
    main()
