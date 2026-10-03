"""Isolated synthetic receipts exercise one-use reservation, never a real gate."""
import copy
import json
from pathlib import Path
import unittest
import uuid
from unittest import mock

import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10ag_development as development
import r10ag_host_runtime as host
import r10ag_selection_check as fixtures
import development_passive_entry_profile as entry
from r10ac_support_loss_diagnosis import write
import r10ag_development_launch as launch


class R10AGLaunchGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = development.EVIDENCE / ('r10ag-launch-guard-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        cls.reference = development.reference()
        fixed = fixtures.fixture()
        cls.template = fixed['declaration']
        chosen = fixed['selection']; worker = chosen['worker_selection']
        cls.template.update(fixtures.candidate.limits(chosen), schema_version=worker['declaration_schema'],
            diagnostic_schedule_id=worker['schedule'], worker_resource=worker['worker'],
            passive_entry_runtime=entry.binding(chosen)['runtime'], timeout_seconds_per_child=2400,
            independent_replay_timeout_seconds=1200)
        cls.real_tokens = sorted(development.EVIDENCE.glob('r10ag*consumption*.json'))
        print('R10AG_LAUNCH_GUARD_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        assert after == cls.before
        assert sorted(development.EVIDENCE.glob('r10ag*consumption*.json')) == cls.real_tokens

    def setUp(self):
        self.base = self.out / self._testMethodName
        self.base.mkdir()
        self.real_evidence, self.real_contract = launch.EVIDENCE, launch.CONTRACT
        for module in (launch, development):
            patch = mock.patch.object(module, 'EVIDENCE', self.base)
            patch.start(); self.addCleanup(patch.stop)
        self.contract = self.base / 'synthetic-contract.json'
        write(self.contract, dict(schema_version='sporespore_r10ag_safety_stage_contract_v1',
            design_sha256=development.DESIGN_SHA, candidate_profile=self.reference,
            population_binding_correction=launch.population.reference(),
            coverage={area: dict(argument='Synthetic control exercise; not qualification.', stage_ids=['synthetic_control']) for area in launch.COVERAGE},
            population=dict(seed=65248, roles=[development.ROLE], mode=development.SINGLE),
            complete_applicable_coverage=True, additional_required_controls=[],
            stages=[dict(id='synthetic_control', pattern='test_synthetic.py', tests=1, candidate_bound=False)], total_tests=1,
            physical_acceptance_authority=False, release_authority=False))
        patch = mock.patch.object(launch, 'CONTRACT', self.contract)
        patch.start(); self.addCleanup(patch.stop)
        head = self.before['head']
        self.freeze = dict(root=ROOT.as_posix(), remote=launch.REMOTE, branch='main',
            head=head, origin_main=head, live_origin_main=head, clean=True)
        patch = mock.patch.object(launch, 'current_freeze', return_value=self.freeze)
        self.freeze_mock = patch.start(); self.addCleanup(patch.stop)

        # Reservation controls isolate the handoff gate; its native production and
        # consumer evidence are exercised by test_r10ag_context_handoff.py.
        patch = mock.patch.object(launch.handoff, 'verify', return_value=dict(synthetic_handoff=True))
        self.handoff_mock = patch.start(); self.addCleanup(patch.stop)

    def fixture(self, mutate=None):
        value = copy.deepcopy(self.template)
        value['attempt_id'] = uuid.uuid4().hex
        value['children'][0]['child_attempt_id'] = uuid.uuid4().hex
        value['children'][0]['termination_nonce'] = uuid.uuid4().hex
        value['runtime'] = host.expected_binding()
        value.update(context_cache_profile_id=entry.profile.CACHE_PROFILE_ID,
            context_cache_call_sites=entry.profile.CACHE_CALL_SITES, step_cost_profile_id=entry.profile.PROFILE_ID)
        value[development.CONTEXT_KEY] = development.context(development.SINGLE, self.before['head'], self.reference)
        root = self.base / ('development-recovery-smoke-' + value['attempt_id'])
        root.mkdir()
        for child in value['children']:
            child['evidence_path'] = (root / 'children' / child['role']).as_posix()
        value['source_snapshot'] = dict(head=self.before['head'], dirty=False, status=[], changed_file_bindings=[])
        receipt = dict(id='synthetic_control', passed=True, timed_out=False, exit_code=0, test_count=1, expected_test_count=1)
        for stream in ('stdout', 'stderr'):
            path = root / ('synthetic_control.' + stream + '.log')
            path.write_text('' if stream == 'stdout' else 'Synthetic stand-in; no gate ran.\nRan 1 test in 0.001s\n\nOK\n', encoding='utf-8')
            receipt[stream] = path.name
            receipt[stream + '_sha256'] = development.sha(path).removeprefix('sha256:')
        value['safety_stages'] = [receipt]
        if mutate: mutate(value)
        path = root / 'declaration.json'
        write(path, value)
        return path

    def test_exact_once_reservation_and_read_only_verification(self):
        path = self.fixture()
        self.assertTrue(launch.authorize(path)['ok'])
        token = self.base / launch.TOKEN
        original = token.read_bytes()
        self.assertTrue(launch.verify(path)['ok'])
        with self.assertRaisesRegex(ValueError, 'ATTEMPT_ALREADY_AUTHORIZED'): launch.authorize(path)
        second = self.fixture()
        with self.assertRaisesRegex(ValueError, 'POPULATION_ALREADY_CONSUMED'): launch.authorize(second)
        self.assertEqual(original, token.read_bytes())
        self.assertFalse((second.parent / launch.LAUNCH_FILE).exists())

    def test_missing_or_corrupt_handoff_refuses_before_reservation(self):
        path = self.fixture()
        for error in [FileNotFoundError('missing retained handoff'), ValueError('corrupt retained handoff')]:
            with mock.patch.object(launch.handoff, 'verify', side_effect=error):
                with self.assertRaises(type(error)): launch.authorize(path)
        self.freeze_mock.assert_not_called()
        self.assertFalse((self.base / launch.TOKEN).exists())
        self.assertFalse((path.parent / launch.LAUNCH_FILE).exists())

    def test_missing_contract_and_real_namespace_refuse_without_consumption(self):
        path = self.fixture()
        with mock.patch.object(launch, 'CONTRACT', self.base / 'missing.json'):
            with self.assertRaisesRegex(ValueError, 'COMPLETE_SAFETY_CONTRACT_PENDING'): launch.authorize(path)
        with mock.patch.object(launch, 'EVIDENCE', self.real_evidence):
            with self.assertRaisesRegex(ValueError, 'DECLARATION_ROOT'): launch.authorize(path)
        self.assertFalse((self.base / launch.TOKEN).exists())

    def test_gate_failures_refuse_before_source_check_or_reservation(self):
        for mutate in [lambda d: d.update(safety_stages=[]),
            lambda d: d['safety_stages'][0].update(passed=False),
            lambda d: d['safety_stages'][0].update(passed=1),
            lambda d: d['safety_stages'][0].update(timed_out=True),
            lambda d: d['safety_stages'][0].update(test_count=True),
            lambda d: d['safety_stages'][0].update(exit_code=1),
            lambda d: d['safety_stages'][0].update(expected_test_count=2),
            lambda d: d['safety_stages'][0].update(stdout='../crossed'),
            lambda d: d['safety_stages'][0].update(stderr_sha256='0' * 64)]:
            with self.assertRaises(ValueError): launch.authorize(self.fixture(mutate))
        self.freeze_mock.assert_not_called()
        self.assertFalse((self.base / launch.TOKEN).exists())

    def test_wrong_population_and_unpushed_source_cannot_consume(self):
        for mutate in [lambda d: d.update(seed=61247),
            lambda d: d.update(development_execution_mode='fresh_paired_development_diagnostic_v1'),
            lambda d: d.update(r10v_development={}),
            lambda d: d['source_snapshot'].update(dirty=True),
            lambda d: d['source_snapshot'].update(status=[' M file']),
            lambda d: d.update(physical_acceptance_authority=True)]:
            with self.assertRaises(ValueError): launch.authorize(self.fixture(mutate))
        with mock.patch.object(launch, 'current_freeze', side_effect=ValueError('SOURCE_NOT_PUSHED')):
            with self.assertRaisesRegex(ValueError, 'SOURCE_NOT_PUSHED'): launch.authorize(self.fixture())
        self.assertFalse((self.base / launch.TOKEN).exists())

    def test_partial_publication_failure_still_consumes_population(self):
        path = self.fixture()
        write = launch.write_new
        def fail_record(target, value):
            if Path(target).name == launch.LAUNCH_FILE: raise OSError('simulated publication failure')
            return write(target, value)
        with mock.patch.object(launch, 'write_new', side_effect=fail_record):
            with self.assertRaisesRegex(OSError, 'publication failure'): launch.authorize(path)
        original = (self.base / launch.TOKEN).read_bytes()
        with self.assertRaisesRegex(ValueError, 'POPULATION_ALREADY_CONSUMED'): launch.authorize(self.fixture())
        with self.assertRaisesRegex(ValueError, 'LAUNCH_RECEIPT_REQUIRED'): launch.verify(path)
        self.assertEqual(original, (self.base / launch.TOKEN).read_bytes())

    def test_crossed_receipts_refused_without_writes(self):
        path = self.fixture(); launch.authorize(path)
        target = path.parent / launch.LAUNCH_FILE
        original = target.read_bytes(); record = json.loads(original); read = launch.read
        for field, value in [('attempt_id', '0' * 32), ('stage', 'paired_commissioning'), ('declaration', {}),
            ('safety_logs', []), ('safety_contract', {}), ('freeze', {}), ('stage_reservation', {}),
            ('source_key', {}), ('runtime_binding', {}), ('context_handoff', {}),
            ('physical_acceptance_authority', True), ('official_qualification', True), ('release_authority', True)]:
            crossed = copy.deepcopy(record); crossed[field] = value
            with mock.patch.object(launch, 'read', side_effect=lambda p: crossed if p == target else read(p)):
                with self.subTest(field=field), self.assertRaises(ValueError): launch.verify(path)
        self.assertEqual(original, target.read_bytes())

    def test_incomplete_crossed_or_empty_contract_refused(self):
        original = launch.read(self.contract); read = launch.read
        for field, value in [('complete_applicable_coverage', False), ('additional_required_controls', ['pending']),
            ('population_binding_correction', {}), ('stages', []), ('total_tests', True), ('total_tests', 2), ('population', {}),
            ('schema_version', 'sporespore_r10v_safety_stage_contract_v3'), ('release_authority', True)]:
            crossed = dict(original); crossed[field] = value
            with mock.patch.object(launch, 'read', side_effect=lambda p: crossed if p == self.contract else read(p)):
                with self.subTest(field=field), self.assertRaises(ValueError): launch.contract()

    def test_missing_coverage_and_malformed_stage_specs_refuse(self):
        original = launch.read(self.contract); read = launch.read
        changes = [lambda c: c.update(coverage={}),
            lambda c: c['coverage']['construction'].update(stage_ids=['absent']),
            lambda c: c['coverage']['serialization'].update(argument=''),
            lambda c: c.update(design_sha256='sha256:' + '0' * 64),
            lambda c: c.update(candidate_profile={}),
            lambda c: c['stages'][0].update(candidate_bound=1),
            lambda c: c['stages'][0].update(timeout_seconds=True),
            lambda c: c['stages'][0].update(timeout_seconds=0),
            lambda c: c['stages'].append(copy.deepcopy(c['stages'][0]))]
        for change in changes:
            crossed = copy.deepcopy(original); change(crossed)
            with mock.patch.object(launch, 'read', side_effect=lambda p: crossed if p == self.contract else read(p)):
                with self.assertRaises(ValueError): launch.contract()
        self.assertFalse((self.base / launch.TOKEN).exists())

    def test_runtime_and_source_failures_prevent_reservation(self):
        path = self.fixture()
        with mock.patch.object(host, 'bind_runtime', side_effect=ValueError('changed actual image')):
            with self.assertRaisesRegex(ValueError, 'changed actual image'): launch.authorize(path)
        with mock.patch.object(launch.candidate, 'selection', side_effect=ValueError('source key drift')):
            with self.assertRaisesRegex(ValueError, 'source key drift'): launch.authorize(path)
        crossed = self.fixture(lambda d: d['runtime'].update(physical_execution_authorized=True))
        with self.assertRaises(ValueError): launch.authorize(crossed)
        self.assertFalse((self.base / launch.TOKEN).exists())

    def test_recorded_authorization_cannot_hide_changed_logs_or_token(self):
        path = self.fixture(); launch.authorize(path)
        token = self.base / launch.TOKEN
        token_bytes = token.read_bytes(); original = launch.read(token); read = launch.read
        for field, value in [('seed', 51008), ('attempt_id', '0' * 32), ('declaration', {}),
                             ('stage', 'first_support_diagnostic'), ('attempt_limit', 2), ('attempt_limit', True), ('ledger_scope', {})]:
            crossed = dict(original); crossed[field] = value
            with mock.patch.object(launch, 'read', side_effect=lambda p: crossed if p == token else read(p)):
                with self.assertRaisesRegex(ValueError, 'RESERVATION_IDENTITY'): launch.verify(path)
        log = path.parent / 'synthetic_control.stderr.log'
        with log.open('a', encoding='utf-8') as stream: stream.write('Retained synthetic corruption control.\n')
        with self.assertRaisesRegex(ValueError, 'GATE_LOG_BYTES'): launch.verify(path)
        self.assertEqual(token_bytes, token.read_bytes())


if __name__ == '__main__': unittest.main()
