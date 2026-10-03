"""Unchanged finite bounds and R10AA's distinct recovery completion identities."""
import copy
import unittest
from unittest import mock

import test_r10v_finite_task_audit as original
import r10aa_finite_task_audit as audit


class R10AAFiniteEnvelope(original.shared.FiniteTaskAudit):
    def setUp(self):
        selected = mock.patch.object(original.shared, 'audit', audit)
        selected.start()
        self.addCleanup(selected.stop)


def report_for(kind):
    report = original.report_for(kind)
    report['retained_arm']['orchestrator_state']['schema_version'] = 'sporespore_r10aa_recovery_orchestrator_state_v1'
    partial = report.pop('r10v_partial_recovery')
    partial.update(schema_version='sporespore_r10aa_partial_recovery_retention_v1',
        control_composition_id='sporespore_r10aa_partial_load_seeking_v23_v7_composition_v1')
    report['r10aa_partial_recovery'] = partial
    return report


class R10AAFiniteCompletion(unittest.TestCase):
    def test_walking_horizon_selects_successor_and_original_schema_limits(self):
        import json
        legacy = json.loads((audit.ROOT/'sdk/recovery/r10g_finite_cycle_kick_recovery_contract_v1.json').read_text(encoding='utf-8'))
        for contract in (audit.contract(), original.audit.contract(), legacy):
            limits = contract['limits']
            maximum = limits.get('maximum_walking_commands', limits.get('maximum_v50_walking_commands'))
            rows = [{}] * (maximum + limits['stopping_commands'] + 1)
            report = dict(configuration=dict(base_descriptor={}), development_walking_entry=dict(rows=rows),
                development_cycle_stop=dict(rows=rows))
            compiled = dict(descriptor={}, morphology=dict(morphology_spec=dict(contact_sites=[{}]*4)))
            with self.subTest(schema=contract['schema_version']), self.assertRaisesRegex(ValueError, 'FINITE_RECOVERY_WALKING_HORIZON'):
                audit.walking.measure(report, compiled, contract)

    def test_original_threshold_sections_are_unchanged(self):
        current, previous = audit.contract(), original.audit.contract()
        for key in ('limits', 'whole_walking_envelope', 'finite_walking_observable',
                    'settled_tail', 'partial_recovery', 'prone_recovery',
                    'upright_recovery', 'native_interaction', 'post_recovery_hold'):
            with self.subTest(key=key):
                self.assertEqual(previous[key], current[key])
        old_entry, new_entry = copy.deepcopy(previous['stance_entry']), copy.deepcopy(current['stance_entry'])
        self.assertEqual(old_entry.pop('kicked_entry').replace('V55', 'V56'), new_entry.pop('kicked_entry'))
        # The predecessor keeps its historical dependency digest. This test
        # compares its frozen task text; it cannot requalify that old dependency
        # against today's checkout. The new binding must match current bytes.
        self.assertEqual('sdk/recovery/r10r_joint_pose_entry_policy_contract_v2.json', old_entry.pop('native_entry_policy_contract'))
        self.assertEqual('sha256:6830507489fda3aea07ea71445ee4c6833abcda488d83cf3d63736f49a521be8', old_entry.pop('native_entry_policy_contract_sha256'))
        path, digest = new_entry.pop('native_entry_policy_contract'), new_entry.pop('native_entry_policy_contract_sha256')
        self.assertEqual('sdk/recovery/r10aa_joint_pose_entry_policy_contract_v1.json', path)
        self.assertEqual('sha256:'+audit.hashlib.sha256((audit.ROOT/path).read_bytes()).hexdigest(), digest)
        self.assertEqual('r10r_v50_zero_amplitude_hold_v1', old_entry['hold'].pop('selection_id'))
        self.assertEqual('r10aa_v50_zero_amplitude_hold_v1', new_entry['hold'].pop('selection_id'))
        self.assertEqual(old_entry, new_entry)

    def test_separate_completions_and_negative_entry_kinds(self):
        for kind in ('partial', 'upright', 'prone', 'waiting', 'timeout', 'unselected'):
            with self.subTest(kind=kind):
                result = audit.recovery_measurement(report_for(kind))
                self.assertEqual(kind in ('partial', 'upright', 'prone'), result['passed'])
                self.assertTrue(result['native_replay_required'])
                self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])

    def test_old_state_schema_partial_schema_or_composition_refused(self):
        for variant in ('state', 'retention', 'composition'):
            report = report_for('partial')
            if variant == 'state':
                report['retained_arm']['orchestrator_state']['schema_version'] = 'sporespore_r10v_recovery_orchestrator_state_v1'
            elif variant == 'retention':
                report['r10aa_partial_recovery']['schema_version'] = 'sporespore_r10v_partial_recovery_retention_v1'
            else:
                report['r10aa_partial_recovery']['control_composition_id'] = 'old_v20_control'
            with self.subTest(variant=variant), self.assertRaises(ValueError):
                audit.recovery_measurement(report)

    def test_incomplete_partial_and_crossed_canonical_history(self):
        for field, value in (('phase', 'stance_dwell'), ('standing_samples_observed', 59)):
            report = report_for('partial')
            report['r10aa_partial_recovery']['final_memory'][field] = value
            self.assertFalse(audit.recovery_measurement(report)['passed'])
        report = report_for('partial')
        report['passive_entry']['canonical_packets'] = [{'memory_after': {'phase': 'complete'}}]
        with self.assertRaisesRegex(ValueError, 'CROSSED_CANONICAL_HISTORY'):
            audit.recovery_measurement(report)

    def test_forbidden_mutations_and_wrong_population_refused(self):
        for field in ('canonical_supervisor_synthesized', 'source_observation_rewritten', 'energy_epoch_reset',
                      'physical_acceptance_authority', 'release_authority'):
            report = report_for('partial')
            report['r10aa_partial_recovery'][field] = True
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'RECOVERY_FORBIDDEN'):
                audit.recovery_measurement(report)
        report = report_for('partial')
        report['r10aa_partial_recovery']['step_packets'].pop()
        with self.assertRaisesRegex(ValueError, 'RECOVERY_STEP_POPULATION'):
            audit.recovery_measurement(report)


if __name__ == '__main__':
    unittest.main()
