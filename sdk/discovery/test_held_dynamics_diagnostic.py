"""Analytic balances and rejection controls for retained force accounting."""
import copy
from types import SimpleNamespace
import unittest
import numpy as np
import held_dynamics_diagnostic as d
import audit_held_dynamics_diagnostic as a


class DiagnosticControls(unittest.TestCase):
    def test_01_contract(self):self.assertEqual(a.declaration(),a.expected_contract())
    def test_02_unsaturated_implicit_scalar(self):
        # M=2, damping=3, force=5: implicit acceleration is 5/(2+h*3).
        m=np.array([[2.]]);z=np.zeros(1);f=np.array([5.]);dam=np.array([3.]);acc=f/(2+d.H*3)
        parts,rn,rp=d.split(m,z,z,dam,f,acc,z,m,z,z,dam,f,z,acc,z)
        np.testing.assert_allclose(rn,0,atol=1e-14);np.testing.assert_allclose(rp,0,atol=1e-14)
        self.assertTrue(all(np.array_equal(x,z) for x in parts.values()))
    def test_03_contact_increment(self):
        m=np.diag([2.,4.]);z=np.zeros(2);force=np.array([6.,8.]);acc=np.array([3.,2.])
        parts,rn,rp=d.split(m,z,z,z,z,z,z,m,z,z,z,force,z,acc,z)
        np.testing.assert_array_equal(parts['contact_wrench'],acc)
        np.testing.assert_array_equal(rn,z);np.testing.assert_array_equal(rp,z)
    def test_04_mass_change_sign(self):
        z=np.zeros(1);one=np.ones(1)
        parts,rn,rp=d.split(np.array([[2.]]),z,z,z,2*one,one,z,np.array([[1.]]),z,z,z,2*one,z,2*one,z)
        np.testing.assert_array_equal(parts['mass_change'],one)
        np.testing.assert_array_equal(rn,z);np.testing.assert_array_equal(rp,z)
    def test_05_motor_clamp_derivative(self):
        force=[-2.,2.,0.,-1.,1.,0.,0.,0.]
        np.testing.assert_array_equal(d.damping(force,[3.]*8,[[-2.,2.]]*8),[0.]*6+[0.,0.,3.,3.,3.,3.,3.,3.])
    def test_06_invalid_motor_domain(self):
        for f,g in (([3.]*8,[1.]*8),([0.]*8,[0.]*8),([float('nan')]*8,[1.]*8)):
            with self.assertRaises(ValueError):d.damping(f,g,[[-2.,2.]]*8)
    def fixture(self):
        # A minimal wrench projector makes sign/frame tests independent of the tree.
        model=SimpleNamespace(tree=SimpleNamespace(index={'body':0}),
            generalized_wrenches=lambda frame,ws:sum((np.r_[w['force'],w['torque'],np.zeros(8)] for w in ws),np.zeros(14)))
        c=dict(native_index=0,dim=3,adhesion_n=0.,efc_address=0,body_names=['world','body'],
            position_m=[0.,0.,0.],force_on_geom2_canonical_n=[2.,3.,4.],torque_on_geom2_canonical_nm=[5.,6.,7.])
        sample=dict(nefc=3,ncon=1,efc_type=[7]*3,efc_id=[0]*3,efc_force=[3.,2.,4.],contacts=[c],before_qpos=[0.]*15)
        return model,dict(t=np.eye(14),frame=None),sample,[[-1.,1.]]*8
    def test_07_contact_sign(self):
        args=self.fixture();force,limit=d.constraint_forces(*args)
        np.testing.assert_array_equal(force[:6],[2.,3.,4.,5.,6.,7.])
        args[2]['contacts'][0]['body_names']=['body','world']
        reverse,_=d.constraint_forces(*args);np.testing.assert_array_equal(reverse,-force)
    def test_08_hinge_limit_sign_and_id(self):
        args=self.fixture();s=args[2];s.update(nefc=5,efc_type=[3,3,7,7,7],efc_id=[1,8,0,0,0],efc_force=[4.,5.,3.,2.,4.])
        s['contacts'][0]['efc_address']=2;s['before_qpos'][7]=-1.1;s['before_qpos'][14]=1.1
        _,limit=d.constraint_forces(*args);self.assertEqual(limit[6],4.);self.assertEqual(limit[13],-5.)
    def test_09_unsupported_constraint(self):
        args=self.fixture();args[2].update(nefc=4,efc_type=[7,7,7,2],efc_id=[0,0,0,1],efc_force=[3.,2.,4.,5.])
        with self.assertRaises(ValueError):d.constraint_forces(*args)
    def test_10_missing_contact_rows(self):
        args=self.fixture();args[2]['efc_type'][1]=3
        with self.assertRaises(ValueError):d.constraint_forces(*args)
    def test_11_duplicate_contacts(self):
        args=self.fixture();s=args[2];s['contacts'].append(copy.deepcopy(s['contacts'][0]));s['ncon']=2;s['contacts'][1]['native_index']=1
        with self.assertRaises(ValueError):d.constraint_forces(*args)
    def test_12_inactive_limit_refused(self):
        args=self.fixture();args[2].update(nefc=4,efc_type=[7,7,7,3],efc_id=[0,0,0,1],efc_force=[3.,2.,4.,5.])
        with self.assertRaises(ValueError):d.constraint_forces(*args)
    def test_13_nonfinite_force_refused(self):
        args=self.fixture();args[2]['efc_force'][0]=float('nan')
        with self.assertRaises(ValueError):d.constraint_forces(*args)
    def test_14_population_loss_refused(self):
        with self.assertRaises(ValueError):d.diagnose([],[],[],{},'')
    def test_15_native_frame_roundtrip(self):
        p=a.ROOT.parent/'SporeSpore_Evidence'/a.ATTEMPT/'physical/hierarchy_hold_left_075_train_001'
        profile=a.read(p/'force-profile.json');control=list(a.read_jsonl(p/'controller.jsonl'))[60]
        model=d.FloatingDynamics(profile['morphology_spec'],[.01]*8);ob=control['native_observation']
        s=d.state(model,ob['qpos'],ob['qvel']);pos,quat,joints,v,g=d.canonical_state(control)
        np.testing.assert_allclose(s['t'] @ v,ob['qvel'],atol=1e-12,rtol=0)
        np.testing.assert_allclose(s['frame']['rotations'][0],d.quaternion_rotation(quat),atol=1e-12,rtol=0)
    def test_16_residual_is_explicit_not_hidden(self):
        m=np.eye(1);z=np.zeros(1);one=np.ones(1)
        parts,rn,rp=d.split(m,z,z,z,z,z,z,m,z,z,z,z,z,one,z)
        np.testing.assert_array_equal(rn,one);np.testing.assert_array_equal(parts['native_balance_residual'],one)


if __name__=='__main__':unittest.main()
