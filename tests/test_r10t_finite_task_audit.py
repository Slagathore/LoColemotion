"""R10T finite thresholds and separate native-task completion histories."""
import copy
import hashlib
from pathlib import Path
import sys
import unittest
from unittest import mock

# Each production stage starts a fresh interpreter without inherited PYTHONPATH.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/python'))
import test_r10j_finite_task_audit as shared
import r10t_finite_task_audit as audit


class R10TFiniteEnvelope(shared.FiniteTaskAudit):
    def setUp(self):
        selected = mock.patch.object(shared, 'audit', audit)
        selected.start()
        self.addCleanup(selected.stop)


def report_for(kind):
    state = dict(schema_version='sporespore_r10t_recovery_orchestrator_state_v1', r10t_entry_kind=kind,
                 partial_start_global_step=None, upright_start_global_step=None, canonical_start_global_step=None,
                 partial_recovery_step_count=0, upright_recovery_step_count=0, partial_standing_complete=False,
                 upright_stabilization_complete=False, confirm_prone_step_count=0, consecutive_prone_sample_count=0)
    report = dict(retained_arm=dict(orchestrator_state=state), passive_entry=dict(canonical_packets=[]))
    for name in ('partial', 'upright'):
        retained = dict(schema_version='sporespore_r10t_' + name + '_recovery_retention_v1', entry_kind=kind,
                        step_packets=[], final_memory={}, canonical_supervisor_synthesized=False,
                        source_observation_rewritten=False, energy_epoch_reset=False,
                        physical_acceptance_authority=False, release_authority=False)
        if name == 'upright':
            retained['partial_supervisor_synthesized'] = False
        if kind == name:
            state[name + '_start_global_step'] = 513
            state[name + '_recovery_step_count'] = 63
            state['partial_standing_complete' if name == 'partial' else 'upright_stabilization_complete'] = True
            retained.update(step_packets=[{} for _ in range(63)], final_memory=dict(phase='complete', standing_samples_observed=60))
        report['r10t_' + name + '_recovery'] = retained
    if kind == 'prone':
        state.update(canonical_start_global_step=390, confirm_prone_step_count=19, consecutive_prone_sample_count=12)
        report['passive_entry']['canonical_packets'] = [dict(memory_after=dict(phase='complete'))]
    return report


class R10TFiniteCompletion(unittest.TestCase):
    def test_three_distinct_completions_and_valid_negative_entries(self):
        for kind in ('upright', 'partial', 'prone', 'waiting', 'timeout', 'unselected'):
            with self.subTest(kind=kind):
                result = audit.recovery_measurement(report_for(kind))
                self.assertEqual(kind in ('upright', 'partial', 'prone'), result['passed'])
                self.assertTrue(result['native_replay_required'])
                self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])

    def test_prone_confirmation_requires_consecutive_not_total_samples(self):
        report = report_for('prone')
        self.assertTrue(audit.recovery_measurement(report)['passed'])  # 19 total, 12 consecutive.
        report['retained_arm']['orchestrator_state']['consecutive_prone_sample_count'] = 11
        self.assertFalse(audit.recovery_measurement(report)['passed'])
        report['retained_arm']['orchestrator_state'].update(consecutive_prone_sample_count=12, confirm_prone_step_count=11)
        self.assertFalse(audit.recovery_measurement(report)['passed'])

    def test_incomplete_and_crossed_upright_history_cannot_pass(self):
        original = report_for('upright')
        for field, value in [('phase', 'stance_dwell'), ('standing_samples_observed', 59)]:
            report = copy.deepcopy(original)
            report['r10t_upright_recovery']['final_memory'][field] = value
            self.assertFalse(audit.recovery_measurement(report)['passed'])
        report = copy.deepcopy(original)
        report['retained_arm']['orchestrator_state']['upright_stabilization_complete'] = 1
        self.assertFalse(audit.recovery_measurement(report)['passed'])
        for field in ['canonical_supervisor_synthesized', 'partial_supervisor_synthesized', 'source_observation_rewritten', 'energy_epoch_reset']:
            report = copy.deepcopy(original)
            report['r10t_upright_recovery'][field] = True
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'RECOVERY_FORBIDDEN'):
                audit.recovery_measurement(report)
        report = copy.deepcopy(original)
        report['retained_arm']['orchestrator_state']['partial_standing_complete'] = True
        with self.assertRaisesRegex(ValueError, 'CROSSED_TASK_HISTORY'):
            audit.recovery_measurement(report)
        report = copy.deepcopy(original)
        report['passive_entry']['canonical_packets'] = [dict(memory_after=dict(phase='complete'))]
        with self.assertRaisesRegex(ValueError, 'CROSSED_CANONICAL_HISTORY'):
            audit.recovery_measurement(report)

    def test_contract_keeps_walking_partial_prone_thresholds_and_explicit_upright_scope(self):
        import json
        task = audit.contract()
        old = json.loads((audit.ROOT / 'sdk/recovery/r10r_upright_finite_cycle_contract_v2.json').read_bytes())
        for key in ['native_interaction', 'finite_walking_observable', 'settled_tail', 'whole_walking_envelope', 'partial_recovery', 'prone_recovery', 'upright_recovery']:
            self.assertEqual(old[key], task[key], key)
        self.assertEqual(3752,task['limits']['maximum_kicked_child_solver_steps'])
        self.assertEqual(2552,task['limits']['maximum_no_kick_child_solver_steps'])
        self.assertEqual(240,task['limits']['maximum_post_recovery_hold_commands'])
        self.assertEqual(360, task['controller_composition']['maximum_preparation_commands'])
        self.assertEqual(audit.TASK_SHA, hashlib.sha256(audit.TASK.read_bytes()).hexdigest())
        supervision = task['upright_recovery']['supervision']
        self.assertEqual((1200, 360, 60), tuple(supervision[k] for k in ['maximum_recovery_commands', 'maximum_standing_dwell_commands', 'required_consecutive_standing_samples']))
        self.assertFalse(supervision['relative_com_height_gain_required'])
        self.assertFalse(task['physical_execution_authorized'])




class R10TPostRecoveryMeasurement(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import json
        from sporespore_locomotion import LocomotionCore
        root=audit.ROOT.parent/'SporeSpore_Evidence'
        raw=(root/'r10h-readiness-source-5af1b33630f34484be9c418e42416eb3/first_v50_command.json').read_bytes()
        assert hashlib.sha256(raw).hexdigest()=='27b28261113f51cf017684d9841a0afaed910203c32f73a97bfa3fa18b9c6ef0'
        descriptor=json.loads(raw)['configuration']['base_descriptor']
        runtime=json.loads((audit.ROOT/'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json').read_text())
        assert 'sha256:'+hashlib.sha256(Path(runtime['runtime']['path']).read_bytes()).hexdigest()==runtime['runtime']['raw_sha256']
        cls.compiled=LocomotionCore(runtime['runtime']['path']).compile_bounded_quadruped(descriptor)
        cases=json.loads((root/'r10t-settling-orchestrator-8b37b87eb6574f789f128035963ffa54/retained_terminal_inputs.json').read_text())['cases']
        cls.source=next(v['source'] for v in cases if v['case_id']=='phase245_upright')
    def synthetic_report(self, ready_sequence, outcome):
        source=copy.deepcopy(self.source)
        origin=source['readiness']['source_semantic_step']
        rows=[]
        consecutive=0
        for i,ready in enumerate(ready_sequence,1):
            row_source=copy.deepcopy(source)
            request=row_source['projection']['request']
            request['state']['semantic_step']=request['measured_body_frame']['semantic_step']=origin+i
            com=row_source['packet']['native_source']['observation']['center_of_mass']
            com['linear_velocity_world_m_s'].update(x=.02 if ready else .04,y=0.,z=0.)
            row_source['readiness']=audit.readiness.measure(request,com,self.compiled,audit.contract()['stance_entry'])
            rows.append(dict(role=audit.ROLES[1],purpose='post_recovery_hold_dwell',global_semantic_step=origin+i,source=row_source))
            consecutive=consecutive+1 if ready else 0
        memory=dict(commands=len(rows),entry_source_step=origin,last_source_step=origin+len(rows),consecutive_ready=consecutive,outcome=outcome)
        post=dict(schema_version='sporespore_r10t_post_recovery_settling_retention_v1',task_contract_sha256='sha256:'+audit.TASK_SHA,energy_epoch_reset=False,physical_acceptance_authority=False,release_authority=False,entry_source=source,control_rows=[{} for _ in rows],readiness_rows=rows,final_memory=memory)
        return dict(arm_id=audit.ROLES[1],retained_arm=dict(orchestrator_state=dict(r10t_entry_kind='upright',upright_phase='complete',post_recovery_settling=copy.deepcopy(memory))),post_recovery_settling=post,
            stance_entry=dict(readiness_rows=[dict(role=audit.ROLES[1],purpose='post_recovery_entry',global_semantic_step=origin,source=source)],neutral_control_rows=[],hold_control_rows=[]))
    def test_initial_failed_entry_is_retained_after_hold_success(self):
        report=self.synthetic_report([True]*30,'ready')
        result=audit.entry_measurement(report,self.compiled)
        self.assertTrue(result['passed']);self.assertTrue(result['final_ready']);self.assertFalse(result['initial_recovery_ready'])
        self.assertFalse(report['stance_entry']['readiness_rows'][0]['source']['readiness']['ready'])
        self.assertEqual('bounded_hold',result['post_recovery']['handoff'])
    def test_exact_deadline_and_dwell_reset(self):
        for pattern,outcome,passed in [([False]*210+[True]*30,'ready',True),([False]*211+[True]*29,'timeout',False),([True]*29+[False]+[True]*30,'ready',True)]:
            with self.subTest(outcome=outcome,count=len(pattern)):
                result=audit.post_recovery_measurement(self.synthetic_report(pattern,outcome),self.compiled,False)
                self.assertEqual(passed,result['passed'])
    def test_false_ready_extra_command_and_crossed_source_refuse(self):
        for pattern,outcome in [([True]*29,'ready'),([True]*31,'ready'),([False]*241,'timeout')]:
            with self.subTest(count=len(pattern)),self.assertRaises(ValueError):
                audit.post_recovery_measurement(self.synthetic_report(pattern,outcome),self.compiled,False)
        report=self.synthetic_report([True]*30,'ready')
        report['post_recovery_settling']['readiness_rows'][-1]['source']['packet']['native_source']['observation']['center_of_mass']['linear_velocity_world_m_s']['x']=.04
        with self.assertRaisesRegex(ValueError,'POST_HOLD_RECOMPUTATION'):audit.entry_measurement(report,self.compiled)
    def test_hold_cannot_attach_to_partial_recovery(self):
        report=self.synthetic_report([True]*30,'ready');report['retained_arm']['orchestrator_state']['r10t_entry_kind']='partial'
        with self.assertRaisesRegex(ValueError,'POST_HOLD_RECOVERY_KIND'):audit.entry_measurement(report,self.compiled)


if __name__ == "__main__": unittest.main()
