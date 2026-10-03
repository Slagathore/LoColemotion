from __future__ import annotations

import copy
import math
import unittest

from .r23d2_oracle import (
    RECEIPT_FIELDS,
    R23D2OracleError,
    canary_state,
    load_contract,
    recompute_oracle,
    run_zero_world_preflight,
    validate_failure_provenance,
    validate_receipt,
    wrap_angle,
)


class R23D2OracleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.contract = load_contract()
        self.profile = self.contract["selected_profile_oracle"]

    def test_successor_is_distinct_outcome_exposed_and_physically_unauthorized(
        self,
    ) -> None:
        self.assertEqual(self.contract["gate_id"], "QSDK-R23D2")
        self.assertTrue(
            self.contract["outcome_exposure"][
                "r23d1_results_exposed_before_preregistration"
            ]
        )
        self.assertTrue(
            self.contract["unchanged_question"]["all_cells_execute_without_early_stop"]
        )
        self.assertFalse(
            self.contract["authorization"]["physical_execution_authorized"]
        )
        self.assertEqual(
            self.contract["future_worker_requirements"]["actual_engine_worker_count"],
            0,
        )
        self.assertFalse(self.contract["claim_boundary"]["q_sdk_r23_satisfied"])

    def test_all_declared_oracle_canaries_recompute_exactly(self) -> None:
        for canary in self.contract["oracle_canaries"]:
            with self.subTest(canary=canary["canary_id"]):
                receipt = recompute_oracle(
                    canary_state(canary),
                    {"desired_heading_rad": canary["desired_heading_rad"]},
                    self.profile,
                )
                self.assertAlmostEqual(
                    receipt["desired_heading_error_rad"],
                    canary["expected_desired_heading_error_rad"],
                    delta=self.profile["comparison_absolute_tolerance"],
                )

    def test_nonzero_canaries_reject_r23d1_raw_heading_oracle(self) -> None:
        rejected = 0
        for canary in self.contract["oracle_canaries"]:
            state = canary_state(canary)
            command = {"desired_heading_rad": canary["desired_heading_rad"]}
            expected = recompute_oracle(state, command, self.profile)
            if (
                expected["cross_track_error_m"] == 0.0
                and expected["cross_track_velocity_m_s"] == 0.0
            ):
                self.assertTrue(canary["legacy_raw_offset_oracle_would_pass"])
                continue
            legacy = dict(expected)
            legacy["desired_heading_error_rad"] = wrap_angle(
                command["desired_heading_rad"] - state["reference_yaw_rad"]
            )
            legacy["yaw_tracking_error_rad"] = wrap_angle(
                expected["measured_yaw_error_rad"] - legacy["desired_heading_error_rad"]
            )
            evaluation = validate_receipt(legacy, state, command, self.profile)
            self.assertFalse(evaluation["ok"])
            self.assertIn(
                "desired_heading_error_rad:mismatch",
                evaluation["failed_predicates"],
            )
            rejected += 1
        self.assertEqual(rejected, 6)

    def test_each_receipt_predicate_has_an_independent_negative_control(self) -> None:
        canary = self.contract["oracle_canaries"][3]
        state = canary_state(canary)
        command = {"desired_heading_rad": canary["desired_heading_rad"]}
        expected = recompute_oracle(state, command, self.profile)
        for field in RECEIPT_FIELDS:
            with self.subTest(field=field):
                mutated = dict(expected)
                mutated[field] += 1.0e-6
                evaluation = validate_receipt(
                    mutated,
                    state,
                    command,
                    self.profile,
                )
                self.assertFalse(evaluation["ok"])
                self.assertEqual(
                    evaluation["failed_predicates"],
                    [f"{field}:mismatch"],
                )

    def test_clamps_and_shortest_arc_wrap_are_covered(self) -> None:
        receipts = {
            canary["canary_id"]: recompute_oracle(
                canary_state(canary),
                {"desired_heading_rad": canary["desired_heading_rad"]},
                self.profile,
            )
            for canary in self.contract["oracle_canaries"]
        }
        self.assertEqual(receipts["positive_clamp"]["desired_heading_error_rad"], 0.25)
        self.assertEqual(receipts["negative_clamp"]["desired_heading_error_rad"], -0.25)
        self.assertAlmostEqual(
            wrap_angle(-3.0 - 3.1),
            0.1831853071795866,
            delta=1e-15,
        )

    def test_invalid_state_profile_and_nonfinite_receipts_fail_closed(self) -> None:
        canary = self.contract["oracle_canaries"][1]
        state = canary_state(canary)
        command = {"desired_heading_rad": canary["desired_heading_rad"]}
        invalid_state = copy.deepcopy(state)
        invalid_state["task_lateral_axis_world_unit"] = [0.0, 0.0, 2.0]
        with self.assertRaises(R23D2OracleError):
            recompute_oracle(invalid_state, command, self.profile)
        receipt = recompute_oracle(state, command, self.profile)
        receipt["desired_heading_error_rad"] = math.nan
        evaluation = validate_receipt(receipt, state, command, self.profile)
        self.assertEqual(
            evaluation["failed_predicates"],
            ["desired_heading_error_rad:nonfinite_or_missing"],
        )

    def test_failure_provenance_is_stage_aware(self) -> None:
        self.assertTrue(validate_failure_provenance("before_world", 0, 0))
        self.assertTrue(validate_failure_provenance("world_construction_failed", 1, 0))
        self.assertTrue(validate_failure_provenance("world_constructed", 1, 1))
        self.assertTrue(
            validate_failure_provenance("controller_validation_failed", 1, 1)
        )
        self.assertFalse(
            validate_failure_provenance("controller_validation_failed", 0, 0)
        )
        self.assertFalse(validate_failure_provenance("unknown", 0, 0))

    def test_complete_zero_world_preflight(self) -> None:
        receipt = run_zero_world_preflight()
        self.assertEqual(receipt["canary_pass_count"], 7)
        self.assertEqual(receipt["nonzero_cross_track_canary_count"], 6)
        self.assertEqual(receipt["legacy_raw_offset_oracle_rejection_count"], 6)
        self.assertEqual(receipt["predicate_mutation_rejection_count"], 35)
        self.assertEqual(receipt["failure_stage_control_pass_count"], 6)
        self.assertEqual(receipt["actual_engine_worker_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])
        self.assertFalse(receipt["q_sdk_r23_satisfied"])


if __name__ == "__main__":
    unittest.main()
