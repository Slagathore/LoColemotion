"""Analytic and retained-input controls for the response decomposition."""
import copy,itertools,json,unittest,xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np
import dynamic_response_diagnostic_metrics as d
from floating_dynamics_oracle_math import canonical_state

class ResponseControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root=Path(__file__).resolve().parents[2]
        cls.path=root.parent/"SporeSpore_Evidence"/"sdk2-dynamic-control-native-9beec4b5fe564f4bb985cce8fb8c5e1b"/"physical/dynamic_hold_left_075_train_001"
        cls.profile=json.loads((cls.path/"force-profile.json").read_text())
        cls.xml=(cls.path/"model.xml").read_text()
        def row(name,index):
            with (cls.path/(name+".jsonl")).open() as f:return json.loads(next(itertools.islice(f,index,index+1)))
        cls.control=row("controller",60);cls.sample=row("contact-force",300);cls.trace=row("trace",300);cls.last=row("trace",304)
        cls.model,cls.ranges=d.configured_model(cls.xml,cls.profile)
    def internal(self,sample=None,trace=None):
        return d.internal_sample(self.model,self.ranges,self.profile,sample or self.sample,trace or self.trace)
    def test_01_common_complete_window(self):
        self.assertEqual(d.validate_window([dict(internal_step=695),dict(internal_step=596)],60,119)["commands_per_trial"],59)
    def test_02_crossed_or_failed_window(self):
        for start,end,first in ((60,120,596),(59,119,596),(60,119,595)):
            with self.subTest(start=start,end=end),self.assertRaises(ValueError):
                d.validate_window([dict(internal_step=695),dict(internal_step=first)],start,end)
    def test_03_unsaturated_affine_damping(self):
        np.testing.assert_array_equal(d.damping_diagonal([0.]*8,[10.]*8,[[-5.,5.]]*8),[0.]*6+[10.]*8)
    def test_04_cap_equality_has_no_derivative(self):
        np.testing.assert_array_equal(d.damping_diagonal([-5.,5.]*4,[10.]*8,[[-5.,5.]]*8),np.zeros(14))
    def test_05_bad_damping_domain(self):
        for force,gain in (([6.]*8,[10.]*8),([0.]*8,[-1.]*8),([float("nan")]*8,[10.]*8)):
            with self.assertRaises(ValueError):d.damping_diagonal(force,gain,[[-5.,5.]]*8)
    def test_06_analytic_implicit_step(self):
        continuous,integrated=d.integration(np.eye(14),np.full(14,4.),np.full(14,2.),.5)
        np.testing.assert_array_equal(continuous,np.full(14,4.));np.testing.assert_array_equal(integrated,np.full(14,2.))
    def test_07_invalid_integrator_domain(self):
        for mass,damping,dt in ((np.eye(14),-np.ones(14),.1),(np.eye(14),np.zeros(14),0.)):
            with self.assertRaises(ValueError):d.integration(mass,np.ones(14),damping,dt)
        with self.assertRaises(np.linalg.LinAlgError):d.integration(-np.eye(14),np.ones(14),np.zeros(14),.1)
    def test_08_native_body_local_angular_basis(self):
        frame=d.prepared_frame(self.model.tree,self.sample["before_qpos"])
        np.testing.assert_allclose(d.canonical_velocity(frame,self.sample["before_qvel"]),canonical_state(self.control)[3],atol=1e-12,rtol=0)
    def limits(self):
        ranges=np.array([[-1.,1.]]*8);q=[0.]*8;q[0]=-1.1;q[1]=1.2
        return dict(before_qpos=[0,0,0,1,0,0,0]+q,nefc=2,efc_type=[3,3],efc_id=[1,2],efc_force=[2.,3.],contacts=[]),ranges
    def test_09_lower_and_upper_limit_signs(self):
        sample,ranges=self.limits();expected=np.zeros(14);expected[6:8]=[2.,-3.]
        np.testing.assert_array_equal(d.limit_force(sample,ranges),expected)
    def test_10_missing_duplicate_or_unsupported_limit(self):
        for mutate in (lambda s:s["efc_type"].__setitem__(0,0),lambda s:s["efc_id"].__setitem__(1,1),
                       lambda s:s["efc_force"].pop()):
            sample,ranges=self.limits();mutate(sample)
            with self.assertRaises(ValueError):d.limit_force(sample,ranges)
    def test_11_inactive_limit_refuses(self):
        sample,ranges=self.limits();sample["before_qpos"][7]=0.
        with self.assertRaises(ValueError):d.limit_force(sample,ranges)
    def test_12_actual_native_increment_reconstruction(self):
        value=self.internal();self.assertLess(value["velocity_error"],1e-10);self.assertLess(value["equation_error"],1e-8)
    def test_13_changed_motor_measurement_refuses(self):
        trace=copy.deepcopy(self.trace);trace["actuator_force_nm"][0]-=.01
        with self.assertRaises(ValueError):self.internal(trace=trace)
    def test_14_changed_native_increment_refuses(self):
        sample=copy.deepcopy(self.sample);trace=copy.deepcopy(self.trace)
        sample["qvel"][0]+=.01;trace["qvel"][0]+=.01
        with self.assertRaises(ValueError):self.internal(sample,trace)
    def test_15_changed_contact_force_refuses(self):
        sample=copy.deepcopy(self.sample);sample["contacts"][0]["force_on_geom2_canonical_n"][1]+=1.
        with self.assertRaises(ValueError):self.internal(sample)
    def test_16_unsupported_model_or_gain_refuses(self):
        for key,value in (("integrator","Euler"),("gravity","0 0 -9.81")):
            doc=ET.fromstring(self.xml);doc.find("option").set(key,value)
            with self.assertRaises(ValueError):d.configured_model(ET.tostring(doc,encoding="unicode"),self.profile)
        profile=copy.deepcopy(self.profile);profile["velocity_gains"][0]+=1.
        with self.assertRaises(ValueError):d.configured_model(self.xml,profile)
    def test_17_actual_prepared_command_decomposition(self):
        value=d.command_snapshot(self.control,self.last,self.internal(),self.model)
        self.assertLess(value["accounting"]["maximum_identity_error"],1e-8)
        self.assertTrue(value["accounting"]["accounting_is_not_causal_attribution"])
    def test_18_analytic_four_term_decomposition(self):
        zero=np.zeros(14);contact=zero.copy();contact[0]=1;limits=zero.copy();limits[6]=2
        torque=np.zeros(8);torque[1]=3;continuous=contact+limits+np.r_[np.zeros(6),torque]
        integrated=continuous.copy();integrated[3]=4
        r=d.decompose(np.eye(14),zero,continuous,integrated,zero,contact,limits,np.zeros(8),torque)
        np.testing.assert_array_equal(r["contributions"]["contact"],contact)
        self.assertEqual(r["contributions"]["joint_limit"][6],2);self.assertEqual(r["contributions"]["motor"][7],3)
        self.assertEqual(r["contributions"]["integrator"][3],4)
    def test_19_unaccounted_acceleration_refuses(self):
        z=np.zeros(14)
        with self.assertRaises(ValueError):d.decompose(np.eye(14),z,np.ones(14),np.ones(14),z,z,z,np.zeros(8),np.zeros(8))
    def test_20_changed_contact_task_refuses(self):
        row=copy.deepcopy(self.control);row["force_reference"]["decision"]["allocation"]["task_targets"]["support_front_left_foot"][1]+=1.
        with self.assertRaises(ValueError):d.command_snapshot(row,self.last,self.internal(),self.model)
if __name__=="__main__":unittest.main()
