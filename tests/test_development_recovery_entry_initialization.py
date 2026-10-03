"""Cold retained diagnosis and source bindings; no native world or evidence write."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_entry_initialization as diagnosis
import development_recovery_smoke as smoke


class EntryInitializationDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.expected = smoke.read(ROOT / 'sdk/development_recovery_entry_initialization_diagnosis_v1.json')
        cls.observed = diagnosis.diagnose()

    def test_retained_source_and_reference_arithmetic(self):
        smoke.validate_checkpoint(self.expected, self.observed)
        observed, derived = self.observed['observed'], self.observed['derived']
        self.assertEqual([0.0] * 8, observed['terminal_applied_motor_impulses_nms'])
        self.assertEqual([True] * 4, observed['terminal_feet_bearing'])
        self.assertLess(observed['terminal_com_vertical_speed_m_s'], 0.0)
        self.assertGreater(derived['required_com_using_postkick_reference_m'],
                           derived['precondition_standing_com_m_from_retained_reference_and_gain'])
        self.assertLess(derived['same_precondition_stance_gain_using_postkick_reference_m'],
                        derived['minimum_com_rise_m'])

    def test_missing_changed_and_promoted_diagnosis_refuses(self):
        for key in self.expected:
            bad = copy.deepcopy(self.expected)
            bad.pop(key)
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                smoke.validate_checkpoint(bad, self.observed)
        for key in ('runtime_fix_integrated', 'later_stance_physically_observed',
                    'physical_acceptance_authority', 'release_authority'):
            bad = copy.deepcopy(self.expected)
            bad[key] = True
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                smoke.validate_checkpoint(bad, self.observed)


if __name__ == '__main__':
    unittest.main()
