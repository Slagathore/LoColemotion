from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys
import unittest
from unittest import mock
from typing import Any


PACKAGE_ROOT = Path(__file__).resolve().parent
ADAPTER_ROOT = PACKAGE_ROOT.parent
SDK_ROOT = ADAPTER_ROOT.parents[1]
REPO_ROOT = SDK_ROOT.parent
SDK_PYTHON = SDK_ROOT / "python"
TURNING_ROOT = SDK_ROOT / "turning"
for path in (ADAPTER_ROOT, SDK_PYTHON, TURNING_ROOT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r23d64_selected_profile_turning as worker,
)


EXPECTED_STATUS = (
    "prospective_campaign_machinery_implemented_receipt_schema_and_rapier_"
    "launcher_contract_gates_passed_"
    "complete_zero_world_gate_passed_physical_not_opened"
)


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _campaign_records(value: Any) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("campaign_id") == worker.CAMPAIGN_ID:
            records.append(value)
        for child in value.values():
            records.extend(_campaign_records(child))
    elif isinstance(value, list):
        for child in value:
            records.extend(_campaign_records(child))
    return records


class R23D64MujocoWorkerTests(unittest.TestCase):
    def test_authorization_receipt_composer_is_exact_and_fail_closed(self) -> None:
        item = worker._validate_selector(
            worker.STAGE_ID,
            worker.ONSET_ID,
            worker.CAMPAIGN_SEED,
            worker.PROFILE_ID,
            "reference_zero",
        )
        receipt = worker.compose_authorization_preflight_receipt(item)
        self.assertIs(
            receipt["complete_ordered_nine_cell_matrix_validated"],
            True,
        )
        worker.validate_authorization_preflight_receipt(receipt, item)

        mutations: list[dict[str, object]] = []
        missing = dict(receipt)
        missing.pop("complete_ordered_nine_cell_matrix_validated")
        mutations.append(missing)
        false_value = dict(receipt)
        false_value["complete_ordered_nine_cell_matrix_validated"] = False
        mutations.append(false_value)
        wrong_type = dict(receipt)
        wrong_type["complete_ordered_nine_cell_matrix_validated"] = "true"
        mutations.append(wrong_type)
        alias = dict(receipt)
        alias.pop("complete_ordered_nine_cell_matrix_validated")
        alias["complete_nine_cell_matrix_validated"] = True
        mutations.append(alias)

        for candidate in mutations:
            with self.assertRaisesRegex(
                worker._core.R23D3MujocoError,
                "QSDK_R23D64_MJC_AUTHORIZATION_PREFLIGHT_RECEIPT_INVALID",
            ):
                worker.validate_authorization_preflight_receipt(candidate, item)

    def test_three_declared_arms_preflight_without_model_or_world(self) -> None:
        expected_offsets = {
            "reference_zero": 0.0,
            "positive_heading": 0.2,
            "negative_heading": -0.2,
        }
        for arm_id, offset in expected_offsets.items():
            with self.subTest(arm_id=arm_id):
                receipt = worker.run_preflight(
                    worker.STAGE_ID,
                    worker.ONSET_ID,
                    worker.CAMPAIGN_SEED,
                    worker.PROFILE_ID,
                    arm_id,
                )
                self.assertEqual(receipt["schema_version"], worker.PREFLIGHT_SCHEMA)
                self.assertEqual(receipt["arm_id"], arm_id)
                self.assertEqual(receipt["turn_heading_offset_rad"], offset)
                self.assertEqual(
                    receipt["segment_counts"],
                    worker.public_design.expected_segment_counts(),
                )
                self.assertEqual(receipt["fixed_controller_horizon_step_count"], 2_992)
                self.assertEqual(
                    receipt["expected_task_origin_reanchor_steps"],
                    [600, 1_800, 2_400],
                )
                self.assertTrue(receipt["public_profile_route_compiled_before_model"])
                self.assertTrue(
                    receipt["same_full_model_xml_consumed_by_physical_constructor"]
                )
                self.assertTrue(
                    receipt["complete_nine_cell_matrix_authorization_required"]
                )
                self.assertEqual(receipt["model_construction_count"], 0)
                self.assertEqual(receipt["data_construction_count"], 0)
                self.assertEqual(receipt["world_attempt_count"], 0)
                self.assertEqual(receipt["world_build_count"], 0)
                self.assertEqual(receipt["solver_step_count"], 0)
                self.assertFalse(receipt["physical_execution_authorized"])
                self.assertFalse(receipt["physical_acceptance_authority"])

    def test_identity_controls_refuse_before_contract_or_model(self) -> None:
        controls = (
            (
                "wrong_stage",
                worker.ONSET_ID,
                worker.CAMPAIGN_SEED,
                worker.PROFILE_ID,
                "reference_zero",
            ),
            (
                worker.STAGE_ID,
                "onset_601",
                worker.CAMPAIGN_SEED,
                worker.PROFILE_ID,
                "reference_zero",
            ),
            (
                worker.STAGE_ID,
                worker.ONSET_ID,
                worker.CAMPAIGN_SEED + 1,
                worker.PROFILE_ID,
                "reference_zero",
            ),
            (
                worker.STAGE_ID,
                worker.ONSET_ID,
                worker.CAMPAIGN_SEED,
                "wrong_profile",
                "reference_zero",
            ),
            (
                worker.STAGE_ID,
                worker.ONSET_ID,
                worker.CAMPAIGN_SEED,
                worker.PROFILE_ID,
                "wrong_arm",
            ),
        )
        with mock.patch.object(
            worker._bound_base.bridge,
            "MujocoBw19vRobot",
        ) as constructor:
            for values in controls:
                with self.subTest(values=values):
                    with self.assertRaises(worker._core.R23D3MujocoError):
                        worker.run_preflight(*values)
            constructor.assert_not_called()

    def test_missing_authorization_refuses_before_model(self) -> None:
        environment = {
            key: os.environ.pop(key, None)
            for key in (
                worker.FREEZE_PATH_ENV,
                worker.ATTEMPT_PATH_ENV,
                worker.TOKEN_ENV,
                worker.STAGE_ENV,
                worker.CELL_ENV,
                worker.ENGINE_ENV,
                worker.ATTEMPT_ROOT_ENV,
                worker.AUTHORITY_REPO_ROOT_ENV,
            )
        }
        try:
            with mock.patch.object(
                worker._bound_base.bridge,
                "MujocoBw19vRobot",
            ) as constructor:
                with self.assertRaises(worker._core.R23D3MujocoError) as caught:
                    worker.run_authorization_preflight(
                        worker.STAGE_ID,
                        worker.ONSET_ID,
                        worker.CAMPAIGN_SEED,
                        worker.PROFILE_ID,
                        "reference_zero",
                        "0" * 40,
                    )
                self.assertEqual(
                    caught.exception.code,
                    "QSDK_R23D64_MJC_PHYSICAL_AUTHORIZATION_REQUIRED",
                )

                with self.assertRaises(worker._core.R23D3MujocoError) as caught:
                    worker.run_physical(
                        worker.STAGE_ID,
                        worker.ONSET_ID,
                        worker.CAMPAIGN_SEED,
                        worker.PROFILE_ID,
                        "reference_zero",
                        "0" * 40,
                    )
                receipt = caught.exception.terminal_receipt
                self.assertIsInstance(receipt, dict)
                assert isinstance(receipt, dict)
                self.assertEqual(receipt["world_attempt_count"], 0)
                self.assertEqual(receipt["world_build_count"], 0)
                self.assertIn("AUTHORIZATION_REQUIRED", receipt["failure_code"])
                constructor.assert_not_called()
        finally:
            for key, value in environment.items():
                if value is not None:
                    os.environ[key] = value

    def test_live_authorities_bind_worker_and_preserve_nonclaims(self) -> None:
        paths = {
            "mujoco_worker": worker.WORKER_PATH,
            "mujoco_worker_unit_test": Path(__file__).resolve(),
            "mujoco_worker_gate": REPO_ROOT
            / "tests/test_qsdk_r23d64_mujoco_physical_worker.ps1",
        }
        for authority_path, suffix in (
            (SDK_ROOT / "release/quadruped_release_contract.json", "_raw_sha256"),
            (SDK_ROOT / "release/quadruped_support_matrix.json", "_sha256"),
        ):
            records = _campaign_records(
                json.loads(authority_path.read_text(encoding="utf-8"))
            )
            self.assertEqual(len(records), 1)
            record = records[0]
            self.assertEqual(record["status"], EXPECTED_STATUS)
            for stem, path in paths.items():
                self.assertEqual(
                    record[stem + "_path"],
                    path.relative_to(REPO_ROOT).as_posix(),
                )
                self.assertEqual(record[stem + suffix], _raw_sha256(path))
            self.assertTrue(record["mujoco_worker_implementation_complete"])
            self.assertTrue(record["mujoco_worker_zero_world_gate_passed"])
            self.assertEqual(record["mujoco_worker_preflight_cell_count"], 3)
            self.assertEqual(record["mujoco_worker_mutation_rejection_count"], 11)
            self.assertEqual(record["mujoco_worker_model_construction_count"], 0)
            self.assertEqual(record["mujoco_worker_world_attempt_count"], 0)
            self.assertEqual(record["mujoco_worker_world_build_count"], 0)
            self.assertEqual(record["implemented_native_dependency_route_count"], 3)
            self.assertEqual(record["implemented_native_worker_count"], 3)
            self.assertFalse(record["physical_campaign_opened"])
            self.assertFalse(record["finite_three_engine_turning"])
            self.assertFalse(record["q_sdk_r23_satisfied"])
            self.assertFalse(record["release_authorized"])


if __name__ == "__main__":
    unittest.main()
