from __future__ import annotations

import copy
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
EVALUATOR_PATH = (
    REPO_ROOT / "sdk/turning/three_engine_turning_route_evaluator.py"
)
SPEC = importlib.util.spec_from_file_location("three_engine_turning_route_evaluator", EVALUATOR_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("turning route evaluator import failed")
evaluator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(evaluator)


class ThreeEngineTurningRouteEvaluatorTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        target = REPO_ROOT / "sdk/target"
        target.mkdir(parents=True, exist_ok=True)
        self._temporary = tempfile.TemporaryDirectory(
            prefix="turning-route-evaluator-test-", dir=target
        )
        self.root = Path(self._temporary.name)
        self.attempt_root = self.root / "attempt"
        self.evidence_root = self.root / "evidence"
        self.attempt_root.mkdir()
        powershell = shutil.which("pwsh")
        if powershell is None:
            self.skipTest("pwsh is required for the production CAS publisher")
        self.powershell = powershell
        self.source_commit = "1" * 40

    def tearDown(self) -> None:
        self._temporary.cleanup()

    def _rows(self, engine_id: str) -> list[dict[str, object]]:
        cell_id = evaluator.expected_cell_id(engine_id)
        return [
            {
                "schema_version": evaluator.TRACE_ROW_SCHEMA,
                "route_id": evaluator.ROUTE_ID,
                "engine_id": engine_id,
                "cell_id": cell_id,
                "campaign_seed": evaluator.DEVELOPMENT_SEED,
                "semantic_step": semantic_step,
                "desired_heading_offset_rad": evaluator.HEADING_OFFSET,
                "native_step_completed": True,
            }
            for semantic_step in range(evaluator.CONTROLLER_STEPS)
        ]

    def _retention(self, engine_id: str) -> dict[str, object]:
        cell_id = evaluator.expected_cell_id(engine_id)
        rows_path = self.root / f"{engine_id}.rows.json"
        rows_path.write_text(json.dumps(self._rows(engine_id)), encoding="utf-8")
        return evaluator.retain_trace(
            engine_id=engine_id,
            cell_id=cell_id,
            rows_json_path=rows_path,
            repo_root=REPO_ROOT,
            attempt_root=self.attempt_root,
            powershell=self.powershell,
            test_only=True,
            evidence_root_override=self.evidence_root,
        )

    def _terminal(self, engine_id: str) -> dict[str, object]:
        retention = self._retention(engine_id)
        return {
            "schema_version": evaluator.CELL_REPORT_SCHEMA,
            "route_id": evaluator.ROUTE_ID,
            "ledger_scope": dict(evaluator.LEDGER_SCOPE),
            "question_class": evaluator.TERMINAL_QUESTION_CLASS,
            "engine_id": engine_id,
            "cell_id": evaluator.expected_cell_id(engine_id),
            "campaign_seed": evaluator.DEVELOPMENT_SEED,
            "arm_id": evaluator.ARM_ID,
            "turn_heading_offset_rad": evaluator.HEADING_OFFSET,
            "source_commit": self.source_commit,
            "execution": {
                "integrity_passed": True,
                "worker_failure_code": "",
                "controller_semantic_step_count": evaluator.CONTROLLER_STEPS,
                "world_attempt_count": 1,
                "world_build_count": 1,
                "trace_retained_before_terminal_entry": True,
                "fixed_horizon_configuration_proved_before_fixture_insertion": True,
                "nonzero_turn_command_step_count": evaluator.CONTROLLER_STEPS,
            },
            "trace_artifact": copy.deepcopy(retention["trace_artifact"]),
            "trace_retention": retention,
            "physical_behavior_thresholds_applied": False,
            "claims": {
                "turning_established": False,
                "portable_basic_turning": False,
                "cross_engine_equivalence": False,
                "arbitrary_quadruped_coverage": False,
                "q_sdk_r23_satisfied": False,
                "release_authorized": False,
                "physical_acceptance_authority": False,
            },
        }

    def test_real_test_only_cas_round_trip_and_complete_evaluation(self) -> None:
        terminals = [self._terminal(engine_id) for engine_id in evaluator.ENGINE_IDS]
        result = evaluator.evaluate_complete_entries(
            terminals, expected_source_commit=self.source_commit
        )
        self.assertTrue(result["route_execution_valid"])
        self.assertEqual(result["execution_valid_engine_count"], 3)
        self.assertEqual(result["complete_evaluator_invocation_count"], 1)
        self.assertFalse(result["physical_behavior_thresholds_applied"])
        self.assertTrue(all(value is False for value in result["claims"].values()))

    def test_terminal_projection_and_cas_mutations_fail_closed(self) -> None:
        terminals = [self._terminal(engine_id) for engine_id in evaluator.ENGINE_IDS]

        root_count = copy.deepcopy(terminals)
        root_count[0]["world_build_count"] = 1
        with self.assertRaisesRegex(
            evaluator.RouteEvaluationError, "SUCCESS_ROOT_COUNTS_FORBIDDEN"
        ):
            evaluator.evaluate_complete_entries(
                root_count, expected_source_commit=self.source_commit
            )

        failure_terminal = copy.deepcopy(terminals)
        failure_terminal[1]["schema_version"] = evaluator.WORKER_FAILURE_SCHEMA
        with self.assertRaisesRegex(
            evaluator.RouteEvaluationError, "SCHEMA_VERSION_INVALID"
        ):
            evaluator.evaluate_complete_entries(
                failure_terminal, expected_source_commit=self.source_commit
            )

        artifact_mutation = copy.deepcopy(terminals)
        artifact_mutation[2]["trace_artifact"]["byte_length"] += 1
        artifact_mutation[2]["trace_retention"]["trace_artifact"]["byte_length"] += 1
        with self.assertRaisesRegex(
            evaluator.RouteEvaluationError, "TRACE_ARTIFACT_BYTES_INVALID"
        ):
            evaluator.evaluate_complete_entries(
                artifact_mutation, expected_source_commit=self.source_commit
            )

        transport_mutation = copy.deepcopy(terminals)
        transport_mutation[0]["trace_artifact"].pop("full_precision")
        transport_mutation[0]["trace_retention"]["trace_artifact"].pop(
            "full_precision"
        )
        with self.assertRaisesRegex(
            evaluator.RouteEvaluationError, "TRACE_ARTIFACT_IDENTITY_INVALID"
        ):
            evaluator.evaluate_complete_entries(
                transport_mutation, expected_source_commit=self.source_commit
            )

        question_mutation = copy.deepcopy(terminals)
        question_mutation[1].pop("question_class")
        with self.assertRaisesRegex(
            evaluator.RouteEvaluationError, "QUESTION_CLASS_INVALID"
        ):
            evaluator.evaluate_complete_entries(
                question_mutation, expected_source_commit=self.source_commit
            )

    def test_retainer_rejects_missing_nonzero_turn_command(self) -> None:
        engine_id = evaluator.ENGINE_IDS[0]
        rows = self._rows(engine_id)
        for row in rows:
            row["desired_heading_offset_rad"] = 0.0
        rows_path = self.root / "zero-command.rows.json"
        rows_path.write_text(json.dumps(rows), encoding="utf-8")
        with self.assertRaisesRegex(
            evaluator.RouteEvaluationError, "NONZERO_COMMAND_MISSING"
        ):
            evaluator.retain_trace(
                engine_id=engine_id,
                cell_id=evaluator.expected_cell_id(engine_id),
                rows_json_path=rows_path,
                repo_root=REPO_ROOT,
                attempt_root=self.attempt_root,
                powershell=self.powershell,
                test_only=True,
                evidence_root_override=self.evidence_root,
            )

    def test_retainer_uses_process_scoped_execution_policy_bypass(self) -> None:
        engine_id = evaluator.ENGINE_IDS[0]
        cell_id = evaluator.expected_cell_id(engine_id)
        rows_path = self.root / "policy.rows.json"
        rows_path.write_text(json.dumps(self._rows(engine_id)), encoding="utf-8")
        observed_command: list[str] = []

        def completed(command: list[str], **_kwargs: object) -> object:
            observed_command.extend(command)
            digest = command[command.index("-ExpectedSha256") + 1]
            byte_length = int(command[command.index("-ExpectedByteLength") + 1])
            artifact = {
                "schema_version": "sporespore_content_addressed_artifact_receipt_v1",
                "sha256": digest,
                "byte_length": byte_length,
                "physical_acceptance_authority": False,
            }
            return evaluator.subprocess.CompletedProcess(
                command,
                0,
                stdout=(evaluator.CAS_MARKER + json.dumps(artifact) + "\n").encode(),
                stderr=b"",
            )

        with mock.patch.object(evaluator.subprocess, "run", side_effect=completed):
            evaluator.retain_trace(
                engine_id=engine_id,
                cell_id=cell_id,
                rows_json_path=rows_path,
                repo_root=REPO_ROOT,
                attempt_root=self.attempt_root,
                powershell=self.powershell,
                test_only=True,
                evidence_root_override=self.evidence_root,
            )
        self.assertEqual(
            observed_command[:7],
            [
                self.powershell,
                "-NoLogo",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(evaluator.PUBLISHER_PATH),
            ],
        )


if __name__ == "__main__":
    unittest.main()
