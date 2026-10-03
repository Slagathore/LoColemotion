"""R10Q development declaration, actual worker seed guard, and result conjunction."""
import copy
import json
import os
import subprocess
import unittest
import uuid
from unittest import mock

from test_development_r10q_complete_report import ROOT, EVIDENCE, PROFILE, declaration, candidate, development, entry, GODOT, write


class R10QDeclaration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = EVIDENCE / ('development-r10q-declaration-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        cls.value = declaration(candidate.reference_for_path(PROFILE), cls.before['head'])
        write(cls.out / 'synthetic-declaration.json', cls.value)
        print('R10Q_DECLARATION_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        if after != cls.before:
            raise AssertionError('R10Q_DECLARATION_SOURCE_DRIFT')

    def test_exact_declared_development_population(self):
        self.assertEqual([246, 245, 241, 243], [development.seed_identity(seed)['prefix_phase'] for seed in (40846, 40845, 40841, 40843)])
        self.assertEqual(development.ROLES, development.validate_declaration(self.value)['roles'])
        for seed in (True, 40846.0, 40200, 40442, 50641):
            with self.subTest(seed=seed), self.assertRaises(ValueError):
                development.seed_identity(seed)
        with self.assertRaisesRegex(ValueError, 'SINGLE_REQUIRES_POSITIVE_PAIR'):
            development.context(development.SINGLE, self.before['head'], self.value['candidate_profile'], diagnostic_seed=40843)

    def test_crossed_context_role_and_identity_refusals(self):
        changes = {
            'seed': lambda d: d.update(seed=40200),
            'mode': lambda d: d.update(development_execution_mode=development.SINGLE),
            'role': lambda d: d['children'].reverse(),
            'nonce_reuse': lambda d: d['children'][1].update(termination_nonce=d['children'][0]['termination_nonce']),
            'source': lambda d: d['r10q_development'].update(source_commit='0'*40),
            'phase': lambda d: d['r10q_development']['seed'].update(prefix_phase=21),
            'prerequisite': lambda d: d['r10q_development'].update(prerequisite_pair={}),
            'claim': lambda d: d['r10q_development'].update(physical_acceptance_authority=True),
            'r10j': lambda d: d.update(r10j_campaign={}),
            'r10k': lambda d: d.update(r10k_development={}),
            'r10l': lambda d: d.update(r10l_development={}),
            'r10m': lambda d: d.update(r10m_development={}),
        }
        for name, mutate in changes.items():
            value = copy.deepcopy(self.value); mutate(value)
            with self.subTest(name=name), self.assertRaises(ValueError):
                development.validate_declaration(value)

    def test_actual_worker_guard_before_sdk_or_world(self):
        output = self.out / 'godot-result.json'
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10q_seed_guard.gd', '--', str(self.out / 'synthetic-declaration.json'), str(output)]
        with (self.out / 'stdout.log').open('xb') as stdout, (self.out / 'stderr.log').open('xb') as stderr:
            try:
                process = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=90,
                    creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
                raise
        write(self.out / 'execution.json', dict(command=command, exit_code=process.returncode, world_build_count=0, solver_step_count=0))
        error = (self.out / 'stderr.log').read_text(encoding='utf-8')
        self.assertNotIn('ERROR:', error)
        self.assertEqual(0, process.returncode, error)
        result = json.loads(output.read_bytes())
        self.assertTrue(result['ok'], result)
        self.assertEqual(32, len(result['checks']))

    def test_positive_pair_requires_every_task_and_the_declared_branch(self):
        cells = [dict(role=role, entry_kind='unselected' if index == 0 else 'upright', finite_task_predicates_passed=True)
                 for index, role in enumerate(development.ROLES)]
        result = development.finite_result(self.value, cells)
        self.assertTrue(development.positive_pair_result(result, self.value['candidate_profile']))
        for index in (0, 1):
            changed = copy.deepcopy(cells); changed[index]['finite_task_predicates_passed'] = False
            self.assertFalse(development.positive_pair_result(development.finite_result(self.value, changed), self.value['candidate_profile']))
        changed = copy.deepcopy(cells); changed[1]['entry_kind'] = 'prone'
        self.assertFalse(development.positive_pair_result(development.finite_result(self.value, changed), self.value['candidate_profile']))
        with self.assertRaises(ValueError):
            development.finite_result(self.value, cells[:1])

    def test_single_branch_requires_independent_reaudit_of_the_positive_pair(self):
        import development_recovery_smoke as smoke
        # A separate synthetic directory prevents these declaration-only inputs
        # from looking like a physical attempt in the durable evidence root.
        directory = self.out / ('development-recovery-smoke-' + self.value['attempt_id'])
        directory.mkdir()
        write(directory / 'declaration.json', self.value)
        cells = [dict(role=role, entry_kind='unselected' if i == 0 else 'upright', finite_task_predicates_passed=True)
                 for i, role in enumerate(development.ROLES)]
        observed = dict(r10q_finite_development=development.finite_result(self.value, cells))
        write(directory / 'independent_audit.stdout.json', observed)
        write(directory / 'supervisor_result.json', dict(ok=True, failure_code=''))
        with mock.patch.object(development, 'EVIDENCE', self.out):
            # A positive summary alone cannot authorize the second branch.
            with mock.patch.object(smoke, 'retained_checkpoint', side_effect=ValueError('ORIGINAL_EVIDENCE_REFUSED')) as audit:
                with self.assertRaisesRegex(ValueError, 'ORIGINAL_EVIDENCE_REFUSED'):
                    development.qualify_prerequisite(directory, self.value['candidate_profile'])
                audit.assert_called_once_with(directory.resolve())
            # Exercise the acceptance branch only behind an explicit unit-test
            # stand-in for the full physical auditor, never an execution receipt.
            with mock.patch.object(smoke, 'retained_checkpoint', return_value=dict(observed=observed)) as audit:
                bound = development.qualify_prerequisite(directory, self.value['candidate_profile'])
                self.assertEqual(development.sha(directory / 'independent_audit.stdout.json'), bound['raw_sha256'])
                self.assertEqual(self.value['attempt_id'], bound['attempt_id'])
                audit.assert_called_once_with(directory.resolve())


if __name__ == '__main__':
    unittest.main()
