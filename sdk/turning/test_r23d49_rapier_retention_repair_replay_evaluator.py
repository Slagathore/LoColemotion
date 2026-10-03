from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import r23d49_rapier_retention_repair_replay as design
import r23d49_rapier_retention_repair_replay_evaluator as evaluator


class R23D49EvaluatorTest(unittest.TestCase):
    def test_declaration_and_complete_synthetic_preflight_are_zero_world(self) -> None:
        declaration = evaluator.load_declaration()
        receipt = evaluator.run_zero_world_preflight()
        self.assertEqual(declaration["campaign_id"], design.CAMPAIGN_ID)
        self.assertEqual(receipt["valid_trace_canary_count"], 3)
        self.assertEqual(receipt["trace_mutation_rejection_count"], 2)
        self.assertTrue(receipt["process_scoped_execution_policy_bypass_wiring_present"])
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_retention_invokes_pinned_publisher_with_process_scoped_bypass(self) -> None:
        item = design.cells()[0]
        rows = evaluator.parent._synthetic_rows(item, trigger=False)
        canonical = evaluator.parent.inherited._canonical_ndjson(rows)
        digest = "sha256:" + hashlib.sha256(canonical).hexdigest()
        artifact = {
            "schema_version": evaluator.ARTIFACT_SCHEMA,
            "sha256": digest,
            "byte_length": len(canonical),
            "payload_path": "synthetic-payload",
            "manifest_path": "synthetic-manifest",
            "test_only": True,
            "physical_acceptance_authority": False,
        }
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="QSDK_R23D49_TRACE_CAS " + json.dumps(artifact) + "\n",
            stderr="",
        )
        with tempfile.TemporaryDirectory(dir=evaluator.REPO_ROOT) as temporary:
            evidence_root = Path(temporary) / "evidence"
            attempt_root = evidence_root / "attempt"
            pending = attempt_root / "pending-traces"
            pending.mkdir(parents=True)
            rows_path = pending / "rows.json"
            rows_path.write_text(
                json.dumps(rows, allow_nan=False, separators=(",", ":"), sort_keys=True),
                encoding="utf-8",
                newline="\n",
            )
            with mock.patch.object(
                evaluator.subprocess, "run", return_value=completed
            ) as invoked:
                receipt = evaluator.retain_trace(
                    stage_id=design.STAGE_ID,
                    cell_id=item.cell_id,
                    rows_json_path=rows_path,
                    source_root=evaluator.REPO_ROOT,
                    repo_root=evaluator.REPO_ROOT,
                    attempt_root=attempt_root,
                    powershell="pwsh",
                    test_only=True,
                    evidence_root_override=evidence_root,
                )
        arguments = invoked.call_args.args[0]
        self.assertEqual(arguments[:6], [
            "pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"
        ])
        self.assertEqual(Path(arguments[6]), evaluator.PUBLISHER_PATH)
        self.assertEqual(receipt["process_scoped_execution_policy"], "Bypass")
        self.assertTrue(receipt["pinned_publisher_source_invoked"])
        self.assertTrue(receipt["expected_digest_and_byte_length_verified"])
        self.assertEqual(receipt["world_build_count"], 0)

    def test_turn_segment_mutation_fails_closed(self) -> None:
        item = design.cells()[0]
        rows = evaluator.parent._synthetic_rows(item, trigger=False)
        rows[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
        summary = evaluator.validate_trace(item.cell_id, rows)
        self.assertFalse(summary["ok"])


if __name__ == "__main__":
    unittest.main()
