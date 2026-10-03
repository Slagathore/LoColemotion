"""Actual R10Y candidate admission through the shared declaration validator."""
import copy
import unittest

import test_development_r10y_complete_report as shared
import r10y_host_deadline as host


class R10YHostDeadline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        reference = shared.candidate.reference_for_path(shared.PROFILE)
        cls.chosen = shared.candidate.selection(reference)
        cls.declared = shared.declaration(reference, shared.entry._source_snapshot()['head'])

    def test_actual_candidate_and_unchanged_wall_limits(self):
        self.assertEqual(1740, host.timeout_seconds(self.chosen, self.declared))
        self.assertEqual(self.chosen['diagnostic_schedule']['limits'], shared.entry.validate_declaration(self.declared))
        self.assertEqual(1500, shared.entry.CHILD_TIMEOUT_SECONDS)
        self.assertEqual(900, shared.entry.REPLAY_TIMEOUT_SECONDS)

    def test_child_deadline_domain_and_stale_limit_refused(self):
        for value in (1500, 1741, True, False, 1740.0, '1740', None):
            changed = copy.deepcopy(self.declared)
            changed['timeout_seconds_per_child'] = value
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'DECLARATION_timeout_seconds_per_child'):
                shared.entry.validate_declaration(changed)

    def test_replay_budget_and_claim_flags_remain_strict(self):
        for field, value in [('independent_replay_timeout_seconds', 901), ('maximum_steps_per_child', 3753),
                ('after_interaction_steps', 3401), ('official_qualification', True),
                ('physical_acceptance_authority', True), ('release_authority', True)]:
            changed = copy.deepcopy(self.declared)
            changed[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                shared.entry.validate_declaration(changed)

    def test_other_candidate_or_contract_cannot_borrow_deadline(self):
        changes = {
            'candidate': lambda c: c['candidate'].update(candidate_id='r10v-v56-post-recovery-hold-integrated-v2'),
            'route': lambda c: c['diagnostic_schedule'].update(walking_policy_id='r10v_v56_post_recovery_hold_route_v1'),
            'reference': lambda c: c.update(candidate_profile={}),
            'design': lambda c: c['diagnostic_schedule']['coverage_basis'].update(successor_design_sha256='sha256:'+'0'*64),
            'task_path': lambda c: c['diagnostic_schedule']['coverage_basis'].update(task_contract='sdk/recovery/other.json'),
            'task_digest': lambda c: c['diagnostic_schedule']['coverage_basis'].update(task_contract_sha256='sha256:'+'0'*64),
        }
        for name, mutate in changes.items():
            changed = copy.deepcopy(self.chosen)
            mutate(changed)
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'HOST_DEADLINE_'):
                host.timeout_seconds(changed, self.declared)

    def test_missing_or_crossed_population_refused(self):
        for mutation in ('missing', 'crossed', 'paired', 'seed', 'baseline'):
            changed = copy.deepcopy(self.declared)
            if mutation == 'missing': del changed['r10y_development']
            elif mutation == 'crossed': changed['r10v_development'] = {}
            elif mutation == 'paired': changed['children'].append(copy.deepcopy(changed['children'][0]))
            elif mutation == 'seed': changed['seed'] = 51007
            else: changed['baseline_reused'] = True
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                shared.entry.validate_declaration(changed)


if __name__ == '__main__':
    unittest.main()
