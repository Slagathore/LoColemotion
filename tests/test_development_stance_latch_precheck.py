"""Saved-input arithmetic and selector lifecycle, never physical proof."""
import sys
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_stance_latch_precheck as sketch


class StanceLatch(unittest.TestCase):
    def test_establish_hold_clear_and_phase_wrap(self):
        select=sketch.select
        self.assertTrue(select(True,73,True,True,True,72,False))
        self.assertTrue(select(True,74,False,False,True,73,True))
        self.assertTrue(select(True,74,True,False,True,74,True))
        self.assertFalse(select(True,72,True,True,True,71,True))
        self.assertFalse(select(False,74,True,True,True,73,True))
        self.assertFalse(select(True,73,False,False,True,359,True))
        self.assertFalse(select(True,74,False,False,False,None,True))
        self.assertFalse(select(True,74,True,False,True,73,False))

    def test_invalid_boolean_phase_and_previous_wave_refuse(self):
        for args in [(True,73,False,True,True,72,False),(True,360,True,True,True,72,False),
                     (True,73.5,True,True,True,72,False),(True,73,True,True,True,None,False),
                     (True,73,True,True,True,float('nan'),False),(True,73,True,True,True,72,1)]:
            with self.subTest(args=args),self.assertRaisesRegex(ValueError,'STANCE_LATCH_'):sketch.select(*args)

    def test_complete_population_and_original_failure_preserved(self):
        full=sketch.observe();v=full['observation']
        self.assertEqual((400,3200),(v['command_count'],v['joint_command_count']))
        self.assertEqual((108,11),(v['original_selector_transitions'],v['proposed_selector_transitions']))
        self.assertEqual(310,v['additional_selected_limb_inputs'])
        self.assertEqual(0.,v['identical_mask_same_memory_motor_maximum_error_rad_s'])
        self.assertTrue(v['all_reference_slew_and_joint_and_motor_bounds_preserved'])
        self.assertFalse(v['original_walking_evaluation']['behavior_passed'])
        self.assertFalse(full['physical_outcome_predicted'])
        self.assertFalse(full['native_component_implemented'])


if __name__=='__main__':unittest.main()
