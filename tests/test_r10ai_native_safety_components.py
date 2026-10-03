"""Fresh selected-DLL V25, legacy compatibility and AI scheduler controls."""
import copy,json,sys,unittest,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ai_gate_support as native
from sporespore_locomotion import LocomotionCoreError

class R10AINativeSafetyComponents(unittest.TestCase):
    run_godot=native.run_godot
    @classmethod
    def setUpClass(cls):
        cls.out=native.EVIDENCE/('r10ai-native-safety-'+uuid.uuid4().hex);cls.out.mkdir()
        print('R10AI_NATIVE_SAFETY_ROOT '+str(cls.out),flush=True)
        cls.before=native.entry._source_snapshot();native.write(cls.out/'source-before.json',cls.before)
        cls.runtime,cls.fixtures=native.runtime()
    @classmethod
    def tearDownClass(cls):
        after=native.entry._source_snapshot();native.write(cls.out/'source-after.json',after);assert cls.before==after
    def test_v25_selected_dll_and_crossed_inputs(self):
        core=native.ExactInputCore(self.runtime['runtime']['path']);rows=[]
        for label,method,request,expected in native.interface.cases(self.fixtures):
            result=error=None
            try:result=core._call_json_input(method,request)
            except LocomotionCoreError as failure:error=failure.failure_code
            rows.append(dict(id=label,method=method,request=request,response_raw_utf8=core.raw_response.decode(),failure_code=error))
            if expected is None:self.assertIsNone(result);self.assertTrue(error)
            else:self.assertIsNone(error);self.assertEqual(expected,result)
        self.assertEqual(24,len(rows));native.write(self.out/'v25-native-calls.json',rows)
    def test_original_partial_calls_unchanged_on_selected_dll(self):
        record=native.read(ROOT/'sdk/recovery/r10aa_partial_native_component_v1.json')
        path=native.verify(next(r for r in record['retained_evidence'] if r['path'].endswith('/native_calls.jsonl')))
        core=native.ExactInputCore(self.runtime['runtime']['path']);rows=[]
        for line in path.read_text().splitlines():
            row=json.loads(line)
            if row['group']!='original_partial_calls':continue
            core._call_json_input(row['method'],row['request_raw_utf8'].encode())
            self.assertEqual(row['response_raw_utf8'].encode(),core.raw_response)
            rows.append(dict(identity=row['identity'],method=row['method'],response_raw_utf8=core.raw_response.decode()))
        self.assertEqual(20,len(rows));native.write(self.out/'original-calls.json',dict(input=native.diagnosis.binding(path),calls=rows))
    def test_ai_orchestrator_clocks_sources_and_mutations(self):
        record=native.read(ROOT/'sdk/recovery/r10ai_worker_source_component_v1.json')
        paths = {name: native.verify(next(r for r in record['evidence'] if r['path'].endswith('/'+name+'.json')))
                 for name in ('partial', 'prone')}
        partial=native.read(paths['partial'])['transitions']
        prone=native.read(paths['prone'])['transitions']
        cases=dict(entry=partial[1], handoff=partial[240], partial=partial[241], complete=partial[303], prone=prone[1])
        path=self.out/'orchestrator-input.json';native.write(path,cases)
        native.write(self.out/'orchestrator-original-bindings.json',[native.diagnosis.binding(p) for p in paths.values()])
        result=self.run_godot('orchestrator','test_development_r10ai_orchestrator_refusals.gd',path,120)
        self.assertEqual(61,len(result['checks']))

if __name__=='__main__':unittest.main()
