"""The new development population requires the declared hold, not just walking."""
import copy
import unittest
from unittest import mock
import uuid
import sys
from pathlib import Path

# Each production stage starts a fresh interpreter with no inherited test path.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10t_development as development
import development_recovery_candidate as candidate
ROOT=development.ROOT
REFERENCE=candidate.reference_for_path(ROOT/'sdk/development/recovery_candidates/r10t-v56-post-recovery-hold-integrated-v1.json')
HEAD='a'*40

def declaration():
    attempt=uuid.uuid4().hex
    role=development.ROLES[1]
    return dict(attempt_id=attempt,seed=41145,candidate_profile=REFERENCE,source_snapshot=dict(head=HEAD),development_execution_mode=development.SINGLE,
        children=[dict(role=role,child_attempt_id=uuid.uuid4().hex,termination_nonce=uuid.uuid4().hex,evidence_path=(development.EVIDENCE/('development-recovery-smoke-'+attempt)/'children'/role).as_posix())],
        r10t_development=development.context(development.SINGLE,HEAD,REFERENCE))
class DevelopmentContext(unittest.TestCase):
    def test_first_population_and_explicit_phase(self):
        value=declaration(); observed=development.validate_context(value['r10t_development'],value)
        self.assertEqual((41145,245,'bounded_hold'),(observed['seed'],observed['identity']['prefix_phase'],observed['required_handoff']))
    def test_crossed_handoff_refuses(self):
        value=declaration();value['r10t_development']['required_handoff']='direct'
        with self.assertRaisesRegex(ValueError,'HANDOFF_BINDING'): development.validate_context(value['r10t_development'],value)
    def test_old_population_refuses(self):
        with self.assertRaisesRegex(ValueError,'UNDECLARED_SEED'): development.seed_identity(41046)
        value=declaration();value['r10s_development']={}
        with self.assertRaisesRegex(ValueError,'CROSSED_CAMPAIGN'): development.validate_context(value['r10t_development'],value)
    def test_no_pair_or_extra_branch_without_positive_prerequisite(self):
        for mode,seed in [(development.PAIR,41145),(development.SINGLE,41146),(development.SINGLE,41141),(development.SINGLE,41143)]:
            with self.subTest(mode=mode,seed=seed),self.assertRaisesRegex(ValueError,'REQUIRES_POSITIVE'):
                development.context(mode,HEAD,REFERENCE,diagnostic_seed=seed)
    def test_positive_walking_without_required_hold_does_not_qualify_branch(self):
        value=declaration()
        cell=dict(role=development.ROLES[1],entry_kind='upright',finite_task_predicates_passed=True,post_recovery_handoff='direct')
        result=development.finite_result(value,[cell]);self.assertTrue(result['all_tasks_positive']);self.assertFalse(result['branch_coverage_complete'])
        self.assertFalse(development.positive_result(result,REFERENCE,paired=False))
        cell['post_recovery_handoff']='bounded_hold'
        result=development.finite_result(value,[cell]);self.assertTrue(development.positive_result(result,REFERENCE,paired=False))
    def test_incomplete_dependency_key_blocks_real_selection(self):
        with mock.patch.object(candidate,'R10T_ROUTE_ENTRY_PATH',ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v1.json'):
            with self.assertRaisesRegex(ValueError,'R10T_SOURCE_KEY_INCOMPLETE'): candidate.selection(REFERENCE)
if __name__=='__main__':unittest.main()
