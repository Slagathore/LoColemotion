"""Counter and history controls for the distinct reader; no physical world."""
import copy
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10p_finite_task_audit as audit


def fixture(flags):
    samples, elapsed, consecutive = [], 0, 0
    for index, flag in enumerate(flags):
        row = dict(global_step=389+index, prone_sample=flag,
            event_kind='passive_prone_observation' if index else 'passive_entry_observation',
            entry_status='prone_handoff' if not index else '',
            before_elapsed=elapsed, before_consecutive=consecutive)
        elapsed += 1
        consecutive = consecutive+1 if flag else 0
        samples.append(dict(row, after_elapsed=elapsed, after_consecutive=consecutive))
    return dict(start_global_step=389, elapsed_count=elapsed, consecutive_count=consecutive,
        samples=samples, partial_packet_count=0,
        native_final_memory=dict(phase='complete', prone_confirm_steps_observed=12.0,
            stance_dwell_steps_observed=60.0, ordered_completed_phases=audit.PHASES[:], terminal_failure_code=None))


class ConsecutiveProneReader(unittest.TestCase):
    def test_elapsed_and_consecutive_boundary_population(self):
        for flags, passed in (([True]*12, True), ([True, False]+[True]*12, True),
                              ([True, False]+[True]*10, False),
                              ([True]+[False]*47+[True]*12, True),
                              ([True]+[False]*48+[True]*12, False)):
            with self.subTest(elapsed=len(flags)):
                self.assertIs(audit.prone_completion(fixture(flags))['passed'], passed)

    def test_missing_unknown_nonfinite_and_boolean_counters_refused(self):
        for key in ('elapsed_count', 'consecutive_count', 'start_global_step', 'partial_packet_count'):
            for value in (None, '12', True, float('nan'), float('inf'), -1, 12.0):
                item = fixture([True, False]+[True]*12)
                item[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    audit.prone_completion(item)
            del item[key]
            with self.assertRaises((KeyError, ValueError)):
                audit.prone_completion(item)

    def test_history_corruption_and_forged_counters_refused(self):
        cases = [lambda x: x['samples'].pop(),
                 lambda x: x['samples'][2].update(global_step=393),
                 lambda x: x['samples'][1].update(prone_sample=None),
                 lambda x: x['samples'][1].update(prone_sample=True),
                 lambda x: x['samples'][1].update(before_elapsed=True),
                 lambda x: x.update(consecutive_count=10),
                 lambda x: x.update(consecutive_count=15),
                 lambda x: x['samples'][0].update(entry_status='partial_handoff'),
                 lambda x: x['samples'][2].update(event_kind='walking'),
                 lambda x: x.update(partial_packet_count=1)]
        for index, change in enumerate(cases):
            value = fixture([True, False]+[True]*12)
            change(value)
            with self.subTest(case=index), self.assertRaises(ValueError):
                audit.prone_completion(value)
        with self.assertRaisesRegex(ValueError, 'LATE_HANDOFF'):
            audit.prone_completion(fixture([True]*13))

    def test_incomplete_native_evidence_cannot_pass(self):
        changes = [dict(phase='stance_dwell'), dict(prone_confirm_steps_observed=11),
                   dict(stance_dwell_steps_observed=59), dict(terminal_failure_code='failure'),
                   dict(ordered_completed_phases=audit.PHASES[:-1])]
        for change in changes:
            value = fixture([True]*12)
            value['native_final_memory'].update(change)
            with self.subTest(change=change):
                self.assertFalse(audit.prone_completion(value)['passed'])
        value['native_final_memory'] = None
        self.assertFalse(audit.prone_completion(value)['passed'])

    def test_native_unknown_nonfinite_or_crossed_history_refused(self):
        changes = [dict(phase='invented'), dict(prone_confirm_steps_observed=True),
                   dict(stance_dwell_steps_observed=float('nan')), dict(stance_dwell_steps_observed=59.5),
                   dict(ordered_completed_phases=list(reversed(audit.PHASES))), dict(terminal_failure_code=0)]
        for change in changes:
            value = fixture([True]*12)
            value['native_final_memory'].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                audit.prone_completion(value)

    def test_no_kick_and_partial_common_measurements_are_unchanged(self):
        for role, kind in ((audit.prior.ROLES[0], ''), (audit.prior.ROLES[1], 'partial')):
            original = dict(schema_version='sporespore_r10o_finite_task_measurement_v1',
                predicates=dict(recovery_completed=True), finite_task_predicates_passed=True,
                entry={'marker': 1}, walking={'marker': 2}, envelope={'marker': 3})
            report = dict(arm_id=role, retained_arm=dict(orchestrator_state=dict(r10k_entry_kind=kind)))
            with mock.patch.object(audit.prior, 'measure', return_value=copy.deepcopy(original)):
                observed = audit.measure(report, None)
            self.assertEqual(audit.SCHEMA, observed.pop('schema_version'))
            self.assertEqual('sha256:'+audit.CONTRACT_SHA, observed.pop('reader_contract_sha256'))
            original.pop('schema_version')
            self.assertEqual(original, observed)

    def test_contract_and_bound_source_drift_are_refused(self):
        real = Path.read_bytes
        for target in (audit.CONTRACT, Path(audit.prior.__file__)):
            def changed(path):
                raw = real(path)
                return raw+b' ' if path == target else raw
            with self.subTest(target=str(target)), mock.patch.object(Path, 'read_bytes', changed):
                with self.assertRaisesRegex(ValueError, 'DRIFT'):
                    audit.contract()

    def test_prone_dispatch_changes_only_the_new_completion_measurement(self):
        original = dict(schema_version='sporespore_r10o_finite_task_measurement_v1',
            predicates=dict(recovery_completed=False, walking=True), finite_task_predicates_passed=False,
            entry={'marker': 1}, walking={'marker': 2}, envelope={'marker': 3})
        report = dict(arm_id=audit.prior.ROLES[1], retained_arm=dict(orchestrator_state=dict(r10k_entry_kind='prone')))
        original_report = copy.deepcopy(report)
        with mock.patch.object(audit.prior, 'measure', return_value=copy.deepcopy(original)), \
             mock.patch.object(audit, 'confirmation_inputs', return_value=fixture([True, False]+[True]*12)):
            result = audit.measure(report, None)
        self.assertTrue(result['finite_task_predicates_passed'])
        self.assertTrue(result['predicates']['recovery_completed'])
        self.assertFalse(original['predicates']['recovery_completed'])
        self.assertEqual(original_report, report)
        for key in ('entry', 'walking', 'envelope'):
            self.assertEqual(original[key], result[key])


if __name__ == '__main__':
    unittest.main()
