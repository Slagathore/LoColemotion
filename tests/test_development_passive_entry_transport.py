"""Real Godot/ABI and retained-input checks, with no physics construction.

Run under the existing locomotion operation lock. This does not commission a
physical worker or promote an old observation into passive-entry evidence.
"""
import copy
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/python"))
sys.path.insert(0, str(ROOT / "tests"))
from sporespore_locomotion import LocomotionCore, LocomotionCoreError
from test_development_recovery_smoke import native, runtime

NEW_DLL = ROOT / "sdk/target/development-passive-entry-v1/debug/sporespore_godot_adapter.dll"
REPORT = ROOT.parent / "SporeSpore_Evidence/development-recovery-smoke-4b4c9c059591449a92c32c131239c487/children/kick_passive_recovery_resume/worker_report.json"
REPORT_SHA = "8de24d7420f12779c07d07dd50932b3e017e8887031a2f9132165e26d752d3fd"
MARKER = "DEVELOPMENT_PASSIVE_ENTRY_TRANSPORT "


class PassiveEntryTransport(unittest.TestCase):
    binding_path = 'sdk/development_passive_entry_runtime_binding_v1.json'
    native_script = 'tests/test_development_passive_entry_transport.gd'

    @classmethod
    def setUpClass(cls):
        cls.binding = json.loads((ROOT / cls.binding_path).read_bytes())
        artifact = cls.binding["runtime"]
        for path in (ROOT / cls.binding['local_build_path'], Path(artifact["path"])):
            raw = path.read_bytes()
            if len(raw) != artifact["byte_length"] or "sha256:" + hashlib.sha256(raw).hexdigest() != artifact["raw_sha256"]:
                raise AssertionError(("passive adapter artifact drift", str(path)))
        for source in cls.binding["source_files"]:
            raw = (ROOT / source["path"]).read_bytes()
            if len(raw) != source["byte_length"] or "sha256:" + hashlib.sha256(raw).hexdigest() != source["raw_sha256"]:
                raise AssertionError(("passive adapter compiled source drift", source["path"]))
        retained_raw = REPORT.read_bytes()
        if hashlib.sha256(retained_raw).hexdigest() != REPORT_SHA:
            raise AssertionError("retained deadline report drift")
        runtime.bind_runtime(Path(runtime.IMAGES["godot_console"]["path"]))
        try:
            run = native(cls.native_script, timeout=30)
        except subprocess.TimeoutExpired as error:
            raise AssertionError(("zero-world test timeout", error.stdout, error.stderr)) from error
        sys.stdout.buffer.write(run.stdout)
        sys.stdout.buffer.flush()
        rows = [line[len(MARKER):] for line in run.stdout.decode().splitlines() if line.startswith(MARKER)]
        if run.returncode or b"ERROR:" in run.stdout + run.stderr or len(rows) != 1:
            raise AssertionError((run.returncode, run.stdout, run.stderr))
        cls.result = json.loads(rows[0])
        cls.core = LocomotionCore(ROOT / cls.binding['local_build_path'])
        raw = REPORT.read_bytes()
        if hashlib.sha256(raw).hexdigest() != REPORT_SHA:
            raise AssertionError("retained deadline report drift")
        report = json.loads(raw)
        cls.original = json.loads(report["retained_arm"]["last_recovery_collection_transport_retention"]["request"]["utf8_text"])

    def test_real_godot_new_methods_refuse_malformed_inputs_without_physics(self):
        self.assertIs(self.result["ok"], True)
        for key, value in self.result["checks"].items():
            if not key.endswith("_json"):
                self.assertIs(value, True, key)
        self.assertEqual(0, self.result["world_build_count"])
        self.assertEqual(0, self.result["solver_step_count"])

    def test_godot_return_transport_preserves_binary64_and_nested_types(self):
        checks = self.result["checks"]
        source = json.loads(checks["source_json"])["value"]
        returned = json.loads(checks["roundtrip_json"])["value"]
        for expected, actual in zip(source["numbers"], returned["numbers"], strict=True):
            self.assertEqual(struct.pack("!d", expected), struct.pack("!d", actual))
        self.assertIs(returned["nested"]["flag"], True)
        self.assertIsNone(returned["nested"]["empty"])
        self.assertIs(type(returned["nested"]["step"]), int)
        self.assertEqual(source["nested"], returned["nested"])

    def test_original_native_record_stays_canonical_and_is_not_passive_evidence(self):
        original = copy.deepcopy(self.original)
        receipt = self.core.recovery_collect_native_v3(original)
        self.assertEqual("supported_exact", receipt["support_status"])
        self.assertEqual(original["observation"], receipt["observation"])
        # New request wrapper; the actual original observation/source are NOT
        # edited to make a retained recovery-owned sample look controller-free.
        passive = copy.deepcopy(original)
        passive["schema_version"] = "sporespore_recovery_passive_native_collection_request_v1"
        passive.pop("phase")
        refused = self.core.recovery_collect_passive_native_v1(passive)
        self.assertEqual("passive_entry_collector_ownership_invalid", refused["collection"]["refusal_reason"])
        self.assertFalse(refused["canonical_controller_step_executed"])
        self.assertIsNone(refused["collection"]["observation"])
        self.assertEqual(self.original, original)
        self.assertEqual(REPORT_SHA, hashlib.sha256(REPORT.read_bytes()).hexdigest())

    def test_real_bridge_retains_the_exact_sent_request_and_refusal(self):
        packet = json.loads(self.result["checks"]["actual_bridge_refusal_json"])
        self.assertEqual("PASSIVE_ENTRY_NATIVE_COLLECTION_REFUSED", packet["failure_code"])
        call = packet["collection_call"]
        self.assertEqual(1, call["compiled_call_count"])
        expected = copy.deepcopy(self.original)
        expected["schema_version"] = "sporespore_recovery_passive_native_collection_request_v1"
        expected.pop("phase")
        self.assertEqual(expected, json.loads(call["request"]["utf8_text"]))
        for part in ("request", "response"):
            raw = call[part]["utf8_text"].encode("utf-8")
            self.assertEqual(len(raw), call[part]["utf8_byte_length"])
            self.assertEqual("sha256:" + hashlib.sha256(raw).hexdigest(), call[part]["raw_sha256"])
        self.assertEqual(json.loads(call["response"]["utf8_text"])["value"], call["value"])

    def test_old_pinned_adapter_still_loads_and_explicitly_refuses_new_api(self):
        old = LocomotionCore(ROOT / "sdk/target/debug/sporespore_godot_adapter.dll")
        with self.assertRaises(LocomotionCoreError) as refused:
            old.recovery_collect_passive_native_v1({})
        self.assertEqual("PASSIVE_NATIVE_COLLECTION_RUNTIME_UNAVAILABLE", refused.exception.failure_code)

    def test_new_runtime_binding_is_not_worker_or_physical_authority(self):
        for field in ("physical_worker_integrated", "default_godot_extension_changed",
                      "old_pinned_adapter_overwritten", "qualification_authority",
                      "physical_acceptance_authority", "release_authority"):
            self.assertIs(self.binding[field], False, field)
        for field in ("world_build_count", "solver_step_count"):
            self.assertIs(type(self.binding[field]), int)
            self.assertEqual(0, self.binding[field])


if __name__ == "__main__":
    unittest.main()
