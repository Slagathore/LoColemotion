"""Zero-world production-evaluator tests for QSDK-R23D18."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d18_physical_evaluator as evaluator
import r23d18_physical_trace as design


class R23D18PhysicalEvaluatorTests(unittest.TestCase):
    SOURCE_COMMIT = "a" * 40

    @classmethod
    def setUpClass(cls) -> None:
        cls._temporary = tempfile.TemporaryDirectory(prefix="r23d18-evaluator-")
        cls.root = Path(cls._temporary.name)
        cls.evidence_root = cls.root / "evidence"
        cls.evidence_root.mkdir()
        cls.powershell = shutil.which("pwsh")
        if not cls.powershell:
            raise RuntimeError("pwsh is required for the R23D18 CAS tests")
        cls.reports: dict[str, dict[str, object]] = {}
        for cell in design.matrix_cells():
            retained = cls._retain(cell, design.synthetic_trace(cell), cell.cell_id)
            cls.reports[cell.cell_id] = cls._report(cell, retained)

        deadline_cell = design.matrix_cells()[-1]
        deadline_rows = design.synthetic_trace(
            deadline_cell,
            design.observations(
                (960, (True, True, True, True), 0.03, 0.30)
            ),
        )
        cls.deadline_report = cls._report(
            deadline_cell,
            cls._retain(deadline_cell, deadline_rows, "deadline"),
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temporary.cleanup()

    @classmethod
    def _retain(
        cls,
        cell: design.Cell,
        rows: list[dict[str, object]],
        leaf: str,
        repo_root: Path | None = None,
    ) -> dict[str, object]:
        attempt = cls.root / "attempts" / leaf
        attempt.mkdir(parents=True)
        rows_path = attempt / "rows.json"
        rows_path.write_text(
            json.dumps(rows, allow_nan=False),
            encoding="utf-8",
        )
        return evaluator.retain_trace(
            stage_id=cell.stage_id,
            cell_id=cell.cell_id,
            rows_json_path=rows_path,
            repo_root=evaluator.REPO_ROOT if repo_root is None else repo_root,
            attempt_root=attempt,
            powershell=cls.powershell,
            test_only=True,
            evidence_root_override=cls.evidence_root,
        )

    @staticmethod
    def _report(
        cell: design.Cell,
        retained: dict[str, object],
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
            "source_commit": R23D18PhysicalEvaluatorTests.SOURCE_COMMIT,
            "trace_artifact": copy.deepcopy(retained["trace_artifact"]),
            "trace_summary": summary,
            "execution": execution,
            "measurements": measurements,
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }

    def _matrix(self) -> list[dict[str, object]]:
        return [
            copy.deepcopy(self.reports[cell.cell_id])
            for cell in design.matrix_cells()
        ]

    def test_trace_retention_is_content_addressed_and_replayed(self) -> None:
        for cell in design.matrix_cells():
            report = copy.deepcopy(self.reports[cell.cell_id])
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
            self.assertEqual(report["trace_summary"]["row_count"], 3_952)
            self.assertEqual(
                report["trace_summary"]["authority_outcome"][
                    "passive_exact_zero_row_count"
                ],
                839,
            )

    def test_trace_retention_overrides_hostile_inherited_execution_policy(self) -> None:
        cell = design.cell_for_identity(
            "finite_three_engine_confirmation_receipt_integrity_recovery",
            "rapier_parry__tight_gated_horizon__reference_zero",
        )
        rows = design.synthetic_trace(cell)
        previous = os.environ.get("PSExecutionPolicyPreference")
        try:
            os.environ["PSExecutionPolicyPreference"] = "AllSigned"
            retained = self._retain(cell, rows, "hostile-execution-policy")
        finally:
            if previous is None:
                os.environ.pop("PSExecutionPolicyPreference", None)
            else:
                os.environ["PSExecutionPolicyPreference"] = previous
        self.assertTrue(retained["retained_before_terminal_entry"])
        self.assertEqual(retained["trace_summary"]["row_count"], 3_952)

    def test_trace_retention_accepts_extended_local_drive_repo_identity(self) -> None:
        cell = design.cell_for_identity(
            "finite_three_engine_confirmation_receipt_integrity_recovery",
            "rapier_parry__tight_gated_horizon__reference_zero",
        )
        extended_root = Path("\\\\?\\" + str(evaluator.REPO_ROOT))
        retained = self._retain(
            cell,
            design.synthetic_trace(cell),
            "extended-local-drive-root",
            repo_root=extended_root,
        )
        self.assertTrue(retained["retained_before_terminal_entry"])
        self.assertEqual(retained["trace_summary"]["row_count"], 3_952)

    def test_publisher_refuses_wrong_root_and_unsupported_path_kinds(self) -> None:
        artifact = self.root / "publisher-path-controls.ndjson"
        artifact.write_bytes(b"[]\n")
        digest = "sha256:" + hashlib.sha256(artifact.read_bytes()).hexdigest()
        publisher = evaluator.TRACE_PUBLISHER_PATH
        cases = (
            (str(self.root), "repository root mismatch"),
            (r"\\?\UNC\server\share\SporeSpore", "path identity kind is unsupported"),
            (r"\\.\C:\SporeSpore", "path identity kind is unsupported"),
        )
        for index, (repo_root, expected) in enumerate(cases):
            evidence = self.root / f"publisher-negative-{index}"
            evidence.mkdir()
            process = subprocess.run(
                [
                    self.powershell,
                    "-NoLogo",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(publisher),
                    "-RepoRoot",
                    repo_root,
                    "-ArtifactPath",
                    str(artifact),
                    "-ExpectedSha256",
                    digest,
                    "-ExpectedByteLength",
                    str(artifact.stat().st_size),
                    "-TestOnly",
                    "-EvidenceRootOverride",
                    str(evidence),
                ],
                cwd=evaluator.REPO_ROOT,
                capture_output=True,
                check=False,
                text=True,
                timeout=30,
            )
            self.assertNotEqual(process.returncode, 0, repo_root)
            self.assertIn(expected, process.stderr, repo_root)

    def test_complete_matrix_positive_is_exact(self) -> None:
        result = evaluator.evaluate_complete_entries(
            self._matrix(),
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertTrue(result["matrix_valid"])
        self.assertEqual(result["classification"], "valid_complete_positive")
        self.assertEqual(result["outcome_failure_count"], 0)
        self.assertEqual(result["world_attempt_count"], 9)
        self.assertEqual(result["world_build_count"], 9)
        self.assertEqual(len(result["cell_evaluations"]), 9)
        self.assertEqual(result["claims"], evaluator.FALSE_CLAIMS)

    def test_complete_valid_negative_preserves_outcomes(self) -> None:
        entries = self._matrix()
        entries[1]["measurements"]["final_forward_displacement_m"] = 0.0
        entries[-1] = copy.deepcopy(self.deadline_report)
        result = evaluator.evaluate_complete_entries(
            entries,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertTrue(result["matrix_valid"])
        self.assertEqual(result["classification"], "valid_complete_negative")
        self.assertEqual(result["outcome_failure_count"], 2)
        self.assertIn(
            "R23D18_FORWARD_DISPLACEMENT",
            result["cell_evaluations"][1]["outcome"]["failed_gate_ids"],
        )
        self.assertIn(
            "R23D18_QUIESCENT_TAPER",
            result["cell_evaluations"][-1]["outcome"]["failed_gate_ids"],
        )

    def test_missing_extra_order_duplicate_and_source_rewrite_are_invalid(self) -> None:
        cases: list[tuple[list[dict[str, object]], str]] = []
        missing = self._matrix()[:-1]
        cases.append((missing, "R23D18_MATRIX_ENTRY_COUNT"))
        extra = self._matrix() + [copy.deepcopy(self._matrix()[-1])]
        cases.append((extra, "R23D18_MATRIX_EXTRA_ENTRY"))
        reversed_entries = list(reversed(self._matrix()))
        cases.append((reversed_entries, "R23D18_MATRIX_ORDER_OR_IDENTITY"))
        duplicate = self._matrix()
        duplicate[1] = copy.deepcopy(duplicate[0])
        cases.append((duplicate, "R23D18_MATRIX_DUPLICATE"))
        for entries, failure in cases:
            result = evaluator.evaluate_complete_entries(
                entries,
                expected_source_commit=self.SOURCE_COMMIT,
                allow_test_artifacts=True,
            )
            self.assertFalse(result["matrix_valid"])
            self.assertEqual(
                result["classification"], "invalid_or_incomplete_complete_matrix"
            )
            self.assertIn(failure, result["failure_codes"])

        source = self._matrix()
        source[4]["source_commit"] = "b" * 40
        result = evaluator.evaluate_complete_entries(
            source,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(result["matrix_valid"])
        self.assertTrue(
            any("R23D18_SOURCE_COMMIT_EXPECTED" in code for code in result["failure_codes"])
        )

    def test_trace_summary_cas_path_and_unknown_fields_fail_closed(self) -> None:
        cell = design.matrix_cells()[0]
        report = copy.deepcopy(self.reports[cell.cell_id])
        report["trace_summary"]["taper_outcome"]["first_passive_step"] = 31
        evaluation = evaluator.evaluate_entry(
            report,
            cell,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D18_REPORT_TRACE_SUMMARY", evaluation["failure_codes"])

        report = copy.deepcopy(self.reports[cell.cell_id])
        loose = self.root / "loose"
        loose.mkdir(exist_ok=True)
        payload = loose / "payload.bin"
        manifest = loose / "manifest.json"
        shutil.copy2(report["trace_artifact"]["payload_path"], payload)
        shutil.copy2(report["trace_artifact"]["manifest_path"], manifest)
        report["trace_artifact"]["payload_path"] = str(payload)
        report["trace_artifact"]["manifest_path"] = str(manifest)
        evaluation = evaluator.evaluate_entry(
            report,
            cell,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D18_TRACE_ARTIFACT_CAS_PATH", evaluation["failure_codes"])

        report = copy.deepcopy(self.reports[cell.cell_id])
        report["undeclared"] = True
        evaluation = evaluator.evaluate_entry(
            report,
            cell,
            expected_source_commit=self.SOURCE_COMMIT,
            allow_test_artifacts=True,
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D18_REPORT_FIELDS", evaluation["failure_codes"])

    def test_failure_entry_is_retained_as_execution_invalid(self) -> None:
        cell = design.matrix_cells()[0]
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

    def test_real_cli_has_one_direct_matrix_marker(self) -> None:
        root = self.root / "cli"
        root.mkdir(exist_ok=True)
        paths: list[str] = []
        for index, entry in enumerate(self._matrix()):
            path = root / f"entry-{index}.json"
            path.write_text(
                json.dumps(entry, allow_nan=False, sort_keys=True),
                encoding="utf-8",
            )
            paths.append(str(path))
        manifest = root / "manifest.json"
        manifest.write_text(json.dumps(paths), encoding="utf-8")
        process = subprocess.run(
            [
                sys.executable,
                str(Path(evaluator.__file__)),
                "evaluate-complete",
                "--manifest",
                str(manifest),
                "--expected-source-commit",
                self.SOURCE_COMMIT,
                "--allow-test-artifacts",
            ],
            cwd=evaluator.REPO_ROOT,
            capture_output=True,
            check=False,
            text=True,
            timeout=120,
        )
        self.assertEqual(process.returncode, 0, process.stderr)
        marker = "QSDK_R23D18_COMPLETE_EVALUATION "
        matches = [
            line for line in process.stdout.splitlines() if line.startswith(marker)
        ]
        self.assertEqual(len(matches), 1, process.stdout[-1_000:])
        self.assertNotIn("QSDK_R23D18_STAGE_A", process.stdout)
        result = json.loads(matches[0][len(marker) :])
        self.assertEqual(result["classification"], "valid_complete_positive")


if __name__ == "__main__":
    unittest.main()
