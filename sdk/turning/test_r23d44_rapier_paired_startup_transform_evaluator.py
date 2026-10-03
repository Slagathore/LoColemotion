"""Focused zero-world tests for the R23D44 paired Rapier successor."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import r23d44_rapier_paired_startup_transform as design  # noqa: E402
import r23d44_rapier_paired_startup_transform_evaluator as evaluator  # noqa: E402


def rows_for(item: design.Cell) -> list[dict[str, object]]:
    return [
        evaluator._synthetic_row(item, step)
        for step in range(design.CONTROLLER_STEPS)
    ]


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    path.write_text(
        json.dumps(rows, allow_nan=False, separators=(",", ":"), sort_keys=True),
        encoding="utf-8",
        newline="\n",
    )


class R23D44EvaluatorTests(unittest.TestCase):
    def test_declaration_and_complete_focused_preflight(self) -> None:
        declaration = evaluator.load_declaration()
        receipt = evaluator.run_zero_world_preflight()
        self.assertEqual(declaration["campaign_id"], design.CAMPAIGN_ID)
        self.assertTrue(
            declaration["paired_causal_development"][
                "seed_was_outcome_exposed_before_preregistration"
            ]
        )
        self.assertEqual(len(design.cells()), 6)
        self.assertEqual(receipt["valid_trace_canary_count"], 6)
        self.assertEqual(receipt["trace_mutation_rejection_count"], 3)
        self.assertEqual(receipt["same_file_path_spelling_positive_control_count"], 1)
        self.assertEqual(receipt["wrong_file_path_rejection_count"], 1)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_candidate_transform_receipts_are_exact_and_not_interchangeable(self) -> None:
        no_ramp = design.cell(
            design.STAGE_ID,
            "rapier_parry",
            "reference_zero",
            design.NO_RAMP_CANDIDATE_ID,
        )
        ramp = design.cell(
            design.STAGE_ID,
            "rapier_parry",
            "reference_zero",
            design.RAMP_CANDIDATE_ID,
        )
        no_ramp_rows = rows_for(no_ramp)
        ramp_rows = rows_for(ramp)
        self.assertTrue(evaluator.validate_trace(no_ramp.cell_id, no_ramp_rows)["ok"])
        self.assertTrue(evaluator.validate_trace(ramp.cell_id, ramp_rows)["ok"])
        self.assertEqual(no_ramp_rows[0]["startup_velocity_scale"], 1.0)
        self.assertEqual(ramp_rows[0]["startup_velocity_scale"], 0.0)
        swapped = copy.deepcopy(no_ramp_rows)
        swapped[0].update(
            startup_ramp_id=design.STARTUP_RAMP_ID,
            startup_velocity_scale=0.0,
            startup_ramp_active=True,
        )
        self.assertFalse(evaluator.validate_trace(no_ramp.cell_id, swapped)["ok"])

    def test_paired_classifier_reports_exact_seed_ramp_regression(self) -> None:
        rows_by_cell = {item.cell_id: rows_for(item) for item in design.cells()}
        for item in design.cells():
            if item.candidate_id == design.RAMP_CANDIDATE_ID and item.arm_id == "positive_heading":
                for row in rows_by_cell[item.cell_id]:
                    row["measured_yaw_rad"] = 0.0

        def fake_evaluate(
            entry: object,
            item: design.Cell,
            *,
            expected_source_commit: str,
            authority_repo_root: Path,
        ) -> tuple[dict[str, object], list[dict[str, object]]]:
            del entry, expected_source_commit, authority_repo_root
            return (
                {
                    "cell_id": item.cell_id,
                    "engine_id": item.engine_id,
                    "candidate_id": item.candidate_id,
                    "arm_id": item.arm_id,
                    "entry_kind": "report",
                    "execution_valid": True,
                    "common_physical_gate_passed": True,
                    "failed_gate_ids": [],
                    "world_attempt_count": 1,
                    "world_build_count": 1,
                },
                rows_by_cell[item.cell_id],
            )

        entries = [{"cell_id": item.cell_id} for item in design.cells()]
        with mock.patch.object(evaluator, "evaluate_entry", side_effect=fake_evaluate):
            result = evaluator.evaluate_complete_entries(
                entries,
                expected_source_commit="a" * 40,
                authority_repo_root=evaluator.REPO_ROOT,
            )
        self.assertEqual(
            result["classification"],
            "valid_complete_ramp_induced_turning_gate_regression_at_seed_21504",
        )
        self.assertTrue(
            result["claims"]["paired_same_seed_startup_transform_effect_characterized"]
        )
        self.assertFalse(result["claims"]["finite_rapier_turning_validation"])
        self.assertIsNotNone(result["paired_continuous_contrasts"])

    def test_test_only_publisher_route_retains_both_transform_schemas(self) -> None:
        for candidate_id in design.CANDIDATE_IDS:
            item = design.cell(
                design.STAGE_ID, "rapier_parry", "reference_zero", candidate_id
            )
            rows = rows_for(item)
            with tempfile.TemporaryDirectory() as directory:
                evidence = Path(directory) / "SporeSpore_Evidence"
                attempt = evidence / "attempt"
                attempt.mkdir(parents=True)
                rows_path = attempt / "input.rows.json"
                write_rows(rows_path, rows)
                receipt = evaluator.retain_trace(
                    stage_id=design.STAGE_ID,
                    cell_id=item.cell_id,
                    rows_json_path=rows_path,
                    source_root=evaluator.REPO_ROOT,
                    repo_root=evaluator.REPO_ROOT,
                    attempt_root=attempt,
                    powershell="pwsh",
                    test_only=True,
                    evidence_root_override=evidence,
                )
                self.assertTrue(receipt["trace_artifact"]["test_only"])
                self.assertEqual(receipt["trace_summary"]["candidate_id"], candidate_id)
                self.assertEqual(receipt["trace_summary"]["row_count"], 2_992)
                self.assertEqual(receipt["world_build_count"], 0)

    def test_failed_publisher_retains_bounded_both_streams(self) -> None:
        item = design.cells()[0]
        rows = rows_for(item)
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "SporeSpore_Evidence"
            attempt = evidence / "attempt"
            attempt.mkdir(parents=True)
            rows_path = attempt / "input.rows.json"
            write_rows(rows_path, rows)
            failure = subprocess.CompletedProcess(
                args=["pwsh"],
                returncode=1,
                stdout="x" * 2_100 + "STDOUT_SENTINEL",
                stderr="y" * 2_100 + "STDERR_SENTINEL",
            )
            with mock.patch.object(evaluator.subprocess, "run", return_value=failure):
                with self.assertRaises(evaluator.R23D44EvaluationError) as raised:
                    evaluator.retain_trace(
                        stage_id=design.STAGE_ID,
                        cell_id=item.cell_id,
                        rows_json_path=rows_path,
                        source_root=evaluator.REPO_ROOT,
                        repo_root=evaluator.REPO_ROOT,
                        attempt_root=attempt,
                        powershell="pwsh",
                        test_only=True,
                        evidence_root_override=evidence,
                    )
            message = str(raised.exception)
            self.assertIn("STDOUT_SENTINEL", message)
            self.assertIn("STDERR_SENTINEL", message)
            self.assertLess(len(message), 4_200)

    def test_same_file_verifier_accepts_namespace_alias_and_rejects_wrong_file(self) -> None:
        ordinary = evaluator.DECLARATION_PATH
        alternate = evaluator._alternate_windows_spelling(ordinary)
        self.assertTrue(evaluator._same_existing_path(ordinary, alternate))
        self.assertFalse(evaluator._same_existing_path(ordinary, evaluator.PUBLISHER_PATH))


if __name__ == "__main__":
    unittest.main()
