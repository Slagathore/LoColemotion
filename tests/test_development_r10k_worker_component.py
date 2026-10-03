"""Actual Godot orchestration and worker hooks on synthetic sources; no worlds."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
from development_passive_entry_profile import _source_snapshot

GODOT = EVIDENCE / 'qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/development-cold-build-ed4ec00a/godot.windows.editor.dev.x86_64.exe'
FIXTURES = EVIDENCE / 'development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log'
ENTRY_INPUT = EVIDENCE / 'development-r10k-bridge-validation-c46b23fb510e4f5eae57b4d5b4c3317e/component/entry-input.json'


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)


class R10KWorkerComponent(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10K_WORKER_ROOT', str(EVIDENCE / ('development-r10k-worker-component-' + uuid.uuid4().hex))))
        cls.out.mkdir(exist_ok=False)
        cls.before = _source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10K_WORKER_COMPONENT_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        write(cls.out / 'source_after.json', after)
        write(cls.out / 'source-stability.json', dict(source_unchanged=after == cls.before,
            world_build_count=0, solver_step_count=0))
        if after != cls.before:
            raise AssertionError('R10K_WORKER_COMPONENT_SOURCE_DRIFT')

    def run_godot(self, name, script, source, count, mode=None):
        result_path = self.out / (name + '.json')
        args = [str(GODOT), '--headless', '--path', str(ROOT), '--script', script,
            '--', str(source), str(result_path)]
        if mode:
            args.append(mode)
        started = time.monotonic()
        with (self.out / (name + '.stdout.log')).open('xb') as stdout, (self.out / (name + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(args, cwd=ROOT, stdout=stdout, stderr=stderr,
                    timeout=180, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / (name + '.execution.json'), dict(command=args, timed_out=True,
                    direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                raise
        write(self.out / (name + '.execution.json'), dict(command=args, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (name + '.stderr.log')).read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads(result_path.read_text(encoding='utf-8'))
        self.assertTrue(result['ok'], result.get('failure', result['checks']))
        self.assertEqual(count, len(result['checks']))
        self.assertTrue(all(result['checks'].values()))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])
        return result

    def test_orchestrator_native_entry_branches_and_crossed_source_refusals(self):
        result = self.run_godot('orchestrator', 'res://tests/test_development_r10k_orchestrator.gd', ENTRY_INPUT, 58)
        self.assertTrue(result['synthetic_orchestration_events'] and result['exposed_inputs_not_regraded'])
        self.assertEqual(597, sum(row.get('samples', 0) for row in result['results']))

    def test_partial_worker_uses_real_motors_and_contiguous_native_recovery(self):
        result = self.run_godot('partial-worker', 'res://tests/test_development_r10k_worker_hooks.gd', FIXTURES, 16)
        self.assertEqual((240, 63), (len(result['entry_packets']), len(result['partial_packets'])))
        self.assertTrue(result['synthetic_measurements_only'])
        self.assertFalse(result['selector_and_launcher_validation_exercised'])
        state, memory = result['final_state'], result['final_partial_memory']
        self.assertEqual('fresh_selected_policy_walking_resume', state['phase'])
        self.assertEqual((0, 0, 63, 60), (state['confirm_prone_step_count'],
            state['post_kick_recovery_step_count'], memory['total_steps_observed'], memory['standing_samples_observed']))
        self.assertIsNone(state['canonical_start_global_step'])
        self.assertEqual(272, state['epoch_start_global_step'])

    def test_prone_worker_preserves_real_confirmation_and_selects_new_budget(self):
        result = self.run_godot('prone-worker', 'res://tests/test_development_r10k_worker_hooks.gd', FIXTURES, 10, 'prone')
        self.assertEqual('prone', result['branch'])
        self.assertEqual({}, result['final_partial_memory'])
        self.assertEqual((12, 2), (result['final_state']['confirm_prone_step_count'], result['final_state']['post_kick_recovery_step_count']))

    def test_unselected_worker_retains_original_recovery_route(self):
        result = self.run_godot('legacy-worker', 'res://tests/test_development_r10k_worker_hooks.gd', FIXTURES, 10, 'legacy')
        self.assertEqual('legacy', result['branch'])
        self.assertNotIn('r10k_entry_kind', result['final_state'])
        self.assertEqual([], result['partial_packets'])


if __name__ == '__main__':
    unittest.main()
