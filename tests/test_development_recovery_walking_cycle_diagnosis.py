"""Cold reproduction of descriptive cycles; no original result is regraded."""
import copy
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_walking_cycle_diagnosis as diagnosis
import development_recovery_candidate_checkpoint as closure


class WalkingCycleDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = diagnosis.candidate.read(ROOT / 'sdk/development/recovery_v23_retained_walking_cycle_diagnosis_v1.json')
        cls.observed = diagnosis.diagnose()

    def test_exact_description_reproduces_all_original_cycles_and_minima(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual((19, 13, 2), tuple(self.record[k] for k in
                         ('counted_cycles', 'failed_relocation_cycles', 'failed_cycles_entirely_at_full_amplitude')))
        full = [c for c in self.record['cycles'] if not c['meets_original_relocation_requirement']
                and c['release_amplitude'] == c['touchdown_amplitude'] == 1]
        self.assertEqual(['front_left', 'rear_left'], [c['limb'] for c in full])
        for c in full:
            self.assertEqual(c['nonbearing_step_count'], c['native_nonbearing_contact_classification']['no_distal_contact'])
        self.assertEqual({'front_left': True, 'front_right': False, 'rear_left': False, 'rear_right': True}, self.record['terminal_contact_by_limb'])

    def test_changed_counts_and_promoted_claims_refuse(self):
        for key, value in [('failed_relocation_cycles', 0), ('evaluation_regraded', True),
                           ('original_attempt_reclassified', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('causal_attribution_proven', True)]:
            bad = copy.deepcopy(self.record)
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(bad, self.observed)
        self.assertEqual([0, 0, 0], [self.record[k] for k in ('world_build_count', 'native_physics_read_count', 'solver_step_count')])


if __name__ == '__main__':
    unittest.main()
