"""Zero-world production-evaluator tests for QSDK-R23D13."""

from __future__ import annotations

import copy
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import r23d13_physical_evaluator as evaluator
import r23d13_physical_trace as design


class R23D13PhysicalEvaluatorTests(unittest.TestCase):
    SOURCE_COMMIT = "a" * 40

    @classmethod
    def setUpClass(cls) -> None:
        cls._temporary = tempfile.TemporaryDirectory(prefix="r23d13-evaluator-")
        cls.root = Path(cls._temporary.name)
        cls.evidence_root = cls.root / "evidence"
        cls.evidence_root.mkdir()
        cls.powershell = shutil.which("pwsh")
        if not cls.powershell:
            raise RuntimeError("pwsh is required for the R23D13 CAS tests")
        cls.reports: dict[tuple[str, str], dict[str, object]] = {}
        for cell in design.all_cells():
            attempt = cls.root / "attempts" / cell.stage_id / cell.cell_id
            attempt.mkdir(parents=True)
            rows_path = attempt / "rows.json"
            rows_path.write_text(
                json.dumps(design.synthetic_trace(cell), allow_nan=False),
                encoding="utf-8",
            )
            retained = evaluator.retain_trace(
                stage_id=cell.stage_id,
                cell_id=cell.cell_id,
                rows_json_path=rows_path,
                repo_root=evaluator.REPO_ROOT,
                attempt_root=attempt,
                powershell=cls.powershell,
                test_only=True,
                evidence_root_override=cls.evidence_root,
            )
            cls.reports[(cell.stage_id, cell.cell_id)] = cls._report(
                cell, retained
            )
        deadline_cell = design.stage_a_cells()[1]
        deadline_attempt = cls.root / "attempts" / "deadline"
        deadline_attempt.mkdir(parents=True)
        deadline_rows_path = deadline_attempt / "rows.json"
        deadline_observations = design.observations(
            (900, (True, True, True, True), 0.03, 0.30)
        )
        deadline_rows_path.write_text(
            json.dumps(
                design.synthetic_trace(deadline_cell, deadline_observations),
                allow_nan=False,
            ),
            encoding="utf-8",
        )
        deadline_retained = evaluator.retain_trace(
            stage_id=deadline_cell.stage_id,
            cell_id=deadline_cell.cell_id,
            rows_json_path=deadline_rows_path,
            repo_root=evaluator.REPO_ROOT,
            attempt_root=deadline_attempt,
            powershell=cls.powershell,
            test_only=True,
            evidence_root_override=cls.evidence_root,
        )
        cls.deadline_report = cls._report(deadline_cell, deadline_retained)

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temporary.cleanup()

    @staticmethod
    def _report(
        cell: design.Cell, retained: dict[str, object]
    ) -> dict[str, object]:
        summary = copy.deepcopy(retained["trace_summary"])
        replay = summary["taper_outcome"]
        applications = (
            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
            + replay["active_native_application_count"]
        )
        execution = {
            "integrity_passed": True,
            "worker_failure_code": "",
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": design.TERMINAL_STEPS,
            "validated_portable_command_count": applications,
            "native_actuation_application_count": applications,
            "post_handoff_native_actuation_application_count": 0,
            "portable_impulse_violation_count": 0,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": True,
            "fixed_horizon_configuration_proved_before_fixture_insertion": True,
        }
        measurements = {
            "final_forward_displacement_m": 1.0,
            "turn_phase_yaw_delta_rad": (
                0.0
                if cell.arm_id == "reference_zero"
                else cell.turn_heading_offset_rad * 0.5
            ),
            "maximum_absolute_requested_steering_fraction": 0.2,
            "maximum_absolute_held_steering_fraction": 0.2,
            "maximum_tilt_rad": 0.2,
            "minimum_torso_height_m": 0.4,
            "contact_cycle_count_by_limb": {
                limb: 2 for limb in design.LIMB_IDS
            },
            "torso_ground_contact_step_count": 0,
            "controller_error_count": 0,
            "active_safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": design.TERMINAL_STEPS,
            "validated_portable_command_count": applications,
            "native_actuation_application_count": applications,
            "post_handoff_native_actuation_application_count": 0,
            "confirmation_satisfied": replay["confirmation_satisfied"],
            "handoff_after_active_step": replay["handoff_after_active_step"],
            "first_passive_step": replay["first_passive_step"],
            "handoff_reason": replay["handoff_reason"],
            "active_terminal_step_count": replay["active_step_count"],
            "quiescent_taper_step_count": replay["taper_step_count"],
            "passive_terminal_step_count": replay["passive_step_count"],
            "taper_reset_count": replay["taper_reset_count"],
            "active_terminal_native_actuation_application_count": replay[
                "active_native_application_count"
            ],
            "quiescent_taper_gate_passed": replay[
                "quiescent_taper_gate_passed"
            ],
            "first_post_handoff_contact_loss_step": replay[
                "first_post_handoff_contact_loss_step"
            ],
            "post_handoff_contact_loss_step_count": replay[
                "post_handoff_contact_loss_step_count"
            ],
            "terminal_receipt_validation_failure_count": 0,
            "maximum_absolute_terminal_active_joint_velocity_rad_s": 0.35,
        }
        return {
            "schema_version": evaluator.REPORT_SCHEMA,
            "campaign_id": evaluator.CAMPAIGN_ID,
            "gate_id": evaluator.GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": cell.engine_id,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": R23D13PhysicalEvaluatorTests.SOURCE_COMMIT,
            "trace_artifact": copy.deepcopy(retained["trace_artifact"]),
            "trace_summary": summary,
            "execution": execution,
            "measurements": measurements,
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }

    def _stage_a(self) -> list[dict[str, object]]:
        return [
            copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
            for cell in design.stage_a_cells()
        ]

    def _stage_b(self) -> list[dict[str, object]]:
        return [
            copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
            for cell in design.stage_b_cells()
        ]

    def test_trace_retention_is_content_addressed_and_replayed(self) -> None:
        for cell in design.all_cells():
            report = copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
            evaluation = evaluator.evaluate_entry(
                report,
                cell,
                expected_source_commit=self.SOURCE_COMMIT,
                allow_test_artifacts=True,
            )
            self.assertTrue(
                evaluation["entry_valid"],
                (cell.cell_id, evaluation["failure_codes"]),
            )
            self.assertTrue(evaluation["outcome"]["outcome_gate_passed"])
            self.assertEqual(report["trace_summary"]["row_count"], 3_892)
            self.assertEqual(
                report["trace_summary"]["authority_outcome"][
                    "active_terminal_row_count"
                ],
                121,
            )
            self.assertEqual(
                report["trace_summary"]["authority_outcome"][
                    "passive_exact_zero_row_count"
                ],
                779,
            )

        first = design.stage_a_cells()[0]
        report = copy.deepcopy(self.reports[(first.stage_id, first.cell_id)])
        loose_root = self.root / "loose-artifact-copy"
        loose_root.mkdir(exist_ok=True)
        loose_payload = loose_root / "payload.bin"
        loose_manifest = loose_root / "manifest.json"
        shutil.copy2(report["trace_artifact"]["payload_path"], loose_payload)
        shutil.copy2(report["trace_artifact"]["manifest_path"], loose_manifest)
        report["trace_artifact"]["payload_path"] = str(loose_payload)
        report["trace_artifact"]["manifest_path"] = str(loose_manifest)
        evaluation = evaluator.evaluate_entry(
            report,
            first,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn(
            "R23D13_TRACE_ARTIFACT_CAS_PATH",
            evaluation["failure_codes"],
        )

        attempt = self.root / "attempts" / first.stage_id / first.cell_id
        with self.assertRaisesRegex(
            evaluator.R23D13PhysicalEvaluationError,
            "R23D13_TRACE_STAGING_PATH_EXISTS",
        ):
            evaluator.retain_trace(
                stage_id=first.stage_id,
                cell_id=first.cell_id,
                rows_json_path=attempt / "rows.json",
                repo_root=evaluator.REPO_ROOT,
                attempt_root=attempt,
                powershell=self.powershell,
                test_only=True,
                evidence_root_override=self.evidence_root,
            )

    def test_stage_a_selects_only_when_both_signed_cells_pass(self) -> None:
        result = evaluator.evaluate_stage_a_entries(
            self._stage_a(),
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertTrue(result["valid"])
        self.assertEqual(result["classification"], "valid_selected_stage_a")
        self.assertEqual(result["selected_terminal_policy_id"], design.POLICY_ID)
        self.assertTrue(result["stage_b_launch_authorized"])

    def test_valid_stage_a_none_preserves_negative_without_stage_b(self) -> None:
        entries = self._stage_a()
        entries[1]["measurements"]["final_forward_displacement_m"] = 0.0
        result = evaluator.evaluate_complete_entries(
            entries,
            [],
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertEqual(result["classification"], "valid_none_stage_a")
        self.assertFalse(result["stage_a"]["stage_b_launch_authorized"])
        self.assertIsNone(result["stage_b"])

        entries = self._stage_a()
        entries[1] = copy.deepcopy(self.deadline_report)
        result = evaluator.evaluate_complete_entries(
            entries,
            [],
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertEqual(result["classification"], "valid_none_stage_a")
        self.assertTrue(result["stage_a"]["valid"])
        self.assertFalse(result["stage_a"]["stage_b_launch_authorized"])
        self.assertIn(
            "R23D13_QUIESCENT_TAPER",
            result["stage_a"]["cell_evaluations"][1]["outcome"]["failed_gate_ids"],
        )

    def test_complete_eleven_cell_positive_is_exact(self) -> None:
        result = evaluator.evaluate_complete_entries(
            self._stage_a(),
            self._stage_b(),
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertEqual(result["classification"], "valid_complete_positive")
        self.assertEqual(result["world_build_count"], 11)
        self.assertEqual(result["stage_b"]["outcome_failure_count"], 0)

    def test_stage_b_after_valid_none_is_invalid(self) -> None:
        entries = self._stage_a()
        entries[0]["measurements"]["maximum_tilt_rad"] = 0.7
        result = evaluator.evaluate_complete_entries(
            entries,
            self._stage_b(),
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertEqual(
            result["classification"], "invalid_or_incomplete_complete_campaign"
        )
        self.assertIn("R23D13_STAGE_B_OPENED_AFTER_VALID_NONE", result["failure_codes"])

    def test_trace_summary_or_measurement_rewrite_is_rejected(self) -> None:
        cell = design.stage_a_cells()[0]
        report = copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
        report["trace_summary"]["taper_outcome"]["first_passive_step"] = 31
        result = evaluator.evaluate_entry(
            report,
            cell,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(result["entry_valid"])
        self.assertIn("R23D13_REPORT_TRACE_SUMMARY", result["failure_codes"])

        report = copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
        report["measurements"]["active_terminal_step_count"] = 31
        result = evaluator.evaluate_entry(
            report,
            cell,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertTrue(result["entry_valid"])
        self.assertFalse(result["outcome"]["outcome_gate_passed"])
        self.assertIn(
            "R23D13_TAPER_REPLAY:active_terminal_step_count",
            result["outcome"]["failed_gate_ids"],
        )

    def test_trace_retention_rejects_diagnostic_receipt_rewrite(self) -> None:
        cell = design.stage_a_cells()[0]
        rows = design.synthetic_trace(cell)
        rows[design.CONTROLLER_STEPS][
            "minimum_dynamic_support_margin_availability"
        ] = design.diagnostic_semantics.SUPPORT_MARGIN_UNAVAILABLE
        root = self.root / "diagnostic-rewrite"
        root.mkdir(exist_ok=True)
        rows_path = root / "rows.json"
        rows_path.write_text(
            json.dumps(rows, allow_nan=False),
            encoding="utf-8",
        )
        attempt = root / "attempt"
        attempt.mkdir()
        with self.assertRaisesRegex(
            evaluator.R23D13PhysicalEvaluationError,
            "R23D13_TRACE_INVALID:.*R23D13_TRACE_DIAGNOSTICS",
        ):
            evaluator.retain_trace(
                stage_id=cell.stage_id,
                cell_id=cell.cell_id,
                rows_json_path=rows_path,
                repo_root=evaluator.REPO_ROOT,
                attempt_root=attempt,
                powershell=self.powershell,
                test_only=True,
                evidence_root_override=self.evidence_root,
            )

    def test_trace_retention_rejects_authority_or_time_order_rewrite(self) -> None:
        cell = design.stage_a_cells()[0]
        mutations = []

        wrong_time = design.synthetic_trace(cell)
        wrong_time[design.CONTROLLER_STEPS + 50][
            "command_time_feedback_trace_step"
        ] -= 1
        mutations.append(wrong_time)

        wrong_floor = design.synthetic_trace(cell)
        wrong_floor[design.CONTROLLER_STEPS + 50][
            "pose_authority_floor_numerator"
        ] = 120
        mutations.append(wrong_floor)

        wrong_vector = design.synthetic_trace(cell)
        wrong_vector[design.CONTROLLER_STEPS + 50][
            "ordered_final_canonical_velocities_rad_s"
        ][0] = 0.3
        mutations.append(wrong_vector)

        for index, rows in enumerate(mutations):
            root = self.root / f"authority-rewrite-{index}"
            root.mkdir(exist_ok=True)
            rows_path = root / "rows.json"
            rows_path.write_text(
                json.dumps(rows, allow_nan=False),
                encoding="utf-8",
            )
            attempt = root / "attempt"
            attempt.mkdir()
            with self.assertRaisesRegex(
                evaluator.R23D13PhysicalEvaluationError,
                "R23D13_TRACE_INVALID:.*R23D13_TRACE_",
            ):
                evaluator.retain_trace(
                    stage_id=cell.stage_id,
                    cell_id=cell.cell_id,
                    rows_json_path=rows_path,
                    repo_root=evaluator.REPO_ROOT,
                    attempt_root=attempt,
                    powershell=self.powershell,
                    test_only=True,
                    evidence_root_override=self.evidence_root,
                )

    def test_failure_entry_is_validly_retained_but_not_selected(self) -> None:
        cell = design.stage_a_cells()[0]
        failure = {
            "schema_version": evaluator.FAILURE_SCHEMA,
            "campaign_id": evaluator.CAMPAIGN_ID,
            "gate_id": evaluator.GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": cell.engine_id,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": "b" * 40,
            "failure_stage": "before_world",
            "failure_code": "SYNTHETIC_FAILURE",
            "world_attempt_count": 0,
            "world_build_count": 0,
            "trace_artifact": None,
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }
        evaluation = evaluator.evaluate_entry(
            failure,
            cell,
            expected_source_commit="b" * 40,
        )
        self.assertEqual(evaluation["entry_kind"], "worker_failure")
        self.assertFalse(evaluation["entry_valid"])
        self.assertEqual(evaluation["failure_codes"], ["SYNTHETIC_FAILURE"])

    def test_identity_order_duplicates_and_unknown_fields_fail_closed(self) -> None:
        reversed_entries = list(reversed(self._stage_a()))
        result = evaluator.evaluate_stage_a_entries(
            reversed_entries,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(result["valid"])
        self.assertIn("R23D13_STAGE_A_ORDER_OR_IDENTITY", result["failure_codes"])

        duplicate_entries = self._stage_a()
        duplicate_entries[1] = copy.deepcopy(duplicate_entries[0])
        result = evaluator.evaluate_stage_a_entries(
            duplicate_entries,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(result["valid"])
        self.assertIn("R23D13_STAGE_A_DUPLICATE", result["failure_codes"])

        entry = self._stage_a()[0]
        entry["undeclared"] = True
        evaluation = evaluator.evaluate_entry(
            entry,
            design.stage_a_cells()[0],
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D13_REPORT_FIELDS", evaluation["failure_codes"])

        source_mismatch = self._stage_a()
        source_mismatch[1]["source_commit"] = "b" * 40
        result = evaluator.evaluate_stage_a_entries(
            source_mismatch,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(result["valid"])
        self.assertIn(
            "R23D13_SOURCE_COMMIT_EXPECTED:"
            + design.stage_a_cells()[1].cell_id,
            result["failure_codes"],
        )

    def test_real_cli_uses_two_exact_markers_and_no_generic_marker(self) -> None:
        cli_root = self.root / "cli"
        cli_root.mkdir(exist_ok=True)

        def retain_entries(name: str, entries: list[dict[str, object]]) -> Path:
            paths: list[str] = []
            for index, entry in enumerate(entries):
                path = cli_root / f"{name}-{index}.json"
                path.write_text(
                    json.dumps(entry, allow_nan=False, sort_keys=True),
                    encoding="utf-8",
                )
                paths.append(str(path))
            manifest = cli_root / f"{name}-manifest.json"
            manifest.write_text(json.dumps(paths), encoding="utf-8")
            return manifest

        stage_a_manifest = retain_entries("stage-a", self._stage_a())
        stage_b_manifest = retain_entries("stage-b", self._stage_b())
        commands = (
            (
                "QSDK_R23D13_STAGE_A_EVALUATION ",
                [
                    "evaluate-stage-a",
                    "--manifest",
                    str(stage_a_manifest),
                    "--expected-source-commit",
                    self.SOURCE_COMMIT,
                    "--allow-test-artifacts",
                ],
            ),
            (
                "QSDK_R23D13_COMPLETE_EVALUATION ",
                [
                    "evaluate-complete",
                    "--stage-a-manifest",
                    str(stage_a_manifest),
                    "--stage-b-manifest",
                    str(stage_b_manifest),
                    "--expected-source-commit",
                    self.SOURCE_COMMIT,
                    "--allow-test-artifacts",
                ],
            ),
        )
        for expected_marker, arguments in commands:
            process = subprocess.run(
                [sys.executable, str(Path(evaluator.__file__)), *arguments],
                cwd=evaluator.REPO_ROOT,
                capture_output=True,
                check=False,
                text=True,
                timeout=120,
            )
            self.assertEqual(process.returncode, 0, process.stderr)
            matches = [
                line
                for line in process.stdout.splitlines()
                if line.startswith(expected_marker)
            ]
            self.assertEqual(len(matches), 1, process.stdout[-1_000:])
            self.assertNotIn("QSDK_R23D13_EVALUATION ", process.stdout)
            payload = json.loads(matches[0][len(expected_marker) :])
            self.assertEqual(payload["gate_id"], evaluator.GATE_ID)

    def test_real_trace_retention_cli_uses_exact_consumer_marker(self) -> None:
        cell = design.stage_a_cells()[0]
        cli_root = self.root / "trace-retention-cli"
        cli_root.mkdir(exist_ok=True)
        attempt_root = cli_root / "attempt"
        attempt_root.mkdir()
        rows_path = cli_root / "rows.json"
        rows_path.write_text(
            json.dumps(design.synthetic_trace(cell), allow_nan=False),
            encoding="utf-8",
        )
        process = subprocess.run(
            [
                sys.executable,
                str(Path(evaluator.__file__)),
                "retain-trace",
                "--stage-id",
                cell.stage_id,
                "--cell-id",
                cell.cell_id,
                "--rows-json",
                str(rows_path),
                "--repo-root",
                str(evaluator.REPO_ROOT),
                "--attempt-root",
                str(attempt_root),
                "--powershell",
                str(self.powershell),
                "--test-only",
                "--evidence-root",
                str(self.evidence_root),
            ],
            cwd=evaluator.REPO_ROOT,
            capture_output=True,
            check=False,
            text=True,
            timeout=120,
        )
        self.assertEqual(process.returncode, 0, process.stderr)
        marker = "QSDK_R23D13_TRACE_RETENTION "
        matches = [
            line for line in process.stdout.splitlines() if line.startswith(marker)
        ]
        self.assertEqual(len(matches), 1, process.stdout[-1_000:])
        self.assertNotIn("QSDK_R23D13_EVALUATION ", process.stdout)
        payload = json.loads(matches[0][len(marker) :])
        self.assertEqual(payload["stage_id"], cell.stage_id)
        self.assertEqual(payload["cell_id"], cell.cell_id)
        self.assertTrue(payload["retained_before_terminal_entry"])


if __name__ == "__main__":
    unittest.main()
