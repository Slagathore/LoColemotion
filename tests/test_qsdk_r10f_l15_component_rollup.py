"""Read the actual combined candidate and rollup, then corrupt complete copies.

One serialized cold run supplies every positive receipt and transcript. Negative
controls only alter copies; they never repeat a physics run or invent a green
replacement for a missing suite. Callable controls have no cold setup, so the
combined candidate can execute them without recursive native/component runs.
This still has no official qualification origin.
"""

import contextlib
import base64
import copy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_component_rollup as rollup
import qsdk_r10f_zero_world_implementation as implementation
import qsdk_r10f_authority_materializer as materializer


class _ReceiptControls:
    # Shared tests only. Neither this mixin nor the callable reader-control
    # host has the standalone cold-run setup defined in ComponentRollup below.
    def consume(self, value):
        rollup.validate_receipt(value, expected_source_bindings=self.sources)

    def test_complete_actual_rollup_preserves_every_output_and_denies_official_scope(
        self,
    ):
        self.consume(self.receipt)
        self.assertEqual(22, len(self.receipt["test_suites"]))
        self.assertEqual(
            137, sum(record["test_count"] for record in self.receipt["test_suites"])
        )
        self.assertEqual(24, len(self.receipt["source_bindings"]))
        self.assertEqual(7, self.receipt["receipt_reader_contract_test_count"])
        self.assertEqual(
            rollup.static_header(),
            {key: self.receipt[key] for key in rollup.static_header()},
        )
        self.assertEqual(
            134, self.receipt["design_audit"]["design_mutation_rejection_count"]
        )
        self.assertEqual(
            39, self.receipt["design_audit"]["retained_diagnosis_control_count"]
        )
        for record in self.receipt["test_suites"]:
            for field in ("stdout", "stderr"):
                self.assertEqual(
                    record[field]["utf8_byte_length"],
                    len(rollup.packet.verify_bytes(record[field])),
                )
        print(
            "L15_COMPONENT_ROLLUP_ACTUAL_PASS suites=22 tests=137 zero_world=true official=false",
            flush=True,
        )

    def test_missing_extra_wrong_kind_or_promoted_header_never_passes(self):
        count = 0
        for key in self.receipt:
            changed = copy.deepcopy(self.receipt)
            del changed[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                self.consume(changed)
            count += 1
        for key, original in rollup.static_header().items():
            replacements = (str(original), None)
            if type(original) is bool:
                replacements += (int(original), not original)
            elif type(original) is int:
                replacements += (float(original), True, original + 1)
            for replacement in replacements:
                if rollup.packet.same(replacement, original):
                    continue
                changed = copy.deepcopy(self.receipt)
                changed[key] = replacement
                with self.subTest(key=key, replacement=replacement), self.assertRaises(
                    ValueError
                ):
                    self.consume(changed)
                count += 1
        changed = copy.deepcopy(self.receipt)
        changed["invented_authority"] = True
        with self.assertRaises(ValueError):
            self.consume(changed)
        print(
            f"L15_COMPONENT_ROLLUP_HEADER_CONTROLS corruptions={count + 1}", flush=True
        )

    def test_each_missing_reordered_or_damaged_suite_refuses_without_rerunning(self):
        for index, (filename, count) in enumerate(rollup.SUITES):
            with self.subTest(filename=filename):
                changed = copy.deepcopy(self.receipt)
                del changed["test_suites"][index]
                with self.assertRaisesRegex(ValueError, "SUITE_POPULATION"):
                    self.consume(changed)
                for key in self.receipt["test_suites"][index]:
                    changed = copy.deepcopy(self.receipt)
                    del changed["test_suites"][index][key]
                    with self.assertRaises(ValueError):
                        self.consume(changed)
                for key, value in (
                    ("test_count", float(count)),
                    ("test_count", True),
                    ("exit_code", False),
                    ("exit_code", 0.0),
                    ("exit_code", 1),
                    ("path", "tests/not_the_selected_suite.py"),
                ):
                    changed = copy.deepcopy(self.receipt)
                    changed["test_suites"][index][key] = value
                    with self.assertRaises(ValueError):
                        self.consume(changed)
        changed = copy.deepcopy(self.receipt)
        changed["test_suites"].reverse()
        with self.assertRaisesRegex(ValueError, "SUITE_PATH"):
            self.consume(changed)

    def test_rehashed_incomplete_skipped_or_failed_actual_output_still_refuses(self):
        original = self.receipt["test_suites"][0]
        stderr = original["stderr"]["utf8_text"]
        for label, text in {
            "skip": stderr.replace("\nOK", "\nOK (skipped=1)"),
            "expected_failure": stderr.replace("\nOK", "\nOK (expected failures=1)"),
            "wrong_count": stderr.replace("Ran 5 tests", "Ran 0 tests"),
            "missing_ok_row": stderr.replace(" ... ok", " ... missing", 1),
            "duplicate_summary": stderr + stderr,
            "missing_summary": "\nOK\n",
            "failed": stderr.replace("\nOK", "\nFAILED (failures=1)"),
            "trailing_data": stderr + "unexpected extra output\n",
        }.items():
            self.assertNotEqual(stderr, text, label)
            changed = copy.deepcopy(self.receipt)
            changed["test_suites"][0]["stderr"] = rollup.snapshot(text.encode("utf-8"))
            with self.subTest(label=label), self.assertRaises(ValueError):
                self.consume(changed)
        for field in ("stdout", "stderr"):
            changed = copy.deepcopy(self.receipt)
            changed["test_suites"][0][field]["utf8_text"] += "changed"
            with self.assertRaises(ValueError):
                self.consume(changed)

    def test_expected_source_population_cannot_be_inferred_from_offered_rollup(self):
        for index in range(len(self.sources)):
            changed = copy.deepcopy(self.receipt)
            changed["source_bindings"][index]["raw_sha256"] = "sha256:" + "0" * 64
            with self.subTest(index=index), self.assertRaisesRegex(
                ValueError, "ENCLOSING_SOURCE_BINDINGS"
            ):
                self.consume(changed)
        for sources in (None, [], self.sources[:-1], list(reversed(self.sources))):
            with self.assertRaises(ValueError):
                rollup.validate_receipt(self.receipt, expected_source_bindings=sources)

    def test_complete_design_and_runtime_sources_are_required(self):
        for group in ("design_audit", "runtime_binding"):
            for key in self.receipt[group]:
                changed = copy.deepcopy(self.receipt)
                del changed[group][key]
                with self.subTest(group=group, key=key), self.assertRaises(ValueError):
                    self.consume(changed)
        for value in (True, -1, float("inf"), float("nan"), "0"):
            changed = copy.deepcopy(self.receipt)
            changed["design_audit"]["elapsed_seconds"] = value
            with self.assertRaises(ValueError):
                self.consume(changed)

    def test_undeclared_suite_refuses_before_starting_a_process(self):
        for filename, count in (
            ("test_qsdk_r10f_worker_source.py", 44),
            ("../sdk/run_qsdk_r10f_continuous_passive_recovery.ps1", 1),
            (rollup.SUITES[0][0], 0),
            (rollup.SUITES[0][0], float(rollup.SUITES[0][1])),
        ):
            with mock.patch.object(rollup.subprocess, "run") as process:
                with self.assertRaisesRegex(ValueError, "UNDECLARED_SUITE"):
                    rollup.execute_suite(filename, count)
                process.assert_not_called()


def exercise_actual_receipt_controls(receipt, *, expected_sources):
    """Test the complete offered receipt without invoking any cold setup."""

    class ActualReceiptControls(_ReceiptControls, unittest.TestCase):
        pass

    ActualReceiptControls.receipt = receipt
    ActualReceiptControls.sources = expected_sources
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ActualReceiptControls)
    if suite.countTestCases() != 7:
        raise ValueError("L15_COMPONENT_READER_CONTROL_POPULATION")
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        result = unittest.TextTestRunner(stream=stderr, verbosity=2).run(suite)
    if (
        result.testsRun != 7
        or not result.wasSuccessful()
        or result.skipped
        or result.expectedFailures
        or result.unexpectedSuccesses
    ):
        raise ValueError(
            "L15_COMPONENT_READER_CONTROL_FAILURE:" + stderr.getvalue()[-6000:]
        )
    return result.testsRun


class _CandidateControls:
    def consume_candidate(self, value, expected=None):
        return materializer.validate_l15_qualification_candidate_record(
            value,
            expected_source_records=(
                self.expected_source_records if expected is None else expected
            ),
        )

    def test_candidate_complete_actual_aggregate_reaches_independent_source_reader(
        self,
    ):
        reopened = materializer.validate_l15_qualification_candidate(
            self.candidate, self.candidate["source_records"]["source"]["source_commit"]
        )
        self.assertTrue(rollup.packet.same(reopened, self.expected_source_records))
        self.consume_candidate(self.candidate)
        self.assertEqual(
            55,
            self.candidate["l14_component_qualification"]["coverage"][
                "python_test_count"
            ],
        )
        self.assertEqual(
            137, self.candidate["l15_component_qualification"]["python_test_count"]
        )
        self.assertEqual(70, len(self.candidate["zero_world_receipt"]))
        self.assertEqual(
            240,
            self.candidate["source_records"]["qualification_inputs"][
                "qualified_source_path_count"
            ],
        )
        historical = self.candidate["source_records"][
            "historical_qualification_wrapper_regression"
        ]
        self.assertEqual(
            335, historical["actual_wrapper_contract"]["mutation_rejection_count"]
        )
        self.assertIs(
            historical["current_l15_receipt_consumed_by_this_legacy_control"], False
        )
        for name in (
            "qualification_wrapper_validated_this_candidate",
            "qualification_directory_validated_this_candidate",
            "official_expected_context_origin_authenticated",
            "complete_implementation_qualified",
            "physical_execution_authorized",
            "qualification_or_physical_identity_created",
        ):
            self.assertIs(self.candidate[name], False)
        print(
            "L15_COMPLETE_CANDIDATE_ACTUAL_PASS legacy=55 additional=137 official=false",
            flush=True,
        )

    def test_candidate_missing_or_promoted_top_level_fields_refuse(self):
        count = 0
        for key in self.candidate:
            changed = copy.deepcopy(self.candidate)
            del changed[key]
            with self.subTest(missing=key), self.assertRaises(
                materializer.MaterializationFailure
            ):
                self.consume_candidate(changed)
            count += 1
        for key, value in implementation.l15_qualification_candidate_header().items():
            replacements = [None]
            if type(value) is int:
                replacements += [False, float(value), str(value), value + 1]
            elif type(value) is bool:
                replacements += [int(value), not value]
            elif type(value) is str:
                replacements += [value + "_changed"]
            elif type(value) is dict:
                replacements += [{}, {**value, "extra": True}]
            for replacement in replacements:
                changed = copy.deepcopy(self.candidate)
                changed[key] = replacement
                with self.subTest(key=key), self.assertRaises(
                    materializer.MaterializationFailure
                ):
                    self.consume_candidate(changed)
                count += 1
        with self.assertRaises(materializer.MaterializationFailure):
            self.consume_candidate({**self.candidate, "extra": True})
        print("L15_CANDIDATE_HEADER_CORRUPTIONS=" + str(count + 1), flush=True)

    def test_candidate_every_complete_source_record_is_required(self):
        for group in self.candidate["source_records"]:
            changed = copy.deepcopy(self.candidate)
            del changed["source_records"][group]
            with self.subTest(missing=group), self.assertRaises(
                materializer.MaterializationFailure
            ):
                self.consume_candidate(changed)
            for replacement in (
                None,
                {},
                {**self.candidate["source_records"][group], "invented_field": True},
            ):
                changed = copy.deepcopy(self.candidate)
                changed["source_records"][group] = replacement
                with self.subTest(group=group), self.assertRaises(
                    materializer.MaterializationFailure
                ):
                    self.consume_candidate(changed)
        for expected in (
            None,
            {},
            {
                key: val
                for key, val in self.expected_source_records.items()
                if key != "qualification_inputs"
            },
        ):
            with self.assertRaises(materializer.MaterializationFailure):
                materializer.validate_l15_qualification_candidate_record(
                    self.candidate, expected_source_records=expected
                )
        changed = copy.deepcopy(self.candidate)
        changed["source_records"]["qualification_inputs"]["qualified_source_bindings"][
            0
        ]["raw_sha256"] = ("sha256:" + "0" * 64)
        with self.assertRaises(materializer.MaterializationFailure):
            self.consume_candidate(changed)

    def test_candidate_corrupted_results_cannot_be_replaced_by_green_subsets(self):
        for path, replacement in (
            (("static_source_receipt", "unittest_case_count"), 0),
            (("dependency_receipt", "qualified_source_path_count"), 239),
            (("zero_world_receipt", "positive_case_count"), 23),
            (("zero_world_receipt", "l15_prepared_collection_context"), None),
            (("worker_parse_receipt", "worker_parse_exit_code"), False),
            (("worker_parse_receipt", "worker_parse_stdout_sha256"), "missing"),
            (
                ("worker_parse_receipt", "worker_parse_stdout_sha256"),
                "sha256:" + "0" * 64,
            ),
            (
                ("worker_parse_receipt", "l15_process_output", "stdout", "utf8_text"),
                "changed",
            ),
            (
                (
                    "worker_parse_receipt",
                    "l15_process_output",
                    "official_source_origin_authenticated",
                ),
                True,
            ),
            (("l14_component_qualification", "coverage", "python_test_count"), 54),
            (("l15_component_qualification", "test_suites", 0, "exit_code"), 1),
            (("l15_component_qualification", "source_bindings", 0, "byte_length"), 0),
            (("prepared_context_integrity", "official_context_qualification"), True),
        ):
            changed = copy.deepcopy(self.candidate)
            owner = changed
            for key in path[:-1]:
                owner = owner[key]
            owner[path[-1]] = replacement
            with self.subTest(path=path), self.assertRaises(
                materializer.MaterializationFailure
            ):
                self.consume_candidate(changed)
        for key in (
            "static_source_receipt",
            "zero_world_receipt",
            "worker_parse_receipt",
            "l14_component_qualification",
            "l15_component_qualification",
            "prepared_context_integrity",
        ):
            changed = copy.deepcopy(self.candidate)
            changed[key] = {"ok": True}
            with self.subTest(key=key), self.assertRaises(
                materializer.MaterializationFailure
            ):
                self.consume_candidate(changed)

    def test_candidate_pure_reader_never_executes_or_reopens_components(self):
        with mock.patch.object(
            implementation,
            "audit_l15_qualification_source_records",
            side_effect=AssertionError("NO_SOURCE_REOPEN"),
        ), mock.patch.object(
            implementation, "checked_process", side_effect=AssertionError("NO_PROCESS")
        ), mock.patch.object(
            rollup, "audit", side_effect=AssertionError("NO_L15_RERUN")
        ), mock.patch.object(
            implementation.l14_components,
            "audit",
            side_effect=AssertionError("NO_LEGACY_RERUN"),
        ), mock.patch.object(
            subprocess, "run", side_effect=AssertionError("NO_SUBPROCESS")
        ):
            proof = self.consume_candidate(self.candidate)
        self.assertTrue(
            rollup.packet.same(proof, self.candidate["prepared_context_integrity"])
        )

    def test_candidate_official_cli_and_invalid_source_never_reach_qualification(self):
        result = subprocess.run(
            [
                sys.executable,
                "-B",
                str(ROOT / "sdk/conformance/qsdk_r10f_zero_world_implementation.py"),
                "--l15-qualification-candidate",
                "--official-qualification",
            ],
            cwd=ROOT,
            capture_output=True,
            timeout=30,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        self.assertEqual(2, result.returncode)
        self.assertEqual(b"", result.stdout)
        self.assertIn(b"not allowed with argument", result.stderr)
        with mock.patch.object(
            implementation,
            "audit_l15_qualification_source_records",
            side_effect=AssertionError("NO_SOURCE_REOPEN"),
        ):
            for source in (None, False, "HEAD", "x" * 40):
                with self.assertRaises(materializer.MaterializationFailure):
                    materializer.validate_l15_qualification_candidate(
                        self.candidate, source
                    )
            with self.assertRaises(materializer.MaterializationFailure):
                materializer.validate_l15_qualification_candidate(
                    [], self.expected_source_records["source"]["source_commit"]
                )


def exercise_actual_candidate_controls(candidate, *, expected_source_records):
    """Run all combined-reader controls on the actual result, with no cold setup."""

    class ActualCandidateControls(_CandidateControls, unittest.TestCase):
        pass

    ActualCandidateControls.candidate = candidate
    ActualCandidateControls.expected_source_records = expected_source_records
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ActualCandidateControls)
    if suite.countTestCases() != 6:
        raise ValueError("L15_CANDIDATE_READER_CONTROL_POPULATION")
    stdout, stderr = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(stdout):
        result = unittest.TextTestRunner(stream=stderr, verbosity=2).run(suite)
    if (
        result.testsRun != 6
        or not result.wasSuccessful()
        or result.skipped
        or result.expectedFailures
        or result.unexpectedSuccesses
    ):
        raise ValueError(
            "L15_CANDIDATE_READER_CONTROL_FAILURE:" + stderr.getvalue()[-6000:]
        )
    return result.testsRun


class _OutputControls:
    def test_output_actual_complete_cli_bytes_reach_pure_materializer(self):
        with mock.patch.object(
            implementation,
            "audit_l15_qualification_source_records",
            side_effect=AssertionError("NO_SOURCE_REOPEN"),
        ), mock.patch.object(
            subprocess, "run", side_effect=AssertionError("NO_PROCESS")
        ):
            candidate, raw_json = (
                materializer.validate_l15_qualification_candidate_output(
                    self.execution.stdout,
                    self.execution.stderr,
                    self.execution.returncode,
                    expected_source_records=self.expected_source_records,
                )
            )
        self.assertTrue(rollup.packet.same(candidate, self.candidate))
        self.assertEqual(self.raw_candidate_json, raw_json)
        self.assertIs(candidate["complete_implementation_qualified"], False)
        self.assertEqual(
            137, candidate["l15_component_qualification"]["python_test_count"]
        )

    def test_output_strict_transport_and_complete_result_corruptions_refuse(self):
        marker = implementation.L15_CANDIDATE_MARKER.encode("ascii")
        raw = self.raw_candidate_json
        count = 0
        with mock.patch.object(
            implementation,
            "audit_l15_qualification_source_records",
            side_effect=AssertionError("NO_SOURCE_REOPEN"),
        ), mock.patch.object(
            subprocess, "run", side_effect=AssertionError("NO_PROCESS")
        ):
            for stdout, stderr, code in (
                (None, b"", 0),
                (b"", None, 0),
                (self.execution.stdout, b"", False),
                (self.execution.stdout, b"", 0.0),
                (self.execution.stdout, b"", "0"),
                (self.execution.stdout, b"", 1),
                (self.execution.stdout + b"\xff", b"", 0),
                (self.execution.stdout, b"\xff", 0),
                (b"", b"", 0),
                (self.execution.stdout + b"\n" + self.execution.stdout, b"", 0),
                (implementation.PASS_MARKER.encode() + raw, b"", 0),
                (self.execution.stdout, b"ERROR: late failure", 0),
                (self.execution.stdout, b"Traceback (most recent call last):", 0),
                (
                    self.execution.stdout
                    + b"\nQSDK_R10F_ZERO_WORLD_IMPLEMENTATION_FAIL damaged",
                    b"",
                    0,
                ),
                (marker + b'{"ok":true,' + raw[1:], b"", 0),
                (marker + b'{"extra":NaN,' + raw[1:], b"", 0),
                (marker + b'{"extra":1e999,' + raw[1:], b"", 0),
                (marker + raw + b"{}", b"", 0),
                (marker + b'{"ok":true}', b"", 0),
            ):
                with self.subTest(case=count), self.assertRaises(
                    materializer.MaterializationFailure
                ):
                    materializer.validate_l15_qualification_candidate_output(
                        stdout,
                        stderr,
                        code,
                        expected_source_records=self.expected_source_records,
                    )
                count += 1
            for key in self.candidate:
                changed = copy.deepcopy(self.candidate)
                del changed[key]
                with self.subTest(missing=key), self.assertRaises(
                    materializer.MaterializationFailure
                ):
                    materializer.validate_l15_qualification_candidate_output(
                        marker + json.dumps(changed).encode(),
                        b"",
                        0,
                        expected_source_records=self.expected_source_records,
                    )
                count += 1
            for expected in (
                None,
                {},
                {"source": self.expected_source_records["source"]},
            ):
                with self.assertRaises(materializer.MaterializationFailure):
                    materializer.validate_l15_qualification_candidate_output(
                        self.execution.stdout,
                        self.execution.stderr,
                        0,
                        expected_source_records=expected,
                    )
                count += 1
        print("L15_COMPLETE_OUTPUT_READER_CORRUPTIONS=" + str(count), flush=True)

    def test_output_actual_wrapper_function_and_cli_consume_original_complete_bytes(
        self,
    ):
        # Load only the actual reader and its two pure guards. The full wrapper's
        # lock/identity/writer body is deliberately not executed by this test.
        script = r"""
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$inputRecord = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 10
$script:RepoRoot = [string]$inputRecord.repo_root
$script:PythonPath = [string]$inputRecord.python_path
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $script:RepoRoot 'sdk/qsdk_r10f_zero_world_qualification.ps1'),
    [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'WRAPPER_PARSE' }
foreach ($name in @('Assert-R10fQualification', 'Test-ExactJsonIntegerZero', 'Read-L15QualificationCandidateOutput')) {
    $found = @($ast.FindAll({param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $true))
    if ($found.Count -ne 1) { throw 'EXACT_FUNCTION_COUNT' }
    . ([scriptblock]::Create($found[0].Extent.Text))
}
$result = Read-L15QualificationCandidateOutput -StdoutBytes ([Convert]::FromBase64String($inputRecord.stdout_base64)) -StderrBytes ([Convert]::FromBase64String($inputRecord.stderr_base64)) -ExitCode $inputRecord.exit_code -SourceCommit $inputRecord.source_commit
[Console]::Out.Write(($result | ConvertTo-Json -Compress -Depth 100))
"""
        source_commit = self.expected_source_records["source"]["source_commit"]
        envelope = {
            "source_commit": source_commit,
            "exit_code": self.execution.returncode,
            "stdout_base64": base64.b64encode(self.execution.stdout).decode("ascii"),
            "stderr_base64": base64.b64encode(self.execution.stderr).decode("ascii"),
        }
        arguments = {**envelope, "repo_root": str(ROOT), "python_path": sys.executable}
        result = subprocess.run(
            [
                "C:/Program Files/PowerShell/7/pwsh.exe",
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                script,
            ],
            cwd=ROOT,
            input=json.dumps(arguments).encode("utf-8"),
            capture_output=True,
            timeout=360,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        self.assertEqual(
            0,
            result.returncode,
            result.stderr.decode("utf-8", errors="replace")[-5000:],
        )
        self.assertEqual(b"", result.stderr)
        receipt = rollup.packet.parse_json(result.stdout.decode("utf-8"))
        self.assertEqual(
            "sporespore_qsdk_r10f_l15_qualification_output_reader_v1",
            receipt["schema_version"],
        )
        self.assertEqual(
            self.raw_candidate_json,
            rollup.packet.verify_bytes(receipt["candidate_json"]),
        )
        self.assertTrue(
            rollup.packet.same(
                rollup.packet.parse_json(receipt["runtime_identity_json"]["utf8_text"]),
                self.candidate["source_records"]["runtime_identity"],
            )
        )
        rollup.packet.verify_bytes(receipt["runtime_identity_json"])
        self.assertTrue(
            rollup.packet.same(
                receipt["prepared_context_snapshot"],
                self.candidate["zero_world_receipt"]["l15_prepared_collection_context"],
            )
        )
        self.assertEqual(
            self.expected_source_records["qualification_inputs"][
                "qualified_source_binding_sha256"
            ],
            receipt["source_binding_sha256"],
        )
        for name in (
            "official_source_origin_authenticated",
            "qualification_or_physical_identity_created",
            "qualification_directory_validated",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(receipt[name], False)
        # These malformed transport envelopes are rejected by the actual CLI
        # before expensive source reopening. None is a replacement positive.
        cases = [b"{}", b'{"source_commit":1,"source_commit":2}', b"\xff"]
        for key, replacement in (
            ("source_commit", False),
            ("exit_code", False),
            ("exit_code", 0.0),
            ("stdout_base64", "%%"),
            ("stderr_base64", "/w=="),
        ):
            changed = {**envelope, key: replacement}
            cases.append(json.dumps(changed).encode("utf-8"))
        for case in cases:
            refused = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    str(ROOT / "sdk/conformance/qsdk_r10f_authority_materializer.py"),
                    "read-l15-candidate-output",
                ],
                cwd=ROOT,
                input=case,
                capture_output=True,
                timeout=30,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            self.assertEqual(1, refused.returncode)
            self.assertEqual(b"", refused.stdout)
            self.assertIn(b"QSDK_R10F_AUTHORITY_MATERIALIZER_FAIL", refused.stderr)
        print(
            "L15_ACTUAL_WRAPPER_OUTPUT_PASS full_candidate=true malformed_cli_refusals=8 official=false",
            flush=True,
        )


class _CaptureControls:
    def test_capture_actual_pre_execution_record_and_all_six_files_reach_reader(self):
        with mock.patch.object(
            subprocess, "run", side_effect=AssertionError("NO_PROCESS")
        ), mock.patch.object(
            implementation,
            "audit_l15_qualification_source_records",
            side_effect=AssertionError("NO_SOURCE_REOPEN"),
        ):
            proof = materializer.validate_l15_candidate_capture_files(
                self.capture_files, expected_source_records=self.expected_source_records
            )
        self.assertEqual(6, proof["complete_file_count"])
        self.assertEqual(
            self.attempt_bytes, self.capture_files["qualification_attempt.json"]
        )
        self.assertEqual(
            self.execution.stdout, self.capture_files["qualification_stdout.log"]
        )
        self.assertEqual(
            self.execution.stderr, self.capture_files["qualification_stderr.log"]
        )
        self.assertEqual(
            self.raw_candidate_json, self.capture_files["implementation_audit.json"]
        )
        attempt = rollup.packet.parse_json(self.attempt_bytes.decode("utf-8"))
        completion = rollup.packet.parse_json(
            self.capture_files["qualification_completion.json"].decode("utf-8")
        )
        self.assertLessEqual(
            attempt["prepared_at_unix_ns"], self.cli_started_at_unix_ns
        )
        self.assertGreaterEqual(
            completion["completed_at_unix_ns"], self.cli_completed_at_unix_ns
        )
        self.assertTrue(
            rollup.packet.same(
                attempt["source_inputs"],
                self.pre_execution_source_records["qualification_inputs"],
            )
        )
        self.assertTrue(
            rollup.packet.same(
                attempt["source_inputs"],
                self.expected_source_records["qualification_inputs"],
            )
        )
        self.assertEqual(
            "sporespore_qsdk_r10f_l15_development_capture_reader_v1",
            proof["schema_version"],
        )
        for value in (attempt, completion, proof):
            for flag in (
                "official_source_origin_authenticated",
                "official_qualification_passed",
                "qualification_or_physical_identity_created",
                "physical_execution_authorized",
            ):
                self.assertIs(value[flag], False)
        self.assertTrue(
            rollup.packet.same(
                proof["prepared_context_snapshot"],
                self.candidate["zero_world_receipt"]["l15_prepared_collection_context"],
            )
        )

    def test_capture_missing_corrupt_and_coherently_rehashed_records_refuse(self):
        count = 0

        def refuse(files):
            nonlocal count
            with self.assertRaises(materializer.MaterializationFailure):
                materializer.validate_l15_candidate_capture_files(
                    files, expected_source_records=self.expected_source_records
                )
            count += 1

        def rebound(name, raw):
            files = {**self.capture_files, name: raw}
            if name != "qualification_completion.json":
                completion = rollup.packet.parse_json(
                    files["qualification_completion.json"].decode("utf-8")
                )
                completion["files"] = [
                    materializer.l15_capture_file_binding(path, files[path])
                    for path in materializer.L15_CAPTURE_FILES[:5]
                ]
                files["qualification_completion.json"] = materializer.l15_capture_json(
                    completion
                )
            return files

        with mock.patch.object(
            subprocess, "run", side_effect=AssertionError("NO_PROCESS")
        ), mock.patch.object(
            implementation,
            "audit_l15_qualification_source_records",
            side_effect=AssertionError("NO_SOURCE_REOPEN"),
        ):
            for name in materializer.L15_CAPTURE_FILES:
                refuse(
                    {
                        key: value
                        for key, value in self.capture_files.items()
                        if key != name
                    }
                )
                refuse({**self.capture_files, name: None})
                refuse(
                    {**self.capture_files, name: self.capture_files[name] + b"damaged"}
                )
                refuse(rebound(name, b"\xff"))
            for extra in (
                "qualification_failure.json",
                "unexpected.json",
                "nested/file.json",
            ):
                refuse({**self.capture_files, extra: b"{}"})
            for name in (
                "qualification_attempt.json",
                "qualification_completion.json",
                "runtime_identity.json",
            ):
                original = rollup.packet.parse_json(
                    self.capture_files[name].decode("utf-8")
                )
                for key, value in original.items():
                    changed = copy.deepcopy(original)
                    del changed[key]
                    refuse(rebound(name, materializer.l15_capture_json(changed)))
                    replacements = [None]
                    if type(value) is int:
                        replacements += [False, float(value), str(value)]
                    elif type(value) is bool:
                        replacements += [int(value), not value]
                    elif type(value) is str:
                        replacements += [value + "_changed"]
                    elif type(value) is dict:
                        replacements += [{}, {**value, "unexpected": True}]
                    elif type(value) is list:
                        replacements += [[], list(reversed(value))]
                    for replacement in replacements:
                        changed = copy.deepcopy(original)
                        changed[key] = replacement
                        with self.subTest(file=name, field=key):
                            refuse(
                                rebound(name, materializer.l15_capture_json(changed))
                            )
                raw = self.capture_files[name]
                for prefix in (b'{"schema_version":"duplicate",', b'{"extra":NaN,'):
                    refuse(rebound(name, prefix + raw[1:]))
            # Even a semantically equal reserialization is not the original
            # implementation JSON carried by the captured stdout marker.
            refuse(
                rebound("implementation_audit.json", self.raw_candidate_json + b"\n")
            )
            completion = rollup.packet.parse_json(
                self.capture_files["qualification_completion.json"].decode("utf-8")
            )
            completion["completed_at_unix_ns"] = completion["prepared_at_unix_ns"] - 1
            refuse(
                rebound(
                    "qualification_completion.json",
                    materializer.l15_capture_json(completion),
                )
            )
            for index in range(5):
                for key, replacement in (
                    ("path", "wrong.json"),
                    ("byte_length", False),
                    ("raw_sha256", "sha256:" + "0" * 64),
                ):
                    for remove in (False, True):
                        completion = rollup.packet.parse_json(
                            self.capture_files["qualification_completion.json"].decode(
                                "utf-8"
                            )
                        )
                        if remove:
                            del completion["files"][index][key]
                        else:
                            completion["files"][index][key] = replacement
                        refuse(
                            rebound(
                                "qualification_completion.json",
                                materializer.l15_capture_json(completion),
                            )
                        )
            attempt = rollup.packet.parse_json(self.attempt_bytes.decode("utf-8"))
            attempt["source_inputs"]["qualified_source_bindings"][0]["raw_sha256"] = (
                "sha256:" + "0" * 64
            )
            refuse(
                rebound(
                    "qualification_attempt.json", materializer.l15_capture_json(attempt)
                )
            )
        print("L15_COMPLETE_CAPTURE_FILE_CORRUPTIONS=" + str(count), flush=True)

    def test_capture_actual_directory_reader_reopens_sources_and_refuses_incomplete_io(
        self,
    ):
        root = materializer.l15_candidate_capture_directory(
            self.expected_source_records["qualification_inputs"]
        )
        source_commit = self.expected_source_records["source"]["source_commit"]
        files = dict(self.capture_files)
        symlinks, not_regular = set(), set()
        drift = False
        read_count = 0
        real_read, real_iterdir = Path.read_bytes, Path.iterdir
        real_is_dir, real_is_file, real_is_symlink = (
            Path.is_dir,
            Path.is_file,
            Path.is_symlink,
        )

        def read(path):
            nonlocal read_count
            if path.parent == root and path.name in files:
                read_count += 1
                return files[path.name] + (
                    b"changed" if drift and read_count > 6 else b""
                )
            return real_read(path)

        with mock.patch.object(Path, "read_bytes", read), mock.patch.object(
            Path,
            "iterdir",
            lambda path: (
                iter(root / name for name in files)
                if path == root
                else real_iterdir(path)
            ),
        ), mock.patch.object(
            Path, "is_dir", lambda path: True if path == root else real_is_dir(path)
        ), mock.patch.object(
            Path,
            "is_file",
            lambda path: (
                path.name in files and path.name not in not_regular
                if path.parent == root
                else real_is_file(path)
            ),
        ), mock.patch.object(
            Path,
            "is_symlink",
            lambda path: (
                path in symlinks
                if path == root or path.parent == root
                else real_is_symlink(path)
            ),
        ):
            # Only the exact six-file directory is virtual. Source, historical
            # evidence and all selected runtime-image reads remain actual.
            proof = materializer.read_l15_candidate_capture_directory(
                root, source_commit
            )
            self.assertEqual(6, proof["complete_file_count"])
            self.assertEqual(12, read_count)
            self.assertIs(proof["official_qualification_passed"], False)
            count = 0

            def refuse():
                nonlocal count
                with self.assertRaises(materializer.MaterializationFailure):
                    materializer.read_l15_candidate_capture_directory(
                        root, source_commit
                    )
                count += 1

            # Reuse the complete actual source record only for the IO mutation
            # controls. A damaged directory cannot trigger another native run.
            with mock.patch.object(
                implementation,
                "audit_l15_qualification_source_records",
                return_value=self.expected_source_records,
            ), mock.patch.object(
                subprocess,
                "run",
                side_effect=AssertionError("NO_PROCESS_IN_IO_CONTROL"),
            ):
                for name in materializer.L15_CAPTURE_FILES:
                    files = {
                        key: value
                        for key, value in self.capture_files.items()
                        if key != name
                    }
                    refuse()
                for extra in ("qualification_failure.json", "unexpected"):
                    files = {**self.capture_files, extra: b"{}"}
                    refuse()
                files = dict(self.capture_files)
                for path in (
                    root,
                    *(root / name for name in materializer.L15_CAPTURE_FILES),
                ):
                    symlinks = {path}
                    refuse()
                symlinks = set()
                for name in materializer.L15_CAPTURE_FILES:
                    not_regular = {name}
                    refuse()
                not_regular = set()
                drift, read_count = True, 0
                refuse()
        print(
            "L15_ACTUAL_CAPTURE_DIRECTORY_PASS virtual_files=6 io_refusals="
            + str(count)
            + " official=false",
            flush=True,
        )


class QualifiedCheckoutContract(unittest.TestCase):
    """Synthetic Git topology only; these artifacts are not qualified records."""

    def setUp(self):
        import qsdk_r10f_l15_source_binding as binding

        self.binding = binding
        self.source, self.freeze, self.authority = (
            character * 40 for character in "123"
        )
        self.head = self.authority
        self.parents = {self.freeze: self.source, self.authority: self.freeze}
        self.paths = binding.QUALIFIED_GRAPH_PATHS
        self.raw = {
            path: ('{"topology_fixture":' + str(index) + "}\n").encode()
            for index, path in enumerate(self.paths)
        }
        self.entries = {
            path: {
                "mode": "100644",
                "kind": "blob",
                "git_blob_oid": binding.frozen.blob_identity(path, raw)["git_blob_oid"],
            }
            for path, raw in self.raw.items()
        }
        self.status = b""
        self.changes = {
            self.freeze: ["A\t" + self.paths[0]],
            self.authority: ["A\t" + self.paths[1]],
        }
        self.extra_parent = ""
        self.net_changes = None

    def git(self, *args):
        if args == ("rev-parse", "HEAD"):
            return self.head.encode()
        if args == ("branch", "--show-current"):
            return b"main"
        if args == ("status", "--porcelain=v1", "--untracked-files=all"):
            return self.status
        if args[:4] == ("rev-list", "--parents", "-n", "1"):
            return (
                args[-1] + " " + self.parents[args[-1]] + self.extra_parent
            ).encode()
        if args[0] == "diff-tree":
            return "\n".join(self.changes[args[-1]]).encode()
        if args[:3] == ("diff", "--name-only", "--no-renames"):
            return "\n".join(
                self.net_changes
                if self.net_changes is not None
                else sorted(self.paths[: 1 if self.head == self.freeze else 2])
            ).encode()
        raise AssertionError("UNEXPECTED_GIT_READ:" + repr(args))

    def read(self, checkout=None):
        with mock.patch.object(
            self.binding, "git", side_effect=self.git
        ), mock.patch.object(
            self.binding, "committed_source_objects", return_value=self.entries
        ), mock.patch.object(
            self.binding, "read_worktree_source", side_effect=self.raw.__getitem__
        ), mock.patch.object(
            self.binding,
            "qualification_git_attributes",
            side_effect=lambda paths: {
                path: dict(self.binding.QUALIFICATION_GIT_ATTRIBUTES) for path in paths
            },
        ):
            return self.binding.qualified_checkout_context(
                self.source, checkout_commit=checkout
            )

    def test_source_freeze_and_authority_are_distinct_and_never_grant_authority(self):
        self.head = self.source
        self.assertEqual("source", self.read()["phase"])
        for head, phase, count in (
            (self.freeze, "freeze", 1),
            (self.authority, "authority", 2),
        ):
            self.head = head
            result = self.read(head)
            self.assertEqual(phase, result["phase"])
            self.assertEqual(count, len(result["graph_artifacts"]))
            self.assertEqual(self.source, result["source_commit"])
            self.assertNotIn("physical_execution_authorized", result)
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_SOURCE_NOT_HEAD"):
                self.read()

    def test_wrong_head_dirty_merge_unrelated_parent_and_net_changes_refuse(self):
        for offered in (False, "", "4" * 40, self.freeze):
            with self.assertRaisesRegex(ValueError, "QUALIFICATION_CHECKOUT_NOT_HEAD"):
                self.read(offered)
        self.status = b" M source.py\n"
        with self.assertRaisesRegex(ValueError, "GRAPH_CHECKOUT_NOT_CLEAN_MAIN"):
            self.read(self.head)
        self.status = b""
        self.extra_parent = " " + "4" * 40
        with self.assertRaisesRegex(ValueError, "GRAPH_SINGLE_PARENT"):
            self.read(self.head)
        self.extra_parent = ""
        self.parents[self.freeze] = "4" * 40
        with self.assertRaisesRegex(ValueError, "GRAPH_SOURCE_PARENT"):
            self.read(self.head)
        self.parents[self.freeze] = self.source
        self.net_changes = sorted([*self.paths, "docs/README.md"])
        with self.assertRaisesRegex(ValueError, "GRAPH_CHANGED_PATHS"):
            self.read(self.head)

    def test_modified_extra_renamed_and_uncommitted_artifacts_refuse(self):
        for commit, path in (
            (self.freeze, self.paths[0]),
            (self.authority, self.paths[1]),
        ):
            for changes in (
                [],
                ["M\t" + path],
                ["R100\told\t" + path],
                ["A\t" + path, "A\textra"],
                ["A\t" + self.paths[1 if commit == self.freeze else 0]],
            ):
                self.changes[commit] = changes
                with self.assertRaisesRegex(ValueError, "GRAPH_SINGLE_NEW_PATH"):
                    self.read(self.head)
            self.changes[commit] = ["A\t" + path]
            original = self.raw[path]
            self.raw[path] += b"changed"
            with self.assertRaisesRegex(ValueError, "GRAPH_ARTIFACT_NOT_COMMITTED"):
                self.read(self.head)
            self.raw[path] = original
            self.entries[path]["mode"] = "120000"
            with self.assertRaisesRegex(ValueError, "GRAPH_REGULAR_ARTIFACT"):
                self.read(self.head)
            self.entries[path]["mode"] = "100644"

    def test_graph_mode_cannot_be_used_with_development_source_checks(self):
        with self.assertRaisesRegex(ValueError, "GRAPH_REQUIRES_COMMITTED_SOURCE"):
            self.binding.bind_qualification_inputs(
                self.source, checkout_commit=self.authority
            )


class QualificationOriginContract(unittest.TestCase):
    """Pure origin comparisons over complete, actually read input populations.

    Clean/committed labels below are explicitly synthetic controls, not a live
    official qualification. Only reopen_l15_official_origin may authenticate
    those labels in production, using Git and the actual wrapper parent.
    """

    @classmethod
    def setUpClass(cls):
        import qsdk_r10f_l15_source_binding as binding

        source = implementation.inspect_source(official_qualification=False)
        inputs = binding.bind_qualification_inputs(source["source_commit"])
        cls.actual_inputs = inputs
        cls.records = {
            "source": copy.deepcopy(source),
            "qualification_inputs": copy.deepcopy(inputs),
        }
        cls.records["source"].update(source_clean=True, source_origin_main_equal=True)
        fixture_inputs = cls.records["qualification_inputs"]
        fixture_inputs["all_source_git_projections_equal_commit"] = True
        fixture_inputs["changed_or_uncommitted_source_paths"] = []
        official_inputs = copy.deepcopy(fixture_inputs)
        official_inputs["committed_source_required"] = True
        official_inputs["complete_dependency_receipt"]["tracked_source_required"] = True
        cls.origin = {
            "source": {
                **cls.records["source"],
                "source_live_main_equal": True,
                "source_live_main_commit": source["source_commit"],
                "official_qualification": True,
            },
            "qualification_inputs": official_inputs,
            "operation_lock": {
                "schema_version": "sporespore_locomotion_operation_lock_receipt_v1",
                "acquired": True,
                "role": "qualification",
                "mutex_name": "Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1",
                "created_new": True,
                "abandoned_owner_recovered": False,
                "owner_process_id": 1,
                "owner_session_id": 0,
                "acquired_utc": "2026-09-07T00:00:00+00:00",
                "test_only": False,
                "physical_acceptance_authority": False,
            },
        }

    def test_complete_mode_projection_preserves_every_input_and_candidate_flag(self):
        original = copy.deepcopy(self.records)
        materializer.validate_l15_official_origin(
            self.origin, source_records=self.records
        )
        self.assertEqual(original, self.records)
        self.assertEqual(
            240, self.origin["qualification_inputs"]["qualified_source_path_count"]
        )
        self.assertIs(self.records["source"]["official_qualification"], False)
        self.assertIs(
            self.records["qualification_inputs"]["committed_source_required"], False
        )
        self.assertEqual(
            self.actual_inputs["qualified_source_bindings"],
            self.origin["qualification_inputs"]["qualified_source_bindings"],
        )

    def test_missing_changed_or_wrong_kind_source_and_lock_fields_refuse(self):
        count = 0
        for group in self.origin:
            for key, value in self.origin[group].items():
                for replacement in (
                    None,
                    str(value),
                    not value if type(value) is bool else False,
                ):
                    if rollup.packet.same(replacement, value):
                        continue
                    if (
                        group == "operation_lock"
                        and key == "created_new"
                        and type(replacement) is bool
                    ):
                        # Acquiring an existing named mutex is also valid.
                        continue
                    changed = copy.deepcopy(self.origin)
                    changed[group][key] = replacement
                    with self.subTest(group=group, key=key), self.assertRaises(
                        (
                            ValueError,
                            TypeError,
                            KeyError,
                            materializer.MaterializationFailure,
                        )
                    ):
                        materializer.validate_l15_official_origin(
                            changed, source_records=self.records
                        )
                    count += 1
                changed = copy.deepcopy(self.origin)
                del changed[group][key]
                with self.assertRaises(
                    (ValueError, KeyError, materializer.MaterializationFailure)
                ):
                    materializer.validate_l15_official_origin(
                        changed, source_records=self.records
                    )
                count += 1
        print(
            f"L15_OFFICIAL_ORIGIN_PURE_CONTROLS={count} synthetic_origin=true",
            flush=True,
        )

    def test_source_runtime_and_dependency_changes_cannot_hide_behind_mode_projection(
        self,
    ):
        for path in (
            ("qualification_inputs", "qualified_source_bindings", 0, "raw_sha256"),
            ("qualification_inputs", "runtime_binding", "schema_version"),
            ("qualification_inputs", "dependency_manifest", "raw_sha256"),
        ):
            changed = copy.deepcopy(self.origin)
            target = changed
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = "damaged"
            with self.assertRaises(materializer.MaterializationFailure):
                materializer.validate_l15_official_origin(
                    changed, source_records=self.records
                )

    def test_completed_origin_preserves_original_lock_without_requiring_dead_parent(
        self,
    ):
        import qsdk_r10f_l15_source_binding as binding

        source = self.origin["source"]
        live = {
            "commit": source["source_commit"],
            "tree": source["source_tree"],
            "branch": "main",
            "live_main_commit": source["source_commit"],
        }
        with mock.patch.object(
            materializer, "live_source_identity", return_value=live
        ) as live_read, mock.patch.object(
            binding,
            "bind_qualification_inputs",
            return_value=self.origin["qualification_inputs"],
        ) as inputs_read, mock.patch.object(
            implementation,
            "inspect_source",
            side_effect=AssertionError("NO_LIVE_QUALIFICATION_OWNER_REQUIRED"),
        ), mock.patch.object(
            os, "getppid", side_effect=AssertionError("NO_HISTORICAL_PID_REUSE")
        ):
            actual = materializer.reopen_l15_official_origin(
                self.records, retained_operation_lock=self.origin["operation_lock"]
            )
        self.assertEqual(self.origin, actual)
        self.assertEqual(2, live_read.call_count)
        inputs_read.assert_called_once_with(
            source["source_commit"], require_committed_source=True
        )

    def test_prepare_and_complete_still_require_the_actual_live_wrapper_parent(self):
        import qsdk_r10f_l15_source_binding as binding

        with mock.patch.object(
            implementation, "inspect_source", return_value=self.origin["source"]
        ), mock.patch.object(
            binding,
            "bind_qualification_inputs",
            return_value=self.origin["qualification_inputs"],
        ), mock.patch.dict(
            os.environ,
            {
                "SPORESPORE_QSDK_R10F_QUALIFICATION_OWNER_JSON": json.dumps(
                    self.origin["operation_lock"]
                )
            },
        ), mock.patch.object(
            os, "getppid", return_value=999
        ):
            with self.assertRaisesRegex(
                materializer.MaterializationFailure, "L15_OFFICIAL_WRAPPER_PARENT"
            ):
                materializer.reopen_l15_official_origin(self.records)


class QualificationLifecycleTransport(unittest.TestCase):
    """Exercise the actual PS byte-capture function without a native SDK call.

    These short-lived files contain artificial binary/process fixtures only,
    never qualification evidence or a candidate result.
    """

    def invoke(self, root, code, *, timeout=10):
        source = r"""
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:RepoRoot = (Get-Location).Path
$script:PhysicalEnvironmentNames = @('SPORESPORE_QSDK_R10F_EXECUTE_PHYSICAL')
$script:QualificationLockEnvironment = 'SPORESPORE_QSDK_R10F_QUALIFICATION_LOCK_HELD'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $script:RepoRoot 'sdk/qsdk_r10f_zero_world_qualification.ps1'),
    [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'WRAPPER_PARSE' }
foreach ($name in @('Assert-R10fQualification', 'Invoke-L15QualificationAudit')) {
    $nodes = @($ast.FindAll({param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -ceq $name
    }, $false))
    if ($nodes.Count -ne 1) { throw 'FUNCTION_POPULATION' }
    Invoke-Expression $nodes[0].Extent.Text
}
$request = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
$result = @(Invoke-L15QualificationAudit -OutputRoot $request.root `
    -FilePath $request.python -Arguments @('-B', '-c', $request.code) `
    -TimeoutSeconds $request.timeout)
if ($result.Count -ne 1 -or $result[0] -isnot [System.Collections.IDictionary]) {
    throw 'QUALIFICATION_TYPED_RETURN_POPULATION'
}
$result[0] | ConvertTo-Json -Compress
"""
        return subprocess.run(
            [
                rollup.runtime.IMAGES["powershell_host"]["path"],
                "-NoProfile",
                "-Command",
                source,
            ],
            input=json.dumps(
                {
                    "root": str(root),
                    "python": sys.executable,
                    "code": code,
                    "timeout": timeout,
                }
            ).encode(),
            cwd=ROOT,
            capture_output=True,
            timeout=30,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )

    def test_original_binary_streams_and_single_typed_return(self):
        with tempfile.TemporaryDirectory(prefix="l15-synthetic-pipes-") as directory:
            root = Path(directory)
            raw = bytes(range(256)) * 1024
            result = self.invoke(
                root,
                "import sys; b=bytes(range(256))*1024; "
                "sys.stdout.buffer.write(b); sys.stderr.buffer.write(b[::-1])",
            )
            self.assertEqual(
                0, result.returncode, result.stderr.decode(errors="replace")
            )
            self.assertEqual(
                {"completed": True, "timed_out": False, "exit_code": 0},
                json.loads(result.stdout),
            )
            self.assertEqual(raw, (root / "qualification_stdout.log").read_bytes())
            self.assertEqual(
                raw[::-1], (root / "qualification_stderr.log").read_bytes()
            )
            refused = self.invoke(root, "raise RuntimeError('MUST_NOT_EXECUTE')")
            self.assertNotEqual(0, refused.returncode)
            self.assertEqual(raw, (root / "qualification_stdout.log").read_bytes())
            self.assertEqual(
                raw[::-1], (root / "qualification_stderr.log").read_bytes()
            )

    def test_nonzero_exit_preserves_both_original_streams(self):
        with tempfile.TemporaryDirectory(prefix="l15-synthetic-failure-") as directory:
            root = Path(directory)
            result = self.invoke(
                root,
                "import sys; sys.stdout.buffer.write(b'partial\\x00\\xff'); "
                "sys.stderr.buffer.write(b'failure\\r\\n'); sys.exit(7)",
            )
            self.assertEqual(
                0, result.returncode, result.stderr.decode(errors="replace")
            )
            self.assertEqual(7, json.loads(result.stdout)["exit_code"])
            self.assertEqual(
                b"partial\x00\xff", (root / "qualification_stdout.log").read_bytes()
            )
            self.assertEqual(
                b"failure\r\n", (root / "qualification_stderr.log").read_bytes()
            )

    def test_timeout_joins_owned_child_and_retains_partial_bytes(self):
        with tempfile.TemporaryDirectory(prefix="l15-synthetic-timeout-") as directory:
            root = Path(directory)
            result = self.invoke(
                root,
                "import os,time; print(os.getpid(), flush=True); time.sleep(20)",
                timeout=1,
            )
            self.assertEqual(
                0, result.returncode, result.stderr.decode(errors="replace")
            )
            receipt = json.loads(result.stdout)
            self.assertIs(receipt["completed"], False)
            self.assertIs(receipt["timed_out"], True)
            pid = int((root / "qualification_stdout.log").read_bytes())
            joined = subprocess.run(
                [
                    rollup.runtime.IMAGES["powershell_host"]["path"],
                    "-NoProfile",
                    "-Command",
                    f"if (Get-Process -Id {pid} -ErrorAction SilentlyContinue) {{ exit 1 }}",
                ],
                cwd=ROOT,
                capture_output=True,
                timeout=10,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            self.assertEqual(0, joined.returncode)

    def test_complete_source_producer_under_actual_outer_qualification_lock(self):
        code = (
            "import json,sys; sys.path.insert(0,'sdk/conformance'); "
            "import qsdk_r10f_zero_world_implementation as i; "
            "r=i.audit_l15_qualification_source_records(i.DEFAULT_GODOT, "
            "i.inspect_source(official_qualification=False)['source_commit']); "
            "print(json.dumps({'record_count':len(r),'legacy':r['legacy_supervisor_regression']}))"
        )
        script = r"""
$ErrorActionPreference = 'Stop'
$request = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
. ./sdk/locomotion_operation_lock.ps1
$lock = Enter-SporeSporeLocomotionOperationLock -Role qualification -TimeoutMilliseconds 0
if (-not $lock.acquired -or $lock.abandoned_owner_recovered) { throw 'LOCK_NOT_ACQUIRED' }
try {
    $env:SPORESPORE_QSDK_R10F_QUALIFICATION_LOCK_HELD = '1'
    & $request.python -B -c $request.code
    $childExit = $LASTEXITCODE
} finally {
    Remove-Item Env:SPORESPORE_QSDK_R10F_QUALIFICATION_LOCK_HELD -ErrorAction SilentlyContinue
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
}
exit $childExit
"""
        result = subprocess.run(
            [
                rollup.runtime.IMAGES["powershell_host"]["path"],
                "-NoProfile",
                "-Command",
                script,
            ],
            input=json.dumps({"python": sys.executable, "code": code}).encode(),
            cwd=ROOT,
            capture_output=True,
            timeout=300,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        self.assertEqual(0, result.returncode, result.stderr.decode(errors="replace"))
        self.assertEqual(
            {
                "record_count": 14,
                "legacy": {
                    "powershell_parse_passed": True,
                    "preflight_process_skipped_under_outer_qualification_lock": True,
                    "physical_refusal_process_skipped_under_outer_qualification_lock": True,
                    "authority_graph_path_projection_exercised_by_static_zero_world_test": True,
                },
            },
            json.loads(result.stdout),
        )


class _GraphWriterControls:
    def test_complete_actual_candidate_feeds_v16_constructors_without_allocating(self):
        # Only the official-origin labels and future graph are synthetic here.
        # Every native/component result and all six input byte strings come from
        # this class's one actual complete cold candidate. This is not a freeze.
        source = self.expected_source_records["source"]["source_commit"]
        directory = materializer.l15_official_qualification_directory(source)
        proof = materializer.validate_l15_candidate_capture_files(
            self.capture_files, expected_source_records=self.expected_source_records
        )
        proof.update(materializer.l15_capture_header("reader", official=True))
        proof.update(source_commit=source, output_root=directory.as_posix())
        checkpoint = materializer.l15_checkpoint_from_reader(proof, source)
        original_identity = materializer.file_identity

        def identity(path, **kwargs):
            if path.parent == directory and path.name in self.capture_files:
                raw = self.capture_files[path.name]
                return {"path": path.as_posix(), "byte_length": len(raw),
                        "raw_sha256": materializer.sha256_bytes(raw)}
            return original_identity(path, **kwargs)

        with mock.patch.object(materializer, "read_l15_capture_population", return_value=self.capture_files), \
                mock.patch.object(materializer, "file_identity", side_effect=identity), \
                mock.patch.object(materializer, "write_new_json", side_effect=AssertionError("NO_GRAPH_WRITE")):
            materials = materializer.l15_stage_materials(source, checkpoint)
            stage = materializer.build_l15_stage(source, materials)
            materializer.validate_l15_stage(stage, source, materials)
            self.assertEqual(240, stage["qualified_source_path_count"])
            self.assertEqual("QSDK-R10F-L15", stage["repair_id"])
            self.assertEqual("QSDK-R10F-L14", stage["consumed_predecessor_physical_closure"]["document"]["repair_id"])
            self.assertEqual(self.candidate["l14_component_qualification"], stage["l14_component_qualification"])
            self.assertEqual(checkpoint, stage["l15_qualification_checkpoint"])
            stage_sha = materializer.sha256_bytes(json.dumps(stage, sort_keys=True).encode())
            authority = materializer.build_l15_authority("a" * 40, stage_sha, stage)
            materializer.validate_l15_authority(authority, "a" * 40, stage_sha, stage)
            self.assertEqual(materializer.L15_STAGE_RELATIVE, authority["zero_world_qualification_closure_path"])
            self.assertEqual(materializer.L15_PREDECESSOR_SHA256, authority["consumed_predecessor_physical_closure_sha256"])
            for record, validate in (
                (stage, lambda value: materializer.validate_l15_stage(value, source, materials)),
                (authority, lambda value: materializer.validate_l15_authority(value, "a" * 40, stage_sha, stage)),
            ):
                for key in record:
                    damaged = copy.deepcopy(record)
                    del damaged[key]
                    with self.subTest(schema=record["schema_version"], missing=key), self.assertRaises(materializer.MaterializationFailure):
                        validate(damaged)
            self.assertFalse(stage["physical_execution_authorized_by_freeze"])
            self.assertFalse(authority["physical_acceptance_authority"])
            self.assertFalse(authority["same_identity_rerun_permitted"])


class ProductionFamilySelection(unittest.TestCase):
    def test_legacy_component_process_preserves_non_ascii_failure_diagnostic(self):
        # The child is a Python diagnostic only. No native component or identity runs.
        environment = {**os.environ, "PYTHONIOENCODING": "cp1252"}
        with self.assertRaisesRegex(ValueError, "DECLARED_DIAGNOSTIC:PROCESS:.*") as caught:
            materializer.l14_components.run(
                [sys.executable, "-B", "-c", "import sys; sys.stderr.write(chr(0x2026)); sys.exit(1)"],
                "DECLARED_DIAGNOSTIC", environment=environment, timeout=15,
            )
        self.assertEqual("DECLARED_DIAGNOSTIC:PROCESS:" + chr(0x2026), str(caught.exception))
        self.assertEqual("cp1252", environment["PYTHONIOENCODING"])

    def test_actual_powershell_python_and_worker_select_same_l15_work_and_paths(self):
        script = r"""
$ErrorActionPreference = 'Stop'
$script:RepoRoot = [Environment]::CurrentDirectory
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $script:RepoRoot 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'SUPERVISOR_PARSE' }
$nodes = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Select-L15ProductionFamily'
}, $true))
if ($nodes.Count -ne 1) { throw 'FAMILY_SELECTOR_COUNT' }
. ([scriptblock]::Create($nodes[0].Extent.Text))
$emitted = @(Select-L15ProductionFamily)
if ($emitted.Count -ne 0) { throw 'FAMILY_SELECTOR_UNEXPECTED_PIPELINE_OUTPUT' }
[Console]::Out.Write((@{
    repair_id=$script:RepairId; work_id=$script:WorkId
    pair_repair_id=$script:QsdkR10fL9RepairId; pair_work_id=$script:QsdkR10fL9WorkId
    authority=$script:ExpectedAuthorityRelativePath; stage=$script:ExpectedFreezeRelativePath
    manifest=[IO.Path]::GetFullPath($script:ManifestPath)
} | ConvertTo-Json -Compress))
"""
        result = subprocess.run(
            [rollup.runtime.IMAGES["powershell_host"]["path"], "-NoProfile", "-NonInteractive", "-Command", script],
            cwd=ROOT, capture_output=True, timeout=30, creationflags=subprocess.CREATE_NO_WINDOW,
        )
        self.assertEqual(0, result.returncode, result.stderr.decode(errors="replace"))
        self.assertEqual(b"", result.stderr)
        value = rollup.packet.parse_json(result.stdout.decode("utf-8"))
        import qsdk_r10f_physical_closure as closer

        with mock.patch.dict(closer.__dict__):
            closer.select_l15_production_family()
            self.assertEqual(closer.REPAIR_ID, value["repair_id"])
            self.assertEqual(closer.work_id_for_family(), value["work_id"])
            self.assertEqual(value["repair_id"], value["pair_repair_id"])
            self.assertEqual(value["work_id"], value["pair_work_id"])
            self.assertEqual(closer.AUTHORITY_PATH.relative_to(ROOT).as_posix(), value["authority"])
            self.assertEqual(closer.STAGE_PATH.relative_to(ROOT).as_posix(), value["stage"])
            self.assertEqual(closer.MANIFEST_PATH.resolve(), Path(value["manifest"]).resolve())
            self.assertEqual(materializer.L15_PREDECESSOR_SHA256, closer.EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256)
            worker = (ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd").read_text()
            self.assertIn('const L15_WORK_ID := "' + value["work_id"] + '"', worker)
            self.assertIn('configured_work_id not in [WORK_ID, L15_WORK_ID]', worker)
        self.assertEqual("QSDK-R10F-L14", closer.REPAIR_ID)

    def test_real_l15_supervisor_refuses_before_identity_without_explicit_physical_switch(self):
        result = subprocess.run(
            [rollup.runtime.IMAGES["powershell_host"]["path"], "-NoProfile", "-NonInteractive", "-File",
             str(ROOT / "sdk/run_qsdk_r10f_continuous_passive_recovery.ps1"), "-L15", "-Mode", "Physical"],
            cwd=ROOT, capture_output=True, timeout=30, creationflags=subprocess.CREATE_NO_WINDOW,
        )
        self.assertEqual(1, result.returncode)
        self.assertEqual(b"", result.stderr)
        marker = "QSDK_R10F_SUPERVISOR_REFUSAL "
        lines = result.stdout.decode("utf-8").splitlines()
        self.assertEqual(1, len(lines))
        self.assertTrue(lines[0].startswith(marker))
        receipt = rollup.packet.parse_json(lines[0][len(marker):])
        self.assertEqual("QSDK-R10F-L15", receipt["repair_id"])
        self.assertEqual("PHYSICAL_MODE_REQUIRES_RUNPHYSICAL", receipt["failure_code"])
        self.assertFalse(receipt["physical_attempt_identity_consumed"])
        self.assertEqual(0, receipt["solver_step_count"])
        self.assertEqual(0, receipt["world_build_count"])


class ComponentRollup(
    _GraphWriterControls,
    _CaptureControls,
    _OutputControls,
    _CandidateControls,
    _ReceiptControls,
    unittest.TestCase,
):
    @classmethod
    def setUpClass(cls):
        cls.sources = rollup.source_bindings()
        godot = Path(rollup.runtime.IMAGES["godot_console"]["path"])
        cls.pre_execution_source_records = (
            implementation.audit_l15_qualification_source_records(
                godot,
                implementation.inspect_source(official_qualification=False)[
                    "source_commit"
                ],
            )
        )
        cls.attempt_bytes = materializer.prepare_l15_candidate_capture(
            source_records=cls.pre_execution_source_records
        )
        cls.cli_started_at_unix_ns = time.time_ns()
        cls.execution = subprocess.run(
            [
                sys.executable,
                "-B",
                str(ROOT / "sdk/conformance/qsdk_r10f_zero_world_implementation.py"),
                "--godot",
                str(godot),
                "--l15-qualification-candidate",
            ],
            cwd=ROOT,
            capture_output=True,
            timeout=3600,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        cls.cli_completed_at_unix_ns = time.time_ns()
        if cls.execution.returncode != 0:
            raise AssertionError(
                "L15_ACTUAL_CLI_FAILED:"
                + cls.execution.stderr.decode("utf-8", errors="replace")[-6000:]
            )
        cls.expected_source_records = (
            implementation.audit_l15_qualification_source_records(
                godot,
                implementation.inspect_source(official_qualification=False)[
                    "source_commit"
                ],
            )
        )
        cls.candidate, cls.raw_candidate_json = (
            materializer.validate_l15_qualification_candidate_output(
                cls.execution.stdout,
                cls.execution.stderr,
                cls.execution.returncode,
                expected_source_records=cls.expected_source_records,
            )
        )
        cls.receipt = cls.candidate["l15_component_qualification"]
        cls.capture_files = materializer.complete_l15_candidate_capture(
            cls.attempt_bytes,
            cls.execution.stdout,
            cls.execution.stderr,
            cls.execution.returncode,
            expected_source_records=cls.expected_source_records,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
