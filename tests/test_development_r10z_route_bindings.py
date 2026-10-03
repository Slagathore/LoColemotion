"""Actual successor DLL policy identities and bounded prospective route selection."""
from pathlib import Path
import sys
import unittest
import uuid
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10z_native_component as native
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared

class R10ZRouteBindings(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot
    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10z-route-bindings-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out/'source_before.json',cls.before)
        original = native.read(ROOT/'sdk/recovery/r10v_v56_walking_route_contract_v2.json')
        cls.input = native.verify(next(x for x in original['policy_binding_evidence'] if x['path'].endswith('/profile.request.json')))
        shared.write(cls.out/'input-binding.json',native.diagnosis.binding(cls.input))
        print('R10Z_ROUTE_BINDINGS_ROOT ' + str(cls.out),flush=True)
    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out/'source_after.json',after)
        assert after == cls.before
    def test_actual_dll_and_prospective_route(self):
        result = self.run_godot('policy-bindings','test_development_r10z_route_bindings.gd',self.input,60)
        self.assertEqual(4,len(result['calls']))
        self.assertTrue(result['checks']['phase248_selected'])
        self.assertTrue(result['checks']['undeclared_seeds_refused'])
        old = native.read(ROOT/'sdk/recovery/r10v_post_recovery_settling_finite_cycle_contract_v2.json')
        new = native.read(ROOT/'sdk/recovery/r10z_partial_pose_geometry_finite_cycle_contract_v1.json')
        for key in ('limits','finite_walking_observable','settled_tail','whole_walking_envelope','partial_recovery','prone_recovery','upright_recovery','native_interaction','post_recovery_hold'):
            self.assertEqual(old[key],new[key],key)
        self.assertEqual([51008],[new['prospective_populations']['development']['first_probe']['seed']])
        self.assertFalse(new['prospective_populations']['held_out']['declared'])
if __name__ == '__main__': unittest.main()
