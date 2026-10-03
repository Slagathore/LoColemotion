"""Executable mutation controls for the QSDK-R24D1 zero-world design."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
AUDIT_PATH = (
    REPO_ROOT
    / "sdk"
    / "recovery"
    / "r24d1_canonical_prone_to_standing_design_audit.py"
)
DECLARATION_PATH = AUDIT_PATH.with_name(
    "r24d1_canonical_prone_to_standing_design_v1.json"
)
SPEC = importlib.util.spec_from_file_location("r24d1_design_audit", AUDIT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("QSDK-R24D1 audit module could not be loaded")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class R24D1DeclarationTests(unittest.TestCase):
    def test_live_design_is_exact_and_zero_world(self) -> None:
        document = AUDIT.load_json(DECLARATION_PATH)
        report = AUDIT.audit_document(document, REPO_ROOT)
        self.assertTrue(report["ok"])
        self.assertEqual(report["gate_id"], "QSDK-R24D1")
        self.assertEqual(report["engine_count"], 3)
        self.assertEqual(report["gate_family_count"], 7)
        self.assertEqual(report["threshold_count"], 16)
        self.assertEqual(report["set_threshold_count"], 0)
        self.assertEqual(report["future_physical_question_count"], 2)
        self.assertTrue(report["design_declaration_gate_passed"])
        self.assertFalse(report["complete_prephysical_gate_passed"])
        self.assertEqual(report["world_attempt_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physical_question_opened"])
        self.assertFalse(report["prone_to_standing_claimed"])
        self.assertFalse(report["physical_acceptance_authority"])
        self.assertFalse(report["release_authority"])

    def test_all_claim_changing_mutations_fail_closed(self) -> None:
        document = AUDIT.load_json(DECLARATION_PATH)
        rejected = AUDIT.run_mutation_suite(document, REPO_ROOT)
        self.assertEqual(rejected, 38)

    def test_cli_emits_one_exact_terminal_receipt(self) -> None:
        process = subprocess.run(
            [sys.executable, str(AUDIT_PATH)],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        markers = [
            line
            for line in process.stdout.splitlines()
            if line.startswith("QSDK_R24D1_DESIGN_AUDIT ")
        ]
        self.assertEqual(len(markers), 1)
        report = json.loads(markers[0].split(" ", 1)[1])
        self.assertTrue(report["ok"])
        self.assertEqual(report["mutation_rejection_count"], 38)
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["solver_step_count"], 0)
        self.assertFalse(report["physics_state_modified"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
