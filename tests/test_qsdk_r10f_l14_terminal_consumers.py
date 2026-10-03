from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_terminal_consumers as consumer
import qsdk_r10f_physical_closure as canonical


class L14TerminalConsumerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(
            r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r10f-development-route-ghost-30427ba7f22cd306\children\01-matched_no_kick_continuation\worker_report.json"
        )
        raw = path.read_bytes()
        assert (
            hashlib.sha256(raw).hexdigest()
            == "1038e6df65338b15de7a83b10456633f6ccf9b8778942f3135ae1f2ff52a7aa6"
        )
        cls.report = json.loads(raw)

    def predicates(self, terminal):
        return consumer.terminal_content_predicates(
            terminal,
            native_step_matches=canonical.integer_valued_native_step_matches,
            canonical_sha256=canonical.canonical_sha256_v1,
            payload_sha256=canonical.payload_sha256_v1,
        )

    def rehash(self, terminal):
        for name in (
            "recovery_memory",
            "recovery_step_receipt",
            "recovery_classification",
        ):
            terminal[name + "_sha256"] = canonical.canonical_sha256_v1(terminal[name])
        terminal["payload_sha256"] = canonical.payload_sha256_v1(terminal)

    def full_terminal(self, terminal):
        return canonical.validate_l9_terminal_receipt(
            terminal,
            parent_attempt_id=self.report["parent_attempt_id"],
            child_attempt_id=self.report["child_attempt_id"],
            role=self.report["arm_id"],
            model_instance_id=self.report["arm_result"]["model_instance_id"],
            maximum_step=3842,
        )

    def project_start(self, session, interaction):
        return consumer.interaction_start_projection(
            session,
            interaction,
            model_instance_id=self.report["arm_result"]["model_instance_id"],
            canonical_sha256=canonical.canonical_sha256_v1,
        )

    def test_retained_terminal_preserves_value_type_and_all_hashes(self):
        terminal = self.report["precondition_terminal_receipt"]
        before = copy.deepcopy(terminal)
        self.assertTrue(all(self.predicates(terminal).values()))
        self.assertIs(type(terminal["recovery_memory"]["last_semantic_step"]), float)
        self.assertEqual(terminal, before)

    def test_duplicated_sources_preserve_nested_number_kinds(self):
        self.assertFalse(
            consumer.same_source_value({"nested": [True]}, {"nested": [1]})
        )
        self.assertFalse(consumer.same_source_value({"nested": [1.0]}, {"nested": [1]}))
        self.assertTrue(
            consumer.same_source_value({"nested": [1.0]}, {"nested": [1.0]})
        )

    def test_integral_source_boundaries_and_terminal_phases(self):
        for phase in ("complete", "failed", "refused"):
            for step in (1, 240, 3842):
                for source in (step, float(step)):
                    with self.subTest(phase=phase, step=step, source_kind=type(source)):
                        terminal = copy.deepcopy(
                            self.report["precondition_terminal_receipt"]
                        )
                        terminal["completed_global_semantic_step"] = step
                        terminal["recovery_memory"]["last_semantic_step"] = source
                        terminal["recovery_memory"]["phase"] = phase
                        terminal["recovery_memory"]["terminal_failure_code"] = (
                            None
                            if phase == "complete"
                            else "synthetic_terminal_failure"
                        )
                        terminal["recovery_terminal_failure_code"] = (
                            "" if phase == "complete" else "synthetic_terminal_failure"
                        )
                        terminal["disposition"] = phase + "_source_retained"
                        terminal["stable_four_foot_stance"] = phase == "complete"
                        terminal["recovery_step_receipt"]["memory"] = copy.deepcopy(
                            terminal["recovery_memory"]
                        )
                        terminal["recovery_step_receipt"]["next_phase"] = phase
                        terminal["recovery_terminal_phase"] = phase
                        self.rehash(terminal)
                        self.assertTrue(all(self.predicates(terminal).values()))
                        actual = self.full_terminal(terminal)
                        self.assertEqual(actual["completed_global_semantic_step"], step)
                        self.assertEqual(
                            actual["disposition"], phase + "_source_retained"
                        )

    def test_bad_native_step_kinds_and_values_are_rejected_without_rewriting(self):
        for source in (
            True,
            False,
            None,
            "240",
            240.5,
            0,
            -1,
            3843,
            float("nan"),
            float("inf"),
            -float("inf"),
        ):
            with self.subTest(source=source):
                terminal = copy.deepcopy(self.report["precondition_terminal_receipt"])
                terminal["recovery_memory"]["last_semantic_step"] = source
                terminal["recovery_step_receipt"]["memory"][
                    "last_semantic_step"
                ] = source
                self.assertFalse(
                    self.predicates(terminal)["memory_step_exact_native_source"]
                )
                with self.assertRaises(canonical.ClosureFailure):
                    self.full_terminal(terminal)

    def test_cross_kind_source_copy_and_host_float_are_rejected(self):
        terminal = copy.deepcopy(self.report["precondition_terminal_receipt"])
        terminal["recovery_step_receipt"]["memory"]["last_semantic_step"] = 240
        self.rehash(terminal)
        predicates = self.predicates(terminal)
        self.assertFalse(predicates["memory_step_exact_native_source"])
        self.assertFalse(predicates["memory_step_number_kind_equal"])
        terminal = copy.deepcopy(self.report["precondition_terminal_receipt"])
        terminal["completed_global_semantic_step"] = 240.0
        self.rehash(terminal)
        self.assertFalse(self.predicates(terminal)["memory_step_exact_native_source"])

    def test_each_terminal_hash_and_memory_link_is_required(self):
        for key in (
            "recovery_memory_sha256",
            "recovery_step_receipt_sha256",
            "recovery_classification_sha256",
            "payload_sha256",
        ):
            with self.subTest(key=key):
                terminal = copy.deepcopy(self.report["precondition_terminal_receipt"])
                terminal[key] = "sha256:" + "0" * 64
                self.assertFalse(all(self.predicates(terminal).values()))
                with self.assertRaises(canonical.ClosureFailure):
                    self.full_terminal(terminal)
        terminal = copy.deepcopy(self.report["precondition_terminal_receipt"])
        terminal["recovery_step_receipt"]["memory"]["phase"] = "failed"
        self.rehash(terminal)
        self.assertFalse(self.predicates(terminal)["step_memory_equal"])

    def test_exact_production_start_selected_without_changing_it(self):
        session = self.report["arm_result"]["walking_sessions"][0]
        interaction = self.report["interaction_source"]
        before = copy.deepcopy(session)
        result = self.project_start(session, interaction)
        self.assertTrue(result["ok"], result)
        self.assertIs(result["start_receipt"], session["start_receipt"])
        self.assertEqual(before, session)

    def test_wrapper_digest_is_not_an_alternative_start_source(self):
        session = self.report["arm_result"]["walking_sessions"][0]
        interaction = copy.deepcopy(self.report["interaction_source"])
        interaction["prefix_session_receipt_sha256"] = canonical.canonical_sha256_v1(
            session
        )
        result = self.project_start(session, interaction)
        self.assertFalse(result["ok"])
        self.assertIn("start_source_digest", result["failed_predicates"])

    def test_malformed_missing_swapped_or_foreign_start_is_rejected(self):
        base = self.report["arm_result"]["walking_sessions"][0]
        interaction = self.report["interaction_source"]
        for name in (
            "missing",
            "array",
            "swapped",
            "wrong_model",
            "wrong_session",
            "wrong_forward",
            "wrong_lateral",
            "authority",
            "counter_bool",
            "extra_wrapper",
        ):
            with self.subTest(name=name):
                session = copy.deepcopy(base)
                if name == "missing":
                    del session["start_receipt"]
                elif name == "array":
                    session["start_receipt"] = []
                elif name == "swapped":
                    session["start_receipt"] = copy.deepcopy(
                        self.report["arm_result"]["walking_sessions"][1][
                            "start_receipt"
                        ]
                    )
                elif name == "wrong_model":
                    session["start_receipt"]["model_instance_id"] = "foreign"
                elif name == "wrong_session":
                    session["session_id"] = "foreign"
                elif name == "wrong_forward":
                    session["start_receipt"][
                        "task_frame_forward_axis_world_host_real"
                    ] = [1.0, 0.0, 0.0]
                elif name == "wrong_lateral":
                    session["start_receipt"][
                        "task_frame_lateral_axis_world_host_real"
                    ] = [0.0, 0.0, 1.0]
                elif name == "authority":
                    session["start_receipt"]["release_authority"] = True
                elif name == "counter_bool":
                    session["start_receipt"]["world_build_count"] = False
                else:
                    session["schema_version"] = "synthetic-wrapper-not-producer-shaped"
                self.assertFalse(self.project_start(session, interaction)["ok"])

    def test_whole_retained_child_sources_cross_the_repaired_boundaries_only(self):
        # Select the historical identity labels only within this diagnostic
        # test scope. The actual current consumer functions run on unchanged
        # L13 sources; this is not a new physical identity or replacement result.
        report = copy.deepcopy(self.report)
        with mock.patch.multiple(
            canonical, REPAIR_ID=report["repair_id"], WORK_ID=report["work_id"]
        ):
            projection = canonical.validate_l9_child_report(
                report,
                expected_role=report["arm_id"],
                expected_parent_attempt_id=report["parent_attempt_id"],
                expected_child_attempt_id=report["child_attempt_id"],
                expected_source_commit=report["source_commit"],
                expected_authority_sha256=report["authorization_sha256"],
                expected_worker_process_id=report["process_id"],
            )
        self.assertEqual(projection["solver_step_count"], 2882)
        self.assertEqual(projection["walking"]["session_count"], 2)
        self.assertFalse(projection["physical_acceptance_authority"])
        descriptor = {
            "role": report["arm_id"],
            "child_attempt_id": report["child_attempt_id"],
            "termination_nonce": "f" * 32,
            "evidence_path": "C:/synthetic/l14-health-refusal",
        }
        envelope = {
            **descriptor,
            "child_retry_count": 0,
            "child_replacement_count": 0,
            "process_id": report["process_id"],
            "worker_process_id": report["process_id"],
            "exit_code": 0,
            "termination_protocol_valid": True,
            "engine_health_passed": False,
            "raw_marker_valid": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "started_utc": "2026-01-01T00:00:00+00:00",
            "completed_utc": "2026-01-01T00:00:01+00:00",
            "report": report,
        }
        with mock.patch.multiple(
            canonical, REPAIR_ID=report["repair_id"], WORK_ID=report["work_id"]
        ):
            outcome = canonical.validate_l9_child_envelope(
                envelope,
                descriptor,
                parent_attempt_id=report["parent_attempt_id"],
                source_commit=report["source_commit"],
                authority_sha256=report["authorization_sha256"],
                verify_files=False,
            )
        self.assertFalse(outcome["child_valid"])
        self.assertEqual(
            outcome["child_validation_error"],
            "L9_" + report["arm_id"] + "_VALID_CHILD_LAUNCH",
        )
        self.assertEqual(report, self.report)


if __name__ == "__main__":
    unittest.main()
