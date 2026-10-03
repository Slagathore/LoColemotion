[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$declarationPath = Join-Path $repoRoot "sdk\turning\r23d19_heading_aligned_path_preregistration_v1.json"
$predecessorPath = Join-Path $repoRoot "sdk\turning\r23d18_physical_closure_v1.json"

function Require-Equal {
    param([object]$Actual, [object]$Expected, [string]$Label)
    if ($Actual -ne $Expected) {
        throw "R23D19_DECLARATION:$Label expected='$Expected' actual='$Actual'"
    }
}

function Require-True {
    param([object]$Actual, [string]$Label)
    if ($Actual -ne $true) {
        throw "R23D19_DECLARATION:$Label must be true"
    }
}

if (-not (Test-Path -LiteralPath $declarationPath -PathType Leaf)) {
    throw "R23D19_DECLARATION:missing declaration"
}
if (-not (Test-Path -LiteralPath $predecessorPath -PathType Leaf)) {
    throw "R23D19_DECLARATION:missing predecessor closure"
}

$d = Get-Content -LiteralPath $declarationPath -Raw | ConvertFrom-Json
$predecessorDigest = "sha256:" + (Get-FileHash -LiteralPath $predecessorPath -Algorithm SHA256).Hash.ToLowerInvariant()

Require-Equal $d.schema_version "sporespore_qsdk_r23d19_heading_aligned_path_preregistration_v1" "schema"
Require-Equal $d.status "prospectively_frozen_stage_zero_zero_world_only" "status"
Require-Equal $d.gate_id "QSDK-R23D19" "gate_id"
Require-Equal $d.study_classification "prospective_exact_finite_godot_jolt_mechanism_development_screen_after_outcome_visible_predecessor" "study_classification"
Require-Equal $d.immutable_lineage.predecessor_closure_raw_sha256 $predecessorDigest "predecessor_digest"
Require-True $d.immutable_lineage.predecessor_same_identity_rerun_forbidden "predecessor_rerun_forbidden"
Require-True $d.outcome_visible_mechanism_basis.development_informed "development_informed"
Require-Equal $d.outcome_visible_mechanism_basis.independent_validation $false "not_independent"
Require-True $d.outcome_visible_mechanism_basis.rapier_mechanism_is_separate "rapier_separate"
Require-Equal $d.outcome_visible_mechanism_basis.rapier_worlds_authorized_here $false "rapier_worlds_refused"
Require-Equal $d.outcome_visible_mechanism_basis.mujoco_worlds_authorized_here $false "mujoco_worlds_refused"

Require-Equal $d.scientifically_distinct_successor.new_policy_id "sporespore_balanced_wave_r23d19_heading_aligned_path_v1" "new_policy"
Require-Equal $d.scientifically_distinct_successor.parent_policy_id "sporespore_balanced_wave_bw15f_b_v1" "parent_policy"
Require-Equal $d.scientifically_distinct_successor.cross_track_frame_mode_id "command_heading_aligned_task_frame_v1" "frame_mode"
Require-True $d.scientifically_distinct_successor.controller_semantics_changed "semantics_changed"
foreach ($unchanged in @(
    "controller_gain_changed",
    "steering_filter_changed",
    "stride_transform_changed",
    "fixture_changed",
    "morphology_changed",
    "actuation_mode_changed",
    "material_profile_changed",
    "threshold_changed",
    "horizon_changed",
    "terminal_policy_changed",
    "engine_specific_gait_logic_permitted",
    "arm_identity_or_outcome_branching_permitted"
)) {
    Require-Equal $d.scientifically_distinct_successor.$unchanged $false $unchanged
}
Require-True $d.authorized_controller_change.zero_heading_exactly_preserves_parent_projection "zero_heading_parent_projection"
Require-True $d.authorized_controller_change.positive_and_negative_rotation_are_symmetric "symmetric_rotation"
Require-True $d.authorized_controller_change.desired_axes_must_remain_unit_orthogonal_and_in_task_plane "orthonormal_axes"
Require-True $d.authorized_controller_change.all_other_parent_profile_fields_exactly_preserved "parent_fields_preserved"

Require-Equal $d.inherited_physical_contract.engine_id "godot_jolt" "engine"
Require-Equal $d.inherited_physical_contract.controller_step_count 2992 "controller_steps"
Require-Equal $d.inherited_physical_contract.terminal_step_count 960 "terminal_steps"
Require-Equal $d.inherited_physical_contract.total_trace_row_count_per_cell 3952 "trace_rows"
Require-Equal $d.inherited_physical_contract.minimum_absolute_signed_turn_phase_yaw_delta_rad 0.01 "signed_yaw_threshold"
Require-Equal $d.inherited_physical_contract.minimum_command_conditioned_yaw_separation_rad 0.01 "conditioned_yaw_threshold"
Require-Equal $d.inherited_physical_contract.maximum_tilt_rad 0.6 "tilt_threshold"
Require-Equal $d.inherited_physical_contract.tight_maximum_torso_tilt_rad 0.01 "tight_tilt_threshold"
Require-Equal $d.inherited_physical_contract.tight_maximum_joint_position_error_rad 0.2 "tight_joint_threshold"

Require-Equal $d.prospective_screen.declared_cell_count 3 "cell_count"
Require-Equal $d.prospective_screen.declared_world_count 3 "world_count"
Require-True $d.prospective_screen.serialized_execution_required "serialized"
Require-True $d.prospective_screen.all_cells_run_without_outcome_early_stop "no_outcome_early_stop"
Require-Equal $d.prospective_screen.selective_replacement_or_rerun_permitted $false "no_selective_rerun"
Require-Equal $d.prospective_screen.positive_minus_reference_requires_at_least_rad 0.01 "positive_separation"
Require-Equal $d.prospective_screen.negative_minus_reference_requires_at_most_rad -0.01 "negative_separation"
Require-True $d.prospective_screen.positive_authorizes_only_a_distinct_cross_engine_candidate_successor "bounded_authority"

Require-True $d.qualification_and_freeze.campaign_local_permanent_kernel_required "permanent_kernel"
Require-Equal $d.qualification_and_freeze.full_historical_cold_sweep_required_per_campaign $false "no_historical_flat_tax"
Require-Equal $d.qualification_and_freeze.physical_execution_authorized $false "physics_closed"
Require-Equal $d.qualification_and_freeze.world_attempt_count 0 "zero_attempts"
Require-Equal $d.qualification_and_freeze.world_build_count 0 "zero_builds"
Require-True $d.claims.stage_zero_design_complete "stage_zero"
foreach ($claim in @(
    "heading_aligned_mechanism_physically_supported",
    "finite_godot_command_conditioned_turning",
    "bilateral_signed_turning",
    "portable_basic_turning",
    "finite_three_engine_turning",
    "cross_engine_equivalence",
    "q_sdk_r23_satisfied",
    "population_robustness",
    "prone_to_standing",
    "release_authorized",
    "physical_acceptance_authority"
)) {
    Require-Equal $d.claims.$claim $false "claim_$claim"
}

Write-Output "QSDK_R23D19_DECLARATION_PASS"
