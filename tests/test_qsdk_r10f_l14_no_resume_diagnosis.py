"""Reopen the exact no-resume diagnosis; do not qualify a physical outcome."""

import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_no_resume_branch_diagnosis as diagnosis
from qsdk_r10f_l14_terminal_consumers import same_source_value


class NoResumeDiagnosisTests(unittest.TestCase):
    def test_exact_record_recomputes_through_frozen_consumer_and_actual_orchestrator(
        self,
    ):
        path = ROOT / "sdk/qsdk_r10f_l14_no_resume_consumer_diagnosis_v1.json"
        raw = path.read_bytes()
        self.assertEqual(len(raw), 5546)
        self.assertEqual(
            hashlib.sha256(raw).hexdigest(),
            "4a95a34533b78526b5d2732e57ab149440365f64e5086f717b250f0714511204",
        )
        expected = json.loads(raw)
        actual = diagnosis.diagnose()
        self.assertTrue(same_source_value(expected, actual))
        self.assertEqual(actual["actual_orchestrator_source_branch_count"], 3)
        self.assertTrue(
            actual["consumer_reopened_from_frozen_git_not_mutable_checkout"]
        )
        self.assertFalse(actual["physical_execution_authorized"])
        self.assertFalse(actual["physical_result_changed_or_promoted"])
        self.assertEqual(path.read_bytes(), raw)


if __name__ == "__main__":
    unittest.main(verbosity=2)
