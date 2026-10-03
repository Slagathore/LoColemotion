"""Actual supervisor selection, walking lifecycle and independent V7 replay."""
import unittest

import test_development_measured_entry_profile as shared


class RearwardFoldProfile(shared.MeasuredEntryProfile):
    mode = 'ObserveRearwardFold'
    fields_function = 'Get-DevelopmentRearwardFoldFields'
    native_script = 'res://tests/test_development_rearward_fold_profile.gd'
    producer_script = 'res://tests/test_development_rearward_fold_replay_fixture.gd'
    producer_marker = 'DEVELOPMENT_REARWARD_FOLD_REPLAY_FIXTURE '
    expected_schema = 'sporespore_development_rearward_fold_smoke_child_v1'
    expected_work = 'SDK1-GODOT-REARWARD-FOLD-SMOKE-V1'
    expected_gate_count = 76
    expected_steps = 286
    missing_cache_code = b'SMOKE_REARWARD_FOLD_REQUIRES_CONTEXT_CACHE'
    root_prefix = 'development-rearward-fold-profile-'


if __name__ == '__main__':
    unittest.main()
