"""Focused zero-world tests for the R23D43 Rapier repair successor."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import r23d43_rapier_retention_hardened_turning as design  # noqa: E402
import r23d43_rapier_retention_hardened_turning_evaluator as evaluator  # noqa: E402


def synthetic_rows() -> tuple[design.Cell, list[dict[str, object]]]:
    item = design.cells()[0]
    return item, [
        evaluator.parent._synthetic_row(item, step)
        for step in range(design.CONTROLLER_STEPS)
    ]


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    path.write_text(
        json.dumps(rows, allow_nan=False, separators=(",", ":"), sort_keys=True),
        encoding="utf-8",
        newline="\n",
    )


class R23D43EvaluatorTests(unittest.TestCase):
    def test_declaration_and_complete_focused_preflight(self) -> None:
        declaration = evaluator.load_declaration()
        receipt = evaluator.run_zero_world_preflight()
        self.assertEqual(declaration["campaign_id"], design.CAMPAIGN_ID)
        self.assertTrue(declaration["immutable_lineage"]["r23d42_identity_consumed"])
        self.assertEqual(len(design.cells()), 3)
        self.assertEqual(receipt["valid_trace_canary_count"], 3)
        self.assertEqual(receipt["trace_mutation_rejection_count"], 1)
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_trace_mutation_and_complete_order_are_fail_closed(self) -> None:
        item, rows = synthetic_rows()
        self.assertTrue(evaluator.validate_trace(item.cell_id, rows)["ok"])
        mutated = copy.deepcopy(rows)
        mutated[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
        self.assertFalse(evaluator.validate_trace(item.cell_id, mutated)["ok"])
        with self.assertRaises(evaluator.R23D43EvaluationError):
            evaluator.evaluate_complete_entries([], expected_source_commit="a" * 40)

    def test_test_only_exact_publisher_route_retains_canonical_trace(self) -> None:
        item, rows = synthetic_rows()
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
            artifact = receipt["trace_artifact"]
            self.assertTrue(artifact["test_only"])
            self.assertTrue(Path(artifact["payload_path"]).is_file())
            self.assertTrue(Path(artifact["manifest_path"]).is_file())
            self.assertEqual(receipt["trace_summary"]["row_count"], 2_992)
            self.assertEqual(receipt["world_build_count"], 0)

    def test_failed_publisher_retains_bounded_stdout_and_stderr(self) -> None:
        item, rows = synthetic_rows()
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
                with self.assertRaises(evaluator.R23D43EvaluationError) as raised:
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

    def test_git_blob_shaped_materialization_uses_its_own_publisher(self) -> None:
        item, rows = synthetic_rows()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            materialized = root / "materialized"
            materialized_sdk = materialized / "sdk"
            materialized_turning = materialized_sdk / "turning"
            materialized_turning.mkdir(parents=True)
            for name in (
                "r23d31_cycle_integrated_measurement.py",
                "r23d34_native_r23d29_transfer.py",
                "r23d34_native_r23d29_transfer_evaluator.py",
                "r23d42_three_engine_startup_ramp_turning.py",
                "r23d42_three_engine_startup_ramp_turning_evaluator.py",
                "r23d43_rapier_retention_hardened_turning.py",
                "r23d43_rapier_retention_hardened_turning_evaluator.py",
                "r23d43_rapier_retention_hardened_turning_preregistration_v1.json",
            ):
                shutil.copy2(ROOT / name, materialized_turning / name)
            for name in (
                "content_addressed_artifact_store.ps1",
                "publish_qsdk_r23d43_trace.ps1",
            ):
                shutil.copy2(evaluator.SDK_ROOT / name, materialized_sdk / name)
            evidence = root / "test-evidence"
            attempt = evidence / "attempt"
            attempt.mkdir(parents=True)
            rows_path = attempt / "input.rows.json"
            write_rows(rows_path, rows)
            process = subprocess.run(
                [
                    sys.executable,
                    str(
                        materialized_turning
                        / "r23d43_rapier_retention_hardened_turning_evaluator.py"
                    ),
                    "retain-trace",
                    "--stage-id",
                    design.STAGE_ID,
                    "--cell-id",
                    item.cell_id,
                    "--rows-json",
                    str(rows_path),
                    "--source-root",
                    str(materialized),
                    "--repo-root",
                    str(evaluator.REPO_ROOT),
                    "--attempt-root",
                    str(attempt),
                    "--powershell",
                    "pwsh",
                    "--test-only",
                    "--evidence-root-override",
                    str(evidence),
                ],
                cwd=materialized,
                capture_output=True,
                check=False,
                text=True,
                timeout=180,
            )
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertIn("QSDK_R23D43_TRACE_RETENTION ", process.stdout)
            self.assertNotIn(str(evaluator.PUBLISHER_PATH), process.stdout)


if __name__ == "__main__":
    unittest.main()
