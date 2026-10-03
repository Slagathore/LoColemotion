#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d6_policy_compatible_restoration_preregistration_v1.json"
)
$parentClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d5_physical_closure_v1.json"
)
$parentPreregistrationPath = Join-Path $repoRoot (
    "sdk\turning\r23d5_dependency_closed_preregistration_v1.json"
)
$parentImplementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d5_implementation_contract_v1.json"
)

function Assert-R23D6Declaration {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D6RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D6GitBlobOid {
    param([Parameter(Mandatory)][string]$Path)
    $value = (& git -C $repoRoot hash-object -- $Path).Trim()
    if ($LASTEXITCODE -ne 0) { throw "git hash-object failed: $Path" }
    return $value
}

Assert-R23D6Declaration (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $declarationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $parentClosurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $parentPreregistrationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $parentImplementationPath -PathType Leaf)
) "QSDK-R23D6 declaration repository or parent inputs changed"

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$parentClosure = Get-Content -Raw -LiteralPath $parentClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$parentPreregistration = Get-Content -Raw -LiteralPath $parentPreregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100

$campaignId = "QSDK-R23D6-POLICY-COMPATIBLE-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D6"
Assert-R23D6Declaration (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d6_policy_compatible_restoration_preregistration_v1" -and
    [string]$declaration.status -ceq
        "stage_zero_preregistered_policy_compatible_restoration_repair_no_workers_no_physical_authorization" -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_implementation_repair_successor_after_pre_evaluation_policy_composition_failure"
) "QSDK-R23D6 declaration identity changed"

Assert-R23D6Declaration (
    (Get-R23D6RawSha256 $parentClosurePath) -ceq
        [string]$declaration.lineage.predecessor_closure_raw_sha256 -and
    (Get-R23D6RawSha256 $parentPreregistrationPath) -ceq
        [string]$declaration.inherited_scientific_contract.r23d5_preregistration_raw_sha256 -and
    (Get-R23D6RawSha256 $parentImplementationPath) -ceq
        [string]$declaration.inherited_scientific_contract.r23d5_implementation_contract_raw_sha256 -and
    [string]$parentClosure.status -ceq
        "closed_consumed_implementation_invalid_after_stage_a_worlds" -and
    [bool]$parentClosure.attempt.one_shot_identity_consumed -and
    -not [bool]$parentClosure.attempt.same_identity_rerun_allowed -and
    [int]$parentClosure.attempt.launched_stage_a_worker_process_count -eq 2 -and
    [int]$parentClosure.attempt.world_attempt_count -eq 2 -and
    [int]$parentClosure.attempt.world_build_count -eq 2 -and
    -not [bool]$parentClosure.attempt.stage_b_authorization_created -and
    -not [bool]$parentClosure.claims.scientific_positive -and
    -not [bool]$parentClosure.claims.scientific_negative -and
    [string]$parentClosure.successor_boundary.successor_id -ceq $gateId -and
    [bool]$parentClosure.successor_boundary.same_unresolved_physical_estimand_may_be_retained -and
    -not [bool]$parentClosure.successor_boundary.numeric_outcome_threshold_change_required
) "QSDK-R23D6 immutable predecessor boundary changed"

$lineage = $declaration.lineage
Assert-R23D6Declaration (
    [int]$lineage.predecessor_stage_a_worker_process_count -eq 2 -and
    [int]$lineage.predecessor_stage_a_world_attempt_count -eq 2 -and
    [int]$lineage.predecessor_stage_a_world_build_count -eq 2 -and
    [int]$lineage.predecessor_completed_turning_controller_horizon_count -eq 2 -and
    [int]$lineage.predecessor_restoration_receipt_count -eq 0 -and
    [int]$lineage.predecessor_trace_artifact_count -eq 0 -and
    -not [bool]$lineage.predecessor_stage_b_opened -and
    [bool]$lineage.same_unresolved_physical_estimand_may_be_retained_by_closure -and
    [bool]$lineage.predecessor_reclassification_forbidden -and
    [bool]$lineage.predecessor_completion_rewrite_forbidden -and
    [string]$lineage.predecessor_failure_code -ceq
        "QSDK_R23D5_MJC_PHYSICAL_WORKER_ERROR:KeyError:'forward_velocity_foot_placement'"
) "QSDK-R23D6 predecessor mechanism or interpretation changed"

$inheritance = $declaration.inherited_scientific_contract
Assert-R23D6Declaration (
    -not [bool]$inheritance.fixture_changed -and
    -not [bool]$inheritance.turning_controller_policy_changed -and
    -not [bool]$inheritance.terminal_restoration_policy_id_changed -and
    [bool]$inheritance.terminal_restoration_policy_composition_derivation_changed -and
    -not [bool]$inheritance.host_profiles_changed -and
    -not [bool]$inheritance.outcome_numeric_thresholds_changed -and
    -not [bool]$inheritance.turn_heading_magnitude_changed -and
    -not [bool]$inheritance.turn_duration_changed -and
    -not [bool]$inheritance.turn_onset_changed -and
    -not [bool]$inheritance.controller_horizon_changed -and
    -not [bool]$inheritance.restoration_horizon_changed -and
    -not [bool]$inheritance.passive_settle_changed -and
    -not [bool]$inheritance.stage_a_schedule_changed -and
    -not [bool]$inheritance.stage_a_selector_changed -and
    -not [bool]$inheritance.stage_b_schedule_changed -and
    -not [bool]$inheritance.result_classification_changed -and
    -not [bool]$inheritance.trace_contract_changed -and
    (@($inheritance.only_implementation_repair_surfaces) -join "|") -ceq
        "bw5r_b_registered_linear_stride_heading_delta_derivation|production_shaped_bw5r_b_restoration_step_zero_preflight"
) "QSDK-R23D6 scientific inheritance changed"

$snapshot = $declaration.frozen_schedule_and_gate_snapshot
$parentSnapshot = $parentPreregistration.frozen_schedule_and_gate_snapshot
$snapshotKeys = @(
    "morphology_id", "campaign_seed", "physics_hz", "authored_sliding_friction",
    "selected_candidate_id", "selected_policy_id", "selected_policy_digest",
    "fixed_onset_id", "turn_start_semantic_step", "turn_duration_steps",
    "turning_controller_semantic_step_count", "terminal_restoration_step_count",
    "maximum_four_contact_acquisition_steps",
    "required_consecutive_all_four_contact_hold_steps", "passive_settle_step_count",
    "total_traced_step_count", "terminal_restoration_policy_id",
    "maximum_absolute_restoration_joint_velocity_rad_s",
    "maximum_absolute_requested_or_held_steering_fraction",
    "minimum_absolute_signed_turn_phase_yaw_delta_rad",
    "minimum_final_forward_displacement_m", "maximum_tilt_rad",
    "minimum_torso_height_m", "minimum_contact_cycles_per_limb",
    "exact_active_native_application_count", "exact_passive_native_application_count",
    "all_outcome_accumulators_cover_all_3772_steps",
    "zero_torso_ground_contact_required", "zero_controller_errors_required",
    "zero_safe_no_actuation_during_active_phases_required",
    "zero_nonfinite_observations_required",
    "zero_actuator_application_mismatches_required"
)
foreach ($key in $snapshotKeys) {
    Assert-R23D6Declaration (
        ($snapshot[$key] | ConvertTo-Json -Compress -Depth 20) -ceq
            ($parentSnapshot[$key] | ConvertTo-Json -Compress -Depth 20)
    ) "QSDK-R23D6 inherited schedule or gate changed: $key"
}
Assert-R23D6Declaration (
    ($snapshot.turn_heading_offset_rad_by_arm | ConvertTo-Json -Compress) -ceq
        ($parentSnapshot.turn_heading_offset_rad_by_arm | ConvertTo-Json -Compress)
) "QSDK-R23D6 turn-arm schedule changed"

Assert-R23D6Declaration (
    [int]$declaration.stage_a_mujoco_terminal_restoration_screen.declared_cell_count -eq 2 -and
    [int]$declaration.stage_a_mujoco_terminal_restoration_screen.declared_world_count -eq 2 -and
    (@($declaration.stage_a_mujoco_terminal_restoration_screen.ordered_arm_ids) -join "|") -ceq
        "positive_heading|negative_heading" -and
    -not [bool]$declaration.stage_a_mujoco_terminal_restoration_screen.parallel_execution_permitted -and
    -not [bool]$declaration.stage_a_mujoco_terminal_restoration_screen.replacement_or_selective_rerun_permitted -and
    [int]$declaration.stage_b_three_engine_confirmation.declared_cell_count_if_launched -eq 9 -and
    [int]$declaration.stage_b_three_engine_confirmation.declared_world_count_if_launched -eq 9 -and
    (@($declaration.stage_b_three_engine_confirmation.ordered_engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    (@($declaration.stage_b_three_engine_confirmation.ordered_arm_ids) -join "|") -ceq
        "reference_zero|positive_heading|negative_heading" -and
    -not [bool]$declaration.stage_b_three_engine_confirmation.parallel_execution_permitted -and
    -not [bool]$declaration.stage_b_three_engine_confirmation.replacement_or_selective_rerun_permitted -and
    -not [bool]$declaration.stage_b_three_engine_confirmation.stage_a_mujoco_reports_may_substitute_for_stage_b
) "QSDK-R23D6 stage schedule changed"

$authorityPaths = @($declaration.policy_derivation_authorities | ForEach-Object {
    [string]$_.path
})
Assert-R23D6Declaration (
    ($authorityPaths -join "|") -ceq (
        "sdk/core/src/controller.rs|sdk/core/src/runtime.rs|" +
        "sdk/turning/heading_command_contract_v1.json|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_pose_hold_restoration_mv6.py|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d5_dependency_closed.py"
    ) -and
    @($authorityPaths | Group-Object | Where-Object Count -gt 1).Count -eq 0
) "QSDK-R23D6 derivation-authority set changed"
foreach ($authority in $declaration.policy_derivation_authorities) {
    $path = Join-Path $repoRoot ([string]$authority.path)
    Assert-R23D6Declaration (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-R23D6RawSha256 $path) -ceq [string]$authority.raw_sha256 -and
        (Get-R23D6GitBlobOid $path) -ceq [string]$authority.git_blob_oid
    ) "QSDK-R23D6 derivation authority changed: $($authority.path)"
}

$compatibility = $declaration.bw5r_b_policy_compatibility_contract
Assert-R23D6Declaration (
    [string]$compatibility.supported_policy_id -ceq
        "sporespore_balanced_wave_bw5r_b_v1" -and
    [string]$compatibility.supported_profile_schema_version -ceq
        "sporespore_balanced_wave_filtered_profile_v1" -and
    $null -eq $compatibility.registered_steering_stride_transform_id -and
    [string]$compatibility.registered_transform_name -ceq
        "linear_bilateral_hip_stride_scale_v1" -and
    [double]$compatibility.left_lateral_side_sign -eq -1.0 -and
    [double]$compatibility.right_lateral_side_sign -eq 1.0 -and
    [double]$compatibility.maximum_absolute_held_steering_fraction -eq 0.4 -and
    [double]$compatibility.minimum_possible_scale -eq 0.6 -and
    [double]$compatibility.maximum_possible_scale -eq 1.4 -and
    $null -eq $compatibility.forward_velocity_foot_placement_mode_id -and
    -not [bool]$compatibility.forward_velocity_foot_placement_receipt_member_expected -and
    [string]$compatibility.exact_current_scale_equation -ceq
        "1 + lateral_side_sign * current_held_steering_fraction" -and
    [string]$compatibility.exact_activation_scale_equation -ceq
        "1 + lateral_side_sign * activation_held_steering_fraction" -and
    [string]$compatibility.exact_nominal_unsteered_hip_target_equation -ceq
        "requested_target_position_rad / current_scale" -and
    [string]$compatibility.exact_heading_target_delta_equation -ceq
        "nominal_unsteered_hip_target_rad * lateral_side_sign * (current_held_steering_fraction - activation_held_steering_fraction)" -and
    [string]$compatibility.independent_oracle_equation -ceq
        "requested_target_position_rad * (1 - activation_scale / current_scale)" -and
    [double]$compatibility.non_hip_heading_target_delta_rad -eq 0.0 -and
    [bool]$compatibility.policy_identity_mismatch_fails_closed -and
    [bool]$compatibility.unexpected_forward_velocity_receipt_member_fails_closed -and
    [bool]$compatibility.missing_forward_velocity_receipt_member_is_required_and_supported -and
    [bool]$compatibility.generic_missing_member_defaults_are_forbidden -and
    [bool]$compatibility.registered_transform_mismatch_fails_closed -and
    [bool]$compatibility.nonfinite_or_nonpositive_scale_fails_closed -and
    [double]$compatibility.independent_oracle_tolerance_rad -eq 1e-12
) "QSDK-R23D6 BW5R-B compatibility contract changed"

$tolerance = [double]$compatibility.independent_oracle_tolerance_rad
$mutationRejected = @{}
foreach ($mutation in @($declaration.required_oracle_mutation_controls)) {
    $mutationRejected[[string]$mutation] = $false
}
foreach ($canary in @($declaration.independent_oracle_canaries)) {
    $side = [double]$canary.lateral_side_sign
    $nominal = [double]$canary.nominal_unsteered_hip_target_rad
    $current = [double]$canary.current_held_steering_fraction
    $activation = [double]$canary.activation_held_steering_fraction
    $requested = [double]$canary.requested_target_position_rad
    $expected = [double]$canary.expected_heading_target_delta_rad
    $currentScale = 1.0 + $side * $current
    $activationScale = 1.0 + $side * $activation
    $subject = ($requested / $currentScale) * $side * ($current - $activation)
    $oracle = $requested * (1.0 - $activationScale / $currentScale)
    Assert-R23D6Declaration (
        $currentScale -ge 0.6 -and $currentScale -le 1.4 -and
        [Math]::Abs($requested - $nominal * $currentScale) -le $tolerance -and
        [Math]::Abs($subject - $expected) -le $tolerance -and
        [Math]::Abs($oracle - $expected) -le $tolerance
    ) "QSDK-R23D6 independent oracle canary failed: $($canary.canary_id)"

    $mutants = @{
        reversed_current_activation_difference = (
            ($requested / $currentScale) * $side * ($activation - $current)
        )
        swapped_lateral_side_sign = (
            ($requested / (1.0 - $side * $current)) * (-$side) *
                ($current - $activation)
        )
        skipped_current_scale_inverse = (
            $requested * $side * ($current - $activation)
        )
        used_activation_scale_as_inverse_denominator = (
            ($requested / $activationScale) * $side * ($current - $activation)
        )
    }
    foreach ($entry in $mutants.GetEnumerator()) {
        if ([Math]::Abs([double]$entry.Value - $expected) -gt $tolerance) {
            $mutationRejected[[string]$entry.Key] = $true
        }
    }
}
foreach ($mutation in @(
    "reversed_current_activation_difference",
    "swapped_lateral_side_sign",
    "skipped_current_scale_inverse",
    "used_activation_scale_as_inverse_denominator"
)) {
    Assert-R23D6Declaration ([bool]$mutationRejected[$mutation]) (
        "QSDK-R23D6 oracle canaries do not distinguish mutation: $mutation"
    )
}
Assert-R23D6Declaration (
    (@($declaration.required_oracle_mutation_controls) -join "|") -ceq (
        "reversed_current_activation_difference|swapped_lateral_side_sign|" +
        "skipped_current_scale_inverse|used_activation_scale_as_inverse_denominator|" +
        "applied_heading_delta_to_knee|read_or_defaulted_forward_velocity_foot_placement|" +
        "accepted_non_bw5r_b_policy_identity|accepted_unregistered_stride_transform"
    )
) "QSDK-R23D6 required mutation-control inventory changed"

$preflight = $declaration.production_shaped_zero_world_preflight_contract
Assert-R23D6Declaration (
    [string]$preflight.release_core_entrypoint_required -ceq
        "LocomotionCore.balanced_wave_policy_step" -and
    [bool]$preflight.real_bw5r_b_actuation_receipt_required -and
    [bool]$preflight.exact_s169_descriptor_required -and
    [bool]$preflight.exact_worker_restoration_step_zero_call_path_required -and
    [bool]$preflight.all_eight_ordered_actuator_commands_required -and
    [bool]$preflight.both_signed_heading_arms_required -and
    [bool]$preflight.positive_and_negative_nonzero_held_steering_receipts_required -and
    [bool]$preflight.receipt_policy_identity_checked_before_composition -and
    [bool]$preflight.receipt_forward_velocity_member_absence_checked_before_composition -and
    [bool]$preflight.independent_algebraic_oracle_checked_per_hip -and
    [bool]$preflight.non_hip_zero_delta_checked_per_knee -and
    [bool]$preflight.all_required_oracle_mutations_rejected -and
    [bool]$preflight.production_worker_path_reaches_complete_restoration_step_zero_receipt -and
    [bool]$preflight.synthetic_mv6_only_restoration_canary_is_insufficient -and
    [int]$preflight.physics_adapter_start_count -eq 0 -and
    [int]$preflight.physical_process_launch_count -eq 0 -and
    [int]$preflight.model_construction_count -eq 0 -and
    [int]$preflight.world_attempt_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0
) "QSDK-R23D6 production-shaped preflight contract changed"

Assert-R23D6Declaration (
    [int]$declaration.stage_zero_proof_requirements.physical_worker_count -eq 0 -and
    -not [bool]$declaration.stage_zero_proof_requirements.production_evaluator_implemented -and
    -not [bool]$declaration.stage_zero_proof_requirements.aggregate_supervisor_implemented -and
    [int]$declaration.stage_zero_proof_requirements.physical_process_launch_count -eq 0 -and
    [int]$declaration.stage_zero_proof_requirements.model_construction_count -eq 0 -and
    [int]$declaration.stage_zero_proof_requirements.world_attempt_count -eq 0 -and
    [int]$declaration.stage_zero_proof_requirements.world_build_count -eq 0 -and
    -not [bool]$declaration.authorization.physical_execution_authorized -and
    -not [bool]$declaration.claim_boundary.stage_a_result_exists -and
    -not [bool]$declaration.claim_boundary.stage_b_result_exists -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence -and
    -not [bool]$declaration.claim_boundary.q_sdk_r23_satisfied -and
    -not [bool]$declaration.claim_boundary.prone_to_standing -and
    -not [bool]$declaration.claim_boundary.release_authorized -and
    -not [bool]$declaration.claim_boundary.physical_acceptance_authority
) "QSDK-R23D6 stage-zero authorization or claim boundary changed"

Write-Host (
    "QSDK_R23D6_DECLARATION_PASS predecessor_worlds=2 " +
    "predecessor_controller_horizons=2 predecessor_restoration_receipts=0 " +
    "stage_a_cells=2 stage_b_cells=9 derivation_authorities=5 " +
    "oracle_canaries=5 mutation_controls=8 workers_implemented=0 " +
    "models=0 worlds=0 turning=False equivalence=False physical_authority=False"
)
