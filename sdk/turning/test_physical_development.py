from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

try:
    from . import physical_development as physical_development_module
    from .physical_development import (
        PhysicalDevelopmentContractError,
        compile_cell_matrix,
        evaluate_aggregate,
        evaluate_cell,
        heading_offset_for_step,
        load_contract,
        perfect_report,
        run_zero_world_preflight,
    )
except ImportError:  # pragma: no cover - direct script execution
    import physical_development as physical_development_module
    from physical_development import (  # type: ignore[no-redef]
        PhysicalDevelopmentContractError,
        compile_cell_matrix,
        evaluate_aggregate,
        evaluate_cell,
        heading_offset_for_step,
        load_contract,
        perfect_report,
        run_zero_world_preflight,
    )


class PhysicalDevelopmentContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.contract = load_contract()
        self.matrix = compile_cell_matrix(self.contract)

    def test_matrix_is_exact_engine_then_arm_product(self) -> None:
        self.assertEqual(
            [cell["cell_id"] for cell in self.matrix],
            [
                "godot_jolt__reference_zero",
                "godot_jolt__positive_heading",
                "godot_jolt__negative_heading",
                "rapier_parry__reference_zero",
                "rapier_parry__positive_heading",
                "rapier_parry__negative_heading",
                "mujoco__reference_zero",
                "mujoco__positive_heading",
                "mujoco__negative_heading",
            ],
        )

    def test_schedule_boundaries_are_exact(self) -> None:
        self.assertEqual(
            heading_offset_for_step("positive_heading", 599, self.contract),
            ("reference_warmup", 0.0),
        )
        self.assertEqual(
            heading_offset_for_step("positive_heading", 600, self.contract),
            ("commanded_turn", 0.2),
        )
        self.assertEqual(
            heading_offset_for_step("negative_heading", 1799, self.contract),
            ("commanded_turn", -0.2),
        )
        self.assertEqual(
            heading_offset_for_step("negative_heading", 1800, self.contract),
            ("reference_recovery", 0.0),
        )
        self.assertEqual(
            heading_offset_for_step("positive_heading", 2400, self.contract),
            ("reference_continuation", 0.0),
        )

    def test_schedule_rejects_invalid_steps_and_arms(self) -> None:
        with self.assertRaises(PhysicalDevelopmentContractError):
            heading_offset_for_step("positive_heading", -1, self.contract)
        with self.assertRaises(PhysicalDevelopmentContractError):
            heading_offset_for_step("positive_heading", True, self.contract)
        with self.assertRaises(PhysicalDevelopmentContractError):
            heading_offset_for_step("unknown", 0, self.contract)

    def test_every_perfect_cell_passes_without_claim_inflation(self) -> None:
        for cell in self.matrix:
            with self.subTest(cell=cell["cell_id"]):
                evaluation = evaluate_cell(
                    perfect_report(cell, self.contract), self.contract
                )
                self.assertTrue(evaluation["execution_valid"])
                self.assertTrue(evaluation["screen_cell_passed"])
                self.assertFalse(evaluation["q_sdk_r23_satisfied"])
                self.assertFalse(evaluation["physical_acceptance_authority"])

    def test_perfect_aggregate_is_development_only(self) -> None:
        reports = [perfect_report(cell, self.contract) for cell in self.matrix]
        evaluation = evaluate_aggregate(reports, self.contract)
        self.assertTrue(evaluation["development_screen_passed"])
        self.assertFalse(evaluation["q_sdk_r23_satisfied"])
        self.assertFalse(evaluation["command_conditioned_turning"])
        self.assertFalse(evaluation["cross_engine_equivalence"])
        self.assertFalse(evaluation["release_authorized"])
        self.assertEqual(evaluation["world_build_count"], 0)

    def test_complete_zero_world_preflight(self) -> None:
        receipt = run_zero_world_preflight()
        self.assertEqual(receipt["declared_engine_count"], 3)
        self.assertEqual(receipt["declared_arm_count"], 3)
        self.assertEqual(receipt["declared_cell_count"], 9)
        self.assertEqual(receipt["schedule_boundary_check_count"], 21)
        self.assertEqual(receipt["perfect_cell_pass_count"], 9)
        self.assertEqual(receipt["cell_negative_control_count"], 26)
        self.assertEqual(receipt["cell_negative_control_rejection_count"], 26)
        self.assertEqual(receipt["aggregate_negative_control_count"], 3)
        self.assertEqual(receipt["aggregate_negative_control_rejection_count"], 3)
        self.assertEqual(receipt["actual_engine_worker_count"], 3)
        self.assertEqual(
            receipt["actual_worker_entrypoint_count_exercised_by_design_preflight"],
            0,
        )
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(
            receipt["physical_execution_authorized"],
            self.contract["authorization"]["physical_execution_authorized"],
        )
        self.assertFalse(receipt["q_sdk_r23_satisfied"])

    def test_aggregate_cli_accepts_only_complete_ordered_matrix(self) -> None:
        with TemporaryDirectory() as directory:
            paths = []
            for cell in self.matrix:
                path = Path(directory) / f"{cell['cell_id']}.json"
                path.write_text(
                    json.dumps(perfect_report(cell, self.contract)),
                    encoding="utf-8",
                )
                paths.append(str(path))
            try:
                from .physical_development import main
            except ImportError:  # pragma: no cover - direct script execution
                from physical_development import main
            self.assertEqual(main(["evaluate-aggregate", *paths]), 0)
            self.assertEqual(main(["evaluate-aggregate", *paths[:-1]]), 1)

    def test_authorization_state_and_contract_status_are_bound(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "authorized-contract.json"
            contract = copy.deepcopy(self.contract)
            contract["status"] = "implemented_prephysical_development_contract"
            contract["authorization"]["physical_execution_authorized"] = False
            path.write_text(json.dumps(contract), encoding="utf-8")
            with patch.object(physical_development_module, "CONTRACT_PATH", path):
                loaded = physical_development_module.load_contract()
            self.assertFalse(loaded["authorization"]["physical_execution_authorized"])

            contract["status"] = (
                "frozen_physical_authorization_pending_exact_source_attestation"
            )
            contract["authorization"]["physical_execution_authorized"] = True
            path.write_text(json.dumps(contract), encoding="utf-8")
            with patch.object(physical_development_module, "CONTRACT_PATH", path):
                loaded = physical_development_module.load_contract()
            self.assertTrue(loaded["authorization"]["physical_execution_authorized"])

            contract["status"] = "implemented_prephysical_development_contract"
            path.write_text(json.dumps(contract), encoding="utf-8")
            with patch.object(physical_development_module, "CONTRACT_PATH", path):
                with self.assertRaises(PhysicalDevelopmentContractError):
                    physical_development_module.load_contract()

            contract["status"] = (
                "frozen_physical_authorization_pending_exact_source_attestation"
            )
            contract["authorization"]["physical_execution_authorized"] = "true"
            path.write_text(json.dumps(contract), encoding="utf-8")
            with patch.object(physical_development_module, "CONTRACT_PATH", path):
                with self.assertRaises(PhysicalDevelopmentContractError):
                    physical_development_module.load_contract()


if __name__ == "__main__":
    unittest.main()
