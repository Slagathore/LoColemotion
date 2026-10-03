"""V44 selects the shared worker and frozen-source resolver, not a new harness."""
import unittest
import test_development_v39_recovery_route as shared


class SupportHoldPostureRecoveryRoute(shared.AirborneReferenceRecoveryRoute):
    policy_id='sporespore_balanced_wave_recovery_support_hold_posture_v1'
    run_label='V44'
    contract_family='support_hold_posture'
    contract_version=1


if __name__=='__main__':unittest.main()
