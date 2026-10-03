"""Actual retained V23 boundary through production adapter, original reader kept."""
import copy
import json
from pathlib import Path
import unittest
import uuid

from development_recovery_candidate_test_support import ROOT, candidate, arguments, selected
import test_development_passive_entry_replay as shared


class WalkingMemoryTransition(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        # Use the currently selected, source-bound candidate runtime. The
        # retained V23 walking inputs/outputs stay exact; a new recovery build
        # must still reproduce those unchanged canonical walking commands.
        cls.selection = selected()
        cls.root = shared.entry.EVIDENCE / ('development-memory-transition-checks-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('MEMORY_TRANSITION_TEST_ROOT', cls.root, flush=True)
        cls.record = candidate.read(ROOT / 'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json')
        path = Path(cls.record['kicked_report']['path'])
        if candidate.sha(path) != cls.record['kicked_report']['raw_sha256']:
            raise AssertionError('V23_REPORT_DRIFT')
        report = candidate.read(path)
        rows = report['development_walking_entry']['rows']
        def pair(local):
            return dict(local_step=local, previous_output=copy.deepcopy(rows[local-2]['native_output']), next_request=copy.deepcopy(rows[local-1]['request']))
        cases = {str(local): pair(local) for local in (359, 360, 361, 362)}
        for kind in ('endpoint', 'clock', 'steering', 'counter', 'missing_limb', 'extra_field', 'omitted_transition', 'early_transition', 'repeated_transition'):
            item = pair(362 if kind == 'repeated_transition' else 361)
            memory = item['next_request']['memory']
            if kind == 'endpoint': memory['ordered_limb_memory'][0]['evidence_gait_step_limit'] += 1
            elif kind == 'clock': memory['ordered_limb_memory'][0]['gait_step'] += 1
            elif kind == 'steering': memory['held_path_steering_fraction'] += .01
            elif kind == 'counter': memory['ordered_limb_memory'][0]['current_gate_hold_steps'] += 1
            elif kind == 'missing_limb': memory['ordered_limb_memory'].pop()
            elif kind == 'extra_field': memory['unexpected'] = None
            elif kind == 'omitted_transition': item['next_request']['memory'] = copy.deepcopy(item['previous_output']['next_memory'])
            elif kind == 'early_transition': item['local_step'] = 360
            else: memory['ordered_limb_memory'][0]['evidence_gait_step_limit'] += 360
            cases[kind] = item
        walking_report = {k: report[k] for k in ('configuration', 'development_walking_entry')}
        walking_report['retained_arm'] = {k: report['retained_arm'][k] for k in ('trace_rows', 'walking_sessions')}
        fixture = cls.root / 'retained_walking_and_transition_cases.json'
        fixture.write_text(json.dumps(dict(source=cls.record['kicked_report'], cases=cases, walking_report=walking_report), separators=(',', ':'), allow_nan=False), encoding='utf-8')
        run = cls._run_retained('res://tests/test_development_walking_memory_transition.gd', ['--', str(fixture), *arguments(cls.selection)], 'actual_adapter_and_readers', 120)
        cls.result = shared.marker(run, 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')

    def test_actual_adapter_accepts_complete_retained_boundary_only(self):
        self.assertTrue(self.result['correct_selection'])
        self.assertTrue(self.result['crossed_entry_refused'])
        for local in ('359', '360', '361', '362'):
            result = self.result['cases'][local]
            self.assertTrue(result['ok'], result)
            self.assertEqual(1 if local == '361' else 0, result['adapter_mode_transition_count'])
            self.assertEqual((0, 0, 0), tuple(result[k] for k in ('world_build_count', 'native_physics_read_count', 'solver_step_count')))

    def test_all_nine_memory_and_boundary_corruptions_refuse(self):
        self.assertEqual(13, len(self.result['cases']))
        for name, result in self.result['cases'].items():
            if not name.isdigit():
                with self.subTest(case=name):
                    self.assertFalse(result['ok'], result)
        self.assertFalse(self.result['unknown_profile']['ok'])

    def test_all_445_original_walking_commands_replay_under_explicit_successor(self):
        self.assertEqual('one_cycle_ramp_clocked_then_contact_gated_v1', self.result['retained_entry_profile_id'])
        selected_id = self.selection['diagnostic_schedule']['walking_entry_profile_id']
        self.assertEqual(selected_id, self.result['selected_entry_profile_id'])
        crossed = self.result['selected_profile_reader']
        self.assertFalse(crossed['ok'])
        expected = ('DEVELOPMENT_WALKING_ENTRY_READER_MEMORY_CHAIN'
                    if selected_id == self.result['retained_entry_profile_id'] else 'DEVELOPMENT_WALKING_ENTRY_READER_RETENTION')
        self.assertEqual(expected, crossed['failure_code'])
        original, successor = self.result['original_reader'], self.result['successor_reader']
        self.assertFalse(original['ok'])
        self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_MEMORY_CHAIN', original['failure_code'])
        self.assertTrue(successor['ok'], successor)
        self.assertEqual((445, 1), (successor['replayed_walking_steps'], successor['adapter_mode_transition_count']))
        self.assertEqual('production_adapter_clocked_warmup_v1', successor['memory_transition_profile_id'])
        for key in ('physical_acceptance_authority', 'release_authority'):
            self.assertFalse(successor[key])

    def test_wrapper_requires_separate_diagnostic_and_original_failure_stays_exact(self):
        select = shared.entry._transition_reader_selection
        profile = 'production_adapter_clocked_warmup_v1'
        historical = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v23-clocked-walking-warmup-v1.json'))
        with self.assertRaisesRegex(ValueError, 'REQUIRES_SEPARATE_DIAGNOSTIC'):
            select(historical, profile, None)
        with self.assertRaisesRegex(ValueError, 'MEMORY_TRANSITION_SELECTION'):
            select(historical, 'unknown', self.root)
        self.assertEqual(historical, select(historical, '', None))
        diagnostic = select(historical, profile, self.root)
        self.assertEqual('res://sdk/trace_analysis/development_recovery_transition_replay.gd', diagnostic['reader'])
        self.assertEqual('closed_consumed_independent_replay_invalid', self.record['status'])
        self.assertEqual('sha256:e1fe74012d27269c081a36971e57e674df09c3d8640adc3ece1b5b70e21fd4f8', candidate.sha(ROOT / 'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json'))
        # Preserve the later test-selection failure as its own zero-world result.
        self.assertEqual('sha256:3acbd4a157cd72a67589e8171705fb5cc46205f611c63a0755f2229ef2841755', candidate.sha(ROOT / 'sdk/development/recovery_attempts/4e43b57e644d47a78c1e80681361a24a.json'))
        failure = candidate.read(ROOT / 'sdk/development/recovery_attempts/4e43b57e644d47a78c1e80681361a24a.json')
        self.assertEqual('closed_consumed_zero_world_safety_gate_failure', failure['status'])
        self.assertEqual((95, 91, 4, 1), tuple(failure[k] for k in ('completed_test_count', 'passed_tests_in_preceding_stages', 'failed_stage_completed_test_count', 'failed_stage_failed_test_count')))
        self.assertEqual('4a83be9cc7e5a276189c47369e92f7efda3af60a', failure['source_snapshot']['head'])
        self.assertFalse(failure['source_snapshot']['dirty'])
        for key in ('physical_attempt_started', 'world_build_count', 'solver_step_count', 'original_v23_reclassified',
                    'complete_route_proven', 'successful_recovery_proven', 'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            self.assertFalse(failure[key])
        for key, count in (('retained_population', 42), ('failed_stage_source_population', 5)):
            population = failure[key]
            folder = Path(population['root'])
            self.assertEqual(count, population['file_count'])
            self.assertEqual(sorted(item['path'] for item in population['files']), sorted(p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()))
            for item in population['files']:
                self.assertEqual(item['raw_sha256'], candidate.sha(folder / item['path']))
                self.assertEqual(item['byte_length'], (folder / item['path']).stat().st_size)
        supervisor = candidate.read(Path(failure['evidence_root']) / 'supervisor_result.json')
        self.assertEqual(failure['failure_code'], supervisor['failure_code'])
        self.assertFalse(supervisor['ok'])
        self.assertEqual([], supervisor['children'])
        for reader in ('original_reader', 'successor_reader'):
            self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_RETENTION', failure['failed_stage_observation'][reader]['failure_code'])


if __name__ == '__main__':
    unittest.main()
