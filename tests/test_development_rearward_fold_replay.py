"""V7 worker-to-independent-reader checks; all observations are synthetic."""
import copy
import unittest

import test_development_passive_entry_replay as shared


class RearwardFoldReplay(shared.PassiveEntryReplay):
    producer_script = 'res://tests/test_development_rearward_fold_replay_fixture.gd'
    producer_marker = 'DEVELOPMENT_REARWARD_FOLD_REPLAY_FIXTURE '
    reader_script = 'res://sdk/trace_analysis/development_rearward_fold_replay.gd'
    reader_marker = 'DEVELOPMENT_REARWARD_FOLD_REPLAY '
    core_path = 'sdk/target/development-rearward-fold-v1/debug/sporespore_godot_adapter.dll'
    root_prefix = 'development-rearward-fold-replay-'
    canonical_count = 12
    segment_count = 15
    report_count = 286
    negative_count = 32

    @classmethod
    def extra_negative_cases(cls, original):
        mutations = {
            'crossed_setup_controller': lambda r: r.update(setup_controller_id=r['post_kick_controller_id']),
            'crossed_postkick_controller': lambda r: r.update(post_kick_controller_id=r['setup_controller_id']),
            'missing_postkick_context': lambda r: r.pop('post_kick_controller_context'),
            'empty_postkick_context': lambda r: r.update(post_kick_controller_context={}),
            'crossed_native_ancestry': lambda r: r['post_kick_controller_context'].update(source_native_context_sha256='sha256:' + '0' * 64),
            'crossed_context_controller': lambda r: r['post_kick_controller_context'].update(recovery_controller_id=r['setup_controller_id']),
            'old_retention_schema': lambda r: r.update(schema_version='sporespore_development_measured_prone_entry_retention_v1'),
        }
        cases = []
        for name, mutate in mutations.items():
            changed = copy.deepcopy(original)
            mutate(changed['retention'])
            cases.append(dict(case_id=name, input=changed))
        return cases

    def test_active_support_step_is_in_the_independently_replayed_timeline(self):
        last = self.input['retention']['canonical_packets'][-1]
        self.assertIs(last['application']['no_actuation_requested'], False)
        self.assertEqual('sporespore_exact_s169_prone_to_standing_controller_v7',
                         last['application']['portable_recovery_controller_id'])
        self.assertEqual(286, last['global_semantic_step'])
        self.assertIs(self.results['complete_report_from_zero']['ok'], True)


if __name__ == '__main__':
    unittest.main()
