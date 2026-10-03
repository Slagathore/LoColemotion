"""Actual zero-world timing/publication, strict reader controls and unbound refusal."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'tests'))
import development_step_cost_profile as profile
import qsdk_r10f_l14_runtime_binding as runtime
from test_development_recovery_smoke import native


class StepCostProfile(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        runtime.bind_runtime(Path(runtime.IMAGES['godot_console']['path']))
        run = native('tests/test_development_step_cost_profile.gd', timeout=30)
        sys.stdout.buffer.write(run.stdout)
        sys.stdout.buffer.flush()
        if run.returncode or b'ERROR:' in run.stdout + run.stderr:
            raise AssertionError((run.returncode, run.stdout[-5000:], run.stderr))
        def one(prefix):
            lines = [line[len(prefix):] for line in run.stdout.decode('utf-8').splitlines() if line.startswith(prefix)]
            if len(lines) != 1:
                raise AssertionError((prefix, lines))
            return lines[0]
        cls.raw = one('SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ')
        cls.report = json.loads(cls.raw)
        cls.profile = json.loads(one(profile.MARKER))
        cls.gate = json.loads(one('DEVELOPMENT_STEP_COST_ZERO_WORLD '))

    def test_actual_nested_clock_controls_and_zero_world_publication(self):
        self.assertIs(self.gate['ok'], True)
        self.assertEqual(9, len(self.gate['checks']))
        self.assertTrue(all(value is True for value in self.gate['checks'].values()))
        self.assertEqual(0, self.gate['world_count'])
        self.assertEqual(0, self.gate['solver_step_count'])
        profile.validate_profile(self.profile, self.report, self.raw)

    def test_changed_report_identity_or_claims_refuse(self):
        for key in self.profile:
            changed = copy.deepcopy(self.profile)
            changed[key] = None
            with self.subTest(key=key), self.assertRaises((ValueError, TypeError)):
                profile.validate_profile(changed, self.report, self.raw)
        for key in ('physical_acceptance_authority', 'release_authority', 'physics_solver_time_isolated'):
            changed = copy.deepcopy(self.profile)
            changed[key] = True
            with self.subTest(promoted=key), self.assertRaises(ValueError):
                profile.validate_profile(changed, self.report, self.raw)
        with self.assertRaises(ValueError):
            profile.validate_profile(self.profile, self.report, self.raw + ' ')

    def test_timing_kind_accounting_and_missing_coverage_refuse(self):
        for key, value in [('elapsed_us', True), ('elapsed_us', -1), ('accounted_us', 999999999),
                           ('unattributed_us', -1), ('open_section_count', 1), ('ok', False)]:
            changed = copy.deepcopy(self.profile)
            changed['timing'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                profile.validate_profile(changed, self.report, self.raw)
        changed = copy.deepcopy(self.profile)
        changed['timing']['sections']['final_report_publication']['sample_count'] = 2
        with self.assertRaises(ValueError):
            profile.validate_profile(changed, self.report, self.raw)

    def test_actual_profiled_worker_refuses_unbound_launch_before_world(self):
        run = native('sdk/adapters/godot/gdscript/development_profiled_recovery_smoke_worker_v1.gd', timeout=20)
        prefix = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '
        rows = [json.loads(line[len(prefix):]) for line in run.stdout.decode('utf-8').splitlines() if line.startswith(prefix)]
        self.assertEqual(1, run.returncode, run.stderr)
        self.assertEqual(1, len(rows), run.stdout[-2000:])
        self.assertEqual('QSDK_R10F_CAMPAIGN_BINDING_INVALID', rows[0]['failure_code'])
        self.assertEqual(0, rows[0]['world_build_count'])
        self.assertEqual(0, rows[0]['solver_step_count'])


if __name__ == '__main__':
    unittest.main()
