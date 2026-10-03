from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import r23d50_rapier_cas_path_identity_replay as design
import r23d50_rapier_cas_path_identity_replay_evaluator as evaluator


class R23D50EvaluatorTest(unittest.TestCase):
    def test_complete_synthetic_preflight_is_zero_world_and_wires_path_controls(self) -> None:
        declaration = evaluator.load_declaration()
        receipt = evaluator.run_zero_world_preflight()
        self.assertEqual(declaration["campaign_id"], design.CAMPAIGN_ID)
        self.assertEqual(receipt["valid_trace_canary_count"], 3)
        self.assertEqual(receipt["trace_mutation_rejection_count"], 2)
        self.assertEqual(receipt["same_file_path_spelling_positive_control_count"], 1)
        self.assertEqual(receipt["wrong_file_path_rejection_count"], 1)
        self.assertTrue(receipt["production_cas_binding_override_wired"])
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_samefile_accepts_namespace_alias_and_rejects_different_existing_file(self) -> None:
        left = evaluator.DECLARATION_PATH
        alias = evaluator._alternate_windows_spelling(left)
        wrong = (
            evaluator.ROOT
            / "r23d50_rapier_cas_path_identity_replay_implementation_v1.json"
        )
        self.assertNotEqual(str(left), str(alias))
        self.assertTrue(evaluator._same_existing_file(left, alias))
        self.assertFalse(evaluator._same_existing_file(left, wrong))

    def test_complete_binding_uses_explicit_authority_root_in_materialized_source(self) -> None:
        raw = b'{"synthetic":"trace"}\n'
        digest_hex = hashlib.sha256(raw).hexdigest()
        digest = "sha256:" + digest_hex
        with tempfile.TemporaryDirectory(dir=evaluator.REPO_ROOT) as temporary:
            temporary_root = Path(temporary)
            authority_root = temporary_root / "authority" / "SporeSpore"
            authority_root.mkdir(parents=True)
            evidence = authority_root.parent / "SporeSpore_Evidence"
            directory = evidence / "artifacts" / "sha256" / digest_hex
            directory.mkdir(parents=True)
            payload = directory / "payload.bin"
            payload.write_bytes(raw)
            manifest = directory / "manifest.json"
            manifest.write_text(
                json.dumps(
                    {
                        "schema_version": "sporespore_content_addressed_artifact_manifest_v1",
                        "algorithm": "sha256",
                        "sha256": digest,
                        "byte_length": len(raw),
                        "payload_name": "payload.bin",
                        "media_type": "application/x-ndjson",
                    },
                    separators=(",", ":"),
                    sort_keys=True,
                ),
                encoding="utf-8",
                newline="\n",
            )
            entry = {
                "trace_artifact": {
                    "schema_version": evaluator.ARTIFACT_SCHEMA,
                    "sha256": digest,
                    "byte_length": len(raw),
                    "payload_path": str(evaluator._alternate_windows_spelling(payload)),
                    "manifest_path": str(evaluator._alternate_windows_spelling(manifest)),
                    "test_only": False,
                }
            }
            wrong_materialized_root = temporary_root / "attempt" / "source"
            wrong_materialized_root.mkdir(parents=True)
            with mock.patch.object(
                evaluator.predecessor.parent,
                "REPO_ROOT",
                wrong_materialized_root,
            ):
                self.assertEqual(
                    evaluator._cas_binding_failures(
                        entry, authority_repo_root=authority_root
                    ),
                    [],
                )
                self.assertEqual(
                    evaluator._cas_binding_failures(entry),
                    ["R23D50_TRACE_ARTIFACT_CAS_FILE_IDENTITY"],
                )
            with mock.patch.object(
                evaluator.predecessor.parent,
                "REPO_ROOT",
                authority_root,
            ):
                self.assertEqual(evaluator._cas_binding_failures(entry), [])

    def test_retention_invokes_pinned_publisher_with_process_scoped_bypass(self) -> None:
        item = design.cells()[0]
        rows = evaluator.predecessor.parent._synthetic_rows(item, trigger=False)
        canonical = evaluator.predecessor.parent.inherited._canonical_ndjson(rows)
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
            stdout="QSDK_R23D50_TRACE_CAS " + json.dumps(artifact) + "\n",
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
        self.assertEqual(
            arguments[:6],
            ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"],
        )
        self.assertEqual(Path(arguments[6]), evaluator.PUBLISHER_PATH)
        self.assertEqual(receipt["process_scoped_execution_policy"], "Bypass")
        self.assertTrue(receipt["pinned_publisher_source_invoked"])
        self.assertEqual(receipt["world_build_count"], 0)

    def test_turn_segment_mutation_fails_closed(self) -> None:
        item = design.cells()[0]
        rows = evaluator.predecessor.parent._synthetic_rows(item, trigger=False)
        rows[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
        summary = evaluator.validate_trace(item.cell_id, rows)
        self.assertFalse(summary["ok"])


if __name__ == "__main__":
    unittest.main()
