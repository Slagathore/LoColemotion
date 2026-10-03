"""Acceptance conjunction controls. No files, launch authority or claim writes."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10j_campaign_authority as authority
import r10j_campaign_audit as audit
import r10j_campaign_closure as closure


def fixture():
    cells = [dict(cell_id=c['cell_id'], execution_valid=True, finite_task_predicates_passed=True)
             for c in authority.population('held_out_finite_decision')]
    return dict(mode='held_out_finite_decision', cells=cells, total_world_builds=6,
                **audit.decide(cells, 'held_out_finite_decision'))


class Closure(unittest.TestCase):
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
