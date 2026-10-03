"""The shared real adapter/ledger/reader suite, selected by V33 data."""
import test_development_v32_walking_policy as shared


class BoundedSupportWalkingPolicy(shared.WalkingPolicy):
    policy_id = 'sporespore_balanced_wave_recovery_bounded_support_v1'
    component_resource = 'res://sdk/development/recovery_candidates/v33-bounded-support-v1.json'
    policy_contract_path = 'sdk/development/recovery_bounded_support_walking_policy_contract_v1.json'
    run_label = 'V33'
