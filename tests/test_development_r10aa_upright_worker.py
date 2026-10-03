"""Check unchanged upright control through R10AA entry and actual worker hooks."""
import json
from pathlib import Path
import sys
import unittest
import uuid
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10aa_native_component as native
import r10r_native_component as original
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared

class R10AAUprightWorker(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot
    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10aa-upright-worker-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out/'source_before.json',cls.before)
        runtime = native.read(ROOT/'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')
        path = native.verify(runtime['compiled_fixtures'])
        fixtures = original.fixtures(path,'R10R_UPRIGHT_FIXTURE')
        assert len(fixtures) == 3
        cls.input = cls.out/'source-fixtures.jsonl'
        cls.input.write_text(''.join('R10V_SOURCE_FIXTURE '+json.dumps(f)+'\n' for f in fixtures),encoding='utf-8',newline='\n')
        shared.write(cls.out/'original-fixture-binding.json',native.diagnosis.binding(path))
        print('R10AA_UPRIGHT_WORKER_ROOT '+str(cls.out),flush=True)
    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out/'source_after.json',after)
        assert after == cls.before
    def test_original_upright_law_through_new_entry_worker(self):
        result = self.run_godot('upright-worker','test_development_r10aa_upright_worker.gd',self.input,180)
        self.assertEqual(240,len(result['entry_packets']))
        self.assertEqual(63,len(result['upright_packets']))
        self.assertEqual(60,result['final_upright_memory']['standing_samples_observed'])
        self.assertEqual('fresh_selected_policy_walking_resume',result['final_state']['phase'])
        self.assertEqual('sporespore_r10aa_recovery_orchestrator_state_v1',result['final_state']['schema_version'])
        self.assertFalse(result['selector_and_launcher_validation_exercised'])
if __name__ == '__main__': unittest.main()
