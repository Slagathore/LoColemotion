"""Production-shaped zero-world trace tests for QSDK-R23D13."""

from __future__ import annotations

import copy
from pathlib import Path
import sys
import unittest


MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d13_physical_trace as trace


SUPPORTED = (True, True, True, True)
PARTIAL = (True, True, True, False)


class R23D13PhysicalTraceTests(unittest.TestCase):
    def test_declared_cell_identity_and_order_are_exact(self) -> None:
        self.assertEqual(
            [cell.cell_id for cell in trace.stage_a_cells()],
            [
                "mujoco__residual_pose_authority__positive_heading",
                "mujoco__residual_pose_authority__negative_heading",
            ],
        )
        self.assertEqual(len(trace.stage_b_cells()), 9)
        self.assertEqual(
            [cell.engine_id for cell in trace.stage_b_cells()],
            ["godot_jolt"] * 3 + ["rapier_parry"] * 3 + ["mujoco"] * 3,
        )

    def test_all_eleven_synthetic_traces_replay_exactly(self) -> None:
        for cell in trace.all_cells():
            result = trace.validate_trace(cell, trace.synthetic_trace(cell))
            self.assertTrue(result["ok"], (cell.cell_id, result["failure_codes"][:4]))
            self.assertEqual(result["row_count"], 3_892)
            self.assertEqual(result["phase_counts"]["terminal_neutral_acquisition"], 1)
            self.assertEqual(result["phase_counts"]["terminal_quiescent_taper"], 120)
            self.assertEqual(result["phase_counts"]["terminal_irreversible_zero_actuation"], 779)
            outcome = result["taper_outcome"]
            self.assertTrue(outcome["quiescent_taper_gate_passed"])
            self.assertEqual(outcome["handoff_after_active_step"], 120)
            authority = result["authority_outcome"]
            self.assertEqual(authority["active_terminal_row_count"], 121)
            self.assertEqual(authority["pose_floor_dominant_row_count"], 0)
            self.assertEqual(
                authority["temporal_dominant_or_equal_row_count"], 121
            )
            self.assertEqual(authority["passive_exact_zero_row_count"], 779)

    def test_command_time_authority_is_ordered_and_replayed_per_actuator(self) -> None:
        cell = trace.stage_a_cells()[0]
        terminal_observations = trace.observations(
            (1, SUPPORTED, 0.005, 0.18),
            (119, SUPPORTED, 0.02039827933466296, 0.2375508558310486),
            (780, SUPPORTED, 0.005, 0.18),
        )
        rows = trace.synthetic_trace(cell, terminal_observations)
        result = trace.validate_trace(cell, rows)
        self.assertTrue(result["ok"], result["failure_codes"][:8])
        first = rows[trace.CONTROLLER_STEPS]
        self.assertEqual(
            first["command_time_feedback_trace_step"], trace.CONTROLLER_STEPS - 1
        )
        self.assertEqual(first["command_time_torso_tilt_rad"], 0.005)
        self.assertEqual(first["temporal_scale_numerator"], 120)
        self.assertEqual(first["pose_authority_floor_numerator"], 1)
        self.assertEqual(first["applied_scale_numerator"], 120)
        self.assertEqual(
            len(first["ordered_combined_pre_taper_velocities_rad_s"]),
            trace.ACTUATOR_COUNT,
        )
        self.assertEqual(
            len(first["ordered_final_canonical_velocities_rad_s"]),
            trace.ACTUATOR_COUNT,
        )
        authority = result["authority_outcome"]
        self.assertGreater(authority["pose_floor_dominant_row_count"], 0)
        self.assertIsNotNone(authority["first_pose_floor_dominant_trace_step"])
        self.assertGreater(authority["maximum_authority_numerator_increase"], 0)

    def test_authority_time_order_receipt_and_vectors_fail_closed_on_rewrite(
        self,
    ) -> None:
        cell = trace.stage_a_cells()[0]
        baseline = trace.synthetic_trace(cell)
        active_index = trace.CONTROLLER_STEPS + 60
        passive_index = trace.CONTROLLER_STEPS + 500
        cases: list[list[dict[str, object]]] = []

        wrong_source_step = copy.deepcopy(baseline)
        wrong_source_step[active_index]["command_time_feedback_trace_step"] -= 1
        cases.append(wrong_source_step)

        future_feedback = copy.deepcopy(baseline)
        future_feedback[active_index]["command_time_torso_tilt_rad"] = 0.02
        cases.append(future_feedback)

        changed_floor = copy.deepcopy(baseline)
        changed_floor[active_index]["pose_authority_floor_numerator"] = 120
        cases.append(changed_floor)

        changed_applied = copy.deepcopy(baseline)
        changed_applied[active_index]["applied_scale_numerator"] = 120
        cases.append(changed_applied)

        changed_pre_taper = copy.deepcopy(baseline)
        changed_pre_taper[active_index][
            "ordered_combined_pre_taper_velocities_rad_s"
        ][0] = 0.3
        cases.append(changed_pre_taper)

        changed_final = copy.deepcopy(baseline)
        changed_final[active_index]["ordered_final_canonical_velocities_rad_s"][0] = 0.3
        cases.append(changed_final)

        passive_reactivation = copy.deepcopy(baseline)
        passive_reactivation[passive_index][
            "ordered_final_canonical_velocities_rad_s"
        ][0] = 0.01
        cases.append(passive_reactivation)

        passive_claim = copy.deepcopy(baseline)
        passive_claim[passive_index]["residual_pose_recovery_invoked"] = True
        cases.append(passive_claim)

        changed_controller = copy.deepcopy(baseline)
        changed_controller[active_index]["pose_authority_controlling_input"] = (
            "heading_sign"
        )
        cases.append(changed_controller)

        missing_vector = copy.deepcopy(baseline)
        del missing_vector[active_index]["ordered_final_canonical_velocities_rad_s"]
        cases.append(missing_vector)

        for rows in cases:
            result = trace.validate_trace(cell, rows)
            self.assertFalse(result["ok"])
            self.assertTrue(result["failure_codes"])

    def test_deadline_reset_and_contact_loss_remain_valid_negatives(self) -> None:
        cell = trace.stage_a_cells()[0]
        deadline_rows = trace.observations((900, SUPPORTED, 0.03, 0.30))
        deadline = trace.validate_trace(cell, trace.synthetic_trace(cell, deadline_rows))
        self.assertTrue(deadline["ok"], deadline["failure_codes"][:4])
        self.assertFalse(deadline["taper_outcome"]["quiescent_taper_gate_passed"])
        self.assertEqual(deadline["taper_outcome"]["handoff_after_active_step"], 539)

        reset_rows = trace.observations(
            (10, PARTIAL, 0.005, 0.18),
            (51, SUPPORTED, 0.005, 0.18),
            (1, PARTIAL, 0.005, 0.18),
            (838, SUPPORTED, 0.005, 0.18),
        )
        reset = trace.validate_trace(cell, trace.synthetic_trace(cell, reset_rows))
        self.assertTrue(reset["ok"], reset["failure_codes"][:4])
        self.assertEqual(reset["taper_outcome"]["taper_reset_count"], 1)
        self.assertTrue(reset["taper_outcome"]["quiescent_taper_gate_passed"])

        loss_rows = trace.observations(
            (500, SUPPORTED, 0.005, 0.18),
            (1, PARTIAL, 0.005, 0.18),
            (399, SUPPORTED, 0.005, 0.18),
        )
        loss = trace.validate_trace(cell, trace.synthetic_trace(cell, loss_rows))
        self.assertTrue(loss["ok"], loss["failure_codes"][:4])
        self.assertFalse(loss["taper_outcome"]["quiescent_taper_gate_passed"])
        self.assertEqual(loss["taper_outcome"]["first_post_handoff_contact_loss_step"], 500)

    def test_terminal_receipt_and_actuation_mutations_fail_closed(self) -> None:
        cell = trace.stage_a_cells()[0]
        baseline = trace.synthetic_trace(cell)
        cases: list[list[dict[str, object]]] = []

        changed_count = copy.deepcopy(baseline)
        changed_count[trace.CONTROLLER_STEPS + 50]["post_step_taper_count"] = 99
        cases.append(changed_count)

        changed_scale = copy.deepcopy(baseline)
        changed_scale[trace.CONTROLLER_STEPS + 50]["temporal_scale_numerator"] = 99
        cases.append(changed_scale)

        early_phase = copy.deepcopy(baseline)
        early_phase[trace.CONTROLLER_STEPS + 120]["phase_id"] = (
            "terminal_irreversible_zero_actuation"
        )
        cases.append(early_phase)

        hidden_application = copy.deepcopy(baseline)
        hidden_application[trace.CONTROLLER_STEPS + 500][
            "native_actuation_application_count"
        ] = 8
        cases.append(hidden_application)

        changed_pose = copy.deepcopy(baseline)
        changed_pose[trace.CONTROLLER_STEPS + 10]["torso_tilt_rad"] = 0.04
        cases.append(changed_pose)

        excessive_velocity = copy.deepcopy(baseline)
        excessive_velocity[trace.CONTROLLER_STEPS + 60][
            "maximum_absolute_commanded_joint_velocity_rad_s"
        ] = 0.35
        cases.append(excessive_velocity)

        for rows in cases:
            result = trace.validate_trace(cell, rows)
            self.assertFalse(result["ok"])
            self.assertTrue(result["failure_codes"])

    def test_preregistered_diagnostic_receipt_mutations_fail_closed(self) -> None:
        cell = trace.stage_a_cells()[0]
        baseline = trace.synthetic_trace(cell)
        cases: list[list[dict[str, object]]] = []

        nonnumeric_base_task = copy.deepcopy(baseline)
        nonnumeric_base_task[0]["base_linear_velocity_task_forward_m_s"] = "0.2"
        cases.append(nonnumeric_base_task)

        fabricated_support_margin = copy.deepcopy(baseline)
        fabricated_support_margin[0]["minimum_dynamic_support_margin_m"] = None
        cases.append(fabricated_support_margin)

        missing_margin_availability = copy.deepcopy(baseline)
        del missing_margin_availability[0][
            "minimum_dynamic_support_margin_availability"
        ]
        cases.append(missing_margin_availability)

        invalid_margin_availability = copy.deepcopy(baseline)
        invalid_margin_availability[0][
            "minimum_dynamic_support_margin_availability"
        ] = "estimated"
        cases.append(invalid_margin_availability)

        unavailable_margin_has_value = copy.deepcopy(baseline)
        unavailable_margin_has_value[0][
            "minimum_dynamic_support_margin_availability"
        ] = trace.diagnostic_semantics.SUPPORT_MARGIN_UNAVAILABLE
        cases.append(unavailable_margin_has_value)

        invalid_availability = copy.deepcopy(baseline)
        invalid_availability[0]["stability_planning_availability"] = "arm_specific"
        cases.append(invalid_availability)

        wrong_delta_count = copy.deepcopy(baseline)
        wrong_delta_count[0][
            "ordered_applied_stability_velocity_deltas_rad_s"
        ] = [0.0] * 7
        cases.append(wrong_delta_count)

        nonzero_unavailable = copy.deepcopy(baseline)
        nonzero_unavailable[trace.CONTROLLER_STEPS][
            "stability_planning_availability"
        ] = trace.composition.OBSERVATION_UNAVAILABLE
        nonzero_unavailable[trace.CONTROLLER_STEPS][
            "minimum_dynamic_support_margin_m"
        ] = None
        nonzero_unavailable[trace.CONTROLLER_STEPS][
            "minimum_dynamic_support_margin_availability"
        ] = trace.diagnostic_semantics.SUPPORT_MARGIN_UNAVAILABLE
        cases.append(nonzero_unavailable)

        excessive_delta = copy.deepcopy(baseline)
        excessive_delta[trace.CONTROLLER_STEPS][
            "ordered_applied_stability_velocity_deltas_rad_s"
        ] = [0.08] * trace.ACTUATOR_COUNT
        cases.append(excessive_delta)

        excessive_slew = copy.deepcopy(baseline)
        excessive_slew[trace.CONTROLLER_STEPS + 1][
            "ordered_applied_stability_velocity_deltas_rad_s"
        ] = [0.04] * trace.ACTUATOR_COUNT
        cases.append(excessive_slew)

        passive_planner_claim = copy.deepcopy(baseline)
        passive_index = trace.CONTROLLER_STEPS + 121
        passive_planner_claim[passive_index][
            "stability_planning_availability"
        ] = trace.composition.AVAILABLE
        cases.append(passive_planner_claim)

        for rows in cases:
            result = trace.validate_trace(cell, rows)
            self.assertFalse(result["ok"])
            self.assertTrue(
                any(
                    code.startswith("R23D13_TRACE_DIAGNOSTICS:")
                    or code.startswith("R23D13_TRACE_ROW_FIELDS:")
                    or code.startswith("R23D13_TRACE_TERMINAL_SEMANTICS:")
                    for code in result["failure_codes"]
                ),
                result["failure_codes"][:4],
            )

    def test_all_active_planner_margin_pairs_remain_independent(self) -> None:
        cell = trace.stage_a_cells()[0]
        tested = 0
        for planner in trace.diagnostic_semantics.PLANNER_AVAILABILITY_VALUES:
            for margin_availability, support_margin in (
                (trace.diagnostic_semantics.SUPPORT_MARGIN_MEASURED, -0.01),
                (trace.diagnostic_semantics.SUPPORT_MARGIN_UNAVAILABLE, None),
            ):
                rows = trace.synthetic_trace(cell)
                last_active_index = trace.CONTROLLER_STEPS + 120
                rows[last_active_index]["stability_planning_availability"] = planner
                rows[last_active_index][
                    "minimum_dynamic_support_margin_availability"
                ] = margin_availability
                rows[last_active_index][
                    "minimum_dynamic_support_margin_m"
                ] = support_margin
                if planner != trace.diagnostic_semantics.PLANNER_AVAILABLE:
                    rows[last_active_index][
                        "ordered_applied_stability_velocity_deltas_rad_s"
                    ] = [0.0] * trace.ACTUATOR_COUNT
                result = trace.validate_trace(cell, rows)
                self.assertTrue(result["ok"], result["failure_codes"][:4])
                tested += 1
        self.assertEqual(tested, 6)

    def test_r23d11_rejected_shape_is_now_explicitly_valid(self) -> None:
        cell = trace.stage_a_cells()[0]
        rows = trace.synthetic_trace(cell)
        critical_index = trace.CONTROLLER_STEPS + 120
        rows[critical_index]["stability_planning_availability"] = (
            trace.diagnostic_semantics.PLANNER_OBSERVATION_UNAVAILABLE
        )
        rows[critical_index]["minimum_dynamic_support_margin_availability"] = (
            trace.diagnostic_semantics.SUPPORT_MARGIN_MEASURED
        )
        rows[critical_index]["minimum_dynamic_support_margin_m"] = -0.01
        rows[critical_index][
            "ordered_applied_stability_velocity_deltas_rad_s"
        ] = [0.0] * trace.ACTUATOR_COUNT
        result = trace.validate_trace(cell, rows)
        self.assertTrue(result["ok"], result["failure_codes"][:4])

    def test_passive_support_margin_may_be_honestly_unavailable(self) -> None:
        cell = trace.stage_a_cells()[0]
        rows = trace.synthetic_trace(cell)
        passive_rows = [
            row
            for row in rows
            if row["phase_id"] == "terminal_irreversible_zero_actuation"
        ]
        self.assertTrue(passive_rows)
        for row in passive_rows:
            self.assertIsNone(row["stability_planning_availability"])
            row["minimum_dynamic_support_margin_availability"] = (
                trace.diagnostic_semantics.SUPPORT_MARGIN_UNAVAILABLE
            )
            row["minimum_dynamic_support_margin_m"] = None
        result = trace.validate_trace(cell, rows)
        self.assertTrue(result["ok"], result["failure_codes"][:4])

    def test_short_or_noncanonical_shape_fails_closed(self) -> None:
        cell = trace.stage_a_cells()[0]
        result = trace.validate_trace(cell, trace.synthetic_trace(cell)[:-1])
        self.assertFalse(result["ok"])
        self.assertIn("R23D13_TRACE_ROW_COUNT", result["failure_codes"])

        extra = trace.synthetic_trace(cell)
        extra[0]["undeclared"] = True
        result = trace.validate_trace(cell, extra)
        self.assertFalse(result["ok"])
        self.assertIn("R23D13_TRACE_ROW_FIELDS:0", result["failure_codes"])


if __name__ == "__main__":
    unittest.main()
