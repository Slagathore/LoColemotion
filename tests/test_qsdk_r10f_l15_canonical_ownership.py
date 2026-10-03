"""Opt-in owner projection through the actual compiled SDK, with zero physics.

This is component coverage, not the full recovery epoch or both worker callers.
The bound engine image runs directly, so its console shim cannot outlive a test
timeout with an orphaned engine process. No bodies or command hinges are made.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_runtime_binding as runtime

MARKER = "QSDK_R10F_L15_CANONICAL_OWNERSHIP_ZERO_WORLD "


class CanonicalOwnershipComponent(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Rehash the foundation and all five existing pinned runtime images.
        runtime.bind_runtime(Path(runtime.IMAGES["godot_console"]["path"]))
        run = subprocess.run(
            [
                runtime.IMAGES["godot_engine"]["path"],
                "--headless",
                "--path",
                str(ROOT),
                "--script",
                "res://tests/test_sdk_qsdk_r10f_l15_canonical_ownership_zero_world.gd",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=60,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        lines = [
            line[len(MARKER) :]
            for line in run.stdout.splitlines()
            if line.startswith(MARKER)
        ]
        if (
            run.returncode
            or "SCRIPT ERROR:" in run.stdout + run.stderr
            or "ERROR:" in run.stdout + run.stderr
            or len(lines) != 1
        ):
            raise AssertionError(
                f"L15_OWNERSHIP_COMPONENT_PROCESS:{run.returncode}:{run.stderr}:{run.stdout[:10000]}"
            )
        cls.receipt = json.loads(lines[0])
        if cls.receipt.get("ok") is not True:
            raise AssertionError(json.dumps(cls.receipt, ensure_ascii=False))

    def test_source_projection_and_all_declared_controls(self):
        self.assertTrue(self.receipt["controls"])
        self.assertEqual(41, self.receipt["control_count"])
        self.assertEqual(len(self.receipt["controls"]), self.receipt["control_count"])
        self.assertTrue(
            all(value is True for value in self.receipt["controls"].values())
        )
        self.assertEqual([], self.receipt["failed_controls"])
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertIs(type(self.receipt[key]), int)
            self.assertEqual(0, self.receipt[key], key)
        for key in (
            "whole_worker_qualified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(self.receipt[key], False, key)

    def test_compiled_collector_accepts_mapped_and_preserves_legacy_refusal(self):
        compiled = self.receipt["compiled_collection"]
        self.assertEqual(3, compiled["compiled_collection_call_count"])
        self.assertEqual("supported_exact", compiled["mapped"]["support_status"])
        self.assertIsNone(compiled["mapped"]["refusal_reason"])
        self.assertEqual("supported_exact", compiled["unowned"]["support_status"])
        self.assertIsNone(compiled["unowned"]["refusal_reason"])
        self.assertEqual("SCHEMA_INVALID", compiled["unmapped_legacy"]["failure_code"])
        self.assertIn(
            "unknown variant `recovery_v6`", compiled["unmapped_legacy"]["detail"]
        )
        self.assertIs(compiled["complete_energy_epoch_path_qualified"], False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
