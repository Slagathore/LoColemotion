"""Actual R10Q candidate selection, native routes and independent segment replay.

Use the locomotion operation lock. Synthetic observations and detached command
surfaces exercise production interfaces without asserting physical success.
"""
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
import development_recovery_candidate as candidate
from development_passive_entry_profile import _source_snapshot
from test_development_r10q_source_orchestration import GODOT, write

PROFILE = ROOT / 'sdk/development/recovery_candidates/r10q-v55-upright-integrated-v1.json'
INPUT = EVIDENCE / 'development-v51-walking-adapter-756cb143d8214f019a816292206406e3/input.json'


class R10QRouteSelection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10Q_ROUTE_ROOT', str(EVIDENCE / ('r10q-route-review-' + uuid.uuid4().hex))))
        cls.out.mkdir(exist_ok=False)
        cls.before = _source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10Q_ROUTE_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        write(cls.out / 'source_after.json', after)
        write(cls.out / 'source-stability.json', dict(source_unchanged=after == cls.before, world_build_count=0, solver_step_count=0))
        if after != cls.before:
            raise AssertionError('R10Q_ROUTE_SOURCE_DRIFT')

    def run_godot(self, name, script, source, timeout=420):
        output = self.out / (name + '.json')
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script', 'res://tests/' + script, '--', str(source), str(output)]
        started = time.monotonic()
        with (self.out / (name + '.stdout.log')).open('xb') as stdout, (self.out / (name + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / (name + '.execution.json'), dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
                raise
        write(self.out / (name + '.execution.json'), dict(command=command, exit_code=process.returncode, seconds=round(time.monotonic()-started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (name + '.stderr.log')).read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads(output.read_bytes())
        self.assertTrue(result['ok'], {k: v for k, v in result['checks'].items() if not v} | dict(failure=result.get('failure'), replay=result.get('replay')))
        self.assertTrue(result['checks'] and all(result['checks'].values()))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])
        return result, output

    def test_complete_candidate_selection_and_crossed_contracts(self):
        selected = candidate.selection(candidate.reference_for_path(PROFILE))
        schedule = selected['diagnostic_schedule']
        self.assertEqual('r10q_v55_upright_recovery_route_v1', candidate.walking_policy_id(schedule))
        self.assertEqual((320, 30, 1, 240, 3160, 3512), tuple(candidate.limits(selected).values()))
        self.assertEqual('res://sdk/trace_analysis/r10q_recovery_replay.gd', selected['reader'])
        for key in ['walking_entry_profile_id', 'walking_start_profile_id', 'walking_policy_id', 'walking_policy_contract_sha256', 'runtime_sha256']:
            with self.subTest(key=key), self.assertRaises(ValueError):
                candidate.walking_policy_id(dict(schedule, **{key: 'crossed'}))

    def test_actual_worker_prefix_and_four_native_routes(self):
        result, _ = self.run_godot('routes', 'test_development_r10q_route_selection.gd', INPUT, 120)
        for seed in (40846, 40845, 40841, 40843):
            self.assertTrue(result['checks']['declared_prefix_' + str(seed)])
        for label in ['resume', 'matched', 'ramp', 'hold']:
            ledger = result['result'][label]['ledger']
            self.assertTrue(ledger['ok'])
            self.assertEqual(8, ledger['detached_hinge_parameter_container_count'])
            self.assertEqual((0, 0, 0), (ledger['world_build_count'], ledger['scene_tree_insertion_count'], ledger['solver_step_count']))

    def test_upright_worker_publication_and_fresh_consumer_replay(self):
        binding = json.loads((ROOT / 'sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.runtime.json').read_bytes())
        fixture, path = self.run_godot('producer', 'test_development_r10q_replay_fixture.gd', binding['compiled_fixtures']['path'])
        self.assertEqual(240, len(fixture['input']['retention']['entry_packets']))
        self.assertEqual(63, len(fixture['input']['upright_retention']['step_packets']))
        self.assertEqual(60, fixture['input']['upright_retention']['final_memory']['standing_samples_observed'])
        result, _ = self.run_godot('reader', 'test_development_r10q_replay_reader.gd', path)
        self.assertTrue(result['checks']['actual_retained_worker_replayed'])
        self.assertTrue(result['checks']['fabricated_partial_history_refused'])
        self.assertFalse(result['complete_report_exercised'])


if __name__ == '__main__':
    unittest.main()
