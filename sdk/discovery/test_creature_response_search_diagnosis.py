"""Retained joint crossings, current guards and correctly timed forecasts."""
import copy
import unittest
from creature_response_search import JointLimitTrace
from creature_trajectory_diagnosis import f32

BINDING=dict(cell_id='test_cell',candidate_id='test_candidate')
CREATURE=dict(compiled=dict(morphology=dict(morphology_spec=dict(
    joints=[dict(joint_id='joint_'+str(i),lower_limit_rad=-1.,upper_limit_rad=1.) for i in range(8)],
    contact_sites=[dict(body_id='foot')]))),spec=dict(geom_names=['ground','torso_geom','foot_geom']))


def control(outer=0,q=None,v=None,targets=None,decision=None):
    q=q or [0.]*8;v=v or [0.]*8;targets=targets or [0.]*8
    native=dict(sampling_stage='prepared_before_control',qpos=[0.,0.,1.,1.,0.,0.,0.]+q,
                qvel=[0.]*6+v)
    commands=[dict(joint_id='joint_'+str(i),canonical_velocity_rad_s=u,joint_guard_applied=False)
              for i,u in enumerate(targets)]
    return dict(cell=0,outer_step=outer,binding=copy.deepcopy(BINDING),native_observation=native,
        request=dict(state=dict(ordered_joint_observations=[dict(position_rad=a,velocity_rad_s=b) for a,b in zip(q,v,strict=True)])),
        native_targets=targets,resolution=dict(ordered_commands=commands,**({} if decision is None else dict(response_search=decision))))


def sample(row,step,q=None,v=None,force=None,contacts=None):
    before=row['native_observation'] if 'native_observation' in row else row
    q=q or before['qpos'][7:];v=v or before['qvel'][6:];targets=row.get('native_targets',row.get('ctrl'))
    return dict(cell=0,step=step,before_qpos=before['qpos'][:],before_qvel=before['qvel'][:],
        qpos=before['qpos'][:7]+q,qvel=before['qvel'][:6]+v,ctrl=[f32(x) for x in targets],
        actuator_force_nm=force or [0.]*8,on_force_cap=[True]*8,time_s=step/600.,
        contacts=contacts or [])


def selection(targets=None):
    return dict(selection_reason='replanned',applied_action=6,predictions=[
        dict(action_index=i,converged=True,native_targets=targets or [0.]*8,velocity=[0.]*14,score=-float(i))
        for i in range(9)])


class JointLimitDiagnosisControls(unittest.TestCase):
    def trace(self,steps=1):return JointLimitTrace(copy.deepcopy(CREATURE),copy.deepcopy(BINDING),0,steps)

    def test_reference_without_crossing(self):
        t=self.trace();row=control();t.control(row)
        for step in range(1,6):row=sample(row,step);t.native(row)
        result=t.finish(dict(joint_limit_violation_steps=0))
        self.assertIsNone(result['first_crossing'])
        self.assertEqual(result['native_samples'],5)
        self.assertEqual(result['maximum_excess_rad'],0.)
        self.assertIsNone(result['mean_selected_joint_velocity_error_rad_s'])

    def test_crossing_counts_and_contiguous_duration(self):
        t=self.trace();row=control(q=[.9]+[0.]*7,v=[1.]+[0.]*7);t.control(row)
        for step,q in enumerate((1.01,1.02,.9,1.03,1.01),1):
            row=sample(row,step,q=[q]+[0.]*7);t.native(row)
        result=t.finish(dict(joint_limit_violation_steps=4))
        self.assertEqual(result['joint_violation_samples'],[4]+[0]*7)
        self.assertAlmostEqual(result['maximum_excess_rad'],.03)
        self.assertEqual(result['joint_longest_violation_seconds'][0],2/600.)
        self.assertEqual(result['first_crossing']['native_step'],1)

    def test_first_crossing_joins_current_guard_force_and_contacts(self):
        t=self.trace();row=control(q=[.99]+[0.]*7,v=[2.]+[0.]*7,targets=[.1]+[0.]*7)
        row['resolution']['ordered_commands'][0]['joint_guard_applied']=True;t.control(row)
        for step in range(1,6):
            row=sample(row,step,q=[1.001 if step==1 else .99]+[0.]*7,v=[1.]+[0.]*7,
                       force=[-5.]+[0.]*7,contacts=[dict(geom=[0,1])]);t.native(row)
        result=t.finish(dict(joint_limit_violation_steps=1));first=result['first_crossing'];joint=first['joints'][0]
        self.assertTrue(joint['joint_guard_applied'] and joint['actuator_opposes_motion'] and joint['force_at_cap'])
        self.assertTrue(joint['command_points_outward'] and joint['velocity_points_outward'])
        self.assertAlmostEqual(joint['required_constant_deceleration_rad_s2'],200.)
        self.assertTrue(first['torso_contact']);self.assertFalse(first['distal_contact'])
        self.assertIsNone(first['last_selection'])

    def test_held_pattern_does_not_retime_an_old_prediction(self):
        t=self.trace(2);row=control(decision=selection());t.control(row)
        for step in range(1,6):row=sample(row,step,q=[.9]+[0.]*7,v=[1.]+[0.]*7);t.native(row)
        row=control(1,q=row['qpos'][7:],v=row['qvel'][6:],targets=[.1]+[0.]*7,
                    decision=dict(selection_reason='held_pattern',applied_action=6,predictions=[]))
        t.control(row)
        for step in range(6,11):row=sample(row,step,q=[1.01]+[0.]*7,v=[2.]+[0.]*7);t.native(row)
        result=t.finish(dict(joint_limit_violation_steps=5));first=result['first_crossing']
        self.assertEqual(result['selected_one_step_predictions_compared'],1)
        self.assertEqual(first['selection_age_intervals'],1)
        self.assertEqual(first['last_selection']['predicted_native_step'],1)
        self.assertEqual(first['last_selection']['observed_next_joint_velocities_rad_s'][0],1.)
        self.assertEqual(first['recent_controls'][-1]['native_targets'][0],.1)

    def test_crossed_stale_and_wrong_command_rows_refused(self):
        for kind in ('cell','step','before_qvel','ctrl'):
            t=self.trace();row=control();t.control(row);native=sample(row,1)
            if kind in ('cell','step'):native[kind]=3
            elif kind=='before_qvel':native[kind][6]=1.
            else:native[kind][0]=1.
            with self.assertRaises(ValueError):t.native(native)
        row=control();row['binding']['cell_id']='crossed'
        with self.assertRaises(ValueError):self.trace().control(row)

    def test_denominator_and_retained_outcome_mismatch_refused(self):
        t=self.trace();row=control();t.control(row)
        with self.assertRaises(ValueError):t.finish(dict(joint_limit_violation_steps=0))
        for step in range(1,6):row=sample(row,step);t.native(row)
        with self.assertRaises(ValueError):t.finish(dict(joint_limit_violation_steps=1))
        with self.assertRaises(ValueError):t.control(control(1))

    def test_prediction_motor_binding_refused(self):
        row=control(decision=selection());row['resolution']['response_search']['predictions'][6]['native_targets']=[1.]*8
        with self.assertRaises(ValueError):self.trace().control(row)


if __name__=='__main__':unittest.main()
