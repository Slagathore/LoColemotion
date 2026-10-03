"""Retained raw log corruption controls; no qualification or world is created."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10w_campaign_authority as authority
import r10w_qualification as qualification


def fixture():
    logs = {'component.stdout.log': b'retained native component\n',
            'component.stderr.log': b'Ran 8 tests in 1.2s\n\nOK\n'}
    spec = [dict(id='component', tests=8)]
    actual = [dict(id='component', passed=True, exit_code=0, timed_out=False, test_count=8, expected_test_count=8,
                   stdout='component.stdout.log', stderr='component.stderr.log',
                   stdout_sha256=authority.sha(logs['component.stdout.log'])[7:],
                   stderr_sha256=authority.sha(logs['component.stderr.log'])[7:])]
    return actual, spec, logs


class Qualification(unittest.TestCase):
    def host_fixture(self):
        root=authority.EVIDENCE/('r10w-qualification-controls-'+uuid.uuid4().hex);root.mkdir()
        request=root/'synthetic_request.json'
        original=dict(source_snapshot=dict(head='1'*40),attempt_id='2'*32,mode='development_ghost',prehost_qualification={'synthetic':True})
        qualification.files.write_new(request,original)
        for name in ('supervisor_result.json','host_result.json','published.json'):
            qualification.files.write_new(root/name,dict(synthetic_zero_world_fixture=True))
        receipt=dict(original,r10w_host=dict(request=qualification.files.bind(request)))
        status=dict(state='complete',host_alive=False,result=dict(primary_terminal=qualification.files.bind(root/'supervisor_result.json')))
        return root,receipt,status

    def test_original_host_must_be_complete_published_and_gone(self):
        root,receipt,status=self.host_fixture()
        with patch.object(qualification.host,'status',return_value=status):
            observed=qualification.validate_completed_host(root,receipt)
        self.assertEqual(observed['prehost'],receipt['prehost_qualification'])
        self.assertEqual(observed['result'],qualification.files.bind(root/'host_result.json'))

    def test_running_failed_unpublished_or_live_host_refuses(self):
        root,receipt,status=self.host_fixture()
        for state,alive in [('running',True),('failed',False),('incomplete',False),('publishing',True),('complete',True)]:
            with self.subTest(state=state,alive=alive),patch.object(qualification.host,'status',return_value=dict(status,state=state,host_alive=alive)):
                with self.assertRaisesRegex(ValueError,'HOST_INCOMPLETE'):qualification.validate_completed_host(root,receipt)

    def test_crossed_primary_source_attempt_mode_or_prehost_refuses(self):
        root,receipt,status=self.host_fixture()
        with patch.object(qualification.host,'status',return_value=status):
            for field,value in [('source_snapshot',dict(head='0'*40)),('attempt_id','0'*32),('mode','held_out_finite_decision'),('prehost_qualification',{})]:
                with self.subTest(field=field),self.assertRaisesRegex(ValueError,'HOST_CONTEXT'):
                    qualification.validate_completed_host(root,dict(receipt,**{field:value}))
        with patch.object(qualification.host,'status',return_value=dict(status,result=dict(primary_terminal={}))):
            with self.assertRaisesRegex(ValueError,'HOST_PRIMARY'):qualification.validate_completed_host(root,receipt)

    def test_missing_host_or_changed_request_bytes_cannot_qualify(self):
        root,receipt,status=self.host_fixture()
        with self.assertRaisesRegex(ValueError,'HOST_MISSING'):qualification.validate_completed_host(root,{})
        request=Path(receipt['r10w_host']['request']['path'])
        request.write_text('{"synthetic_changed":true}',encoding='utf-8')
        with self.assertRaises(ValueError):qualification.validate_completed_host(root,receipt)

    def test_exact_raw_logs_and_actual_population(self):
        actual, spec, logs = fixture()
        self.assertEqual(8, qualification.validate_stage_stream(actual, spec, logs.__getitem__))

    def test_missing_extra_failed_timed_out_and_boolean_counts_refuse(self):
        for defect in ('missing', 'extra', 'failed', 'timeout', 'boolean'):
            actual, spec, logs = fixture()
            if defect == 'missing': actual = []
            elif defect == 'extra': actual += copy.deepcopy(actual)
            elif defect == 'failed': actual[0]['exit_code'] = 1
            elif defect == 'timeout': actual[0]['timed_out'] = True
            else: actual[0]['test_count'] = True
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                qualification.validate_stage_stream(actual, spec, logs.__getitem__)

    def test_changed_or_rebound_failing_raw_log_refuses(self):
        for rebound in (False, True):
            actual, spec, logs = fixture()
            logs['component.stderr.log'] = b'Ran 8 tests in 1.2s\n\nFAILED (failures=1)\n'
            if rebound: actual[0]['stderr_sha256'] = authority.sha(logs['component.stderr.log'])[7:]
            with self.subTest(rebound=rebound), self.assertRaises(ValueError):
                qualification.validate_stage_stream(actual, spec, logs.__getitem__)

    def test_path_escape_duplicate_result_and_partial_count_refuse(self):
        for defect in ('path', 'duplicate', 'count'):
            actual, spec, logs = fixture()
            if defect == 'path': actual[0]['stdout'] = '../component.stdout.log'
            else:
                logs['component.stderr.log'] = logs['component.stderr.log']*2 if defect == 'duplicate' else b'Ran 7 tests in 1.2s\n\nOK\n'
                actual[0]['stderr_sha256'] = authority.sha(logs['component.stderr.log'])[7:]
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                qualification.validate_stage_stream(actual, spec, logs.__getitem__)


if __name__ == '__main__':
    unittest.main()
