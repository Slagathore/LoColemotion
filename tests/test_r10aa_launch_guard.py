"""Isolated synthetic receipts exercise one-use reservation, never a real gate."""
import copy
import json
from pathlib import Path
import unittest
import uuid
from unittest import mock

import test_development_r10aa_complete_report as shared
import r10aa_development_launch as launch


class R10AALaunchGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = shared.native.EVIDENCE / ('r10aa-launch-guard-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
        print('R10AA_LAUNCH_GUARD_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before

    def setUp(self):
        self.base = self.out / self._testMethodName
        self.base.mkdir()
        self.real_evidence, self.real_contract = launch.EVIDENCE, launch.CONTRACT
        for module in (launch, shared.development):
            patch = mock.patch.object(module, 'EVIDENCE', self.base)
            patch.start(); self.addCleanup(patch.stop)
        self.contract = self.base / 'synthetic-contract.json'
        shared.write(self.contract, dict(schema_version=launch.read(self.real_contract)['schema_version'],
            population=dict(seed=51008, roles=shared.development.ROLES, mode=shared.development.SINGLE),
            complete_applicable_coverage=True, additional_required_controls=[],
            stages=[dict(id='synthetic_control', pattern='test_synthetic.py', tests=1)], total_tests=1,
            physical_acceptance_authority=False, release_authority=False))
        patch = mock.patch.object(launch, 'CONTRACT', self.contract)
        patch.start(); self.addCleanup(patch.stop)
        head = self.before['head']
        self.freeze = dict(root=shared.ROOT.as_posix(), remote=launch.REMOTE, branch='main',
            head=head, origin_main=head, live_origin_main=head, clean=True)
        patch = mock.patch.object(launch, 'current_freeze', return_value=self.freeze)
        self.freeze_mock = patch.start(); self.addCleanup(patch.stop)

    def fixture(self, mutate=None):
        value = shared.declaration(self.reference, self.before['head'])
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
            receipt[stream + '_sha256'] = shared.development.sha(path).removeprefix('sha256:')
        value['safety_stages'] = [receipt]
        if mutate: mutate(value)
        path = root / 'declaration.json'
        shared.write(path, value)
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
        for mutate in [lambda d: d.update(seed=51007),
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
            ('physical_acceptance_authority', True), ('official_qualification', True), ('release_authority', True)]:
            crossed = copy.deepcopy(record); crossed[field] = value
            with mock.patch.object(launch, 'read', side_effect=lambda p: crossed if p == target else read(p)):
                with self.subTest(field=field), self.assertRaises(ValueError): launch.verify(path)
        self.assertEqual(original, target.read_bytes())

    def test_incomplete_crossed_or_empty_contract_refused(self):
        original = launch.read(self.contract); read = launch.read
        for field, value in [('complete_applicable_coverage', False), ('additional_required_controls', ['pending']),
            ('stages', []), ('total_tests', True), ('total_tests', 2), ('population', {}),
            ('schema_version', 'sporespore_r10v_safety_stage_contract_v3'), ('release_authority', True)]:
            crossed = dict(original); crossed[field] = value
            with mock.patch.object(launch, 'read', side_effect=lambda p: crossed if p == self.contract else read(p)):
                with self.subTest(field=field), self.assertRaises(ValueError): launch.contract()


if __name__ == '__main__': unittest.main()
