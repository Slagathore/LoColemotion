"""Complete existing native zero-world gate with a source-context capture.

Both positive runs execute the actual gate serially. Reader corruptions reuse
their complete captured process output; only process execution and image reopening
are explicitly replaced in those negative controls. No qualification is allocated.
"""

import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_zero_world_implementation as implementation
import qsdk_r10f_l15_collection_context as context
import qsdk_r10f_physical_closure as closer
import qsdk_r10f_authority_materializer as materializer

FIELD = "l15_prepared_collection_context"


class ProcessUtf8Boundary(unittest.TestCase):
    def test_strict_process_rejects_invalid_bytes_without_replacement(self):
        command = (
            sys.executable,
            "-B",
            "-c",
            "import sys;sys.stdout.buffer.write(b'bad\\xff')",
        )
        legacy = implementation.run_process(command, timeout_seconds=10)
        self.assertEqual("bad\ufffd", legacy.stdout)
        with self.assertRaises(UnicodeDecodeError):
            implementation.checked_process(
                command, "STRICT_UTF8", timeout_seconds=10, strict_utf8=True
            )
        line = implementation.checked_process(
            (
                sys.executable,
                "-B",
                "-c",
                "import sys;sys.stdout.buffer.write(b'line\\r\\n')",
            ),
            "STRICT_LINES",
            timeout_seconds=10,
            strict_utf8=True,
        )
        self.assertEqual("line\r\n", line.stdout)
        stderr_command = (
            sys.executable,
            "-B",
            "-c",
            "import sys;sys.stderr.buffer.write(b'bad\\xff')",
        )
        with self.assertRaises(UnicodeDecodeError):
            implementation.checked_process(
                stderr_command, "STRICT_STDERR", timeout_seconds=10, strict_utf8=True
            )
        for invalid in (None, 0, 1, "true"):
            with mock.patch.object(implementation.subprocess, "run") as process:
                with self.assertRaisesRegex(implementation.AuditFailure, "MODE_KIND"):
                    implementation.run_process(
                        command, timeout_seconds=10, strict_utf8=invalid
                    )
                process.assert_not_called()

    def test_only_explicit_l15_gate_selects_strict_transport(self):
        def stop_at_gate(_arguments, label, **kwargs):
            if label == "WORKER_PARSE":
                self.assertIs(kwargs["strict_utf8"], self.expected_mode)
                return subprocess.CompletedProcess(
                    [str(argument) for argument in _arguments], 0, "", ""
                )
            self.assertEqual("ZERO_WORLD", label)
            self.assertIs(kwargs["strict_utf8"], self.expected_mode)
            raise RuntimeError("TEST_BOUNDARY_BEFORE_GATE_PROCESS")

        for mode in (False, True):
            self.expected_mode = mode
            with mock.patch.object(
                implementation, "checked_process", side_effect=stop_at_gate
            ), mock.patch.object(
                implementation.l14_runtime,
                "bind_runtime",
                return_value=implementation.l14_runtime.expected_binding(),
            ):
                with self.assertRaisesRegex(RuntimeError, "TEST_BOUNDARY"):
                    implementation.audit_godot(
                        implementation.DEFAULT_GODOT, require_l15_context=mode
                    )


class CompleteGateContext(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.godot = implementation.DEFAULT_GODOT
        implementation.l14_runtime.bind_runtime(cls.godot)
        cls.outputs = {}
        actual = implementation.checked_process

        def record(arguments, label, **kwargs):
            result = actual(arguments, label, **kwargs)
            cls.outputs[label] = result
            return result

        # Use the actual gate, not the smaller context fixture. Legacy runs
        # first; each native process completes before the next one is started.
        cls.legacy, cls.legacy_worker_parse = implementation.audit_godot(cls.godot)
        with mock.patch.object(implementation, "checked_process", side_effect=record):
            cls.receipt, cls.worker_parse = implementation.audit_godot(
                cls.godot, require_l15_context=True
            )

    def consume_output(self, stdout, stderr=""):
        def captured(_arguments, label, **_kwargs):
            if label == "WORKER_PARSE":
                return self.outputs[label]
            self.assertEqual("ZERO_WORLD", label)
            original = self.outputs[label]
            return subprocess.CompletedProcess(original.args, 0, stdout, stderr)

        with mock.patch.object(
            implementation, "checked_process", side_effect=captured
        ), mock.patch.object(
            implementation.l14_runtime,
            "bind_runtime",
            return_value=implementation.l14_runtime.expected_binding(),
        ):
            return implementation.audit_godot(self.godot, require_l15_context=True)

    def consume(self, receipt):
        text = json.dumps(receipt, sort_keys=True, separators=(",", ":"))
        return self.consume_output(implementation.ZERO_WORLD_MARKER + text + "\n")

    def test_complete_legacy_population_is_unchanged_and_capture_is_independent(self):
        legacy_projection = copy.deepcopy(self.receipt)
        snapshot = legacy_projection.pop(FIELD)
        self.assertNotIn(FIELD, self.legacy)
        self.assertTrue(context.packet.same(legacy_projection, self.legacy))
        self.assertEqual(24, self.receipt["positive_case_count"])
        self.assertEqual(237, self.receipt["forced_failure_case_count"])
        raw = context.packet.verify_bytes(snapshot).decode("utf-8")
        proof = context.validate_capture(
            raw,
            expected_raw_binding={
                key: snapshot[key] for key in ("utf8_byte_length", "raw_sha256")
            },
            canonical_sha256=closer.canonical_sha256_v1,
        )
        self.assertIs(proof["ok"], True)
        for flag in (
            "official_context_qualification",
            "physical_worker_context_installed",
            "source_origin_authenticated_by_this_reader",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(proof[flag], False)
        for name in context.ZERO_COUNTERS:
            self.assertIs(type(proof[name]), int)
            self.assertEqual(0, proof[name])

    def test_actual_complete_emitted_output_is_accepted_by_same_reader(self):
        original = self.outputs["ZERO_WORLD"]
        receipt, worker = self.consume_output(original.stdout, original.stderr)
        self.assertTrue(context.packet.same(receipt, self.receipt))
        self.assertTrue(context.packet.same(worker, self.worker_parse))

    def test_actual_worker_parse_output_reaches_materializer_without_any_process(self):
        original = self.outputs["WORKER_PARSE"]
        output = self.worker_parse["l15_process_output"]
        self.assertEqual(
            {
                "worker_parse_exit_code",
                "worker_parse_stdout_sha256",
                "worker_parse_stderr_sha256",
            },
            self.legacy_worker_parse.keys(),
        )
        self.assertEqual(
            [str(argument) for argument in original.args], output["arguments"]
        )
        self.assertIn("--check-only", output["arguments"])
        self.assertEqual(implementation.WORKER_SCRIPT, output["arguments"][-1])
        self.assertEqual(ROOT.as_posix(), output["working_directory"])
        for stream in ("stdout", "stderr"):
            text = getattr(original, stream)
            self.assertEqual(
                text.encode("utf-8"), context.packet.verify_bytes(output[stream])
            )
            self.assertEqual(text, output[stream]["utf8_text"])
            self.assertTrue(
                context.packet.same(
                    {
                        key: output[stream][key]
                        for key in ("utf8_byte_length", "raw_sha256")
                    },
                    context.raw_binding(text),
                )
            )
            self.assertEqual(
                output[stream]["raw_sha256"],
                self.worker_parse["worker_parse_" + stream + "_sha256"],
            )
        with mock.patch.object(
            implementation,
            "checked_process",
            side_effect=AssertionError("NO_ENGINE_PROCESS"),
        ), mock.patch.object(
            implementation.l14_runtime,
            "bind_runtime",
            side_effect=AssertionError("NO_IMAGE_REOPEN"),
        ), mock.patch.object(
            implementation.subprocess,
            "run",
            side_effect=AssertionError("NO_SUBPROCESS"),
        ):
            self.assertIsNone(
                materializer.validate_l15_qualification_worker_parse(self.worker_parse)
            )
            self.assertIsNone(
                implementation.validate_l15_worker_parse_receipt(self.worker_parse)
            )
        for name in (
            "worker_runtime_entrypoint_executed",
            "official_source_origin_authenticated",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(output[name], False)
        for name in (*implementation.ZERO_COUNTERS, "scene_tree_insertion_count"):
            self.assertIs(type(output[name]), int)
            self.assertEqual(0, output[name])

    def test_worker_parse_reader_refuses_missing_altered_and_rehashed_error_output(
        self,
    ):
        # Every mutation starts from the complete, actually captured process
        # result. The pure reader cannot rerun the syntax check to fill a gap.
        count = 0

        def refuse(value):
            nonlocal count
            with self.assertRaises(materializer.MaterializationFailure):
                materializer.validate_l15_qualification_worker_parse(value)
            count += 1

        def changed_at(path, replacement=None, *, missing=False):
            changed = copy.deepcopy(self.worker_parse)
            owner = changed
            for name in path[:-1]:
                owner = owner[name]
            if missing:
                del owner[path[-1]]
            else:
                owner[path[-1]] = replacement
            return changed

        def exercise_fields(value, path=()):
            for key, original in value.items():
                location = (*path, key)
                with self.subTest(missing=location):
                    refuse(changed_at(location, missing=True))
                replacements = [None]
                if type(original) is int:
                    replacements += [
                        False,
                        float(original),
                        str(original),
                        original + 1,
                    ]
                elif type(original) is bool:
                    replacements += [int(original), not original]
                elif type(original) is str:
                    replacements += [original + "_changed"]
                elif type(original) is list:
                    replacements += [[], original + ["--unexpected"]]
                elif type(original) is dict:
                    replacements += [{}, {**original, "unexpected": True}]
                for replacement in replacements:
                    with self.subTest(altered=location, replacement=replacement):
                        refuse(changed_at(location, replacement))
                if type(original) is dict:
                    exercise_fields(original, location)

        with mock.patch.object(
            implementation,
            "checked_process",
            side_effect=AssertionError("NO_ENGINE_PROCESS"),
        ), mock.patch.object(
            implementation.l14_runtime,
            "bind_runtime",
            side_effect=AssertionError("NO_IMAGE_REOPEN"),
        ), mock.patch.object(
            implementation.subprocess,
            "run",
            side_effect=AssertionError("NO_SUBPROCESS"),
        ):
            exercise_fields(self.worker_parse)
            for value in (
                None,
                [],
                {"ok": True},
                self.legacy_worker_parse,
                {**self.worker_parse, "unexpected": True},
            ):
                refuse(value)
            for stream in ("stdout", "stderr"):
                top_hash = "worker_parse_" + stream + "_sha256"
                for path in ((top_hash,), ("l15_process_output", stream, "raw_sha256")):
                    refuse(changed_at(path, "sha256:" + "0" * 64))
                refuse(
                    changed_at(("l15_process_output", stream, "utf8_text"), "\ud800")
                )
                for diagnostic in (
                    "ERROR: damaged check",
                    "SCRIPT ERROR: damaged script",
                ):
                    changed = copy.deepcopy(self.worker_parse)
                    text = (
                        changed["l15_process_output"][stream]["utf8_text"] + diagnostic
                    )
                    snapshot = {"utf8_text": text, **context.raw_binding(text)}
                    changed["l15_process_output"][stream] = snapshot
                    changed[top_hash] = snapshot["raw_sha256"]
                    refuse(changed)
            changed = copy.deepcopy(self.worker_parse)
            changed["l15_process_output"]["arguments"][-1] = "res://wrong_worker.gd"
            refuse(changed)
        print("L15_WORKER_PARSE_OUTPUT_READER_CORRUPTIONS=" + str(count), flush=True)

    def test_actual_complete_native_result_reaches_materializer_without_any_process(
        self,
    ):
        with mock.patch.object(
            implementation,
            "checked_process",
            side_effect=AssertionError("NO_ENGINE_PROCESS"),
        ), mock.patch.object(
            implementation.l14_runtime,
            "bind_runtime",
            side_effect=AssertionError("NO_IMAGE_REOPEN"),
        ), mock.patch.object(
            implementation.subprocess,
            "run",
            side_effect=AssertionError("NO_SUBPROCESS"),
        ):
            proof = materializer.validate_l15_qualification_native_result(self.receipt)
            direct = implementation.validate_godot_receipt(
                self.receipt, require_l15_context=True
            )
            self.assertTrue(context.packet.same(proof, direct))
            self.assertIsNone(implementation.validate_godot_receipt(self.legacy))
        self.assertEqual(70, len(self.receipt))
        self.assertEqual(
            implementation.expected_godot_zero_world_fields(),
            {key: value for key, value in self.receipt.items() if key != FIELD},
        )
        self.assertEqual(1458, self.receipt["active_terminal_global_step"])
        self.assertEqual(734, self.receipt["active_terminal_local_recovery_step"])
        self.assertEqual(17, self.receipt["same_body_node_identity_count"])
        self.assertEqual(0, self.receipt["solver_step_count"])
        self.assertIs(proof["source_origin_authenticated_by_this_reader"], False)
        self.assertIs(proof["official_context_qualification"], False)
        self.assertIs(proof["physical_execution_authorized"], False)

    def test_complete_result_reader_refuses_every_missing_or_altered_emitted_field(
        self,
    ):
        count = 0
        for key, value in self.receipt.items():
            changes = [None]
            if type(value) is int:
                changes += [False, float(value), str(value), value + 1]
            elif type(value) is bool:
                changes += [int(value), not value]
            elif type(value) is str:
                changes += [value + "_changed"]
            elif type(value) is dict:
                changes += [{}, {**value, "unexpected": True}]
            for replacement in changes:
                changed = copy.deepcopy(self.receipt)
                changed[key] = replacement
                with self.subTest(key=key, replacement=replacement), self.assertRaises(
                    materializer.MaterializationFailure
                ):
                    materializer.validate_l15_qualification_native_result(changed)
                count += 1
            missing = copy.deepcopy(self.receipt)
            del missing[key]
            with self.subTest(missing=key), self.assertRaises(
                materializer.MaterializationFailure
            ):
                materializer.validate_l15_qualification_native_result(missing)
            count += 1
        with self.assertRaises(materializer.MaterializationFailure):
            materializer.validate_l15_qualification_native_result(
                {**self.receipt, "extra": True}
            )
        with self.assertRaises(materializer.MaterializationFailure):
            materializer.validate_l15_qualification_native_result(self.receipt[FIELD])
        with self.assertRaises(materializer.MaterializationFailure):
            materializer.validate_l15_qualification_native_result(self.legacy)
        print(
            "L15_COMPLETE_NATIVE_RESULT_READER_CORRUPTIONS=" + str(count + 3),
            flush=True,
        )

    def test_missing_stale_and_rehashed_inconsistent_capture_refuses(self):
        for value in (None, {}, True, "missing"):
            changed = copy.deepcopy(self.receipt)
            changed[FIELD] = value
            with self.subTest(value=value), self.assertRaises(
                implementation.AuditFailure
            ):
                self.consume(changed)
        changed = copy.deepcopy(self.receipt)
        del changed[FIELD]
        with self.assertRaises(implementation.AuditFailure):
            self.consume(changed)
        for key, value in (
            ("utf8_text", self.receipt[FIELD]["utf8_text"] + " "),
            ("utf8_byte_length", float(self.receipt[FIELD]["utf8_byte_length"])),
            ("raw_sha256", "sha256:" + "0" * 64),
        ):
            changed = copy.deepcopy(self.receipt)
            changed[FIELD][key] = value
            with self.subTest(key=key), self.assertRaises(implementation.AuditFailure):
                self.consume(changed)
        for key, value in (
            ("official_context_qualification", True),
            ("world_build_count", 1),
            ("source_is_prepared_context_not_observation", False),
        ):
            changed = copy.deepcopy(self.receipt)
            capture = context.packet.parse_json(changed[FIELD]["utf8_text"])
            capture[key] = value
            raw = json.dumps(capture, sort_keys=True, separators=(",", ":"))
            changed[FIELD] = {"utf8_text": raw, **context.raw_binding(raw)}
            with self.subTest(key=key), self.assertRaises(implementation.AuditFailure):
                self.consume(changed)

    def test_complete_gate_and_strict_json_guards_still_refuse(self):
        for key, value in (
            ("positive_case_count", 23),
            ("positive_case_count", 24.0),
            ("forced_failure_case_count", 236),
            ("world_build_count", False),
            ("native_readback_count", 0.0),
            ("solver_step_count", "0"),
            ("body_impulse_write_count", 1),
            ("body_transform_write_count", 0.0),
            ("body_velocity_write_count", False),
            ("physical_execution_authorized", True),
            ("physics_state_modified", True),
            ("physical_question_opened", True),
            ("prone_to_standing_claimed", True),
        ):
            changed = copy.deepcopy(self.receipt)
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(implementation.AuditFailure):
                self.consume(changed)
        text = json.dumps(self.receipt, sort_keys=True, separators=(",", ":"))
        for changed in (
            '{"ok":true,' + text[1:],
            '{"extra_nonfinite":NaN,' + text[1:],
            '{"extra_nonfinite":1e999,' + text[1:],
        ):
            with self.assertRaises(implementation.AuditFailure):
                self.consume_output(implementation.ZERO_WORLD_MARKER + changed)
        with self.assertRaisesRegex(implementation.AuditFailure, "DIAGNOSTIC"):
            self.consume_output(self.outputs["ZERO_WORLD"].stdout, "ERROR: fixture")

    def test_ambiguous_opt_in_is_rejected_before_any_process(self):
        for invalid in (None, 0, 1, "true", [], {}):
            with mock.patch.object(implementation, "checked_process") as process:
                with self.subTest(value=invalid), self.assertRaisesRegex(
                    implementation.AuditFailure, "MODE_KIND"
                ):
                    implementation.audit_godot(self.godot, require_l15_context=invalid)
                process.assert_not_called()

    def test_actual_cli_rejects_unknown_or_duplicate_options_before_gate(self):
        for options in (
            ["--unknown"],
            ["--r10f-l15-prepared-context", "--r10f-l15-prepared-context"],
        ):
            result = implementation.run_process(
                (
                    self.godot,
                    "--headless",
                    "--path",
                    ROOT,
                    "--script",
                    implementation.ZERO_WORLD_SCRIPT,
                    "--",
                    *options,
                ),
                timeout_seconds=30,
            )
            self.assertEqual(1, result.returncode)
            refusal = implementation.parse_marker(
                result.stdout, implementation.ZERO_WORLD_MARKER, "CLI_REFUSAL"
            )
            self.assertIs(refusal["ok"], False)
            self.assertEqual("QSDK_R10F_ZERO_WORLD_ARGUMENTS", refusal["failure_code"])
            self.assertNotIn(FIELD, refusal)
            self.assertEqual(0, refusal["positive_case_count"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
