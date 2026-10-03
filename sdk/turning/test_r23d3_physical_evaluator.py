from __future__ import annotations

import copy
import json
import shutil
import unittest
import uuid
from pathlib import Path

import r23d3_phase_balanced as design
import r23d3_physical_evaluator as physical


class R23D3PhysicalEvaluatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        target = physical.SDK_ROOT / "target" / "qsdk-r23d3-physical-evaluator-tests"
        target.mkdir(parents=True, exist_ok=True)
        cls.root = target / uuid.uuid4().hex
        cls.attempt_root = cls.root / "attempt"
        cls.cas_root = cls.root / "cas"
        cls.rows_root = cls.root / "rows"
        cls.attempt_root.mkdir(parents=True)
        cls.cas_root.mkdir(parents=True)
        cls.rows_root.mkdir(parents=True)
        cls.cells = design.stage_a_cells() + design.stage_b_cells("onset_600")
        cls.retention: dict[tuple[str, str], dict] = {}
        for cell in cls.cells:
            rows_path = cls.rows_root / f"{cell.stage_id}__{cell.cell_id}.json"
            rows_path.write_text(
                json.dumps(
                    design.synthetic_trace(cell),
                    allow_nan=False,
                    separators=(",", ":"),
                    sort_keys=True,
                ),
                encoding="utf-8",
            )
            cls.retention[(cell.stage_id, cell.cell_id)] = physical.retain_trace(
                stage_id=cell.stage_id,
                cell_id=cell.cell_id,
                rows_json_path=rows_path,
                repo_root=physical.REPO_ROOT,
                attempt_root=cls.attempt_root,
                powershell="pwsh",
                test_only=True,
                evidence_root_override=cls.cas_root,
            )

    @classmethod
    def tearDownClass(cls) -> None:
        resolved = cls.root.resolve()
        expected_parent = (
            physical.SDK_ROOT / "target" / "qsdk-r23d3-physical-evaluator-tests"
        ).resolve()
        if resolved.parent != expected_parent or not resolved.name:
            raise RuntimeError(f"refusing unsafe test cleanup: {resolved}")
        shutil.rmtree(resolved)

    @classmethod
    def report(cls, cell: design.Cell) -> dict:
        yaw_delta = 0.0
        if cell.arm_id == "positive_heading":
            yaw_delta = 0.1
        elif cell.arm_id == "negative_heading":
            yaw_delta = -0.1
        retention = cls.retention[(cell.stage_id, cell.cell_id)]
        return {
            "schema_version": physical.REPORT_SCHEMA,
            "campaign_id": design.CAMPAIGN_ID,
            "gate_id": design.GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": cell.engine_id,
            "onset_id": cell.onset_id,
            "turn_start_semantic_step": cell.turn_start_semantic_step,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": "1" * 40,
            "trace_artifact": copy.deepcopy(retention["trace_artifact"]),
            "trace_summary": copy.deepcopy(retention["trace_summary"]),
            "execution": {
                "integrity_passed": True,
                "worker_failure_code": "",
                "controller_semantic_step_count": design.CONTROLLER_STEPS,
                "validated_portable_command_count": (
                    design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
                ),
                "native_actuation_application_count": (
                    design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
                ),
                "portable_impulse_violation_count": 0,
                "world_attempt_count": 1,
                "world_build_count": 1,
                "trace_retained_before_terminal_entry": True,
                "fixed_horizon_configuration_proved_before_fixture_insertion": True,
            },
            "measurements": {
                "final_forward_displacement_m": 0.1,
                "turn_phase_yaw_delta_rad": yaw_delta,
                "maximum_absolute_requested_steering_fraction": 0.2,
                "maximum_absolute_held_steering_fraction": 0.2,
                "maximum_tilt_rad": 0.1,
                "minimum_torso_height_m": 0.4,
                "contact_cycle_count_by_limb": {
                    limb: 2 for limb in design.LIMB_IDS
                },
                "torso_ground_contact_step_count": 0,
                "controller_error_count": 0,
                "safe_no_actuation_count": 0,
                "nonfinite_observation_count": 0,
                "actuator_application_mismatch_count": 0,
                "controller_semantic_step_count": design.CONTROLLER_STEPS,
                "validated_portable_command_count": (
                    design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
                ),
                "native_actuation_application_count": (
                    design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
                ),
            },
            "godot_execution_predicates": (
                design.project_godot_execution_predicates(
                    {
                        "ok": True,
                        "failure_code": "",
                        "step_count": design.CONTROLLER_STEPS,
                        "safe_no_actuation_count": 0,
                        "mismatch_count": 0,
                        "validated_balanced_wave_command_count": (
                            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
                        ),
                        "native_actuation_application_count": (
                            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
                        ),
                    }
                )
                if cell.engine_id == "godot_jolt"
                else None
            ),
            "claims": copy.deepcopy(physical.FALSE_CLAIMS),
        }

    def test_trace_retention_is_canonical_and_content_addressed(self) -> None:
        for cell in self.cells:
            retention = self.retention[(cell.stage_id, cell.cell_id)]
            artifact = retention["trace_artifact"]
            self.assertTrue(retention["retained_before_terminal_entry"])
            self.assertEqual(retention["trace_summary"]["row_count"], 2992)
            self.assertEqual(
                artifact["sha256"], retention["trace_summary"]["raw_sha256"]
            )
            self.assertEqual(
                artifact["byte_length"], retention["trace_summary"]["byte_length"]
            )
            self.assertTrue(Path(artifact["payload_path"]).is_file())
            self.assertTrue(Path(artifact["manifest_path"]).is_file())
            self.assertTrue(artifact["test_only"])

    def test_every_stage_a_report_is_recomputed_valid(self) -> None:
        for cell in design.stage_a_cells():
            evaluation = physical.evaluate_entry(
                self.report(cell), cell, allow_test_artifacts=True
            )
            self.assertTrue(evaluation["entry_valid"], evaluation["failure_codes"])
            self.assertTrue(evaluation["outcome"]["outcome_gate_passed"])

    def test_stage_a_selector_parsimony_none_and_invalid_are_distinct(self) -> None:
        reports = [self.report(cell) for cell in design.stage_a_cells()]
        selected = physical.evaluate_stage_a_entries(
            reports, allow_test_artifacts=True
        )
        self.assertEqual(selected["classification"], "valid_selected_stage_a")
        self.assertEqual(selected["selected_onset_id"], "onset_600")
        self.assertEqual(selected["eligible_onset_ids"], list(design.ONSET_IDS))
        none_reports = copy.deepcopy(reports)
        for report in none_reports:
            if report["arm_id"] == "negative_heading":
                report["measurements"]["turn_phase_yaw_delta_rad"] = 0.0
        none = physical.evaluate_stage_a_entries(
            none_reports, allow_test_artifacts=True
        )
        self.assertTrue(none["valid"])
        self.assertEqual(none["classification"], "valid_none_stage_a")
        self.assertEqual(none["selected_onset_id"], "NONE")
        invalid = physical.evaluate_stage_a_entries(
            reports[:-1], allow_test_artifacts=True
        )
        self.assertFalse(invalid["valid"])
        self.assertEqual(invalid["classification"], "invalid_or_incomplete_stage_a")

    def test_complete_positive_and_valid_negative_are_distinct(self) -> None:
        stage_a = [self.report(cell) for cell in design.stage_a_cells()]
        stage_b = [self.report(cell) for cell in design.stage_b_cells("onset_600")]
        positive = physical.evaluate_complete_entries(
            stage_a, stage_b, allow_test_artifacts=True
        )
        self.assertEqual(positive["classification"], "valid_positive_complete")
        self.assertEqual(positive["world_attempt_count"], 17)
        self.assertEqual(positive["world_build_count"], 17)
        negative_stage_b = copy.deepcopy(stage_b)
        negative_stage_b[-1]["measurements"]["final_forward_displacement_m"] = 0.0
        negative = physical.evaluate_complete_entries(
            stage_a, negative_stage_b, allow_test_artifacts=True
        )
        self.assertEqual(negative["classification"], "valid_negative_complete")
        self.assertEqual(negative["stage_b"]["outcome_failure_count"], 1)

    def test_stage_b_cannot_open_after_valid_none(self) -> None:
        stage_a = [self.report(cell) for cell in design.stage_a_cells()]
        for report in stage_a:
            if report["arm_id"] == "negative_heading":
                report["measurements"]["turn_phase_yaw_delta_rad"] = 0.0
        stage_b = [self.report(cell) for cell in design.stage_b_cells("onset_600")]
        result = physical.evaluate_complete_entries(
            stage_a, stage_b, allow_test_artifacts=True
        )
        self.assertEqual(result["classification"], "invalid_or_incomplete_complete")
        self.assertIn("R23D3_STAGE_B_OPENED_AFTER_VALID_NONE", result["failure_codes"])

    def test_worker_pass_bits_cannot_override_measurements(self) -> None:
        cell = design.stage_a_cells()[0]
        report = self.report(cell)
        report["measurements"]["maximum_tilt_rad"] = 0.7
        evaluation = physical.evaluate_entry(
            report, cell, allow_test_artifacts=True
        )
        self.assertTrue(evaluation["entry_valid"])
        self.assertFalse(evaluation["outcome"]["walking_gate_passed"])
        self.assertIn("R23D3_MAXIMUM_TILT", evaluation["outcome"]["failed_gate_ids"])

    def test_test_artifact_is_rejected_without_explicit_test_mode(self) -> None:
        cell = design.stage_a_cells()[0]
        evaluation = physical.evaluate_entry(self.report(cell), cell)
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D3_TRACE_ARTIFACT_RECEIPT", evaluation["failure_codes"])

    def test_godot_predicate_mutation_is_execution_invalid(self) -> None:
        cell = design.stage_b_cells("onset_600")[0]
        report = self.report(cell)
        report["godot_execution_predicates"]["raw_sdk_authority_summary"][
            "step_count"
        ] = 2991
        evaluation = physical.evaluate_entry(
            report, cell, allow_test_artifacts=True
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D3_REPORT_GODOT_PREDICATES", evaluation["failure_codes"])

    def test_trace_summary_and_execution_counts_are_not_worker_authority(self) -> None:
        cell = design.stage_a_cells()[0]
        report = self.report(cell)
        report["trace_summary"]["row_count"] = 2991
        report["execution"]["controller_semantic_step_count"] = 2991
        evaluation = physical.evaluate_entry(
            report, cell, allow_test_artifacts=True
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D3_REPORT_TRACE_SUMMARY", evaluation["failure_codes"])
        self.assertIn("R23D3_REPORT_EXECUTION", evaluation["failure_codes"])

    def test_outcome_thresholds_are_exactly_frozen(self) -> None:
        cell = design.stage_a_cells()[0]
        at_threshold = self.report(cell)
        at_threshold["measurements"][
            "maximum_absolute_requested_steering_fraction"
        ] = 0.4
        at_threshold["measurements"]["turn_phase_yaw_delta_rad"] = 0.01
        evaluation = physical.evaluate_entry(
            at_threshold, cell, allow_test_artifacts=True
        )
        self.assertTrue(evaluation["outcome"]["outcome_gate_passed"])
        over_threshold = copy.deepcopy(at_threshold)
        over_threshold["measurements"][
            "maximum_absolute_requested_steering_fraction"
        ] = 0.400000000002
        evaluation = physical.evaluate_entry(
            over_threshold, cell, allow_test_artifacts=True
        )
        self.assertFalse(evaluation["outcome"]["outcome_gate_passed"])
        self.assertIn("R23D3_STEERING_LIMIT", evaluation["outcome"]["failed_gate_ids"])


if __name__ == "__main__":
    unittest.main()
