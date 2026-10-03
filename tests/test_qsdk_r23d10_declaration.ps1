$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedOrigin = "https://github.com/Slagathore/sporespore.git"
$declarationPath = Join-Path $repoRoot "sdk\turning\r23d10_quiescent_taper_preregistration_v1.json"
$oraclePath = Join-Path $repoRoot "sdk\turning\r23d10_quiescent_taper.py"
$oracleTestPath = Join-Path $repoRoot "sdk\turning\test_r23d10_quiescent_taper.py"
$predecessorClosurePath = Join-Path $repoRoot "sdk\turning\r23d9_physical_closure_v1.json"

function Assert-R23D10Declaration {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-ExactArray {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Actual,
        [Parameter(Mandatory = $true)]
        [object[]]$Expected,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Assert-R23D10Declaration (
        ($Actual | ConvertTo-Json -Compress -Depth 8) -ceq
        ($Expected | ConvertTo-Json -Compress -Depth 8)
    ) $Message
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\")
$origin = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D10Declaration (
    $root -ceq $expectedRoot -and $origin -ceq $expectedOrigin
) "QSDK-R23D10 declaration repository identity mismatch"

foreach ($path in @(
    $declarationPath,
    $oraclePath,
    $oracleTestPath,
    $predecessorClosurePath
)) {
    Assert-R23D10Declaration (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D10 declaration input is missing: $path"
    )
}

$expectedHashes = @{
    $declarationPath = "8a367a311b1133737037900bb0922f14a3c31d0e3f063fc39bb2fc554f263b3b"
    $oraclePath = "0d9929ae30df8000d9685d4cdfea3b102c46a0d1586b14981ad6e5cbdb176eb0"
    $oracleTestPath = "74ffcbd930821140bafc4889f56030432a5c8e86f6f56399412fb3acc810672b"
    $predecessorClosurePath = "464d97cb79eac4ba7a83ac3d0904137b44e05aed7c02a226bc27f3ade90cfcbf"
}
foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-R23D10Declaration (
        (Get-RawSha256 -Path ([string]$entry.Key)) -ceq ([string]$entry.Value)
    ) "QSDK-R23D10 raw source changed: $($entry.Key)"
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath | ConvertFrom-Json
$predecessor = Get-Content -Raw -LiteralPath $predecessorClosurePath | ConvertFrom-Json

Assert-R23D10Declaration (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d10_quiescent_taper_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.campaign_id -ceq
        "QSDK-R23D10-SUPPORT-POSE-CONFIRMED-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D10" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_development_screen_after_consumed_infrastructure_invalid_predecessor"
) "QSDK-R23D10 declaration identity changed"

Assert-R23D10Declaration (
    [string]$predecessor.status -ceq
        "closed_consumed_infrastructure_invalid_after_two_stage_a_worlds_evaluator_marker_mismatch" -and
    [string]$predecessor.gate_id -ceq "QSDK-R23D9" -and
    [bool]$predecessor.attempt.one_shot_identity_consumed -and
    -not [bool]$predecessor.attempt.same_identity_rerun_allowed -and
    -not [bool]$predecessor.scientific_observation_boundary.campaign_level_scientific_result_exists -and
    -not [bool]$predecessor.claims.command_conditioned_turning -and
    [string]$declaration.lineage.predecessor_closure_raw_sha256 -ceq
        "sha256:464d97cb79eac4ba7a83ac3d0904137b44e05aed7c02a226bc27f3ade90cfcbf" -and
    -not [bool]$declaration.lineage.predecessor_diagnostic_payload_promoted -and
    -not [bool]$declaration.declared_use_of_predecessor_data.counterfactual_success_claimed
) "QSDK-R23D10 immutable predecessor boundary changed"

$data = $declaration.declared_use_of_predecessor_data
Assert-R23D10Declaration (
    [bool]$data.development_informed -and
    -not [bool]$data.independent_validation -and
    [string]$data.positive_trace_raw_sha256 -ceq
        "sha256:ff02fb0adf03a70eb892ab3f11298cbe60380e6cf7b46f4a186e2949ddde4afa" -and
    [string]$data.negative_trace_raw_sha256 -ceq
        "sha256:29d5b19d110de4f0bdb9c2e48bdd2379221a7202c64d6dc6caa96a77a11fe2d6" -and
    [double]$data.r23d9_positive_last_30_support_maximum_torso_tilt_rad -eq
        0.0046328184846318905 -and
    [double]$data.r23d9_positive_last_30_support_maximum_joint_position_error_rad -eq
        0.17540983309682578 -and
    [double]$data.r23d9_negative_last_30_support_minimum_torso_tilt_rad -eq
        0.02392804760050467 -and
    [double]$data.r23d9_negative_last_30_support_minimum_joint_position_error_rad -eq
        0.26349168895154307 -and
    [int]$data.r23d9_negative_final_continuous_support_window_first_terminal_step_zero_based -eq 382 -and
    [int]$data.r23d9_negative_first_post_handoff_contact_loss_terminal_step_zero_based -eq 528 -and
    [int]$data.r23d9_negative_post_handoff_contact_loss_step_count -eq 93
) "QSDK-R23D10 disclosed development data changed"

$distinct = $declaration.scientifically_distinct_successor
Assert-R23D10Declaration (
    -not [bool]$distinct.fixture_changed -and
    -not [bool]$distinct.morphology_changed -and
    -not [bool]$distinct.turning_controller_policy_changed -and
    -not [bool]$distinct.walking_turning_and_safety_thresholds_changed -and
    -not [bool]$distinct.stage_a_and_stage_b_shape_changed -and
    [bool]$distinct.active_terminal_policy_changed -and
    [bool]$distinct.terminal_horizon_changed -and
    [bool]$distinct.support_only_confirmation_replaced -and
    -not [bool]$distinct.marker_only_same_policy_rerun -and
    [string]$distinct.new_policy_id -ceq
        "sporespore_support_pose_confirmed_quiescent_taper_v1"
) "QSDK-R23D10 scientific distinction changed"

$policy = $declaration.terminal_policy_contract
Assert-R23D10Declaration (
    [string]$policy.initial_mode -ceq "active_neutral_acquisition" -and
    [string]$policy.quiescent_mode -ceq "active_quiescent_taper" -and
    [string]$policy.passive_mode -ceq "irreversible_zero_actuation_stability" -and
    [int]$policy.terminal_step_count -eq 900 -and
    [int]$policy.maximum_active_step_count -eq 540 -and
    [int]$policy.minimum_quiescent_taper_step_count -eq 120 -and
    [int]$policy.minimum_passive_step_count -eq 360 -and
    [int]$policy.ordered_actuator_count -eq 8
) "QSDK-R23D10 terminal policy shape changed"

$derivation = $declaration.numeric_derivation
Assert-R23D10Declaration (
    [double]$derivation.coarse_maximum_torso_tilt_rad.value -eq 0.035 -and
    [double]$derivation.coarse_maximum_joint_position_error_rad.value -eq 0.32 -and
    [double]$derivation.tight_maximum_torso_tilt_rad.value -eq 0.01 -and
    [double]$derivation.tight_maximum_joint_position_error_rad.value -eq 0.2 -and
    [int]$derivation.minimum_quiescent_taper_steps.value -eq 120 -and
    [int]$derivation.maximum_active_terminal_steps.value -eq 540 -and
    [int]$derivation.minimum_passive_zero_actuation_steps.value -eq 360 -and
    [int]$derivation.terminal_step_count.value -eq 900
) "QSDK-R23D10 numeric derivation changed"

Assert-R23D10Declaration (
    [string]$policy.coarse_pose_predicate -ceq
        "all_four_contacts and torso_tilt_rad <= 0.035 and maximum_absolute_joint_position_error_rad <= 0.32" -and
    [string]$policy.tight_pose_predicate -ceq
        "all_four_contacts and torso_tilt_rad <= 0.01 and maximum_absolute_joint_position_error_rad <= 0.2" -and
    [string]$policy.taper_velocity_scale_fraction_for_completed_taper_count_c -ceq
        "max(1, 120 - c) / 120" -and
    [bool]$policy.taper_scale_is_applied_to_canonical_velocity_limit_before_host_mapping -and
    [bool]$policy.taper_resets_to_acquisition_on_coarse_pose_failure -and
    [bool]$policy.tight_pose_may_authorize_handoff_only_after_120_completed_taper_steps -and
    [int]$policy.deadline_forced_transition_after_active_step_zero_based -eq 539 -and
    -not [bool]$policy.deadline_forced_handoff_can_pass -and
    -not [bool]$policy.mode_reactivation_after_passive_handoff_permitted -and
    [bool]$policy.all_900_terminal_steps_execute
) "QSDK-R23D10 taper or transition contract changed"

Assert-ExactArray @($declaration.required_oracle_canaries) @(
    "coarse_pose_from_first_step_then_120_step_taper_passes",
    "r23d9_positive_shaped_delayed_entry_then_taper_passes",
    "coarse_pose_loss_resets_taper_before_later_confirmation",
    "tight_pose_never_reached_forces_deadline_and_fails",
    "post_handoff_contact_loss_fails_without_reactivation"
) "QSDK-R23D10 oracle canary inventory changed"
Assert-R23D10Declaration (
    @($declaration.required_mutation_controls).Count -eq 16 -and
    (@($declaration.required_mutation_controls | Select-Object -Unique)).Count -eq 16
) "QSDK-R23D10 mutation inventory changed"

$stageA = $declaration.stage_a_mujoco_screen
$stageB = $declaration.stage_b_three_engine_confirmation
Assert-ExactArray @($stageA.ordered_arm_ids) @("positive_heading", "negative_heading") (
    "QSDK-R23D10 Stage A arms changed"
)
Assert-ExactArray @($stageB.ordered_engine_ids) @("godot_jolt", "rapier_parry", "mujoco") (
    "QSDK-R23D10 Stage B engines changed"
)
Assert-ExactArray @($stageB.ordered_arm_ids) @("reference_zero", "positive_heading", "negative_heading") (
    "QSDK-R23D10 Stage B arms changed"
)
Assert-R23D10Declaration (
    [int]$stageA.declared_world_count -eq 2 -and
    -not [bool]$stageA.parallel_execution_permitted -and
    [int]$stageB.declared_world_count_if_launched -eq 9 -and
    -not [bool]$stageB.parallel_execution_permitted -and
    [bool]$stageB.reference_zero_requires_zero_command_straight_walk_compatibility
) "QSDK-R23D10 stage topology changed"

$wire = $declaration.evaluator_cli_wire_contract
Assert-R23D10Declaration (
    [string]$wire.stage_a_command -ceq "evaluate-stage-a" -and
    [string]$wire.stage_a_success_marker -ceq
        "QSDK_R23D10_STAGE_A_EVALUATION " -and
    [string]$wire.complete_command -ceq "evaluate-complete" -and
    [string]$wire.complete_success_marker -ceq
        "QSDK_R23D10_COMPLETE_EVALUATION " -and
    -not [bool]$wire.generic_shared_success_marker_permitted -and
    [bool]$wire.prephysical_integration_must_execute_each_cli_command -and
    [bool]$wire.prephysical_integration_must_compare_exact_producer_and_consumer_prefix -and
    -not [bool]$wire.function_only_evaluator_tests_sufficient
) "QSDK-R23D10 evaluator CLI wire contract changed"

$authority = $declaration.stage_zero_authority
$claims = $declaration.claim_boundary
Assert-R23D10Declaration (
    [bool]$authority.declaration_complete -and
    [bool]$authority.pure_temporal_policy_required -and
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
    -not [bool]$claims.quiescent_taper_hypothesis_physically_tested -and
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
) "QSDK-R23D10 stage-zero authority or claims changed"

$forbiddenPaths = @(
    "sdk\run_qsdk_r23d10_supervisor.ps1",
    "sdk\turning\r23d10_physical_evaluator.py",
    "sdk\turning\r23d10_physical_implementation_contract_v1.json",
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d10_quiescent_taper_physical.py",
    "sdk\adapters\rapier\src\qsdk_r23d10_quiescent_taper.rs",
    "tests\test_sdk_qsdk_r23d10_quiescent_taper_godot_jolt_worker.gd"
)
foreach ($relative in $forbiddenPaths) {
    Assert-R23D10Declaration (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) (
        "QSDK-R23D10 undeclared later-stage surface already exists: $relative"
    )
}

$python = Get-Command python -ErrorAction Stop
$output = @(& $python.Source $oracleTestPath 2>&1)
$exitCode = $LASTEXITCODE
Assert-R23D10Declaration ($exitCode -eq 0) (
    "QSDK-R23D10 pure oracle failed: $($output -join ' ')"
)
$markers = @($output | Where-Object {
    [string]$_ -like "QSDK_R23D10_ORACLE_PASS *"
})
Assert-R23D10Declaration ($markers.Count -eq 1) (
    "QSDK-R23D10 pure oracle marker count changed: $($markers.Count)"
)
$marker = [string]$markers[0]
foreach ($token in @(
    "canaries=5",
    "mutations=16",
    "terminal_steps=900",
    "maximum_active=540",
    "taper=120",
    "passive=360",
    "processes=0",
    "models=0",
    "worlds=0",
    "physical_authority=False"
)) {
    Assert-R23D10Declaration ($marker.Contains($token)) (
        "QSDK-R23D10 pure oracle marker lost token: $token"
    )
}

Write-Output (
    "QSDK_R23D10_DECLARATION_PASS status=stage-zero canaries=5 mutations=16 " +
    "terminal_steps=900 active=540 taper=120 passive=360 stage_a_worlds=0 " +
    "stage_b_worlds=0 physical_authority=False turning=False"
)
