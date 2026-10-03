"""Actual supervisor selection, walking lifecycle and independent V8 replay."""
import unittest

import test_development_measured_entry_profile as shared


class RateLimitedRecoveryProfile(shared.MeasuredEntryProfile):
    mode = 'ObserveRateLimitedRecovery'
    fields_function = 'Get-DevelopmentRateLimitedRecoveryFields'
    native_script = 'res://tests/test_development_rate_limited_recovery_profile.gd'
    producer_script = 'res://tests/test_development_rate_limited_recovery_replay_fixture.gd'
    producer_marker = 'DEVELOPMENT_RATE_LIMITED_RECOVERY_REPLAY_FIXTURE '
    expected_schema = 'sporespore_development_rate_limited_recovery_smoke_child_v1'
    expected_work = 'SDK1-GODOT-RATE-LIMITED-RECOVERY-SMOKE-V1'
    expected_gate_count = 76
    expected_steps = 286
    missing_cache_code = b'SMOKE_RATE_LIMITED_RECOVERY_REQUIRES_CONTEXT_CACHE'
    root_prefix = 'development-rate-limited-recovery-profile-'


if __name__ == '__main__':
    unittest.main()
