"""Ramp, separate V50 hold and V50 sessions through actual scheduler hooks and cold replay."""
import unittest
import test_development_r10g_recovery_route as shared
class SettledHoldRoute(shared.FiniteRecoveryRoute):
    policy_id = "r10j_v50_settled_hold_route_v1"
    run_label = "R10J"
    baseline_event_count = 67
    contract_prefix = "r10j"
    contract_version = "v6"
    task_contract = "r10j_settled_hold_finite_cycle_contract_v1.json"
if __name__ == "__main__": unittest.main()
