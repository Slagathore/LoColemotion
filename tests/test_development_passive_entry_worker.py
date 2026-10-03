"""Real scheduler/worker boundary checks. No model, world or solver execution.

Run under the locomotion operation lock. These do not enable a physical launch;
the independent new-report reader and launch-profile integration remain required.
"""
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from test_development_recovery_smoke import native


def receipt(script, marker, *, expected_exit=0, timeout=55):
    try:
        run = native(script, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise AssertionError(("native test timed out", error.stdout, error.stderr)) from error
    sys.stdout.buffer.write(run.stdout)
    sys.stdout.buffer.flush()
    rows = [json.loads(line[len(marker):]) for line in run.stdout.decode().splitlines()
            if line.startswith(marker)]
    if run.returncode != expected_exit or b"ERROR:" in run.stdout + run.stderr or len(rows) != 1:
        raise AssertionError((run.returncode, run.stdout[-6000:], run.stderr))
    return rows[0]


class PassiveEntryWorker(unittest.TestCase):
    def assert_zero_world(self, value):
        for key in ("world_build_count", "solver_step_count"):
            self.assertIs(type(value[key]), int)
            self.assertEqual(0, value[key])
        self.assertIs(value["physical_acceptance_authority"], False)
        self.assertIs(value["release_authority"], False)

    def test_distinct_scheduler_keeps_original_schema_closed(self):
        value = receipt("tests/test_development_passive_entry_scheduler.gd",
                        "DEVELOPMENT_PASSIVE_ENTRY_SCHEDULER ")
        self.assertIs(value["ok"], True)
        self.assertEqual(14, len(value["checks"]))
        self.assertTrue(all(flag is True for flag in value["checks"].values()), value)
        self.assert_zero_world(value)

    def test_actual_worker_wait_handoff_canonical_continuation_and_refusals(self):
        value = receipt("tests/test_development_passive_entry_worker_hooks.gd",
                        "DEVELOPMENT_PASSIVE_ENTRY_WORKER_HOOKS ")
        self.assertIs(value["ok"], True)
        self.assertEqual(27, len(value["checks"]))
        self.assertTrue(all(flag is True for flag in value["checks"].values()), value)
        self.assertIs(value["synthetic_native_observations_only"], True)
        self.assert_zero_world(value)

    def test_actual_new_worker_unbound_launch_refuses_without_world(self):
        value = receipt("sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd",
                        "SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ", expected_exit=1, timeout=20)
        self.assertEqual("sporespore_development_measured_prone_smoke_child_v1", value["schema_version"])
        self.assertEqual("QSDK_R10F_CAMPAIGN_BINDING_INVALID", value["failure_code"])
        # Binding refused before the process-isolated lane or entry state exists.
        self.assertNotIn("passive_entry", value)
        self.assertEqual("", value["attempt_id"])
        self.assert_zero_world(value)


if __name__ == "__main__":
    unittest.main()
