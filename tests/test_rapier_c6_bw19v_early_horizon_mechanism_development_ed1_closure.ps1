$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_early_horizon_mechanism_development_ed1_closure.json"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preregistration.json"
$c2ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c2_closure.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_early_horizon_mechanism_development_ed1.ps1"
$expectedClosureRawSha256 = (
    "sha256:" +
    "8155effd3e0141839964a18b59733fc256e3b5c130f936824b6a34c0cd21f3d4"
)
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "8c149f47a87bbd72402a7aa98fec1e75ff05abb36df2802f9b8a333f469b3197"
)
$expectedC2ClosureRawSha256 = (
    "sha256:" +
    "3047c2d9712a7d9b70c7423dab7df19bc8de96b1c39663b2bf0fb6e278fe5590"
)
$campaignId = "C6-RAPIER-BW19V-EARLY-HORIZON-MECHANISM-DEVELOPMENT-ED1"
$gateId = "C6-RAP-BW19V-ED1"
$expectedActuatorIds = @(
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-CompactJson {
    param([AllowNull()][object]$Value)
    return ConvertTo-Json -InputObject $Value -Depth 100 -Compress
}

function Test-FiniteNumber {
    param([AllowNull()][object]$Value)
    try {
        return [double]::IsFinite([double]$Value)
    } catch {
        return $false
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureRawSha256
) "The ED1 closure manifest is missing or byte-changed"
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "The ED1 preregistration changed after physical execution"
Assert-Exact (
    (Test-Path -LiteralPath $c2ClosurePath -PathType Leaf) -and
    (Get-RawSha256 $c2ClosurePath) -ceq $expectedC2ClosureRawSha256
) "The C2 predecessor closure changed"

$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
$c2Closure = Get-Content -Raw -LiteralPath $c2ClosurePath | ConvertFrom-Json
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_complete_both_arms_failed_residual_not_necessary_exact_pair" -and
    [string]$closure.study_class -ceq
        "outcome_exposed_paired_single_body_mechanism_development_screen" -and
    [string]$closure.source.commit -ceq
        "54efdeece59054997311ce70afa7ce0f44ae4d62" -and
    [bool]$closure.source.clean -and
    [bool]$closure.source.matches_origin_main -and
    [bool]$closure.source.matches_live_remote_main -and
    [bool]$closure.source.full_skip_godot_conformance_passed_before_freeze_commit -and
    [bool]$closure.source.full_skip_godot_conformance_passed_from_clean_pushed_freeze_commit -and
    [int]$closure.source.physical_attempt_count -eq 1
) "ED1 closure identity, source, or status changed"
Assert-Exact (
    [string]$closure.preregistration.raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$closure.predecessor.closure_raw_sha256 -ceq
        $expectedC2ClosureRawSha256 -and
    [string]$closure.predecessor.status -ceq [string]$c2Closure.status -and
    -not [bool]$closure.predecessor.same_identity_rerun -and
    -not [bool]$closure.predecessor.result_reinterpreted_or_rethresholded
) "ED1 predecessor or preregistration chain changed"

$sourceCommit = [string]$closure.source.commit
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "The frozen ED1 source commit is missing"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "Current HEAD is not descended from ED1 source"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit origin/main
Assert-Exact ($LASTEXITCODE -eq 0) "origin/main lost the ED1 source commit"

foreach ($artifactProperty in $closure.artifacts.PSObject.Properties) {
    $artifact = $artifactProperty.Value
    $path = [System.IO.Path]::GetFullPath([string]$artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.bytes -and
        (Get-RawSha256 $path) -ceq [string]$artifact.sha256
    ) "ED1 retained artifact changed: $($artifactProperty.Name)"
}
Assert-Exact (
    [string]$closure.artifacts.report.sha256 -ceq
        [string]$closure.artifacts.stdout.sha256 -and
    [long]$closure.artifacts.report.bytes -eq
        [long]$closure.artifacts.stdout.bytes -and
    [long]$closure.artifacts.stderr.bytes -eq 0 -and
    [string]$closure.artifacts.stderr.sha256 -ceq
        "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
) "ED1 stdout/stderr retention changed"

$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.artifacts.attempt.path
) | ConvertFrom-Json
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.artifacts.completion.path
) | ConvertFrom-Json
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.artifacts.report.path
) | ConvertFrom-Json
Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.status -ceq
        "physical_process_launch_reserved_identity_consumed" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.live_remote_main_commit -ceq $sourceCommit -and
    [string]$attempt.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [int]$attempt.declared_world_count -eq 2 -and
    (Get-CompactJson @($attempt.fixed_arm_order)) -ceq
        (Get-CompactJson @("ED1-A", "ED1-B")) -and
    [bool]$attempt.process_launch_consumes_identity -and
    -not [bool]$attempt.same_identity_rerun_allowed
) "ED1 attempt supervision receipt changed"
Assert-Exact (
    [string]$completion.schema_version -ceq
        "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_process_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.status -ceq "physical_process_exited_with_report" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [int]$completion.process_exit_code -eq 0 -and
    [bool]$completion.physical_process_launched -and
    [bool]$completion.report_retained -and
    [string]$completion.report_raw_sha256 -ceq
        [string]$closure.artifacts.report.sha256 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.abnormal_attempt_is_not_a_scientific_result -and
    [bool]$closure.attempt_supervision.report_and_stdout_bytes_identical -and
    [bool]$closure.attempt_supervision.stderr_empty -and
    -not [bool]$closure.attempt_supervision.abnormal_attempt
) "ED1 process completion changed or was reclassified"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_report_v1" -and
    [bool]$report.ok -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$report.c2_closure_raw_sha256 -ceq
        $expectedC2ClosureRawSha256 -and
    [string]$report.engine -ceq "rapier3d" -and
    [string]$report.engine_version -ceq "0.34.0" -and
    [string]$report.adapter_id -ceq "sporespore_rapier3d_adapter" -and
    [string]$report.candidate_id -ceq "BW19V-B" -and
    [string]$report.candidate_composition_digest -ceq
        "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77" -and
    [string]$report.selected_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$report.selected_policy_digest -ceq
        "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd" -and
    [string]$report.morphology_id -ceq "qsdk_r05_generated_s169" -and
    [string]$report.descriptor_sha256 -ceq
        "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0" -and
    (Get-CompactJson @($report.ordered_actuator_ids)) -ceq
        (Get-CompactJson $expectedActuatorIds)
) "ED1 physical report identity changed"
Assert-Exact (
    [string]$report.host_configuration.motor_model -ceq "ForceBased" -and
    [double]$report.host_configuration.motor_stiffness_nm_per_rad -eq 40.0 -and
    [double]$report.host_configuration.motor_damping_nm_s_per_rad -eq 10.0 -and
    [int]$report.host_configuration.solver_iterations -eq 16 -and
    [int]$report.host_configuration.internal_pgs_iterations -eq 3 -and
    [int]$report.host_configuration.internal_stabilization_iterations -eq 5 -and
    [double]$report.host_configuration.outer_timestep_s -eq
        0.008333333767950535 -and
    [double]$report.host_configuration.authored_friction -eq
        0.949999988079071 -and
    [double]$report.host_configuration.characterized_controller_friction -eq 0.94
) "ED1 host configuration changed"

$preflight = $report.preflight
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_two_arm_report_passed_complete_integrity_gate -and
    [bool]$preflight.synthetic_outcome_variants_all_integrity_valid -and
    [int]$preflight.synthetic_arm_count -eq 2 -and
    [int]$preflight.synthetic_trace_step_count -eq 944 -and
    [int]$preflight.synthetic_command_count_per_layer -eq 7552 -and
    [bool]$preflight.missing_trace_step_canary_rejected -and
    [bool]$preflight.reordered_semantic_step_canary_rejected -and
    [bool]$preflight.arm_a_nonzero_applied_residual_canary_rejected -and
    [bool]$preflight.arm_b_missing_nonzero_shadow_residual_canary_rejected -and
    [bool]$preflight.final_command_count_canary_rejected -and
    [bool]$preflight.nested_state_schema_canary_rejected -and
    [bool]$preflight.claim_inflation_canary_rejected -and
    [bool]$preflight.serialization_round_trip_passed -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.physical_acceptance_authority
) "The physical report lost the complete ED1 zero-world gate"
Assert-Exact (
    [int]$report.world_attempt_count -eq 2 -and
    [int]$report.world_build_count -eq 2 -and
    [int]$report.world_reset_count -eq 0 -and
    [int]$report.trace_step_count_total -eq 944 -and
    [int]$report.base_command_count_total -eq 7552 -and
    [int]$report.shadow_residual_command_count_total -eq 7552 -and
    [int]$report.final_host_command_count_total -eq 7552 -and
    [int]$report.post_step_host_observation_count_total -eq 7552 -and
    @($report.diagnostic_gate_failures).Count -eq 0 -and
    [string]$report.pair_interpretation.classification -ceq "both_arms_failure" -and
    [bool]$report.pair_interpretation.exact_pair_causal_scope_only -and
    -not [bool]$report.pair_interpretation.population_inference -and
    -not [bool]$report.pair_interpretation.policy_superiority -and
    -not [bool]$report.pair_interpretation.walking_acceptance -and
    -not [bool]$report.pair_interpretation.physical_acceptance_authority
) "ED1 aggregate execution or pair classification changed"

$reportTrueClaims = @(
    $report.claim_boundary.PSObject.Properties |
        Where-Object { [bool]$_.Value } |
        ForEach-Object { $_.Name }
)
Assert-Exact (
    $reportTrueClaims.Count -eq 1 -and
    $reportTrueClaims[0] -ceq "complete_mechanism_development_trace_only"
) "ED1 physical report inflated its authority"

$thresholds = $preregistration.declared_early_failure_thresholds
$expectedArmValues = @{
    "ED1-A" = @{
        first_failure_step = 94
        first_torso_step = 114
        last_torso_step = 158
        torso_count = 45
        tilt_count = 378
        maximum_tilt = 1.2298119068145752
        maximum_tilt_step = 136
        minimum_height = 0.2809027433395386
        minimum_height_step = 113
        maximum_anchor = 0.00012370019976515323
        maximum_axis = 0.002868003910407424
        terminal_tilt = 0.6999521255493164
        terminal_height = 0.29627400636672974
        shadow_nonzero = 721
        applied_nonzero = 0
        velocity_saturated = 2866
        velocity_saturated_through_failure = 417
        global_limit = 2726
        global_limit_through_failure = 404
    }
    "ED1-B" = @{
        first_failure_step = 94
        first_torso_step = 117
        last_torso_step = 157
        torso_count = 41
        tilt_count = 366
        maximum_tilt = 1.1976855993270874
        maximum_tilt_step = 136
        minimum_height = 0.2812921702861786
        minimum_height_step = 116
        maximum_anchor = 0.0002086837193928659
        maximum_axis = 0.0038447328843176365
        terminal_tilt = 0.6985858678817749
        terminal_height = 0.29624319076538086
        shadow_nonzero = 724
        applied_nonzero = 724
        velocity_saturated = 2883
        velocity_saturated_through_failure = 427
        global_limit = 2741
        global_limit_through_failure = 414
    }
}

Assert-Exact (
    @($report.arms).Count -eq 2 -and
    [string]$report.arms[0].arm_id -ceq "ED1-A" -and
    [string]$report.arms[1].arm_id -ceq "ED1-B"
) "ED1 arm order changed"
foreach ($armIndex in 0..1) {
    $arm = $report.arms[$armIndex]
    $armId = [string]$arm.arm_id
    $expected = $expectedArmValues[$armId]
    $summary = if ($armId -ceq "ED1-A") {
        $closure.physical_result.arm_a
    } else {
        $closure.physical_result.arm_b
    }
    Assert-Exact (
        [int]$arm.arm_order_index -eq $armIndex -and
        [bool]$arm.completed_declared_horizon -and
        $null -eq $arm.fatal_error -and
        [int]$arm.world_attempt_count -eq 1 -and
        [int]$arm.world_build_count -eq 1 -and
        [int]$arm.world_reset_count -eq 0 -and
        [int]$arm.body_count -eq 9 -and
        [int]$arm.joint_count -eq 8 -and
        [int]$arm.actuator_count -eq 8 -and
        [int]$arm.settle_steps -eq 240 -and
        [int]$arm.controller_semantic_step_count -eq 472 -and
        [int]$arm.trace_step_count -eq 472 -and
        [bool]$arm.post_settle_initial_four_contact_stance -and
        @($arm.post_settle_declared_failure_events).Count -eq 0 -and
        [int]$arm.controller_error_count -eq 0 -and
        [int]$arm.safe_no_actuation_count -eq 0 -and
        [int]$arm.nonfinite_observation_count -eq 0 -and
        [int]$arm.composition_error_count -eq 0 -and
        [int]$arm.actuator_application_mismatch_count -eq 0 -and
        [int]$arm.motor_impulse_limit_violation_count -eq 0 -and
        [int]$arm.global_scale_mismatch_count -eq 0 -and
        [int]$arm.motor_model_readback_mismatch_count -eq 0 -and
        [int]$arm.native_motor_application_count -eq 3776 -and
        [int]$arm.base_command_count -eq 3776 -and
        [int]$arm.shadow_residual_command_count -eq 3776 -and
        [int]$arm.final_host_command_count -eq 3776 -and
        [int]$arm.post_step_host_observation_count -eq 3776 -and
        [double]$arm.response_reconstruction_maximum_error_nm -eq
            4.440892098500626e-16 -and
        -not [bool]$arm.physical_acceptance_authority
    ) "ED1 arm execution integrity changed: $armId"
    Assert-Exact (
        [int]$arm.shadow_nonzero_effective_host_residual_count -eq
            [int]$expected.shadow_nonzero -and
        [int]$arm.applied_residual_nonzero_count -eq
            [int]$expected.applied_nonzero -and
        [int]$summary.shadow_nonzero_effective_host_residual_count -eq
            [int]$expected.shadow_nonzero -and
        [int]$summary.applied_residual_nonzero_count -eq
            [int]$expected.applied_nonzero
    ) "ED1 intervention counts changed: $armId"
    if ($armId -ceq "ED1-A") {
        Assert-Exact (
            -not [bool]$arm.bw19v_stability_contribution_applied_to_host -and
            [string]$arm.residual_application_mode -ceq
                "bw15f_b_base_only_shadow_bw19v_b" -and
            [int]$arm.final_command_mismatch_from_base_count -eq 0
        ) "ED1-A no-residual intervention changed"
    } else {
        Assert-Exact (
            [bool]$arm.bw19v_stability_contribution_applied_to_host -and
            [string]$arm.residual_application_mode -ceq
                "exact_bw19v_b_full_composition" -and
            [int]$arm.shadow_and_applied_residual_mismatch_count -eq 0
        ) "ED1-B full-composition intervention changed"
    }

    $trace = @($arm.ordered_trace)
    Assert-Exact ($trace.Count -eq 472) "ED1 trace count changed: $armId"
    $firstFailureStep = $null
    $firstFailureCodes = @()
    $firstTorsoStep = $null
    $lastTorsoStep = $null
    $torsoCount = 0
    $tiltCount = 0
    $heightCount = 0
    $anchorCount = 0
    $axisCount = 0
    $maximumTilt = [double]::NegativeInfinity
    $maximumTiltStep = -1
    $minimumHeight = [double]::PositiveInfinity
    $minimumHeightStep = -1
    $maximumAnchor = [double]::NegativeInfinity
    $maximumAxis = [double]::NegativeInfinity
    $appliedNonzero = 0
    $maximumAppliedResidual = 0.0
    $velocitySaturated = 0
    $velocitySaturatedThroughFailure = 0
    $globalLimitCount = 0
    $globalLimitThroughFailure = 0
    $impulseAtOrAbove95Percent = 0

    foreach ($semanticStep in 0..471) {
        $entry = $trace[$semanticStep]
        Assert-Exact (
            [string]$entry.arm_id -ceq $armId -and
            [int]$entry.semantic_step -eq $semanticStep -and
            [string]$entry.phase_progression_mode -ceq "clocked" -and
            [bool]$entry.command_provenance_recorded_before_application -and
            @($entry.ordered_limb_controller_memory_before).Count -eq 4 -and
            @($entry.ordered_base_commands).Count -eq 8 -and
            @($entry.shadow_composition.ordered_shadow_residual_commands).Count -eq 8 -and
            @($entry.ordered_final_host_commands).Count -eq 8 -and
            @($entry.ordered_post_step_host_observations).Count -eq 8 -and
            [string]$entry.shadow_composition.composition_receipt_sha256 -cmatch
                "^sha256:[0-9a-f]{64}$" -and
            (Test-FiniteNumber $entry.shadow_composition.response_reconstruction_maximum_error_nm) -and
            [double]$entry.shadow_composition.response_reconstruction_maximum_error_nm -le 1e-12
        ) "ED1 trace structure changed: $armId step $semanticStep"
        foreach ($layer in @(
            @($entry.ordered_base_commands),
            @($entry.shadow_composition.ordered_shadow_residual_commands),
            @($entry.ordered_final_host_commands),
            @($entry.ordered_post_step_host_observations)
        )) {
            Assert-Exact (
                (Get-CompactJson @($layer.actuator_id)) -ceq
                    (Get-CompactJson $expectedActuatorIds)
            ) "ED1 actuator order changed: $armId step $semanticStep"
        }

        $state = $entry.post_state
        Assert-Exact (
            (Test-FiniteNumber $state.torso_tilt_rad) -and
            (Test-FiniteNumber $state.torso_height_m) -and
            (Test-FiniteNumber $state.maximum_anchor_error_m) -and
            (Test-FiniteNumber $state.maximum_hinge_axis_error_rad)
        ) "ED1 post-state became nonfinite: $armId step $semanticStep"
        $derivedEvents = @()
        if ([bool]$state.torso_ground_contact) {
            $derivedEvents += "torso_ground_contact"
            $torsoCount += 1
            if ($null -eq $firstTorsoStep) {
                $firstTorsoStep = $semanticStep
            }
            $lastTorsoStep = $semanticStep
        }
        if ([double]$state.torso_tilt_rad -gt [double]$thresholds.maximum_tilt_rad) {
            $derivedEvents += "maximum_tilt_threshold_crossing"
            $tiltCount += 1
        }
        if ([double]$state.torso_height_m -lt [double]$thresholds.minimum_torso_height_m) {
            $derivedEvents += "minimum_torso_height_threshold_crossing"
            $heightCount += 1
        }
        if ([double]$state.maximum_anchor_error_m -gt [double]$thresholds.maximum_anchor_error_m) {
            $derivedEvents += "maximum_anchor_error_threshold_crossing"
            $anchorCount += 1
        }
        if ([double]$state.maximum_hinge_axis_error_rad -gt [double]$thresholds.maximum_hinge_axis_error_rad) {
            $derivedEvents += "maximum_hinge_axis_error_threshold_crossing"
            $axisCount += 1
        }
        Assert-Exact (
            (Get-CompactJson @($entry.declared_failure_events)) -ceq
                (Get-CompactJson $derivedEvents)
        ) "ED1 event reconstruction changed: $armId step $semanticStep"
        if ($null -eq $firstFailureStep -and $derivedEvents.Count -gt 0) {
            $firstFailureStep = $semanticStep
            $firstFailureCodes = $derivedEvents
        }

        if ([double]$state.torso_tilt_rad -gt $maximumTilt) {
            $maximumTilt = [double]$state.torso_tilt_rad
            $maximumTiltStep = $semanticStep
        }
        if ([double]$state.torso_height_m -lt $minimumHeight) {
            $minimumHeight = [double]$state.torso_height_m
            $minimumHeightStep = $semanticStep
        }
        $maximumAnchor = [math]::Max(
            $maximumAnchor,
            [double]$state.maximum_anchor_error_m
        )
        $maximumAxis = [math]::Max(
            $maximumAxis,
            [double]$state.maximum_hinge_axis_error_rad
        )

        $baseCommands = @($entry.ordered_base_commands)
        $shadowCommands = @(
            $entry.shadow_composition.ordered_shadow_residual_commands
        )
        $finalCommands = @($entry.ordered_final_host_commands)
        foreach ($commandIndex in 0..7) {
            $base = $baseCommands[$commandIndex]
            $shadow = $shadowCommands[$commandIndex]
            $final = $finalCommands[$commandIndex]
            $applied = [double]$final.applied_residual_velocity_rad_s
            if ([math]::Abs($applied) -gt 0.0) {
                $appliedNonzero += 1
            }
            $maximumAppliedResidual = [math]::Max(
                $maximumAppliedResidual,
                [math]::Abs($applied)
            )
            if ([bool]$base.velocity_saturated) {
                $velocitySaturated += 1
                if ($semanticStep -le 94) {
                    $velocitySaturatedThroughFailure += 1
                }
            }
            if (
                [math]::Abs(
                    [math]::Abs([double]$base.target_velocity_rad_s) - 3.5
                ) -le 1e-12
            ) {
                $globalLimitCount += 1
                if ($semanticStep -le 94) {
                    $globalLimitThroughFailure += 1
                }
            }
            if ($armId -ceq "ED1-A") {
                Assert-Exact (
                    $applied -eq 0.0 -and
                    [double]$final.final_target_velocity_rad_s -eq
                        [double]$base.target_velocity_rad_s
                ) "ED1-A applied the residual: step $semanticStep"
            } else {
                Assert-Exact (
                    $applied -eq
                        [double]$shadow.effective_host_target_velocity_delta_rad_s -and
                    [double]$final.final_target_velocity_rad_s -eq
                        [double]$shadow.combined_target_velocity_rad_s
                ) "ED1-B lost exact shadow/application equality: step $semanticStep"
            }
            $observation = $entry.ordered_post_step_host_observations[$commandIndex]
            $impulseRatio = [math]::Abs(
                [double]$observation.motor_impulse_nms
            ) / [double]$observation.maximum_impulse_nms
            if ($impulseRatio -ge 0.95) {
                $impulseAtOrAbove95Percent += 1
            }
        }
    }

    Assert-Exact (
        [int]$arm.first_failure_event.semantic_step -eq $firstFailureStep -and
        [string]$arm.first_failure_event.event_code -ceq $firstFailureCodes[0] -and
        (Get-CompactJson @($arm.first_failure_event.all_event_codes)) -ceq
            (Get-CompactJson $firstFailureCodes) -and
        $firstFailureStep -eq [int]$expected.first_failure_step -and
        $firstTorsoStep -eq [int]$expected.first_torso_step -and
        $lastTorsoStep -eq [int]$expected.last_torso_step -and
        $torsoCount -eq [int]$expected.torso_count -and
        $tiltCount -eq [int]$expected.tilt_count -and
        $heightCount -eq 0 -and
        $anchorCount -eq 0 -and
        $axisCount -eq 0 -and
        $maximumTilt -eq [double]$expected.maximum_tilt -and
        $maximumTiltStep -eq [int]$expected.maximum_tilt_step -and
        $minimumHeight -eq [double]$expected.minimum_height -and
        $minimumHeightStep -eq [int]$expected.minimum_height_step -and
        $maximumAnchor -eq [double]$expected.maximum_anchor -and
        $maximumAxis -eq [double]$expected.maximum_axis -and
        [double]$trace[471].post_state.torso_tilt_rad -eq
            [double]$expected.terminal_tilt -and
        [double]$trace[471].post_state.torso_height_m -eq
            [double]$expected.terminal_height -and
        -not [bool]$trace[471].post_state.torso_ground_contact -and
        $appliedNonzero -eq [int]$expected.applied_nonzero -and
        $velocitySaturated -eq [int]$expected.velocity_saturated -and
        $velocitySaturatedThroughFailure -eq
            [int]$expected.velocity_saturated_through_failure -and
        $globalLimitCount -eq [int]$expected.global_limit -and
        $globalLimitThroughFailure -eq
            [int]$expected.global_limit_through_failure -and
        $impulseAtOrAbove95Percent -eq 0
    ) "ED1 independently reconstructed arm result changed: $armId"
    if ($armId -ceq "ED1-A") {
        Assert-Exact ($maximumAppliedResidual -eq 0.0) (
            "ED1-A gained a nonzero applied residual"
        )
    } else {
        Assert-Exact (
            $maximumAppliedResidual -eq 0.07500000000000018
        ) "ED1-B maximum applied residual changed"
    }
}

Assert-Exact (
    [bool]$closure.physical_result.diagnostic_integrity_complete -and
    [string]$closure.physical_result.pair_classification -ceq
        "both_arms_failure" -and
    [int]$closure.physical_result.world_build_count -eq 2 -and
    [int]$closure.physical_result.trace_step_count_total -eq 944 -and
    [int]$closure.physical_result.diagnostic_gate_failure_count -eq 0 -and
    [bool]$closure.causal_interpretation.base_only_host_loop_sufficient_for_declared_early_failure -and
    -not [bool]$closure.causal_interpretation.bw19v_residual_necessary_for_declared_early_failure -and
    -not [bool]$closure.causal_interpretation.bw19v_residual_sufficient_to_prevent_declared_early_failure -and
    [bool]$closure.causal_interpretation.c2_full_composition_first_torso_contact_reproduced -and
    [bool]$closure.causal_interpretation.exact_pair_causal_scope_only -and
    -not [bool]$closure.causal_interpretation.population_inference -and
    -not [bool]$closure.causal_interpretation.base_controller_intrinsic_cause_identified -and
    -not [bool]$closure.causal_interpretation.rapier_host_mapping_intrinsic_cause_identified -and
    -not [bool]$closure.causal_interpretation.base_host_interaction_cause_identified -and
    [bool]$closure.causal_interpretation.descriptive_residual_effect_is_not_confirmatory
) "ED1 causal result was inflated, weakened, or reclassified"
Assert-Exact (
    [int]$closure.causal_interpretation.descriptive_residual_effect.torso_contact_delay_steps -eq 3 -and
    [double]$closure.causal_interpretation.descriptive_residual_effect.maximum_tilt_reduction_rad -eq
        0.03212630748748779 -and
    [int]$closure.causal_interpretation.descriptive_residual_effect.torso_contact_step_count_reduction -eq 4 -and
    [int]$closure.causal_interpretation.descriptive_residual_effect.tilt_threshold_crossing_step_count_reduction -eq 12
) "ED1 descriptive paired differences changed"
Assert-Exact (
    [string]$closure.source_grounded_semantic_question.status -ceq
        "open_must_resolve_before_next_rapier_world" -and
    [bool]$closure.source_grounded_semantic_question.portable_controller_synthesizes_target_velocity_from_position_error_and_measured_velocity -and
    [bool]$closure.source_grounded_semantic_question.godot_jolt_selected_application_reports_motor_target_velocity_only -and
    [bool]$closure.source_grounded_semantic_question.rapier_selected_application_uses_target_position_and_target_velocity_with_force_based_40_10_pd -and
    -not [bool]$closure.source_grounded_semantic_question.cross_engine_actuation_semantic_equivalence_established -and
    -not [bool]$closure.source_grounded_semantic_question.this_source_difference_is_causally_confirmed_by_ed1
) "ED1 source-grounded semantic question was prematurely resolved"
Assert-Exact (
    [bool]$closure.disposition.complete_diagnostic_report_retained -and
    -not [bool]$closure.disposition.remove_or_disable_bw19v_residual_as_presumed_fix -and
    -not [bool]$closure.disposition.same_identity_rerun_allowed -and
    -not [bool]$closure.disposition.threshold_change_allowed -and
    -not [bool]$closure.disposition.report_rewrite_allowed -and
    -not [bool]$closure.disposition.posthoc_reclassification_allowed -and
    [bool]$closure.disposition.scientifically_distinct_successor_allowed -and
    [bool]$closure.disposition.successor_must_use_new_campaign_source_and_preregistration_identity -and
    -not [bool]$closure.disposition.another_rapier_acceptance_campaign_allowed_now -and
    [bool]$closure.disposition.zero_world_actuation_semantics_audit_required_first -and
    [bool]$closure.disposition.new_host_characterization_required_if_application_semantics_change -and
    [bool]$closure.disposition.new_early_horizon_development_screen_required_before_acceptance -and
    [bool]$closure.disposition.fresh_independent_validation_required_after_development -and
    [bool]$closure.disposition.independent_bw19v_b_cold_friction_track_remains_open
) "ED1 disposition changed"

$closureTrueClaims = @(
    $closure.claim_boundary.PSObject.Properties |
        Where-Object { [bool]$_.Value } |
        ForEach-Object { $_.Name }
)
Assert-Exact (
    (Get-CompactJson $closureTrueClaims) -ceq
        (Get-CompactJson @(
            "complete_exact_pair_mechanism_development_trace",
            "residual_not_necessary_for_exact_pair_early_failure"
        ))
) "ED1 closure claim boundary changed"

$frozenRuntimeSource = (& git -C $repoRoot show (
    "$sourceCommit`:sdk/core/src/runtime.rs"
)) -join "`n"
$frozenGodotSource = (& git -C $repoRoot show (
    "$sourceCommit`:scripts/lab/gait/sdk_godot_jolt_adapter.gd"
)) -join "`n"
$frozenRapierSource = (& git -C $repoRoot show (
    "$sourceCommit`:sdk/adapters/rapier/src/locomotion.rs"
)) -join "`n"
$frozenPreregistration = (& git -C $repoRoot show (
    "$sourceCommit`:sdk/rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preregistration.json"
)) -join "`n"
Assert-Exact ($LASTEXITCODE -eq 0) "Unable to read frozen ED1 sources"
foreach ($binding in @(
    "MOTOR_POSITION_GAIN_PER_S",
    "requested_target_position_rad - measured_position",
    "MOTOR_RATE_DAMPING * measured_velocity"
)) {
    Assert-Exact ($frozenRuntimeSource.Contains($binding)) (
        "Frozen portable velocity synthesis lost binding: $binding"
    )
}
foreach ($binding in @(
    '"motor_target_velocity_only": true',
    "HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY"
)) {
    Assert-Exact ($frozenGodotSource.Contains($binding)) (
        "Frozen Godot application source lost binding: $binding"
    )
}
foreach ($binding in @(
    "command.base_target_position_rad as f32",
    "command.combined_target_velocity_rad_s as f32",
    "MOTOR_STIFFNESS",
    "MOTOR_DAMPING",
    ".set_motor_model(MotorModel::ForceBased)"
)) {
    Assert-Exact ($frozenRapierSource.Contains($binding)) (
        "Frozen Rapier application source lost binding: $binding"
    )
}
$currentPreregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath
).TrimEnd("`r", "`n")
Assert-Exact (
    $frozenPreregistration.TrimEnd("`r", "`n") -ceq $currentPreregistration
) "The preregistration at the frozen ED1 source commit changed"

$attemptMatches = @()
$allEvidenceRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent ([string]$closure.evidence_root))
)
foreach ($candidate in @(
    Get-ChildItem `
        -LiteralPath $allEvidenceRoot `
        -Recurse `
        -File `
        -Filter "attempt.json" `
        -ErrorAction Stop
)) {
    try {
        $candidateReceipt = Get-Content -Raw -LiteralPath $candidate.FullName |
            ConvertFrom-Json
        if ([string]$candidateReceipt.campaign_id -ceq $campaignId) {
            $attemptMatches += $candidate.FullName
        }
    } catch {
        continue
    }
}
Assert-Exact (
    $attemptMatches.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($attemptMatches[0]) -ceq
        [System.IO.Path]::GetFullPath([string]$closure.artifacts.attempt.path)
) "ED1 has more than its one permitted physical attempt"

$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$runnerOutput = (& pwsh -NoLogo -NoProfile -File $runnerPath 2>&1) |
    Out-String
$runnerExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorPreference
Assert-Exact (
    $runnerExitCode -ne 0 -and
    $runnerOutput.Contains("$gateId is already closed and may not open another world")
) "The ED1 runner no longer refuses a same-identity physical rerun"
$global:LASTEXITCODE = 0

Write-Output (
    "C6_RAP_BW19V_ED1_CLOSURE_PASS worlds=2 trace_steps=944 " +
    "arm_a_first=tilt:94,torso:114 arm_b_first=tilt:94,torso:117 " +
    "applied_residuals=0,724 integrity_failures=0 " +
    "residual_necessary=False walking_authority=False same_identity_rerun=False"
)
