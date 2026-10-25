"""Rigid collision, quaternion, causality and complete-rollout controls."""
import copy
import unittest
from unittest.mock import patch
import numpy as np
import held_contact_rollout as r
from actuation_recovery_mechanics import quaternion_rotation,rotation
from audit_gpu_batch_execution import read_jsonl
from hierarchical_native_task_v6 import read,ROOT

FOLDER=ROOT.parent/'SporeSpore_Evidence/sdk2-hierarchical-native-v6-f5072c1d2e46499498911eed68d74146/physical/hierarchy_hold_left_075_train_001'


class RolloutControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile=read(FOLDER/'force-profile.json');cls.xml=(FOLDER/'model.xml').read_text(encoding='utf-8')
        cls.model=r.HeldContactRollout(cls.profile,cls.xml)
        cls.trace=list(read_jsonl(FOLDER/'trace.jsonl'));cls.contacts=list(read_jsonl(FOLDER/'contact-force.jsonl'))
        cls.controls=list(read_jsonl(FOLDER/'controller.jsonl'))
    def start(self,command=60):
        c=self.controls[command];o=c['native_observation']
        return dict(qpos=o['qpos'].copy(),qvel=o['qvel'].copy(),target_velocity=c['native_targets'].copy())
    def test_01_zero_rotation(self):
        q=[0.,0.,1.,1.,0.,0.,0.]+[0.]*8
        np.testing.assert_array_equal(r.integrate_position(q,[0.]*14),q)
    def test_02_body_local_quaternion_composition(self):
        q=np.r_[np.zeros(3),np.cos(.3),0.,0.,np.sin(.3),np.zeros(8)]
        v=np.zeros(14);v[3]=.7
        after=r.integrate_position(q,v)
        expected=rotation([0.,0.,1.],.6) @ rotation([1.,0.,0.],.7*r.H)
        np.testing.assert_allclose(quaternion_rotation(np.r_[after[4:7],after[3]]),expected,atol=1e-15,rtol=0)
    def test_03_translation_and_hinges(self):
        q=np.r_[np.zeros(3),1.,0.,0.,0.,np.zeros(8)];v=np.arange(14,dtype=float)
        after=r.integrate_position(q,v)
        np.testing.assert_array_equal(after[:3],r.H*v[:3]);np.testing.assert_array_equal(after[7:],r.H*v[6:])
    def test_04_quaternion_norm_and_sign(self):
        q=np.r_[np.zeros(3),1.,0.,0.,0.,np.zeros(8)];v=np.ones(14)
        negative=q.copy();negative[3:7]*=-1
        for _ in range(100):q=r.integrate_position(q,v);negative=r.integrate_position(negative,v)
        self.assertLess(abs(np.linalg.norm(q[3:7])-1.),1e-14)
        np.testing.assert_allclose(q[3:7],-negative[3:7],atol=1e-15,rtol=0)
    def test_05_nonunit_or_nonfinite_pose_refused(self):
        q=np.r_[np.zeros(3),2.,0.,0.,0.,np.zeros(8)]
        with self.assertRaises(ValueError):r.integrate_position(q,np.zeros(14))
        q[3]=float('nan')
        with self.assertRaises(ValueError):self.model.detect(q)
    def test_06_vertical_capsule_point_and_depth(self):
        c=r.capsule_contacts(2,[[0.,0.,.3],[0.,0.,.01]],.02)
        self.assertEqual(len(c),1);self.assertEqual(c[0]['distance_m'],-.01)
        np.testing.assert_allclose(c[0]['position_m'],[0.,0.,-.005],atol=1e-15,rtol=0)
    def test_07_horizontal_capsule_two_contacts(self):
        c=r.capsule_contacts(2,[[.1,0.,.01],[-.1,0.,.01]],.02)
        self.assertEqual(len(c),2);self.assertEqual([v['position_m'][0] for v in c],[.1,-.1])
    def test_08_separation_and_exact_touch(self):
        self.assertEqual(r.capsule_contacts(2,[[0.,0.,.03],[0.,0.,.04]],.02),[])
        c=r.capsule_contacts(2,[[0.,0.,.02],[0.,0.,.04]],.02)
        self.assertEqual(c[0]['distance_m'],0.)
        p=self.start();p['contacts']=c
        self.assertEqual(self.model.contact_model.problem(p)['identities'],[])
    def test_09_box_face_contacts(self):
        c=r.box_contacts(1,[0.,0.,.04],np.eye(3),[.2,.1,.06])
        self.assertEqual(len(c),4)
        for x in c:self.assertAlmostEqual(x['distance_m'],-.02,15);self.assertAlmostEqual(x['position_m'][2],-.01,15)
        self.assertEqual([x['position_m'][:2] for x in c],[[-.2,-.1],[.2,-.1],[-.2,.1],[.2,.1]])
    def test_10_rotated_box_lower_half(self):
        rot=rotation([0.,1.,0.],.4);c=r.box_contacts(1,[0.,0.,0.],rot,[.2,.1,.06])
        self.assertEqual(len(c),4);self.assertTrue(all(x['distance_m']<0 for x in c))
        self.assertEqual(r.box_contacts(1,[0.,0.,1.],rot,[.2,.1,.06]),[])
    def test_11_unsupported_geometry_refused(self):
        with self.assertRaises(ValueError):r.HeldContactRollout(self.profile,self.xml.replace('type="box"','type="sphere"'))
        with self.assertRaises(ValueError):r.HeldContactRollout(self.profile,self.xml.replace('name="ground"','name="ground" pos="0 0 .01"'))
    def test_12_complete_retained_geometry(self):
        for x,c in zip(self.trace,self.contacts,strict=True):
            with self.subTest(step=x['step']):r.compare_geometry(self.model.detect(x['before_qpos']),c['contacts'])
    def test_13_complete_retained_pose_integration(self):
        for x in self.trace:
            with self.subTest(step=x['step']):
                np.testing.assert_allclose(r.integrate_position(x['before_qpos'],x['qvel']),x['qpos'],atol=1e-12,rtol=0)
    def test_14_intermediate_observation_inputs_refused(self):
        for name in ('contacts','future_qpos','trace','measured_force'):
            p=self.start();p[name]=[]
            with self.subTest(name=name),self.assertRaises(ValueError):self.model.predict(p)
    def test_15_generated_state_continuity_and_fixed_command(self):
        start=self.start();a=self.model.predict(start);self.assertTrue(a['accepted']);self.assertEqual(a['completed_steps'],5)
        for i,row in enumerate(a['rows']):
            self.assertEqual(row['before_qpos'],start['qpos'] if i==0 else a['rows'][i-1]['qpos'])
            self.assertEqual(row['before_qvel'],start['qvel'] if i==0 else a['rows'][i-1]['qvel'])
            self.assertEqual(row['contacts'],self.model.detect(row['before_qpos']))
        self.assertEqual(a['held_target'],start['target_velocity'])
    def test_16_isotropic_tangent_rotation(self):
        s=self.start();p=dict(s,contacts=self.model.detect(s['qpos']));a=self.model.contact_model.predict(p)
        angle=.37;change=np.array([[1.,0.,0.],[0.,np.cos(angle),-np.sin(angle)],[0.,np.sin(angle),np.cos(angle)]])
        for c in p['contacts']:c['frame']=(change @ np.array(c['frame']).reshape(3,3)).reshape(-1).tolist()
        b=self.model.contact_model.predict(p)
        np.testing.assert_allclose(a['contact_generalized_force'],b['contact_generalized_force'],atol=2e-7,rtol=0)
        np.testing.assert_allclose(a['post_velocity'],b['post_velocity'],atol=2e-8,rtol=0)
    def test_17_independent_step_composition(self):
        start=self.start();a=self.model.predict(start);q=start['qpos'];v=start['qvel']
        for _ in range(5):
            packet=r.prepared_packet(q,v,self.model.detect(q),start['target_velocity'])
            result=self.model.contact_model.predict(packet);v=result['post_velocity'];q=r.integrate_position(q,v).tolist()
        self.assertEqual(a['final_qpos'],q);self.assertEqual(a['final_qvel'],v)
    def test_18_complete_command_population(self):
        for command in range(60,119):
            with self.subTest(command=command):self.assertTrue(self.model.predict(self.start(command))['accepted'])
    def test_19_geometry_corruption_refused(self):
        observed=copy.deepcopy(self.contacts[300]['contacts']);predicted=self.model.detect(self.trace[300]['before_qpos'])
        observed[0]['position_m'][0]+=.001
        with self.assertRaises(ValueError):r.compare_geometry(predicted,observed)
        with self.assertRaises(ValueError):r.compare_geometry(predicted,[])
    def test_20_numerical_refusal_preserves_prefix(self):
        original=self.model.contact_model.predict;calls=[]
        def fail(packet):
            calls.append(packet)
            return original(packet) if len(calls)<3 else dict(accepted=False,reason='synthetic refusal')
        with patch.object(self.model.contact_model,'predict',side_effect=fail):a=self.model.predict(self.start())
        self.assertFalse(a['accepted']);self.assertEqual(a['refused_at_step'],2);self.assertEqual(a['completed_steps'],2)
        self.assertEqual(len(a['rows']),3);self.assertNotIn('final_qpos',a)
    def test_21_out_of_range_command_refused(self):
        s=self.start();s['target_velocity'][0]=4.
        with self.assertRaises(ValueError):self.model.predict(s)
    def test_22_exact_contract(self):
        import audit_held_contact_rollout as a
        self.assertEqual(a.declaration(),a.expected_contract())


if __name__=='__main__':unittest.main()
