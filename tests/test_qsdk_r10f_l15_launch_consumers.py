"""Production early/pair/closer readers on complete synthetic child sources.

No Godot process, physical identity, world or solver is invoked. Retained-file
publication and the official source/authority graph are separate coverage.
"""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_l15_launch_relationship as launch
import qsdk_r10f_physical_closure as closer


def seal(payload: dict) -> dict:
    text = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    return {
        "schema_version": "sporespore_qsdk_r10f_launch_relationship_receipt_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "development_host_process_relationship",
            "question_class": "development",
        },
        "ok": True,
        "payload_json": text,
        "payload_byte_length": len(text.encode("utf-8")),
        "payload_raw_sha256": "sha256:"
        + hashlib.sha256(text.encode("utf-8")).hexdigest(),
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def complete_fixture(case: str = "behavior_positive") -> dict:
    report = closer.l9_synthetic_supervisor(case)
    for index, envelope in enumerate(report["child_envelopes"]):
        context = launch.production_context(
            parent_attempt_id=report["attempt_id"],
            descriptor=report["ordered_child_manifest"][index],
            source_commit=report["source_commit"],
            authority_sha256=report["authority_sha256"],
            runtime_binding=runtime.expected_binding(),
        )
        envelope["process_id"] = 2101 + index
        base = f"2026-01-01T00:00:0{index * 2}"
        envelope["started_utc"] = base + ".0000000Z"
        envelope["completed_utc"] = f"2026-01-01T00:00:0{index * 2 + 1}.0000000Z"
        ready = {
            "schema_version": "sporespore_godot_supervised_termination_ready_v1",
            "termination_protocol_id": "godot_4_7_gdscript_shutdown_containment_v1",
            "termination_nonce": context["termination_nonce"],
            "process_id": envelope["worker_process_id"],
            "worker_receipt_emitted": True,
            "requested_exit_code": envelope["exit_code"],
        }
        payload = {
            "context": context,
            "root_process_id": envelope["process_id"],
            "worker_process_id": envelope["worker_process_id"],
            "started_utc": envelope["started_utc"],
            "observed_utc": base + ".5000000Z",
            "relationship": "descendant",
            "process_chain": [
                {
                    "process_id": envelope["worker_process_id"],
                    "parent_process_id": envelope["process_id"],
                    "created_utc": base + ".2000000Z",
                    "executable_path": context["worker_image"]["path"],
                },
                {
                    "process_id": envelope["process_id"],
                    "parent_process_id": 9001,
                    "created_utc": base + ".1000000Z",
                    "executable_path": context["root_image"]["path"],
                },
            ],
            "ready_line": closer.READY_MARKER
            + json.dumps(ready, separators=(",", ":")),
            "ready_receipt": ready,
        }
        envelope["r10f_l15_launch_relationship"] = seal(payload)
        envelope["termination_ready_receipt"] = ready
    report["process_population_evaluation"] = closer.l9_synthetic_population(
        report["child_envelopes"],
        report["attempt_id"],
        report["source_commit"],
        report["authority_sha256"],
    )
    return report


def pair_readers(cases: list[dict]) -> dict:
    result = subprocess.run(
        [
            "C:/Program Files/PowerShell/7/pwsh.exe",
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(ROOT / "tests/test_qsdk_r10f_l15_launch_consumers.ps1"),
        ],
        cwd=ROOT,
        input=json.dumps({"cases": cases}, separators=(",", ":")),
        text=True,
        capture_output=True,
        timeout=60,
        check=True,
    )
    if result.stderr:
        raise AssertionError(result.stderr)
    return json.loads(result.stdout)


def child_projection(report: dict, index: int = 0) -> dict:
    return closer.validate_l9_child_envelope(
        report["child_envelopes"][index],
        report["ordered_child_manifest"][index],
        parent_attempt_id=report["attempt_id"],
        source_commit=report["source_commit"],
        authority_sha256=report["authority_sha256"],
        verify_files=False,
        require_l15_launch=True,
    )


class ProductionLaunchConsumers(unittest.TestCase):
    def test_actual_retained_file_reader_binds_proof_and_exact_ready_line(self):
        report = complete_fixture()
        evidence = (ROOT.parent / "SporeSpore_Evidence").resolve()
        # Disposable source-only fixtures live in the declared evidence root.
        # No old evidence or physical identity is opened or changed.
        with tempfile.TemporaryDirectory(
            prefix="qsdk-r10f-l15-launch-files-", dir=evidence
        ) as directory:
            child_root = Path(directory).resolve()
            self.assertEqual(child_root.parent, evidence)
            self.assertTrue(child_root.name.startswith("qsdk-r10f-l15-launch-files-"))
            envelope = copy.deepcopy(report["child_envelopes"][0])
            descriptor = copy.deepcopy(report["ordered_child_manifest"][0])
            envelope["evidence_path"] = descriptor["evidence_path"] = (
                child_root.as_posix()
            )
            ready = envelope["termination_ready_receipt"]
            payload = json.loads(
                envelope["r10f_l15_launch_relationship"]["payload_json"]
            )
            stdout = (
                closer.RAW_MARKER
                + json.dumps(envelope["report"], separators=(",", ":"))
                + "\n"
                + payload["ready_line"]
                + "\n"
            )
            identity = {
                "schema_version": closer.CHILD_ATTEMPT_SCHEMA,
                "gate_id": "QSDK-R10F",
                "repair_id": closer.REPAIR_ID,
                "status": "reserved_and_retained_before_first_child_start",
                "parent_attempt_id": report["attempt_id"],
                "child_attempt_id": descriptor["child_attempt_id"],
                "launch_index": descriptor["launch_index"],
                "role": descriptor["role"],
                "termination_nonce": descriptor["termination_nonce"],
                "evidence_path": child_root.as_posix(),
                "source_commit": report["source_commit"],
                "authority_sha256": report["authority_sha256"],
                "child_retry_count": 0,
                "child_replacement_count": 0,
                "physical_acceptance_authority": False,
                "release_authority": False,
            }
            termination = {
                key: envelope[key]
                for key in (
                    "exit_code",
                    "started_utc",
                    "completed_utc",
                    "process_id",
                    "worker_process_id",
                    "termination_protocol_valid",
                    "r10f_l15_launch_relationship",
                    "termination_ready_receipt",
                )
            }
            termination.update(
                timed_out=False,
                stdout=stdout,
                stderr="",
                supervisor_terminated=True,
                termination_protocol_failure_code="",
            )

            def write(name, value):
                (child_root / name).write_bytes(
                    (
                        json.dumps(value, ensure_ascii=False, separators=(",", ":"))
                        + "\n"
                    ).encode("utf-8")
                )

            write("child_attempt_identity.json", identity)
            (child_root / "worker.stdout.txt").write_bytes(stdout.encode("utf-8"))
            (child_root / "worker.stderr.txt").write_bytes(b"")
            write("engine_health.json", closer.project_l9_engine_health(""))
            write("worker_report.json", envelope["report"])

            def refresh(term):
                write("termination_receipt.json", term)
                envelope["retained_artifact_bindings"] = {
                    role: closer.file_identity(child_root / name)
                    for role, name in (
                        ("child_attempt_identity", "child_attempt_identity.json"),
                        ("worker_stdout", "worker.stdout.txt"),
                        ("worker_stderr", "worker.stderr.txt"),
                        ("termination_receipt", "termination_receipt.json"),
                        ("engine_health", "engine_health.json"),
                        ("worker_report", "worker_report.json"),
                    )
                }
                write("child_envelope.json", envelope)

            def read():
                return closer.validate_l9_child_envelope(
                    envelope,
                    descriptor,
                    parent_attempt_id=report["attempt_id"],
                    source_commit=report["source_commit"],
                    authority_sha256=report["authority_sha256"],
                    verify_files=True,
                    require_l15_launch=True,
                )

            refresh(termination)
            self.assertIs(read()["child_valid"], True)
            for key in ("r10f_l15_launch_relationship", "termination_ready_receipt"):
                changed = copy.deepcopy(termination)
                changed.pop(key)
                refresh(changed)
                with self.assertRaisesRegex(
                    closer.ClosureFailure, "L15_TERMINATION_FILE_SOURCE_BINDING"
                ):
                    read()
            changed_payload = copy.deepcopy(payload)
            changed_payload["ready_line"] = closer.READY_MARKER + json.dumps(
                ready, indent=None, separators=(", ", ": ")
            )
            envelope["r10f_l15_launch_relationship"] = seal(changed_payload)
            changed = copy.deepcopy(termination)
            changed["r10f_l15_launch_relationship"] = envelope[
                "r10f_l15_launch_relationship"
            ]
            refresh(changed)
            with self.assertRaisesRegex(
                closer.ClosureFailure, "L15_READY_LINE_BYTE_SOURCE_BINDING"
            ):
                read()

    def test_complete_positive_negative_and_precondition_branches(self):
        cases = [
            {"name": name, "report": complete_fixture(name)}
            for name in (
                "behavior_positive",
                "behavior_negative",
                "precondition_negative",
            )
        ]
        outputs = pair_readers(cases)
        for case, actual in zip(cases, outputs["results"]):
            with self.subTest(case["name"]):
                self.assertIs(actual["early_ok"], True, actual)
                # A valid precondition negative never entered the recovery
                # route. The launch repair must not promote that old boundary.
                expected_route = case["name"] != "precondition_negative"
                self.assertIs(actual["pair_route_valid"], expected_route, actual)
                self.assertEqual(1, actual["evaluator_invocation_count"])
                self.assertEqual([], actual["pair_errors"])
                independent = closer.validate_l9_report(
                    case["report"],
                    report_path=None,
                    verify_files=False,
                    require_l15_launch=True,
                )
                self.assertIs(independent["route_execution_valid"], expected_route)
        self.assertEqual(0, outputs["world_build_count"])

    def test_missing_or_resealed_proof_never_uses_legacy_fallback(self):
        cases = []
        base = complete_fixture()
        for name in (
            "missing_proof",
            "same_pid_without_proof",
            "changed_root",
            "wrong_nonce",
            "coherently_forged_nonce",
            "wrong_runtime",
            "after_exit",
            "missing_ready",
            "false_health",
            "missing_peer",
        ):
            report = copy.deepcopy(base)
            envelope = report["child_envelopes"][0]
            payload = json.loads(
                envelope["r10f_l15_launch_relationship"]["payload_json"]
            )
            if name in ("missing_proof", "same_pid_without_proof"):
                del envelope["r10f_l15_launch_relationship"]
                if name == "same_pid_without_proof":
                    envelope["process_id"] = envelope["worker_process_id"]
            elif name == "changed_root":
                payload["root_process_id"] += 1
                envelope["r10f_l15_launch_relationship"] = seal(payload)
            elif name == "wrong_nonce":
                payload["context"]["termination_nonce"] = "f" * 32
                envelope["r10f_l15_launch_relationship"] = seal(payload)
            elif name == "coherently_forged_nonce":
                # Keep the parent manifest fixed while rewriting every child
                # copy. The child cannot select its own expected nonce.
                envelope["termination_nonce"] = "f" * 32
                envelope["termination_ready_receipt"]["termination_nonce"] = "f" * 32
                payload["context"]["termination_nonce"] = "f" * 32
                payload["ready_receipt"]["termination_nonce"] = "f" * 32
                payload["ready_line"] = closer.READY_MARKER + json.dumps(
                    payload["ready_receipt"], separators=(",", ":")
                )
                envelope["r10f_l15_launch_relationship"] = seal(payload)
            elif name == "wrong_runtime":
                payload["context"]["worker_image"]["raw_sha256"] = "sha256:" + "f" * 64
                envelope["r10f_l15_launch_relationship"] = seal(payload)
            elif name == "after_exit":
                payload["observed_utc"] = "2026-01-01T00:00:02.0000000Z"
                envelope["r10f_l15_launch_relationship"] = seal(payload)
            elif name == "missing_ready":
                del envelope["termination_ready_receipt"]
            elif name == "false_health":
                envelope["engine_health_passed"] = False
            elif name == "missing_peer":
                report["child_envelopes"] = report["child_envelopes"][:1]
            cases.append({"name": name, "report": report})
        results = pair_readers(cases)["results"]
        for case, actual in zip(cases, results):
            with self.subTest(case["name"]):
                self.assertIs(actual["pair_route_valid"], False, actual)
                self.assertEqual(0, actual["evaluator_invocation_count"], actual)
                if case["name"] != "missing_peer":
                    self.assertIs(actual["early_ok"], False, actual)
                    if case["name"] == "coherently_forged_nonce":
                        with self.assertRaises(closer.ClosureFailure):
                            child_projection(case["report"])
                    else:
                        self.assertIs(
                            child_projection(case["report"])["child_valid"], False
                        )

    def test_legacy_report_is_not_reclassified_by_new_opt_in(self):
        legacy = closer.l9_synthetic_supervisor("behavior_positive")
        self.assertIs(
            closer.validate_l9_report(legacy, report_path=None, verify_files=False)[
                "route_execution_valid"
            ],
            True,
        )
        self.assertIs(child_projection(legacy)["child_valid"], False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
