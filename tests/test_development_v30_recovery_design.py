"""Retained V29 diagnosis and a distinct existing-mode selection; no physics."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_v28_contact_geometry as geometry


class V30Design(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = candidate.read(candidate.CONTACT_GATED_ENTRY_PATH)
        cls.basis = cls.contract['diagnostic_basis']
        cls.record = candidate.read(ROOT / cls.basis['source_closure'])
        cls.report_path = Path(cls.record['kicked_report']['path'])
        cls.report = candidate.read(cls.report_path)

    def test_retained_raw_contact_gaps_and_real_intervening_touchdowns(self):
        self.assertEqual(self.basis['source_closure_sha256'], candidate.sha(ROOT / self.basis['source_closure']))
        self.assertEqual(self.basis['source_report_sha256'], candidate.sha(self.report_path))
        rows, _ = geometry.reconstruct(self.report)
        selected = [r for limb, spans in self.basis['selected_failed_stance_gap_trace_intervals'].items()
                    for start, end in spans for r in rows if r['limb'] == limb and start <= r['trace_local_step'] < end]
        self.assertEqual(45, len(selected))
        self.assertEqual(0, sum(r['raw_contact_count'] for r in selected))
        touches = [r for start, end in self.basis['front_left_intervening_raw_contact_intervals']
                   for r in rows if r['limb'] == 'front_left' and start <= r['trace_local_step'] < end]
        self.assertEqual(14, len(touches))
        self.assertTrue(all(r['raw_contact_count'] > 0 for r in touches))
        self.assertFalse(self.basis['causal_attribution_proven'])
        self.assertFalse(self.basis['physical_outcome_predicted'])

    def test_observed_unsatisfied_recontact_checkpoints_use_prior_memory(self):
        entries = {r['session_local_step']: r for r in self.report['development_walking_entry']['rows']}
        for probe in self.basis['bypassed_unsatisfied_recontact_checkpoints']:
            row = entries[probe['command_local_step']]
            memory = row['request']['memory']['ordered_limb_memory']
            index, limb = next((i, m) for i, m in enumerate(memory) if m['limb_id'] == probe['limb'])
            self.assertEqual(144, (limb['gait_step'] + 360 - index*90) % 360)
            contact = next(c for c in row['request']['state']['ordered_contact_observations'] if c['contact_site_id'] == probe['limb']+'_foot')
            self.assertIs(contact['bears_support'], False)
            self.assertEqual('clocked', row['request']['command']['phase_progression_mode'])
            following = next(m for m in row['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == probe['limb'])
            self.assertEqual(limb['gait_step']+1, following['gait_step'])
        self.assertEqual([56, 236], [p['command_local_step'] for p in self.basis['bypassed_unsatisfied_recontact_checkpoints']])

    def test_new_mode_reuses_runtime_bounds_amplitude_and_normal_initializer(self):
        def select(name):
            return candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates' / (name+'.json')))
        old, new = select('v29-joint-bounded-walking-amplitude-v1'), select('v30-contact-gated-walking-from-start-v1')
        for key in ('post_kick_controller_id', 'runtime_binding', 'runtime_binding_sha256', 'runtime_sha256', 'extension', 'extension_sha256'):
            self.assertEqual(old['candidate'][key], new['candidate'][key])
        for key in ('limits', 'controller_id', 'runtime_sha256', 'walking_resume_frame_id', 'walking_contact_profile_id'):
            self.assertEqual(old['diagnostic_schedule'][key], new['diagnostic_schedule'][key])
        self.assertNotIn('walking_replay_profile_id', new['diagnostic_schedule'])
        self.assertEqual('', candidate.walking_memory_transition_id(new['diagnostic_schedule']))
        old_entry = candidate.read(candidate.JOINT_BOUNDED_ENTRY_PATH)
        for key in ('maximum_amplitude', 'warmup_steps', 'first_full_amplitude_local_step'):
            self.assertEqual(old_entry[key], self.contract[key])
        self.assertEqual(1, self.contract['first_contact_gated_local_step'])
        start = candidate.walking_start_contract(candidate.walking_start_id(new['diagnostic_schedule']))
        parent = candidate.read(ROOT / start['parent_start_contract'])
        for key in ('normal_launcher_resource', 'normal_launcher_raw_sha256', 'initial_gait_steps'):
            self.assertEqual(parent[key], start[key])

    def test_bound_sources_refusals_and_exact_historical_records(self):
        for source in self.contract['bound_source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT / source['path']))
        self.assertFalse(self.basis['selected_policy_release_gate_apex_overrides_active'])
        self.assertEqual(1.1, (.82*1.75+.4)*self.contract['maximum_amplitude'])
        original_read = candidate.read
        for change, code in (({'maximum_amplitude': 1.}, 'WALKING_ENTRY_AMPLITUDE_BOUND'),
                             ({'first_contact_gated_local_step': 361}, 'WALKING_ENTRY_TIMING')):
            bad = dict(self.contract, **change)
            with patch.object(candidate, 'read', side_effect=lambda p: bad if p == candidate.CONTACT_GATED_ENTRY_PATH else original_read(p)):
                with self.assertRaisesRegex(ValueError, code):
                    candidate.walking_entry_phase_family(self.contract['profile_id'])
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        import development_recovery_candidate_checkpoint as closure
        for relative in (self.basis['source_closure'], 'sdk/development/recovery_joint_bounded_walking_entry_contract_v1.json',
                         'sdk/core/src/controller.rs', 'sdk/core/src/runtime.rs'):
            self.assertEqual(closure.prior.committed(relative, 'a7891ab8f755af8cf40cf5fbb3be28df087137c5'), (ROOT / relative).read_bytes())
        schedule = candidate.read(ROOT / 'sdk/development/recovery_schedules/v30-contact-gated-walking-from-start-v1.json')['schedules']['v30-contact-gated-walking-from-start-v1']
        # Exercise the frozen-source resolver with explicitly prospective bytes;
        # this is not an observed closure or a replacement for a clean freeze.
        with patch.object(closure.prior, 'committed', side_effect=lambda relative, source: (ROOT / relative).read_bytes()):
            sources = closure.walking_entry_rule_sources(schedule, 'prospective-zero-world-fixture')
        paths = {s['path'] for s in sources}
        for path in (candidate.CONTACT_GATED_ENTRY_PATH, candidate.CONTACT_GATED_START_PATH):
            self.assertIn(path.relative_to(ROOT).as_posix(), paths)
        self.assertIn('sdk/development/recovery_walking_start_contract_v1.json', paths)
        self.assertNotIn('sdk/development/recovery_prospective_walking_replay_contract_v1.json', paths)


if __name__ == '__main__':
    unittest.main()
