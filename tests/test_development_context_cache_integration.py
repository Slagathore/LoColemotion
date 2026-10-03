"""Actual opt-in publication, dynamic route guards, declaration and reader controls."""
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


class ContextCacheIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        runtime.bind_runtime(Path(runtime.IMAGES['godot_console']['path']))
        run = native('tests/test_development_context_cache_integration.gd', timeout=60)
        sys.stdout.buffer.write(run.stdout)
        sys.stdout.buffer.flush()
        if run.returncode or run.stderr or b'ERROR:' in run.stdout:
            raise AssertionError((run.returncode, run.stdout[-4000:], run.stderr))
        def one(prefix):
            rows = [line[len(prefix):] for line in run.stdout.decode('utf-8').splitlines() if line.startswith(prefix)]
            if len(rows) != 1:
                raise AssertionError((prefix, rows))
            return rows[0]
        cls.raw = one('SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ')
        cls.report = json.loads(cls.raw)
        cls.profile = json.loads(one(profile.MARKER))
        cls.gate = json.loads(one('DEVELOPMENT_CONTEXT_CACHE_INTEGRATION '))

    def test_actual_dynamic_preflight_refusals_and_both_call_sites(self):
        self.assertIs(self.gate['ok'], True)
        self.assertGreaterEqual(len(self.gate['checks']), 45)
        self.assertTrue(all(value is True for value in self.gate['checks'].values()))
        for field in ('world_build_count', 'solver_step_count', 'native_physics_read_count'):
            self.assertIs(type(self.gate[field]), int)
            self.assertEqual(0, self.gate[field])

    def test_actual_bound_profile_requires_declared_cache(self):
        profile.validate_profile(self.profile, self.report, self.raw, context_cache_expected=True)
        with self.assertRaises(ValueError):
            profile.validate_profile(self.profile, self.report, self.raw)
        missing = copy.deepcopy(self.profile)
        missing.pop('context_cache')
        with self.assertRaises(ValueError):
            profile.validate_profile(missing, self.report, self.raw, context_cache_expected=True)

    def test_cache_accounting_types_coverage_and_forbidden_claims(self):
        good = copy.deepcopy(self.profile['context_cache'])
        good.update(call_sites={site: 3 for site in profile.CACHE_CALL_SITES},
                    hits=4, full_checks=2, retained_entries=2)
        profile.validate_context_cache(good, 3)  # Accounting fixture, not a physical result.
        cases = [(key, None) for key in good]
        cases += [('hits', 4.0), ('hits', True), ('hits', 5), ('full_checks', 0),
                  ('bypasses', 3), ('retained_entries', 3), ('observations_cached', True),
                  ('dynamic_preflight_checks_skipped', True), ('call_sites', {'epoch_preflight': 6})]
        for key, value in cases:
            changed = copy.deepcopy(good)
            changed[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                profile.validate_context_cache(changed, 3)

    def test_independent_declaration_reader_refuses_mismatched_selection(self):
        declared = dict(context_cache_profile_id=profile.CACHE_PROFILE_ID,
                        context_cache_call_sites=profile.CACHE_CALL_SITES,
                        worker_resource=profile.CACHE_WORKER_RESOURCE, step_cost_profile_id=profile.PROFILE_ID)
        self.assertIs(profile.declared_context_cache(declared), True)
        self.assertIs(profile.declared_context_cache({}), False)
        for key in declared:
            for operation in ('missing', 'wrong'):
                changed = copy.deepcopy(declared)
                if operation == 'missing':
                    changed.pop(key)
                else:
                    changed[key] = 'wrong'
                with self.subTest(key=key, operation=operation), self.assertRaises(ValueError):
                    profile.declared_context_cache(changed)

    def test_real_unbound_worker_and_unprofiled_cli_refuse_before_world(self):
        script = profile.CACHE_WORKER_RESOURCE.removeprefix('res://')
        run = native(script, timeout=20)
        rows = [json.loads(line.split(' ', 1)[1]) for line in run.stdout.decode().splitlines()
                if line.startswith('SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ')]
        self.assertEqual(1, run.returncode, run.stderr)
        self.assertEqual(1, len(rows))
        self.assertEqual('QSDK_R10F_CAMPAIGN_BINDING_INVALID', rows[0]['failure_code'])
        self.assertEqual(0, rows[0]['world_build_count'])
        self.assertEqual(0, rows[0]['solver_step_count'])
        cli = subprocess.run(['C:/Program Files/PowerShell/7/pwsh.exe', '-NoProfile', '-NonInteractive',
                              '-File', 'sdk/run_development_recovery_smoke.ps1', '-ReuseContextChecks'],
                             cwd=ROOT, capture_output=True, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
        self.assertNotEqual(0, cli.returncode)
        self.assertIn(b'SMOKE_CONTEXT_CACHE_REQUIRES_PROFILE_STEPS', cli.stderr)


if __name__ == '__main__':
    unittest.main()
