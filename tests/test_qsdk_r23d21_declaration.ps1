[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$declarationPath = Join-Path $repoRoot "sdk\turning\r23d21_reduced_yaw_authority_preregistration_v1.json"
$predecessorPath = Join-Path $repoRoot "sdk\turning\r23d20_physical_closure_v1.json"

function Require-Equal {
    param([object]$Actual, [object]$Expected, [string]$Label)
    if ($Actual -ne $Expected) {
        throw "R23D21_DECLARATION:$Label expected='$Expected' actual='$Actual'"
    }
}

function Require-True {
    param([object]$Actual, [string]$Label)
    if ($Actual -ne $true) { throw "R23D21_DECLARATION:$Label must be true" }
}

$d = Get-Content -LiteralPath $declarationPath -Raw | ConvertFrom-Json
$predecessorDigest = "sha256:" + (
    Get-FileHash -LiteralPath $predecessorPath -Algorithm SHA256
).Hash.ToLowerInvariant()

Require-Equal $d.schema_version "sporespore_qsdk_r23d21_reduced_yaw_authority_preregistration_v1" "schema"
Require-Equal $d.status "prospectively_frozen_stage_zero_zero_world_only" "status"
Require-Equal $d.campaign_id "QSDK-R23D21-REDUCED-YAW-AUTHORITY-GODOT-DEVELOPMENT" "campaign"
Require-Equal $d.gate_id "QSDK-R23D21" "gate"
Require-Equal $d.immutable_lineage.predecessor_gate_id "QSDK-R23D20" "predecessor"
Require-Equal $d.immutable_lineage.predecessor_closure_raw_sha256 $predecessorDigest "predecessor_digest"
Require-True $d.immutable_lineage.predecessor_same_identity_rerun_forbidden "predecessor_consumed"
Require-Equal $d.immutable_lineage.predecessor_scientific_positive $false "no_predecessor_positive"
Require-True $d.immutable_lineage.predecessor_scientific_negative "predecessor_negative"
Require-Equal $d.immutable_lineage.predecessor_world_attempt_count 3 "attempts"
Require-Equal $d.immutable_lineage.predecessor_world_build_count 3 "builds"

Require-Equal $d.retained_mechanism_observation.all_three_warmup_trajectories_identical_through_step 599 "warmup_identity"
Require-Equal $d.retained_mechanism_observation.divergence_begins_only_at_commanded_turn_step 600 "divergence_boundary"
Require-Equal $d.retained_mechanism_observation.reference_commanded_phase_yaw_sign_crossing_count 12 "reference_crossings"
Require-Equal $d.retained_mechanism_observation.reference_requested_steering_saturation_step_count 331 "reference_saturation"
Require-Equal $d.retained_mechanism_observation.negative_requested_steering_saturation_step_count 338 "negative_saturation"

Require-Equal $d.scientifically_distinct_successor.new_policy_id "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1" "policy"
Require-Equal $d.scientifically_distinct_successor.parent_policy_id "sporespore_balanced_wave_r23d19_heading_aligned_path_v1" "parent_policy"
Require-Equal $d.scientifically_distinct_successor.only_controller_parameter_change "yaw_error_stride_gain_per_rad" "only_delta"
Require-Equal $d.scientifically_distinct_successor.parent_yaw_error_stride_gain_per_rad 1.3 "parent_gain"
Require-Equal $d.scientifically_distinct_successor.candidate_yaw_error_stride_gain_per_rad 1.0 "candidate_gain"
foreach ($unchanged in @(
    "cross_track_frame_changed", "steering_filter_changed", "stride_transform_changed",
    "forward_velocity_mechanism_changed", "fixture_changed", "morphology_changed",
    "actuation_mode_changed", "material_profile_changed", "threshold_changed",
    "horizon_changed", "terminal_policy_changed", "engine_specific_gait_logic_permitted",
    "arm_identity_or_outcome_branching_permitted"
)) { Require-Equal $d.scientifically_distinct_successor.$unchanged $false $unchanged }

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

Require-True $d.zero_world_entry_gate.exact_profile_delta_and_policy_digest_required "profile_gate"
Require-True $d.zero_world_entry_gate.exact_selected_policy_adapter_start_required "adapter_gate"
Require-True $d.zero_world_entry_gate.actual_diagnostics_composition_path_required "diagnostics_gate"
Require-True $d.zero_world_entry_gate.worker_failure_terminal_controls_required "terminal_gate"
Require-Equal $d.zero_world_entry_gate.full_historical_cold_sweep_required_per_campaign $false "no_flat_tax"
Require-Equal $d.zero_world_entry_gate.physical_execution_authorized $false "physics_closed"
Require-Equal $d.zero_world_entry_gate.world_attempt_count 0 "zero_attempts"
Require-Equal $d.zero_world_entry_gate.world_build_count 0 "zero_builds"
Require-True $d.claims.stage_zero_design_complete "stage_zero"
Require-True $d.claims.r23d20_failure_mechanism_diagnosed "diagnosed"
foreach ($claim in @(
    "reduced_yaw_authority_implemented", "finite_godot_command_conditioned_turning",
    "bilateral_signed_turning", "portable_basic_turning", "finite_three_engine_turning",
    "cross_engine_equivalence", "q_sdk_r23_satisfied", "prone_to_standing",
    "release_authorized", "physical_acceptance_authority"
)) { Require-Equal $d.claims.$claim $false "claim_$claim" }

Write-Output "QSDK_R23D21_DECLARATION_PASS"
