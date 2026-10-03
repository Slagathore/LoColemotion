"""Actual opt-in worker stage and partial abort projection, without physics."""

import hashlib
import json
from pathlib import Path
import unittest

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture, verify_bytes
from test_qsdk_r10f_worker_source import function

ROOT = Path(__file__).resolve().parents[1]
ABORT_MARKER = "QSDK_R10F_L15_SYNTHETIC_ABORT_RAW "


class WorkerRetention(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_worker_retention_zero_world.gd",
            "QSDK_R10F_L15_WORKER_RETENTION_ZERO_WORLD ",
            additional_markers=(ABORT_MARKER,),
        )

    def test_actual_stage_and_abort_projection_keep_original_bytes(self):
        receipt = self.receipt
        self.assertEqual(54, receipt["control_count"])
        self.assertEqual([], receipt["failed_controls"])
        self.assertTrue(all(value is True for value in receipt["controls"].values()))
        self.assertEqual(2, receipt["genuine_compiled_collection_call_count"])
        self.assertEqual(1, receipt["compiled_portable_step_call_count"])
        self.assertEqual(1, receipt["compiled_control_planning_call_count"])
        self.assertEqual(1, receipt["malformed_response_stub_call_count"])
        for label, case in receipt["cases"].items():
            partial = case["partial_arm"]
            packet = partial["last_recovery_collection_transport_retention"]
            self.assertEqual(case["original_trace_rows"], partial["trace_rows"])
            self.assertEqual(
                509, partial["last_recovery_collection_transport_global_semantic_step"]
            )
            self.assertEqual(packet, case["advance"]["collection_transport_retention"])
            for binding in packet["source_links"].values():
                verify_bytes(binding)
            if label in ("success", "native_schema_refusal"):
                verify_bytes(packet["request"])
                response = json.loads(verify_bytes(packet["response"]))
                self.assertIs(response["ok"], label == "success")
            elif label == "malformed_reply":
                verify_bytes(packet["request"])
                self.assertEqual(
                    b"{deliberately_malformed_transport_reply",
                    verify_bytes(packet["response"]),
                )
                self.assertEqual("compiled_response_malformed", packet["stage"])
                self.assertEqual(1, packet["compiled_collection_call_count"])
            else:
                self.assertIsNone(packet["request"])
                self.assertIsNone(packet["response"])
                self.assertEqual(0, packet["compiled_collection_call_count"])
            if label != "success":
                self.assertIs(case["stage_ok"], False)
                self.assertEqual(
                    case["advance"], partial["last_recovery_advance_failure"]
                )

    def test_actual_worker_wiring_retains_before_failure_and_cleanup(self):
        source = (
            ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
        ).read_text(encoding="utf-8")
        self.assertIn('const REPAIR_ID := "QSDK-R10F-L14"', source)
        process = function(source, "_process_completed_arm_step_v1")
        opt_in = process.index('if _repair_id == "QSDK-R10F-L15":')
        call = process.index("RecoveryAdvanceStageL15.advance_v1(", opt_in)
        retain = process.index("_arms[arm_id] = arm", call)
        validation = process.index("production_advance_receipt_valid_v1(", retain)
        failure = process.index(
            '"QSDK_R10F_RECOVERY_PRODUCTION_ADVANCE_INVALID"', validation
        )
        self.assertLess(call, retain)
        self.assertLess(retain, validation)
        self.assertLess(validation, failure)
        abort = function(source, "_abort_process_isolated_child_v1")
        self.assertLess(
            abort.index("partial_arm_failure_retention_projection_l15_v1("),
            abort.index("_cleanup_worlds_v1()"),
        )
        self.assertIn('"partial_arm": partial_arm', abort)
        self.assertIn('"detail": _json_safe_v1(detail)', abort)

    def test_no_physics_or_complete_abort_claim(self):
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_physics_read_count",
            "solver_step_count",
            "additional_failure_reconstruction_call_count",
        ):
            self.assertEqual(0, self.receipt[key], key)
        for key in (
            "complete_worker_abort_envelope_qualified",
            "physical_worker_instance_created",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(self.receipt[key], False, key)

    def test_complete_actual_abort_report_publication_keeps_bytes_after_cleanup(self):
        emitted = self.receipt["captured_additional_marker_texts"][ABORT_MARKER]
        self.assertEqual(1, len(emitted))
        report = json.loads(emitted[0])
        self.assertIs(report["ok"], False)
        self.assertEqual("QSDK-R10F-L15", report["repair_id"])
        # Early failures can precede context preparation. Absence must remain
        # explicit null without Godot logging an error while publishing it.
        self.assertIsNone(report["l15_prepared_context_comparison"])
        self.assertEqual(
            "QSDK_R10F_L9_CHILD_STEP_PROCESSING_INVALID", report["failure_code"]
        )
        original = self.receipt["cases"]["native_schema_refusal"]
        self.assertEqual(original["advance"], report["detail"]["advance"])
        self.assertEqual(original["partial_arm"], report["partial_arm"])
        packet = report["partial_arm"]["last_recovery_collection_transport_retention"]
        verify_bytes(packet["request"])
        response = json.loads(verify_bytes(packet["response"]))
        self.assertEqual("SCHEMA_INVALID", response["failure_code"])
        # Model counters exceed aggregate counters in this labeled fixture;
        # the actual abort's max projection must keep the completed work.
        self.assertEqual(509, report["solver_step_count"])
        self.assertEqual(1, report["world_attempt_count"])
        self.assertEqual(1, report["model_construction_attempt_count"])
        self.assertEqual(17, report["explicit_worker_extra_native_readback_count"])
        control = self.receipt["abort_control_flow"]
        source = (
            ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
        ).read_bytes()
        self.assertEqual(
            "sha256:" + hashlib.sha256(source).hexdigest(),
            control["worker_source_raw_sha256"],
        )
        self.assertIs(control["actual_abort_and_publication_methods_executed"], True)
        self.assertIs(control["report_counters_are_synthetic_fixture_inputs"], True)
        self.assertEqual(0, control["remaining_arm_count"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
