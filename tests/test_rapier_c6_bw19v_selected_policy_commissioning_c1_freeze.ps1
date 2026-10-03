#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c1_preregistration.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_selected_policy_commissioning_c1.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c1_closure.json"
$expectedPreregistrationRawSha256 = (
    "231ddf65d2f12137f1215182c9076b46cd5f1adf3e0db2443ac4da1ecf1af319"
)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Read-RepoText {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repoRoot $RelativePath
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "The C6-RAP-BW19V-C1 source is missing: $RelativePath"
    return Get-Content -Raw -LiteralPath $path
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Message
    )

    Assert-Exact (
        $Text.Contains($Needle, [System.StringComparison]::Ordinal)
    ) $Message
}

Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "The C6-RAP-BW19V-C1 preregistration is missing"
Assert-Exact (
    (Get-Sha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "The C6-RAP-BW19V-C1 preregistration changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath)
) "C6-RAP-BW19V-C1 already has a closure; the prospective freeze audit is stale"

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-BW19V-C1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_c1_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        "9b9369ca131035d0cdccc0206d7a2bc56ab81ad7"
) "The C6-RAP-BW19V-C1 freeze identity changed"

$study = $preregistration.study_class
Assert-Exact (
    [string]$study.classification -ceq
        "outcome_exposed_single_body_technical_commissioning" -and
    [int]$study.world_count -eq 1 -and
    [int]$study.morphology_count -eq 1 -and
    -not [bool]$study.fresh_morphology -and
    [bool]$study.morphology_outcome_exposed -and
    -not [bool]$study.independent_validation -and
    -not [bool]$study.development_selection -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_noninferiority_or_equivalence -and
    -not [bool]$study.cohort_size_adequacy_argument_required -and
    [bool]$study.technical_commissioning_authority_if_passed
) "The C6-RAP-BW19V-C1 study class or inferential boundary changed"

$policy = $preregistration.portable_policy_identity
Assert-Exact (
    [string]$policy.candidate_id -ceq "BW19V-B" -and
    [string]$policy.candidate_composition_digest -ceq
        "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77" -and
    [string]$policy.controller_candidate_id -ceq "BW15F-B" -and
    [string]$policy.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$policy.controller_policy_digest -ceq
        "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd" -and
    [string]$policy.reference_descriptor_runtime_profile_sha256 -ceq
        "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413" -and
    [string]$policy.stability_policy_id -ceq
        "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
    [string]$policy.portable_plan_operation -ceq
        "plan_scheduled_load_transfer_v3" -and
    [string]$policy.mapping_operation -ceq
        "map_endpoint_force_to_joint_v3" -and
    [string]$policy.stability_influence_operation -ceq
        "bound_stability_influence_v3" -and
    [double]$policy.global_requested_correction_scale -eq 0.5 -and
    [bool]$policy.global_scale_applied_before_magnitude_and_slew -and
    [int]$policy.morphology_material_seed_failure_and_outcome_branch_count -eq 0
) "The exact BW19V-B/BW15F-B portable composition changed"

$hostContract = $preregistration.host_contract
$response = $preregistration.source_derived_response_contract
Assert-Exact (
    [string]$hostContract.host -ceq "rapier3d" -and
    [string]$hostContract.host_version -ceq "0.34.0" -and
    [string]$hostContract.motor_model -ceq "ForceBased" -and
    [bool]$hostContract.motor_model_explicit_builder_selection -and
    [bool]$hostContract.motor_model_explicit_mutable_update_selection -and
    [bool]$hostContract.motor_model_readback_required_every_command -and
    [double]$hostContract.motor_stiffness_nm_per_rad -eq 40.0 -and
    [double]$hostContract.motor_damping_nm_s_per_rad -eq 10.0 -and
    [int]$hostContract.solver_iterations -eq 16 -and
    [int]$hostContract.internal_pgs_iterations -eq 3 -and
    [int]$hostContract.internal_stabilization_iterations -eq 5 -and
    [double]$hostContract.authored_ground_and_robot_friction -eq 0.95 -and
    [double]$hostContract.characterized_controller_friction -eq 0.94 -and
    [bool]$hostContract.friction_held_fixed -and
    -not [bool]$hostContract.friction_robustness_claim -and
    -not [bool]$hostContract.normal_load_measurement_available -and
    [bool]$hostContract.raw_multishape_contact_impulses_not_used_as_per_foot_loads -and
    [string]$response.profile_id -ceq
        "rapier_force_based_velocity_residual_v1" -and
    [string]$response.composition_formula -ceq
        "raw_canonical_velocity_delta_rad_s=generalized_torque_command_nm/motor_damping_nm_s_per_rad" -and
    [double]$response.canonical_to_host_velocity_sign -eq 1.0 -and
    [double]$response.global_scale -eq 0.5 -and
    [double]$response.maximum_absolute_position_delta_rad -eq 0.0 -and
    [double]$response.maximum_absolute_velocity_delta_rad_s -eq 0.075 -and
    [double]$response.maximum_velocity_delta_slew_per_step_rad_s -eq 0.01 -and
    [bool]$response.scale_then_magnitude_then_slew_order -and
    [bool]$response.requested_generalized_torque_is_not_a_measurement -and
    -not [bool]$response.exact_realized_incremental_torque_claim
) "The C6-RAP-BW19V-C1 host or source-derived response contract changed"

$fixture = $preregistration.physical_fixture
$gate = $preregistration.composition_integrity_gate
$preflight = $preregistration.preflight_contract
Assert-Exact (
    [string]$fixture.morphology_id -ceq "qsdk_r05_generated_s169" -and
    [string]$fixture.compiled_s169_runtime_profile_sha256 -ceq
        "sha256:312957dedabd3bd0eb7160c5cc69c7788bc7927acaedc42dc609a781f9c6c7db" -and
    [bool]$fixture.runtime_profile_hash_differs_from_reference_because_torso_length_scale_is_descriptor_dependent -and
    [int]$fixture.maximum_controller_semantic_steps -eq 3232 -and
    [bool]$gate.composition_attempt_count_equals_controller_semantic_step_count -and
    [bool]$gate.available_unavailable_and_infeasible_counts_partition_attempts -and
    [double]$gate.global_scale_exact_on_every_step -eq 0.5 -and
    [int]$gate.nonzero_effective_host_application_count_minimum -eq 1 -and
    [int]$gate.motor_model_readback_mismatch_count -eq 0 -and
    [bool]$gate.all_eight_final_motor_writes_once_per_controller_step -and
    [bool]$preflight.must_complete_before_any_physics_world -and
    [bool]$preflight.complete_declared_3232_step_synthetic_horizon -and
    [bool]$preflight.available_partial_support_and_fail_zero_paths_exercised -and
    [bool]$preflight.perfect_synthetic_whole_report_passes -and
    [bool]$preflight.wrong_scale_canary_fails -and
    [bool]$preflight.composition_count_canary_fails -and
    [bool]$preflight.motor_model_mismatch_canary_fails -and
    [bool]$preflight.missing_nonzero_application_canary_fails -and
    [int]$preflight.preflight_world_build_count -eq 0 -and
    [int]$preflight.preflight_scene_insertion_count -eq 0 -and
    [int]$preflight.preflight_physics_state_mutation_count -eq 0
) "The C6-RAP-BW19V-C1 fixture, composition gate, or preflight changed"

$execution = $preregistration.execution_contract
Assert-Exact (
    [bool]$execution.clean_source_required -and
    [bool]$execution.head_must_equal_origin_main -and
    [bool]$execution.attempt_receipt_reserved_before_physical_process_launch -and
    [bool]$execution.completion_receipt_retained_after_every_physical_process_exit -and
    [bool]$execution.any_physical_process_launch_consumes_the_campaign_identity -and
    [bool]$execution.runtime_abort_is_retained_as_an_abnormal_attempt_not_a_scientific_result -and
    [bool]$execution.abnormal_attempt_requires_immutable_closure_not_a_rerun -and
    [bool]$execution.first_complete_report_for_source_is_final -and
    [bool]$execution.existing_artifact_overwrite_forbidden -and
    [bool]$execution.negative_report_retention_required -and
    [bool]$execution.same_identity_rerun_forbidden_after_closure -and
    [bool]$execution.evidence_must_live_beneath_sibling_SporeSpore_Evidence
) "The one-attempt supervisor contract changed"

foreach ($claim in @(
    "independent_validation",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "material_robustness",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "cross_engine_c6",
    "different_physics_engines",
    "locomotion_acceptance",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)) {
    Assert-Exact (
        -not [bool]$preregistration.claim_boundary[$claim]
    ) "The prospective campaign may not authorize $claim"
}
Assert-Exact (
    [bool]$preregistration.claim_boundary.technical_commissioning_only
) "The prospective campaign lost its technical-commissioning-only boundary"

$compositionSource = Read-RepoText (
    "sdk\adapters\rapier\src\bw19v_composition.rs"
)
$campaignSource = Read-RepoText (
    "sdk\adapters\rapier\src\bw19v_commissioning.rs"
)
$locomotionSource = Read-RepoText (
    "sdk\adapters\rapier\src\locomotion.rs"
)
$binarySource = Read-RepoText (
    "sdk\adapters\rapier\src\bin\bw19v_commissioning.rs"
)
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath

foreach ($binding in @(
    "BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE: f64 = 0.5;",
    "RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD: f64 = 10.0;",
    "RAPIER_BW19V_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S: f64 = 0.075;",
    "RAPIER_BW19V_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S: f64 = 0.010;",
    "plan_scheduled_load_transfer_v3",
    "map_endpoint_force_to_joint_v3",
    "bound_stability_influence_v3",
    "generalized_torque_nm / RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD",
    "C6_RAP_BW19V_INACTIVE_CONTACT_NOT_EXACT_ZERO"
)) {
    Assert-TextContains -Text $compositionSource -Needle $binding -Message (
        "The BW19V composition binding changed: $binding"
    )
}
foreach ($binding in @(
    "const COMPLETE_SYNTHETIC_HORIZON_STEPS: u64 = MAXIMUM_CONTROLLER_SEMANTIC_STEPS;",
    "build_bw19v_robot(&compiled)?",
    "robot.apply_bw19v_composed_actuation(&receipt.ordered_commands)?",
    '"wrong_scale_canary_rejected"',
    '"composition_count_canary_rejected"',
    '"motor_model_canary_rejected"',
    '"missing_nonzero_application_canary_rejected"',
    'report["rapier_selected_policy_physical_c6"] = json!(false);'
)) {
    Assert-TextContains -Text $campaignSource -Needle $binding -Message (
        "The BW19V campaign gate changed: $binding"
    )
}
foreach ($binding in @(
    "build_robot_with_friction(compiled, 1.0)",
    "build_robot_with_friction(compiled, BW19V_AUTHORED_FRICTION)",
    ".set_motor_model(MotorModel::ForceBased)",
    "Some(MotorModel::ForceBased)",
    "rapier_active_pair_presence_equals_support_bearing_v1"
)) {
    Assert-TextContains -Text $locomotionSource -Needle $binding -Message (
        "The active Rapier host path changed: $binding"
    )
}
foreach ($binding in @(
    "--preflight-only",
    "refusing to overwrite report",
    "std::fs::rename(&temporary, path)",
    "retained a complete negative report"
)) {
    Assert-TextContains -Text $binarySource -Needle $binding -Message (
        "The BW19V physical binary retention contract changed: $binding"
    )
}
foreach ($binding in @(
    '[switch]$PreflightOnly',
    "HEAD == origin/main == GitHub",
    "reserved_before_physical_process_launch",
    "physical_process_exited_without_report_abnormal_attempt",
    "any process launch consumes this campaign identity",
    "attempt and completion receipts are durable",
    "SporeSpore_Evidence"
)) {
    Assert-TextContains -Text $runnerSource -Needle $binding -Message (
        "The BW19V supervisor contract changed: $binding"
    )
}

[void][scriptblock]::Create($runnerSource)

$evidenceRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence"
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorCampaignDirectories = @(
        Get-ChildItem `
            -LiteralPath $evidenceRoot `
            -Directory `
            -Filter "c6-rapier-bw19v-selected-policy-c1-*"
    )
    Assert-Exact (
        $priorCampaignDirectories.Count -eq 0
    ) "A C6-RAP-BW19V-C1 physical attempt already exists; freeze is no longer unopened"
}

& pwsh -NoLogo -NoProfile -File $runnerPath -PreflightOnly
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The complete C6-RAP-BW19V-C1 zero-world preflight failed"

Write-Output (
    "C6_RAP_BW19V_C1_FREEZE_PASS " +
    "study=outcome_exposed_single_body_technical_commissioning " +
    "policy=BW19V-B scale=0.5 solver=16/3/5 worlds=0 " +
    "physical_authority=False"
)
