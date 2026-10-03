"""Acceptance conjunction controls. No files, launch authority or claim writes."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import test_r10w_campaign_authority as graph_controls

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10w_campaign_authority as authority
import r10w_campaign_audit as audit
import r10w_campaign_closure as closure


def fixture():
    cells = [dict(cell_id=c['cell_id'], execution_valid=True, finite_task_predicates_passed=True)
             for c in authority.population('held_out_finite_decision')]
    return dict(mode='held_out_finite_decision', cells=cells, total_world_builds=6,
                **audit.decide(cells, 'held_out_finite_decision'))


class Closure(unittest.TestCase):
    def test_development_coverage_requires_positive_no_kick_upright_hold(self):
        cells = [dict(cell_id=c['cell_id'], seed=c['seed']['seed'], role=c['role'],
            execution_valid=True, finite_task_predicates_passed=True, entry_kind=branch,post_recovery_handoff='bounded_hold' if branch=='upright' else 'direct')
            for c, branch in zip(authority.population('development_ghost'), ('unselected', 'upright'))]
        value = dict(mode='development_ghost', cells=cells, total_world_builds=2,
                     **audit.decide(cells, 'development_ghost'))
        self.assertEqual(dict(no_kick=True, upright_bounded_hold=True),
                         closure.development_coverage(value))
        for defect in ('negative', 'wrong_branch', 'wrong_seed', 'wrong_handoff', 'missing', 'wrong_worlds'):
            changed = copy.deepcopy(value)
            if defect == 'negative': changed['cells'][0]['finite_task_predicates_passed'] = False
            elif defect == 'wrong_branch': changed['cells'][1]['entry_kind'] = 'partial'
            elif defect == 'wrong_seed': changed['cells'][1]['seed'] = 50644
            elif defect == 'wrong_handoff': changed['cells'][1]['post_recovery_handoff'] = 'direct'
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

    def test_original_workflow_flags_are_required_even_for_six_positive_cells(self):
        flags=dict(original_host_success=True,original_publication_complete=True,owned_cleanup_complete=True,source_unchanged=True)
        self.assertTrue(closure.accepted_decision(fixture(),flags)['sdk1_m07_satisfied'])
        for name in flags:
            for value in (False,1,None):
                with self.subTest(name=name,value=value):
                    self.assertFalse(closure.accepted_decision(fixture(),dict(flags,**{name:value}))['sdk1_m07_satisfied'])

    def test_actual_closure_builder_emits_the_authority_graph_contract(self):
        auth,qual,ghost,graph=graph_controls.fixture()
        cells=[dict(cell_id=c['cell_id'],seed=c['seed']['seed'],role=c['role'],execution_valid=True,
                    finite_task_predicates_passed=True,entry_kind='unselected' if i==0 else 'upright',
                    post_recovery_handoff='direct' if i==0 else 'bounded_hold')
            for i,c in enumerate(authority.population('development_ghost'))]
        observed=dict(mode='development_ghost',cells=cells,total_world_builds=2,source_commit='4'*40,
            production_route_key=ghost['production_route_key'],**audit.decide(cells,'development_ghost'))
        workflow=dict(original_host_success=True,original_publication_complete=True,owned_cleanup_complete=True,source_unchanged=True)
        with patch.object(closure.campaign,'audit',return_value=observed),patch.object(closure,'original_workflow',return_value=workflow),patch.object(closure.qualification,'validate_gate',return_value={'synthetic':True}):
            built=closure.build(authority.EVIDENCE/'synthetic-not-a-campaign')
        graph['blobs'][auth['source_freeze_commit'],authority.GHOST_PATH]=graph_controls.raw(built)
        auth['prerequisite_ghost_sha256']=authority.sha(graph_controls.raw(built))
        graph['blobs'][graph['head'],authority.AUTHORITY_PATH]=graph_controls.raw(auth)
        self.assertEqual(graph_controls.validate(auth,qual,built,graph)['authority_commit'],graph['head'])

    def test_failed_original_host_prevents_ghost_promotion(self):
        observed=dict(mode='development_ghost',cells=[],total_world_builds=2,source_commit='4'*40,
            production_route_key='sha256:'+'5'*64,execution_valid=True,all_finite_tasks_passed=True)
        workflow=dict(original_host_success=False,original_publication_complete=True,owned_cleanup_complete=True,source_unchanged=True)
        with patch.object(closure.campaign,'audit',return_value=observed),patch.object(closure,'original_workflow',return_value=workflow),patch.object(closure.qualification,'validate_gate') as gate:
            built=closure.build(authority.EVIDENCE/'synthetic-not-a-campaign')
        self.assertFalse(built['production_route_ghost_passed']);self.assertIsNone(built['safety_gate']);gate.assert_not_called()

    def test_missing_original_host_cannot_be_reconstructed(self):
        with patch.object(closure.qualification.files,'read',return_value={}):
            with self.assertRaisesRegex(ValueError,'CLOSURE_ORIGINAL_HOST_MISSING'):
                closure.original_workflow(authority.EVIDENCE/'synthetic-not-a-campaign')


if __name__ == '__main__':
    unittest.main()
