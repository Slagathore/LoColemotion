"""Fresh diagnostic engine controls, under the calling supervisor operation lock.

All packets are synthetic. No test builds a physics world or steps a solver.
Historical sidecar inputs exercise unchanged readers, not past qualification.
"""
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10af_host_runtime as host
import r10af_development as identity
import r10af_selection_check as selection
import r10ac_contact_report_check as reports
import r10ac_contact_frame_replay as capture
import development_passive_entry_profile as entry


def write(path,value):
    with path.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,indent=2);stream.write('\n')


class R10AFNativeInterfaces(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=identity.EVIDENCE/('r10af-native-interfaces-'+uuid.uuid4().hex)
        cls.out.mkdir();print('R10AF_NATIVE_INTERFACES_ROOT '+str(cls.out),flush=True)
        cls.before=entry._source_snapshot();write(cls.out/'source-before.json',cls.before)
        expected=host.expected_binding()
        cls.runtime=host.bind_runtime(expected['images']['godot_console']['path'],expected['images']['powershell_host']['path'])
        cls.engine=cls.runtime['images']['godot_engine']['path']
        write(cls.out/'runtime.json',cls.runtime)
        selection.candidate.selection(identity.reference())

    @classmethod
    def tearDownClass(cls):
        after=entry._source_snapshot();write(cls.out/'source-after.json',after)
        assert after==cls.before

    def run_retained(self,label,command):
        # No nested lock: the complete safety supervisor owns the operation.
        record=dict(command=command,working_directory=str(ROOT),timeout_seconds=120)
        write(self.out/(label+'.command.json'),record)
        try:
            result=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=120,
                creationflags=subprocess.CREATE_NO_WINDOW)
        except subprocess.TimeoutExpired as error:
            (self.out/(label+'.stdout.log')).write_bytes(error.stdout or b'')
            (self.out/(label+'.stderr.log')).write_bytes(error.stderr or b'')
            write(self.out/(label+'.execution.json'),dict(timed_out=True))
            raise
        (self.out/(label+'.stdout.log')).write_bytes(result.stdout)
        (self.out/(label+'.stderr.log')).write_bytes(result.stderr)
        write(self.out/(label+'.execution.json'),dict(exit_code=result.returncode,timed_out=False))
        self.assertEqual(0,result.returncode,result.stderr.decode('utf-8',errors='replace'))
        self.assertEqual(b'',result.stderr)
        return result.stdout.decode('utf-8')

    def native(self,label,script,*args):
        return self.run_retained(label,[self.engine,'--headless','--path',str(ROOT),
            '--log-file',str(self.out/(label+'.engine.log')),'--script','res://'+script,*map(str,args)])

    def test_actual_candidate_selection_and_worker_reader_parsing(self):
        case=self.out/'selection';case.mkdir()
        write(case/'fixture.json',selection.fixture())
        self.native('worker-parse','sdk/adapters/godot/gdscript/r10af_development_worker_v1.gd','--check-only')
        self.native('reader-parse','sdk/trace_analysis/r10af_recovery_replay.gd','--check-only')
        self.native('selection','tests/test_r10af_selection.gd','--',case/'fixture.json',case/'native.json')
        result=json.loads(self.run_retained('selection-verify',[sys.executable,'-B',selection.__file__,'--verify',str(case/'native.json')]))
        self.assertEqual(30,result['native_checks']);self.assertIs(result['ok'],True)
        write(case/'verification.json',result)

    def test_native_observer_api_and_snapshot_negative_controls(self):
        output=self.native('observer','tests/test_r10ac_contact_frames_zero_world.gd')
        rows=[line.split(' ',1)[1] for line in output.splitlines() if line.startswith('R10AC_CONTACT_FRAMES_ZERO_WORLD ')]
        self.assertEqual(1,len(rows));value=json.loads(rows[0])
        self.assertIs(value['ok'],True);self.assertEqual(3,value['native_invalid_rid_refusals'])
        self.assertEqual(2,value['synthetic_positive_cases']);self.assertEqual(39,value['synthetic_negative_cases'])
        self.assertEqual(0,value['world_build_count']);self.assertEqual(0,value['solver_step_count'])
        write(self.out/'observer-result.json',value)

    def test_contact_capture_and_independent_packet_replay(self):
        path=self.out/'capture-fixtures.json'
        self.native('capture','tests/test_r10ac_contact_frame_capture.gd','--',path)
        value=json.loads(path.read_text(encoding='utf-8-sig'))
        self.assertIs(value['ok'],True)
        self.assertEqual(5,value['summary']['positive_cases']);self.assertEqual(29,value['summary']['negative_cases'])
        result=capture.check_fixture_result(path)
        # The fifth native positive checks disabled-by-default capture and emits no packet.
        self.assertEqual(4,result['independent_positive_replays']);self.assertEqual(29,result['independent_negative_refusals'])
        write(self.out/'capture-replay.json',result)

    def test_sidecar_hash_chain_and_independent_report_refusals(self):
        case=self.out/'report';case.mkdir()
        write(case/'fixture.json',reports.fixtures())
        self.native('report','tests/test_r10ac_contact_frame_report.gd','--',case/'fixture.json',case/'native.json')
        result=json.loads(self.run_retained('report-verify',[sys.executable,'-B',reports.__file__,'--verify',str(case/'native.json')]))
        self.assertIs(result['ok'],True);self.assertEqual(3,result['positive_cases'])
        self.assertEqual(40,result['negative_cases'])
        write(case/'verification.json',result)


if __name__=='__main__':unittest.main()
