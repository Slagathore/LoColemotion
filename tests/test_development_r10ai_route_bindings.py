"""Actual successor DLL policy identities and bounded prospective route selection."""
from pathlib import Path
import sys
import unittest
import uuid
import copy
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ai_gate_support as native
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared

class R10AIRouteBindings(unittest.TestCase):
    run_godot = native.run_godot
    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10ai-route-bindings-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out/'source_before.json',cls.before)
        original = native.read(ROOT/'sdk/recovery/r10v_v56_walking_route_contract_v2.json')
        cls.input = native.verify(next(x for x in original['policy_binding_evidence'] if x['path'].endswith('/profile.request.json')))
        shared.write(cls.out/'input-binding.json',native.diagnosis.binding(cls.input))
        print('R10AI_ROUTE_BINDINGS_ROOT ' + str(cls.out),flush=True)
    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out/'source_after.json',after)
        assert after == cls.before
    def test_actual_dll_and_prospective_route(self):
        result = self.run_godot('policy-bindings','test_development_r10ai_route_bindings.gd',self.input,60)
        self.assertEqual(4,len(result['calls']))
        self.assertTrue(result['checks']['phase248_selected'])
        self.assertTrue(result['checks']['undeclared_seeds_refused'])
        old = native.read(ROOT/'sdk/recovery/r10v_post_recovery_settling_finite_cycle_contract_v2.json')
        new = native.read(ROOT/'sdk/recovery/r10ai_concurrent_load_rise_finite_cycle_contract_v1.json')
        old['limits'] = dict(old['limits'], child_wall_time_limit_seconds=2400, independent_reader_wall_time_limit_seconds=1200)
        self.assertEqual(2400, native.read(native.identity.DESIGN)['limits']['child_wall_time_limit_seconds'])
        self.assertEqual(1200, native.read(native.identity.DESIGN)['limits']['independent_reader_wall_time_limit_seconds'])
        for key in ('limits','finite_walking_observable','settled_tail','whole_walking_envelope','partial_recovery','prone_recovery','upright_recovery','native_interaction','post_recovery_hold'):
            self.assertEqual(old[key],new[key],key)
        development = new['prospective_populations']['development']
        design = native.read(native.identity.DESIGN)
        self.assertEqual(67248, development['first_probe']['seed'])
        self.assertEqual(native.identity.SEED, development['first_probe']['seed'])
        self.assertEqual(design['first_probe']['seed'], development['first_probe']['seed'])
        self.assertFalse(new['prospective_populations']['held_out']['declared'])
if __name__ == '__main__': unittest.main()
