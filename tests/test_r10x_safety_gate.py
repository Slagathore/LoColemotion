"""Synthetic original-log corruption controls; no stage or world is launched."""
import copy
import json
from pathlib import Path
import sys
import unittest
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10x_safety_gate as safety


class SafetyGate(unittest.TestCase):
    def setUp(self):
        self.root=safety.authority.EVIDENCE/('r10x-safety-controls-'+uuid.uuid4().hex);self.root.mkdir()
        self.specs=[dict(id='synthetic',tests=2)]
        self.stages=[dict(id='synthetic',passed=True,timed_out=False,exit_code=0,test_count=2,expected_test_count=2)]
        for stream,text in [('stdout','Synthetic receipt control only; no actual tests represented.\n'),('stderr','Ran 2 tests in 0.001s\n\nOK\n')]:
            name='synthetic.'+stream+'.log';(self.root/name).write_text(text,encoding='utf-8')
            self.stages[0][stream]=name
            self.stages[0][stream+'_sha256']=safety.authority.sha((self.root/name).read_bytes()).removeprefix('sha256:')

    def test_exact_original_population(self):
        self.assertEqual(safety.validate_stages(self.root,self.stages,self.specs),2)

    def test_missing_extra_and_reordered_stages_refuse(self):
        for value in ([],self.stages*2,[dict(self.stages[0],id='different')]):
            with self.subTest(value=value),self.assertRaises(ValueError):safety.validate_stages(self.root,value,self.specs)

    def test_typed_failure_counts_and_flags_refuse(self):
        for key,value in [('passed',1),('timed_out',0),('exit_code',False),('test_count',True),('expected_test_count',1),('passed',False)]:
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):
                safety.validate_stages(self.root,[dict(self.stages[0],**{key:value})],self.specs)

    def test_crossed_bytes_and_paths_refuse(self):
        for key,value in [('stdout','../crossed.log'),('stderr_sha256','0'*64)]:
            with self.subTest(key=key),self.assertRaises(ValueError):
                safety.validate_stages(self.root,[dict(self.stages[0],**{key:value})],self.specs)

    def test_rehashed_failed_or_duplicated_output_refuses(self):
        for text in ['Ran 2 tests in 0.1s\nFAILED\n','Ran 1 test in 0.1s\nOK\n','Ran 2 tests in 0.1s\nOK\nOK\n','Ran 2 tests in 0.1s\nOK\nERROR: hidden failure\n']:
            path=self.root/'synthetic.stderr.log';path.write_text(text,encoding='utf-8')
            value=copy.deepcopy(self.stages);value[0]['stderr_sha256']=safety.authority.sha(path.read_bytes()).removeprefix('sha256:')
            with self.subTest(text=text),self.assertRaises(ValueError):safety.validate_stages(self.root,value,self.specs)

    def test_declared_bounds_and_pending_integration_are_enforced(self):
        value=safety.contract()
        self.assertLess(sum(s['timeout_seconds'] for s in value['stages'])+150,30000)
        if value['additional_required_controls']:
            with self.assertRaisesRegex(ValueError,'INTEGRATION_CONTROLS_PENDING'):safety.contract(complete=True)
        else:self.assertEqual(safety.contract(complete=True),value)


if __name__=='__main__':unittest.main()
