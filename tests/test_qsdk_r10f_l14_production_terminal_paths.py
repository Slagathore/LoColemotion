"""Actual GDScript worker-source outputs cross the independent Python consumer.

All purported world/step data below is a labeled synthetic fixture. The only
native object instantiated is the SDK's pure canonical-JSON service, not a
model or physics world. No historical result is changed or promoted.
"""

from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_physical_closure as closer
import qsdk_r10f_l14_walking_failure_retention as retention

DEFAULT_GODOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r24d157-godot-jolt-rotation-integration-energy-v6\development-cold-build-ed4ec00a\godot.windows.editor.dev.x86_64.console.exe"
)
MARKER = "QSDK_R10F_L14_WORKER_TERMINAL_ZERO_WORLD "


class ProductionTerminalPaths(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        started = time.perf_counter()
        executable = Path(
            os.environ.get("SPORESPORE_L14_GODOT_EXECUTABLE", DEFAULT_GODOT)
        )
        run = subprocess.run(
            [
                str(executable),
                "--headless",
                "--path",
                str(ROOT),
                "--script",
                "res://tests/test_sdk_qsdk_r10f_l14_worker_terminal_zero_world.gd",
                "--",
                "--emit-fixtures",
            ],
            cwd=ROOT,
            text=True,
            encoding="utf-8",
            capture_output=True,
            timeout=300,
        )
        if (
            run.returncode
            or "SCRIPT ERROR:" in run.stdout + run.stderr
            or "ERROR:" in run.stdout + run.stderr
        ):
            raise AssertionError(
                "GDSCRIPT_PRODUCTION_SOURCE_TEST_FAILED:"
                + (run.stderr + run.stdout[:2000])
            )
        receipts = [
            line[len(MARKER) :]
            for line in run.stdout.splitlines()
            if line.startswith(MARKER)
        ]
        assert len(receipts) == 1, "EXACTLY_ONE_PRODUCTION_SOURCE_RECEIPT_REQUIRED"
        cls.receipt = json.loads(receipts[0])
        assert cls.receipt["ok"] is True, cls.receipt["failed_controls"]
        assert cls.receipt["control_count"] == 14
        cls.fixtures = {
            value["name"]: value["partial_arm"]
            for value in cls.receipt["production_failure_fixtures"]
        }
        assert len(cls.fixtures) == 7
        print(
            "L14_GDSCRIPT_PRODUCTION_SOURCE_PASS controls=14 invalid_sources=7 zero_world=true elapsed_s="
            + str(round(time.perf_counter() - started, 3)),
            flush=True,
        )

    def check(self, partial):
        return retention.validate_failure_retention(
            partial,
            role=partial.get("arm_id", closer.ACTIVE_ARM),
            canonical_sha256=closer.canonical_sha256_v1,
            payload_sha256=closer.payload_sha256_v1,
        )

    def report(self, partial):
        role = partial["arm_id"]
        identity = {
            "expected_role": role,
            "expected_parent_attempt_id": "1" * 32,
            "expected_child_attempt_id": "2" * 32,
            "expected_source_commit": "3" * 40,
            "expected_authority_sha256": "sha256:" + "4" * 64,
            "expected_worker_process_id": 1234,
        }
        report = closer.l13_synthetic_partial_walking_failure_report(
            role=role,
            parent_attempt_id=identity["expected_parent_attempt_id"],
            child_attempt_id=identity["expected_child_attempt_id"],
            source_commit=identity["expected_source_commit"],
            authority_sha256=identity["expected_authority_sha256"],
            process_id=identity["expected_worker_process_id"],
        )
        report.update(
            {
                "failure_code": "QSDK_R10F_L9_CHILD_WALKING_CLOSE_INVALID",
                "partial_arm": copy.deepcopy(partial),
                "solver_step_count": len(partial["trace_rows"]),
                "global_solver_frame_count": len(partial["trace_rows"]),
                "world_build_count": 1,
            }
        )
        return report, identity

    def test_all_actual_worker_failure_sources_pass_independent_retention_only(self):
        for name, partial in self.fixtures.items():
            with self.subTest(name=name):
                result = self.check(partial)
                self.assertTrue(
                    result["walking_evaluation_failure_retention_valid"], result
                )
                self.assertFalse(result["route_execution_valid"])
                report, identity = self.report(partial)
                actual = closer.validate_l14_partial_walking_evaluation_failure_report(
                    report, **identity
                )
                self.assertTrue(actual["walking_evaluation_failure_retention_valid"])
                self.assertFalse(actual["behavior_passed"])
                self.assertFalse(actual["release_authority"])

    def test_every_failure_source_field_is_required(self):
        base = self.fixtures["malformed_observed_vector"]
        for key in retention.KEYS:
            with self.subTest(key=key):
                mutated = copy.deepcopy(base)
                del mutated["last_walking_evaluation_failure"][key]
                self.assertFalse(
                    self.check(mutated)["walking_evaluation_failure_retention_valid"]
                )

    def test_tampering_is_refused_even_with_rehashed_internal_receipt(self):
        base = self.fixtures["malformed_observed_vector"]
        cases = {}
        value = copy.deepcopy(base)
        value["last_walking_evaluation_failure"]["all_observed_trace_rows"].pop()
        cases["omitted_original_row"] = value
        value = copy.deepcopy(base)
        value["last_walking_evaluation_failure"]["active_walking_session"][
            "session_id"
        ] = "different-session"
        cases["swapped_original_session"] = value
        value = copy.deepcopy(base)
        value["last_walking_evaluation_failure"]["walking_evaluation_input"][
            "expected_step_count"
        ] = 720.0
        cases["rewritten_source_number_kind"] = value
        value = copy.deepcopy(base)
        value["last_walking_evaluation_failure"]["walking_evaluation_input"][
            "rows"
        ].pop()
        cases["incomplete_evaluator_input"] = value
        value = copy.deepcopy(base)
        value["last_walking_evaluation_failure"]["evaluation"]["ok"] = True
        cases["invalid_evaluation_promoted"] = value
        for field in (
            "ok",
            "measurement_complete",
            "physical_acceptance_authority",
            "release_authority",
        ):
            value = copy.deepcopy(base)
            value["last_walking_evaluation_failure"][field] = True
            cases["promoted_" + field] = value
        for field, replacement in (
            ("failure_code", "generic_failure"),
            ("evaluator_failure_code", ""),
            ("trace_slice_valid", False),
            ("walking_session_completion_attempted", False),
        ):
            value = copy.deepcopy(base)
            value["last_walking_evaluation_failure"][field] = replacement
            cases["altered_" + field] = value
        for name, value in cases.items():
            with self.subTest(name=name):
                failure = value["last_walking_evaluation_failure"]
                failure["payload_sha256"] = closer.payload_sha256_v1(failure)
                self.assertFalse(
                    self.check(value)["walking_evaluation_failure_retention_valid"]
                )

    def test_original_digest_and_enclosing_partial_population_remain_required(self):
        base = self.fixtures["malformed_observed_vector"]
        value = copy.deepcopy(base)
        value["last_walking_evaluation_failure"]["payload_sha256"] = (
            "sha256:" + "0" * 64
        )
        self.assertFalse(
            self.check(value)["walking_evaluation_failure_retention_valid"]
        )
        for field in (
            "trace_rows",
            "active_walking_session",
            "walking_session_completion_attempted",
            "direct_torso_force_command_count",
        ):
            with self.subTest(field=field):
                value = copy.deepcopy(base)
                value.pop(field)
                self.assertFalse(
                    self.check(value)["walking_evaluation_failure_retention_valid"]
                )
        report, identity = self.report(base)
        report["solver_step_count"] -= 1
        with self.assertRaises(closer.ClosureFailure):
            closer.validate_l14_partial_walking_evaluation_failure_report(
                report, **identity
            )

    def test_complete_worker_sessions_preserve_positive_and_negative(self):
        positive, negative = self.receipt["production_complete_sessions"]
        for session, expected in ((positive, True), (negative, False)):
            with self.subTest(expected=expected):
                projection = closer.validate_l9_walking_sessions(
                    [session], session["evaluation"]["arm_id"]
                )
                self.assertIs(
                    projection["behavior_by_segment"]["walking_prefix"], expected
                )
                self.assertEqual(
                    session["evaluation"]["schema_version"],
                    "sporespore_qsdk_r10f_walking_segment_evaluation_v2",
                )
                self.assertEqual(session["evaluation"]["walking_receipt_count"], 27)
                payload = copy.deepcopy(session["evaluation"])
                payload["payload_sha256"] = ""
                self.assertEqual(
                    session["evaluation"]["payload_sha256"],
                    closer.canonical_sha256_v1(payload),
                )

    def test_actual_native_interaction_producers_cross_whole_child_consumer(self):
        for produced in self.receipt["production_interaction_fixtures"]["fixtures"]:
            with self.subTest(role=produced["role"]):
                supervisor = closer.l9_synthetic_supervisor("behavior_positive")
                index = closer.ARM_ORDER.index(produced["role"])
                report = supervisor["child_envelopes"][index]["report"]
                session = report["arm_result"]["walking_sessions"][0]
                session["start_receipt"] = copy.deepcopy(
                    produced["prefix_session"]["start_receipt"]
                )
                interaction = copy.deepcopy(produced["interaction_build"]["source"])
                report["interaction_source"] = interaction
                report["interaction_source_sha256"] = interaction["payload_sha256"]
                report["arm_result"]["interaction_source"] = copy.deepcopy(interaction)
                identity = {
                    "expected_role": report["arm_id"],
                    "expected_parent_attempt_id": report["parent_attempt_id"],
                    "expected_child_attempt_id": report["child_attempt_id"],
                    "expected_source_commit": report["source_commit"],
                    "expected_authority_sha256": report["authorization_sha256"],
                    "expected_worker_process_id": report["process_id"],
                }
                actual = closer.validate_l9_child_report(report, **identity)
                self.assertEqual(actual["interaction"]["application_count"], index)
                for corrupted in (
                    "wrapper_digest",
                    "missing_start",
                    "foreign_start",
                    "wrong_axes",
                    "payload",
                ):
                    modified = copy.deepcopy(report)
                    prefix = modified["arm_result"]["walking_sessions"][0]
                    source = modified["interaction_source"]
                    if corrupted == "wrapper_digest":
                        source["prefix_session_receipt_sha256"] = (
                            closer.canonical_sha256_v1(prefix)
                        )
                        source["payload_sha256"] = closer.payload_sha256_v1(source)
                        modified["interaction_source_sha256"] = source["payload_sha256"]
                        modified["arm_result"]["interaction_source"] = copy.deepcopy(
                            source
                        )
                    elif corrupted == "missing_start":
                        prefix.pop("start_receipt")
                    elif corrupted == "foreign_start":
                        prefix["start_receipt"]["model_instance_id"] = "foreign-model"
                    elif corrupted == "wrong_axes":
                        prefix["start_receipt"][
                            "task_frame_forward_axis_world_host_real"
                        ] = [0.0, 1.0, 0.0]
                    else:
                        source["payload_sha256"] = "sha256:" + "0" * 64
                    with self.subTest(corrupted=corrupted), self.assertRaises(
                        closer.ClosureFailure
                    ):
                        closer.validate_l9_child_report(modified, **identity)


if __name__ == "__main__":
    unittest.main(verbosity=2)
