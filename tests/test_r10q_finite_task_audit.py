"""R10Q finite thresholds and separate native-task completion histories."""
import copy
import unittest
from unittest import mock
import test_r10j_finite_task_audit as shared
import r10q_finite_task_audit as audit


class R10QFiniteEnvelope(shared.FiniteTaskAudit):
    def setUp(self):
        selected = mock.patch.object(shared, 'audit', audit)
        selected.start()
        self.addCleanup(selected.stop)


def report_for(kind):
    state = dict(schema_version='sporespore_r10q_recovery_orchestrator_state_v1', r10q_entry_kind=kind,
                 partial_start_global_step=None, upright_start_global_step=None, canonical_start_global_step=None,
                 partial_recovery_step_count=0, upright_recovery_step_count=0, partial_standing_complete=False,
                 upright_stabilization_complete=False, confirm_prone_step_count=0, consecutive_prone_sample_count=0)
    report = dict(retained_arm=dict(orchestrator_state=state), passive_entry=dict(canonical_packets=[]))
    for name in ('partial', 'upright'):
        retained = dict(schema_version='sporespore_r10q_' + name + '_recovery_retention_v1', entry_kind=kind,
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
        report['r10q_' + name + '_recovery'] = retained
    if kind == 'prone':
        state.update(canonical_start_global_step=390, confirm_prone_step_count=19, consecutive_prone_sample_count=12)
        report['passive_entry']['canonical_packets'] = [dict(memory_after=dict(phase='complete'))]
    return report


class R10QFiniteCompletion(unittest.TestCase):
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
            report['r10q_upright_recovery']['final_memory'][field] = value
            self.assertFalse(audit.recovery_measurement(report)['passed'])
        report = copy.deepcopy(original)
        report['retained_arm']['orchestrator_state']['upright_stabilization_complete'] = 1
        self.assertFalse(audit.recovery_measurement(report)['passed'])
        for field in ['canonical_supervisor_synthesized', 'partial_supervisor_synthesized', 'source_observation_rewritten', 'energy_epoch_reset']:
            report = copy.deepcopy(original)
            report['r10q_upright_recovery'][field] = True
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
        old = json.loads((audit.ROOT / 'sdk/recovery/r10o_initialized_zero_brake_finite_cycle_contract_v1.json').read_bytes())
        for key in ['native_interaction', 'finite_walking_observable', 'settled_tail', 'whole_walking_envelope', 'partial_recovery', 'prone_recovery']:
            self.assertEqual(old[key], task[key], key)
        self.assertEqual(old['limits'], {k:v for k,v in task['limits'].items() if k != 'maximum_upright_recovery_commands'})
        supervision = task['upright_recovery']['supervision']
        self.assertEqual((1200, 360, 60), tuple(supervision[k] for k in ['maximum_recovery_commands', 'maximum_standing_dwell_commands', 'required_consecutive_standing_samples']))
        self.assertFalse(supervision['relative_com_height_gain_required'])
        self.assertFalse(task['physical_execution_authorized'])


if __name__ == '__main__':
    unittest.main()
