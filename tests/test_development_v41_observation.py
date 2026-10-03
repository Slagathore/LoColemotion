"""Cold V41 receipt description on the full retained physical population."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_upright_stance_observation as observer


class UprightObservation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure = ROOT/'sdk/development/recovery_attempts/f4a08fa3230d4276869bb865c8c25a58.json'
        cls.record = json.loads(cls.closure.read_bytes())
        cls.report = json.loads(Path(cls.record['kicked_report']['path']).read_bytes())

    def test_complete_validated_population_and_original_negative(self):
        value = observer.observe(self.closure)['observation']
        self.assertEqual(400, value['command_count'])
        self.assertEqual(943, value['upright_selected_limb_commands'])
        self.assertEqual(246, value['speed_clamped_joint_commands'])
        self.assertEqual(dict(measured_pose_baseline=0, floor_upright_reference=0), value['empty_common_height_intervals'])
        self.assertFalse(value['original_walking_evaluation']['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], value['original_walking_evaluation']['false_walking_receipts'])
        self.assertFalse(value['original_evaluation_replaced'])
        for key in ('native_calls', 'world_build_count', 'solver_step_count'):
            self.assertEqual(0, value[key])

    def test_crossed_receipt_fields_refuse_without_editing_retained_evidence(self):
        rows = self.report['development_walking_entry']['rows']
        index = next(i for i, row in enumerate(rows) if any(x['upright_reference_selected'] for x in row['native_output']['actuation']['receipt']['recovery_support_plane']['upright_stance']['ordered_limbs']))
        original = rows[index]
        for kind, error in [('selector', 'UPRIGHT_SELECTOR'), ('reference', 'UPRIGHT_REFERENCE_NOT_OBSERVATION'), ('goal', 'UPRIGHT_SELECTED_GOAL_VALUES'), ('plan', 'UPRIGHT_HEIGHT_PLAN_CONSISTENCY')]:
            rows[index] = copy.deepcopy(original)
            u = rows[index]['native_output']['actuation']['receipt']['recovery_support_plane']['upright_stance']
            if kind == 'selector': u['ordered_limbs'][0]['upright_reference_selected'] = not u['ordered_limbs'][0]['upright_reference_selected']
            elif kind == 'reference': u['reference_anatomical_vertical_projections'][1] = .5
            elif kind == 'goal': u['ordered_selected_goals_rad'][0] += .01
            else: u['floor_upright_reference_plan']['common_height_interval_nonempty'] = False
            try:
                with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, error):
                    observer.summarize(self.report)
            finally:
                rows[index] = original


if __name__ == '__main__':
    unittest.main()
