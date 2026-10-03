"""Actual recovery sender -> actual bounded launcher -> detached worker guard.

The only launch seam replaces the physical worker script with the zero-world
receiver. Expected bytes come from a separate test preparation, not a report or
official qualification. Temporary outputs are owned source fixtures only.
"""

import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_qsdk_r10f_l15_collection_transport import ROOT, run_zero_world_fixture
import qsdk_r10f_l15_collection_context as context
import qsdk_r10f_l15_launch_relationship as launch
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_physical_closure as closer

LENGTH_ENV = "SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_UTF8_BYTE_LENGTH"
SHA_ENV = "SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_RAW_SHA256"
STALE = {LENGTH_ENV: "stale_parent_length", SHA_ENV: "stale_parent_digest"}


def powershell(mode, value):
    environment = os.environ.copy()
    environment.update(STALE)
    run = subprocess.run(
        [
            "C:/Program Files/PowerShell/7/pwsh.exe",
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(ROOT / "tests/test_r10dg_context_environment.ps1"),
            "-Mode",
            mode,
        ],
        cwd=ROOT,
        input=json.dumps(value, ensure_ascii=False),
        text=True,
        encoding="utf-8",
        capture_output=True,
        timeout=120,
        creationflags=subprocess.CREATE_NO_WINDOW,
        env=environment,
    )
    if run.returncode or run.stderr:
        raise AssertionError(
            f"ENVIRONMENT_FIXTURE:{run.returncode}:{run.stderr}:{run.stdout[:4000]}"
        )
    return context.packet.parse_json(run.stdout)


class R10DGContextEnvironment(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        prepared = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_pre_world_context_zero_world.gd",
            "QSDK_R10F_L15_PRE_WORLD_CONTEXT_ZERO_WORLD ",
        )
        cls.capture = prepared["expected_capture"]
        cls.binding = context.raw_binding(cls.capture["utf8_text"])
        cls.identity = context.validate_capture(
            cls.capture["utf8_text"],
            expected_raw_binding=cls.binding,
            canonical_sha256=closer.canonical_sha256_v1,
        )["expected_identity"]

    def invoke(self, expectation, *, repair="QSDK-R10F-L15"):
        evidence = (ROOT.parent / "SporeSpore_Evidence").resolve()
        owned = tempfile.TemporaryDirectory(
            prefix="qsdk-r10f-l15-environment-", dir=evidence
        )
        self.addCleanup(owned.cleanup)
        directory = Path(owned.name).resolve()
        self.assertEqual(evidence, directory.parent)
        source = closer.l9_synthetic_supervisor("behavior_positive")
        result = powershell(
            "Launch",
            {
                "fixture_root": str(directory),
                "repair_id": repair,
                "parent_attempt_id": source["attempt_id"],
                "descriptor": source["ordered_child_manifest"][0],
                "source_commit": source["source_commit"],
                "authority_sha256": source["authority_sha256"],
                "expectation": expectation,
            },
        )
        self.assertEqual(STALE, result["parent_environment_before"])
        self.assertEqual(STALE, result["parent_environment_after"])
        self.assertEqual(
            result["original_script_scrub_names"], result["final_script_scrub_names"]
        )
        for field in (
            "model_construction_count",
            "world_build_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertEqual(0, result[field])
        for field in (
            "complete_physical_worker_run_executed",
            "supervisor_outer_catch_executed",
            "official_qualification_origin_used",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(result[field], False)
        return result, source, directory

    def expectation(self, binding=None):
        return {
            "raw_capture_binding": self.binding if binding is None else binding,
            "collection_identity": self.identity,
        }

    def assert_receiver(self, result, source, *, accepted, repair="QSDK-R10F-L15"):
        self.assertEqual("", result["caught_failure"])
        self.assertEqual(1, result["launcher_call_count"])
        envelope = result["envelope"]
        self.assertIs(envelope["termination_protocol_valid"], True)
        self.assertIs(envelope["engine_health_passed"], True)
        self.assertIs(envelope["raw_marker_valid"], True)
        self.assertEqual(0, envelope["exit_code"])
        child_root = Path(envelope["evidence_path"])
        termination = context.packet.parse_json(
            (child_root / "termination_receipt.json").read_text()
        )
        self.assertIs(termination["supervisor_terminated"], True)
        self.assertIs(termination["timed_out"], False)
        if repair == "QSDK-R10F-L15":
            expected = launch.production_context(
                parent_attempt_id=source["attempt_id"],
                descriptor=result["descriptor"],
                source_commit=source["source_commit"],
                authority_sha256=source["authority_sha256"],
                runtime_binding=runtime.expected_binding(),
            )
            launch.validate_child_launch(envelope, expected)
        else:
            self.assertNotIn("r10f_l15_launch_relationship", envelope)
            self.assertNotIn("r10f_l15_launch_relationship", termination)
        report = envelope["report"]
        self.assertTrue(
            context.packet.same(
                report,
                context.packet.parse_json(
                    (child_root / "worker_report.json").read_text()
                ),
            )
        )
        self.assertIs(
            report["ok"], True
        )  # Receiver executed; not the guard's decision.
        self.assertIs(report["worker_guard_accepted"], accepted)
        self.assertIs(
            report["actual_worker_method_executed_in_detached_refcounted_host"], True
        )
        for field in context.ZERO_COUNTERS:
            self.assertIs(type(report[field]), int)
            self.assertEqual(0, report[field])
        for field in (
            "environment_modified_in_receiver",
            "complete_physical_worker_run_executed",
            "official_supervisor_qualification_origin_used_in_fixture",
            "physics_state_modified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(report[field], False)
        self.assertEqual(1, report["production_v18_context_preparation_call_count"])
        return report

    def test_actual_sender_overrides_stale_parent_and_guard_accepts(self):
        result, source, _ = self.invoke(self.expectation())
        report = self.assert_receiver(result, source, accepted=True)
        wanted = {
            LENGTH_ENV: str(self.binding["utf8_byte_length"]),
            SHA_ENV: self.binding["raw_sha256"],
        }
        self.assertEqual(wanted, report["received_environment"])
        for name, value in wanted.items():
            self.assertEqual(value, result["offered_environment"][name])
            self.assertEqual(1, result["offered_scrub_names"].count(name))
        proof = context.validate_worker_comparison(
            report["comparison"],
            expected_raw_binding=self.binding,
            expected_identity=self.identity,
            canonical_sha256=closer.canonical_sha256_v1,
        )
        self.assertIs(proof["prepared_context_valid"], True)
        self.assertIs(proof["expected_context_origin_authenticated_here"], False)

    def test_well_formed_crossed_binding_is_delivered_but_actual_guard_refuses(self):
        for field, value in (
            ("utf8_byte_length", self.binding["utf8_byte_length"] + 1),
            ("raw_sha256", "sha256:" + "0" * 64),
        ):
            with self.subTest(field=field):
                binding = dict(self.binding, **{field: value})
                result, source, _ = self.invoke(self.expectation(binding))
                report = self.assert_receiver(result, source, accepted=False)
                self.assertEqual(
                    {
                        LENGTH_ENV: str(binding["utf8_byte_length"]),
                        SHA_ENV: binding["raw_sha256"],
                    },
                    report["received_environment"],
                )
                comparison = report["comparison"]
                self.assertEqual(
                    "L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH",
                    comparison["failure_code"],
                )
                self.assertTrue(
                    context.packet.same(self.capture, comparison["observed_capture"])
                )

    def test_missing_or_malformed_binding_refuses_before_any_launcher_or_report(self):
        for expectation in (
            None,
            {},
            {"raw_capture_binding": None},
            self.expectation(dict(self.binding, utf8_byte_length=True)),
        ):
            with self.subTest(expectation=expectation):
                result, _, directory = self.invoke(expectation)
                self.assertIn(
                    "L15_CONTEXT_ENVIRONMENT_BINDING_INVALID", result["caught_failure"]
                )
                self.assertEqual(0, result["launcher_call_count"])
                self.assertIsNone(result["envelope"])
                self.assertIsNone(result["offered_environment"])
                self.assertEqual(
                    ["child_attempt_identity.json"],
                    sorted(path.name for path in (directory / "child").iterdir()),
                )

    def test_legacy_sender_keeps_its_original_environment_and_guard_bypass(self):
        result, source, _ = self.invoke(None, repair="QSDK-R10F-L14")
        report = self.assert_receiver(
            result, source, accepted=True, repair="QSDK-R10F-L14"
        )
        self.assertIsNone(report["comparison"])
        self.assertEqual(STALE, report["received_environment"])
        for name in STALE:
            self.assertNotIn(name, result["offered_environment"])
            self.assertNotIn(name, result["offered_scrub_names"])

    def test_projection_accepts_only_exact_binding_and_canonical_strings(self):
        positives = [
            self.binding,
            dict(self.binding, utf8_byte_length=1),
            dict(self.binding, utf8_byte_length=2**63 - 1),
        ]
        cases = [
            {"name": f"positive:{index}", "raw": json.dumps(value)}
            for index, value in enumerate(positives)
        ]
        invalid = [None, [], {}, self.capture, dict(self.binding, extra=False)]
        for key in self.binding:
            changed = copy.deepcopy(self.binding)
            del changed[key]
            invalid.append(changed)
            changed = copy.deepcopy(self.binding)
            changed[key.upper()] = changed.pop(key)
            invalid.append(changed)
        for value in (True, False, 0, -1, 1.0, "1", None, 2**63):
            invalid.append(dict(self.binding, utf8_byte_length=value))
        for value in (
            None,
            True,
            123,
            "",
            self.binding["raw_sha256"].upper(),
            self.binding["raw_sha256"] + "\n",
            " " + self.binding["raw_sha256"],
            "sha256:" + "z" * 64,
        ):
            invalid.append(dict(self.binding, raw_sha256=value))
        cases.extend(
            {"name": f"invalid:{index}", "raw": json.dumps(value)}
            for index, value in enumerate(invalid)
        )
        cases.extend(
            [
                {
                    "name": "duplicate",
                    "raw": '{"utf8_byte_length":1,' + json.dumps(self.binding)[1:],
                },
                {
                    "name": "nonfinite",
                    "raw": '{"utf8_byte_length":NaN,"raw_sha256":"sha256:'
                    + "0" * 64
                    + '"}',
                },
            ]
        )
        result = powershell("Project", {"cases": cases})
        self.assertEqual(len(cases), len(result["results"]))
        for case in result["results"]:
            if case["name"].startswith("positive:"):
                source = positives[int(case["name"].split(":")[1])]
                self.assertEqual("", case["failure"], case)
                self.assertEqual(
                    {
                        LENGTH_ENV: str(source["utf8_byte_length"]),
                        SHA_ENV: source["raw_sha256"],
                    },
                    case["environment"],
                )
            else:
                self.assertIsNone(case["environment"], case)
                self.assertTrue(case["failure"], case)
        print(
            f"L15_CONTEXT_ENVIRONMENT_PROJECTION_PASS positives=3 corruptions={len(cases) - 3} zero_world=true",
            flush=True,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
