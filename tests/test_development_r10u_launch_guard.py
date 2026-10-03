"""Isolated synthetic gate logs exercise the real R10U consumption guard."""
import copy
import json
from pathlib import Path
import unittest
import uuid
from unittest import mock

import test_development_r10u_complete_report as shared
import r10u_development_launch as launch


class LaunchGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = shared.EVIDENCE/('development-r10u-launch-guard-'+uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out/'source_before.json',cls.before)
        cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
        print('R10U_LAUNCH_GUARD_EVIDENCE '+str(cls.out),flush=True)

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out/'source_after.json',after)
        if after != cls.before: raise AssertionError('R10U_LAUNCH_GUARD_SOURCE_DRIFT')

    def setUp(self):
        self.base = self.out/self._testMethodName
        self.base.mkdir()
        self.real_evidence = launch.EVIDENCE
        for module in (launch,shared.development):
            patch = mock.patch.object(module,'EVIDENCE',self.base)
            patch.start(); self.addCleanup(patch.stop)
        head = self.before['head']
        self.freeze = dict(root=shared.ROOT.as_posix(),remote=launch.REMOTE,branch='main',head=head,
            origin_main=head,live_origin_main=head,clean=True)
        patch = mock.patch.object(launch,'current_freeze',return_value=self.freeze)
        self.freeze_mock = patch.start(); self.addCleanup(patch.stop)

    def fixture(self, mutate=None):
        value = shared.declaration(self.reference,self.before['head'])
        root = self.base/('development-recovery-smoke-'+value['attempt_id']);root.mkdir()
        for child in value['children']:child['evidence_path']=(root/'children'/child['role']).as_posix()
        value.update(source_snapshot=dict(head=self.before['head'],dirty=False,status=[],changed_file_bindings=[]),
            physical_acceptance_authority=False,release_authority=False,official_qualification=False,safety_stages=[])
        for spec in launch.read(launch.CONTRACT)['stages']:
            receipt = dict(id=spec['id'],passed=True,timed_out=False,exit_code=0,
                test_count=spec['tests'],expected_test_count=spec['tests'])
            for stream in ('stdout','stderr'):
                name=spec['id']+'.'+stream+'.log';path=root/name
                text = '' if stream == 'stdout' else 'Synthetic unit-test stand-in, no stages executed.\nRan '+str(spec['tests'])+' tests in 0.001s\n\nOK\n'
                with path.open('x',encoding='utf-8',newline='\n') as target:target.write(text)
                receipt[stream]=name;receipt[stream+'_sha256']=shared.development.sha(path).removeprefix('sha256:')
            value['safety_stages'].append(receipt)
        if mutate:mutate(value)
        path=root/'declaration.json';shared.write(path,value)
        return path

    def test_nested_synthetic_inputs_cannot_use_real_evidence_namespace(self):
        path=self.fixture()
        with mock.patch.object(launch,'EVIDENCE',self.real_evidence):
            with self.assertRaisesRegex(ValueError,'DECLARATION_ROOT'):launch.authorize(path)
        self.assertFalse((path.parent/launch.LAUNCH_FILE).exists())
        self.assertFalse((self.base/launch.FIRST_FILE).exists())

    def test_complete_gate_reserves_first_pair_exactly_once(self):
        path=self.fixture()
        self.assertTrue(launch.authorize(path)['first_pair_reserved'])
        self.freeze_mock.assert_called_once_with(self.before['head'])
        original=(self.base/launch.FIRST_FILE).read_bytes()
        self.assertTrue(launch.verify(path)['ok'])
        with self.assertRaisesRegex(ValueError,'ATTEMPT_ALREADY_AUTHORIZED'):launch.authorize(path)
        second=self.fixture()
        with self.assertRaisesRegex(ValueError,'FIRST_PAIR_ALREADY_CONSUMED'):launch.authorize(second)
        self.assertEqual(original,(self.base/launch.FIRST_FILE).read_bytes())
        self.assertFalse((second.parent/launch.LAUNCH_FILE).exists())

    def test_gate_omissions_false_results_and_crossed_log_bytes_refuse_before_consumption(self):
        cases=[lambda d:d.update(safety_stages=[]),
            lambda d:d['safety_stages'][0].update(passed=False),
            lambda d:d['safety_stages'][0].update(passed=1),
            lambda d:d['safety_stages'][0].update(timed_out=True),
            lambda d:d['safety_stages'][0].update(test_count=True),
            lambda d:d['safety_stages'][0].update(exit_code=1),
            lambda d:d['safety_stages'][0].update(expected_test_count=0),
            lambda d:d['safety_stages'][0].update(stdout='../crossed'),
            lambda d:d['safety_stages'][0].update(stderr_sha256='0'*64)]
        for index,mutate in enumerate(cases):
            with self.subTest(case=index),self.assertRaises(ValueError):launch.authorize(self.fixture(mutate))
            self.assertFalse((self.base/launch.FIRST_FILE).exists())

    def test_unpushed_or_dirty_source_cannot_consume_an_attempt(self):
        path=self.fixture()
        with mock.patch.object(launch,'current_freeze',side_effect=ValueError('R10U_LAUNCH_SOURCE_NOT_PUSHED')):
            with self.assertRaisesRegex(ValueError,'SOURCE_NOT_PUSHED'):launch.authorize(path)
        for mutate in [lambda d:d['source_snapshot'].update(dirty=True),
                lambda d:d['source_snapshot'].update(status=[' M file']),
                lambda d:d['source_snapshot'].update(changed_file_bindings=[{}])]:
            with self.assertRaisesRegex(ValueError,'DECLARED_SOURCE_NOT_CLEAN'):launch.authorize(self.fixture(mutate))
        self.assertFalse((self.base/launch.FIRST_FILE).exists())

    def test_independent_prerequisite_refusal_propagates_before_consumption(self):
        path=self.fixture()
        with mock.patch.object(shared.development,'validate_declaration',side_effect=ValueError('ORIGINAL_PREREQUISITE_REFUSED')) as guard:
            with self.assertRaisesRegex(ValueError,'ORIGINAL_PREREQUISITE_REFUSED'):launch.authorize(path)
            guard.assert_called_once()
        self.assertFalse((self.base/launch.FIRST_FILE).exists())

    def test_later_declared_stages_cannot_be_retried(self):
        # Isolate exclusive stage reservation from prerequisite qualification,
        # which the declaration tests exercise independently. All files stay
        # in this test's private nested namespace; no physical launch occurs.
        for stage,seed in [('additional_branch_diagnostic',41246),
                ('additional_branch_diagnostic',41241),('additional_branch_diagnostic',41243)]:
            def select(value):
                value['seed']=seed
                value['r10u_development']['stage']=stage
            with mock.patch.object(shared.development,'validate_declaration',return_value={}), mock.patch('development_recovery_smoke.declared_schedule',return_value={}):
                first=self.fixture(select)
                self.assertFalse(launch.authorize(first)['first_pair_reserved'])
                self.assertTrue(launch.verify(first)['ok'])
                token=self.base/('r10u_'+stage+'_'+str(seed)+'_consumption_v1.json')
                original=token.read_bytes()
                second=self.fixture(select)
                with self.assertRaisesRegex(ValueError,'STAGE_ALREADY_CONSUMED'):launch.authorize(second)
                self.assertEqual(original,token.read_bytes())
                self.assertFalse((second.parent/launch.LAUNCH_FILE).exists())

    def test_replay_rejects_crossed_launch_receipts_without_writes(self):
        path=self.fixture();launch.authorize(path)
        record_path=path.parent/launch.LAUNCH_FILE
        original=record_path.read_bytes();record=json.loads(original)
        original_read=launch.read
        for field,value in [('attempt_id','0'*32),('declaration',{}),('safety_logs',[]),
                ('freeze',{}),('physical_acceptance_authority',True),('first_pair_reservation',None),('stage_reservation',None)]:
            crossed=copy.deepcopy(record);crossed[field]=value
            shared.write(path.parent/('synthetic-crossed-'+field+'.json'),crossed)
            with mock.patch.object(launch,'read',side_effect=lambda p:crossed if p==record_path else original_read(p)):
                with self.subTest(field=field),self.assertRaises(ValueError):launch.verify(path)
        self.assertEqual(original,record_path.read_bytes())

    def test_crossed_gate_contract_refuses(self):
        path=self.fixture();launch.authorize(path)
        record_path=path.parent/launch.LAUNCH_FILE
        original=record_path.read_bytes();record=json.loads(original)
        original_read=launch.read
        for contract in [dict(path='unknown.json',raw_sha256='sha256:'+'0'*64),
                         launch.binding(shared.ROOT/'sdk/development/r10s_safety_stage_contract_v2.json')]:
            crossed=dict(record,safety_contract=contract)
            with mock.patch.object(launch,'read',side_effect=lambda p:crossed if p==record_path else original_read(p)):
                with self.assertRaisesRegex(ValueError,'GATE_CONTRACT'):launch.verify(path)
        self.assertEqual(original,record_path.read_bytes())

if __name__=='__main__':unittest.main()
