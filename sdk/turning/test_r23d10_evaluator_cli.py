from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest


SCRIPT = Path(__file__).resolve().with_name("r23d10_evaluator_cli.py")
STAGE_A = "QSDK_R23D10_STAGE_A_EVALUATION "
COMPLETE = "QSDK_R23D10_COMPLETE_EVALUATION "
GENERIC = "QSDK_R23D10_EVALUATION "


class R23D10EvaluatorCliIntegrationTests(unittest.TestCase):
    def _run(self, command: str, marker: str) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), command, "--zero-world-canary"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        lines = completed.stdout.splitlines()
        matches = [line for line in lines if line.startswith(marker)]
        self.assertEqual(len(matches), 1)
        self.assertFalse(any(line.startswith(GENERIC) for line in lines))
        receipt = json.loads(matches[0][len(marker) :])
        self.assertEqual(receipt["command"], command)
        self.assertTrue(receipt["zero_world_canary"])
        self.assertFalse(receipt["production_evaluator_implemented"])
        self.assertEqual(receipt["world_build_count"], 0)

    def test_stage_a_producer_matches_consumer_prefix(self) -> None:
        self._run("evaluate-stage-a", STAGE_A)

    def test_complete_producer_matches_consumer_prefix(self) -> None:
        self._run("evaluate-complete", COMPLETE)

    def test_physical_evaluation_is_unreachable(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "evaluate-stage-a"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertNotIn(STAGE_A, completed.stdout)
        self.assertNotIn(COMPLETE, completed.stdout)
        self.assertNotIn(GENERIC, completed.stdout)


if __name__ == "__main__":
    unittest.main()
