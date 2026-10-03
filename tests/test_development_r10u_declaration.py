"""R10U staged development population and actual pre-world worker refusals."""
import copy
import json
import subprocess
import unittest
import uuid
from unittest import mock

from test_development_r10u_complete_report import ROOT, EVIDENCE, PROFILE, declaration, candidate, development, entry, GODOT, write


def result(reference, paired):
    roles = development.ROLES if paired else [development.ROLES[1]]
    return dict(schema_version=development.RESULT_SCHEMA, seed=41245, prefix_phase=245,
        candidate_profile=reference, cells=[dict(role=role,
            entry_kind='unselected' if role == development.ROLES[0] else 'upright',
            finite_task_predicates_passed=True, post_recovery_handoff='bounded_hold' if role == development.ROLES[1] else 'direct') for role in roles],
        all_tasks_positive=True, branch_coverage_complete=True,
        physical_acceptance_authority=False, release_authority=False)


class R10UDeclaration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = EVIDENCE / ('development-r10u-declaration-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        cls.value = declaration(candidate.reference_for_path(PROFILE), cls.before['head'])
        candidate.selection(cls.value['candidate_profile'])
        write(cls.out / 'synthetic-declaration.json', cls.value)
        print('R10U_DECLARATION_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        if after != cls.before:
            raise AssertionError('R10U_DECLARATION_SOURCE_DRIFT')

    def test_exact_initial_single_and_declared_population(self):
        self.assertEqual([245, 246, 241, 243], [development.seed_identity(seed)['prefix_phase']
            for seed in (41245, 41246, 41241, 41243)])
        self.assertEqual(development.ROLES, development.validate_declaration(self.value)['roles'])
        self.assertEqual('paired_commissioning', self.value['r10u_development']['stage'])
        for seed in (True, 41245.0, 40200, 40846, 50641):
            with self.subTest(seed=seed), self.assertRaises(ValueError):
                development.seed_identity(seed)
        for mode, seed, code in [(development.SINGLE, 41245, 'MODE_SEED'),
                *[(development.SINGLE, s, 'ADDITIONAL_SINGLE_REQUIRES_POSITIVE_PAIR') for s in (41246, 41241, 41243)],
                (development.PAIR, 41246, 'MODE_SEED')]:
            with self.subTest(mode=mode, seed=seed), self.assertRaisesRegex(ValueError, code):
                development.context(mode, self.before['head'], self.value['candidate_profile'], diagnostic_seed=seed)

    def test_actual_final_header_selects_r10u_seed_for_both_roles(self):
        import development_recovery_smoke as reader
        from test_development_recovery_smoke_reader import SmokeReader
        selected = candidate.selection(self.value['candidate_profile'])
        worker = selected['worker_selection']
        identity = development.seed_identity(41245)
        fixtures = []
        for descriptor in self.value['children']:
            # Header-only synthetic fixtures: no launch, physical trace, or replay.
            report, _, _ = SmokeReader().fixture()
            report.update(schema_version=worker['report_schema'], work_id=worker['work_id'],
                source_commit=self.before['head'], parent_attempt_id=self.value['attempt_id'],
                child_attempt_id=descriptor['child_attempt_id'], arm_id=descriptor['role'], seed=41245,
                maximum_solver_step_count=candidate.limits(selected)['maximum_steps_per_child'],
                coverage_complete=False, status='development_smoke_coverage_incomplete',
                r10u_development=copy.deepcopy(self.value['r10u_development']),
                seed_label=identity['label'], seed_sha256=identity['sha256'], held_out_cell_access_count=0,
                retained_arm=dict(walking_sessions=[dict(evaluation_segment_id='walking_prefix',
                    start_receipt=dict(initial_gait_steps=dict.fromkeys(
                        ('front_left','front_right','rear_left','rear_right'),245),
                        development_prefix_phase_selection=dict(
                            schema_version='sporespore_r10u_prefix_phase_selection_v1',
                            profile_id='r10u_declared_development_prefix_phase_v1',seed=41245,
                            prefix_phase=245,source_design_sha256=development.DESIGN_SHA,
                            physical_acceptance_authority=False,release_authority=False)))]))
            for field in ('candidate_profile','development_execution_mode','comparative_authority','baseline_reused'):
                report[field] = self.value[field]
            reader.validate_header(report,descriptor,self.value,123)
            for seed in (40200,41145,True,41245.0):
                with self.subTest(role=descriptor['role'],seed=seed), self.assertRaisesRegex(ValueError,'HEADER_seed'):
                    reader.validate_header(dict(report,seed=seed),descriptor,self.value,123)
            with self.assertRaisesRegex(ValueError,'SYNTHETIC_REPORT_NOT_PHYSICAL'):
                reader.validate_header(dict(report,synthetic_test_fixture=True),descriptor,self.value,123)
            fixtures.append(dict(header=report,descriptor=descriptor))
        write(self.out/'synthetic-final-header-fixtures.json',dict(fixtures=fixtures,
            synthetic_header_only=True,complete_report_or_route=False,
            world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False))

    def test_crossed_context_role_identity_and_stage_refusals(self):
        changes = {
            'seed': lambda d: d.update(seed=40846),
            'mode': lambda d: d.update(development_execution_mode=development.SINGLE),
            'role': lambda d: d['children'][0].update(role=development.ROLES[1]),
            'nonce_reuse': lambda d: d['children'][0].update(termination_nonce=d['children'][0]['child_attempt_id']),
            'parent_reuse': lambda d: d['children'][0].update(termination_nonce=d['attempt_id']),
            'path': lambda d: d['children'][0].update(evidence_path=str(self.out)),
            'source': lambda d: d['r10u_development'].update(source_commit='0'*40),
            'phase': lambda d: d['r10u_development']['seed'].update(prefix_phase=266),
            'stage': lambda d: d['r10u_development'].update(stage='initial_single_diagnostic'),
            'single_prerequisite': lambda d: d['r10u_development'].update(prerequisite_single_diagnostic={}),
            'pair_prerequisite': lambda d: d['r10u_development'].update(prerequisite_pair={}),
            'claim': lambda d: d['r10u_development'].update(physical_acceptance_authority=True),
        }
        for name, mutate in changes.items():
            value = copy.deepcopy(self.value); mutate(value)
            with self.subTest(name=name), self.assertRaises(ValueError):
                development.validate_declaration(value)
        for field in ('r10j_campaign', 'r10k_development', 'r10l_development', 'r10m_development',
                      'r10n_development', 'r10o_development', 'r10p_campaign', 'r10q_development', 'r10r_development', 'r10s_development', 'r10t_development'):
            with self.subTest(field=field), self.assertRaises(ValueError):
                development.validate_declaration(dict(self.value, **{field: {}}))

    def test_actual_worker_guard_before_sdk_or_world(self):
        output = self.out / 'godot-result.json'
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10u_seed_guard.gd', '--', str(self.out/'synthetic-declaration.json'), str(output)]
        with (self.out/'stdout.log').open('xb') as stdout, (self.out/'stderr.log').open('xb') as stderr:
            try:
                process = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=90,
                    creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out/'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
                raise
        write(self.out/'execution.json', dict(command=command, exit_code=process.returncode,
            world_build_count=0, solver_step_count=0))
        error = (self.out/'stderr.log').read_text(encoding='utf-8')
        self.assertNotIn('ERROR:', error)
        self.assertEqual(0, process.returncode, error)
        observed = json.loads(output.read_bytes())
        self.assertTrue(observed['ok'], observed)
        self.assertTrue(all(observed['checks'].values()))
        self.assertEqual((0, 0, 0), tuple(observed[k] for k in
            ('world_build_count', 'solver_step_count', 'sdk_instantiation_count')))
        self.assertGreaterEqual(len(observed['checks']), 35)

    def test_positive_single_and_pair_require_every_task_and_upright_branch(self):
        reference = self.value['candidate_profile']
        for paired in (True,):
            positive = result(reference, paired)
            self.assertTrue(development.positive_result(positive, reference, paired=paired))
            self.assertFalse(development.positive_result(positive, reference, paired=not paired))
            for index in range(len(positive['cells'])):
                changed = copy.deepcopy(positive); changed['cells'][index]['finite_task_predicates_passed'] = False
                self.assertFalse(development.positive_result(changed, reference, paired=paired))
            for field, value in [('seed', 41246), ('candidate_profile', {}), ('branch_coverage_complete', False),
                    ('all_tasks_positive', False), ('physical_acceptance_authority', True), ('release_authority', True)]:
                self.assertFalse(development.positive_result(dict(positive, **{field:value}), reference, paired=paired))
            changed = copy.deepcopy(positive); changed['cells'][-1]['entry_kind'] = 'prone'
            self.assertFalse(development.positive_result(changed, reference, paired=paired))
        finite = development.finite_result(self.value, result(reference, True)['cells'])
        self.assertTrue(development.positive_result(finite, reference, paired=True))
        with self.assertRaises(ValueError):
            development.finite_result(self.value, result(reference, False)['cells'])

    def test_later_contexts_select_the_correct_independently_audited_prerequisite(self):
        reference = self.value['candidate_profile']
        binding = dict(path='synthetic-only', raw_sha256='sha256:'+'0'*64, attempt_id='1'*32)
        for mode, seed, paired in [(development.SINGLE, seed, True) for seed in (41246, 41241, 41243)]:
            with mock.patch.object(development, 'qualify_prerequisite', return_value=binding) as audit:
                context = development.context(mode, self.before['head'], reference, self.out, seed)
                audit.assert_called_once_with(self.out, reference, paired=paired)
                self.assertEqual(binding, context['prerequisite_pair' if paired else 'prerequisite_single_diagnostic'])
                self.assertNotIn('prerequisite_single_diagnostic', context)
                self.assertEqual('additional_branch_diagnostic' if paired else 'paired_commissioning', context['stage'])
        with self.assertRaisesRegex(ValueError, 'INITIAL_PAIR_HAS_PREREQUISITE'):
            development.context(development.PAIR, self.before['head'], reference, self.out, 41245)

    def test_positive_summary_cannot_bypass_original_evidence_or_stage(self):
        import development_recovery_smoke as smoke
        reference = self.value['candidate_profile']
        # Nested test-only roots and explicit mocks cannot be physical prerequisites.
        for paired in (True,):
            attempt = uuid.uuid4().hex
            directory = self.out / ('development-recovery-smoke-' + attempt)
            directory.mkdir()
            value = dict(attempt_id=attempt, seed=41245,
                development_execution_mode=development.PAIR if paired else development.SINGLE,
                r10u_development=dict(stage='paired_commissioning' if paired else 'initial_single_diagnostic'))
            observed = dict(r10u_finite_development=result(reference, paired))
            write(directory/'declaration.json', value)
            write(directory/'independent_audit.stdout.json', observed)
            write(directory/'supervisor_result.json', dict(ok=True, failure_code=''))
            with self.assertRaisesRegex(ValueError, 'PREREQUISITE_ROOT'):
                development.qualify_prerequisite(directory, reference, paired=paired)
            with mock.patch.object(development, 'EVIDENCE', self.out):
                with mock.patch.object(smoke, 'retained_checkpoint', side_effect=ValueError('ORIGINAL_EVIDENCE_REFUSED')) as audit:
                    with self.assertRaisesRegex(ValueError, 'ORIGINAL_EVIDENCE_REFUSED'):
                        development.qualify_prerequisite(directory, reference, paired=paired)
                    audit.assert_called_once_with(directory.resolve())
                with mock.patch.object(smoke, 'retained_checkpoint', return_value=dict(observed=observed)) as audit:
                    bound = development.qualify_prerequisite(directory, reference, paired=paired)
                    audit.assert_called_once_with(directory.resolve())
                    self.assertEqual(development.sha(directory/'independent_audit.stdout.json'), bound['raw_sha256'])
                    self.assertEqual(attempt, bound['attempt_id'])
                    with self.assertRaisesRegex(ValueError, 'ONLY_PAIR_PREREQUISITE'):
                        development.qualify_prerequisite(directory, reference, paired=not paired)
                    failed_supervisor = directory/'synthetic-failed-supervisor.json'
                    write(failed_supervisor, dict(ok=False, failure_code='synthetic-failure'))
                    original_read = development.read
                    def crossed_read(path):
                        return original_read(failed_supervisor if path == directory/'supervisor_result.json' else path)
                    with mock.patch.object(development, 'read', side_effect=crossed_read):
                        with self.assertRaisesRegex(ValueError, 'PREREQUISITE_SUPERVISOR_FAILURE'):
                            development.qualify_prerequisite(directory, reference, paired=paired)
                    bad = copy.deepcopy(observed)
                    bad['r10u_finite_development']['cells'][-1]['finite_task_predicates_passed'] = False
                    audit.return_value = dict(observed=bad)
                    with self.assertRaisesRegex(ValueError, 'PREREQUISITE_NOT_POSITIVE'):
                        development.qualify_prerequisite(directory, reference, paired=paired)


if __name__ == '__main__':
    unittest.main()
