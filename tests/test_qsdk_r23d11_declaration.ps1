#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedOrigin = "https://github.com/Slagathore/sporespore.git"
$turningRoot = Join-Path $repoRoot "sdk\turning"
$declarationPath = Join-Path $turningRoot "r23d11_stability_assisted_taper_preregistration_v1.json"
$oraclePath = Join-Path $turningRoot "r23d11_stability_assisted_taper.py"
$oracleTestPath = Join-Path $turningRoot "test_r23d11_stability_assisted_taper.py"
$predecessorPath = Join-Path $turningRoot "r23d10_physical_closure_v1.json"
$temporalPath = Join-Path $turningRoot "r23d10_quiescent_taper.py"

function Assert-R23D11 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-ExactArray {
    param([object[]]$Actual, [object[]]$Expected, [string]$Message)
    Assert-R23D11 (
        ($Actual | ConvertTo-Json -Compress -Depth 10) -ceq
        ($Expected | ConvertTo-Json -Compress -Depth 10)
    ) $Message
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\")
$origin = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D11 ($root -ceq $expectedRoot -and $origin -ceq $expectedOrigin) (
    "QSDK-R23D11 repository identity mismatch"
)

$expectedHashes = [ordered]@{
    $declarationPath = "4eae08c30fdd6af9ebdc7a43da4b277a05c404ce49bdd239ce4d895dd99d23e7"
    $oraclePath = "2580f8a4dc489de387c93ed427c70e06541058d7b30ccae592fac7e511f47678"
    $oracleTestPath = "5c93c6a5454c090813c1b03fcea68411c0c94202e5762655f388f44eec450ae6"
    $predecessorPath = "cf8306e8e1a91b53860da328c31a7b2e1ec3f23653bf6053c2cbd63ba6964f78"
    $temporalPath = "0d9929ae30df8000d9685d4cdfea3b102c46a0d1586b14981ad6e5cbdb176eb0"
    (Join-Path $repoRoot "sdk\core\src\stability.rs") = "4181580b3a08b6b684a474e8cd3b24605858276cad9a948ba4afaf3a1b678ad1"
    (Join-Path $repoRoot "sdk\core\src\canonical_actuation.rs") = "e2d7e27edaf7caa218d95a5ed7966f5c6d317ff8c5990c5cd0e2876e1d485d05"
    (Join-Path $repoRoot "sdk\adapters\mujoco\sporespore_mujoco_adapter\selected_policy_development.py") = "306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46"
    (Join-Path $repoRoot "sdk\adapters\rapier\src\bw19v_composition.rs") = "105b9dab60b9614ba19e0811c3dcae1aaf297bb6b29db005eebccb7bf5b3b1af"
    (Join-Path $repoRoot "scripts\lab\gait\sdk_godot_jolt_adapter.gd") = "043bdb94b586fd24048a2595a1d4495791b9e88e5f4fce40961963bb749ef10b"
}
foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-R23D11 (Test-Path -LiteralPath ([string]$entry.Key) -PathType Leaf) (
        "QSDK-R23D11 required input missing: $($entry.Key)"
    )
    Assert-R23D11 (
        (Get-RawSha256 ([string]$entry.Key)) -ceq ([string]$entry.Value)
    ) "QSDK-R23D11 required source changed: $($entry.Key)"
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -Depth 100
$predecessor = Get-Content -Raw -LiteralPath $predecessorPath |
    ConvertFrom-Json -Depth 100

Assert-R23D11 (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d11_stability_assisted_taper_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.campaign_id -ceq
        "QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D11" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_development_screen_after_consumed_valid_finite_negative"
) "QSDK-R23D11 declaration identity changed"

Assert-R23D11 (
    [string]$predecessor.gate_id -ceq "QSDK-R23D10" -and
    [string]$predecessor.immutable_completion_record.campaign_result_classification -ceq
        "valid_none_stage_a" -and
    [bool]$predecessor.immutable_completion_record.scientific_negative -and
    [bool]$predecessor.attempt.one_shot_identity_consumed -and
    -not [bool]$predecessor.attempt.same_identity_rerun_allowed -and
    [string]$predecessor.immutable_completion_record.selected_terminal_policy_id -ceq
        "NONE" -and
    [int]$predecessor.attempt.stage_b_worker_process_count -eq 0 -and
    [string]$declaration.lineage.predecessor_closure_raw_sha256 -ceq
        "sha256:cf8306e8e1a91b53860da328c31a7b2e1ec3f23653bf6053c2cbd63ba6964f78"
) "QSDK-R23D11 immutable predecessor boundary changed"

$data = $declaration.declared_use_of_predecessor_data
Assert-R23D11 (
    [bool]$data.development_informed -and
    -not [bool]$data.independent_validation -and
    [string]$data.positive_trace_raw_sha256 -ceq
        "sha256:b1c4555659bc60292768c2e0e16504fef03a0ba69cd3cd6e72ae9dedb465496a" -and
    [string]$data.negative_trace_raw_sha256 -ceq
        "sha256:50242d20338e9100bb62170ddf5a67fe8458172afcb63283a63c6b44ec05023d" -and
    [double]$data.positive_minimum_active_torso_tilt_rad -eq 0.001102316862293035 -and
    [double]$data.positive_minimum_active_joint_position_error_rad -eq 0.051229947604733414 -and
    [double]$data.negative_minimum_active_torso_tilt_rad -eq 0.02016302087153935 -and
    [double]$data.negative_minimum_active_joint_position_error_rad -eq 0.23392008522378124 -and
    [double]$data.negative_final_active_torso_tilt_rad -eq 0.023156201635509317 -and
    [double]$data.negative_final_active_joint_position_error_rad -eq 0.2491202646278005 -and
    -not [bool]$data.r23d10_trace_contains_direct_lateral_velocity -and
    -not [bool]$data.r23d10_trace_contains_direct_body_angular_velocity -and
    -not [bool]$data.residual_momentum_cause_claimed -and
    -not [bool]$data.counterfactual_success_claimed
) "QSDK-R23D11 disclosed development data changed"

$distinct = $declaration.scientifically_distinct_successor
Assert-R23D11 (
    -not [bool]$distinct.fixture_changed -and
    -not [bool]$distinct.morphology_changed -and
    -not [bool]$distinct.turning_controller_policy_changed -and
    -not [bool]$distinct.walking_turning_and_safety_thresholds_changed -and
    -not [bool]$distinct.stage_a_and_stage_b_shape_changed -and
    -not [bool]$distinct.r23d10_temporal_handoff_policy_changed -and
    [bool]$distinct.active_terminal_actuation_composition_changed -and
    [int]$distinct.new_tunable_gain_count -eq 0 -and
    [string]$distinct.new_policy_id -ceq
        "sporespore_support_centroid_assisted_quiescent_taper_v1" -and
    -not [bool]$distinct.arm_identity_or_command_sign_is_control_input -and
    -not [bool]$distinct.marker_only_same_policy_rerun
) "QSDK-R23D11 scientific distinction changed"

$temporal = $declaration.inherited_temporal_contract
Assert-R23D11 (
    [string]$temporal.source_raw_sha256 -ceq
        "sha256:0d9929ae30df8000d9685d4cdfea3b102c46a0d1586b14981ad6e5cbdb176eb0" -and
    [int]$temporal.terminal_step_count -eq 900 -and
    [int]$temporal.maximum_active_step_count -eq 540 -and
    [int]$temporal.minimum_quiescent_taper_step_count -eq 120 -and
    [int]$temporal.minimum_passive_step_count -eq 360 -and
    [string]$temporal.coarse_pose_predicate -ceq
        "all_four_contacts and torso_tilt_rad <= 0.035 and maximum_absolute_joint_position_error_rad <= 0.32" -and
    [string]$temporal.tight_pose_predicate -ceq
        "all_four_contacts and torso_tilt_rad <= 0.01 and maximum_absolute_joint_position_error_rad <= 0.2" -and
    -not [bool]$temporal.deadline_forced_handoff_can_pass -and
    -not [bool]$temporal.mode_reactivation_after_passive_handoff_permitted -and
    [bool]$temporal.all_900_terminal_steps_execute
) "QSDK-R23D11 inherited temporal boundary changed"

$composition = $declaration.stability_assisted_composition_contract
Assert-R23D11 (
    [string]$composition.stability_policy_id -ceq
        "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
    [double]$composition.global_requested_correction_scale -eq 0.5 -and
    [double]$composition.maximum_absolute_position_delta_rad -eq 0.0 -and
    [double]$composition.maximum_absolute_velocity_delta_rad_s -eq 0.075 -and
    [double]$composition.maximum_position_delta_slew_per_step_rad -eq 0.0 -and
    [double]$composition.maximum_velocity_delta_slew_per_step_rad_s -eq 0.01 -and
    [double]$composition.neutral_base_velocity_limit_rad_s -eq 0.35 -and
    [double]$composition.maximum_pre_taper_combined_velocity_magnitude_rad_s -eq 0.425 -and
    [int]$composition.ordered_actuator_count -eq 8 -and
    [bool]$composition.global_stability_scale_applied_before_stability_magnitude_and_slew_limits -and
    [bool]$composition.complete_combined_canonical_velocity_tapered_before_host_mapping -and
    [bool]$composition.canonical_velocity_composed_once -and
    [bool]$composition.host_mapping_applied_once -and
    [bool]$composition.unavailable_stability_observation_forces_exact_zero_stability_contribution -and
    [bool]$composition.passive_mode_bypasses_neutral_and_stability_actuation -and
    -not [bool]$composition.arm_id_heading_sign_or_outcome_may_branch_composition -and
    -not [bool]$composition.fit_to_r23d10_outcomes
) "QSDK-R23D11 active composition contract changed"

$bindings = $declaration.preexisting_reference_bindings
Assert-R23D11 (
    [string]$bindings.portable_stability_core_raw_sha256 -ceq
        "sha256:4181580b3a08b6b684a474e8cd3b24605858276cad9a948ba4afaf3a1b678ad1" -and
    [string]$bindings.canonical_actuation_core_raw_sha256 -ceq
        "sha256:e2d7e27edaf7caa218d95a5ed7966f5c6d317ff8c5990c5cd0e2876e1d485d05" -and
    [string]$bindings.mujoco_reference_composition_raw_sha256 -ceq
        "sha256:306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46" -and
    [string]$bindings.rapier_reference_composition_raw_sha256 -ceq
        "sha256:105b9dab60b9614ba19e0811c3dcae1aaf297bb6b29db005eebccb7bf5b3b1af" -and
    [string]$bindings.godot_reference_adapter_raw_sha256 -ceq
        "sha256:043bdb94b586fd24048a2595a1d4495791b9e88e5f4fce40961963bb749ef10b"
) "QSDK-R23D11 preexisting implementation bindings changed"

Assert-ExactArray @($declaration.required_oracle_canaries) @(
    "available_stability_is_globally_scaled_bounded_and_slew_limited",
    "stability_memory_continues_in_order_across_active_steps",
    "unavailable_observation_falls_back_to_exact_zero_without_fabrication",
    "taper_scales_the_complete_neutral_plus_stability_velocity",
    "sign_mirrored_observations_produce_sign_mirrored_corrections",
    "passive_mode_is_exact_zero_actuation",
    "r23d10_temporal_positive_shape_remains_passing"
) "QSDK-R23D11 oracle inventory changed"
Assert-R23D11 ([int]$declaration.required_mutation_control_count -eq 18) (
    "QSDK-R23D11 mutation count changed"
)

$stageA = $declaration.stage_a_mujoco_screen
$stageB = $declaration.stage_b_three_engine_confirmation
Assert-ExactArray @($stageA.ordered_arm_ids) @("positive_heading", "negative_heading") (
    "QSDK-R23D11 Stage A arms changed"
)
Assert-ExactArray @($stageB.ordered_engine_ids) @("godot_jolt", "rapier_parry", "mujoco") (
    "QSDK-R23D11 Stage B engines changed"
)
Assert-ExactArray @($stageB.ordered_arm_ids) @("reference_zero", "positive_heading", "negative_heading") (
    "QSDK-R23D11 Stage B arms changed"
)
Assert-R23D11 (
    [int]$stageA.declared_world_count -eq 2 -and
    [bool]$stageA.positive_arm_no_regression_required -and
    -not [bool]$stageA.parallel_execution_permitted -and
    -not [bool]$stageA.replacement_or_selective_rerun_permitted -and
    [int]$stageB.declared_world_count_if_launched -eq 9 -and
    -not [bool]$stageB.parallel_execution_permitted -and
    [bool]$stageB.reference_zero_requires_zero_command_straight_walk_compatibility
) "QSDK-R23D11 stage topology changed"

$authority = $declaration.stage_zero_authority
$claims = $declaration.claim_boundary
Assert-R23D11 (
    [bool]$authority.declaration_complete -and
    [bool]$authority.pure_composition_oracle_required -and
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
    -not [bool]$claims.stability_assisted_taper_hypothesis_physically_tested -and
    -not [bool]$claims.stage_a_result_exists -and
    -not [bool]$claims.stage_b_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D11 stage-zero authority or claims changed"

foreach ($relative in @(
    "sdk\turning\r23d11_native_route_contract_v1.json",
    "sdk\turning\r23d11_physical_implementation_contract_v1.json",
    "sdk\turning\r23d11_physical_evaluator.py",
    "sdk\run_qsdk_r23d11_supervisor.ps1",
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d11_stability_assisted_taper_physical.py",
    "sdk\adapters\rapier\src\qsdk_r23d11_stability_assisted_taper.rs",
    "tests\test_sdk_qsdk_r23d11_stability_assisted_taper_godot_jolt_worker.gd"
)) {
    Assert-R23D11 (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) (
        "QSDK-R23D11 undeclared later-stage surface exists: $relative"
    )
}

$python = (Get-Command python -ErrorAction Stop).Source
$output = @(& $python $oracleTestPath 2>&1)
Assert-R23D11 ($LASTEXITCODE -eq 0) (
    "QSDK-R23D11 pure oracle failed: $($output -join ' ')"
)
$markers = @($output | Where-Object {
    [string]$_ -like "QSDK_R23D11_ORACLE_PASS *"
})
Assert-R23D11 ($markers.Count -eq 1) (
    "QSDK-R23D11 oracle marker count changed: $($markers.Count)"
)
$marker = [string]$markers[0]
foreach ($token in @(
    "canaries=7", "mutations=18", "actuators=8", "temporal_steps=900",
    "active_maximum=540", "taper=120", "passive=360", "processes=0",
    "models=0", "worlds=0", "physical_authority=False"
)) {
    Assert-R23D11 ($marker.Contains($token)) (
        "QSDK-R23D11 oracle marker lost token: $token"
    )
}

Write-Output (
    "QSDK_R23D11_DECLARATION_PASS status=stage-zero canaries=7 mutations=18 " +
    "actuators=8 temporal=900 active=540 taper=120 passive=360 " +
    "stage_a_worlds=0 stage_b_worlds=0 physical_authority=False turning=False"
)
