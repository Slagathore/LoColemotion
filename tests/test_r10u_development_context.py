"""R10U's pair-first population, original-result prerequisite and native guard.

These are zero-world component tests. The synthetic profile is deliberately not
a selectable production candidate; this suite cannot qualify a physical route.
"""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10u_development as development
import development_passive_entry_profile as entry
import development_recovery_smoke as smoke

REFERENCE = dict(resource='synthetic-r10u-component-only', raw_sha256='sha256:' + '0'*64)
HEAD = 'a'*40
GODOT = development.EVIDENCE / 'qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/development-cold-build-ed4ec00a/godot.windows.editor.dev.x86_64.exe'


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2); stream.write('\n')


def declaration():
    attempt = uuid.uuid4().hex
    return dict(attempt_id=attempt, seed=41245, candidate_profile=REFERENCE,
        source_snapshot=dict(head=HEAD), development_execution_mode=development.PAIR,
        comparative_authority=False, baseline_reused=False,
        children=[dict(role=role, child_attempt_id=uuid.uuid4().hex,
            termination_nonce=uuid.uuid4().hex,
            evidence_path=(development.EVIDENCE/('development-recovery-smoke-'+attempt)/'children'/role).as_posix())
            for role in development.ROLES],
        r10u_development=development.context(development.PAIR, HEAD, REFERENCE))


def result():
    return development.finite_result(declaration(), [
        dict(role=role, entry_kind='unselected' if index == 0 else 'upright',
            finite_task_predicates_passed=True,
            post_recovery_handoff='direct' if index == 0 else 'bounded_hold')
        for index, role in enumerate(development.ROLES)])


class DevelopmentContext(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = development.EVIDENCE/('r10u-population-component-'+uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out/'source_before.json', cls.before)
        print('R10U_POPULATION_COMPONENT_EVIDENCE '+str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out/'source_after.json', after)
        if cls.before != after:
            raise AssertionError('R10U_POPULATION_COMPONENT_SOURCE_DRIFT')

    def test_first_population_is_fresh_pair_with_bounded_hold(self):
        value = declaration()
        observed = development.validate_context(value['r10u_development'], value)
        self.assertEqual((41245, 245, development.ROLES, 'bounded_hold'),
            (observed['seed'], observed['identity']['prefix_phase'], observed['roles'], observed['required_handoff']))
        self.assertEqual('paired_commissioning', value['r10u_development']['stage'])
        self.assertIsNone(value['r10u_development']['prerequisite_pair'])
        self.assertNotIn('prerequisite_single_diagnostic', value['r10u_development'])
        self.assertEqual([245,246,241,243], [development.seed_identity(s)['prefix_phase'] for s in (41245,41246,41241,41243)])

    def test_single_first_old_seeds_and_undeclared_pairs_refuse(self):
        for seed in (True, 41245.0, 41145, 40200, 50641):
            with self.subTest(seed=seed), self.assertRaisesRegex(ValueError, 'UNDECLARED_SEED'):
                development.seed_identity(seed)
        for mode, seed in [(development.SINGLE,41245), (development.PAIR,41246),
                           (development.PAIR,41241), (development.PAIR,41243)]:
            with self.subTest(mode=mode,seed=seed), self.assertRaisesRegex(ValueError, 'MODE_SEED'):
                development.context(mode, HEAD, REFERENCE, diagnostic_seed=seed)
        with self.assertRaisesRegex(ValueError, 'INITIAL_PAIR_HAS_PREREQUISITE'):
            development.context(development.PAIR, HEAD, REFERENCE, self.out)

    def test_branch_diagnostics_require_original_positive_pair(self):
        for seed in (41246,41241,41243):
            with self.subTest(seed=seed), self.assertRaisesRegex(ValueError, 'REQUIRES_POSITIVE_PAIR'):
                development.context(development.SINGLE, HEAD, REFERENCE, diagnostic_seed=seed)
            bound = dict(path='synthetic-only', raw_sha256='sha256:'+'0'*64, attempt_id='1'*32)
            with mock.patch.object(development, 'qualify_prerequisite', return_value=bound) as audit:
                context = development.context(development.SINGLE, HEAD, REFERENCE, self.out, seed)
                audit.assert_called_once_with(self.out, REFERENCE, paired=True)
                self.assertEqual(bound, context['prerequisite_pair'])
                self.assertEqual('additional_branch_diagnostic', context['stage'])
                self.assertEqual('direct', context['required_handoff'])
        with self.assertRaisesRegex(ValueError, 'ONLY_PAIR_PREREQUISITE'):
            development.qualify_prerequisite(self.out, REFERENCE, paired=False)

    def test_context_mutations_cannot_change_population_or_authority(self):
        changes = {
            'handoff': lambda d: d['r10u_development'].update(required_handoff='direct'),
            'branch': lambda d: d['r10u_development'].update(required_entry_kind='partial'),
            'source': lambda d: d['r10u_development'].update(source_commit='0'*40),
            'phase': lambda d: d['r10u_development']['seed'].update(prefix_phase=246),
            'profile': lambda d: d['r10u_development'].update(candidate_profile={}),
            'design': lambda d: d['r10u_development'].update(design_binding={}),
            'claim': lambda d: d['r10u_development'].update(release_authority=True),
            'missing_role': lambda d: d['children'].pop(0),
            'reused_child': lambda d: d['children'][1].update(child_attempt_id=d['children'][0]['child_attempt_id']),
            'reused_parent': lambda d: d['children'][0].update(termination_nonce=d['attempt_id']),
            'child_path': lambda d: d['children'][0].update(evidence_path=str(self.out)),
            'single_mode': lambda d: d.update(development_execution_mode=development.SINGLE),
            'stage': lambda d: d['r10u_development'].update(stage='initial_single_diagnostic'),
            'old_prerequisite': lambda d: d['r10u_development'].update(prerequisite_single_diagnostic=None),
            'pair_prerequisite': lambda d: d['r10u_development'].update(prerequisite_pair={}),
        }
        for name, mutate in changes.items():
            changed = declaration(); mutate(changed)
            with self.subTest(name=name), self.assertRaises(ValueError):
                development.validate_context(changed['r10u_development'], changed)
        for field in ('r10j_campaign','r10k_development','r10l_development','r10m_development',
                'r10n_development','r10o_development','r10p_campaign','r10q_development','r10r_development',
                'r10s_development','r10t_development'):
            changed = declaration(); changed[field] = {}
            with self.subTest(field=field), self.assertRaisesRegex(ValueError,'CROSSED_CAMPAIGN'):
                development.validate_context(changed['r10u_development'], changed)

    def test_positive_pair_requires_both_cells_and_hold(self):
        positive = result()
        self.assertTrue(development.positive_result(positive, REFERENCE, paired=True))
        self.assertFalse(development.positive_result(positive, REFERENCE, paired=False))
        for index in (0,1):
            changed = copy.deepcopy(positive); changed['cells'][index]['finite_task_predicates_passed'] = False
            self.assertFalse(development.positive_result(changed, REFERENCE, paired=True))
        for field,value in [('seed',41145),('candidate_profile',{}),('all_tasks_positive',False),
                ('branch_coverage_complete',False),('physical_acceptance_authority',True)]:
            self.assertFalse(development.positive_result(dict(positive, **{field:value}), REFERENCE, paired=True))
        changed = copy.deepcopy(positive); changed['cells'][1]['post_recovery_handoff'] = 'direct'
        self.assertFalse(development.positive_result(changed, REFERENCE, paired=True))
        finite = development.finite_result(declaration(), changed['cells'])
        self.assertTrue(finite['all_tasks_positive']); self.assertFalse(finite['branch_coverage_complete'])

    def test_prerequisite_reconstructs_original_audit_and_rejects_failed_supervisor(self):
        # These nested synthetic fixtures cannot inhabit the real launch namespace.
        namespace = self.out/'prerequisite'; namespace.mkdir()
        attempt = uuid.uuid4().hex
        directory = namespace/('development-recovery-smoke-'+attempt); directory.mkdir()
        write(directory/'declaration.json', dict(seed=41245, attempt_id=attempt,
            development_execution_mode=development.PAIR, r10u_development=dict(stage='paired_commissioning')))
        observed = dict(r10u_finite_development=result())
        write(directory/'independent_audit.stdout.json', observed)
        write(directory/'supervisor_result.json', dict(ok=True, failure_code=''))
        with self.assertRaisesRegex(ValueError, 'PREREQUISITE_ROOT'):
            development.qualify_prerequisite(directory, REFERENCE, paired=True)
        with mock.patch.object(development, 'EVIDENCE', namespace):
            with mock.patch.object(smoke, 'retained_checkpoint', side_effect=ValueError('ORIGINAL_AUDIT_REFUSED')):
                with self.assertRaisesRegex(ValueError,'ORIGINAL_AUDIT_REFUSED'):
                    development.qualify_prerequisite(directory, REFERENCE, paired=True)
            with mock.patch.object(smoke, 'retained_checkpoint', return_value=dict(observed=observed)) as audit:
                self.assertEqual(attempt, development.qualify_prerequisite(directory, REFERENCE, paired=True)['attempt_id'])
                audit.assert_called_once_with(directory.resolve())
                original_read = development.read
                def read_failed(path):
                    return dict(ok=False, failure_code='SMOKE_INDEPENDENT_AUDIT_FAILED') if path == directory/'supervisor_result.json' else original_read(path)
                with mock.patch.object(development, 'read', side_effect=read_failed):
                    with self.assertRaisesRegex(ValueError,'PREREQUISITE_SUPERVISOR_FAILURE'):
                        development.qualify_prerequisite(directory, REFERENCE, paired=True)

    def test_native_population_guard_and_publication_context_without_sdk(self):
        self.assertEqual('sha256:1b365fe5a054e2614e2c063273d6e686593eafac81836475385df14b65177e4b', development.sha(GODOT))
        source = self.out/'synthetic-pair.json'; write(source, declaration())
        target = self.out/'native-result.json'
        command = [str(GODOT),'--headless','--path',str(ROOT),'--script',
            'res://tests/test_r10u_development_seed.gd','--',str(source),str(target)]
        with (self.out/'native.stdout.log').open('xb') as stdout, (self.out/'native.stderr.log').open('xb') as stderr:
            process = subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
        write(self.out/'native-execution.json',dict(command=command,exit_code=process.returncode,
            world_build_count=0,solver_step_count=0,sdk_instantiation_count=0))
        error = (self.out/'native.stderr.log').read_text(encoding='utf-8')
        self.assertEqual(0,process.returncode,error); self.assertNotIn('ERROR:',error)
        observed = json.loads(target.read_bytes())
        self.assertTrue(observed['ok'], observed)
        self.assertGreaterEqual(len(observed['checks']), 40)
        self.assertTrue(all(observed['checks'].values()))


if __name__ == '__main__':
    unittest.main()
