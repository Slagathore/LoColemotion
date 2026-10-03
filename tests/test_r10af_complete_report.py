"""Full native controller plus diagnostic replay on fresh synthetic sources only."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10af_development as identity
import r10af_host_runtime as host
import r10af_replay_host as replay_host
import development_recovery_candidate as candidate
import r10af_preflight_fixture as declaration_fixture
import r10af_contact_frame_report as diagnostic
import development_passive_entry_profile as entry

CONTROL=identity.EVIDENCE/'development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log'



def write(path,value):
    with path.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,separators=(',',':'),allow_nan=False);stream.write('\n')


class R10AFCompleteReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=identity.EVIDENCE/('r10af-complete-report-'+uuid.uuid4().hex);cls.out.mkdir()
        print('R10AF_COMPLETE_REPORT_ROOT '+str(cls.out),flush=True)
        cls.before=entry._source_snapshot();write(cls.out/'source-before.json',cls.before)
        cls.chosen=candidate.selection(identity.reference());cls.declaration=declaration_fixture.fixture(cls.before['head'])
        cls.declaration['source_snapshot']['head']=cls.before['head']
        cls.declaration['r10af_development']=identity.context(identity.SINGLE,cls.before['head'],identity.reference())
        cls.declaration['runtime']=host.expected_binding()
        identity.validate_declaration(cls.declaration)
        write(cls.out/'synthetic-declaration.json',cls.declaration)
        assert identity.sha(CONTROL)=='sha256:8b389a917370a534accc0502835a2cca66537fe1d6785f7eb5d7b27c7f3441ae'
        cls.frames=cls.out/'frame-fixtures.json'
        from types import SimpleNamespace
        result=cls.native(SimpleNamespace(out=cls.out),'frames','res://tests/test_r10af_contact_report_fixture.gd',
            [cls.out/'synthetic-declaration.json',cls.frames],timeout=60)
        assert result.returncode==0 and result.stderr==b'',result.stdout[-3000:]+result.stderr
        host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],host.expected_binding()['images']['powershell_host']['path'])

    @classmethod
    def tearDownClass(cls):
        after=entry._source_snapshot();write(cls.out/'source-after.json',after)
        assert cls.before==after

    def native(self,label,script,args,environment=None,timeout=180):
        command=[host.expected_binding()['images']['godot_engine']['path'],'--headless','--path',str(ROOT),
            '--script',script,'--',*map(str,args)]
        started=time.monotonic()
        with (self.out/(label+'.stdout.txt')).open('xb') as stdout, (self.out/(label+'.stderr.txt')).open('xb') as stderr:
            try:
                result=subprocess.run(command,cwd=ROOT,env=environment,stdout=stdout,stderr=stderr,timeout=timeout,
                    creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out/(label+'.execution.json'),dict(command=command,timed_out=True,timeout_seconds=timeout))
                raise
        result.stdout=(self.out/(label+'.stdout.txt')).read_bytes()
        result.stderr=(self.out/(label+'.stderr.txt')).read_bytes()
        write(self.out/(label+'.execution.json'),dict(command=command,returncode=result.returncode,timed_out=False,
            timeout_seconds=timeout,elapsed_seconds=time.monotonic()-started,world_build_count=0,solver_step_count=0))
        return result

    def test_complete_partial_controller_and_contact_report(self):
        fixture_path=self.out/'partial.fixture.json'
        environment=dict(os.environ,SPORE_R10AF_FIXTURE_DECLARATION=str(self.out/'synthetic-declaration.json'),
            SPORE_R10AF_FRAME_FIXTURES=str(self.frames))
        result=self.native('fixture','res://tests/test_r10af_complete_report_fixture.gd',[CONTROL,fixture_path,'partial'],environment)
        self.assertEqual(0,result.returncode,result.stdout[-3000:].decode()+result.stderr.decode())
        self.assertEqual(b'',result.stderr)
        fixed=json.loads(fixture_path.read_text())
        self.assertIs(fixed['ok'],True)
        rejected=json.loads(Path(str(fixture_path)+'.rejected.json').read_text())
        self.assertEqual('R10K_PENDING_PARTIAL_SOURCE_CROSSED',rejected['result']['failure_code'])
        self.assertEqual(1,len(rejected['link_records']))
        report=fixed['active']['report']
        identity.validate_report_header(report,self.declaration)
        expected=diagnostic.replay_report(report,self.declaration,identity)
        self.assertEqual(575,expected['diagnostic_steps_replayed'])
        path=self.out/'worker_report.json';write(path,report)
        result=self.native('replay',self.chosen['reader'],[path,identity.reference()['resource'],identity.PROFILE_SHA,self.out/'synthetic-declaration.json'])
        self.assertEqual(0,result.returncode,result.stdout[-3000:].decode()+result.stderr.decode())
        self.assertEqual(b'',result.stderr)
        marker=self.chosen['replay_marker']
        receipts=[json.loads(line[len(marker):]) for line in result.stdout.decode().splitlines() if line.startswith(marker)]
        self.assertEqual(1,len(receipts));receipt=receipts[0]
        self.assertIs(receipt['ok'],True)
        self.assertIs(receipt['complete_report_timeline_replayed'],True)
        self.assertEqual(575,receipt['transition_count'])
        self.assertEqual(expected,replay_host.independent_result(report,self.out/'synthetic-declaration.json',receipt))
        write(self.out/'complete-replay.json',receipt)
        # Either side of the combined audit must still refuse independently.
        for label in ('controller-missing','capture-missing','source-crossed'):
            changed=copy.deepcopy(report)
            if label=='controller-missing':changed['passive_entry']['orchestrator_transitions'].pop()
            elif label=='capture-missing':changed['r10af_contact_frames']['records'].pop()
            else:changed['r10af_contact_frame_links']['records'][300]['source_trace']['contact_source_sha256']='sha256:'+'0'*64
            changed_path=self.out/(label+'.json');write(changed_path,changed)
            refused=self.native(label,self.chosen['reader'],[changed_path,identity.reference()['resource'],identity.PROFILE_SHA,self.out/'synthetic-declaration.json'])
            self.assertEqual(1,refused.returncode,refused.stderr.decode())
            self.assertEqual(b'',refused.stderr)
            rows=[json.loads(line[len(marker):]) for line in refused.stdout.decode().splitlines() if line.startswith(marker)]
            self.assertEqual(1,len(rows));self.assertIs(rows[0]['ok'],False)


if __name__=='__main__':unittest.main()
