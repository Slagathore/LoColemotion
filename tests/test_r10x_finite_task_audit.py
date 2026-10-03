"""Campaign-specific handoff coverage and prefix identity refusal controls."""
import copy
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10x_campaign_authority as authority
import r10x_campaign_profile as profile
import r10x_finite_task_audit as audit


def report(seed):
    identity=authority.seed_identity(seed)
    return dict(seed=seed,r10x_campaign=dict(seed=identity,
        mode='development_ghost' if seed in authority.DEVELOPMENT_SEEDS else 'held_out_finite_decision'))


class Readout(unittest.TestCase):
    def test_held_out_accepts_only_completed_task_permitted_handoffs(self):
        for seed in authority.SEEDS:
            for kind in ('upright','partial','prone','waiting','timeout'):
                for handoff in ('direct','bounded_hold','not_reached','timeout','entry_refused'):
                    with self.subTest(seed=seed,kind=kind,handoff=handoff):
                        actual=audit.declared_handoff_passed(report(seed),dict(handoff=handoff,passed=True),dict(entry_kind=kind,passed=True))
                        expected=(handoff=='direct' and kind in ('upright','partial','prone')) or (handoff=='bounded_hold' and kind=='upright')
                        self.assertIs(actual,expected)
        for bad in (False,None,1):
            self.assertFalse(audit.declared_handoff_passed(report(51007),dict(handoff='direct',passed=bad),dict(entry_kind='prone',passed=True)))
            self.assertFalse(audit.declared_handoff_passed(report(51007),dict(handoff='direct',passed=True),dict(entry_kind='prone',passed=bad)))

    def test_development_requires_upright_hold_and_refuses_crossed_context(self):
        for kind in ('upright','partial','prone'):
            for handoff in ('direct','bounded_hold'):
                self.assertIs(audit.declared_handoff_passed(report(42445),dict(handoff=handoff,passed=True),dict(entry_kind=kind,passed=True)),kind=='upright' and handoff=='bounded_hold')
        original=report(42445)
        for mutate in (lambda x:x['r10x_campaign'].update(mode='held_out_finite_decision'),
                       lambda x:x['r10x_campaign']['seed'].update(prefix_phase=45),
                       lambda x:x.update(r10v_development={}),lambda x:x.update(seed=True)):
            changed=copy.deepcopy(original);mutate(changed)
            with self.assertRaises(ValueError): audit.declared_handoff_passed(changed,dict(handoff='bounded_hold',passed=True),dict(entry_kind='upright',passed=True))

    def test_prefix_receipt_binds_actual_phase_and_original_design(self):
        for seed in (*authority.DEVELOPMENT_SEEDS,*authority.SEEDS):
            identity=authority.seed_identity(seed)
            selected=dict(schema_version='sporespore_r10x_prefix_phase_selection_v1',profile_id='r10x_declared_campaign_prefix_phase_v1',seed=seed,prefix_phase=identity['prefix_phase'],source_design_sha256=authority.DESIGN_SHA,physical_acceptance_authority=False,release_authority=False)
            receipt=dict(initial_gait_steps=dict.fromkeys(('front_left','front_right','rear_left','rear_right'),identity['prefix_phase']),development_prefix_phase_selection=selected)
            original=dict(retained_arm=dict(walking_sessions=[dict(evaluation_segment_id='walking_prefix',start_receipt=receipt)]))
            profile.validate_prefix_retention(original,dict(seed=seed))
            for key,value in [('seed',True),('prefix_phase',45),('source_design_sha256','sha256:'+'0'*64),('physical_acceptance_authority',True)]:
                changed=copy.deepcopy(original);changed['retained_arm']['walking_sessions'][0]['start_receipt']['development_prefix_phase_selection'][key]=value
                with self.assertRaises(ValueError): profile.validate_prefix_retention(changed,dict(seed=seed))
            for steps in ([],[original['retained_arm']['walking_sessions'][0]]*2):
                with self.assertRaises(ValueError): profile.validate_prefix_retention(dict(retained_arm=dict(walking_sessions=steps)),dict(seed=seed))


if __name__=='__main__': unittest.main()
