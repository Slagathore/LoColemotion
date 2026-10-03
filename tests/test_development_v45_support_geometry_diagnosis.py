import copy
import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import development_v45_support_geometry_diagnosis as d

class Geometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.rows,cls.value=d.read_source();cls.result=d.analyze(cls.rows,cls.value)
    def test_complete_native_fk_population_and_release(self):
        r=self.result;self.assertEqual(399,r['precommand_count']);self.assertEqual(1596,r['limb_samples'])
        self.assertLess(r['maximum_native_fk_bottom_error_m'],1e-12)
        self.assertEqual([146],[v['command'] for v in r['releases']]);self.assertGreater(r['releases'][0]['margin_m'],.026)
        self.assertFalse(r['causal_attribution_proven'])
    def test_rear_target_gap_and_measured_pose_baseline(self):
        sample=next(s for s in self.result['all_samples'] if s['command']==160 and s['limb']=='rear_right')
        self.assertFalse(sample['precommand_bearing']);self.assertTrue(sample['held'])
        self.assertAlmostEqual(.0026759282127326243,sample['selected_target_bottom_in_measured_pose_m'],places=12)
        self.assertLess(abs(sample['measured_pose_support_target_bottom_m']),1e-12)
    def test_crossed_clocks_body_joint_geometry_refuse(self):
        for kind in ('clock','joint','body'):
            rows=copy.deepcopy(self.rows[:1])
            if kind=='clock':rows[0]['request']['state']['semantic_step']=9
            elif kind=='joint':rows[0]['request']['state']['ordered_joint_observations'][0]['position_rad']+=.1
            else:rows[0]['request']['measured_body_frame']['ordered_body_states'][2]['pose_world']['position_m']['y']+=.01
            with self.assertRaises(ValueError):d.analyze(rows,self.value)

if __name__=='__main__':unittest.main()
