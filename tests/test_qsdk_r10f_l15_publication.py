"""Actual report writer and full post-allocation caller branches, zero physics."""

from __future__ import annotations

import json
import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_physical_closure as closer


def write_fixture_json(path: Path, value: dict) -> None:
    # Callers own a checked disposable fixture sandbox, never retained evidence.
    with path.open("xb") as stream:
        stream.write((json.dumps(value, ensure_ascii=False) + "\n").encode("utf-8"))


def retain_synthetic_children(report: dict, root: Path) -> None:
    for descriptor, envelope in zip(
        report["ordered_child_manifest"], report["child_envelopes"]
    ):
        child_root = (
            root / "children" / f'{descriptor["launch_index"]:02d}-{descriptor["role"]}'
        )
        child_root.mkdir(parents=True)
        descriptor["evidence_path"] = envelope["evidence_path"] = child_root.as_posix()
        identity = dict(descriptor)
        identity.update(
            schema_version=closer.CHILD_ATTEMPT_SCHEMA,
            gate_id="QSDK-R10F",
            repair_id=closer.REPAIR_ID,
            status="reserved_and_retained_before_first_child_start",
            parent_attempt_id=report["attempt_id"],
            source_commit=report["source_commit"],
            authority_sha256=report["authority_sha256"],
            physical_acceptance_authority=False,
            release_authority=False,
        )
        ready = {
            "schema_version": "sporespore_godot_supervised_termination_ready_v1",
            "termination_protocol_id": "godot_4_7_gdscript_shutdown_containment_v1",
            "termination_nonce": envelope["termination_nonce"],
            "process_id": envelope["worker_process_id"],
            "worker_receipt_emitted": True,
            "requested_exit_code": envelope["exit_code"],
        }
        stdout = (
            closer.RAW_MARKER
            + json.dumps(envelope["report"])
            + "\n"
            + closer.READY_MARKER
            + json.dumps(ready)
            + "\n"
        )
        termination = {
            key: envelope[key]
            for key in (
                "exit_code",
                "started_utc",
                "completed_utc",
                "process_id",
                "worker_process_id",
                "termination_protocol_valid",
            )
        }
        termination.update(
            stdout=stdout,
            stderr="",
            timed_out=False,
            supervisor_terminated=True,
            termination_protocol_failure_code="",
            termination_ready_receipt=ready,
        )
        (child_root / "worker.stdout.txt").write_bytes(stdout.encode("utf-8"))
        (child_root / "worker.stderr.txt").write_bytes(b"")
        for name, value in (
            ("child_attempt_identity.json", identity),
            ("termination_receipt.json", termination),
            ("engine_health.json", closer.project_l9_engine_health("")),
            ("worker_report.json", envelope["report"]),
        ):
            write_fixture_json(child_root / name, value)
        envelope["retained_artifact_bindings"] = {
            key: closer.file_identity(child_root / name)
            for key, name in (
                ("child_attempt_identity", "child_attempt_identity.json"),
                ("worker_stdout", "worker.stdout.txt"),
                ("worker_stderr", "worker.stderr.txt"),
                ("termination_receipt", "termination_receipt.json"),
                ("engine_health", "engine_health.json"),
                ("worker_report", "worker_report.json"),
            )
        }
        write_fixture_json(child_root / "child_envelope.json", envelope)


def invoke(case: str, inspect_files=None) -> dict:
    kind = (
        "behavior_negative"
        if case == "caller_negative"
        else (
            "invalid_active_child"
            if case == "caller_invalid_active"
            else "behavior_positive"
        )
    )
    report = closer.l9_synthetic_supervisor(kind)
    if case == "caller_invalid_baseline":
        # A valid-looking configuration is a paired consistency question, not
        # an early launch refusal. A nonzero child exit exercises that branch.
        report["child_envelopes"][0]["exit_code"] = 1
    evidence = (ROOT.parent / "SporeSpore_Evidence").resolve()
    with tempfile.TemporaryDirectory(
        prefix="qsdk-r10f-l15-publication-", dir=evidence
    ) as directory:
        path = Path(directory).resolve()
        assert path.parent == evidence and path.name.startswith(
            "qsdk-r10f-l15-publication-"
        )
        run = subprocess.run(
            [
                "C:/Program Files/PowerShell/7/pwsh.exe",
                "-NoProfile",
                "-NonInteractive",
                "-File",
                str(ROOT / "tests/test_qsdk_r10f_l15_publication.ps1"),
                "-Case",
                case,
            ],
            cwd=ROOT,
            input=json.dumps(
                {"report": report, "fixture_root": str(path)}, separators=(",", ":")
            ),
            capture_output=True,
            text=True,
            timeout=60,
        )
        control_path = path / "test_control.json"
        if not control_path.is_file():
            raise AssertionError(
                f"PUBLICATION_CONTROL_MISSING: {run.returncode}: {run.stderr}: {run.stdout[:1000]}"
            )
        control = json.loads(control_path.read_bytes())
        primary_path = path / "supervisor_result.json"
        primary_bytes = primary_path.read_bytes() if primary_path.is_file() else None
        primary = (
            None
            if primary_bytes is None or case == "partial_primary_exception"
            else json.loads(primary_bytes)
        )
        terminal = path / "terminal_supervisor_failure.json"
        markers = [
            line[len(control["physical_marker"]) :]
            for line in run.stdout.splitlines()
            if line.startswith(control["physical_marker"])
        ]
        result = {
            "exit": run.returncode,
            "stdout": run.stdout,
            "stderr": run.stderr,
            "control": control,
            "primary": primary,
            "primary_bytes": primary_bytes,
            "markers": markers,
            "terminal": (
                json.loads(terminal.read_bytes()) if terminal.exists() else None
            ),
        }
        if result["terminal"] is not None:
            result["retention_audit"] = (
                closer.validate_l15_primary_report_failure_retention(
                    result["terminal"], report_path=terminal
                )
            )
            try:
                closer.validate_l9_report(
                    primary or {},
                    report_path=primary_path,
                    verify_files=True,
                    require_l15_publication=True,
                )
            except closer.ClosureFailure as exc:
                result["primary_only_refusal"] = str(exc)
            else:
                raise AssertionError("L15_LATER_FAILURE_WAS_IGNORED")
        if inspect_files is not None:
            inspect_files(path, result)
        return result


class SupervisorPublication(unittest.TestCase):
    def test_writer_returns_exactly_one_dictionary_and_publishes_once(self):
        result = invoke("writer")
        self.assertEqual(0, result["exit"], result["stderr"])
        self.assertEqual("", result["control"]["caught_failure"])
        self.assertEqual(1, result["control"]["typed_output_count"])
        self.assertIs(result["control"]["typed_dictionary"], True)
        self.assertEqual(1, len(result["markers"]))
        self.assertEqual(result["primary"], json.loads(result["markers"][0]))

    def test_actual_complete_early_and_full_pair_callers(self):
        for case, expected_exit, children, valid in (
            ("caller_positive", 0, 2, True),
            ("caller_negative", 0, 2, True),
            ("caller_invalid_baseline", 1, 1, False),
            ("caller_invalid_active", 1, 2, False),
        ):
            with self.subTest(case):
                result = invoke(case)
                self.assertEqual(expected_exit, result["exit"], result["control"])
                self.assertEqual("", result["control"]["caught_failure"])
                self.assertEqual(
                    children, result["control"]["child_fixture_call_count"]
                )
                self.assertEqual(1, len(result["markers"]))
                self.assertEqual(result["primary"], json.loads(result["markers"][0]))
                self.assertIs(result["primary"]["ok"], valid)
                self.assertEqual(0, result["control"]["world_build_count"])

    def test_duplicate_or_changed_source_cannot_republish_or_overwrite(self):
        for case, error, markers in (
            ("duplicate", "L15_PRIMARY_MARKER_ALREADY_PUBLISHED", 1),
            ("changed_dictionary", "L15_PRIMARY_RETURN_FILE_MISMATCH", 0),
            ("changed_file", "L15_PRIMARY_FILE_CHANGED", 0),
            ("writer_already_exists", "already exists", 0),
        ):
            with self.subTest(case):
                result = invoke(case)
                self.assertIn(error, result["control"]["caught_failure"])
                self.assertEqual(markers, len(result["markers"]))
                self.assertIs(result["primary"]["ok"], True)
                if case != "changed_file":
                    self.assertEqual(
                        result["control"]["primary_original_binding"],
                        result["control"]["primary_retention"]["primary_file_binding"],
                    )

    def test_actual_later_catch_preserves_and_binds_primary_report(self):
        result = invoke("post_publish_exception")
        self.assertEqual(1, result["exit"], result["control"])
        self.assertEqual(1, len(result["markers"]))
        self.assertIs(result["primary"]["ok"], True)
        self.assertIs(result["terminal"]["ok"], False)
        self.assertEqual(
            "L15_DECLARED_TEST_EXCEPTION:post_publish_exception",
            result["terminal"]["failure_code"],
        )
        retention = result["terminal"]["l15_primary_report_failure_retention"]
        self.assertEqual(
            result["control"]["primary_original_binding"],
            retention["primary_file_binding"],
        )
        self.assertIs(retention["primary_report_replaced"], False)
        self.assertIs(retention["primary_marker_published"], True)
        self.assertEqual(
            retention["primary_written_binding"], retention["primary_file_binding"]
        )
        self.assertIs(
            result["retention_audit"]["original_written_bytes_still_present"], True
        )
        self.assertEqual(
            "L15_LATER_TERMINAL_FAILURE_REQUIRES_TERMINAL_CLOSURE",
            result["primary_only_refusal"],
        )

    def test_early_partial_written_and_changed_primary_failure_sources(self):
        for case, exists, completed, published, original_present in (
            ("before_primary_exception", False, False, False, None),
            ("partial_primary_exception", True, False, False, None),
            ("post_write_exception", True, True, False, True),
            ("post_publish_changed_primary_exception", True, True, True, False),
        ):
            with self.subTest(case):
                result = invoke(case)
                self.assertEqual(1, result["exit"], result["control"])
                retention = result["terminal"]["l15_primary_report_failure_retention"]
                self.assertIs(retention["primary_file_exists"], exists)
                self.assertIs(retention["primary_write_completed"], completed)
                self.assertIs(retention["primary_marker_published"], published)
                self.assertEqual(int(published), len(result["markers"]))
                self.assertIs(
                    result["retention_audit"]["original_written_bytes_still_present"],
                    original_present,
                )
                if case == "partial_primary_exception":
                    self.assertEqual(b'{"incomplete":', result["primary_bytes"])
                self.assertIs(
                    result["retention_audit"]["primary_json_parsed_or_repaired"], False
                )

    def test_independent_reader_rejects_forged_retention(self):
        def inspect_files(path, result):
            terminal = path / "terminal_supervisor_failure.json"
            base = result["terminal"]
            changes = (
                (("primary_file_exists",), False),
                (("primary_file_exists",), 1),
                (("primary_write_completed",), False),
                (("primary_marker_published",), 1),
                (("primary_written_binding",), None),
                (("primary_file_binding", "byte_length"), 1.0),
                (("primary_file_binding", "byte_length"), 1),
                (("primary_file_binding", "raw_sha256"), "sha256:" + "f" * 64),
                (
                    ("primary_written_binding", "path"),
                    (path / "elsewhere.json").as_posix(),
                ),
                (("primary_file_binding",), None),
                (("primary_file_binding_failure",), "invented_failure_with_bound_file"),
                (("primary_report_replaced",), True),
                (("physical_acceptance_authority",), True),
                (("release_authority",), True),
            )
            for keys, value in changes:
                changed = copy.deepcopy(base)
                target = changed["l15_primary_report_failure_retention"]
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = value
                with self.subTest(keys=keys, value=value), self.assertRaises(
                    closer.ClosureFailure
                ):
                    closer.validate_l15_primary_report_failure_retention(
                        changed, report_path=terminal
                    )
            for missing in base["l15_primary_report_failure_retention"]:
                changed = copy.deepcopy(base)
                del changed["l15_primary_report_failure_retention"][missing]
                with self.subTest(missing=missing), self.assertRaises(
                    closer.ClosureFailure
                ):
                    closer.validate_l15_primary_report_failure_retention(
                        changed, report_path=terminal
                    )
            # A previously unhashable file can be read now, but that supplies
            # only today's binding, never a fabricated error-time binding.
            changed = copy.deepcopy(base)
            changed["l15_primary_report_failure_retention"].update(
                primary_file_binding=None,
                primary_file_binding_failure="declared_fixture_read_error",
            )
            audit = closer.validate_l15_primary_report_failure_retention(
                changed, report_path=terminal
            )
            self.assertIs(audit["error_time_bytes_independently_verified"], False)
            self.assertIsNone(audit["primary_error_time_binding"])
            self.assertEqual(
                closer.file_identity(path / "supervisor_result.json"),
                audit["primary_current_file_binding"],
            )
            # Change the fixture after the failure receipt has been sealed.
            # A fresh read must refuse its stale error-time binding.
            with (path / "supervisor_result.json").open("ab") as stream:
                stream.write(b" ")
            with self.assertRaisesRegex(
                closer.ClosureFailure, "L15_PRIMARY_FAILURE_OBSERVED_BYTES_CHANGED"
            ):
                closer.validate_l15_primary_report_failure_retention(
                    base, report_path=terminal
                )

        invoke("post_publish_exception", inspect_files)

    def test_source_selected_mode_and_malformed_terminal_block_primary(self):
        def inspect_files(path, result):
            primary_path = path / "supervisor_result.json"
            (path / "terminal_supervisor_failure.json").write_bytes(
                b"incomplete terminal fixture"
            )
            with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
                with self.assertRaisesRegex(
                    closer.ClosureFailure,
                    "L15_LATER_TERMINAL_FAILURE_REQUIRES_TERMINAL_CLOSURE",
                ):
                    closer.validate_l9_report(
                        result["primary"], report_path=primary_path, verify_files=True
                    )

        invoke("writer", inspect_files)

    def test_whole_terminal_consumer_keeps_valid_children_but_no_route_claim(self):
        def inspect_files(sandbox, result):
            # This is a distinct, synthetic enclosing L14 fixture with the
            # prospective publication reader explicitly selected. It is not
            # the actual catch record above and not a qualified L15 graph.
            # Child validation and every child/parent file read are real. Only
            # the separately qualified authority graph and evidence-root base
            # are fixture seams; no world or physical identity is reserved.
            report = copy.deepcopy(result["primary"])
            root = sandbox / (
                "qsdk-r10f-development-route-ghost-" + report["authority_sha256"][7:23]
            )
            root.mkdir()
            report["evidence_root"] = root.as_posix()
            retain_synthetic_children(report, root)
            report["process_population_evaluation"]["child_evidence_paths"] = [
                descriptor["evidence_path"]
                for descriptor in report["ordered_child_manifest"]
            ]
            primary_path = root / "supervisor_result.json"
            write_fixture_json(primary_path, report)
            attempt = {
                key: copy.deepcopy(report[key])
                for key in (
                    "gate_id",
                    "repair_id",
                    "campaign_id",
                    "campaign_role",
                    "question_class",
                    "source_commit",
                    "authority_sha256",
                    "attempt_id",
                    "ordered_child_manifest",
                    "consumed_predecessor_physical_closure_sha256",
                    "repair_design_sha256",
                    "branch_completeness_addendum_sha256",
                    "same_identity_rerun_permitted",
                    "maximum_campaign_attempt_count",
                    "maximum_child_process_count",
                    "maximum_world_count_per_child",
                    "maximum_total_world_count",
                    "maximum_solver_step_count_per_child",
                    "maximum_total_solver_step_count",
                    "physical_acceptance_authority",
                    "release_authority",
                )
            }
            attempt.update(
                schema_version=closer.ATTEMPT_SCHEMA,
                ledger_scope=closer.ledger_scope("consumed_physical_attempt_identity"),
                status="physical_identity_and_ordered_children_consumed_before_first_child_start",
                seed=closer.SEED,
                child_retry_permitted=False,
                child_replacement_permitted=False,
                physical_execution_authorized=True,
            )
            write_fixture_json(root / "attempt_identity.json", attempt)
            with mock.patch.object(closer, "EVIDENCE_ROOT", sandbox), mock.patch.object(
                closer,
                "validate_l9_authority_files",
                return_value={
                    "authority": {"source_only_authority_graph_fixture": True}
                },
            ):
                positive = closer.validate_l9_report(
                    report,
                    report_path=primary_path,
                    verify_files=True,
                    require_l15_publication=True,
                )
                self.assertIs(positive["route_execution_valid"], True)
                failure = copy.deepcopy(result["terminal"])
                failure.update(
                    repair_id=closer.REPAIR_ID,
                    physical_attempt_root=root.as_posix(),
                    observed_child_envelopes=report["child_envelopes"],
                )
                retention = failure["l15_primary_report_failure_retention"]
                retention.update(
                    primary_written_binding=closer.file_identity(primary_path),
                    primary_file_binding=closer.file_identity(primary_path),
                )
                terminal_path = root / "terminal_supervisor_failure.json"
                write_fixture_json(terminal_path, failure)
                with self.assertRaisesRegex(
                    closer.ClosureFailure,
                    "L15_LATER_TERMINAL_FAILURE_REQUIRES_TERMINAL_CLOSURE",
                ):
                    closer.validate_l9_report(
                        report,
                        report_path=primary_path,
                        verify_files=True,
                        require_l15_publication=True,
                    )
                normalized, outcome = closer.validate_l9_terminal_supervisor_failure(
                    failure,
                    report_path=terminal_path,
                    require_l15_publication=True,
                )
                self.assertEqual(2, normalized["ordered_child_count"])
                self.assertEqual({}, outcome["child_validation_errors"])
                self.assertEqual(
                    set(closer.ARM_ORDER), set(outcome["child_projections"])
                )
                self.assertEqual(
                    "invalid_or_incomplete_no_behavioral_conclusion",
                    outcome["classification"],
                )
                self.assertIs(outcome["route_execution_valid"], False)
                self.assertEqual("none", outcome["scientific_outcome"])
                self.assertIs(
                    outcome["precondition_terminal_dispositions"][
                        "independent_population_validation_performed"
                    ],
                    False,
                )
                self.assertEqual(
                    ["terminal_supervisor_failure_after_primary_publication"],
                    outcome["topology_validation_errors"],
                )
                self.assertEqual(
                    closer.file_identity(primary_path),
                    outcome["evidence_bindings"]["retained_primary_supervisor_result"],
                )

        invoke("post_publish_exception", inspect_files)


if __name__ == "__main__":
    unittest.main(verbosity=2)
