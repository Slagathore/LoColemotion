"""Bounded retained-data regression; no qualification or physics invocation."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_retained_integrity_failure as failure


class RetainedIntegrityFailure(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.expected = failure.collect()
        cls.frozen = failure.frozen_functions(failure.git("show", failure.SOURCE + ":" + failure.RETENTION))

    def test_actual_population_and_exact_failure_are_retained(self):
        self.assertEqual(16, self.expected["retained_evidence"]["file_count"])
        self.assertEqual(127458028, self.expected["retained_evidence"]["total_byte_length"])
        self.assertEqual([True, True, False, False], [item["exact_equal"] for item in
                         self.expected["frozen_predicate_replay"]["comparisons"]])
        self.assertFalse(self.expected["independent_physical_report_audit_passed"])

    def test_complete_closure_fields_fail_closed_on_removal(self):
        for key in self.expected:
            broken = copy.deepcopy(self.expected)
            del broken[key]
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "CLOSURE_RECORD_MISMATCH"):
                failure.validate_record(broken, self.expected)

    def test_claim_promotion_refuses(self):
        for key in ("independent_physical_report_audit_passed", "valid_physical_route_established",
                    "behavioral_conclusion_authorized", "same_identity_rerun_permitted",
                    "sdk1_m07_satisfied", "physical_execution_authorized", "release_authority"):
            broken = copy.deepcopy(self.expected)
            broken[key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                failure.validate_record(broken, self.expected)

    def test_exact_binary64_types_signed_zero_and_one_step_refuse(self):
        same = self.frozen["same"]
        for left, right in ((True, 1), (1, 1.0), (0.0, -0.0),
                            (2.9802322387695312e-08, 2.980232238769531e-08)):
            with self.subTest(left=left, right=right):
                self.assertFalse(same(left, right))
        self.assertTrue(same({"value": 2.9802322387695312e-08}, {"value": 2.9802322387695312e-08}))

    def test_duplicate_and_nonfinite_json_refuse(self):
        for text in ('{"x":1,"x":1}', '{"x":NaN}', '{"x":1e999}'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.frozen["parse_json"](text)

    def test_missing_added_and_corrupted_population_files_refuse(self):
        # A small disposable fixture is not retained scientific evidence.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "original.json"
            target.write_bytes(b"{}")
            bindings = [dict(path=target.name, byte_length=2, raw_sha256=failure.sha(b"{}"))]
            failure.verify_population(root, bindings)
            target.write_bytes(b"[]")
            with self.assertRaisesRegex(ValueError, "RETAINED_FILE"):
                failure.verify_population(root, bindings)
            target.unlink()
            with self.assertRaisesRegex(ValueError, "POPULATION_SET"):
                failure.verify_population(root, bindings)
            target.write_bytes(b"{}")
            (root / "extra.json").write_bytes(b"{}")
            with self.assertRaisesRegex(ValueError, "POPULATION_SET"):
                failure.verify_population(root, bindings)

    def test_real_powershell_roundtrip_reproduces_observed_decimal(self):
        command = "$v = '{\"value\":2.9802322387695312e-08}' | ConvertFrom-Json -AsHashtable; $v | ConvertTo-Json -Compress"
        result = subprocess.run(["C:/Program Files/PowerShell/7/pwsh.exe", "-NoLogo", "-NoProfile",
                                 "-NonInteractive", "-Command", command], cwd=ROOT,
                                capture_output=True, text=True, encoding="utf-8", timeout=30, check=True)
        self.assertEqual('', result.stderr)
        self.assertEqual('{"value":2.980232238769531E-08}', result.stdout.strip())
        self.assertFalse(self.frozen["same"](json.loads('{"value":2.9802322387695312e-08}'),
                                            json.loads(result.stdout)))


if __name__ == "__main__":
    unittest.main()
