"""Acceptance conjunction controls. No files, launch authority or claim writes."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10p_campaign_authority as authority
import r10p_campaign_audit as audit
import r10p_campaign_closure as closure


def fixture():
    cells = [dict(cell_id=c['cell_id'], execution_valid=True, finite_task_predicates_passed=True)
             for c in authority.population('held_out_finite_decision')]
    return dict(mode='held_out_finite_decision', cells=cells, total_world_builds=6,
                **audit.decide(cells, 'held_out_finite_decision'))


class Closure(unittest.TestCase):
    def test_development_coverage_requires_positive_no_kick_partial_and_prone(self):
        cells = [dict(cell_id=c['cell_id'], seed=c['seed']['seed'], role=c['role'],
            execution_valid=True, finite_task_predicates_passed=True, entry_kind=branch)
            for c, branch in zip(authority.population('development_ghost'), ('unselected', 'partial', 'prone'))]
        value = dict(mode='development_ghost', cells=cells, total_world_builds=3,
                     **audit.decide(cells, 'development_ghost'))
        self.assertEqual(dict(no_kick=True, partial=True, prone=True, held_out_physics_observed=False),
                         closure.development_coverage(value))
        for defect in ('negative', 'wrong_branch', 'wrong_seed', 'missing', 'wrong_worlds'):
            changed = copy.deepcopy(value)
            if defect == 'negative': changed['cells'][0]['finite_task_predicates_passed'] = False
            elif defect == 'wrong_branch': changed['cells'][2]['entry_kind'] = 'partial'
            elif defect == 'wrong_seed': changed['cells'][2]['seed'] = 50644
            elif defect == 'missing': changed['cells'].pop()
            else: changed['total_world_builds'] = True
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                closure.development_coverage(changed)

    def test_unknown_counts_on_invalid_campaign_never_grant_acceptance(self):
        value = fixture()
        value['cells'][0]['execution_valid'] = False
        value['cells'][0]['finite_task_predicates_passed'] = False
        value.update(audit.decide(value['cells'], value['mode']))
        value['total_world_builds'] = None
        self.assertFalse(closure.finite_decision(value)['sdk1_m07_satisfied'])

    def test_six_valid_positive_cells_are_finite_only(self):
        value = closure.finite_decision(fixture())
        self.assertTrue(value['q_sdk_r10_satisfied'])
        self.assertTrue(value['sdk1_m07_satisfied'])
        for key in ('population_robustness','arbitrary_morphology','cross_engine_push_recovery','force_aware_recovery','continuous_coverage','release_authority'):
            self.assertFalse(value[key])

    def test_development_or_five_cells_cannot_be_promoted(self):
        for defect in ('development', 'missing'):
            value = fixture()
            if defect == 'development': value['mode'] = 'development_ghost'
            else: value['cells'].pop()
            with self.subTest(defect=defect), self.assertRaises(ValueError): closure.finite_decision(value)

    def test_every_negative_or_invalid_cell_prevents_acceptance(self):
        for index in range(6):
            for flag in ('execution_valid','finite_task_predicates_passed'):
                value = fixture(); value['cells'][index][flag] = False
                value.update(audit.decide(value['cells'], value['mode']))
                self.assertFalse(closure.finite_decision(value)['sdk1_m07_satisfied'])

    def test_stale_positive_summary_and_extra_world_are_refused(self):
        for defect in ('summary','world'):
            value = fixture()
            if defect == 'summary': value['cells'][0]['finite_task_predicates_passed'] = False
            else: value['total_world_builds'] = 7
            with self.subTest(defect=defect), self.assertRaises(ValueError): closure.finite_decision(value)


if __name__ == '__main__':
    unittest.main()
