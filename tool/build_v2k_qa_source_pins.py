#!/usr/bin/env python3
"""Rebuild Ostinato's closed, source-only v2k QA catalog."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parents[2]
SOURCE = ROOT / "ops/tools/motion_courses/contracts/v2k/source_pins_v1/source-pins.json"
MANIFEST = ROOT / "ops/tools/motion_courses/contracts/v2k/production-manifest.json"
COURSE = APP / "assets/content/guitar_journey.v1.json"
OUTPUT = APP / "assets/motion_content/ostinato_source_pins_v2k.json"
SOURCE_SHA = "791bfea8e1479307794bcf8799cf703a7a840bcd3058c1a0d7fdf065d32d8594"
MANIFEST_SHA = "d887683c9a9b9bdb8d4ab7c51cdc5a5b4b4de6a918079e4cfd9cf543e9751e60"
PROOF_SHA = "dec615e14881b86b7676e1157f63b8bf6269026d856e59f2ee3a65d7f97e512a"
COURSE_SHA = "bf553f62d91927be66b88210103b982bed17c357b4b643cb9b50f57a3e105a18"
OUTPUT_SHA = "fc838a2276cae3146951b63004ad9fba4075cfc7fae0397fc602291762b7074f"


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def read_exact(path: Path, expected: str) -> bytes:
    require(path.is_file() and not path.is_symlink(), f"missing or symlinked input: {path}")
    raw = path.read_bytes()
    require(sha(raw) == expected, f"SHA drift: {path}")
    return raw


def identity(catalog: dict, lesson: dict, scene: dict, variant: dict) -> dict:
    return {
        "manifestSHA256": catalog["manifestSHA256"],
        "app": lesson["app"],
        "courseSourceSHA256": lesson["courseSourceSHA256"],
        "lessonId": lesson["lessonId"],
        "lessonCanonicalSHA256": lesson["lessonCanonicalSHA256"],
        "assetId": lesson["assetId"],
        "sceneId": scene["sceneId"],
        "variantStem": variant["stem"],
        "productionSpecSHA256": scene["productionSpecSHA256"],
        "sourceCueSHA256": scene["sourceCueSHA256"],
        "idempotencyKey": scene["idempotencyKey"],
        "productionState": scene["productionState"],
    }


def expected_bytes() -> bytes:
    catalog = json.loads(read_exact(SOURCE, SOURCE_SHA))
    manifest = json.loads(read_exact(MANIFEST, MANIFEST_SHA))
    read_exact(COURSE, COURSE_SHA)
    require(catalog["kind"] == "MOTION_MEDIA_V2K_SOURCE_PINS_V1"
            and catalog["state"] == "CLOSED_PREPRODUCTION_SOURCE_MEMBERSHIP_ONLY"
            and catalog["manifestSHA256"] == MANIFEST_SHA
            and catalog["sourceProofSHA256"] == PROOF_SHA
            and catalog["visible"] is False and catalog["releaseEligible"] is False
            and catalog["progressEffect"] == 0 and catalog["approvedProductionTrustRoot"] is False
            and catalog["counts"]["variants"] == 2456
            and catalog["counts"]["generatedMedia"] == catalog["counts"]["qualifiedMedia"] == 0,
            "global v2k closed catalog drift")
    require(manifest["sourceProofReceiptSHA256"] == PROOF_SHA
            and manifest["liveLissomPromotionVerified"] is True
            and manifest["releaseEligible"] is False
            and manifest["courseSourcePins"] == catalog["courseSourcePins"], "manifest/proof/course link")
    require(catalog["courseSourcePins"]["ostinato"] == {
        "path": "ventures/ostinato/app/assets/content/guitar_journey.v1.json", "sha256": COURSE_SHA,
    }, "live Ostinato course pin")
    lessons = [r for r in catalog["lessons"] if r["app"] == "ostinato"]
    require(len(lessons) == len({r["lessonId"] for r in lessons}) == 60, "Ostinato lesson set")
    scenes: set[str] = set()
    stems: set[str] = set()
    pins: set[str] = set()
    for lesson in lessons:
        require(lesson["membershipStatus"] == "SOURCE_PINNED_TEST_ONLY"
                and lesson["courseSourceSHA256"] == COURSE_SHA, "Ostinato lesson policy")
        for scene in lesson["scenes"]:
            require(scene["sceneId"] not in scenes
                    and scene["productionState"] == "PREPRODUCTION_UNGENERATED", "Ostinato scene policy")
            scenes.add(scene["sceneId"])
            for variant in scene["variants"]:
                pin = sha(canonical(identity(catalog, lesson, scene, variant)))
                require(variant["stem"] not in stems and pin not in pins
                        and variant["sourcePinSHA256"] == pin, "Ostinato source pin identity")
                stems.add(variant["stem"])
                pins.add(pin)
    require(len(scenes) == len(stems) == len(pins) == 420
            and not any(h["app"] == "ostinato" for h in catalog["holds"]), "Ostinato 420/no HOLD")
    projection = {
        "schemaVersion": 1,
        "kind": "OSTINATO_V2K_SOURCE_PINS_QA_ONLY",
        "sourceCatalogSHA256": SOURCE_SHA,
        "manifestSHA256": MANIFEST_SHA,
        "sourceProofSHA256": PROOF_SHA,
        "courseSourceSHA256": COURSE_SHA,
        "counts": {"lessons": 60, "scenes": 420, "variants": 420,
                   "generatedMedia": 0, "qualifiedMedia": 0},
        "lessons": lessons,
        "visible": False,
        "releaseEligible": False,
        "progressEffect": 0,
    }
    raw = (json.dumps(projection, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()
    require(sha(raw) == OUTPUT_SHA, "Ostinato projection SHA drift")
    return raw


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    raw = expected_bytes()
    if args.write:
        require(not OUTPUT.exists(), "versioned output exists; use --check")
        OUTPUT.write_bytes(raw)
    else:
        require(OUTPUT.is_file() and not OUTPUT.is_symlink() and OUTPUT.read_bytes() == raw,
                "Ostinato app projection output drift")
    print("PASS_OSTINATO_V2K_CLOSED_QA_60_420")


if __name__ == "__main__":
    main()
