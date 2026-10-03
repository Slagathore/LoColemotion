"""Isolated synthetic gate logs exercise the real R10S consumption guard."""
import copy
import json
from pathlib import Path
import unittest
import uuid
from unittest import mock

import test_development_r10s_complete_report as shared
import r10s_development_launch as launch


class LaunchGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = shared.EVIDENCE/('development-r10s-launch-guard-'+uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out/'source_before.json',cls.before)
        cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
        print('R10S_LAUNCH_GUARD_EVIDENCE '+str(cls.out),flush=True)

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out/'source_after.json',after)
        if after != cls.before: raise AssertionError('R10S_LAUNCH_GUARD_SOURCE_DRIFT')

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

    def test_complete_gate_reserves_first_single_exactly_once(self):
        path=self.fixture()
        self.assertTrue(launch.authorize(path)['first_single_reserved'])
        self.freeze_mock.assert_called_once_with(self.before['head'])
        original=(self.base/launch.FIRST_FILE).read_bytes()
        self.assertTrue(launch.verify(path)['ok'])
        with self.assertRaisesRegex(ValueError,'ATTEMPT_ALREADY_AUTHORIZED'):launch.authorize(path)
        second=self.fixture()
        with self.assertRaisesRegex(ValueError,'FIRST_SINGLE_ALREADY_CONSUMED'):launch.authorize(second)
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
        with mock.patch.object(launch,'current_freeze',side_effect=ValueError('R10S_LAUNCH_SOURCE_NOT_PUSHED')):
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
        for stage,seed in [('paired_commissioning',41046),('additional_branch_diagnostic',41045),
                ('additional_branch_diagnostic',41041),('additional_branch_diagnostic',41043)]:
            def select(value):
                value['seed']=seed
                value['r10s_development']['stage']=stage
            with mock.patch.object(shared.development,'validate_declaration',return_value={}):
                first=self.fixture(select)
                self.assertFalse(launch.authorize(first)['first_single_reserved'])
                self.assertTrue(launch.verify(first)['ok'])
                token=self.base/('r10s_'+stage+'_'+str(seed)+'_consumption_v1.json')
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
                ('freeze',{}),('physical_acceptance_authority',True),('first_single_reservation',None),('stage_reservation',None)]:
            crossed=copy.deepcopy(record);crossed[field]=value
            shared.write(path.parent/('synthetic-crossed-'+field+'.json'),crossed)
            with mock.patch.object(launch,'read',side_effect=lambda p:crossed if p==record_path else original_read(p)):
                with self.subTest(field=field),self.assertRaises(ValueError):launch.verify(path)
        self.assertEqual(original,record_path.read_bytes())

    def test_original_contract_remains_required_for_historical_launches(self):
        with mock.patch.object(launch,'CONTRACT',launch.LEGACY_CONTRACT):
            path=self.fixture();launch.authorize(path)
        record_path=path.parent/launch.LAUNCH_FILE
        original=record_path.read_bytes();record=json.loads(original)
        self.assertEqual(launch.binding(launch.LEGACY_CONTRACT),record['safety_contract'])
        self.assertTrue(launch.verify(path)['ok'])
        original_read=launch.read
        for replacement in [launch.binding(launch.CONTRACT),dict(path='unknown.json',raw_sha256='0'*64),
                dict(launch.binding(launch.LEGACY_CONTRACT),raw_sha256='sha256:'+'0'*64)]:
            crossed=dict(record,safety_contract=replacement)
            with mock.patch.object(launch,'read',side_effect=lambda p:crossed if p==record_path else original_read(p)):
                with self.assertRaisesRegex(ValueError,'GATE'):launch.verify(path)
        self.assertEqual(original,record_path.read_bytes())

    def test_timeout_successor_preserves_failed_gate_and_physical_contracts(self):
        old=launch.read(launch.LEGACY_CONTRACT);new=launch.read(launch.CONTRACT)
        expected=copy.deepcopy(old)
        expected.update(schema_version='sporespore_r10s_safety_stage_contract_v2',total_tests=194,
            predecessor_contract=dict(path=launch.LEGACY_CONTRACT.relative_to(shared.ROOT).as_posix(),
                raw_sha256=launch.LEGACY_CONTRACT_SHA),revision_reason=new['revision_reason'])
        expected['stage_timeout_overrides_seconds']['r10s_native_control']=600
        next(s for s in expected['stages'] if s['id']=='r10s_launch_guard')['tests']=9
        self.assertEqual(expected,new)
        record=launch.read(shared.ROOT/'sdk/recovery/r10s_phase245_zero_world_timeout_v1.json')
        for item in record['bindings']+[record['source_contract'],record['safety_contract']]:
            path=Path(item['path'])
            self.assertEqual(item['byte_length'],path.stat().st_size)
            self.assertEqual(item['raw_sha256'],shared.development.sha(path))
        self.assertEqual(launch.LEGACY_CONTRACT_SHA,record['safety_contract']['raw_sha256'])
        supervisor=launch.read(Path(record['gate_root'])/'supervisor_result.json')
        execution=launch.read(Path(record['outer_root'])/'execution.json')
        self.assertEqual('SMOKE_SAFETY_GATE_FAILED:r10s_native_control',supervisor['failure_code'])
        self.assertEqual(record['failed_stage'],supervisor['safety_stages'][-1])
        self.assertTrue(record['failed_stage']['timed_out'])
        self.assertEqual(-1,record['failed_stage']['exit_code'])
        self.assertFalse(supervisor['physical_attempt_started'])
        self.assertFalse(execution['physical_consumption_record_exists'])
        self.assertFalse(record['physical_identity_consumed'])
        self.assertFalse(record['original_results_reclassified'])


if __name__ == '__main__':unittest.main()
