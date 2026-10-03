"""Original normal report through actual writers and external-context consumers.

The expected binding comes from a different V18 preparation, not the report.
This is still test-supplied origin, not official qualification or a physics run.
"""

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
from unittest import mock

import test_qsdk_r10f_l15_collection_enclosing_retention as enclosing
import test_qsdk_r10f_l15_launch_consumers as launch
import test_qsdk_r10f_l15_normal_finalization as normal
from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture

closer = enclosing.closer
context = enclosing.context_reader
packet = context.packet
import qsdk_r10f_l15_context_source_bridge as bridge


class ContextConsumers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        normal.NormalFinalization.setUpClass()
        cls.addClassCleanup(normal.NormalFinalization.doClassCleanups)
        cls.raw = normal.NormalFinalization.raw
        cls.report = normal.NormalFinalization.report
        cls.comparison = cls.report["l15_prepared_context_comparison"]
        prepared = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_pre_world_context_zero_world.gd",
            "QSDK_R10F_L15_PRE_WORLD_CONTEXT_ZERO_WORLD ",
        )
        cls.context_comparison = prepared["positive_comparison"]
        capture = prepared["expected_capture"]
        cls.expected = context.raw_binding(capture["utf8_text"])
        cls.identity = context.validate_capture(
            capture["utf8_text"],
            expected_raw_binding=cls.expected,
            canonical_sha256=closer.canonical_sha256_v1,
        )["expected_identity"]
        cls.case = enclosing.EnclosingCollectionRetention.make_enclosing_case.__func__(
            cls,
            cls.raw,
            expected_context_binding=cls.expected,
            expected_collection_identity=cls.identity,
        )

    def validate(self, value, *, identity=None):
        return context.validate_worker_comparison(
            value,
            expected_raw_binding=self.expected,
            expected_identity=self.identity if identity is None else identity,
            canonical_sha256=closer.canonical_sha256_v1,
        )

    def child(self, report=None, *, binding=None, use_missing_binding=False):
        primary = self.case["primary"]
        envelope = copy.deepcopy(primary["child_envelopes"][1])
        if report is not None:
            envelope["report"] = report
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            return closer.validate_l9_child_envelope(
                envelope,
                primary["ordered_child_manifest"][1],
                parent_attempt_id=primary["attempt_id"],
                source_commit=primary["source_commit"],
                authority_sha256=primary["authority_sha256"],
                verify_files=report is None,
                expected_l15_collection_identity=self.identity,
                expected_l15_context_binding=(
                    None
                    if use_missing_binding
                    else self.expected if binding is None else binding
                ),
            )

    def test_original_normal_report_crosses_actual_writer_and_child_file_reader(self):
        child = self.child()
        self.assertIs(child["child_valid"], True, child["child_validation_error"])
        self.assertIs(
            child["prepared_context_integrity"]["prepared_context_valid"], True
        )
        self.assertEqual("precondition_negative", child["child"]["role_outcome"])
        raw_lines = [
            line[len(closer.RAW_MARKER) :]
            for line in (Path(child["evidence_path"]) / "worker.stdout.txt")
            .read_text(encoding="utf-8")
            .splitlines()
            if line.startswith(closer.RAW_MARKER)
        ]
        self.assertEqual([self.raw], raw_lines)
        self.assertTrue(
            packet.same(
                self.report, self.case["primary"]["child_envelopes"][1]["report"]
            )
        )
        self.assertEqual(2, self.case["control"]["process_fixture_call_count"])
        for key in (
            "model_construction_count",
            "world_build_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertIs(type(self.case["control"][key]), int)
            self.assertEqual(0, self.case["control"][key])

    def test_independently_prepared_expectation_proves_integrity_not_origin(self):
        proof = self.validate(self.comparison)
        self.assertIs(proof["ok"], True)
        self.assertIs(proof["prepared_context_valid"], True)
        self.assertTrue(packet.same(proof["raw_capture_binding"], self.expected))
        self.assertTrue(packet.same(self.context_comparison, self.comparison))
        for field in context.ZERO_COUNTERS:
            self.assertIs(type(proof[field]), int)
            self.assertEqual(0, proof[field])
        for field in (
            "expected_context_origin_authenticated_here",
            "official_context_qualification",
            "context_integrity_establishes_valid_child",
            "physics_state_modified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(proof[field], False)

    def test_missing_extra_wrong_kind_or_promoted_comparison_fields_refuse(self):
        self.validate(self.comparison)
        for key in self.comparison:
            with self.subTest(missing=key), self.assertRaises(ValueError):
                value = copy.deepcopy(self.comparison)
                del value[key]
                self.validate(value)
        for key in context.ZERO_COUNTERS | {"context_capture_call_count"}:
            for substitute in (False, True, 0.0, 1.0, "0", None, -1, 2):
                with self.subTest(key=key, substitute=substitute), self.assertRaises(
                    ValueError
                ):
                    value = copy.deepcopy(self.comparison)
                    value[key] = substitute
                    self.validate(value)
        for key in context.COMPARISON_FALSE_FLAGS:
            for substitute in (True, 0, None):
                with self.subTest(key=key, substitute=substitute), self.assertRaises(
                    ValueError
                ):
                    value = copy.deepcopy(self.comparison)
                    value[key] = substitute
                    self.validate(value)
        for key, substitute in (
            ("invented_authority", True),
            ("ok", 1),
            ("expected_capture_binding_matched", 1),
            ("failure_code", "retained_refusal"),
            ("prepared_context_capture_failure_code", "capture_failed"),
            ("schema_version", "crossed"),
            ("ledger_scope", {}),
            ("observed_capture", None),
        ):
            with self.subTest(key=key), self.assertRaises(ValueError):
                value = copy.deepcopy(self.comparison)
                value[key] = substitute
                self.validate(value)

    def test_self_rehashed_worker_capture_cannot_replace_external_expectation(self):
        self.validate(self.comparison)
        value = copy.deepcopy(self.comparison)
        capture = packet.parse_json(value["observed_capture"]["utf8_text"])
        # This source-shaped edit is followed by every offered raw rehash. It
        # still cannot change the independent caller's expected capture identity.
        capture["collection_request_constructor_call_count"] = 2
        raw = json.dumps(capture, separators=(",", ":"))
        replacement = context.raw_binding(raw)
        value["observed_capture"] = {"utf8_text": raw, **replacement}
        value["expected_capture_binding"] = replacement
        with self.assertRaisesRegex(ValueError, "NOT_ENCLOSING_EXPECTATION"):
            self.validate(value)
        damaged = copy.deepcopy(self.report)
        damaged["l15_prepared_context_comparison"] = value
        child = self.child(damaged)
        self.assertIs(child["child_valid"], False)
        self.assertIn("NOT_ENCLOSING_EXPECTATION", child["child_validation_error"])
        self.assertIs(
            child["prepared_context_integrity"]["prepared_context_valid"], False
        )

    def test_missing_binding_is_not_inferred_by_any_enclosing_entrypoint(self):
        for offered in (
            {},
            True,
            {**self.expected, "utf8_byte_length": True},
            {**self.expected, "utf8_byte_length": 0},
            {**self.expected, "utf8_byte_length": 2**63},
            {**self.expected, "raw_sha256": self.expected["raw_sha256"].upper()},
            {**self.expected, "extra": True},
        ):
            with self.subTest(offered=offered), self.assertRaisesRegex(
                closer.ClosureFailure, "QUALIFIED_CONTEXT_BINDING_REQUIRED"
            ):
                self.child(binding=offered)
        with self.assertRaisesRegex(
            closer.ClosureFailure, "QUALIFIED_CONTEXT_BINDING_REQUIRED"
        ):
            self.child(use_missing_binding=True)
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            for terminal in (False, True):
                with self.subTest(terminal=terminal), self.assertRaisesRegex(
                    closer.ClosureFailure, "QUALIFIED_CONTEXT_BINDING_REQUIRED"
                ):
                    if terminal:
                        closer.validate_l9_terminal_supervisor_failure(
                            {},
                            report_path=self.case["directory"] / "not_written.json",
                            expected_l15_collection_identity=self.identity,
                        )
                    else:
                        closer.validate_l9_report(
                            self.case["primary"],
                            report_path=None,
                            verify_files=False,
                            expected_l15_collection_identity=self.identity,
                        )

    def test_missing_context_and_crossed_collection_identity_cannot_qualify_child(self):
        self.assertIs(self.child()["child_valid"], True)
        for value in (None, {}, {**self.comparison, "ok": False}):
            damaged = copy.deepcopy(self.report)
            damaged["l15_prepared_context_comparison"] = value
            child = self.child(damaged)
            self.assertIs(child["child_valid"], False)
            self.assertIn("PREPARED_CONTEXT_INVALID", child["child_validation_error"])
        changed = copy.deepcopy(self.identity)
        changed["task_id"] = "unrelated_task"
        with self.assertRaisesRegex(ValueError, "NOT_ENCLOSING_COLLECTION_IDENTITY"):
            self.validate(self.comparison, identity=changed)
        crossed = {**self.expected, "raw_sha256": "sha256:" + "0" * 64}
        child = self.child(binding=crossed)
        self.assertIs(child["child_valid"], False)
        self.assertIn("NOT_ENCLOSING_EXPECTATION", child["child_validation_error"])

    def test_legacy_default_does_not_require_or_adopt_future_context(self):
        self.assertEqual("QSDK-R10F-L14", closer.REPAIR_ID)
        source = launch.complete_fixture()
        child = launch.child_projection(source)
        self.assertIs(child["child_valid"], True)
        self.assertNotIn("prepared_context_integrity", child)
        self.assertIs(closer.require_l15_context_expectations(None, None), False)

    def test_whole_reader_refuses_claimed_success_with_invalid_child_context(self):
        # Complete synthetic input isolates the independent supervisor reader.
        # The PowerShell pre-evaluator context handoff remains separate work.
        with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
            source = launch.complete_fixture()
            for envelope in source["child_envelopes"]:
                envelope["report"]["l15_prepared_context_comparison"] = copy.deepcopy(
                    self.comparison
                )

            def read(value):
                return closer.validate_l9_report(
                    value,
                    report_path=None,
                    verify_files=False,
                    expected_l15_collection_identity=self.identity,
                    expected_l15_context_binding=self.expected,
                )

            positive = read(source)
            self.assertIs(positive["route_execution_valid"], True)
            self.assertIs(positive["behavior_passed"], True)
            for index in (0, 1):
                damaged = copy.deepcopy(source)
                damaged["child_envelopes"][index]["report"][
                    "l15_prepared_context_comparison"
                ] = None
                with self.subTest(index=index), self.assertRaisesRegex(
                    closer.ClosureFailure, "L9_.*POPULATION"
                ):
                    read(damaged)

    def bridge_request(self):
        return {
            "schema_version": bridge.REQUEST_SCHEMA,
            "comparison": self.comparison,
            "expected_capture_binding": self.expected,
            "expected_collection_identity": self.identity,
        }

    def invoke_bridge(self, raw, options=()):
        run = subprocess.run(
            [
                "C:/Program Files/Python311/python.exe",
                "-B",
                str(
                    normal.ROOT
                    / "sdk/conformance/qsdk_r10f_l15_context_source_bridge.py"
                ),
                *options,
            ],
            cwd=normal.ROOT,
            input=raw,
            capture_output=True,
            timeout=60,
        )
        self.assertEqual(b"", run.stderr)
        lines = run.stdout.decode("utf-8", errors="strict").splitlines()
        self.assertEqual(1, len(lines))
        self.assertTrue(lines[0].startswith(bridge.MARKER))
        result = packet.parse_json(lines[0][len(bridge.MARKER) :])
        self.assertEqual(
            "sha256:" + hashlib.sha256(raw).hexdigest(),
            result["offered_request_raw_sha256"],
        )
        self.assertEqual(0 if result["ok"] is True else 1, run.returncode)
        return result

    def test_actual_context_bridge_refuses_missing_sources_and_unsafe_json(self):
        raw = json.dumps(self.bridge_request(), separators=(",", ":")).encode()
        positive = self.invoke_bridge(raw)
        self.assertIs(positive["ok"], True)
        self.assertTrue(packet.same(positive["proof"], self.validate(self.comparison)))
        for key in context.ZERO_COUNTERS:
            self.assertIs(type(positive[key]), int)
            self.assertEqual(0, positive[key])
        for label, candidate, options in (
            ("duplicate", b'{"schema_version":"wrong",' + raw[1:], ()),
            ("nonfinite", b'{"extra":NaN,' + raw[1:], ()),
            ("utf8", raw + b"\xff", ()),
            ("option", raw, ("--infer-expected-context",)),
        ):
            with self.subTest(label=label):
                refusal = self.invoke_bridge(candidate, options)
                self.assertIs(refusal["ok"], False)
                self.assertIsNone(refusal["proof"])
        for key in self.bridge_request():
            damaged = copy.deepcopy(self.bridge_request())
            del damaged[key]
            with self.subTest(missing=key):
                refusal = self.invoke_bridge(json.dumps(damaged).encode())
                self.assertIs(refusal["ok"], False)

    def test_actual_powershell_reader_requires_every_bridge_receipt_field(self):
        raw_request = json.dumps(self.bridge_request(), separators=(",", ":")).encode()
        receipt = self.invoke_bridge(raw_request)
        self.assertIs(receipt["ok"], True)
        cases = [{"name": "actual_positive", "raw": json.dumps(receipt)}]

        def visit(value, prefix=()):
            if type(value) is dict:
                for key, child in value.items():
                    path = (*prefix, key)
                    yield path, child
                    yield from visit(child, path)

        for path, original in visit(receipt):
            changed = copy.deepcopy(receipt)
            target = changed
            for key in path[:-1]:
                target = target[key]
            del target[path[-1]]
            cases.append({"name": "missing:" + str(path), "raw": json.dumps(changed)})
            if type(original) in (int, bool):
                for replacement in (str(original), float(original), None):
                    changed = copy.deepcopy(receipt)
                    target = changed
                    for key in path[:-1]:
                        target = target[key]
                    target[path[-1]] = replacement
                    cases.append(
                        {
                            "name": "kind:"
                            + str(path)
                            + ":"
                            + type(replacement).__name__,
                            "raw": json.dumps(changed),
                        }
                    )
        original_raw = json.dumps(receipt, separators=(",", ":"))
        cases.extend(
            [
                {"name": "extra", "raw": '{"invented":true,' + original_raw[1:]},
                {"name": "duplicate", "raw": '{"ok":true,' + original_raw[1:]},
                {"name": "nonfinite", "raw": '{"extra":NaN,' + original_raw[1:]},
            ]
        )
        run = subprocess.run(
            [
                "C:/Program Files/PowerShell/7/pwsh.exe",
                "-NoProfile",
                "-NonInteractive",
                "-File",
                str(normal.ROOT / "tests/test_qsdk_r10f_l15_context_source.ps1"),
            ],
            cwd=normal.ROOT,
            input=json.dumps(
                {
                    "cases": cases,
                    "request_sha256": receipt["offered_request_raw_sha256"],
                    "expected_binding": self.expected,
                }
            ),
            text=True,
            encoding="utf-8",
            capture_output=True,
            timeout=60,
        )
        self.assertEqual(0, run.returncode, run.stderr)
        self.assertEqual("", run.stderr)
        result = packet.parse_json(run.stdout)
        self.assertEqual(len(cases), len(result["results"]))
        for case in result["results"]:
            self.assertIs(case["accepted"], case["name"] == "actual_positive", case)
        print(
            f"L15_CONTEXT_RESPONSE_READER_PASS corruptions={len(cases) - 1} zero_world=true",
            flush=True,
        )

    def test_actual_early_and_pair_callers_refuse_context_before_evaluation(self):
        for label, expected_processes in (
            ("positive", 2),
            ("crossed_expectation", 1),
            ("crossed_identity", 1),
            ("active_metadata_missing", 2),
        ):
            with self.subTest(label=label):
                with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
                    source = launch.complete_fixture()
                for envelope in source["child_envelopes"]:
                    envelope["report"]["l15_prepared_context_comparison"] = (
                        copy.deepcopy(self.comparison)
                    )
                binding = copy.deepcopy(self.expected)
                identity = copy.deepcopy(self.identity)
                # Missing/malformed bindings now stop before launch, with no
                # primary report. The actual sender/receiver suite covers that
                # boundary without fabricating a completed supervisor result.
                if label == "crossed_expectation":
                    binding["raw_sha256"] = "sha256:" + "0" * 64
                elif label == "crossed_identity":
                    identity["task_id"] = "unrelated_expected_task"
                elif label == "active_metadata_missing":
                    source["child_envelopes"][1]["report"][
                        "l15_prepared_context_comparison"
                    ] = None
                case = (
                    enclosing.EnclosingCollectionRetention.make_enclosing_case.__func__(
                        type(self),
                        supplied_report=source,
                        expected_context_binding=binding,
                        expected_collection_identity=identity,
                    )
                )
                positive = label == "positive"
                self.assertEqual(0 if positive else 1, case["execution"].returncode)
                self.assertEqual(
                    expected_processes, case["control"]["process_fixture_call_count"]
                )
                primary = case["primary"]
                self.assertEqual(
                    1 if positive else 0, primary["evaluator_invocation_count"]
                )
                self.assertEqual(
                    "positive" if positive else "none", primary["scientific_outcome"]
                )
                if not positive:
                    errors = primary["process_population_evaluation"][
                        "population_validation_errors"
                    ]
                    self.assertTrue(
                        any(
                            "L15_PREPARED_CONTEXT_INVALID" in error for error in errors
                        ),
                        errors,
                    )
                if binding is not None:
                    with mock.patch.object(closer, "REPAIR_ID", "QSDK-R10F-L15"):
                        independently = closer.validate_l9_report(
                            primary,
                            report_path=None,
                            verify_files=False,
                            expected_l15_collection_identity=identity,
                            expected_l15_context_binding=binding,
                        )
                    self.assertIs(independently["route_execution_valid"], positive)
                for counter in (
                    "model_construction_count",
                    "world_build_count",
                    "native_physics_read_count",
                    "solver_step_count",
                ):
                    self.assertEqual(0, case["control"][counter])


if __name__ == "__main__":
    unittest.main(verbosity=2)
