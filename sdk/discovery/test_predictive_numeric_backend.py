"""Compiled ABI refusal controls and independent numerical comparisons."""
import copy
from contextlib import ExitStack
import unittest
from unittest.mock import patch
import mujoco
import numpy as np
from actuation_recovery_mechanics import quaternion_rotation
from causal_contact_predictor import solve_cones
from predictive_command_selection_v2 import PredictiveSelector,packet
from predictive_numeric_backend import KernelSelector,Kernels
from audit_predictive_numeric_backend import DLL,DLL_SHA,ROOT,read,compare,PARENT
from audit_gpu_batch_execution import read_jsonl
from test_held_contact_rollout import FOLDER
from floating_base_dynamics_inputs import C


class KernelControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile=read(FOLDER/"force-profile.json");cls.xml=(FOLDER/"model.xml").read_text(encoding="utf-8")
        cls.fast=KernelSelector(cls.profile,cls.xml,DLL,DLL_SHA);cls.slow=PredictiveSelector(cls.profile,cls.xml)
        cls.trace=list(read_jsonl(FOLDER/"trace.jsonl"));cls.controls=list(read_jsonl(FOLDER/"controller.jsonl"))
        cls.parent=read(ROOT.parent/"SporeSpore_Evidence"/PARENT/"audit.json")
    def frame(self,index=300):
        q=np.array(self.trace[index]["before_qpos"]);v=np.array(self.trace[index]["before_qvel"])
        args=(C @ q[:3],np.r_[C @ q[4:7],q[3]],q[7:])
        frame=self.slow.model.tree.kinematics(*args)
        velocity=np.r_[C @ v[:3],frame["rotations"][0] @ C @ v[3:6],v[6:]]
        return args,frame,velocity
    def test_01_wrong_binary_hash_refused(self):
        with self.assertRaisesRegex(ValueError,"exact executable"):Kernels(DLL,"0"*64)
    def test_02_bad_abi_length_refused(self):
        k=self.fast.kernels;p=self.fast.model.parameters;q=np.zeros(15);out=np.empty(186)
        self.assertEqual(k.dll.lc_kin(k.pointer(p),150,k.pointer(q),15,k.pointer(out),186),1)
    def test_03_bad_quaternion_refused(self):
        with self.assertRaises(ValueError):self.fast.model.tree.kinematics([0.]*3,[0.]*4,[0.]*8)
    def test_04_nonfinite_input_refused(self):
        with self.assertRaises(ValueError):self.fast.model.tree.kinematics([float("nan"),0.,0.],[0.,0.,0.,1.],[0.]*8)
    def test_05_all_retained_kinematics(self):
        for i in range(595):
            args,frame,_=self.frame(i);fast=self.fast.model.tree.kinematics(*args)
            for key in frame:np.testing.assert_allclose(fast[key],frame[key],rtol=0,atol=1e-13)
    def test_06_mass_symmetry_and_reference(self):
        for i in (0,300,459,594):
            _,f,_=self.frame(i);m=self.fast.model.mass_matrix(f)
            np.testing.assert_allclose(m,self.slow.model.mass_matrix(f),rtol=0,atol=1e-12)
            np.testing.assert_allclose(m,m.T,rtol=0,atol=1e-14);self.assertGreater(np.linalg.eigvalsh(m)[0],0)
    def test_07_inverse_dynamics(self):
        a=np.linspace(-.5,.5,14);g=[0.,-9.8,0.]
        for i in (0,300,459,594):
            _,f,v=self.frame(i)
            np.testing.assert_allclose(self.fast.model.inverse_dynamics(f,v,a,g),
                self.slow.model.inverse_dynamics(f,v,a,g),rtol=0,atol=1e-11)
    def test_08_all_retained_motion(self):
        a=np.linspace(-.5,.5,14)
        for i in range(595):
            _,f,v=self.frame(i);x=self.fast.model.motion(f,v,a);y=self.slow.model.motion(f,v,a)
            for key in y:np.testing.assert_allclose(x[key],y[key],rtol=0,atol=1e-12)
    def test_09_all_body_jacobians(self):
        for i in (0,300,459,594):
            _,f,_=self.frame(i)
            for j,body in enumerate(self.slow.model.tree.body_ids):
                point=f["centers"][j]+[.02,-.03,.01]
                for x,y in zip(self.fast.model.jacobians(f,body,point),self.slow.model.jacobians(f,body,point)):
                    np.testing.assert_allclose(x,y,rtol=0,atol=1e-14)
    def test_10_energy(self):
        for i in (0,300,459,594):
            _,f,v=self.frame(i)
            self.assertAlmostEqual(self.fast.model.kinetic_energy(f,v),self.slow.model.kinetic_energy(f,v),places=11)
    def test_11_scalar_and_friction_cones(self):
        for m,q,b in [(np.eye(1),[-2.],[(1,0.)]),
            (np.eye(3),[-1.,.2,-.3],[(3,.95)]),(np.eye(3),[-1.,4.,-2.],[(3,.95)]),
            (np.diag([1.,2.,3.,4.]),[-2.,-1.,4.,-2.],[(1,0.),(3,.95)])]:
            x=self.fast.kernels.solve(m,q,b);y=solve_cones(m,q,b)
            self.assertTrue(x["accepted"]);self.assertTrue(x["certificate"]["accepted"])
            np.testing.assert_allclose(x["force"],y["force"],rtol=0,atol=1e-8)
    def test_12_empty_contact_problem(self):
        self.assertEqual(self.fast.kernels.solve(np.empty((0,0)),[],[]),solve_cones(np.empty((0,0)),[],[]))
    def test_13_invalid_cone_matrix(self):
        for m in (np.array([[1.,2.],[0.,1.]]),-np.eye(2)):
            with self.assertRaises(ValueError):self.fast.kernels.solve(m,[0.,0.],[(1,0.),(1,0.)])
    def test_14_bad_cone_population(self):
        for blocks in ([(1,0.)],[(2,1.)]):
            with self.assertRaises(ValueError):self.fast.kernels.solve(np.eye(2),[-1.,-1.],blocks)
    def test_15_native_world_apis_forbidden(self):
        c=self.controls[60];o=c["native_observation"]
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_forward"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No world")))
            self.assertTrue(self.fast.rollout.predict(dict(qpos=o["qpos"],qvel=o["qvel"],target_velocity=c["native_targets"]))["accepted"])
    def test_16_three_complete_nominal_holds(self):
        for command in (60,92,118):
            c=self.controls[command];o=c["native_observation"]
            value=dict(qpos=o["qpos"],qvel=o["qvel"],target_velocity=c["native_targets"])
            compare(self.slow.rollout.predict(value),self.fast.rollout.predict(value))
    def test_17_handoff_all_candidates(self):
        old=self.parent["results"][0];result=self.fast.select(old["starting_packet"])
        compare({k:v for k,v in old.items() if k!="starting_packet"},result)
    def test_18_lower_cap_all_candidates(self):
        old=self.parent["results"][92-60];result=self.fast.select(old["starting_packet"])
        compare({k:v for k,v in old.items() if k!="starting_packet"},result)
        for c in result["candidates"]:self.assertLessEqual(abs(c["target"][1]),3.)
    def test_19_terminal_all_candidates(self):
        old=self.parent["results"][-1];result=self.fast.select(old["starting_packet"])
        compare({k:v for k,v in old.items() if k!="starting_packet"},result)
        self.assertFalse(result["accepted"]);self.assertIsNone(result["selected_target"])
    def test_20_input_not_mutated(self):
        c=self.controls[60];o=c["native_observation"]
        value=dict(qpos=o["qpos"],qvel=o["qvel"],target_velocity=c["native_targets"]);before=copy.deepcopy(value)
        self.fast.rollout.predict(value);self.assertEqual(value,before)
    def test_21_comparison_refuses_corruption(self):
        for a,b in ((dict(qpos=[0.]),dict(qpos=[.001])),(dict(qvel=[0.]),dict(qvel=[.001])),
            (dict(accepted=True),dict(accepted=False)),(dict(selected_index=1),dict(selected_index=2))):
            with self.assertRaises(ValueError):compare(a,b)
    def test_22_exact_contract_and_build(self):
        import audit_predictive_numeric_backend as a
        self.assertEqual(a.declaration(),a.expected_contract())


if __name__=="__main__":unittest.main()
