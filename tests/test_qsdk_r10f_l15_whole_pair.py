"""Complete L15-shaped worker data through actual envelope/pair/report writers.

The seven no-resume branches come from the unchanged native orchestrator and
full source-retention fixture. All report model/step values are synthetic input,
not physical observations. Only the owned process executor/lock and unissued
authority graph are test seams; no physical worker or official identity runs.
"""

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
from unittest import mock

import test_qsdk_r10f_l14_no_resume_terminal as no_resume
import test_qsdk_r10f_l15_collection_enclosing_retention as enclosing
import test_qsdk_r10f_l15_launch_consumers as launch_fixtures
from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture

closer = enclosing.closer
packet = enclosing.reader
ROOT = Path(__file__).resolve().parents[1]


class WholePair(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Only the current report family's identity changes in these synthetic
        # templates. The actual seven native branch producers remain unchanged.
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            no_resume.NoResumeTerminal.setUpClass()
        cls.addClassCleanup(no_resume.NoResumeTerminal.doClassCleanups)
        cls.context = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_pre_world_context_zero_world.gd",
            "QSDK_R10F_L15_PRE_WORLD_CONTEXT_ZERO_WORLD ",
        )
        capture = cls.context["expected_capture"]
        import qsdk_r10f_l15_collection_context as context_reader

        proof = context_reader.validate_capture(
            capture["utf8_text"],
            expected_raw_binding=context_reader.raw_binding(capture["utf8_text"]),
            canonical_sha256=closer.canonical_sha256_v1,
        )
        cls.expected_identity = proof["expected_identity"]
        cls.expected_context_binding = proof["raw_capture_binding"]

    @classmethod
    def source(cls, case):
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            report = launch_fixtures.complete_fixture(
                case
                if case in ("behavior_positive", "behavior_negative")
                else "behavior_positive"
            )
        if case in no_resume.NoResumeTerminal.reports:
            report["child_envelopes"][1]["report"] = copy.deepcopy(
                no_resume.NoResumeTerminal.reports[case]
            )
        for envelope in report["child_envelopes"]:
            envelope["report"]["l15_prepared_context_comparison"] = copy.deepcopy(
                cls.context["positive_comparison"]
            )
        return report

    @classmethod
    def publish(cls, source, *, omit_active_child=False):
        return enclosing.EnclosingCollectionRetention.make_enclosing_case.__func__(
            cls,
            supplied_report=source,
            omit_active_child=omit_active_child,
            expected_context_binding=cls.expected_context_binding,
            expected_collection_identity=cls.expected_identity,
        )

    def read(self, case):
        primary = case["primary"]
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            # Every actual child file is independently reopened. The enclosing
            # unissued official graph/location is not claimed by this fixture.
            children = [
                closer.validate_l9_child_envelope(
                    envelope,
                    descriptor,
                    parent_attempt_id=primary["attempt_id"],
                    source_commit=primary["source_commit"],
                    authority_sha256=primary["authority_sha256"],
                    verify_files=True,
                    expected_l15_collection_identity=self.expected_identity,
                    expected_l15_context_binding=self.expected_context_binding,
                )
                for envelope, descriptor in zip(
                    primary["child_envelopes"], primary["ordered_child_manifest"]
                )
            ]
            outcome = closer.validate_l9_report(
                primary,
                report_path=None,
                verify_files=False,
                expected_l15_collection_identity=self.expected_identity,
                expected_l15_context_binding=self.expected_context_binding,
            )
        for child in children:
            self.assertIs(
                child["prepared_context_integrity"]["prepared_context_valid"], True
            )
        self.assertEqual(
            {child["role"] for child in children},
            set(outcome["prepared_context_integrity_by_arm"]),
        )
        return children, outcome

    def assert_publication(self, case, expected_processes=2):
        control = case["control"]
        self.assertEqual(expected_processes, control["process_fixture_call_count"])
        self.assertIs(control["actual_runtime_image_checks_executed"], True)
        self.assertIs(control["source_only_fixture_not_physical_identity"], True)
        self.assertEqual("", control["caught_failure"])
        for key in (
            "model_construction_count",
            "world_build_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertIs(type(control[key]), int)
            self.assertEqual(0, control[key])
        marker = control["physical_marker"]
        emitted = [
            line[len(marker) :]
            for line in case["execution"].stdout.splitlines()
            if line.startswith(marker)
        ]
        self.assertEqual(1, len(emitted))
        self.assertTrue(packet.same(packet.parse_json(emitted[0]), case["primary"]))
        self.assertFalse(
            (case["directory"] / "terminal_supervisor_failure.json").exists()
        )
        for envelope in case["primary"]["child_envelopes"]:
            retained = envelope["report"]["l15_prepared_context_comparison"]
            self.assertTrue(packet.same(retained, self.context["positive_comparison"]))

    def test_complete_resumed_positive_and_negative_survive_actual_publication(self):
        for label in ("behavior_positive", "behavior_negative"):
            with self.subTest(label=label):
                case = self.publish(self.source(label))
                self.assert_publication(case)
                self.assertEqual(0, case["execution"].returncode)
                children, outcome = self.read(case)
                self.assertTrue(all(child["child_valid"] for child in children))
                self.assertIs(outcome["route_execution_valid"], True)
                self.assertEqual(
                    label == "behavior_positive", outcome["behavior_passed"]
                )
                self.assertEqual(1, case["primary"]["evaluator_invocation_count"])

    def test_all_seven_actual_no_resume_branches_survive_complete_callers(self):
        self.assertEqual(7, len(no_resume.NoResumeTerminal.reports))
        for label in no_resume.NoResumeTerminal.reports:
            with self.subTest(label=label):
                case = self.publish(self.source(label))
                self.assert_publication(case)
                self.assertEqual(
                    0, case["execution"].returncode, case["primary"].get("failure_code")
                )
                children, outcome = self.read(case)
                self.assertTrue(all(child["child_valid"] for child in children))
                self.assertIs(outcome["route_execution_valid"], True)
                self.assertIs(outcome["behavior_passed"], False)
                self.assertEqual("negative", outcome["scientific_outcome"])
                self.assertEqual(1, case["primary"]["evaluator_invocation_count"])
                proof = children[1]["child"]["no_resume_terminal"]
                self.assertIs(proof["source_proven_no_resume_negative"], True)
                self.assertIs(proof["recovery_success_observed"], False)
                self.assertEqual(
                    1,
                    children[1]["child"]["walking_actuation_handoffs"]["handoff_count"],
                )

    def test_incomplete_active_is_retained_without_behavior_evaluation(self):
        source = self.source("confirm_failed")
        del source["child_envelopes"][1]["report"]["arm_result"][
            "terminal_recovery_observation_sources"
        ]
        case = self.publish(source)
        self.assert_publication(case)
        self.assertEqual(1, case["execution"].returncode)
        children, outcome = self.read(case)
        self.assertIs(children[0]["child_valid"], True)
        self.assertIs(children[1]["child_valid"], False)
        self.assertIs(outcome["route_execution_valid"], False)
        self.assertEqual("none", outcome["scientific_outcome"])
        self.assertEqual(0, case["primary"]["evaluator_invocation_count"])

    def test_missing_or_unhealthy_peer_cannot_become_a_complete_negative(self):
        for label in ("missing_peer", "unhealthy_active"):
            source = self.source("confirm_failed")
            if label == "missing_peer":
                source["child_envelopes"] = source["child_envelopes"][:1]
            else:
                source["child_envelopes"][1]["engine_health_passed"] = False
            missing = label == "missing_peer"
            case = self.publish(source, omit_active_child=missing)
            self.assert_publication(case, expected_processes=1 if missing else 2)
            self.assertIs(
                case["control"]["active_invocation_omitted_for_missing_peer_test"],
                missing,
            )
            self.assertEqual(1, case["execution"].returncode)
            children, outcome = self.read(case)
            self.assertEqual(1 if missing else 2, len(children))
            if not missing:
                self.assertIs(children[1]["child_valid"], False)
                self.assertIs(
                    case["primary"]["child_envelopes"][1]["engine_health_passed"], False
                )
            self.assertEqual(0, case["primary"]["evaluator_invocation_count"])
            self.assertEqual("none", outcome["scientific_outcome"])
            self.assertIs(outcome["route_execution_valid"], False)

    def bridge_request(self):
        import qsdk_r10f_l15_child_source_bridge as bridge

        report = self.source("confirm_failed")["child_envelopes"][1]["report"]
        return {
            "schema_version": bridge.REQUEST_SCHEMA,
            "report": report,
            "expected_identity": no_resume.identity(report),
        }

    def test_source_selected_bridge_rejects_crossed_families_without_relaxing_proof(
        self,
    ):
        import qsdk_r10f_l15_child_source_bridge as bridge

        request = self.bridge_request()
        original = copy.deepcopy(request)
        positive = bridge.validate_request(request)
        self.assertIs(positive["whole_child_source_validation_passed"], True)
        self.assertIs(
            positive["process_health_and_peer_validation_still_required"], True
        )
        self.assertTrue(packet.same(original, request))
        # Default L14 reading does not adopt the offered L15 family.
        legacy = copy.deepcopy(request)
        legacy["schema_version"] = bridge.legacy.REQUEST_SCHEMA
        with self.assertRaisesRegex(closer.ClosureFailure, "REPORT_FIELDS"):
            bridge.legacy.validate_request(legacy)
        for mode in (0, 1, None, "true"):
            with self.assertRaisesRegex(
                closer.ClosureFailure, "L15_CHILD_FAMILY_MODE_KIND"
            ):
                closer.validate_l9_child_report(
                    request["report"],
                    **request["expected_identity"],
                    require_l15_family=mode
                )
        for path in (
            ("report",),
            ("report", "arm_result"),
            ("report", "arm_result", "trace"),
        ):
            for family in ("QSDK-R10F-L14", "QSDK-R10F-L16", None):
                changed = copy.deepcopy(request)
                target = changed
                for key in path:
                    target = target[key]
                target["repair_id"] = family
                no_resume.refresh_trace(changed["report"])
                with self.assertRaises(closer.ClosureFailure):
                    bridge.validate_request(changed)
        for path, key, value in (
            (("expected_identity",), "expected_worker_process_id", True),
            (("report",), "recovery_success_observed", True),
            (("report", "arm_result"), "terminal_orchestrator_transition", {}),
            (("report", "arm_result"), "terminal_recovery_observation_sources", {}),
        ):
            changed = copy.deepcopy(request)
            target = changed
            for component in path:
                target = target[component]
            target[key] = value
            with self.assertRaises(closer.ClosureFailure):
                bridge.validate_request(changed)

    def test_actual_bridge_process_keeps_raw_request_identity_and_zero_scope(self):
        import qsdk_r10f_l15_child_source_bridge as bridge

        original = json.dumps(self.bridge_request(), separators=(",", ":")).encode(
            "utf-8"
        )
        for label, raw, options, should_pass in (
            ("complete", original, [], True),
            ("duplicate", b'{"schema_version":"wrong",' + original[1:], [], False),
            ("nonfinite", b'{"extra":NaN,' + original[1:], [], False),
            ("invalid_utf8", original + b"\xff", [], False),
            ("unknown_option", original, ["--accept-other-family"], False),
        ):
            with self.subTest(label=label):
                run = subprocess.run(
                    [
                        "C:/Program Files/Python311/python.exe",
                        "-B",
                        str(
                            ROOT
                            / "sdk/conformance/qsdk_r10f_l15_child_source_bridge.py"
                        ),
                        *options,
                    ],
                    input=raw,
                    capture_output=True,
                    cwd=ROOT,
                    timeout=60,
                )
                self.assertEqual(b"", run.stderr)
                lines = run.stdout.decode("utf-8", errors="strict").splitlines()
                self.assertEqual(1, len(lines))
                self.assertTrue(lines[0].startswith(bridge.MARKER))
                receipt = packet.parse_json(lines[0][len(bridge.MARKER) :])
                self.assertEqual(
                    0 if should_pass else 1, run.returncode, receipt["failure_code"]
                )
                self.assertIs(receipt["ok"], should_pass)
                self.assertEqual(
                    "sha256:" + hashlib.sha256(raw).hexdigest(),
                    receipt["offered_request_raw_sha256"],
                )
                for key in (
                    "model_construction_count",
                    "world_attempt_count",
                    "world_build_count",
                    "scene_tree_insertion_count",
                    "native_readback_count",
                    "solver_step_count",
                ):
                    self.assertIs(type(receipt[key]), int)
                    self.assertEqual(0, receipt[key])
                for key in (
                    "physics_state_modified",
                    "physical_execution_authorized",
                    "physical_acceptance_authority",
                    "release_authority",
                ):
                    self.assertIs(receipt[key], False)
                if not should_pass:
                    self.assertNotIn("no_resume_terminal", receipt)


if __name__ == "__main__":
    unittest.main(verbosity=2)
