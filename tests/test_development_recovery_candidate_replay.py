"""The same worker producer and cold reader for every immutable candidate profile."""
import copy
import unittest

import test_development_passive_entry_replay as shared
import test_development_rate_limited_recovery_replay as negatives
from development_recovery_candidate_test_support import selected, arguments


class CandidateReplay(shared.PassiveEntryReplay):
    producer_script = 'res://tests/test_development_recovery_candidate_fixture.gd'
    producer_marker = 'DEVELOPMENT_RECOVERY_CANDIDATE_FIXTURE '
    reader_script = 'res://sdk/trace_analysis/development_recovery_candidate_replay.gd'
    reader_marker = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
    root_prefix = 'development-candidate-replay-'
    canonical_count = 12
    segment_count = 15
    report_count = 286
    negative_count = 34

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.baseline_report_count = 272 if cls.selection.get("diagnostic_schedule", {}).get("walking_policy_id") in ("r10h_v50_stance_entry_route_v1", "r10i_v50_flexed_entry_route_v1", "r10j_v50_settled_hold_route_v1") else 276
        cls.negative_count = 36 if 'diagnostic_schedule' in cls.selection else 34
        if cls.selection.get("diagnostic_schedule", {}).get("walking_policy_id") in ("r10g_v50_finite_cycle_walking_route_v1", "r10h_v50_stance_entry_route_v1", "r10i_v50_flexed_entry_route_v1", "r10j_v50_settled_hold_route_v1"): cls.negative_count += 3
        cls.core_path = shared.entry.binding(cls.selection)['local_build_path']
        super().setUpClass()

    @classmethod
    def _run_retained(cls, script, supplied, name, timeout):
        if script in (cls.producer_script, cls.reader_script):
            supplied = (list(supplied) if supplied else ['--']) + arguments(cls.selection)
        return super()._run_retained(script, supplied, name, timeout)

    @classmethod
    def extra_negative_cases(cls, original):
        cases = negatives.RateLimitedRecoveryReplay.extra_negative_cases(original)
        for key, value in [('resource', 'res://sdk/development/recovery_candidates/unknown.json'),
                           ('raw_sha256', 'sha256:' + '0' * 64)]:
            changed = copy.deepcopy(original)
            changed['retention']['candidate_profile'][key] = value
            cases.append(dict(case_id='candidate_' + key + '_crossed', input=changed))
        if 'diagnostic_schedule' in cls.selection:
            for value in (480, 627):
                changed = copy.deepcopy(original)
                changed['retention']['after_interaction_steps'] = value
                cases.append(dict(case_id='candidate_schedule_tail_' + str(value), input=changed))
        if cls.selection.get("diagnostic_schedule", {}).get("walking_policy_id") in ("r10g_v50_finite_cycle_walking_route_v1", "r10h_v50_stance_entry_route_v1", "r10i_v50_flexed_entry_route_v1", "r10j_v50_settled_hold_route_v1"):
            for name in ("missing_task", "crossed_task_contract", "invented_task_completion"):
                changed=copy.deepcopy(cls.full_report)
                if name=="missing_task":changed["report"].pop("finite_recovery_task")
                elif name=="crossed_task_contract":changed["report"]["finite_recovery_task"]["task_contract_sha256"]="sha256:"+"0"*64
                else:changed["report"]["finite_recovery_task"]["cycle_and_stop_boundary_reached"]=True
                cases.append(dict(case_id="finite_"+name,input=changed))
        return cases

    def test_actual_active_and_disabled_command_producers(self):
        super().test_actual_active_and_disabled_command_producers()
        if 'diagnostic_schedule' in self.selection:
            checks = self.application_sources['late_schedule_checks']
            self.assertEqual(12, len(checks))
            self.assertTrue(all(checks.values()), checks)

    def test_selected_candidate_active_support_step_is_independently_replayed(self):
        application = self.input['retention']['canonical_packets'][-1]['application']
        self.assertIs(application['no_actuation_requested'], False)
        self.assertEqual(self.selection['post_kick_controller_id'], application['portable_recovery_controller_id'])
        self.assertIs(self.results['complete_report_from_zero']['ok'], True)

    def test_reader_is_bound_to_original_input_and_denies_physics_claims(self):
        super().test_reader_is_bound_to_original_input_and_denies_physics_claims()
        # Exercise the Python process wrapper too, not just the GDScript reader.
        import json
        path = self.root / 'worker_report.json'
        path.write_text(json.dumps(self.full_report['report'], separators=(',', ':'), allow_nan=False), encoding='utf-8')
        result = shared.entry.run_replay(path)
        self.assertEqual(result, shared.entry.consume_replay(path))
        self.assertIs(result['complete_report_timeline_replayed'], True)
        if self.selection.get('diagnostic_schedule', {}).get('walking_start_profile_id'):
            self.assertEqual(self.selection['diagnostic_schedule']['walking_start_profile_id'], result['walking_start_validation']['profile_id'])
            self.assertEqual(0, result['walking_start_validation']['validated_resume_sessions'])
        if self.selection.get('diagnostic_schedule', {}).get('walking_replay_profile_id'):
            from unittest.mock import patch
            execution_path = path.parent / 'passive_entry_replay/execution.json'
            execution = shared.entry.read(execution_path)
            self.assertEqual('production_adapter_clocked_warmup_v1', execution['memory_transition_profile_id'])
            # This actual short producer ends before resumed walking. Selection
            # must still be explicit, and the observed transition count is zero.
            self.assertEqual((0, 0), tuple(result['walking_control_replay'][k]
                             for k in ('replayed_walking_steps', 'adapter_mode_transition_count')))
            original_read = shared.entry.read
            for value in ('', 'unknown'):
                changed = dict(execution, memory_transition_profile_id=value)
                with patch.object(shared.entry, 'read', side_effect=lambda p: changed if p == execution_path else original_read(p)):
                    with self.assertRaisesRegex(ValueError, 'MEMORY_TRANSITION_EXECUTION_SELECTION'):
                        shared.entry.consume_replay(path)


if __name__ == '__main__':
    unittest.main()
