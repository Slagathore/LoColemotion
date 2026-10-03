import copy
import itertools
import math
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_v44_pre_liftoff_diagnosis as diagnosis


class PreLiftoff(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=diagnosis.source.report()
        cls.result=diagnosis.summarize(cls.source)

    def test_triangle_margin_orientation_translation_and_boundary(self):
        points=[[0.,0.],[1.,0.],[0.,1.]]
        for ordered in itertools.permutations(points):
            self.assertAlmostEqual(.2,diagnosis.triangle_margin([.2,.2],list(ordered)))
            self.assertEqual(0,diagnosis.triangle_margin([.5,.5],list(ordered)))
            self.assertLess(diagnosis.triangle_margin([.8,.8],list(ordered)),0)
        def transform(p): return [100+math.cos(.7)*p[0]-math.sin(.7)*p[1],-50+math.sin(.7)*p[0]+math.cos(.7)*p[1]]
        self.assertAlmostEqual(.2,diagnosis.triangle_margin(transform([.2,.2]),[transform(p) for p in points]),places=12)
        with self.assertRaisesRegex(ValueError,'COLLAPSED'): diagnosis.triangle_margin([0,0],[[0,0],[1,1],[2,2]])

    def test_complete_measured_population_and_first_loading_event(self):
        r=self.result; rows=r['all_samples']
        self.assertEqual(400,len(rows))
        self.assertEqual(858,rows[0]['source_observation_global_step'])
        self.assertEqual(1257,rows[-1]['source_observation_global_step'])
        # The first ramp sample has zero amplitude; the active wave starts at 2.
        self.assertIsNone(rows[0]['planned_swing_limb'])
        self.assertEqual('front_left',rows[1]['planned_swing_limb'])
        self.assertTrue(rows[1]['remaining_three_measured_bearing'])
        self.assertTrue(all(rows[n]['remaining_three_measured_bearing'] for n in range(1,23)))
        self.assertFalse(rows[23]['remaining_three_measured_bearing'])
        self.assertGreater(rows[17]['normal_impulse_ns']['front_left'],0)
        self.assertEqual(0,rows[18]['normal_impulse_ns']['front_left'])
        self.assertGreater(rows[22]['normal_impulse_ns']['rear_right'],0)
        self.assertEqual(0,rows[23]['normal_impulse_ns']['rear_right'])
        self.assertIsNone(rows[23]['actual_three_contact_centroid_margin_m'])
        self.assertLess(r['maximum_measured_mass_position_crosscheck_error_m'],1e-6)
        self.assertFalse(r['geometry_is_contact_authority'])
        print('V44_PRELIFT', {k:v for k,v in r.items() if k not in ('all_samples','first_swing_loading_window')})

    def test_crossed_clock_com_mass_and_impulse_refuse(self):
        for defect in ('clock','com','mass','impulse'):
            r=copy.deepcopy(self.source)
            rows=[x for x in r['development_native_walking_contacts']['rows'] if x['segment_id']=='walking_resume']
            if defect=='clock': rows[0]['session_local_step']=2
            if defect=='com': rows[0]['native_source']['observation']['center_of_mass']['position_world_m']['x']=float('nan')
            if defect=='mass': r['development_walking_entry']['rows'][0]['ordered_body_states'][0]['pose_world']['position_m']['x']+=.01
            if defect=='impulse': rows[0]['native_source']['observation']['ordered_foot_bearing_observations'][0]['bearing_normal_impulse_ns']=-.01
            with self.subTest(defect=defect),self.assertRaises(ValueError): diagnosis.summarize(r)


if __name__=='__main__': unittest.main(verbosity=2)
