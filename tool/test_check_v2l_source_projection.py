"""Negative controls for Ostinato's app-owned source-only v2l inputs."""

from __future__ import annotations

import copy
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import check_v2l_source_projection as source


class SourceProjectionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.raw = {
            key: (source.APP / path).read_bytes()
            for key, path in source.INPUTS.items()
        }
        self.course = json.loads(self.raw["course"])
        self.source_slice = json.loads(self.raw["slice"])
        self.projection = json.loads(self.raw["projection"])
        self.qa = json.loads(self.raw["qa"])

    def test_live_app_check_is_source_only(self) -> None:
        self.assertEqual(source.check_app(), (60, 420, 420, 0))

    def test_same_byte_intermediate_symlink_swap_fails_after_precheck(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._app_copy(Path(temporary) / "app")
            outside = Path(temporary) / "outside"
            shutil.copytree(root / "assets", outside / "assets")
            self.assertTrue((root / source.INPUTS["slice"]).is_file())
            original_open = os.open
            swapped = False

            def swap_before_component_open(path, flags, *args, **kwargs):
                nonlocal swapped
                if not swapped and path == "assets" and kwargs.get("dir_fd") is not None:
                    swapped = True
                    os.rename(root / "assets", root / "assets-original")
                    (root / "assets").symlink_to(outside / "assets", target_is_directory=True)
                return original_open(path, flags, *args, **kwargs)

            with mock.patch.object(source.os, "open", side_effect=swap_before_component_open):
                with self.assertRaisesRegex(source.ProjectionError, "INPUT_SYMLINK"):
                    source.check_app(root)
            self.assertTrue(swapped)
            # The outside copy is byte-equal, so a path-based reader would pass.
            self.assertEqual((root / source.INPUTS["slice"]).read_bytes(), self.raw["slice"])

    def test_same_byte_leaf_symlink_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._app_copy(Path(temporary) / "app")
            outside = Path(temporary) / "outside.json"
            outside.write_bytes(self.raw["projection"])
            target = root / source.INPUTS["projection"]
            target.unlink()
            target.symlink_to(outside)
            self.assertEqual(target.read_bytes(), self.raw["projection"])
            with self.assertRaisesRegex(source.ProjectionError, "INPUT_SYMLINK"):
                source.check_app(root)

    def test_repinning_wrong_lesson_hash_and_all_seven_variant_pins_fails(self) -> None:
        altered = copy.deepcopy(self.source_slice)
        first = altered["lessons"][0]
        self.assertEqual(len(first["scenes"]), 7)
        first["lessonCanonicalSHA256"] = "0" * 64
        for scene in first["scenes"]:
            variant = scene["variants"][0]
            identity = source.source_identity(first, scene, variant["stem"])
            variant["sourcePinSHA256"] = source.digest(source.canonical(identity))
        altered_projection = copy.deepcopy(self.projection)
        for row in altered_projection["rows"]:
            if row[1] == first["lessonId"]:
                scene = next(scene for scene in first["scenes"] if scene["sceneId"] == row[3])
                row[0] = scene["variants"][0]["sourcePinSHA256"]
                row[6] = first["lessonCanonicalSHA256"]
        altered_projection["rows"].sort(key=lambda row: row[0])
        with self.assertRaisesRegex(source.ProjectionError, "LESSON_CANONICAL_DRIFT"):
            source.verify_semantics(self.course, altered, altered_projection, self.qa)

    def test_source_slice_cannot_acquire_video_field(self) -> None:
        altered = copy.deepcopy(self.source_slice)
        altered["lessons"][0]["scenes"][0]["variants"][0]["video"] = {
            "path": "assets/content/media/fake.mp4"
        }
        with self.assertRaisesRegex(source.ProjectionError, "VARIANT_SCHEMA"):
            source.verify_semantics(self.course, altered, self.projection, self.qa)

    def test_projection_scene_order_drift_fails(self) -> None:
        altered = copy.deepcopy(self.projection)
        altered["rows"][0][4] += 1
        with self.assertRaisesRegex(source.ProjectionError, "PROJECTION_ROWS_DRIFT"):
            source.verify_semantics(self.course, self.source_slice, altered, self.qa)

    def test_duplicate_source_json_key_fails(self) -> None:
        raw = self.raw["slice"].replace(b'"appId":"ostinato",', b'"appId":"ostinato","appId":"ostinato",', 1)
        with self.assertRaisesRegex(source.ProjectionError, "DUPLICATE_JSON_KEY"):
            source.parse_json(raw, canonical_source=True)

    def test_qa_fixture_membership_drift_fails(self) -> None:
        qa = copy.deepcopy(self.qa)
        qa["lessons"][0]["scenes"].pop()
        with self.assertRaisesRegex(source.ProjectionError, "QA_LESSONS_DRIFT"):
            source.verify_semantics(self.course, self.source_slice, self.projection, qa)

    def _app_copy(self, root: Path) -> Path:
        root.mkdir()
        for key, path in source.INPUTS.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(self.raw[key])
        return root


if __name__ == "__main__":
    unittest.main()
