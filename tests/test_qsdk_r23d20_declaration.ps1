[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$declarationPath = Join-Path $repoRoot "sdk\turning\r23d20_actual_session_integration_recovery_preregistration_v1.json"
$predecessorPath = Join-Path $repoRoot "sdk\turning\r23d19_physical_closure_v1.json"

function Require-Equal {
    param([object]$Actual, [object]$Expected, [string]$Label)
    if ($Actual -ne $Expected) {
        throw "R23D20_DECLARATION:$Label expected='$Expected' actual='$Actual'"
    }
}

function Require-True {
    param([object]$Actual, [string]$Label)
    if ($Actual -ne $true) {
        throw "R23D20_DECLARATION:$Label must be true"
    }
}

$d = Get-Content -LiteralPath $declarationPath -Raw | ConvertFrom-Json
$predecessorDigest = "sha256:" + (Get-FileHash -LiteralPath $predecessorPath -Algorithm SHA256).Hash.ToLowerInvariant()

Require-Equal $d.schema_version "sporespore_qsdk_r23d20_actual_session_integration_recovery_preregistration_v1" "schema"
Require-Equal $d.status "prospectively_frozen_stage_zero_zero_world_only" "status"
Require-Equal $d.gate_id "QSDK-R23D20" "gate"
Require-Equal $d.immutable_lineage.predecessor_closure_raw_sha256 $predecessorDigest "predecessor_digest"
Require-True $d.immutable_lineage.predecessor_same_identity_rerun_forbidden "predecessor_consumed"
Require-Equal $d.immutable_lineage.predecessor_scientific_positive $false "no_predecessor_positive"
Require-Equal $d.immutable_lineage.predecessor_scientific_negative $false "no_predecessor_negative"
Require-Equal $d.immutable_lineage.predecessor_world_attempt_count_proved_by_retained_worker_terminals 3 "attempts"
Require-Equal $d.immutable_lineage.predecessor_world_build_count_proved_by_retained_worker_terminals 3 "builds"
Require-Equal $d.observed_failure_mechanism.godot_adapter_missing_policy_id "sporespore_balanced_wave_r23d19_heading_aligned_path_v1" "missing_policy"
Require-Equal $d.observed_failure_mechanism.adapter_start_failure_code "ADAPTER_START_INPUT_INVALID" "adapter_failure"
Require-True $d.observed_failure_mechanism.adapter_start_failed_before_compiled_morphology "precompile_failure"
Require-Equal $d.observed_failure_mechanism.physics_or_controller_outcome_inference_permitted $false "no_outcome_inference"

Require-Equal $d.scientifically_distinct_successor.controller_policy_id "sporespore_balanced_wave_r23d19_heading_aligned_path_v1" "policy"
foreach ($unchanged in @(
    "controller_policy_changed", "controller_semantics_changed", "controller_gain_changed",
    "steering_filter_changed", "stride_transform_changed", "fixture_changed",
    "morphology_changed", "actuation_mode_changed", "material_profile_changed",
    "threshold_changed", "horizon_changed", "terminal_policy_changed",
    "engine_specific_gait_logic_permitted", "arm_identity_or_outcome_branching_permitted"
)) {
    Require-Equal $d.scientifically_distinct_successor.$unchanged $false $unchanged
}
foreach ($change in @(
    "add_selected_policy_to_godot_adapter_balanced_wave_and_full_authority_allowlists",
    "preserve_specific_path_diagnostic_failure_while_retaining_inherited_diagnostics",
    "parse_exactly_one_structured_worker_terminal_independent_of_process_exit_code",
    "retain_worker_failure_world_counts_and_failure_stage_losslessly",
    "reject_missing_duplicate_malformed_wrong_identity_or_exit_schema_mismatch_terminals"
)) {
    Require-True $d.authorized_implementation_changes.$change $change
}
Require-Equal $d.authorized_implementation_changes.change_physics_or_controller_output $false "no_output_change"
Require-Equal $d.authorized_implementation_changes.change_outcome_evaluator_rules $false "no_evaluator_change"

Require-Equal $d.inherited_physical_contract.controller_step_count 2992 "controller_steps"
Require-Equal $d.inherited_physical_contract.terminal_step_count 960 "terminal_steps"
Require-Equal $d.inherited_physical_contract.total_trace_row_count_per_cell 3952 "trace_rows"
Require-Equal $d.inherited_physical_contract.minimum_absolute_signed_turn_phase_yaw_delta_rad 0.01 "yaw_threshold"
Require-Equal $d.inherited_physical_contract.minimum_command_conditioned_yaw_separation_rad 0.01 "separation_threshold"
Require-Equal $d.inherited_physical_contract.tight_maximum_torso_tilt_rad 0.01 "terminal_tilt"
Require-Equal $d.inherited_physical_contract.tight_maximum_joint_position_error_rad 0.2 "terminal_joint_error"
Require-Equal $d.prospective_screen.declared_cell_count 3 "cell_count"
Require-Equal $d.prospective_screen.declared_world_count 3 "world_count"
Require-True $d.prospective_screen.serialized_execution_required "serialized"
Require-True $d.prospective_screen.all_cells_run_without_outcome_early_stop "no_early_stop"
Require-Equal $d.prospective_screen.selective_replacement_or_rerun_permitted $false "no_rerun"

Require-True $d.zero_world_entry_gate.exact_selected_policy_adapter_start_required "adapter_start_gate"
Require-True $d.zero_world_entry_gate.actual_diagnostics_composition_path_required "diagnostics_gate"
Require-True $d.zero_world_entry_gate.nonzero_exit_structured_failure_terminal_reproduction_required "terminal_reproduction"
Require-Equal $d.zero_world_entry_gate.full_historical_cold_sweep_required_per_campaign $false "no_flat_tax"
Require-Equal $d.zero_world_entry_gate.physical_execution_authorized $false "physics_closed"
Require-Equal $d.zero_world_entry_gate.world_attempt_count 0 "zero_attempts"
Require-Equal $d.zero_world_entry_gate.world_build_count 0 "zero_builds"
Require-True $d.claims.stage_zero_design_complete "stage_zero"
Require-True $d.claims.r23d19_failure_mechanism_diagnosed "diagnosed"
foreach ($claim in @(
    "integration_recovery_implemented", "heading_aligned_mechanism_physically_supported",
    "finite_godot_command_conditioned_turning", "bilateral_signed_turning",
    "portable_basic_turning", "finite_three_engine_turning", "cross_engine_equivalence",
    "q_sdk_r23_satisfied", "prone_to_standing", "release_authorized",
    "physical_acceptance_authority"
)) {
    Require-Equal $d.claims.$claim $false "claim_$claim"
}

Write-Output "QSDK_R23D20_DECLARATION_PASS"
