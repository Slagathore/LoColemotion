"""Actual Godot source-producer and bridge checks; never constructs a world."""
import hashlib
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
NATIVE = EVIDENCE / 'development-r10k-native-component-6cf028564e544e9eb38c49a84983aadb/component'


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)


class R10KSourceBridges(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10K_BRIDGE_ROOT', str(EVIDENCE / ('development-r10k-source-bridges-' + uuid.uuid4().hex))))
        cls.out.mkdir(exist_ok=False)
        cls.before = _source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10K_BRIDGE_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        write(cls.out / 'source_after.json', after)
        write(cls.out / 'source-stability.json', dict(source_unchanged=after == cls.before,
            world_build_count=0, solver_step_count=0))
        if after != cls.before:
            raise AssertionError('R10K_SOURCE_DRIFT_DURING_NATIVE_CHECKS')

    def run_native(self, name, script, source, expected_checks, timeout):
        output = self.out / (name + '.json')
        args = [str(GODOT), '--headless', '--path', str(ROOT), '--script', script, '--', str(source), str(output)]
        started = time.monotonic()
        with (self.out / (name + '.stdout.log')).open('xb') as stdout, (self.out / (name + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(args, cwd=ROOT, stdout=stdout, stderr=stderr,
                    timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / (name + '.execution.json'), dict(command=args, timed_out=True,
                    owned_direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                raise
        write(self.out / (name + '.execution.json'), dict(command=args, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (name + '.stderr.log')).read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads(output.read_text(encoding='utf-8'))
        self.assertTrue(result['ok'], result['checks'])
        self.assertEqual(expected_checks, len(result['checks']))
        self.assertTrue(all(result['checks'].values()))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])
        return result

    def test_source_identity_is_selected_by_the_original_sampler_before_native_reads(self):
        result = self.run_native('task-source', 'res://tests/test_development_r10k_task_source.gd', FIXTURES, 99, 120)
        self.assertTrue(result['measurements']['synthetic_snapshots'])
        self.assertTrue(result['checks']['no_inserted_body'])
        self.assertTrue(result['checks']['direct_source_identical'])

    def test_real_entry_bridge_and_partial_step_requests_preserve_native_sources(self):
        cases = []
        for seed, count, branch in [(50641, 240, 'partial'), (50642, 240, 'partial'), (50643, 117, 'prone')]:
            retained = json.loads((NATIVE / f'retained-passive-{seed}.json').read_text(encoding='utf-8'))
            source = retained['source']
            raw = Path(source['path']).read_bytes()
            self.assertEqual(source['raw_sha256'], 'sha256:' + hashlib.sha256(raw).hexdigest())
            report = json.loads(raw)
            packets = [{key: row[key] for key in ['source_attempt_id', 'bound_observations']}
                for row in report['passive_entry']['entry_packets']]
            self.assertEqual(count, len(packets))
            cases.append(dict(seed=seed, expected_count=count, expected_branch=branch,
                source=source, packets=packets, expected_final=retained['final_prospective_result']))
        source = self.out / 'entry-input.json'
        write(source, dict(cases=cases, step_fixtures_path=str(FIXTURES)))
        result = self.run_native('recovery-stage', 'res://tests/test_development_r10k_recovery_stage.gd', source, 61, 300)
        entries = [row for row in result['results'] if 'seed' in row]
        self.assertEqual(597, sum(row['count'] for row in entries))
        self.assertEqual(['partial', 'partial', 'prone'], [row['last_packet']['entry_kind'] for row in entries])
        self.assertTrue(result['exposed_inputs_not_regraded'] and result['synthetic_step_fixtures'])
        # The old entry declaration contains the exact descriptor. These two
        # fields can differ by one ULP from the fresh Godot context constants.
        for row in result['results']:
            if 'synthetic_step_fixture' not in row:
                continue
            request = json.loads(row['call']['request']['utf8_text'])
            original = request['step']['declaration']['entry_request']['passive_request']['declaration']['initialization']['descriptor']
            self.assertEqual(original, request['collection']['descriptor'])


if __name__ == '__main__':
    unittest.main()
