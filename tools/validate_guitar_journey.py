#!/usr/bin/env python3
"""Fail closed on the shipped guitar path's structure and honesty contract."""

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "assets/content/guitar_journey.v1.json"


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
    if len(sources) != 7 or len(course.get("sources", [])) != len(sources) or any(not s.get("url", "").startswith("https://") for s in sources.values()):
        errors.append("source IDs and canonical URLs required")
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
    if len(shapes) != 13:
        errors.append("expected 13 unique example chord shapes")
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
    modules = course.get("modules", [])
    if len(modules) != 10:
        errors.append(f"expected 10 modules, got {len(modules)}")
    seen = set()
    previous = None
    capstones = []
    concrete_steps = set()
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
            if any(sid not in shapes for sid in lesson.get("shapeIds", [])):
                errors.append(f"{lid}: unknown chord shape reference")
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
