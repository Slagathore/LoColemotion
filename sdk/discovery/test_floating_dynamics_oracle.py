"""Zero-world coordinate, corruption, launch and retained-input controls."""
import copy
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
from test_actuation_recovery_mechanics import specimen
from floating_base_dynamics import FloatingDynamics
from floating_base_dynamics_inputs import C
from floating_dynamics_oracle_math import compare,velocity_map,unchanged_state
import floating_dynamics_oracle_task as task
from audit_floating_dynamics_oracle import audit


class OracleControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.contract=task.declaration()

    def setUp(self):
        self.model=FloatingDynamics(specimen(),[.01,.02]);self.p=[.1,.2,.3]
        self.q=[0.,0.,np.sin(.3),np.cos(.3)];self.j=[.2,-.4]
        self.v=np.linspace(-.5,1.,8);self.a=np.linspace(-.2,.3,8);self.g=[0.,-10.,0.]
        frame=self.model.tree.kinematics(self.p,self.q,self.j);r=C.T @ frame["rotations"][0] @ C
        t,_=velocity_map(r,2,self.v);value=self.model.evaluate(self.p,self.q,self.j,self.v,self.a,self.g)
        self.native=dict(root_rotation=r.tolist(),qvel=(t @ self.v).tolist(),
            mass_matrix=(t @ value["mass_matrix"] @ t.T).tolist(),
            bias=(t @ value["bias"]).tolist(),gravity_bias=(t @ value["gravity_force"]).tolist(),
            passive_force=(t @ value["passive_generalized_force"]).tolist())
        self.c=copy.deepcopy(self.contract);self.source="0"*40;self.attempt="sdk2-floating-dynamics-oracle-synthetic"
        self.owner=dict(source_commit=self.source,contract=self.c,source_status=[],**{k:False for k in task.FLAGS})
        self.gate=dict(ok=True,source_commit=self.source,declaration_sha256="declaration",
            safety_controls={**{n:k for n,_,k in task.GATES},"containment":1},
            preflight=dict(ok=True,component_evidence_verified=True,states=132,world_build_count=0,solver_steps=0))
        self.consumed=dict(attempt_id=self.attempt,source_commit=self.source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256="declaration",gate_receipt_sha256="gate",trials=self.c["trials"])

    def check(self):return compare(self.model,self.p,self.q,self.j,self.v,self.g,self.a,self.native)
    def launch(self):task.validate_launch(self.owner,self.gate,self.consumed,self.c,self.source,self.attempt,"declaration","gate")
    def data(self):return SimpleNamespace(qpos=np.arange(9.),qvel=np.arange(8.),time=.5)

    def test_01_complete_coordinate_comparison(self):self.assertLess(max(self.check()["maximum_errors"].values()),1e-12)
    def test_02_rotated_free_root_velocity(self):
        t,_=velocity_map(np.array(self.native["root_rotation"]),2,self.v)
        np.testing.assert_allclose(t[:3,:3],C.T);np.testing.assert_allclose(t[3:6,3:6] @ self.v[3:6],
            np.array(self.native["root_rotation"]).T @ C.T @ self.v[3:6])
        self.assertFalse(np.allclose(t[3:6,3:6],C.T))
    def test_03_acceleration_frame_offset(self):
        _,offset=velocity_map(np.array(self.native["root_rotation"]),2,self.v)
        np.testing.assert_allclose(offset,0,atol=1e-15)
    def test_04_changed_mass_refused(self):
        self.native["mass_matrix"][0][0]+=.01
        with self.assertRaises(ValueError):self.check()
    def test_05_changed_gravity_refused(self):
        self.native["gravity_bias"][0]+=.01
        with self.assertRaises(ValueError):self.check()
    def test_06_changed_velocity_bias_refused(self):
        self.native["bias"][6]+=.01
        with self.assertRaises(ValueError):self.check()
    def test_07_changed_passive_refused(self):
        self.native["passive_force"][6]+=.01
        with self.assertRaises(ValueError):self.check()
    def test_08_nonfinite_refused(self):
        for key in ("bias","gravity_bias","passive_force","qvel"):
            old=self.native[key][0];self.native[key][0]=float("nan")
            with self.assertRaises(ValueError):self.check()
            self.native[key][0]=old
    def test_09_dimension_refused(self):
        self.native["mass_matrix"].pop()
        with self.assertRaises(ValueError):self.check()
    def test_10_wrong_rotation_refused(self):
        self.native["root_rotation"]=np.eye(3).tolist()
        with self.assertRaises(ValueError):self.check()
    def test_11_asymmetric_mass_refused(self):
        self.native["mass_matrix"][0][1]+=.01
        with self.assertRaises(ValueError):self.check()
    def test_12_wrong_generalized_velocity_refused(self):
        self.native["qvel"][3]+=.01
        with self.assertRaises(ValueError):self.check()
    def test_13_state_is_unchanged(self):
        d=self.data();unchanged_state(d,d.qpos.copy(),d.qvel.copy(),.5)
    def test_14_position_mutation_refused(self):
        d=self.data();q=d.qpos.copy();d.qpos[0]+=.01
        with self.assertRaises(ValueError):unchanged_state(d,q,d.qvel.copy(),.5)
    def test_15_velocity_mutation_refused(self):
        d=self.data();v=d.qvel.copy();d.qvel[0]+=.01
        with self.assertRaises(ValueError):unchanged_state(d,d.qpos.copy(),v,.5)
    def test_16_time_mutation_refused(self):
        d=self.data();d.time+=.001
        with self.assertRaises(ValueError):unchanged_state(d,d.qpos.copy(),d.qvel.copy(),.5)
    def test_17_complete_launch(self):
        self.launch();self.assertEqual(sum(self.gate["safety_controls"].values()),83)
    def test_18_dirty_source_refused(self):
        self.owner["source_status"]=[" M unexpected"]
        with self.assertRaises(ValueError):self.launch()
    def test_19_missing_or_world_opening_gate_refused(self):
        for key,value in (("states",131),("world_build_count",1),("solver_steps",1),("component_evidence_verified",False)):
            before=self.gate["preflight"][key];self.gate["preflight"][key]=value
            with self.assertRaises(ValueError):self.launch()
            self.gate["preflight"][key]=before
        del self.gate["safety_controls"]["containment"]
        with self.assertRaises(ValueError):self.launch()
    def test_20_crossed_consumed_identity_refused(self):
        for key in ("attempt_id","source_commit","contract_sha256","declaration_sha256","gate_receipt_sha256"):
            before=self.consumed[key];self.consumed[key]="crossed"
            with self.assertRaises(ValueError):self.launch()
            self.consumed[key]=before
    def test_21_promoted_authority_refused(self):
        for key in task.FLAGS:
            self.owner[key]=True
            with self.assertRaises(ValueError):self.launch()
            self.owner[key]=False
    def test_22_complete_preflight_opens_zero_worlds(self):
        self.assertEqual(task.preflight(),self.gate["preflight"])
    def test_23_reflection_refused(self):
        self.native["root_rotation"]=np.diag([-1.,1.,1.]).tolist()
        with self.assertRaises(ValueError):self.check()
    def test_24_changed_retained_input_digest_refused(self):
        self.c["input_sha256"][next(iter(self.c["input_sha256"]))]="0"*64
        with self.assertRaises(ValueError):task.inputs(self.c)
    def test_25_changed_contract_refused(self):
        self.c["planned_cpu_worlds"]=0
        with patch.object(task,"read",return_value=self.c),self.assertRaises(ValueError):task.declaration()
    def test_26_partial_native_population_refused(self):
        worker=dict(ok=True,constructed_models=2,constructed_cpu_worlds=2,constructed_gpu_worlds=0,
            solver_steps=0,states=131,dense_mass_readbacks=131,position_evaluations=262,velocity_evaluations=262,
            new_trajectory_generated=False,**{k:False for k in task.FLAGS})
        with patch("audit_floating_dynamics_oracle.read",return_value=worker),self.assertRaises(ValueError):audit(task.EVIDENCE)

if __name__=="__main__":unittest.main()
