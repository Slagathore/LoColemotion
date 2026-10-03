from __future__ import annotations

import copy
import math
import unittest

from .r23d3_phase_balanced import (
    ACTUATOR_COUNT,
    ARM_IDS,
    CAMPAIGN_ID,
    CONTROLLER_STEPS,
    GATE_ID,
    GODOT_PREDICATE_SCHEMA,
    ONSET_IDS,
    R23D3Error,
    _good_godot_summary,
    evaluate_complete,
    evaluate_stage_a,
    expected_segment_counts,
    load_contract,
    project_godot_execution_predicates,
    projected_report,
    run_zero_world_preflight,
    stage_a_cells,
    stage_b_cells,
    synthetic_trace,
    synthetic_trace_row,
    validate_projected_report,
    validate_trace,
)


class R23D3PhaseBalancedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = load_contract()

    @staticmethod
    def _trace_summary(cell):
        onset_row = synthetic_trace_row(cell, cell.turn_start_semantic_step)
        return {
            "ok": True,
            "failure_codes": [],
            "row_count": CONTROLLER_STEPS,
            "raw_sha256": "sha256:" + "0" * 64,
            "byte_length": 1,
            "hash_projection": "sha256_canonical_sorted_key_ndjson_rows_v1",
            "segment_counts": expected_segment_counts(cell),
            "onset_snapshot": {
                "semantic_step": cell.turn_start_semantic_step,
                "ordered_limb_phase_before": copy.deepcopy(
                    onset_row["ordered_limb_phase_before"]
                ),
                "ordered_foot_contacts_before": copy.deepcopy(
                    onset_row["ordered_foot_contacts_before"]
                ),
                "torso_position_world_m": copy.deepcopy(
                    onset_row["torso_position_world_m"]
                ),
                "measured_yaw_rad": onset_row["measured_yaw_rad"],
                "requested_steering_fraction": onset_row[
                    "requested_steering_fraction"
                ],
                "held_steering_fraction": onset_row["held_steering_fraction"],
            },
            "steering_saturation_step_count": 0,
        }

    @classmethod
    def _reports(cls, cells):
        return [
            projected_report(cell, cls._trace_summary(cell))
            for cell in cells
        ]

    def test_preregistration_is_distinct_exposed_and_physically_closed(self) -> None:
        self.assertEqual(self.contract["campaign_id"], CAMPAIGN_ID)
        self.assertEqual(self.contract["gate_id"], GATE_ID)
        self.assertTrue(
            self.contract["lineage"]["r23d2_results_exposed_before_preregistration"]
        )
        self.assertFalse(self.contract["lineage"]["predecessor_identity_reused"])
        self.assertFalse(
            self.contract["authorization"]["physical_execution_authorized"]
        )
        self.assertEqual(
            self.contract["future_implementation_requirements"][
                "stage_a_physical_worker_count"
            ],
            0,
        )
        self.assertEqual(
            self.contract["future_implementation_requirements"][
                "stage_b_physical_worker_count"
            ],
            0,
        )
        self.assertFalse(self.contract["claim_boundary"]["portable_basic_turning"])

    def test_stage_a_and_stage_b_matrices_are_exact_and_serial(self) -> None:
        stage_a = stage_a_cells(self.contract)
        self.assertEqual(len(stage_a), 8)
        self.assertEqual(
            [cell.cell_id for cell in stage_a],
            self.contract["stage_a_mujoco_onset_screen"]["ordered_cell_ids"],
        )
        self.assertEqual(
            [(cell.onset_id, cell.arm_id) for cell in stage_a],
            [(onset_id, arm_id) for onset_id in ONSET_IDS for arm_id in ARM_IDS],
        )
        for onset_id in ONSET_IDS:
            stage_b = stage_b_cells(onset_id)
            self.assertEqual(len(stage_b), 9)
            self.assertEqual(len({cell.cell_id for cell in stage_b}), 9)
            self.assertTrue(all(cell.onset_id == onset_id for cell in stage_b))
        self.assertFalse(
            self.contract["stage_a_mujoco_onset_screen"][
                "parallel_execution_permitted"
            ]
        )
        self.assertFalse(
            self.contract["stage_b_three_engine_confirmation"][
                "parallel_execution_permitted"
            ]
        )
        self.assertTrue(
            self.contract["command_schedule"][
                "all_engine_physical_workers_must_execute_exact_fixed_controller_horizon"
            ]
        )
        self.assertTrue(
            self.contract["command_schedule"][
                "godot_contact_gated_evidence_termination_must_not_bound_controller_horizon"
            ]
        )

    def test_godot_horizon_forensics_remain_hypothesis_and_block_old_runner(self) -> None:
        predecessor = self.contract["disclosed_predecessor_results"]
        self.assertFalse(
            predecessor["godot_jolt_exact_failed_execution_subpredicate_known"]
        )
        self.assertEqual(
            predecessor["godot_jolt_retained_terminal_wave_ticks"],
            {"reference_zero": 2859, "positive_heading": 2891, "negative_heading": 2930},
        )
        self.assertEqual(
            predecessor["godot_jolt_inferred_post_settle_controller_step_counts"],
            {"reference_zero": 2620, "positive_heading": 2652, "negative_heading": 2691},
        )
        self.assertTrue(
            predecessor[
                "godot_jolt_horizon_hypothesis_is_not_a_reconstructed_r23d2_cell_report"
            ]
        )
        godot = self.contract["godot_post_world_failure_contract"]
        self.assertEqual(godot["fixed_controller_horizon_step_count"], CONTROLLER_STEPS)
        self.assertTrue(
            godot["adaptive_contact_gated_terminal_end_for_controller_trace_forbidden"]
        )
        future = self.contract["future_implementation_requirements"]
        self.assertFalse(
            future["godot_fixed_controller_horizon_physical_worker_implemented"]
        )
        self.assertFalse(
            future["godot_fixed_horizon_zero_world_worker_preflight_implemented"]
        )

    def test_all_onset_schedules_are_contiguous_and_fit_the_frozen_horizon(self) -> None:
        for cell in stage_a_cells(self.contract):
            with self.subTest(cell=cell.cell_id):
                counts = expected_segment_counts(cell)
                self.assertEqual(sum(counts.values()), CONTROLLER_STEPS)
                self.assertEqual(counts["commanded_turn"], 1_200)
                self.assertEqual(counts["reference_recovery"], 600)
                self.assertGreaterEqual(counts["after_declared_schedule"], 0)

    def test_full_trace_schema_retains_phase_support_and_application_truth(self) -> None:
        cell = stage_a_cells(self.contract)[1]
        rows = synthetic_trace(cell)
        result = validate_trace(cell, rows)
        self.assertTrue(result["ok"], result["failure_codes"])
        self.assertEqual(result["row_count"], CONTROLLER_STEPS)
        self.assertEqual(
            result["hash_projection"],
            self.contract["diagnostic_trace_contract"]["hash_projection"],
        )
        self.assertEqual(result["segment_counts"], expected_segment_counts(cell))
        self.assertEqual(
            result["onset_snapshot"]["semantic_step"],
            cell.turn_start_semantic_step,
        )
        self.assertEqual(
            len(result["onset_snapshot"]["ordered_limb_phase_before"]),
            4,
        )

    def test_trace_schema_rejects_nonfinite_reordered_and_phase_corruption(self) -> None:
        cell = stage_a_cells(self.contract)[0]
        rows = synthetic_trace(cell)
        rows[0]["measured_yaw_rad"] = math.nan
        result = validate_trace(cell, rows)
        self.assertFalse(result["ok"])
        self.assertTrue(
            any(code.startswith("R23D3_TRACE_NONFINITE") for code in result["failure_codes"])
        )

        rows = synthetic_trace(cell)
        rows[3]["semantic_step"] = 4
        self.assertFalse(validate_trace(cell, rows)["ok"])

        rows = synthetic_trace(cell)
        rows[1]["semantic_step"] = True
        self.assertFalse(validate_trace(cell, rows)["ok"])

        rows = synthetic_trace(cell)
        rows[0]["ordered_limb_phase_before"][2]["local_phase_step"] += 1
        result = validate_trace(cell, rows)
        self.assertIn("R23D3_TRACE_LOCAL_PHASE:0:2", result["failure_codes"])

    def test_selector_uses_bilateral_eligibility_and_frozen_parsimony(self) -> None:
        reports = self._reports(stage_a_cells(self.contract))
        result = evaluate_stage_a(reports)
        self.assertEqual(result["selected_onset_id"], "onset_600")
        self.assertEqual(result["eligible_onset_ids"], list(ONSET_IDS))

        fallback = copy.deepcopy(reports)
        for report in fallback:
            if report["onset_id"] in ("onset_600", "onset_690"):
                report["outcome"]["walking_gate_passed"] = False
                report["outcome"]["outcome_gate_passed"] = False
                report["outcome"]["failed_gate_ids"] = ["synthetic_failure"]
        self.assertEqual(
            evaluate_stage_a(fallback)["selected_onset_id"],
            "onset_780",
        )

        none = copy.deepcopy(reports)
        for report in none:
            if report["arm_id"] == "negative_heading":
                report["outcome"]["turn_phase_yaw_delta_rad"] = 0.0
                report["outcome"]["signed_yaw_response_passed"] = False
                report["outcome"]["outcome_gate_passed"] = False
                report["outcome"]["failed_gate_ids"] = ["synthetic_failure"]
        none_result = evaluate_stage_a(none)
        self.assertEqual(none_result["classification"], "valid_none_stage_a")
        self.assertFalse(none_result["stage_b_launch_authorized"])

    def test_report_recomputes_signed_yaw_and_pins_trace_projection(self) -> None:
        cell = stage_a_cells(self.contract)[0]
        report = projected_report(cell, self._trace_summary(cell))
        self.assertEqual(validate_projected_report(report, cell), [])

        wrong_yaw = copy.deepcopy(report)
        wrong_yaw["outcome"]["turn_phase_yaw_delta_rad"] = -0.1
        self.assertIn("R23D3_REPORT_OUTCOME", validate_projected_report(wrong_yaw, cell))

        wrong_hash = copy.deepcopy(report)
        wrong_hash["trace_summary"]["raw_sha256"] = "sha256:short"
        self.assertIn(
            "R23D3_REPORT_TRACE_SUMMARY",
            validate_projected_report(wrong_hash, cell),
        )

    def test_invalid_stage_a_never_becomes_none_or_opens_stage_b(self) -> None:
        reports = self._reports(stage_a_cells(self.contract))
        invalid = evaluate_stage_a(reports[:-1])
        self.assertFalse(invalid["valid"])
        self.assertEqual(invalid["classification"], "invalid_or_incomplete_stage_a")
        self.assertFalse(invalid["stage_b_launch_authorized"])

    def test_complete_evaluator_preserves_positive_negative_none_and_invalid(self) -> None:
        stage_a = self._reports(stage_a_cells(self.contract))
        stage_b = self._reports(stage_b_cells("onset_600"))
        self.assertEqual(
            evaluate_complete(stage_a, stage_b)["classification"],
            "valid_positive_complete",
        )

        negative = copy.deepcopy(stage_b)
        negative[-1]["outcome"]["walking_gate_passed"] = False
        negative[-1]["outcome"]["outcome_gate_passed"] = False
        negative[-1]["outcome"]["failed_gate_ids"] = ["synthetic_failure"]
        self.assertEqual(
            evaluate_complete(stage_a, negative)["classification"],
            "valid_negative_complete",
        )

        none = copy.deepcopy(stage_a)
        for report in none:
            if report["arm_id"] == "negative_heading":
                report["outcome"]["turn_phase_yaw_delta_rad"] = 0.0
                report["outcome"]["signed_yaw_response_passed"] = False
                report["outcome"]["outcome_gate_passed"] = False
                report["outcome"]["failed_gate_ids"] = ["synthetic_failure"]
        self.assertEqual(
            evaluate_complete(none, [])["classification"],
            "valid_none_stage_a",
        )
        self.assertEqual(
            evaluate_complete(none, stage_b)["classification"],
            "invalid_or_incomplete_complete",
        )
        self.assertEqual(
            evaluate_complete(stage_a, stage_b[:-1])["classification"],
            "invalid_or_incomplete_complete",
        )

    def test_godot_projection_names_every_observed_predicate(self) -> None:
        good = _good_godot_summary()
        projection = project_godot_execution_predicates(good)
        self.assertEqual(projection["schema_version"], GODOT_PREDICATE_SCHEMA)
        self.assertTrue(projection["ok"])
        self.assertEqual(len(projection["ordered_predicates"]), 7)
        self.assertEqual(projection["raw_sdk_authority_summary"], good)

        for predicate in projection["ordered_predicates"]:
            with self.subTest(predicate=predicate["predicate_id"]):
                field = predicate["source_path"].split(".")[-1]
                mutated = copy.deepcopy(good)
                del mutated[field]
                rejected = project_godot_execution_predicates(mutated)
                self.assertFalse(rejected["ok"])
                self.assertEqual(
                    rejected["failed_predicate_ids"],
                    [predicate["predicate_id"]],
                )
                rejected_row = next(
                    row
                    for row in rejected["ordered_predicates"]
                    if row["predicate_id"] == predicate["predicate_id"]
                )
                self.assertFalse(rejected_row["field_present"])
                self.assertEqual(rejected_row["observed_value_type"], "null")

        loose_bool = copy.deepcopy(good)
        loose_bool["ok"] = 1
        self.assertEqual(
            project_godot_execution_predicates(loose_bool)["failed_predicate_ids"],
            ["sdk_summary_ok"],
        )
        loose_integer = copy.deepcopy(good)
        loose_integer["step_count"] = float(CONTROLLER_STEPS)
        self.assertEqual(
            project_godot_execution_predicates(loose_integer)[
                "failed_predicate_ids"
            ],
            ["sdk_step_count"],
        )

    def test_unknown_onset_cannot_materialize_stage_b(self) -> None:
        with self.assertRaises(R23D3Error):
            stage_b_cells("post_hoc_onset")

    def test_complete_zero_world_preflight(self) -> None:
        receipt = run_zero_world_preflight()
        self.assertEqual(receipt["stage_a_cell_count"], 8)
        self.assertEqual(receipt["stage_b_projected_cell_count"], 9)
        self.assertEqual(receipt["trace_validation_count"], 17)
        self.assertEqual(receipt["trace_row_validation_count"], 50_864)
        self.assertEqual(receipt["trace_negative_control_rejection_count"], 10)
        self.assertEqual(receipt["selector_canary_pass_count"], 4)
        self.assertEqual(receipt["complete_evaluation_canary_pass_count"], 5)
        self.assertEqual(receipt["godot_execution_predicate_count"], 7)
        self.assertEqual(
            receipt["godot_execution_predicate_mutation_rejection_count"], 7
        )
        self.assertTrue(receipt["godot_fixed_horizon_requirement_preregistered"])
        self.assertEqual(receipt["godot_fixed_horizon_controller_step_count"], 2_992)
        self.assertFalse(
            receipt["godot_fixed_horizon_zero_world_worker_preflight_implemented"]
        )
        self.assertFalse(receipt["godot_fixed_horizon_physical_worker_implemented"])
        self.assertEqual(receipt["physical_process_launch_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])
        self.assertFalse(receipt["portable_basic_turning"])


if __name__ == "__main__":
    unittest.main()
