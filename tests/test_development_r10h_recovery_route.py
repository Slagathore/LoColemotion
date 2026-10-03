"""Fresh neutral phase and V50 sessions through actual scheduler hooks and cold replay."""
import unittest
import test_development_r10g_recovery_route as shared
class StanceEntryRoute(shared.FiniteRecoveryRoute):
    policy_id = "r10h_v50_stance_entry_route_v1"
    run_label = "R10H"
    baseline_event_count = 66
    contract_prefix = "r10h"
    contract_version = "v3"
    task_contract = "r10h_stance_entry_finite_cycle_contract_v1.json"
if __name__ == "__main__": unittest.main()
