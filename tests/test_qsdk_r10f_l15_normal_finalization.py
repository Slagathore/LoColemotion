"""Actual normal finalizer with synthetic input, without a physical worker.

The complete source methods execute unchanged in a detached host. Identity
handles are ordinary Nodes, not bodies. Expected context origin is test-only.
The report reader checks a complete precondition diagnostic, not an R10F pass.
"""

import copy
from pathlib import Path
import sys
import unittest

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_collection_context as context
import qsdk_r10f_physical_closure as closer

RAW_MARKER = "QSDK_R10F_L15_NORMAL_FINALIZATION_RAW "
ABSENT_MARKER = "QSDK_R10F_L15_NORMAL_FINALIZATION_ABSENT_METADATA_RAW "


class NormalFinalization(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_normal_finalization_zero_world.gd",
            "QSDK_R10F_L15_NORMAL_FINALIZATION_ZERO_WORLD ",
            additional_markers=(RAW_MARKER, ABSENT_MARKER),
        )
        emitted = cls.receipt["captured_additional_marker_texts"]
        assert len(emitted[RAW_MARKER]) == 1, "ONE_NORMAL_REPORT_REQUIRED"
        assert len(emitted[ABSENT_MARKER]) == 1, "ONE_ABSENT_METADATA_REPORT_REQUIRED"
        cls.raw = emitted[RAW_MARKER][0]
        cls.report = context.packet.parse_json(cls.raw)
        cls.absent = context.packet.parse_json(emitted[ABSENT_MARKER][0])

    def read_child(self, report):
        return closer.validate_l9_child_report(
            report,
            expected_role=closer.ACTIVE_ARM,
            expected_parent_attempt_id="0123456789abcdef0123456789abcdef",
            expected_child_attempt_id="2" * 32,
            expected_source_commit="0123456789abcdef0123456789abcdef01234567",
            expected_authority_sha256="sha256:" + "9" * 64,
            expected_worker_process_id=self.receipt["fixture_process_id"],
            require_l15_family=True,
        )

    def test_actual_finalizer_is_idempotent_with_explicit_nonphysical_seams(self):
        self.assertEqual(
            [
                "quiesce",
                "cleanup",
                "exit:0:valid_complete_process_isolated_child_development",
            ],
            self.receipt["seam_events"],
        )
        for flag in (
            "actual_normal_finalizer_and_arm_projection_executed",
            "actual_same_body_identity_reader_with_detached_handles",
            "actual_session_close_already_closed_branch_executed",
            "report_counters_and_precondition_outcome_are_synthetic",
            "expected_context_origin_is_test_authority_only",
            "native_quiescence_cleanup_exit_and_abort_dispatch_are_named_test_seams",
            "fixture_scheduler_tick_setting_restored",
        ):
            self.assertIs(self.receipt[flag], True, flag)
        self.assertEqual(17, self.receipt["detached_identity_handle_count"])
        for flag in (
            "open_session_shutdown_exercised_here",
            "complete_physical_worker_executed",
            "physics_state_modified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(self.receipt[flag], False, flag)
        for counter in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertIs(type(self.receipt[counter]), int, counter)
            self.assertEqual(0, self.receipt[counter], counter)

    def test_original_context_survives_actual_normal_serialization(self):
        retained = self.report["l15_prepared_context_comparison"]
        self.assertTrue(
            context.packet.same(retained, self.receipt["original_context_comparison"])
        )
        self.assertIs(retained["ok"], True)
        self.assertIs(retained["expected_capture_binding_matched"], True)
        raw = context.packet.verify_bytes(retained["observed_capture"]).decode("utf-8")
        proof = context.validate_capture(
            raw,
            expected_raw_binding=retained["expected_capture_binding"],
            canonical_sha256=closer.canonical_sha256_v1,
        )
        self.assertIs(proof["ok"], True)
        for flag in (
            "official_context_qualification",
            "source_origin_authenticated_by_this_reader",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(proof[flag], False, flag)

    def test_actual_normal_report_is_a_complete_precondition_diagnostic_only(self):
        # Consume the emitted report directly; do not repair/rebuild its fields.
        projection = self.read_child(self.report)
        self.assertEqual("precondition_negative", projection["role_outcome"])
        self.assertIs(projection["complete_precondition"], False)
        self.assertEqual(1, projection["solver_step_count"])
        self.assertEqual(0, projection["walking"]["session_count"])
        self.assertIs(self.report["measurement_complete"], True)
        self.assertEqual("none", self.report["scientific_outcome"])
        self.assertIs(self.report["recovery_success_observed"], False)
        self.assertIs(self.report["event_triggered_passive_recovery_observed"], False)
        self.assertEqual(0, self.report["behavior_evaluator_invocation_count"])
        # These nonzero source-shaped counters are not the fixture's real counts.
        self.assertEqual(1, self.report["world_build_count"])
        self.assertEqual(0, self.receipt["world_build_count"])

    def test_absent_metadata_is_null_and_counter_disagreement_refuses(self):
        self.assertIsNone(self.absent["l15_prepared_context_comparison"])
        self.assertEqual(
            self.receipt["seam_events"], self.receipt["absent_metadata_seam_events"]
        )
        self.assertIs(
            self.receipt["absent_metadata_case_bypasses_pre_world_guard"], True
        )
        refusal = self.receipt["terminal_counter_refusal"]
        self.assertEqual(
            "QSDK_R10F_L9_CHILD_TERMINAL_POPULATION_INVARIANT_INVALID",
            refusal["failure_code"],
        )
        self.assertEqual(2, refusal["detail"]["solver_step_count"])
        self.assertEqual(1, refusal["detail"]["global_solver_frames"])
        self.assertEqual(
            ["quiesce"], self.receipt["terminal_counter_refusal_seam_events"]
        )

    def test_independent_reader_rejects_damaged_or_promoted_normal_report(self):
        # Refusals are meaningful only after this exact unmodified source passes.
        self.read_child(self.report)
        for field, value in (
            ("repair_id", "QSDK-R10F-L14"),
            ("model_construction_count", True),
            ("solver_step_count", 2),
            ("physics_ticks_per_second", 60),
            ("role_outcome", "behavior_positive"),
            ("recovery_success_observed", True),
            ("scientific_outcome", "behavior_positive"),
            ("release_authority", True),
        ):
            with self.subTest(field=field), self.assertRaises(closer.ClosureFailure):
                damaged = copy.deepcopy(self.report)
                damaged[field] = value
                self.read_child(damaged)
        for field in (
            "terminal_same_body_identity_receipt",
            "initial_application_validation_receipt",
            "trace",
            "in_run_invariant_receipts",
        ):
            with self.subTest(field=field), self.assertRaises(closer.ClosureFailure):
                damaged = copy.deepcopy(self.report)
                damaged["arm_result"].pop(field)
                self.read_child(damaged)

    def test_production_quiescence_order_and_l14_selector_are_unchanged(self):
        source = (
            ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
        ).read_text()

        def method(name):
            tail = source.split("\nfunc " + name + "(", 1)[1]
            return tail.split("\nfunc ", 1)[0].split("\nstatic func ", 1)[0]

        finalizer = method("_finalize_process_isolated_child_result_v1")
        self.assertLess(
            finalizer.index("_quiesce_process_isolated_child_v1()"),
            finalizer.index("_finish_walking_session_v1("),
        )
        self.assertLess(
            finalizer.index('report["l15_prepared_context_comparison"]'),
            finalizer.index("_cleanup_worlds_v1()"),
        )
        self.assertLess(
            finalizer.index("_cleanup_worlds_v1()"),
            finalizer.index("print(_raw_marker"),
        )
        quiescence = method("_quiesce_process_isolated_child_v1")
        self.assertEqual(
            ") -> void:\n\tPhysicsServer3D.set_active(false)\n"
            "\tif physics_frame.is_connected(_on_physics_frame):\n"
            "\t\tphysics_frame.disconnect(_on_physics_frame)",
            quiescence.strip(),
        )
        self.assertIn(
            "_quiesce_process_isolated_child_v1()",
            method("_quiesce_process_isolated_child_before_abort_v1"),
        )
        self.assertIn('const REPAIR_ID := "QSDK-R10F-L14"', source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
