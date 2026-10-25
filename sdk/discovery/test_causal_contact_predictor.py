"""Analytic cone, causal-input and configured-model rejection controls."""
import copy
from pathlib import Path
import unittest
import numpy as np
import causal_contact_predictor as c
from audit_gpu_batch_execution import read_jsonl
from hierarchical_native_task_v6 import read,ROOT

FOLDER=ROOT.parent/'SporeSpore_Evidence/sdk2-hierarchical-native-v6-f5072c1d2e46499498911eed68d74146/physical/hierarchy_hold_left_075_train_001'


class ContactControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile=read(FOLDER/'force-profile.json');cls.xml=(FOLDER/'model.xml').read_text(encoding='utf-8')
        cls.model=c.ContactPredictor(cls.profile,cls.xml)
        cls.trace=list(read_jsonl(FOLDER/'trace.jsonl'));cls.contacts=list(read_jsonl(FOLDER/'contact-force.jsonl'))
    def packet(self,index=300):
        r=self.trace[index];return c.prepared_packet(r['before_qpos'],r['before_qvel'],self.contacts[index]['contacts'],r['ctrl'])
    def test_01_cone_interior(self):
        np.testing.assert_array_equal(c.project_cones([3.,.4,.5],[(3,.5)]),[3.,.4,.5])
    def test_02_cone_polar(self):
        np.testing.assert_array_equal(c.project_cones([-3.,1.,1.],[(3,.5)]),[0.,0.,0.])
    def test_03_cone_boundary_analytic(self):
        np.testing.assert_allclose(c.project_cones([1.,2.,0.],[(3,.5)]),[1.6,.8,0.],atol=1e-15,rtol=0)
    def test_04_scalar_analytic(self):
        a=c.solve_cones([[2.]],[-6.],[(1,0.)]);self.assertTrue(a['accepted']);self.assertEqual(a['force'],[3.])
        self.assertEqual(c.solve_cones([[2.]],[6.],[(1,0.)])['force'],[0.])
    def test_05_sliding_analytic_optimum(self):
        a=c.solve_cones(np.eye(3),[-1.,-2.,0.],[(3,.5)])
        self.assertTrue(a['accepted']);np.testing.assert_allclose(a['force'],[1.6,.8,0.],atol=1e-14,rtol=0)
    def test_06_coupled_cones_kkt(self):
        h=np.diag([2.,3.,4.,5.]);h[0,1]=h[1,0]=.2
        a=c.solve_cones(h,[-2.,-4.,-8.,3.],[(1,0.),(3,.7)])
        self.assertTrue(a['accepted']);self.assertTrue(c.certificate(h,np.array([-2.,-4.,-8.,3.]),np.array(a['force']),[(1,0.),(3,.7)])['accepted'])
    def test_07_nonoptimal_certificate_refused(self):
        self.assertFalse(c.certificate(np.eye(3),np.array([-1.,-2.,0.]),np.array([2.,0.,0.]),[(3,.5)])['accepted'])
    def test_08_nonconvex_and_nonfinite_refused(self):
        for h in ([[0.]], [[-1.]], [[float('nan')]]):
            with self.assertRaises(ValueError):c.solve_cones(h,[0.],[(1,0.)])
        with self.assertRaises(ValueError):c.project_cones([float('nan')],[(1,0.)])
        with self.assertRaises(ValueError):c.certificate(np.eye(1),[0.],[float('nan')],[(1,0.)])
    def test_09_impedance_endpoints_and_middle(self):
        self.assertEqual(c.impedance(0.),.9);self.assertEqual(c.impedance(-.001),.95)
        self.assertAlmostEqual(c.impedance(-.0005),.925,15)
        self.assertEqual(c.impedance(.0002),c.impedance(-.0002))
    def test_10_free_fall_without_contacts(self):
        packet=dict(qpos=[0.,0.,1.,1.,0.,0.,0.]+[0.]*8,qvel=[0.]*14,target_velocity=[0.]*8,contacts=[])
        a=self.model.predict(packet);self.assertTrue(a['accepted'])
        np.testing.assert_allclose(a['integrated_acceleration'],[0.,0.,-9.8]+[0.]*11,atol=1e-12,rtol=0)
    def test_11_detached_geometry(self):
        p=self.packet()
        for contact in p['contacts']:contact['distance_m']=.01
        problem=self.model.problem(p);self.assertEqual(problem['blocks'],[])
    def test_12_joint_limit_direction(self):
        p=dict(qpos=[0.,0.,1.,1.,0.,0.,0.]+[0.]*8,qvel=[0.]*14,target_velocity=[0.]*8,contacts=[])
        p['qpos'][7]=-.73;p['qpos'][14]=1.11
        q=self.model.problem(p);self.assertEqual(q['blocks'],[(1,0.),(1,0.)])
        self.assertEqual(q['jacobian'][0,6],1.);self.assertEqual(q['jacobian'][1,13],-1.)
    def test_13_candidate_changes_force_prediction(self):
        p=self.packet();first=self.model.predict(p);p['target_velocity']=[0.]*8;second=self.model.predict(p)
        self.assertTrue(first['accepted'] and second['accepted'])
        self.assertGreater(np.max(np.abs(np.array(first['solution']['force'])-second['solution']['force'])),.01)
    def test_14_future_fields_rejected_by_predictor(self):
        p=self.packet();p['measured_force']=[0.]*8
        with self.assertRaises(ValueError):self.model.predict(p)
        p=self.packet();p['contacts'][0]['local_force_n']=[0.]*3
        with self.assertRaises(ValueError):self.model.predict(p)
    def test_15_packet_builder_cannot_leak_future_data(self):
        raw=copy.deepcopy(self.contacts[300]);before=c.prepared_packet(raw['before_qpos'],raw['before_qvel'],raw['contacts'],raw['ctrl'])
        raw['qpos']=[1e9]*15;raw['qvel']=[1e9]*14;raw['efc_force']=[1e9]*len(raw['efc_force'])
        for contact in raw['contacts']:
            contact['local_force_n']=[1e9]*3;contact['force_on_geom2_canonical_n']=[1e9]*3
        after=c.prepared_packet(raw['before_qpos'],raw['before_qvel'],raw['contacts'],raw['ctrl'])
        self.assertEqual(before,after);self.assertEqual(self.model.predict(before),self.model.predict(after))
    def test_16_geometry_frame_refused(self):
        p=self.packet();p['contacts'][0]['frame'][0]=2.
        with self.assertRaises(ValueError):self.model.predict(p)
    def test_17_unsupported_model_and_capability_refused(self):
        with self.assertRaises(ValueError):c.ContactPredictor(self.profile,self.xml.replace('integrator="implicitfast"','integrator="Euler"'))
        profile=copy.deepcopy(self.profile);profile['velocity_gains'][0]*=2
        with self.assertRaises(ValueError):c.ContactPredictor(profile,self.xml)
    def test_18_invalid_command_and_geometry_population(self):
        p=self.packet();p['target_velocity'][0]=4.
        with self.assertRaises(ValueError):self.model.predict(p)
        p=self.packet();p['contacts']*=33
        with self.assertRaises(ValueError):self.model.predict(p)
    def test_19_actuator_force_clipping(self):
        p=self.packet();p['qvel'][6:]=[100.]*8
        np.testing.assert_array_equal(self.model.problem(p)['actuator_force'],self.model.ranges[:,0])
    def test_20_complete_retained_numerical_population(self):
        for index in range(300,595):
            with self.subTest(step=index+1):self.assertTrue(self.model.predict(self.packet(index))['accepted'])
    def test_21_reader_checks_clock_and_original_boundary(self):
        import audit_causal_contact_predictor as a
        control=list(read_jsonl(FOLDER/'controller.jsonl'))[60]
        result=a.measure(self.model,control,self.trace[300],self.contacts[300]);self.assertTrue(result['first_step'])
        wrong=copy.deepcopy(self.contacts[300]);wrong['step']+=1
        with self.assertRaises(ValueError):a.measure(self.model,control,self.trace[300],wrong)
        wrong=copy.deepcopy(control);wrong['native_observation']['contacts'][0]['distance_m']-=.01
        with self.assertRaises(ValueError):a.measure(self.model,wrong,self.trace[300],self.contacts[300])
    def test_22_exact_contract(self):
        import audit_causal_contact_predictor as a
        self.assertEqual(a.declaration(),a.expected_contract())


if __name__=='__main__':unittest.main()
