"""Exercise the R10Q Godot producer, bridge and scheduler without physics.

Run under the locomotion operation lock. Exposed inputs remain original evidence;
the separate synthetic completion snapshot does not prove a physical trajectory.
"""
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
import r10p_entry_domain_diagnosis as diagnosis
import r10q_upright_native_component as component

GODOT = EVIDENCE / 'qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/development-cold-build-ed4ec00a/godot.windows.editor.dev.x86_64.exe'
LEGACY_INPUT = EVIDENCE / 'development-r10k-bridge-validation-c46b23fb510e4f5eae57b4d5b4c3317e/component/entry-input.json'
LEGACY_FIXTURES = EVIDENCE / 'development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log'


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)


class R10QSourceOrchestration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10Q_COMPONENT_ROOT', str(EVIDENCE / ('r10q-source-orchestration-' + uuid.uuid4().hex))))
        cls.out.mkdir(exist_ok=False)
        cls.before = _source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10Q_COMPONENT_EVIDENCE ' + str(cls.out), flush=True)
        raw = (ROOT / component.BINDING).read_bytes()
        assert diagnosis.digest(raw) == component.BINDING_SHA
        cls.runtime = json.loads(raw)
        for item in cls.runtime['source_files']:
            assert diagnosis.binding(ROOT / item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
        for item in (cls.runtime['runtime'], cls.runtime['compiled_fixtures']):
            assert diagnosis.binding(Path(item['path'])) == item

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        write(cls.out / 'source_after.json', after)
        write(cls.out / 'source-stability.json', dict(source_unchanged=after == cls.before, world_build_count=0, solver_step_count=0))
        if after != cls.before:
            raise AssertionError('R10Q_SOURCE_DRIFT')

    def run_godot(self, name, script, source, timeout=420):
        output = self.out / (name + '.json')
        args = [str(GODOT), '--headless', '--path', str(ROOT), '--script', 'res://tests/' + script, '--', str(source), str(output)]
        started = time.monotonic()
        with (self.out / (name + '.stdout.log')).open('xb') as stdout, (self.out / (name + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(args, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / (name + '.execution.json'), dict(command=args, timed_out=True, direct_process_killed_and_reaped=True))
                raise
        write(self.out / (name + '.execution.json'), dict(command=args, exit_code=process.returncode, seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (name + '.stderr.log')).read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads(output.read_text(encoding='utf-8'))
        self.assertTrue(result['ok'], {k: v for k, v in result['checks'].items() if not v})
        self.assertTrue(result['checks'] and all(result['checks'].values()))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])
        return result

    def test_upright_source_identity_and_exclusive_native_owners(self):
        result = self.run_godot('upright-task-source', 'test_development_r10q_task_source.gd', self.runtime['compiled_fixtures']['path'], 120)
        self.assertTrue(result['checks']['no_inserted_body'])
        self.assertTrue(result['checks']['competing_tasks_refused'])
        self.assertTrue(result['checks']['select_3'])  # Actual V7 pre-completion plan.

    def test_legacy_source_selection_still_passes_its_actual_interface_checks(self):
        result = self.run_godot('legacy-task-source', 'test_development_r10k_task_source.gd', LEGACY_FIXTURES, 120)
        self.assertEqual(99, len(result['checks']))

    def test_contiguous_upright_worker_control_and_ramp_handoff(self):
        result = self.run_godot('upright-worker', 'test_development_r10q_worker_hooks.gd', self.runtime['compiled_fixtures']['path'])
        self.assertEqual(240, len(result['entry_packets']))
        self.assertEqual(63, len(result['upright_packets']))
        self.assertEqual(60, result['final_upright_memory']['standing_samples_observed'])
        self.assertEqual('fresh_selected_policy_walking_resume', result['final_state']['phase'])
        self.assertEqual(0, result['final_state']['confirm_prone_step_count'])
        self.assertTrue(result['synthetic_measurements_only'])
        self.assertFalse(result['selector_and_launcher_validation_exercised'])

    def test_exposed_entry_branches_and_separately_typed_completion(self):
        raw = (ROOT / diagnosis.CLOSURE).read_bytes()
        self.assertEqual(diagnosis.CLOSURE_SHA, diagnosis.digest(raw))
        closure = json.loads(raw)
        claim_path = Path(closure['evidence_root']) / 'campaign_claim.json'
        self.assertEqual(closure['independent_audit']['campaign_claim_sha256'], diagnosis.binding(claim_path)['raw_sha256'])
        children = {c['cell_id']: c for c in json.loads(claim_path.read_text(encoding='utf-8'))['children']}
        cases = []
        for cell in closure['independent_audit']['cells']:
            if cell['role'] != diagnosis.KICK or cell['outcome'] != 'negative':
                continue
            report, binding = diagnosis.read_report(cell, children[cell['cell_id']])
            packets = [dict(source_attempt_id=p['source_attempt_id'], bound_observations=p['bound_observations'], expected_original_control=p['native_receipt']) for p in report['passive_entry']['entry_packets']]
            self.assertEqual(240, len(packets))
            cases.append(dict(seed=cell['seed'], expected_count=240, expected_branch='upright', source=binding, packets=packets))
        self.assertEqual([50645, 50646], [c['seed'] for c in cases])
        # Existing bridge input was pinned by its immutable implementation record.
        legacy_record = json.loads((ROOT / 'sdk/recovery/r10k_source_bridge_component_implementation_v1.json').read_text(encoding='utf-8'))
        binding = next(b for b in legacy_record['retained_evidence'] if b['path'].replace('\\', '/') == LEGACY_INPUT.as_posix())
        self.assertEqual(binding['raw_sha256'], diagnosis.binding(LEGACY_INPUT)['raw_sha256'])
        legacy = json.loads(LEGACY_INPUT.read_text(encoding='utf-8'))
        for case in legacy['cases']:
            if case['seed'] not in (50641, 50643):
                continue
            self.assertEqual(case['source']['raw_sha256'], diagnosis.binding(Path(case['source']['path']))['raw_sha256'])
            cases.append(case)
        self.assertEqual([50645, 50646, 50641, 50643], [c['seed'] for c in cases])
        source = self.out / 'entry-input.json'
        write(source, dict(cases=cases, step_fixtures_path=self.runtime['compiled_fixtures']['path']))
        result = self.run_godot('source-orchestrator', 'test_development_r10q_orchestrator.gd', source)
        rows = [r for r in result['results'] if 'exposed_seed' in r]
        self.assertEqual(837, sum(r['samples'] for r in rows))
        self.assertEqual(['upright', 'upright', 'partial', 'prone'], [r['state']['r10q_entry_kind'] for r in rows])
        self.assertTrue(result['checks']['completion_requires_60_standing'])
        self.assertTrue(result['checks']['fresh_walking_preserves_upright_history'])


if __name__ == '__main__':
    unittest.main()
