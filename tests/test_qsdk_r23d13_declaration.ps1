#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$declarationPath = Join-Path $turningRoot "r23d13_residual_pose_authority_preregistration_v1.json"
$oraclePath = Join-Path $turningRoot "r23d13_residual_pose_authority.py"
$oracleTestPath = Join-Path $turningRoot "test_r23d13_residual_pose_authority.py"
$stageZeroGatePath = Join-Path $repoRoot "sdk\run_qsdk_r23d13_stage_zero_gate.ps1"
$predecessorPath = Join-Path $turningRoot "r23d12_physical_closure_v1.json"
$predecessorAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d12_closure.ps1"
$temporalPath = Join-Path $turningRoot "r23d10_quiescent_taper.py"
$compositionPath = Join-Path $turningRoot "r23d11_stability_assisted_taper.py"
$compositionDeclarationPath = Join-Path $turningRoot "r23d11_stability_assisted_taper_preregistration_v1.json"

function Assert-R23D13([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D13Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-R23D13Array([object[]]$Actual, [object[]]$Expected, [string]$Message) {
    Assert-R23D13 (
        ($Actual | ConvertTo-Json -Compress -Depth 20) -ceq
        ($Expected | ConvertTo-Json -Compress -Depth 20)
    ) $Message
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\")
$origin = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D13 (
    $root -ceq "C:\Users\Cole\CodeStuff\games\SporeSpore" -and
    $origin -ceq "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 repository identity mismatch"

foreach ($path in @(
    $declarationPath,
    $oraclePath,
    $oracleTestPath,
    $stageZeroGatePath,
    $predecessorPath,
    $predecessorAuditPath,
    $temporalPath,
    $compositionPath,
    $compositionDeclarationPath
)) {
    Assert-R23D13 (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D13 required source is missing: $path"
    )
}

$declaration = Get-Content -LiteralPath $declarationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$predecessor = Get-Content -LiteralPath $predecessorPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D13 (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d13_residual_pose_authority_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.campaign_id -ceq
        "QSDK-R23D13-RESIDUAL-POSE-AUTHORITY-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D13" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_development_screen_after_consumed_valid_finite_negative"
) "QSDK-R23D13 declaration identity changed"

$lineage = $declaration.lineage
Assert-R23D13 (
    [string]$lineage.immutable_predecessor_gate_id -ceq "QSDK-R23D12" -and
    [string]$lineage.predecessor_physical_source_commit -ceq
        "662763fc4eab164c56dbc06bd76e3cd618dd8515" -and
    [string]$lineage.predecessor_closure_commit -ceq
        "e93ac8a42407926ff55fcde876402e68bfdf8038" -and
    [bool]$lineage.predecessor_same_identity_rerun_forbidden -and
    [bool]$lineage.predecessor_scientific_negative -and
    [string]$lineage.predecessor_selected_terminal_policy_id -ceq "NONE" -and
    [int]$lineage.predecessor_stage_a_world_count -eq 2 -and
    [int]$lineage.predecessor_stage_b_world_count -eq 0 -and
    (Get-R23D13Sha256 $predecessorPath) -ceq
        [string]$lineage.predecessor_closure_raw_sha256 -and
    (Get-R23D13Sha256 $predecessorAuditPath) -ceq
        [string]$lineage.predecessor_closure_audit_raw_sha256 -and
    [string]$predecessor.status -ceq
        "closed_consumed_valid_none_stage_a_negative_heading_quiescent_taper_failure" -and
    [string]$predecessor.immutable_completion_record.campaign_result_classification -ceq
        "valid_none_stage_a" -and
    [bool]$predecessor.immutable_completion_record.scientific_negative -and
    [bool]$predecessor.attempt.one_shot_identity_consumed -and
    -not [bool]$predecessor.attempt.same_identity_rerun_allowed -and
    [int]$predecessor.attempt.stage_b_worker_process_count -eq 0
) "QSDK-R23D13 immutable predecessor boundary changed"

$use = $declaration.declared_use_of_predecessor_data
Assert-R23D13 (
    [bool]$use.development_informed -and
    -not [bool]$use.independent_validation -and
    [string]$use.positive_trace_raw_sha256 -ceq
        "sha256:1c4751730e64865b22573a0da56f728327722c621114ee26b9083d0d261c5309" -and
    [string]$use.negative_trace_raw_sha256 -ceq
        "sha256:43cfdfa3c1f7caa2b3a41e83591804f64daf4e29a137da439b6f7b87bcb22b58" -and
    [int]$use.positive_active_terminal_row_count -eq 439 -and
    [int]$use.positive_existing_trace_rows_where_declared_floor_exceeds_temporal_scale -eq 0 -and
    [int]$use.negative_active_terminal_row_count -eq 540 -and
    [int]$use.negative_existing_trace_rows_where_declared_floor_exceeds_temporal_scale -eq 132 -and
    [int]$use.negative_first_existing_trace_step_where_declared_floor_exceeds_temporal_scale -eq 3400 -and
    [int]$use.negative_maximum_existing_trace_numerator_increase -eq 82 -and
    [int]$use.negative_best_state_declared_tilt_floor_numerator -eq 50 -and
    [int]$use.negative_best_state_declared_joint_error_floor_numerator -eq 38 -and
    [int]$use.negative_final_state_declared_tilt_floor_numerator -eq 83 -and
    [int]$use.negative_final_state_declared_joint_error_floor_numerator -eq 71 -and
    [bool]$use.projection_is_controller_output_only -and
    -not [bool]$use.counterfactual_physics_outcome_claimed -and
    -not [bool]$use.counterfactual_success_claimed
) "QSDK-R23D13 disclosed predecessor-data use changed"

$distinct = $declaration.scientifically_distinct_successor
Assert-R23D13 (
    [bool]$distinct.new_campaign_identity -and
    [bool]$distinct.fresh_worlds_required -and
    -not [bool]$distinct.fixture_changed -and
    -not [bool]$distinct.morphology_changed -and
    -not [bool]$distinct.walking_turning_controller_changed -and
    -not [bool]$distinct.r23d10_temporal_state_machine_changed -and
    -not [bool]$distinct.terminal_horizon_or_deadline_changed -and
    -not [bool]$distinct.walking_turning_or_safety_threshold_changed -and
    -not [bool]$distinct.stage_a_selector_changed -and
    -not [bool]$distinct.stage_a_or_stage_b_topology_changed -and
    -not [bool]$distinct.r23d11_whole_body_pre_taper_composition_changed -and
    [bool]$distinct.final_active_authority_scalar_changed -and
    [bool]$distinct.measured_state_feedback_added -and
    [int]$distinct.new_tunable_gain_count -eq 0 -and
    [int]$distinct.new_decision_threshold_count -eq 0 -and
    [string]$distinct.new_policy_id -ceq
        "sporespore_residual_pose_authority_quiescent_taper_v1" -and
    -not [bool]$distinct.arm_identity_or_command_sign_is_control_input -and
    -not [bool]$distinct.marker_only_same_policy_rerun
) "QSDK-R23D13 scientific distinction changed"

$temporal = $declaration.inherited_temporal_contract
Assert-R23D13 (
    (Get-R23D13Sha256 $temporalPath) -ceq [string]$temporal.source_raw_sha256 -and
    [int]$temporal.terminal_step_count -eq 900 -and
    [int]$temporal.maximum_active_step_count -eq 540 -and
    [int]$temporal.minimum_quiescent_taper_step_count -eq 120 -and
    [int]$temporal.minimum_passive_step_count -eq 360 -and
    [double]$temporal.coarse_maximum_torso_tilt_rad -eq 0.035 -and
    [double]$temporal.coarse_maximum_joint_position_error_rad -eq 0.32 -and
    [double]$temporal.tight_maximum_torso_tilt_rad -eq 0.01 -and
    [double]$temporal.tight_maximum_joint_position_error_rad -eq 0.2 -and
    -not [bool]$temporal.deadline_forced_handoff_can_pass -and
    -not [bool]$temporal.mode_reactivation_after_passive_handoff_permitted -and
    [bool]$temporal.every_post_handoff_step_requires_all_four_contacts -and
    [bool]$temporal.every_post_handoff_step_requires_zero_native_actuation -and
    [bool]$temporal.all_900_terminal_steps_execute
) "QSDK-R23D13 inherited temporal contract changed"

$composition = $declaration.inherited_whole_body_composition
Assert-R23D13 (
    (Get-R23D13Sha256 $compositionDeclarationPath) -ceq
        [string]$composition.preregistration_raw_sha256 -and
    (Get-R23D13Sha256 $compositionPath) -ceq [string]$composition.oracle_raw_sha256 -and
    [string]$composition.policy_id -ceq
        "sporespore_support_centroid_assisted_quiescent_taper_v1" -and
    [int]$composition.ordered_actuator_count -eq 8 -and
    [double]$composition.neutral_base_velocity_limit_rad_s -eq 0.35 -and
    [double]$composition.maximum_absolute_stability_velocity_delta_rad_s -eq 0.075 -and
    [double]$composition.maximum_pre_taper_combined_velocity_magnitude_rad_s -eq 0.425 -and
    [bool]$composition.unavailable_stability_observation_forces_exact_zero_stability_contribution -and
    [bool]$composition.complete_neutral_plus_stability_command_is_feedback_scaled -and
    [bool]$composition.host_mapping_applied_once_after_feedback_scale -and
    [bool]$composition.passive_mode_bypasses_neutral_and_stability_actuation
) "QSDK-R23D13 inherited whole-body composition changed"

$feedback = $declaration.residual_pose_authority_contract
Assert-R23D13Array @($feedback.feedback_inputs) @(
    "ordered_four_foot_contacts",
    "torso_tilt_rad",
    "maximum_absolute_joint_position_error_rad"
) "QSDK-R23D13 feedback inputs changed"
Assert-R23D13 (
    [int]$feedback.scale_denominator -eq 120 -and
    [int]$feedback.all_four_contacts_false_floor_numerator -eq 120 -and
    [int]$feedback.minimum_supported_floor_numerator -eq 1 -and
    [int]$feedback.maximum_floor_numerator -eq 120 -and
    [double]$feedback.numerical_ceiling_tolerance -eq 1e-12 -and
    [bool]$feedback.tight_and_coarse_limits_are_inherited_decision_thresholds_not_new_fitted_gains -and
    [bool]$feedback.authority_floor_may_never_reduce_inherited_temporal_authority -and
    [bool]$feedback.recovery_may_never_reactivate_after_passive_handoff -and
    [bool]$feedback.complete_combined_velocity_scaled_once_before_host_mapping -and
    -not [bool]$feedback.per_actuator_or_limb_role_branching -and
    -not [bool]$feedback.arm_identity_heading_sign_or_outcome_branching
) "QSDK-R23D13 residual-pose feedback law changed"

$oracle = $declaration.pure_zero_world_oracle
Assert-R23D13 (
    (Get-R23D13Sha256 $oraclePath) -ceq [string]$oracle.source_raw_sha256 -and
    (Get-R23D13Sha256 $oracleTestPath) -ceq [string]$oracle.test_raw_sha256 -and
    [int]$oracle.declared_canary_count -eq 10 -and
    [int]$oracle.declared_mutation_control_count -eq 20 -and
    [int]$oracle.new_tunable_gain_count -eq 0 -and
    [int]$oracle.native_engine_route_count -eq 0 -and
    [int]$oracle.world_build_count -eq 0
) "QSDK-R23D13 pure zero-world oracle changed"

$stageA = $declaration.stage_a_mujoco_screen
$stageB = $declaration.stage_b_three_engine_confirmation
Assert-R23D13Array @($stageA.ordered_arm_ids) @(
    "positive_heading", "negative_heading"
) "QSDK-R23D13 Stage A arms changed"
Assert-R23D13Array @($stageB.ordered_engine_ids) @(
    "godot_jolt", "rapier_parry", "mujoco"
) "QSDK-R23D13 Stage B engines changed"
Assert-R23D13Array @($stageB.ordered_arm_ids) @(
    "reference_zero", "positive_heading", "negative_heading"
) "QSDK-R23D13 Stage B arms changed"
Assert-R23D13 (
    [int]$stageA.declared_world_count -eq 2 -and
    [bool]$stageA.positive_arm_no_regression_required -and
    -not [bool]$stageA.parallel_execution_permitted -and
    -not [bool]$stageA.replacement_or_selective_rerun_permitted -and
    [int]$stageB.declared_world_count_if_launched -eq 9 -and
    -not [bool]$stageB.parallel_execution_permitted -and
    [bool]$stageB.reference_zero_requires_zero_command_straight_walk_compatibility -and
    [bool]$stageB.complete_nine_report_aggregate_required
) "QSDK-R23D13 stage topology changed"

$authority = $declaration.stage_zero_authority
$claims = $declaration.claim_boundary
Assert-R23D13 (
    [bool]$authority.declaration_complete -and
    [bool]$authority.pure_feedback_oracle_complete -and
    [int]$authority.native_engine_route_count -eq 0 -and
    [int]$authority.physical_worker_count -eq 0 -and
    [int]$authority.evaluator_implementation_count -eq 0 -and
    [int]$authority.supervisor_implementation_count -eq 0 -and
    [int]$authority.physical_process_launch_count -eq 0 -and
    [int]$authority.model_construction_count -eq 0 -and
    [int]$authority.world_attempt_count -eq 0 -and
    [int]$authority.world_build_count -eq 0 -and
    -not [bool]$authority.physical_execution_authorized -and
    [bool]$claims.stage_zero_design_complete -and
    -not [bool]$claims.residual_pose_authority_hypothesis_physically_tested -and
    -not [bool]$claims.stage_a_result_exists -and
    -not [bool]$claims.stage_b_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D13 stage-zero authority or claims changed"

$allowed = @(
    "sdk/run_qsdk_r23d13_stage_zero_gate.ps1",
    "sdk/turning/r23d13_residual_pose_authority.py",
    "sdk/turning/r23d13_residual_pose_authority_preregistration_v1.json",
    "sdk/turning/test_r23d13_residual_pose_authority.py",
    "tests/test_qsdk_r23d13_declaration.ps1"
) | Sort-Object
$actual = @(
    git -C $repoRoot ls-files --cached --others --exclude-standard |
        Where-Object { [IO.Path]::GetFileName($_) -match "r23d13" } |
        Sort-Object
)
Assert-R23D13 (($actual -join "|") -ceq ($allowed -join "|")) (
    "QSDK-R23D13 stage zero unexpectedly contains a future route: $($actual -join '|')"
)

$pythonOutput = @(
    & $Python -m unittest sdk.turning.test_r23d13_residual_pose_authority -v 2>&1
) -join "`n"
Assert-R23D13 (
    $LASTEXITCODE -eq 0 -and
    $pythonOutput.Contains("Ran 6 tests") -and
    $pythonOutput.Contains("OK")
) "QSDK-R23D13 pure residual-pose authority tests failed: $pythonOutput"
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D13_DECLARATION_PASS canaries=10 mutations=20 gains=0 " +
    "predecessor_worlds=2 fresh_worlds=0 native_routes=0 workers=0 " +
    "models=0 worlds=0 turning=False equivalence=False physical_authority=False"
)
