#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$closurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_bw19v_selected_policy_commissioning_c1_closure.json"
$runnerPath = Join-Path (
    $repoRoot
) "sdk\run_rapier_c6_bw19v_selected_policy_commissioning_c1.ps1"
$expectedClosureRawSha256 = (
    "e2919cc899df78aebe5d2486bb7250a1388044f2f040f53f23f581d113aa8fae"
)
$expectedPreregistrationRawSha256 = (
    "231ddf65d2f12137f1215182c9076b46cd5f1adf3e0db2443ac4da1ecf1af319"
)
$expectedSourceCommit = "b4e12db533e987b8361fcc2c770be027bef52359"

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Close {
    param(
        [double]$Actual,
        [double]$Expected,
        [double]$Tolerance,
        [string]$Message
    )

    Assert-Exact (
        [double]::IsFinite($Actual) -and
        [math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-HashedArtifact {
    param(
        [Parameter(Mandatory)][hashtable]$Declaration,
        [Parameter(Mandatory)][string]$Name
    )

    $path = [string]$Declaration.path
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Sha256 $path) -ceq
            ([string]$Declaration.sha256).Replace("sha256:", "") -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Declaration.bytes
    ) "The retained C6-RAP-BW19V-C1 $Name changed"
}

function Read-SourceCommitText {
    param([Parameter(Mandatory)][string]$RelativePath)

    $gitPath = $RelativePath.Replace("\", "/")
    $text = (& git -C $repoRoot show "${expectedSourceCommit}:$gitPath") |
        Out-String
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($text)
    ) "The frozen C6-RAP-BW19V-C1 source is unavailable: $RelativePath"
    return $text
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
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "The C6-RAP-BW19V-C1 closure is missing"
Assert-Exact (
    (Get-Sha256 $closurePath) -ceq $expectedClosureRawSha256
) "The C6-RAP-BW19V-C1 closure changed"
$closure = (
    Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_closure_v1" -and
    [string]$closure.campaign_id -ceq
        "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1" -and
    [string]$closure.gate_id -ceq "C6-RAP-BW19V-C1" -and
    [string]$closure.status -ceq
        "closed_negative_portable_observation_availability_routing_failure" -and
    [string]$closure.study_class -ceq
        "outcome_exposed_single_body_technical_commissioning" -and
    [string]$closure.source.commit -ceq $expectedSourceCommit -and
    [bool]$closure.source.clean -and
    [bool]$closure.source.matches_origin_main -and
    [bool]$closure.source.matches_live_remote_main -and
    [bool]$closure.source.full_skip_godot_conformance_passed_before_attempt -and
    [int]$closure.source.physical_attempt_count -eq 1
) "The C6-RAP-BW19V-C1 closure identity or source boundary changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-BW19V-C1 source commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-BW19V-C1 source is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-BW19V-C1 source is not retained on origin/main"
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$liveRemoteMain = ($remoteLine -split "\s+")[0]
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $liveRemoteMain -cmatch "^[0-9a-f]{40}$"
) "The live remote main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $liveRemoteMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-BW19V-C1 source is not retained on live remote main"

$preregistrationPath = Join-Path (
    $repoRoot
) ([string]$closure.preregistration.path)
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-Sha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    ([string]$closure.preregistration.raw_sha256).Replace("sha256:", "") -ceq
        $expectedPreregistrationRawSha256
) "The frozen C6-RAP-BW19V-C1 preregistration changed"

foreach ($artifactName in @(
    "attempt",
    "completion",
    "report",
    "stdout",
    "stderr"
)) {
    Assert-HashedArtifact `
        -Declaration $closure.artifacts[$artifactName] `
        -Name $artifactName
}
Assert-Exact (
    [string]$closure.artifacts.report.sha256 -ceq
        [string]$closure.artifacts.stdout.sha256
) "The retained report and stdout are not byte-identical"

$attempt = (
    Get-Content -Raw -LiteralPath ([string]$closure.artifacts.attempt.path) |
        ConvertFrom-Json -AsHashtable
)
$completion = (
    Get-Content -Raw -LiteralPath ([string]$closure.artifacts.completion.path) |
        ConvertFrom-Json -AsHashtable
)
$report = (
    Get-Content -Raw -LiteralPath ([string]$closure.artifacts.report.path) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_attempt_v1" -and
    [string]$attempt.status -ceq "reserved_before_physical_process_launch" -and
    [string]$attempt.source_commit -ceq $expectedSourceCommit -and
    [string]$attempt.origin_main_commit -ceq $expectedSourceCommit -and
    [string]$attempt.live_remote_main_commit -ceq $expectedSourceCommit -and
    [bool]$attempt.any_physical_process_launch_consumes_campaign_identity -and
    [bool]$attempt.same_identity_rerun_forbidden -and
    -not [bool]$attempt.scientific_result_claim -and
    [string]$completion.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_process_completion_v1" -and
    [string]$completion.status -ceq "physical_process_exited_with_report" -and
    [int]$completion.process_exit_code -eq 1 -and
    [bool]$completion.report_retained -and
    [string]$completion.report_raw_sha256 -ceq
        [string]$closure.artifacts.report.sha256 -and
    [string]$completion.stdout_raw_sha256 -ceq
        [string]$closure.artifacts.stdout.sha256 -and
    [string]$completion.stderr_raw_sha256 -ceq
        [string]$closure.artifacts.stderr.sha256 -and
    [bool]$completion.any_physical_process_launch_consumes_campaign_identity -and
    [bool]$completion.same_identity_rerun_forbidden -and
    -not [bool]$completion.abnormal_attempt_is_not_a_scientific_result
) "The C6-RAP-BW19V-C1 attempt supervision changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_report_v1" -and
    -not [bool]$report.ok -and
    [string]$report.campaign_id -ceq [string]$closure.campaign_id -and
    [string]$report.gate_id -ceq [string]$closure.gate_id -and
    [string]$report.source_commit -ceq $expectedSourceCommit -and
    [string]$report.preregistration_raw_sha256 -ceq
        ("sha256:" + $expectedPreregistrationRawSha256) -and
    [string]$report.candidate_id -ceq "BW19V-B" -and
    [string]$report.candidate_composition_digest -ceq
        "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77" -and
    [string]$report.selected_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$report.selected_policy_digest -ceq
        "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd" -and
    [string]$report.reference_runtime_profile_sha256 -ceq
        "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413" -and
    [string]$report.runtime_profile_sha256 -ceq
        "sha256:312957dedabd3bd0eb7160c5cc69c7788bc7927acaedc42dc609a781f9c6c7db" -and
    -not [bool]$report.rapier_bw19v_single_body_technical_commissioning_passed -and
    -not [bool]$report.rapier_selected_policy_physical_c6
) "The retained C6-RAP-BW19V-C1 report identity changed"

Assert-Exact (
    [bool]$report.preflight.ok -and
    [int]$report.preflight.complete_declared_horizon_steps -eq 3232 -and
    [bool]$report.preflight.complete_declared_horizon_passed -and
    [int]$report.preflight.synthetic_available_plan_count -eq 2160 -and
    [int]$report.preflight.synthetic_partial_support_mapping_count -eq 1080 -and
    [int]$report.preflight.synthetic_fail_zero_count -eq 1072 -and
    [int]$report.preflight.synthetic_influence_output_count -eq 25856 -and
    [int]$report.preflight.synthetic_nonzero_effective_application_count -eq 14630 -and
    [bool]$report.preflight.perfect_synthetic_whole_gate_passed -and
    [bool]$report.preflight.wrong_scale_canary_rejected -and
    [bool]$report.preflight.composition_count_canary_rejected -and
    [bool]$report.preflight.motor_model_canary_rejected -and
    [bool]$report.preflight.missing_nonzero_application_canary_rejected -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.preflight.scene_insertion_count -eq 0 -and
    [int]$report.preflight.physics_state_mutation_count -eq 0
) "The retained C6-RAP-BW19V-C1 preflight changed"

Assert-Exact (
    [int]$report.world_attempt_count -eq 1 -and
    [int]$report.world_build_count -eq 1 -and
    [int]$report.world_reset_count -eq 0 -and
    [int]$report.body_count -eq 9 -and
    [int]$report.joint_count -eq 8 -and
    [int]$report.actuator_count -eq 8 -and
    [int]$report.direct_body_write_count -eq 0 -and
    [int]$report.controller_error_count -eq 0 -and
    [int]$report.safe_no_actuation_count -eq 0 -and
    [int]$report.nonfinite_observation_count -eq 0 -and
    [int]$report.motor_impulse_limit_violation_count -eq 0 -and
    [int]$report.controller_semantic_step_count -eq 2992 -and
    [int]$report.validated_portable_command_count -eq 23936 -and
    [int]$report.native_motor_application_count -eq 3152 -and
    [int]$report.actuator_application_mismatch_count -eq 2598 -and
    [bool]$report.initial_four_contact_stance -and
    -not [bool]$report.terminal_four_contact_recovery -and
    -not [bool]$report.zero_torso_ground_contact -and
    [int]$report.torso_ground_contact_step_count -eq 3025 -and
    [int]$report.observability.first_torso_ground_contact_semantic_step -eq 117 -and
    -not [bool]$report.schedule.evidence_limits_reached -and
    -not [bool]$report.schedule.cooldown_completed -and
    [bool]$report.schedule.terminal_settle_completed
) "The retained C6-RAP-BW19V-C1 physical accounting changed"

Assert-Close `
    -Actual ([double]$report.metrics.final_forward_displacement_m) `
    -Expected (-0.563105046749115) `
    -Tolerance 1.0e-15 `
    -Message "The final forward displacement changed"
Assert-Close `
    -Actual ([double]$report.metrics.final_lateral_displacement_m) `
    -Expected (-0.5745333433151245) `
    -Tolerance 1.0e-15 `
    -Message "The final lateral displacement changed"
Assert-Close `
    -Actual ([double]$report.metrics.final_yaw_drift_rad) `
    -Expected (-0.9361107046446827) `
    -Tolerance 1.0e-15 `
    -Message "The final yaw drift changed"
Assert-Close `
    -Actual ([double]$report.metrics.maximum_tilt_rad) `
    -Expected 3.1415927410125732 `
    -Tolerance 1.0e-15 `
    -Message "The maximum tilt changed"
Assert-Close `
    -Actual ([double]$report.metrics.minimum_torso_height_m) `
    -Expected 0.05829561501741409 `
    -Tolerance 1.0e-15 `
    -Message "The minimum torso height changed"
Assert-Exact (
    $null -eq $report.metrics.evidence_forward_displacement_m
) "The unavailable evidence displacement changed"

$composition = $report.composition
Assert-Exact (
    [int]$composition.attempt_count -eq 2992 -and
    [int]$composition.scheduled_plan_receipt_count -eq 394 -and
    [int]$composition.stability_influence_receipt_count -eq 394 -and
    [int]$composition.composition_error_count -eq 2598 -and
    [int]$composition.composition_error_codes.Count -eq 1 -and
    [int]$composition.composition_error_codes[
        "C6_RAP_BW19V_PLAN_FAILED:CONTACT_INVALID:stability_qualified_support_set_empty"
    ] -eq 2598 -and
    [int]$composition.available_plan_count -eq 13 -and
    [int]$composition.observation_unavailable_plan_count -eq 349 -and
    [int]$composition.upstream_infeasible_plan_count -eq 32 -and
    [int]$composition.fail_zero_receipt_count -eq 381 -and
    [int]$composition.mapping_receipt_count -eq 13 -and
    [int]$composition.influence_output_count -eq 3152 -and
    [int]$composition.nonzero_raw_request_count -eq 104 -and
    [int]$composition.nonzero_scaled_request_count -eq 104 -and
    [int]$composition.nonzero_applied_contribution_count -eq 104 -and
    [int]$composition.nonzero_effective_host_application_count -eq 85 -and
    [int]$composition.host_speed_saturation_count -eq 19 -and
    [int]$composition.global_scale_mismatch_count -eq 0 -and
    [int]$composition.host_response_conversion_failure_count -eq 0 -and
    [int]$composition.inactive_contact_zero_mismatch_count -eq 0 -and
    [int]$composition.motor_model_readback_mismatch_count -eq 0 -and
    [string]$composition.first_composition_receipt_sha256 -ceq
        "sha256:ead451e2dffc35bd20d859a6e868a59bf00672603ca57980c3ae5e1ad5d4c863" -and
    [string]$composition.last_composition_receipt_sha256 -ceq
        "sha256:fcfd7a6b0bd74d217f9d1a9d98a68fc1ca7ce6d127cad880b61f7f4aba7e02d3"
) "The retained C6-RAP-BW19V-C1 composition accounting changed"
Assert-Close `
    -Actual ([double]$composition.response_reconstruction_maximum_error_nm) `
    -Expected 8.673617379884035e-19 `
    -Tolerance 1.0e-30 `
    -Message "The source-derived response reconstruction changed"

$expectedFailures = @(
    $closure.physical_result.gate_failures | ForEach-Object { [string]$_ }
)
$actualFailures = @($report.gate_failures | ForEach-Object { [string]$_ })
Assert-Exact (
    $expectedFailures.Count -eq 22 -and
    $actualFailures.Count -eq 22 -and
    -not (Compare-Object $expectedFailures $actualFailures -SyncWindow 0)
) "The retained C6-RAP-BW19V-C1 gate failures changed"

foreach ($claim in @(
    "single_body_bw19v_b_rapier_technical_commissioning",
    "rapier_selected_policy_technical_integration",
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
        -not [bool]$closure.claim_boundary[$claim]
    ) "The C6-RAP-BW19V-C1 closure may not authorize $claim"
}
Assert-Exact (
    [bool]$closure.contract_diagnosis.integration_failure_established -and
    -not [bool]$closure.contract_diagnosis.response_conversion_failure_established -and
    -not [bool]$closure.contract_diagnosis.motor_model_failure_established -and
    -not [bool]$closure.contract_diagnosis.policy_performance_interpretation_allowed -and
    -not [bool]$closure.contract_diagnosis.causal_claim_that_availability_routing_caused_first_torso_contact -and
    [bool]$closure.disposition.complete_negative_report_retained -and
    -not [bool]$closure.disposition.technical_commissioning_accepted -and
    -not [bool]$closure.disposition.rapier_selected_policy_physical_c6 -and
    -not [bool]$closure.disposition.same_identity_rerun_allowed -and
    -not [bool]$closure.disposition.threshold_change_allowed -and
    -not [bool]$closure.disposition.report_rewrite_allowed -and
    [bool]$closure.disposition.scientifically_distinct_successor_allowed -and
    [bool]$closure.disposition.successor_must_preserve_morphology_policy_host_material_response_and_walking_thresholds -and
    [bool]$closure.disposition.successor_may_correct_only_observation_availability_routing_and_receipts -and
    [bool]$closure.disposition.successor_must_route_zero_qualified_support_to_observation_unavailable -and
    [bool]$closure.disposition.successor_must_apply_valid_base_command_with_exact_zero_stability_contribution -and
    [bool]$closure.disposition.successor_zero_world_gate_must_include_zero_qualified_support
) "The C6-RAP-BW19V-C1 diagnosis or successor boundary changed"

$compositionSource = Read-SourceCommitText (
    "sdk\adapters\rapier\src\bw19v_composition.rs"
)
$campaignSource = Read-SourceCommitText (
    "sdk\adapters\rapier\src\bw19v_commissioning.rs"
)
$portableSource = Read-SourceCommitText "sdk\core\src\stability.rs"
$godotSource = Read-SourceCommitText (
    "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
)
foreach ($binding in @(
    "observation_available: true",
    "observation_unavailable_reason: None"
)) {
    Assert-TextContains -Text $compositionSource -Needle $binding -Message (
        "The frozen Rapier availability defect is not retained: $binding"
    )
}
foreach ($binding in @(
    '10..=19 => contact_id != "front_left_foot"',
    'contact_id == "front_right_foot" || contact_id == "rear_left_foot"',
    "robot.hold_zero_and_step()?;"
)) {
    Assert-TextContains -Text $campaignSource -Needle $binding -Message (
        "The frozen C1 preflight/error path changed: $binding"
    )
}
foreach ($binding in @(
    "NO_QUALIFIED_SUPPORT_CONTACT",
    "observation_available = false",
    "StabilityInfluenceAvailability::ObservationUnavailable"
)) {
    Assert-TextContains -Text $portableSource -Needle $binding -Message (
        "The portable v3 unavailable contract changed: $binding"
    )
}
foreach ($binding in @(
    '"observation_available": false',
    '"unavailable_reason": "NO_QUALIFIED_SUPPORT_CONTACT"'
)) {
    Assert-TextContains -Text $godotSource -Needle $binding -Message (
        "The established Godot/Jolt availability route changed: $binding"
    )
}

$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$runnerOutput = (& pwsh -NoLogo -NoProfile -File $runnerPath 2>&1) |
    Out-String
$runnerExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorPreference
Assert-Exact (
    $runnerExitCode -ne 0 -and
    $runnerOutput.Contains(
        "C6-RAP-BW19V-C1 is already closed and may not open another world",
        [System.StringComparison]::Ordinal
    )
) "The C6-RAP-BW19V-C1 runner did not reject a same-identity rerun"

# This audit is dot-invoked by run_conformance.ps1. The deliberately nonzero
# child-runner canary must not leak through the shared native-process status
# after its rejection has been asserted.
$global:LASTEXITCODE = 0

Write-Output (
    "C6_RAP_BW19V_C1_CLOSURE_PASS worlds=1 receipts=394 " +
    "composition_errors=2598 nonzero_effective=85 " +
    "model_mismatches=0 impulse_violations=0 " +
    "technical_commissioning=False same_identity_rerun=False"
)
