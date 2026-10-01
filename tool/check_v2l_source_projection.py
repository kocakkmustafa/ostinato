#!/usr/bin/env python3
"""Check Ostinato's app-owned v2l source identities without workspace ops.

The assets describe ungenerated demonstration scenes. They do not grant
playback, course credit, media rights, model accuracy, or release approval.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from pathlib import Path


APP = Path(__file__).absolute().parent.parent
INPUTS = {
    "course": Path("assets/content/guitar_journey.v1.json"),
    "slice": Path("assets/motion_content/ostinato.source-slice.v1.json"),
    "projection": Path("assets/motion_content/ostinato.source-projection.v1.json"),
    "qa": Path("assets/motion_content/ostinato_source_pins_v2k.json"),
    "pubspec": Path("pubspec.yaml"),
}
PINS = {
    "course": "bf553f62d91927be66b88210103b982bed17c357b4b643cb9b50f57a3e105a18",
    "slice": "a1bcfcbe28f8f8c518b24faca593f8ff2e9bc5e92e3e1ca22b693dffda2dcbe0",
    "projection": "a5213f9447d5aac10c5bea96c1d8eb5717d5eafb976c069833b9003e235afb20",
    "qa": "fc838a2276cae3146951b63004ad9fba4075cfc7fae0397fc602291762b7074f",
}
CATALOG_SHA256 = "791bfea8e1479307794bcf8799cf703a7a840bcd3058c1a0d7fdf065d32d8594"
MANIFEST_SHA256 = "d887683c9a9b9bdb8d4ab7c51cdc5a5b4b4de6a918079e4cfd9cf543e9751e60"
PROOF_SHA256 = "dec615e14881b86b7676e1157f63b8bf6269026d856e59f2ee3a65d7f97e512a"
COUNTS = (60, 420, 420, 0)
LIMITS = {"course": 2 << 20, "slice": 2 << 20, "projection": 2 << 20,
          "qa": 2 << 20, "pubspec": 512 << 10}
DIR_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
FILE_FLAGS = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK
HEX64 = re.compile(r"[0-9a-f]{64}\Z")


class ProjectionError(ValueError):
    """A byte pin, source semantic, or local input boundary changed."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ProjectionError(code)


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def _unique_pairs(pairs: list[tuple[str, object]]) -> dict:
    value = {}
    for key, item in pairs:
        require(key not in value, "DUPLICATE_JSON_KEY")
        value[key] = item
    return value


def parse_json(raw: bytes, *, canonical_source: bool) -> dict:
    try:
        value = json.loads(
            raw.decode("utf-8"), object_pairs_hook=_unique_pairs,
            parse_constant=lambda _: (_ for _ in ()).throw(
                ProjectionError("NONFINITE_JSON")),
        )
        require(type(value) is dict, "JSON_OBJECT")
        if canonical_source:
            require(canonical(value) == raw, "NONCANONICAL_SOURCE_JSON")
        return value
    except ProjectionError:
        raise
    except (UnicodeError, ValueError, TypeError, RecursionError, OverflowError) as error:
        raise ProjectionError("INVALID_JSON") from error


def read_from_root(root_fd: int, relative: Path, limit: int) -> bytes:
    """Open each component beneath one app-root FD without following links."""
    parts = relative.parts
    require(bool(parts) and all(part not in ("", ".", "..") for part in parts),
            "INPUT_RELATIVE_PATH")
    parent_fd = os.dup(root_fd)
    try:
        for component in parts[:-1]:
            try:
                next_fd = os.open(component, DIR_FLAGS, dir_fd=parent_fd)
            except OSError as error:
                raise ProjectionError("INPUT_SYMLINK_OR_UNAVAILABLE") from error
            os.close(parent_fd)
            parent_fd = next_fd
        try:
            file_fd = os.open(parts[-1], FILE_FLAGS, dir_fd=parent_fd)
        except OSError as error:
            raise ProjectionError("INPUT_SYMLINK_OR_UNAVAILABLE") from error
        try:
            before = os.fstat(file_fd)
            require(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= limit,
                    "INPUT_SHAPE_OR_SIZE")
            chunks = []
            remaining = limit + 1
            while remaining:
                chunk = os.read(file_fd, min(remaining, 64 * 1024))
                if not chunk:
                    break
                chunks.append(chunk)
                remaining -= len(chunk)
            raw = b"".join(chunks)
            after = os.fstat(file_fd)
            require(len(raw) == before.st_size and len(raw) <= limit and
                    (before.st_dev, before.st_ino, before.st_size) ==
                    (after.st_dev, after.st_ino, after.st_size),
                    "INPUT_CHANGED_OR_OVERSIZE")
            return raw
        finally:
            os.close(file_fd)
    finally:
        os.close(parent_fd)


def exact_fields(value: object, fields: set[str], code: str) -> None:
    require(type(value) is dict and set(value) == fields, code)


def hex64(value: object) -> bool:
    return isinstance(value, str) and HEX64.fullmatch(value) is not None


def safe_stem(value: object) -> bool:
    return (type(value) is str and value.startswith("ostinato/") and
            "\\" not in value and all(part not in ("", ".", "..")
                                      for part in value.split("/")))


def source_identity(lesson: dict, scene: dict, stem: str) -> dict:
    """The exact source pin material, independent of its embedded digest."""
    return {
        "manifestSHA256": MANIFEST_SHA256,
        "app": "ostinato",
        "courseSourceSHA256": PINS["course"],
        "lessonId": lesson["lessonId"],
        "lessonCanonicalSHA256": lesson["lessonCanonicalSHA256"],
        "assetId": lesson["assetId"],
        "sceneId": scene["sceneId"],
        "variantStem": stem,
        "productionSpecSHA256": scene["productionSpecSHA256"],
        "sourceCueSHA256": scene["sourceCueSHA256"],
        "idempotencyKey": scene["idempotencyKey"],
        "productionState": scene["productionState"],
    }


def verify_semantics(course: dict, source_slice: dict, projection: dict,
                     qa: dict) -> tuple[int, int, int, int]:
    """Rebuild every projected row from the current course and source slice."""
    try:
        slice_fields = {"schemaVersion", "kind", "appId", "sourceCatalogSHA256",
                        "sourceManifestSHA256", "sourceProofSHA256",
                        "courseSourceSHA256", "lessons", "holds"}
        projection_fields = slice_fields - {"sourceProofSHA256", "lessons", "holds"} | {"rows"}
        exact_fields(source_slice, slice_fields, "SLICE_SCHEMA")
        exact_fields(projection, projection_fields, "PROJECTION_SCHEMA")
        for payload, kind in ((source_slice, "MOTION_V2L_APP_SOURCE_SLICE_V1"),
                              (projection, "MOTION_V2L_APP_SOURCE_PROJECTION_V1")):
            require(payload["schemaVersion"] == 1 and payload["kind"] == kind and
                    payload["appId"] == "ostinato" and
                    payload["courseSourceSHA256"] == PINS["course"] and
                    payload["sourceCatalogSHA256"] == CATALOG_SHA256 and
                    payload["sourceManifestSHA256"] == MANIFEST_SHA256,
                    "SOURCE_HEADER")
        require(source_slice["sourceProofSHA256"] == PROOF_SHA256,
                "SOURCE_PROOF")
        require(source_slice["holds"] == [], "SOURCE_HOLDS")
        require(type(course.get("modules")) is list and len(course["modules"]) == 10,
                "LIVE_COURSE_MODULES")
        live_lessons = []
        for module in course["modules"]:
            require(type(module) is dict and type(module.get("lessons")) is list and
                    len(module["lessons"]) == 6, "LIVE_COURSE_MODULE_SHAPE")
            live_lessons.extend(module["lessons"])
        live_ids = [lesson["id"] for lesson in live_lessons]
        require(len(live_ids) == 60 and len(set(live_ids)) == 60,
                "LIVE_COURSE_LESSONS")
        require(type(source_slice["lessons"]) is list and
                len(source_slice["lessons"]) == 60 and
                [lesson["lessonId"] for lesson in source_slice["lessons"]] == live_ids,
                "SOURCE_LESSON_ORDER")

        exact_fields(qa, {"counts", "courseSourceSHA256", "kind", "lessons",
                          "manifestSHA256", "progressEffect", "releaseEligible",
                          "schemaVersion", "sourceCatalogSHA256",
                          "sourceProofSHA256", "visible"}, "QA_SCHEMA")
        require(qa["kind"] == "OSTINATO_V2K_SOURCE_PINS_QA_ONLY" and
                qa["schemaVersion"] == 1 and
                qa["courseSourceSHA256"] == PINS["course"] and
                qa["manifestSHA256"] == MANIFEST_SHA256 and
                qa["sourceCatalogSHA256"] == CATALOG_SHA256 and
                qa["sourceProofSHA256"] == PROOF_SHA256 and
                qa["releaseEligible"] is False and qa["visible"] is False and
                qa["progressEffect"] == 0 and
                qa["counts"] == {"generatedMedia": 0, "qualifiedMedia": 0,
                                  "lessons": 60, "scenes": 420, "variants": 420},
                "QA_SOURCE_POLICY")
        rows = []
        scene_ids: set[str] = set()
        pin_ids: set[str] = set()
        stems: set[str] = set()
        for lesson, live_lesson in zip(source_slice["lessons"], live_lessons, strict=True):
            exact_fields(lesson, {"app", "assetId", "courseSourceSHA256",
                                  "lessonCanonicalSHA256", "lessonId",
                                  "membershipStatus", "scenes"}, "LESSON_SCHEMA")
            lesson_id = lesson["lessonId"]
            require(lesson["app"] == "ostinato" and
                    lesson["assetId"] == f"ostinato.{lesson_id}.v8e.demo" and
                    lesson["courseSourceSHA256"] == PINS["course"] and
                    lesson["membershipStatus"] == "SOURCE_PINNED_TEST_ONLY" and
                    type(lesson["scenes"]) is list and len(lesson["scenes"]) == 7,
                    "SOURCE_LESSON_POLICY")
            require(lesson["lessonCanonicalSHA256"] == digest(canonical(live_lesson)),
                    "LESSON_CANONICAL_DRIFT")
            for order, scene in enumerate(lesson["scenes"]):
                exact_fields(scene, {"idempotencyKey", "productionSpecSHA256",
                                     "productionState", "sceneId", "sourceCueSHA256",
                                     "variants"}, "SCENE_SCHEMA")
                scene_id = scene["sceneId"]
                require(type(scene_id) is str and
                        scene_id.startswith(f"ostinato:{lesson_id}:") and
                        scene_id not in scene_ids and
                        hex64(scene["productionSpecSHA256"]) and
                        hex64(scene["sourceCueSHA256"]) and
                        scene["idempotencyKey"] ==
                        f'motion-media-v1:{scene["productionSpecSHA256"]}' and
                        scene["productionState"] == "PREPRODUCTION_UNGENERATED" and
                        type(scene["variants"]) is list and len(scene["variants"]) == 1,
                        "SOURCE_SCENE_POLICY")
                scene_ids.add(scene_id)
                variant = scene["variants"][0]
                exact_fields(variant, {"sourcePinSHA256", "stem"}, "VARIANT_SCHEMA")
                pin, stem = variant["sourcePinSHA256"], variant["stem"]
                require(hex64(pin) and pin not in pin_ids and
                        safe_stem(stem) and stem not in stems,
                        "VARIANT_ID_OR_PATH")
                require(pin == digest(canonical(source_identity(lesson, scene, stem))),
                        "VARIANT_SOURCE_PIN_DRIFT")
                pin_ids.add(pin)
                stems.add(stem)
                rows.append([pin, lesson_id, lesson["assetId"], scene_id,
                             order, stem, lesson["lessonCanonicalSHA256"],
                             scene["productionSpecSHA256"], scene["sourceCueSHA256"],
                             scene["idempotencyKey"], False])
        require((len(source_slice["lessons"]), len(scene_ids), len(rows),
                 len(source_slice["holds"])) == COUNTS, "SOURCE_COUNTS")
        require(type(projection["rows"]) is list and
                projection["rows"] == sorted(rows, key=lambda row: row[0]),
                "PROJECTION_ROWS_DRIFT")
        require(qa["lessons"] == source_slice["lessons"], "QA_LESSONS_DRIFT")
        return COUNTS
    except (KeyError, TypeError, ValueError, IndexError) as error:
        if isinstance(error, ProjectionError):
            raise
        raise ProjectionError("SOURCE_SCHEMA_INVALID") from error


def _check_pubspec(raw: bytes) -> None:
    try:
        lines = raw.decode("utf-8").splitlines()
    except UnicodeError as error:
        raise ProjectionError("PUBSPEC_ENCODING") from error
    require(lines.count("flutter:") == 1 and lines.count("  assets:") == 1,
            "PUBSPEC_ASSET_SECTION")
    start = lines.index("  assets:")
    assets = []
    for line in lines[start + 1:]:
        if line and not line[0].isspace():
            break
        if line.startswith("  ") and not line.startswith("    ") and not line.lstrip().startswith("#"):
            break
        match = re.fullmatch(r"\s{4}-\s+(\S+)(?:\s+#.*)?", line)
        if match:
            assets.append(match.group(1))
    for required in INPUTS.values():
        if required == INPUTS["pubspec"]:
            continue
        require(assets.count(required.as_posix()) == 1,
                "PUBSPEC_EXACT_ASSET:" + required.as_posix())
    require("assets/motion_content/" not in assets and
            "assets/content/media/" not in assets, "PUBSPEC_BROAD_MEDIA_ASSET")


def check_app(app_root: Path = APP) -> tuple[int, int, int, int]:
    try:
        root_fd = os.open(app_root, DIR_FLAGS)
    except OSError as error:
        raise ProjectionError("APP_ROOT_UNAVAILABLE") from error
    try:
        raw = {key: read_from_root(root_fd, path, LIMITS[key])
               for key, path in INPUTS.items()}
    finally:
        os.close(root_fd)
    for key, expected in PINS.items():
        require(digest(raw[key]) == expected, "APP_BYTE_SHA_DRIFT:" + key)
    _check_pubspec(raw["pubspec"])
    course = parse_json(raw["course"], canonical_source=False)
    source_slice = parse_json(raw["slice"], canonical_source=True)
    projection = parse_json(raw["projection"], canonical_source=True)
    qa = parse_json(raw["qa"], canonical_source=False)
    return verify_semantics(course, source_slice, projection, qa)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", required=True)
    parser.parse_args()
    try:
        counts = check_app()
    except ProjectionError as error:
        print(f"FAIL_SOURCE_IDENTITY_RELEASE_CLOSED {error}", file=sys.stderr)
        return 1
    print("PASS_SOURCE_IDENTITY_ONLY_RELEASE_CLOSED "
          f"ostinato lessons={counts[0]} scenes={counts[1]} "
          f"variants={counts[2]} held={counts[3]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
