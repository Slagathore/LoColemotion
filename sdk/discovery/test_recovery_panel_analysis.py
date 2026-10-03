"""Adversarial checks for descriptive analysis; no native worlds or file edits."""
import copy
import unittest

import recovery_panel_analysis as A


def record(contacts):
    return dict(packet=dict(contact_sites_by_body={name:{} for name in ('a','b','c','d')}),
                replay=dict(ok=True, comparisons=contacts))


def contact(body, load, foot):
    return dict(body_id=body, normal_impulse_ns=load, classified_as_foot=foot)


def fixture():
    frames = []
    trace = []
    for step in (1, 2):
        frame = record([])
        frame['packet'].update(semantic_step=step, direct_state_source=dict(ordered_body_states=[
            dict(body_id=str(i), linear_velocity_world_m_s=[0,0,0]) for i in range(9)]))
        frames.append(frame)
        trace.append(dict(global_semantic_step=step, torso_position_world_m=[0,.3,0], torso_tilt_rad=0.,
                          orchestrator_phase='prefix' if step == 1 else 'native_kick_or_matched_no_kick_step',
                          application_phase='same'))
    return dict(solver_step_count=2, r10af_contact_frames=dict(records=frames),
                retained_arm=dict(trace_rows=trace, orchestrator_state=dict(phase='complete')))


class AnalysisControls(unittest.TestCase):
    def test_nonfoot_is_not_necessarily_torso(self):
        value = A.contact_sample(record([contact('upper_leg',.1,False)]))
        self.assertTrue(value['nonfoot_contact'])
        self.assertFalse(value['torso_contact'])
        self.assertEqual(0,value['bearing_feet'])
        self.assertTrue(A.contact_sample(record([contact('torso',.1,False)]))['torso_contact'])

    def test_load_is_summed_per_foot_before_thresholding(self):
        value = A.contact_sample(record([contact('a',A.BEARING_NS/2,True)]*2 +
                                       [contact('b',A.BEARING_NS-1e-9,True), contact('c',A.BEARING_NS,True)]))
        self.assertEqual(2,value['bearing_feet'])
        for invalid in (float('nan'),float('inf'),-.1,True):
            with self.subTest(load=invalid),self.assertRaises(ValueError):
                A.contact_sample(record([contact('a',invalid,True)]))
        with self.assertRaises(ValueError): A.contact_sample(record([contact('unknown',.1,True)]))

    def test_late_stance_cannot_hide_bad_rise(self):
        def point(step, bearing):
            return dict(step=step,bearing_feet=bearing,foot_impulses_ns=dict(a=.1),
                        nonfoot_contact=bearing==0,torso_contact=False,height_m=.3,up_dot=1.)
        rows=[point(i,0) for i in range(1,61)]+[point(i,4) for i in range(61,91)]
        value=A.stage_summary(rows)
        self.assertEqual((90,30,60,0,30),tuple(value[k] for k in
            ('samples','four_foot_samples','nonfoot_contact_samples','torso_contact_samples','final_30_four_foot_samples')))
        self.assertEqual(30,value['final_window_samples'])
        self.assertEqual(1,A.stage_summary(rows[:1])['final_window_samples'])

    def test_pairing_rejects_velocity_drift_and_duplicate_roles(self):
        report=fixture();first=A.features(report)
        changed=copy.deepcopy(report)
        changed['r10af_contact_frames']['records'][0]['packet']['direct_state_source']['ordered_body_states'][8]['linear_velocity_world_m_s'][2]=.001
        second=A.features(changed)
        def row(role, features):
            return dict(cell=dict(phase=140,role=role),features=features,
                        measurement=dict(finite_task_predicates_passed=True))
        roles=A.P.ROLES
        self.assertTrue(A.matched_blocks([row(roles[0],first),row(roles[1],first)])[0]['both_roles_positive'])
        with self.assertRaises(ValueError):A.matched_blocks([row(roles[0],first),row(roles[1],second)])
        with self.assertRaises(ValueError):A.matched_blocks([row(roles[0],first),row(roles[0],first)])

    def test_clock_and_interaction_population_refused(self):
        for mode in ('clock','interaction','body_count'):
            report=fixture()
            if mode=='clock':report['retained_arm']['trace_rows'][1]['global_semantic_step']=3
            if mode=='interaction':report['retained_arm']['trace_rows'][0]['orchestrator_phase']='native_kick_or_matched_no_kick_step'
            if mode=='body_count':report['r10af_contact_frames']['records'][0]['packet']['direct_state_source']['ordered_body_states'].pop()
            with self.subTest(mode=mode),self.assertRaises(ValueError):A.features(report)


if __name__=='__main__':unittest.main(verbosity=2)
