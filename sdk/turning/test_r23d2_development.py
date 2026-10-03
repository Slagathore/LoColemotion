from __future__ import annotations

import copy
import io
import json
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

try:
    from . import r23d2_development as development
except ImportError:  # pragma: no cover - direct script execution
    import r23d2_development as development  # type: ignore[no-redef]


class R23D2DevelopmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.contract = development.load_contract()
        self.matrix = development.compile_cell_matrix(self.contract)
        self.reports = [
            development.perfect_report(cell, self.contract) for cell in self.matrix
        ]

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

    def test_schedule_boundaries_are_exact_and_invalid_inputs_refuse(self) -> None:
        self.assertEqual(
            development.heading_offset_for_step("positive_heading", 599, self.contract),
            ("reference_warmup", 0.0),
        )
        self.assertEqual(
            development.heading_offset_for_step("positive_heading", 600, self.contract),
            ("commanded_turn", 0.2),
        )
        self.assertEqual(
            development.heading_offset_for_step(
                "negative_heading", 1799, self.contract
            ),
            ("commanded_turn", -0.2),
        )
        self.assertEqual(
            development.heading_offset_for_step(
                "negative_heading", 1800, self.contract
            ),
            ("reference_recovery", 0.0),
        )
        self.assertEqual(
            development.heading_offset_for_step(
                "positive_heading", 2400, self.contract
            ),
            ("reference_continuation", 0.0),
        )
        with self.assertRaises(development.R23D2DevelopmentError):
            development.heading_offset_for_step("positive_heading", -1, self.contract)
        with self.assertRaises(development.R23D2DevelopmentError):
            development.heading_offset_for_step("positive_heading", True, self.contract)
        with self.assertRaises(development.R23D2DevelopmentError):
            development.heading_offset_for_step("unknown", 0, self.contract)

    def test_perfect_cells_and_aggregate_are_finite_development_positive(self) -> None:
        evaluations = [
            development.evaluate_cell(report, self.contract) for report in self.reports
        ]
        self.assertTrue(all(item["execution_valid"] for item in evaluations))
        self.assertTrue(all(item["screen_cell_passed"] for item in evaluations))
        self.assertTrue(
            all(
                item["result_classification"] == "valid_positive"
                for item in evaluations
            )
        )
        aggregate = development.evaluate_aggregate(self.reports, self.contract)
        self.assertTrue(aggregate["aggregate_valid"])
        self.assertTrue(aggregate["development_screen_passed"])
        self.assertEqual(aggregate["result_classification"], "valid_positive")
        self.assertEqual(aggregate["world_attempt_count"], 9)
        self.assertEqual(aggregate["world_build_count"], 9)
        self.assertFalse(aggregate["q_sdk_r23_satisfied"])
        self.assertFalse(aggregate["command_conditioned_turning"])
        self.assertFalse(aggregate["cross_engine_equivalence"])
        self.assertFalse(aggregate["physical_acceptance_authority"])

    def test_physical_gate_failure_is_valid_negative_not_invalid(self) -> None:
        reports = copy.deepcopy(self.reports)
        reports[1]["physics"]["final_forward_displacement_m"] = 0.0
        cell = development.evaluate_cell(reports[1], self.contract)
        self.assertTrue(cell["execution_valid"])
        self.assertFalse(cell["screen_cell_passed"])
        self.assertEqual(cell["result_classification"], "valid_negative")
        self.assertEqual(cell["integrity_failure_codes"], [])
        self.assertEqual(cell["outcome_failure_codes"], ["R23D2_FORWARD_PROGRESS"])
        aggregate = development.evaluate_aggregate(reports, self.contract)
        self.assertTrue(aggregate["aggregate_valid"])
        self.assertTrue(aggregate["development_screen_valid"])
        self.assertFalse(aggregate["development_screen_passed"])
        self.assertEqual(aggregate["result_classification"], "valid_negative")
        self.assertEqual(aggregate["valid_negative_cell_count"], 1)

    def test_oracle_and_stage_integrity_defects_are_invalid(self) -> None:
        mutations = []
        for path, value in (
            (("execution_stage", "world_attempt_count"), 0),
            (("command_validation", "independent_oracle_validation_step_count"), 2399),
            (("command_validation", "accepted_receipt_count"), 2399),
            (("command_validation", "rejected_receipt_count"), 1),
            (("command_validation", "predicate_failure_count"), 1),
            (("command_validation", "raw_heading_offset_equality_used"), True),
            (("command_validation", "oracle_contract_sha256"), "sha256:00"),
        ):
            report = copy.deepcopy(self.reports[1])
            target = report
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = value
            mutations.append(report)
        for report in mutations:
            with self.subTest(report=report["command_validation"]):
                evaluation = development.evaluate_cell(report, self.contract)
                self.assertFalse(evaluation["execution_valid"])
                self.assertEqual(evaluation["result_classification"], "invalid")

    def test_all_stage_receipts_are_truthful_and_controller_rejection_is_retained(
        self,
    ) -> None:
        for stage in self.contract["failure_provenance"]["required_stage_ids"]:
            receipt = development.perfect_failure(self.matrix[0], stage, self.contract)
            evaluation = development.evaluate_failure(receipt, self.contract)
            with self.subTest(stage=stage):
                self.assertTrue(evaluation["entry_valid"])
                self.assertEqual(evaluation["entry_kind"], "worker_failure")
                self.assertEqual(evaluation["result_classification"], "worker_failure")
            if stage == "controller_validation_failed":
                self.assertEqual(receipt["world_attempt_count"], 1)
                self.assertEqual(receipt["world_build_count"], 1)
                self.assertTrue(
                    receipt["rejected_projection_retention"]["embedded_before_exit"]
                )
                self.assertEqual(
                    receipt["oracle_evaluation"]["failed_predicates"],
                    ["desired_heading_error_rad:mismatch"],
                )

    def test_dangling_zero_counts_and_rejected_projection_tampering_are_invalid(
        self,
    ) -> None:
        receipt = development.perfect_failure(
            self.matrix[0], "controller_validation_failed", self.contract
        )
        mutations = []
        for path, value in (
            (("world_attempt_count",), 0),
            (("world_build_count",), 0),
            (("rejected_projection_retention", "payload_sha256"), "sha256:00"),
            (("rejected_projection_retention", "embedded_before_exit"), False),
            (("oracle_evaluation", "failed_predicates"), []),
        ):
            candidate = copy.deepcopy(receipt)
            target = candidate
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = value
            mutations.append(candidate)
        self.assertTrue(
            all(
                not development.evaluate_failure(item, self.contract)["entry_valid"]
                for item in mutations
            )
        )

    def test_cross_language_oracle_evaluation_uses_frozen_absolute_tolerance(
        self,
    ) -> None:
        receipt = development.perfect_failure(
            self.matrix[0], "controller_validation_failed", self.contract
        )
        tolerance = float(
            receipt["oracle_input"]["profile"]["comparison_absolute_tolerance"]
        )
        field = "desired_heading_error_rad"

        within_tolerance = copy.deepcopy(receipt)
        within_tolerance["oracle_evaluation"]["expected_receipt"][field] += (
            tolerance * 0.5
        )
        self.assertTrue(
            development.evaluate_failure(within_tolerance, self.contract)["entry_valid"]
        )

        outside_tolerance = copy.deepcopy(receipt)
        outside_tolerance["oracle_evaluation"]["expected_receipt"][field] += (
            tolerance * 2.0
        )
        evaluation = development.evaluate_failure(outside_tolerance, self.contract)
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn(
            "R23D2_FAILURE_ORACLE_EVALUATION_PARITY",
            evaluation["failure_codes"],
        )

    def test_aggregate_sums_actual_failure_stage_counts(self) -> None:
        expectations = {
            "before_world": (8, 8),
            "world_construction_failed": (9, 8),
            "controller_validation_failed": (9, 9),
        }
        for stage, expected_counts in expectations.items():
            entries = copy.deepcopy(self.reports)
            entries[0] = development.perfect_failure(
                self.matrix[0], stage, self.contract
            )
            aggregate = development.evaluate_aggregate(entries, self.contract)
            with self.subTest(stage=stage):
                self.assertFalse(aggregate["aggregate_valid"])
                self.assertEqual(
                    aggregate["result_classification"], "invalid_or_incomplete"
                )
                self.assertEqual(
                    (aggregate["world_attempt_count"], aggregate["world_build_count"]),
                    expected_counts,
                )

    def test_aggregate_rejects_missing_duplicate_reordered_and_structural_tamper(
        self,
    ) -> None:
        tampered = copy.deepcopy(self.reports)
        tampered[0]["command_validation"]["raw_heading_offset_equality_used"] = True
        candidates = (
            self.reports[:-1],
            [*self.reports[:-1], copy.deepcopy(self.reports[0])],
            list(reversed(self.reports)),
            tampered,
        )
        for entries in candidates:
            evaluation = development.evaluate_aggregate(entries, self.contract)
            self.assertFalse(evaluation["aggregate_valid"])
            self.assertEqual(
                evaluation["result_classification"], "invalid_or_incomplete"
            )

    def test_cli_exit_codes_distinguish_valid_negative_from_invalid(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            negative = copy.deepcopy(self.reports)
            negative[1]["physics"]["final_forward_displacement_m"] = 0.0
            paths = []
            for index, report in enumerate(negative):
                path = root / f"{index:02d}.json"
                path.write_text(json.dumps(report), encoding="utf-8")
                paths.append(str(path))
            output = io.StringIO()
            with redirect_stdout(output):
                self.assertEqual(development.main(["evaluate-aggregate", *paths]), 0)
                self.assertEqual(
                    development.main(["evaluate-aggregate", *paths[:-1]]), 1
                )
            self.assertIn(
                '"result_classification": "valid_negative"', output.getvalue()
            )
            self.assertIn(
                '"result_classification": "invalid_or_incomplete"',
                output.getvalue(),
            )

    def test_synthetic_matrix_writer_emits_exact_order_without_world(self) -> None:
        with TemporaryDirectory() as directory:
            output = Path(directory) / "matrix"
            manifest = development.write_synthetic_matrix(output)
            self.assertEqual(manifest["report_count"], 9)
            self.assertEqual(manifest["synthetic_projected_world_count"], 9)
            self.assertEqual(manifest["actual_world_build_count"], 0)
            observed = [
                json.loads(Path(path).read_text(encoding="utf-8"))["cell_id"]
                for path in manifest["ordered_report_paths"]
            ]
            self.assertEqual(observed, [cell["cell_id"] for cell in self.matrix])

    def test_synthetic_failure_writer_retains_stage_and_projection(self) -> None:
        with TemporaryDirectory() as directory:
            output = Path(directory) / "controller-failure.json"
            manifest = development.write_synthetic_failure(
                self.matrix[0]["cell_id"],
                "controller_validation_failed",
                output,
            )
            self.assertEqual(manifest["world_attempt_count"], 1)
            self.assertEqual(manifest["world_build_count"], 1)
            self.assertEqual(manifest["actual_world_build_count"], 0)
            receipt = json.loads(output.read_text(encoding="utf-8"))
            self.assertTrue(
                receipt["rejected_projection_retention"]["embedded_before_exit"]
            )
            self.assertTrue(
                development.evaluate_failure(receipt, self.contract)["entry_valid"]
            )
            with self.assertRaises(development.R23D2DevelopmentError):
                development.write_synthetic_failure(
                    self.matrix[0]["cell_id"], "before_world", output
                )

    def test_bound_worker_digest_change_fails_closed(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "contract.json"
            contract = copy.deepcopy(self.contract)
            contract["engines"][0]["worker_contract_sha256"] = "sha256:" + "0" * 64
            path.write_text(json.dumps(contract), encoding="utf-8")
            with patch.object(development, "CONTRACT_PATH", path):
                with self.assertRaises(development.R23D2DevelopmentError):
                    development.load_contract()

    def test_evaluator_does_not_import_closed_r23d1_evaluator(self) -> None:
        source = Path(development.__file__).read_text(encoding="utf-8")
        forbidden = "physical" + "_development"
        self.assertNotIn(f"import {forbidden}", source)
        self.assertNotIn(f"from .{forbidden}", source)
        self.assertNotIn(f"from {forbidden}", source)

    def test_complete_zero_world_preflight(self) -> None:
        receipt = development.run_zero_world_preflight()
        self.assertEqual(receipt["declared_engine_count"], 3)
        self.assertEqual(receipt["declared_arm_count"], 3)
        self.assertEqual(receipt["declared_cell_count"], 9)
        self.assertEqual(receipt["schedule_boundary_check_count"], 21)
        self.assertEqual(receipt["synthetic_positive_cell_count"], 9)
        self.assertEqual(receipt["synthetic_positive_aggregate_pass_count"], 1)
        self.assertEqual(receipt["synthetic_valid_negative_aggregate_count"], 1)
        self.assertEqual(receipt["structural_negative_control_count"], 18)
        self.assertEqual(receipt["structural_negative_control_rejection_count"], 18)
        self.assertEqual(receipt["valid_outcome_negative_control_count"], 9)
        self.assertEqual(receipt["aggregate_negative_control_count"], 4)
        self.assertEqual(receipt["aggregate_negative_control_rejection_count"], 4)
        self.assertEqual(receipt["failure_stage_control_count"], 6)
        self.assertEqual(receipt["failure_stage_control_pass_count"], 6)
        self.assertEqual(receipt["failure_provenance_mutation_count"], 5)
        self.assertEqual(receipt["failure_provenance_mutation_rejection_count"], 5)
        self.assertEqual(receipt["synthetic_projected_world_attempt_count"], 9)
        self.assertEqual(receipt["synthetic_projected_world_build_count"], 9)
        self.assertEqual(receipt["actual_world_attempt_count"], 0)
        self.assertEqual(receipt["actual_world_build_count"], 0)
        self.assertTrue(receipt["physical_execution_authorized"])


if __name__ == "__main__":
    unittest.main()
