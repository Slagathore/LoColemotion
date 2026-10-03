"""Guard against dropping a timeout sample or mixing support from another step."""
import copy
import unittest

import r10p_entry_domain_diagnosis as diagnosis


def descent():
    classification = dict(torso_height_ratio=0.72, torso_up_dot=0.999,
        terminal_linear_speed_m_s=0.02, terminal_angular_speed_rad_s=0.05,
        minimum_nonfoot_clearance_m=-0.003, entry_prone_gate=False,
        joint_limits_respected=False, all_four_distal_sites_bearing=True)
    return [dict(semantic_step=273+i, classification=copy.deepcopy(classification)) for i in range(240)]


class EntryDiagnosisTests(unittest.TestCase):
    def test_complete_upright_trace_preserves_failure_domain(self):
        result = diagnosis.summarize_descent(descent())
        self.assertEqual((273, 512), (result['first_semantic_step'], result['last_semantic_step']))
        self.assertEqual(0, result['original_partial_geometry_samples'])
        self.assertEqual(0, result['joint_limits_respected_samples'])
        self.assertLess(result['final_classification']['minimum_nonfoot_clearance_m'], 0)

    def test_missing_or_repeated_timeout_sample_refuses(self):
        samples = descent()
        with self.assertRaisesRegex(ValueError, 'POPULATION'):
            diagnosis.summarize_descent(samples[:-1])
        samples[100]['semantic_step'] -= 1
        with self.assertRaisesRegex(ValueError, 'CLOCK'):
            diagnosis.summarize_descent(samples)

    def test_nonfinite_geometry_cannot_disappear_from_ranges(self):
        for value in (float('nan'), float('inf'), True):
            samples = descent()
            samples[100]['classification']['torso_height_ratio'] = value
            with self.assertRaisesRegex(ValueError, 'NONFINITE'):
                diagnosis.summarize_descent(samples)

    def test_support_before_ramp_completion_cannot_satisfy_handoff(self):
        rows = [dict(semantic_step=273+i, complete=i>=168, four_supports=i<156,
                     geometry_feasible=i>=73, ready=False) for i in range(240)]
        result = diagnosis.summarize_ramp(rows)
        self.assertEqual(169, result['first_reference_complete_command'])
        self.assertEqual(156, result['last_four_support_command'])
        self.assertEqual(0, result['original_handoff_eligible_samples'])
        rows[169]['four_supports'] = True
        self.assertEqual(1, diagnosis.summarize_ramp(rows)['original_handoff_eligible_samples'])

    def test_ramp_clock_and_unknown_support_refuse(self):
        rows = [dict(semantic_step=273+i, complete=True, four_supports=False,
                     geometry_feasible=True, ready=False) for i in range(240)]
        rows[17]['four_supports'] = None
        with self.assertRaisesRegex(ValueError, 'SAMPLE_TYPE'):
            diagnosis.summarize_ramp(rows)
        rows[17]['four_supports'] = False
        rows[17]['semantic_step'] -= 1
        with self.assertRaisesRegex(ValueError, 'CLOCK'):
            diagnosis.summarize_ramp(rows)


if __name__ == '__main__':
    unittest.main()
