"""Production no-actuation stages through actual zero-world epoch/V6 consumers."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_runtime_binding as runtime

MARKER = "QSDK_R10F_L15_WORKER_OWNERSHIP_ZERO_WORLD "


class WorkerOwnershipStages(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        runtime.bind_runtime(Path(runtime.IMAGES["godot_console"]["path"]))
        run = subprocess.run(
            [
                runtime.IMAGES["godot_engine"]["path"],
                "--headless",
                "--path",
                str(ROOT),
                "--script",
                "res://tests/test_sdk_qsdk_r10f_l15_worker_ownership_zero_world.gd",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=120,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        lines = [
            line[len(MARKER) :]
            for line in run.stdout.splitlines()
            if line.startswith(MARKER)
        ]
        if run.returncode or "ERROR:" in run.stdout + run.stderr or len(lines) != 1:
            raise AssertionError(
                f"L15_WORKER_OWNERSHIP_PROCESS:{run.returncode}:{run.stderr}:{run.stdout[:15000]}"
            )
        cls.receipt = json.loads(lines[0])
        if cls.receipt.get("ok") is not True:
            raise AssertionError(json.dumps(cls.receipt, ensure_ascii=False))

    def test_both_actual_stages_through_compiled_epoch_and_controller(self):
        receipt = self.receipt
        self.assertEqual(2, receipt["production_stage_count"])
        self.assertEqual(3, receipt["compiled_collection_call_count"])
        self.assertEqual(3, receipt["compiled_controller_advance_call_count"])
        self.assertEqual(2, receipt["successful_compiled_controller_advance_count"])
        self.assertEqual(1, receipt["refused_compiled_controller_step_count"])
        self.assertEqual(
            [509, 510], [row["global_step"] for row in receipt["epoch_results"]]
        )
        self.assertEqual(
            [1, 2], [row["local_step"] for row in receipt["epoch_results"]]
        )
        self.assertTrue(
            all(
                row["collection_support"] == "supported_exact"
                for row in receipt["epoch_results"]
            )
        )
        self.assertNotEqual(
            receipt["source_applications"][0]["source_memory_sha256"],
            receipt["source_applications"][1]["source_memory_sha256"],
        )

    def test_source_preservation_and_refusal_controls_are_complete(self):
        self.assertEqual(36, self.receipt["control_count"])
        self.assertEqual(self.receipt["control_count"], len(self.receipt["controls"]))
        self.assertEqual([], self.receipt["failed_controls"])
        self.assertTrue(
            all(value is True for value in self.receipt["controls"].values())
        )
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
            "enclosing_physical_worker_executed",
            "complete_worker_to_envelope_qualified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(self.receipt[key], False, key)
        self.assertIs(self.receipt["motor_readback_is_synthetic_fixture"], True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
