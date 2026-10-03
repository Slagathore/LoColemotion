"""R10R frame interfaces and historical frame-only identity; declared finite horizon."""
import unittest
import test_development_recovery_walking_frame as shared
candidate, ROOT, ATTEMPT = shared.candidate, shared.ROOT, shared.ATTEMPT

class R10RWalkingFrame(shared.WalkingFrame):
    def test_historical_frame_runtime_and_selected_horizon_preserved(self):
        self.assertEqual(candidate.R10R_ROUTE_ID, self.selection['diagnostic_schedule']['walking_policy_id'])
        old = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v17-velocity-damped-stance-v1.json'))
        frame_only = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v18-anatomical-walking-frame-v1.json'))
        # V18 changed only the frame. Preserve that historical identity claim
        # without falsely requiring every later controller to use the V17 DLL.
        for key in ('post_kick_controller_id', 'runtime_binding', 'runtime_binding_sha256', 'runtime_sha256', 'extension', 'extension_sha256'):
            self.assertEqual(old['candidate'][key], frame_only['candidate'][key])
        expected_limits = candidate.limits(old)
        if self.selection['diagnostic_schedule'].get('walking_entry_profile_id'):
            warmup = candidate.read(ROOT / 'sdk/development/recovery_walking_entry_contract_v1.json')['warmup_steps']
            for key in ('after_interaction_steps', 'maximum_steps_per_child'):
                expected_limits[key] += warmup
        if self.selection['diagnostic_schedule'].get('walking_policy_id') in ('sporespore_balanced_wave_recovery_remaining_support_release_v1','sporespore_balanced_wave_recovery_startup_reference_velocity_v1', candidate.FINITE_ROUTE_ID, candidate.STANCE_ROUTE_ID, candidate.FLEXED_ROUTE_ID, candidate.HOLD_ROUTE_ID, candidate.R10K_ROUTE_ID, candidate.R10L_ROUTE_ID, candidate.R10M_ROUTE_ID, candidate.R10N_ROUTE_ID, candidate.R10O_ROUTE_ID, candidate.R10R_ROUTE_ID):
            expected_limits['after_interaction_steps'] = 3160
            expected_limits['maximum_steps_per_child'] = 3512
        self.assertEqual(expected_limits, candidate.limits(self.selection))
        self.assertNotEqual(old['candidate_profile'], self.selection['candidate_profile'])
        self.assertNotIn('walking_resume_frame_id', old['diagnostic_schedule'])
        self.assertEqual('anatomical_plus_x_horizontal_resume_v1', self.selection['diagnostic_schedule']['walking_resume_frame_id'])
        for relative, digest in [
            ('sdk/development/recovery_attempts/' + ATTEMPT + '.json', '9f7af3f0b174571424bdf171bb0a7c947a3bbde626a94c6d8fc39ef13b4eea20'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f'),
        ]:
            self.assertEqual('sha256:' + digest, candidate.sha(ROOT / relative))


if __name__ == '__main__': unittest.main()
