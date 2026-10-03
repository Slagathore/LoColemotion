"""Actual emitted abort -> envelope writer -> publisher -> independent readers.

The Godot fixture runs pure SDK calls in a detached abort host. The PowerShell
fixture executes complete production caller/writer bodies, but receives named
nonphysics process sources. No prospective identity or physical run is opened.
"""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture
from test_qsdk_r10f_l15_launch_consumers import complete_fixture, seal
from test_qsdk_r10f_l15_worker_retention import ABORT_MARKER

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_physical_closure as closer
import qsdk_r10f_l15_collection_retention as reader
import qsdk_r10f_l15_launch_relationship as launch
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_l15_collection_context as context_reader

ABORT_BRANCHES = (
    "malformed_reply",
    "dispatch_refusal",
    "missing_memory",
    "missing_current_capture",
)
BRANCH_MARKERS = {
    label: f"QSDK_R10F_L15_SYNTHETIC_ABORT_{label.upper()}_RAW "
    for label in ABORT_BRANCHES
}


def fixture_json(path, value):
    """Only checked, disposable source-fixture files may use this writer."""
    path.write_bytes((json.dumps(value, ensure_ascii=False) + "\n").encode("utf-8"))


class EnclosingCollectionRetention(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.native = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_worker_retention_zero_world.gd",
            "QSDK_R10F_L15_WORKER_RETENTION_ZERO_WORLD ",
            additional_markers=(ABORT_MARKER, *BRANCH_MARKERS.values()),
        )
        emitted = cls.native["captured_additional_marker_texts"][ABORT_MARKER]
        if len(emitted) != 1:
            raise AssertionError("ONE_ACTUAL_ABORT_REQUIRED")
        cls.raw_text = emitted[0]
        cls.raw = reader.parse_json(cls.raw_text)
        cls.identity = cls.native["expected_collection_identity_from_prepared_context"]
        prepared = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_pre_world_context_zero_world.gd",
            "QSDK_R10F_L15_PRE_WORLD_CONTEXT_ZERO_WORLD ",
        )
        cls.context_comparison = prepared["positive_comparison"]
        cls.expected_context_binding = context_reader.raw_binding(
            prepared["expected_capture"]["utf8_text"]
        )
        proof = context_reader.validate_capture(
            prepared["expected_capture"]["utf8_text"],
            expected_raw_binding=cls.expected_context_binding,
            canonical_sha256=closer.canonical_sha256_v1,
        )
        assert reader.same(cls.identity, proof["expected_identity"])
        default = cls.make_enclosing_case(
            cls.raw_text,
            expected_context_binding=cls.expected_context_binding,
            expected_collection_identity=cls.identity,
        )
        cls.directory = default["directory"]
        cls.execution = default["execution"]
        cls.control = default["control"]
        cls.primary = default["primary"]

    @classmethod
    def make_enclosing_case(
        cls,
        raw_text=None,
        *,
        supplied_report=None,
        omit_active_child=False,
        expected_context_binding,
        expected_collection_identity,
    ):
        # Reuse an already emitted exact abort. This helper never starts the
        # native fixture or repeats a collection to reconstruct its payload.
        if raw_text is None and supplied_report is None:
            raise AssertionError("EXPLICIT_WORKER_SOURCE_REQUIRED")
        if type(omit_active_child) is not bool:
            raise AssertionError("MISSING_PEER_FIXTURE_FLAG_KIND")
        raw = reader.parse_json(raw_text) if raw_text is not None else None
        evidence = (ROOT.parent / "SporeSpore_Evidence").resolve()
        owned = tempfile.TemporaryDirectory(
            prefix="qsdk-r10f-l15-enclosing-", dir=evidence
        )
        cls.addClassCleanup(owned.cleanup)
        directory = Path(owned.name).resolve()
        if directory.parent != evidence or not directory.name.startswith(
            "qsdk-r10f-l15-enclosing-"
        ):
            raise AssertionError("DISPOSABLE_FIXTURE_ROOT")
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            report = (
                complete_fixture()
                if supplied_report is None
                else copy.deepcopy(supplied_report)
            )
        if raw is not None:
            report["child_envelopes"][1]["report"] = raw
            report["child_envelopes"][1]["worker_process_id"] = raw["process_id"]
            report["child_envelopes"][1]["exit_code"] = 0 if raw["ok"] is True else 1
        if supplied_report is None:
            # The baseline is synthetic source input. The original active raw
            # report remains byte-for-byte unchanged, including absent metadata.
            report["child_envelopes"][0]["report"][
                "l15_prepared_context_comparison"
            ] = copy.deepcopy(cls.context_comparison)
        for index, descriptor in enumerate(report["ordered_child_manifest"]):
            descriptor["evidence_path"] = (
                directory / "children" / f'{index + 1:02d}-{descriptor["role"]}'
            ).as_posix()
        runs = []
        for index, (descriptor, envelope) in enumerate(
            zip(report["ordered_child_manifest"], report["child_envelopes"])
        ):
            child_root = (
                directory / "children" / f'{index + 1:02d}-{descriptor["role"]}'
            )
            descriptor["evidence_path"] = envelope["evidence_path"] = (
                child_root.as_posix()
            )
            # Synthetic launch sources are explicit. The real launch producer
            # is separately tested; this test isolates byte-retention callers.
            payload = json.loads(
                envelope["r10f_l15_launch_relationship"]["payload_json"]
            )
            context = launch.production_context(
                parent_attempt_id=report["attempt_id"],
                descriptor=descriptor,
                source_commit=report["source_commit"],
                authority_sha256=report["authority_sha256"],
                runtime_binding=runtime.expected_binding(),
            )
            ready = envelope["termination_ready_receipt"]
            ready["process_id"] = envelope["worker_process_id"]
            ready["requested_exit_code"] = envelope["exit_code"]
            payload.update(
                context=context,
                worker_process_id=envelope["worker_process_id"],
                ready_receipt=ready,
            )
            payload["process_chain"][0]["process_id"] = envelope["worker_process_id"]
            payload["ready_line"] = closer.READY_MARKER + json.dumps(
                ready, separators=(",", ":")
            )
            envelope["r10f_l15_launch_relationship"] = seal(payload)
            text = (
                raw_text
                if index == 1 and raw_text is not None
                else json.dumps(envelope["report"], separators=(",", ":"))
            )
            run = {
                key: envelope[key]
                for key in (
                    "started_utc",
                    "completed_utc",
                    "process_id",
                    "worker_process_id",
                    "exit_code",
                    "termination_protocol_valid",
                    "r10f_l15_launch_relationship",
                    "termination_ready_receipt",
                )
            }
            run.update(
                stdout=closer.RAW_MARKER + text + "\n" + payload["ready_line"] + "\n",
                stderr=(
                    ""
                    if envelope["engine_health_passed"] is True
                    else "ERROR: explicit synthetic source-only engine-health refusal\n"
                ),
                timed_out=False,
                supervisor_terminated=True,
                termination_protocol_failure_code="",
            )
            runs.append(run)
        execution = subprocess.run(
            [
                "C:/Program Files/PowerShell/7/pwsh.exe",
                "-NoProfile",
                "-NonInteractive",
                "-File",
                str(
                    ROOT / "tests/test_qsdk_r10f_l15_collection_enclosing_retention.ps1"
                ),
            ],
            cwd=ROOT,
            input=json.dumps(
                {
                    "report": report,
                    "runs": runs,
                    "fixture_root": str(directory),
                    "omit_active_child_for_missing_peer_test": omit_active_child,
                    "expected_context_binding": expected_context_binding,
                    "expected_collection_identity": expected_collection_identity,
                },
                ensure_ascii=False,
            ),
            text=True,
            encoding="utf-8",
            capture_output=True,
            timeout=180,
        )
        control_path = directory / "test_control.json"
        if not control_path.is_file():
            raise AssertionError(
                f"ENCLOSING_CONTROL_MISSING:{execution.returncode}:{execution.stderr}:{execution.stdout[:1000]}"
            )
        control = json.loads(control_path.read_bytes())
        if control["caught_failure"] or execution.stderr:
            raise AssertionError(f"ENCLOSING_FAILURE:{control}:{execution.stderr}")
        return {
            "directory": directory,
            "execution": execution,
            "control": control,
            "primary": json.loads((directory / "supervisor_result.json").read_bytes()),
        }

    def child(self, report=None, *, verify_files=False, identity=None):
        report = self.primary if report is None else report
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            return closer.validate_l9_child_envelope(
                report["child_envelopes"][1],
                report["ordered_child_manifest"][1],
                parent_attempt_id=report["attempt_id"],
                source_commit=report["source_commit"],
                authority_sha256=report["authority_sha256"],
                verify_files=verify_files,
                expected_l15_collection_identity=(
                    self.identity if identity is None else identity
                ),
                expected_l15_context_binding=self.expected_context_binding,
            )

    def test_exact_emitted_abort_survives_actual_writers_and_independent_file_reader(
        self,
    ):
        self.assertEqual(1, self.execution.returncode)
        self.assertEqual(2, self.control["process_fixture_call_count"])
        self.assertIs(self.control["actual_runtime_image_checks_executed"], True)
        child = self.child(verify_files=True)
        audit = child["collection_failure_retention"]
        self.assertIs(child["child_valid"], False)
        self.assertIs(audit["collection_failure_retention_valid"], True, audit)
        self.assertIs(audit["retention_establishes_valid_child"], False)
        self.assertEqual("abi_refusal", audit["packet_audit"]["native_response_kind"])
        self.assertIs(audit["packet_audit"]["decoded_refusal_whole_value_exact"], True)
        self.assertEqual(509, audit["captured_global_semantic_step"])
        self.assertEqual(1, audit["partial_trace_row_count"])
        retained_raw = self.primary["child_envelopes"][1]["report"]
        self.assertTrue(reader.same(self.raw, retained_raw))
        child_root = Path(child["evidence_path"])
        raw_lines = [
            line[len(closer.RAW_MARKER) :]
            for line in (child_root / "worker.stdout.txt")
            .read_text(encoding="utf-8")
            .splitlines()
            if line.startswith(closer.RAW_MARKER)
        ]
        self.assertEqual([self.raw_text], raw_lines)
        markers = [
            line[len(self.control["physical_marker"]) :]
            for line in self.execution.stdout.splitlines()
            if line.startswith(self.control["physical_marker"])
        ]
        self.assertEqual(1, len(markers))
        self.assertTrue(reader.same(self.primary, reader.parse_json(markers[0])))
        for key in (
            "model_construction_count",
            "world_build_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertEqual(0, self.control[key])

    def test_actual_supervisor_reader_preserves_invalidity_and_retention_separately(
        self,
    ):
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            outcome = closer.validate_l9_report(
                self.primary,
                report_path=None,
                verify_files=False,
                expected_l15_collection_identity=self.identity,
                expected_l15_context_binding=self.expected_context_binding,
            )
        self.assertEqual(
            "invalid_or_incomplete_no_behavioral_conclusion", outcome["classification"]
        )
        self.assertIs(outcome["route_execution_valid"], False)
        self.assertIs(outcome["behavior_passed"], False)
        self.assertEqual("none", outcome["scientific_outcome"])
        self.assertIs(
            outcome["collection_failure_retention_by_arm"][closer.ACTIVE_ARM][
                "collection_failure_retention_valid"
            ],
            True,
        )
        self.assertEqual(0, self.primary["evaluator_invocation_count"])
        self.assertEqual(
            0,
            self.primary["process_population_evaluation"]["evaluator_invocation_count"],
        )

    def test_missing_identity_is_not_inferred_from_the_packet(self):
        with mock.patch.object(
            closer, "REPAIR_ID", "QSDK-R10F-L15"
        ), self.assertRaisesRegex(
            closer.ClosureFailure, "QUALIFIED_COLLECTION_IDENTITY_REQUIRED"
        ):
            closer.validate_l9_report(
                self.primary, report_path=None, verify_files=False
            )
        changed = copy.deepcopy(self.identity)
        changed["task_id"] = "crossed_expected_task"
        audit = self.child(identity=changed)["collection_failure_retention"]
        self.assertIs(audit["collection_failure_retention_valid"], False)
        self.assertIn("REQUEST_IDENTITY:task_id", audit["retention_validation_error"])

    def test_other_actual_abort_stages_keep_exact_sources_without_inventing_calls(self):
        expected = {
            "malformed_reply": (True, "malformed_response"),
            "dispatch_refusal": (True, "not_called"),
            "missing_memory": (False, "SOURCE_LINKS_KEYS"),
            "missing_current_capture": (False, "FAILED_ADVANCE_PACKET_MISSING"),
        }
        self.assertEqual(2, self.native["genuine_compiled_collection_call_count"])
        self.assertEqual(1, self.native["malformed_response_stub_call_count"])
        for label, (retention_valid, classification) in expected.items():
            with self.subTest(label=label):
                marker = BRANCH_MARKERS[label]
                emitted = self.native["captured_additional_marker_texts"][marker]
                self.assertEqual(1, len(emitted))
                original = reader.parse_json(emitted[0])
                case = self.make_enclosing_case(
                    emitted[0],
                    expected_context_binding=self.expected_context_binding,
                    expected_collection_identity=self.identity,
                )
                self.assertEqual(1, case["execution"].returncode)
                self.assertEqual(2, case["control"]["process_fixture_call_count"])
                report = case["primary"]
                self.assertTrue(
                    reader.same(original, report["child_envelopes"][1]["report"])
                )
                child = self.child(report, verify_files=True)
                self.assertIs(child["child_valid"], False)
                audit = child["collection_failure_retention"]
                self.assertIs(
                    audit["collection_failure_retention_valid"], retention_valid
                )
                if retention_valid:
                    self.assertEqual(
                        classification, audit["packet_audit"]["native_response_kind"]
                    )
                else:
                    self.assertIn(classification, audit["retention_validation_error"])
                packet = original["partial_arm"][reader.PARTIAL_PACKET]
                if label == "malformed_reply":
                    self.assertEqual(1, packet["compiled_collection_call_count"])
                    self.assertEqual(
                        b"{deliberately_malformed_transport_reply",
                        reader.verify_bytes(packet["response"]),
                    )
                elif label != "missing_current_capture":
                    self.assertIsNone(packet["request"])
                    self.assertIsNone(packet["response"])
                    self.assertEqual(0, packet["compiled_collection_call_count"])
                    if label == "missing_memory":
                        # The producer stops on the absent memory source. It
                        # keeps the preceding application snapshot, not an
                        # invented empty memory or a complete three-link claim.
                        self.assertEqual(
                            {"source_application"}, packet["source_links"].keys()
                        )
                        self.assertEqual(
                            "L15_COLLECTION_SOURCE_LINK_INVALID:source_memory",
                            packet["transport_failure_code"],
                        )
                else:
                    self.assertEqual({}, packet)
                    self.assertEqual(510, original["solver_step_count"])
                with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
                    outcome = closer.validate_l9_report(
                        report,
                        report_path=None,
                        verify_files=False,
                        expected_l15_collection_identity=self.identity,
                        expected_l15_context_binding=self.expected_context_binding,
                    )
                self.assertIs(outcome["route_execution_valid"], False)
                self.assertEqual("none", outcome["scientific_outcome"])
                self.assertEqual(0, report["evaluator_invocation_count"])

    def test_missing_crossed_stale_and_promoted_partial_records_are_not_qualified(self):
        mutations = []
        for key in (
            reader.PARTIAL_PACKET,
            reader.PARTIAL_STEP,
            reader.PARTIAL_FAILURE,
            "recovery_memory",
            "trace_rows",
        ):
            damaged = copy.deepcopy(self.primary)
            del damaged["child_envelopes"][1]["report"]["partial_arm"][key]
            mutations.append(("missing:" + key, damaged))
        for key, replacement in (
            ("source_commit", "f" * 40),
            ("process_id", 1),
            ("solver_step_count", 510),
            ("global_solver_frame_count", 510),
            ("physical_acceptance_authority", True),
            ("world_build_count", True),
            ("physical_question_opened", False),
            ("physics_state_modified", False),
        ):
            damaged = copy.deepcopy(self.primary)
            damaged["child_envelopes"][1]["report"][key] = replacement
            mutations.append(("report:" + key, damaged))
        for kind in (
            "detail",
            "packet",
            "memory",
            "wrong_capture_step",
            "numeric_counter",
            "trace_integer_outside_canonical_range",
        ):
            damaged = copy.deepcopy(self.primary)
            raw = damaged["child_envelopes"][1]["report"]
            partial = raw["partial_arm"]
            if kind == "detail":
                raw["detail"]["advance"]["failure_code"] = "rewritten_failure"
            elif kind == "packet":
                partial[reader.PARTIAL_PACKET]["response"]["utf8_text"] += " "
            elif kind == "memory":
                partial["recovery_memory"]["phase_steps_observed"] += 1
            elif kind == "wrong_capture_step":
                partial[reader.PARTIAL_STEP] = 508
            elif kind == "trace_integer_outside_canonical_range":
                partial["trace_rows"][0]["invalid_large_integer"] = 10**30
            else:
                partial[reader.PARTIAL_PACKET]["compiled_collection_call_count"] = 1.0
            mutations.append((kind, damaged))
        for label, damaged in mutations:
            with self.subTest(label=label):
                result = self.child(damaged)
                self.assertIs(result["child_valid"], False)
                audit = result["collection_failure_retention"]
                self.assertIs(audit["collection_failure_retention_valid"], False, audit)

    def test_file_reader_refuses_numeric_kind_change_and_rehashed_worker_substitution(
        self,
    ):
        descriptor = self.primary["ordered_child_manifest"][1]
        child_root = Path(descriptor["evidence_path"])
        envelope_path = child_root / "child_envelope.json"
        worker_path = child_root / "worker_report.json"
        originals = {p: p.read_bytes() for p in (envelope_path, worker_path)}
        for kind in (
            "envelope_numeric_kind",
            "worker_numeric_kind",
            "worker_packet_substitution",
        ):
            try:
                damaged = copy.deepcopy(self.primary)
                envelope = damaged["child_envelopes"][1]
                if kind == "envelope_numeric_kind":
                    envelope["report"]["model_construction_count"] = 1.0
                else:
                    changed = copy.deepcopy(envelope["report"])
                    if kind == "worker_numeric_kind":
                        changed["model_construction_count"] = 1.0
                    else:
                        changed["partial_arm"][reader.PARTIAL_PACKET]["response"][
                            "utf8_text"
                        ] += " "
                    fixture_json(worker_path, changed)
                    envelope["retained_artifact_bindings"]["worker_report"] = (
                        closer.file_identity(worker_path)
                    )
                fixture_json(envelope_path, envelope)
                with self.subTest(kind=kind), self.assertRaises(
                    (ValueError, closer.ClosureFailure)
                ):
                    self.child(damaged, verify_files=True)
            finally:
                for path, raw in originals.items():
                    path.write_bytes(raw)
        self.assertIs(
            self.child(verify_files=True)["collection_failure_retention"][
                "collection_failure_retention_valid"
            ],
            True,
        )

    def test_complete_terminal_reader_keeps_failed_collection_with_separate_graph_seam(
        self,
    ):
        # This is a distinct source-only terminal fixture, not an actual later
        # exception or prospective graph. The abort bytes and complete child
        # artifact reader are real; the separately qualified authority graph
        # and evidence-root base are explicitly replaced, like prior tests.
        report = copy.deepcopy(self.primary)
        terminal_root = self.directory / (
            "qsdk-r10f-development-route-ghost-" + report["authority_sha256"][7:23]
        )
        terminal_root.mkdir()
        report["evidence_root"] = terminal_root.as_posix()
        for index, (descriptor, envelope) in enumerate(
            zip(report["ordered_child_manifest"], report["child_envelopes"])
        ):
            old_root = Path(descriptor["evidence_path"])
            new_root = (
                terminal_root / "children" / f'{index + 1:02d}-{descriptor["role"]}'
            )
            new_root.mkdir(parents=True)
            descriptor["evidence_path"] = envelope["evidence_path"] = (
                new_root.as_posix()
            )
            files = {
                "child_attempt_identity": "child_attempt_identity.json",
                "worker_stdout": "worker.stdout.txt",
                "worker_stderr": "worker.stderr.txt",
                "termination_receipt": "termination_receipt.json",
                "engine_health": "engine_health.json",
                "worker_report": "worker_report.json",
            }
            for name in files.values():
                (new_root / name).write_bytes((old_root / name).read_bytes())
            identity_path = new_root / "child_attempt_identity.json"
            identity = json.loads(identity_path.read_bytes())
            identity["evidence_path"] = new_root.as_posix()
            fixture_json(identity_path, identity)
            envelope["retained_artifact_bindings"] = {
                role: closer.file_identity(new_root / name)
                for role, name in files.items()
            }
            fixture_json(new_root / "child_envelope.json", envelope)
        primary_path = terminal_root / "supervisor_result.json"
        fixture_json(primary_path, report)
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
            physical_execution_authorized=True,  # Source-only fixture flag, not authority.
        )
        fixture_json(terminal_root / "attempt_identity.json", attempt)
        counts = closer.l9_observed_counter_projection(report["child_envelopes"])
        primary_binding = closer.file_identity(primary_path)
        failure = {
            "schema_version": "sporespore_qsdk_r10f_supervisor_refusal_v1",
            "gate_id": "QSDK-R10F",
            "repair_id": "QSDK-R10F-L15",
            "campaign_id": closer.CAMPAIGN_ID,
            "campaign_role": "development_route_ghost",
            "question_class": "development",
            "ledger_scope": closer.ledger_scope("consumed_physical_supervisor_failure"),
            "ok": False,
            "mode": "Physical",
            "failure_code": "DECLARED_SYNTHETIC_LATER_EXCEPTION",
            "physical_execution_requested": True,
            "physical_attempt_identity_consumed": True,
            "attempt_id": report["attempt_id"],
            "physical_attempt_root": terminal_root.as_posix(),
            "physical_question_opened": True,
            "observed_completed_child_count": 2,
            "observed_child_envelopes": report["child_envelopes"],
            "count_fields_known": counts["core_known"],
            "model_construction_count": counts["model_construction_count"],
            "world_attempt_count": counts["world_attempt_count"],
            "world_build_count": counts["world_build_count"],
            "solver_step_count": counts["solver_step_count"],
            "native_readback_count": counts[
                "explicit_worker_extra_native_readback_count"
            ],
            "scene_tree_insertion_count": -1,
            "physics_state_modified": counts["physics_state_modified"],
            "physical_acceptance_authority": False,
            "release_authority": False,
            "l15_primary_report_failure_retention": {
                "schema_version": "sporespore_qsdk_r10f_l15_primary_report_failure_retention_v1",
                "ledger_scope": closer.ledger_scope(
                    "development_primary_report_failure_retention"
                ),
                "primary_file_exists": True,
                "primary_file_binding": primary_binding,
                "primary_file_binding_failure": "",
                "primary_written_binding": primary_binding,
                "primary_write_completed": True,
                "primary_marker_published": True,
                "primary_report_replaced": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
        }
        terminal_path = terminal_root / "terminal_supervisor_failure.json"
        fixture_json(terminal_path, failure)
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"), mock.patch.object(
            closer, "EVIDENCE_ROOT", self.directory
        ), mock.patch.object(
            closer,
            "validate_l9_authority_files",
            return_value={"authority": {"source_only_authority_graph_fixture": True}},
        ):
            normalized, outcome = closer.validate_l9_terminal_supervisor_failure(
                failure,
                report_path=terminal_path,
                expected_l15_collection_identity=self.identity,
                expected_l15_context_binding=self.expected_context_binding,
            )
        self.assertEqual(2, normalized["ordered_child_count"])
        self.assertEqual("none", outcome["scientific_outcome"])
        self.assertIs(outcome["route_execution_valid"], False)
        self.assertIs(
            outcome["collection_failure_retention_by_arm"][closer.ACTIVE_ARM][
                "collection_failure_retention_valid"
            ],
            True,
        )
        self.assertIs(
            outcome["l15_primary_report_failure_retention"][
                "original_written_bytes_still_present"
            ],
            True,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
