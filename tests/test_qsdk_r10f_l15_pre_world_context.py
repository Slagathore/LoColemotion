"""Actual worker's pre-world method and exact abort metadata, without a world.

The expected capture is a separate preparation with explicit test authority.
Neither the launch environment nor a self-signed receipt authenticates its origin.
"""

from pathlib import Path
import sys
import unittest

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_collection_context as context
import qsdk_r10f_physical_closure as closer

ABORT_MARKER = "QSDK_R10F_L15_CONTEXT_METADATA_ABORT_RAW "


class PreWorldContext(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_pre_world_context_zero_world.gd",
            "QSDK_R10F_L15_PRE_WORLD_CONTEXT_ZERO_WORLD ",
            additional_markers=(ABORT_MARKER,),
        )
        cls.positive = cls.receipt["positive_comparison"]
        cls.expected = cls.receipt["expected_capture"]

    def test_actual_worker_method_keeps_zero_world_and_origin_boundaries(self):
        self.assertEqual(21, self.receipt["control_count"])
        self.assertEqual([], self.receipt["failed_controls"])
        self.assertTrue(
            all(value is True for value in self.receipt["controls"].values())
        )
        self.assertIs(
            self.receipt["actual_worker_method_executed_in_detached_refcounted_host"],
            True,
        )
        self.assertIs(self.receipt["complete_physical_worker_run_executed"], False)
        self.assertIs(
            self.receipt["official_supervisor_qualification_origin_used_in_fixture"],
            False,
        )
        self.assertIs(self.receipt["expected_binding_has_test_authority_only"], True)
        self.assertEqual(
            2, self.receipt["production_v18_context_preparation_call_count"]
        )
        for value in (self.receipt, self.positive):
            for field in context.ZERO_COUNTERS:
                self.assertIs(type(value[field]), int)
                self.assertEqual(0, value[field])
            for flag in (
                "physics_state_modified",
                "physical_execution_authorized",
                "physical_acceptance_authority",
                "release_authority",
            ):
                self.assertIs(value[flag], False)
        for flag in (
            "expected_binding_origin_authenticated_here",
            "official_context_qualification",
            "observation_or_failed_packet_used_as_expected_context",
        ):
            self.assertIs(self.positive[flag], False)

    def test_two_separate_preparations_match_original_byte_identity(self):
        self.assertTrue(
            context.packet.same(self.expected, self.positive["observed_capture"])
        )
        self.assertIs(self.positive["ok"], True)
        self.assertIs(self.positive["expected_capture_binding_matched"], True)
        self.assertIsNone(self.positive["failure_code"])
        self.assertEqual(1, self.positive["context_capture_call_count"])
        raw = context.packet.verify_bytes(self.positive["observed_capture"]).decode(
            "utf-8"
        )
        proof = context.validate_capture(
            raw,
            expected_raw_binding=self.positive["expected_capture_binding"],
            canonical_sha256=closer.canonical_sha256_v1,
        )
        self.assertIs(proof["ok"], True)
        self.assertIs(proof["official_context_qualification"], False)

    def test_actual_refusals_distinguish_missing_binding_from_mismatched_capture(self):
        for label, refusal in self.receipt["refusals"].items():
            self.assertIs(refusal["ok"], False, label)
            self.assertIs(refusal["expected_capture_binding_matched"], False, label)
            if label.startswith("crossed_"):
                self.assertEqual(
                    "L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH", refusal["failure_code"]
                )
                self.assertEqual(1, refusal["context_capture_call_count"])
                self.assertTrue(
                    context.packet.same(refusal["observed_capture"], self.expected)
                )
                raw = context.packet.verify_bytes(refusal["observed_capture"]).decode(
                    "utf-8"
                )
                with self.assertRaisesRegex(ValueError, "ENCLOSING_RAW_BINDING"):
                    context.validate_capture(
                        raw,
                        expected_raw_binding=refusal["expected_capture_binding"],
                        canonical_sha256=closer.canonical_sha256_v1,
                    )
            else:
                self.assertEqual(
                    "L15_PRE_WORLD_EXPECTED_BINDING_INVALID", refusal["failure_code"]
                )
                self.assertEqual(0, refusal["context_capture_call_count"])
                self.assertIsNone(refusal["observed_capture"])

    def test_actual_abort_retains_the_unmodified_comparison_before_cleanup(self):
        originals = self.receipt["captured_additional_marker_texts"][ABORT_MARKER]
        self.assertEqual(1, len(originals))
        report = context.packet.parse_json(originals[0])
        self.assertTrue(
            context.packet.same(
                report["l15_prepared_context_comparison"], self.positive
            )
        )
        self.assertIs(report["ok"], False)
        self.assertEqual("none", report["scientific_outcome"])
        self.assertIs(self.receipt["abort_report_counters_are_synthetic_inputs"], True)
        retained = self.receipt["abort_metadata_retention"]
        self.assertIs(retained["actual_abort_and_publication_methods_executed"], True)
        self.assertTrue(retained["seam_events"][0:2] == ["quiesce", "cleanup"])
        self.assertEqual(0, retained["remaining_arm_count"])

    def test_worker_calls_guard_before_model_and_retains_both_terminal_paths(self):
        source = (
            ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
        ).read_text()

        def method(name):
            tail = source.split("\nfunc " + name + "(", 1)[1]
            return tail.split("\nfunc ", 1)[0].split("\nstatic func ", 1)[0]

        run = method("_run")
        self.assertLess(
            run.index("prepare_complete_energy_context_v18"),
            run.index("_verify_l15_prepared_context_before_world_v1()"),
        )
        self.assertLess(
            run.index("_verify_l15_prepared_context_before_world_v1()"),
            run.index("await _build_arm_v1"),
        )
        for name in (
            "_finalize_process_isolated_child_result_v1",
            "_abort_process_isolated_child_v1",
        ):
            body = method(name)
            self.assertIn('if _repair_id == "QSDK-R10F-L15":', body)
            self.assertLess(
                body.index('report["l15_prepared_context_comparison"]'),
                body.index("_cleanup_worlds_v1()"),
            )
        self.assertIn('const REPAIR_ID := "QSDK-R10F-L14"', source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
