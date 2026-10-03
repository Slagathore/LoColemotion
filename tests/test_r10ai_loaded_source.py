"""Exact exposed V23 loaded inputs through the selected DLL and source bridge.
No observations, controller identities or historical result interpretations change.
"""
import json,sys,unittest,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ai_gate_support as native
import r10aa_first_support_closure as previous
class R10AILoadedSource(unittest.TestCase):
    run_godot=native.run_godot
    def test_loaded_source_and_crossed_contract_refusals(self):
        self.out=native.EVIDENCE/('r10ai-loaded-source-'+uuid.uuid4().hex);self.out.mkdir();print('R10AI_LOADED_SOURCE_ROOT '+str(self.out),flush=True)
        before=native.entry._source_snapshot();native.write(self.out/'source-before.json',before)
        runtime,_=native.runtime();core=native.ExactInputCore(runtime['runtime']['path']);rows=[]
        for kind,packet in previous.partial_records(previous.CHILD/'worker_report.json'):
            if kind!='packet' or (packet['native_receipt'].get('next_load_plan') or {}).get('mode')!='loaded_geometry_rise':continue
            request=json.loads(packet['call']['request']['utf8_text'])
            result=core._call_json_input('ss_recovery_r10aa_partial_step_control_v1_json',request)
            self.assertEqual(packet['native_receipt'],result)
            rows.append(dict(request=request,expected=result,native_response_utf8=core.raw_response.decode()))
        self.assertEqual(44,len(rows));path=self.out/'fixtures.json'
        native.write(path,dict(original_report=native.diagnosis.binding(previous.CHILD/'worker_report.json'),fixtures=rows,changed_fields=[],world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False))
        result=self.run_godot('loaded-source','test_r10ai_loaded_source.gd',path,120)
        self.assertEqual(44,result['loaded_inputs']);self.assertEqual(352,result['negative_checks'])
        after=native.entry._source_snapshot();native.write(self.out/'source-after.json',after);self.assertEqual(before,after)
if __name__=='__main__':unittest.main()
