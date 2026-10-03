"""Fresh neutral phase and V50 sessions through actual scheduler hooks and cold replay."""
import unittest
import test_development_r10g_recovery_route as shared
class StanceEntryRoute(shared.FiniteRecoveryRoute):
    policy_id = "r10i_v50_flexed_entry_route_v1"
    run_label = "R10I"
    baseline_event_count = 66
    contract_prefix = "r10i"
    contract_version = "v4"
    task_contract = "r10i_flexed_entry_finite_cycle_contract_v1.json"
if __name__ == "__main__": unittest.main()
