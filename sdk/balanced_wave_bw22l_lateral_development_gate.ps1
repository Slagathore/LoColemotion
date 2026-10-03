#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw22lCampaignId = "BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT"
$script:Bw22lGateId = "BW22L"
$script:Bw22lReceiptSchema =
    "sporespore_balanced_wave_bw22l_lateral_development_result_v1"
$script:Bw22lGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:Bw22lGodotSha256 =
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
$script:Bw22lStabilityPolicyId =
    "sporespore_scheduled_load_transfer_bw13p_a_v3"
$script:Bw22lExecutionMode =
    "native_balanced_wave_base_with_stability_contribution"
$script:Bw22lWalkingGateKeys = @(
    "bounded_lateral_drift",
    "bounded_tilt",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation"
)
$script:Bw22lProfiles = @(
    [ordered]@{
        token = "057"
        authored_friction = 0.57
        controller_coefficient = 0.56
        profile_id = "godot_jolt_bw22m_mu057_v1"
        profile_digest =
            "sha256:754c2f45b19dea315bd3527db8b8b87041be57cb7e4999412710d82c7c57903f"
    },
    [ordered]@{
        token = "069"
        authored_friction = 0.69
        controller_coefficient = 0.68
        profile_id = "godot_jolt_bw22m_mu069_v1"
        profile_digest =
            "sha256:a66f00fb0836a0838ab20e3f54c531ee5e9a6ea50180780e81e4f6106aad5ff3"
    },
    [ordered]@{
        token = "081"
        authored_friction = 0.81
        controller_coefficient = 0.79
        profile_id = "godot_jolt_bw22m_mu081_v1"
        profile_digest =
            "sha256:9446ba227a7a80f7592ffb7e358b8903a4e7afeb7297d5ba94dab87be8e33cbd"
    }
)
$script:Bw22lSeeds = @(24011, 24012, 24013, 24014)
$script:Bw22lCandidates = @(
    [ordered]@{
        candidate_id = "BW22L-A"
        policy_id = "sporespore_balanced_wave_bw15f_b_v1"
        runtime_profile_sha256 =
            "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"
        composition_digest =
            "sha256:c67ad10b9eb0c74eae4a91b7a431c0d0eaae8c28574dcc78d91ab90fdee82aba"
        proportional_factor = 1.0
        velocity_factor = 1.0
        candidate_order = 0
    },
    [ordered]@{
        candidate_id = "BW22L-B"
        policy_id = "sporespore_balanced_wave_bw21l_b_v1"
        runtime_profile_sha256 =
            "sha256:70b1b0c445bc8b53d94a09f70e18271b9727d9f41b772fa843ae9e59174af6f5"
        composition_digest =
            "sha256:431e8ea82d751f5c3755a21a2e91d096264580caa3b84d2dbaa9fc50062db07e"
        proportional_factor = 1.5
        velocity_factor = 1.0
        candidate_order = 1
    }
)
$script:Bw22lControlCompositionDigest =
    "sha256:867ac6c232ae94d27fe2f0789ef4df752cfcbb5881deb609e8c5acedf1bd35ef"
$script:Bw22lFalseClaims = @(
    "accepted",
    "walking_acceptance",
    "bounded_discrete_material_robustness",
    "material_robustness",
    "continuous_friction_coverage",
    "arbitrary_material_robustness",
    "population_inference",
    "superiority",
    "noninferiority_or_equivalence",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)

function Get-Bw22lMapValue {
    param(
        [Parameter(Mandatory)][object]$Map,
        [Parameter(Mandatory)][string]$Key,
        [object]$Default = $null
    )
    if ($Map -is [System.Collections.IDictionary] -and $Map.Contains($Key)) {
        return $Map[$Key]
    }
    return $Default
}

function Test-Bw22lNear {
    param([object]$Actual, [double]$Expected, [double]$Tolerance = 1.0e-12)
    try {
        $value = [double]$Actual
        return [double]::IsFinite($value) -and
            [math]::Abs($value - $Expected) -le $Tolerance
    } catch {
        return $false
    }
}

function Test-Bw22lFinite {
    param([object]$Value)
    try { return [double]::IsFinite([double]$Value) } catch { return $false }
}

function Test-Bw22lDiagnosticCell {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Cell)
    foreach ($field in @(
        "final_task_frame_lateral_displacement_m",
        "minimum_cross_track_error_m",
        "maximum_cross_track_error_m",
        "maximum_absolute_cross_track_error_m",
        "cumulative_absolute_cross_track_error_m_s",
        "maximum_absolute_requested_steering_fraction",
        "maximum_absolute_filtered_steering_fraction",
        "maximum_absolute_steering_delta_per_step"
    )) {
        if (-not (Test-Bw22lFinite (Get-Bw22lMapValue $Cell $field))) {
            return $false
        }
    }
    $initialPerturbation = Get-Bw22lMapValue $Cell "initial_perturbation" @{}
    return (
        [int](Get-Bw22lMapValue $Cell "steering_feedback_update_count" -1) -gt 0 -and
        [int](Get-Bw22lMapValue $Cell "steering_filter_application_count" -1) -gt 0 -and
        [int](Get-Bw22lMapValue $Cell "steering_saturation_count" -1) -ge 0 -and
        [int](Get-Bw22lMapValue $Cell "steering_slew_limited_count" -1) -ge 0 -and
        [double](Get-Bw22lMapValue (
            $Cell
        ) "maximum_absolute_requested_steering_fraction" 1.0) -le 0.400000000001 -and
        [double](Get-Bw22lMapValue (
            $Cell
        ) "maximum_absolute_filtered_steering_fraction" 1.0) -le 0.400000000001 -and
        $initialPerturbation -is [System.Collections.IDictionary] -and
        $initialPerturbation.Count -gt 0
    )
}

function Test-Bw22lSha256 {
    param([object]$Value)
    return [string]$Value -cmatch '^sha256:[0-9a-f]{64}$'
}

function Get-Bw22lFalseWalkingGateCount {
    param([object]$Gates)
    if ($Gates -isnot [System.Collections.IDictionary]) { return 999999 }
    if ($Gates.Count -ne $script:Bw22lWalkingGateKeys.Count) { return 999999 }
    $count = 0
    foreach ($key in $script:Bw22lWalkingGateKeys) {
        if (-not $Gates.Contains($key) -or $Gates[$key] -isnot [bool]) {
            return 999999
        }
        if (-not [bool]$Gates[$key]) { $count += 1 }
    }
    return $count
}

function Add-Bw22lGate {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Gates,
        [Parameter(Mandatory)][int]$Index,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [Parameter(Mandatory)][string]$FailureCode
    )
    $Gates.Add([ordered]@{
        index = $Index
        name = $Name
        passed = $Passed
        failure_code = $(if ($Passed) { "" } else { $FailureCode })
    })
}

function Get-Bw22lExpectedCells {
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($profile in $script:Bw22lProfiles) {
        foreach ($seed in $script:Bw22lSeeds) {
            foreach ($candidate in $script:Bw22lCandidates) {
                $candidateToken = ([string]$candidate.candidate_id).ToLowerInvariant().Replace(
                    "-", "_"
                )
                $cells.Add([ordered]@{
                    cell_id = "development_mu$($profile.token)_s${seed}_${candidateToken}"
                    role = "candidate"
                    campaign_seed = $seed
                    authored_friction = [double]$profile.authored_friction
                    controller_coefficient = [double]$profile.controller_coefficient
                    profile_id = [string]$profile.profile_id
                    profile_digest = [string]$profile.profile_digest
                    candidate_id = [string]$candidate.candidate_id
                    policy_id = [string]$candidate.policy_id
                    runtime_profile_sha256 = [string]$candidate.runtime_profile_sha256
                    composition_digest = [string]$candidate.composition_digest
                    proportional_factor = [double]$candidate.proportional_factor
                    velocity_factor = [double]$candidate.velocity_factor
                    global_scale = 0.5
                })
            }
            if ($seed -eq 24011) {
                $cells.Add([ordered]@{
                    cell_id = "development_mu$($profile.token)_s24011_control"
                    role = "control"
                    campaign_seed = 24011
                    authored_friction = [double]$profile.authored_friction
                    controller_coefficient = [double]$profile.controller_coefficient
                    profile_id = [string]$profile.profile_id
                    profile_digest = [string]$profile.profile_digest
                    candidate_id = "BW22L-CONTROL"
                    policy_id = [string]$script:Bw22lCandidates[0].policy_id
                    runtime_profile_sha256 =
                        [string]$script:Bw22lCandidates[0].runtime_profile_sha256
                    composition_digest = $script:Bw22lControlCompositionDigest
                    proportional_factor = 1.0
                    velocity_factor = 1.0
                    global_scale = 0.0
                })
            }
        }
    }
    $cells.Add([ordered]@{
        cell_id = "negative_mu000_s24011_safety"
        role = "safety"
        campaign_seed = 24011
        authored_friction = 0.0
        controller_coefficient = 0.0
        profile_id = "NONE"
        profile_digest = "NONE"
        candidate_id = "BW22L-SAFETY"
        policy_id = "NONE"
        runtime_profile_sha256 = "NONE"
        composition_digest = "NONE"
        proportional_factor = 0.0
        velocity_factor = 0.0
        global_scale = 0.0
    })
    return @($cells)
}

function Test-Bw22lCell {
    param(
        [Parameter(Mandatory)][object]$Cell,
        [Parameter(Mandatory)][object]$Expected
    )
    if ($Cell -isnot [System.Collections.IDictionary]) { return $false }
    $role = [string]$Expected.role
    $walkingGates = Get-Bw22lMapValue $Cell "walking_gate_receipts" @{}
    $falseWalkingGateCount = if ($role -ceq "safety") {
        0
    } else {
        Get-Bw22lFalseWalkingGateCount $walkingGates
    }
    $walkingObserved = if ($role -ceq "safety") {
        $false
    } else {
        $falseWalkingGateCount -eq 0
    }
    $common = (
        [string](Get-Bw22lMapValue $Cell "schema_version" "") -ceq
            "sporespore_balanced_wave_bw22l_lateral_development_cell_v1" -and
        [string](Get-Bw22lMapValue $Cell "campaign_id" "") -ceq
            $script:Bw22lCampaignId -and
        [string](Get-Bw22lMapValue $Cell "gate_id" "") -ceq $script:Bw22lGateId -and
        [string](Get-Bw22lMapValue $Cell "cell_id" "") -ceq
            [string]$Expected.cell_id -and
        [string](Get-Bw22lMapValue $Cell "role" "") -ceq $role -and
        [int](Get-Bw22lMapValue $Cell "campaign_seed" -1) -eq
            [int]$Expected.campaign_seed -and
        (Test-Bw22lNear (Get-Bw22lMapValue $Cell "authored_friction") (
            [double]$Expected.authored_friction
        )) -and
        (Test-Bw22lNear (Get-Bw22lMapValue $Cell "controller_coefficient") (
            [double]$Expected.controller_coefficient
        )) -and
        [string](Get-Bw22lMapValue $Cell "material_profile_id" "") -ceq
            [string]$Expected.profile_id -and
        [string](Get-Bw22lMapValue $Cell "material_profile_sha256" "") -ceq
            [string]$Expected.profile_digest -and
        [string](Get-Bw22lMapValue $Cell "candidate_id" "") -ceq
            [string]$Expected.candidate_id -and
        [string](Get-Bw22lMapValue $Cell "candidate_composition_digest" "") -ceq
            [string]$Expected.composition_digest -and
        [string](Get-Bw22lMapValue $Cell "controller_policy_id" "") -ceq
            [string]$Expected.policy_id -and
        [string](Get-Bw22lMapValue $Cell "declared_controller_policy_id" "") -ceq
            [string]$Expected.policy_id -and
        [string](Get-Bw22lMapValue $Cell "controller_runtime_profile_sha256" "") -ceq
            [string]$Expected.runtime_profile_sha256 -and
        (Test-Bw22lNear (Get-Bw22lMapValue $Cell "proportional_factor") (
            [double]$Expected.proportional_factor
        )) -and
        (Test-Bw22lNear (Get-Bw22lMapValue $Cell "velocity_factor") (
            [double]$Expected.velocity_factor
        )) -and
        (Test-Bw22lNear (Get-Bw22lMapValue $Cell "global_requested_correction_scale") (
            [double]$Expected.global_scale
        )) -and
        [int](Get-Bw22lMapValue $Cell "world_build_count" -1) -eq 1 -and
        [int](Get-Bw22lMapValue $Cell "world_reset_count" -1) -eq 0 -and
        [string](Get-Bw22lMapValue $Cell "physics_engine" "") -ceq "Jolt Physics" -and
        [int](Get-Bw22lMapValue $Cell "physics_hz" -1) -eq 120 -and
        [int](Get-Bw22lMapValue $Cell "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw22lMapValue $Cell "solver_position_steps" -1) -eq 7 -and
        [int](Get-Bw22lMapValue $Cell "direct_body_write_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "sdk_mismatch_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "sdk_failure_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "policy_branch_surface_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "material_condition_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "seed_condition_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "failure_identity_condition_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "outcome_condition_count" -1) -eq 0 -and
        [bool](Get-Bw22lMapValue $Cell "profile_binding_exact" $false) -and
        [bool](Get-Bw22lMapValue $Cell "common_execution_integrity" $false) -and
        [bool](Get-Bw22lMapValue $Cell "outcome_complete" $false) -and
        (Get-Bw22lMapValue $Cell "walking_observed" $null) -is [bool] -and
        [bool](Get-Bw22lMapValue $Cell "walking_observed" $false) -eq $walkingObserved -and
        [int](Get-Bw22lMapValue $Cell "failed_production_walking_gate_count" -1) -eq
            $falseWalkingGateCount -and
        -not [bool](Get-Bw22lMapValue $Cell "walking_claim_authorized" $true) -and
        -not [bool](Get-Bw22lMapValue $Cell "material_acceptance_claim_authorized" $true) -and
        -not [bool](Get-Bw22lMapValue $Cell "physical_acceptance_authority" $true)
    )
    if (-not $common) { return $false }
    foreach ($field in @(
        "fixture_spec_sha256",
        "evidence_threshold_configuration_sha256",
        "solver_policy_configuration_sha256",
        "controller_configuration_sha256",
        "initial_perturbation_sha256",
        "initial_pose_sha256"
    )) {
        if (-not (Test-Bw22lSha256 (Get-Bw22lMapValue $Cell $field ""))) {
            return $false
        }
    }
    if ($role -ceq "candidate") {
        return (
            [bool](Get-Bw22lMapValue $Cell "mechanism_gate_passed" $false) -and
            [bool](Get-Bw22lMapValue $Cell "combined_application_gate_passed" $false) -and
            [bool](Get-Bw22lMapValue $Cell "residual_application_expected" $false) -and
            [bool](Get-Bw22lMapValue $Cell "residual_application_observed" $false) -and
            [int](Get-Bw22lMapValue $Cell "sdk_effective_application_count" 0) -gt 0 -and
            [int](Get-Bw22lMapValue $Cell "sdk_native_motor_write_count" 0) -gt 0 -and
            (Test-Bw22lFinite (
                Get-Bw22lMapValue $Cell "maximum_absolute_applied_velocity_rad_s"
            )) -and
            [double](Get-Bw22lMapValue (
                $Cell
            ) "maximum_absolute_applied_velocity_rad_s" 0.0) -gt 0.0 -and
            [bool](Get-Bw22lMapValue $Cell "base_controller_application_observed" $false) -and
            [bool](Get-Bw22lMapValue $Cell "broad_base_controller_physical_influence_observed" $false) -and
            (Test-Bw22lDiagnosticCell -Cell $Cell)
        )
    }
    if ($role -ceq "control") {
        return (
            [bool](Get-Bw22lMapValue $Cell "mechanism_gate_passed" $false) -and
            -not [bool](Get-Bw22lMapValue $Cell "combined_application_gate_passed" $true) -and
            -not [bool](Get-Bw22lMapValue $Cell "residual_application_expected" $true) -and
            -not [bool](Get-Bw22lMapValue $Cell "residual_application_observed" $true) -and
            [int](Get-Bw22lMapValue $Cell "sdk_effective_application_count" -1) -eq 0 -and
            [int](Get-Bw22lMapValue $Cell "sdk_native_motor_write_count" 0) -gt 0 -and
            (Test-Bw22lNear (Get-Bw22lMapValue $Cell "maximum_absolute_applied_velocity_rad_s") 0.0) -and
            [bool](Get-Bw22lMapValue $Cell "base_controller_application_observed" $false) -and
            [bool](Get-Bw22lMapValue $Cell "broad_base_controller_physical_influence_observed" $false)
        )
    }
    return (
        -not [bool](Get-Bw22lMapValue $Cell "mechanism_gate_passed" $true) -and
        -not [bool](Get-Bw22lMapValue $Cell "combined_application_gate_passed" $true) -and
        [int](Get-Bw22lMapValue $Cell "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $Cell "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw22lMapValue $Cell "physical_influence" $true)
    )
}

function Get-Bw22lCandidateSummaries {
    param([Parameter(Mandatory)][object[]]$CandidateCells)
    $summaries = [System.Collections.Generic.List[object]]::new()
    $baselineCells = @($CandidateCells | Where-Object {
        [string](Get-Bw22lMapValue $_ "candidate_id" "") -ceq "BW22L-A"
    })
    foreach ($candidate in $script:Bw22lCandidates) {
        $candidateId = [string]$candidate.candidate_id
        $cells = @($CandidateCells | Where-Object {
            [string](Get-Bw22lMapValue $_ "candidate_id" "") -ceq $candidateId
        })
        $walkingFailures = @($cells | Where-Object {
            -not [bool](Get-Bw22lMapValue $_ "walking_observed" $false)
        }).Count
        $failedGates = 0
        $maxCrossTrack = [double]::NegativeInfinity
        $cumulative = 0.0
        foreach ($cell in $cells) {
            $failedGates += [int](Get-Bw22lMapValue (
                $cell
            ) "failed_production_walking_gate_count" 999999)
            $maxCrossTrack = [math]::Max(
                $maxCrossTrack,
                [double](Get-Bw22lMapValue (
                    $cell
                ) "maximum_absolute_cross_track_error_m" ([double]::PositiveInfinity))
            )
            $cumulative += [double](Get-Bw22lMapValue (
                $cell
            ) "cumulative_absolute_cross_track_error_m_s" ([double]::PositiveInfinity))
        }
        $pairedRegressions = 0
        if ($candidateId -cne "BW22L-A") {
            foreach ($cell in $cells) {
                $baseline = @($baselineCells | Where-Object {
                    [int](Get-Bw22lMapValue $_ "campaign_seed" -1) -eq
                        [int](Get-Bw22lMapValue $cell "campaign_seed" -2) -and
                    [string](Get-Bw22lMapValue $_ "material_profile_id" "") -ceq
                        [string](Get-Bw22lMapValue $cell "material_profile_id" "")
                }) | Select-Object -First 1
                if ($null -eq $baseline) {
                    $pairedRegressions += 1000
                    continue
                }
                $baselineGates = Get-Bw22lMapValue $baseline "walking_gate_receipts" @{}
                $candidateGates = Get-Bw22lMapValue $cell "walking_gate_receipts" @{}
                foreach ($key in $script:Bw22lWalkingGateKeys) {
                    if ([bool]$baselineGates[$key] -and -not [bool]$candidateGates[$key]) {
                        $pairedRegressions += 1
                    }
                }
            }
        }
        $summaries.Add([ordered]@{
            candidate_id = $candidateId
            observed_world_count = $cells.Count
            walking_conjunction_failure_count = [int]$walkingFailures
            aggregate_failed_production_walking_gate_count = [int]$failedGates
            maximum_absolute_cross_track_error_m = [double]$maxCrossTrack
            aggregate_cumulative_absolute_cross_track_error_m_s = [double]$cumulative
            paired_walking_gate_regression_count = [int]$pairedRegressions
            candidate_order = [int]$candidate.candidate_order
        })
    }
    return @($summaries)
}

function Compare-Bw22lCandidateSummary {
    param([Parameter(Mandatory)][object]$Left, [Parameter(Mandatory)][object]$Right)
    foreach ($field in @(
        "walking_conjunction_failure_count",
        "aggregate_failed_production_walking_gate_count",
        "maximum_absolute_cross_track_error_m",
        "aggregate_cumulative_absolute_cross_track_error_m_s",
        "candidate_order"
    )) {
        $leftValue = [double]$Left[$field]
        $rightValue = [double]$Right[$field]
        if ($leftValue -lt $rightValue) { return -1 }
        if ($leftValue -gt $rightValue) { return 1 }
    }
    return 0
}

function Invoke-Bw22lLateralDevelopmentEvaluation {
    param([Parameter(Mandatory)][object]$Result)
    $gates = [System.Collections.Generic.List[object]]::new()
    $cells = @((Get-Bw22lMapValue $Result "cells" @()))
    $expectedCells = @(Get-Bw22lExpectedCells)

    Add-Bw22lGate $gates 1 "receipt_identity" (
        [string](Get-Bw22lMapValue $Result "schema_version" "") -ceq
            $script:Bw22lReceiptSchema -and
        [string](Get-Bw22lMapValue $Result "campaign_id" "") -ceq
            $script:Bw22lCampaignId -and
        [string](Get-Bw22lMapValue $Result "gate_id" "") -ceq $script:Bw22lGateId -and
        [string](Get-Bw22lMapValue $Result "study_classification" "") -ceq
            "paired_outcome_exposed_finite_controller_development_screen" -and
        [int](Get-Bw22lMapValue $Result "expected_gate_count" -1) -eq 50 -and
        [int](Get-Bw22lMapValue $Result "expected_world_count" -1) -eq 28
    ) "BW22L_RECEIPT_IDENTITY"

    $engine = Get-Bw22lMapValue $Result "engine" @{}
    $source = Get-Bw22lMapValue $Result "source" @{}
    Add-Bw22lGate $gates 2 "host_and_source" (
        [string](Get-Bw22lMapValue $engine "physics_engine" "") -ceq "Jolt Physics" -and
        [string](Get-Bw22lMapValue $engine "godot_version" "") -ceq
            $script:Bw22lGodotVersion -and
        [string](Get-Bw22lMapValue $engine "godot_executable_sha256" "") -ceq
            $script:Bw22lGodotSha256 -and
        [int](Get-Bw22lMapValue $engine "physics_hz" -1) -eq 120 -and
        [int](Get-Bw22lMapValue $engine "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw22lMapValue $engine "solver_position_steps" -1) -eq 7 -and
        [string](Get-Bw22lMapValue $source "commit" "") -cmatch '^[0-9a-f]{40}$' -and
        [bool](Get-Bw22lMapValue $source "worktree_clean" $false) -and
        [bool](Get-Bw22lMapValue $source "matches_live_github_main" $false)
    ) "BW22L_HOST_SOURCE"

    $prerequisites = Get-Bw22lMapValue $Result "prerequisites" @{}
    Add-Bw22lGate $gates 3 "prerequisite_evidence" (
        [string](Get-Bw22lMapValue $prerequisites "bw21l_closure_raw_sha256" "") -ceq
            "d592e160c1111d05047a545986099ce957226a8d12e81d19013930133b98af4b" -and
        [string](Get-Bw22lMapValue $prerequisites "bw22m_characterization_closure_raw_sha256" "") -ceq
            "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6" -and
        [string](Get-Bw22lMapValue $prerequisites "bw22m_profile_closure_raw_sha256" "") -ceq
            "09a7f017a85f9bfe53c6f707985bd9b87083cee564168bf0311d8b57d8b787e9" -and
        [bool](Get-Bw22lMapValue $prerequisites "bw21l_infrastructure_invalid" $false) -and
        -not [bool](Get-Bw22lMapValue $prerequisites "bw21l_candidate_selected" $true) -and
        [bool](Get-Bw22lMapValue $prerequisites "bw22m_profiles_closed_positive" $false) -and
        [bool](Get-Bw22lMapValue $prerequisites "fresh_values_and_seeds_unopened" $false)
    ) "BW22L_PREREQUISITES"

    $declarations = Get-Bw22lMapValue $Result "declarations" @{}
    Add-Bw22lGate $gates 4 "frozen_declarations" (
        [string](Get-Bw22lMapValue $declarations "candidates_raw_sha256" "") -ceq
            "31b02c3cfd6c15ed054d27082c21d8e2fad7811260bfc952e8455ba72a90a55c" -and
        @((Get-Bw22lMapValue $declarations "candidate_order" @())) -join ',' -ceq
            "BW22L-A,BW22L-B" -and
        @((Get-Bw22lMapValue $declarations "material_profile_ids" @())) -join ',' -ceq
            (@($script:Bw22lProfiles.profile_id) -join ',') -and
        @((Get-Bw22lMapValue $declarations "seeds" @())) -join ',' -ceq
            ($script:Bw22lSeeds -join ',') -and
        [string](Get-Bw22lMapValue $declarations "baseline_candidate_id" "") -ceq
            "BW22L-A"
    ) "BW22L_DECLARATIONS"

    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $cell = if ($index -lt $cells.Count) { $cells[$index] } else { @{} }
        Add-Bw22lGate $gates ($index + 5) (
            "cell_" + [string]$expectedCells[$index].cell_id
        ) (Test-Bw22lCell -Cell $cell -Expected $expectedCells[$index]) `
            "BW22L_CELL_GATE"
    }

    $candidates = @($cells | Where-Object {
        [string](Get-Bw22lMapValue $_ "role" "") -ceq "candidate"
    })
    $controls = @($cells | Where-Object {
        [string](Get-Bw22lMapValue $_ "role" "") -ceq "control"
    })
    $safetyCells = @($cells | Where-Object {
        [string](Get-Bw22lMapValue $_ "role" "") -ceq "safety"
    })
    Add-Bw22lGate $gates 33 "exact_order_and_role_cardinality" (
        $cells.Count -eq 28 -and $candidates.Count -eq 24 -and
        $controls.Count -eq 3 -and $safetyCells.Count -eq 1 -and
        [int](Get-Bw22lMapValue $Result "observed_world_count" -1) -eq 28 -and
        [int](Get-Bw22lMapValue $Result "integrity_failure_count" -1) -eq 0
    ) "BW22L_MATRIX_CARDINALITY"

    Add-Bw22lGate $gates 34 "zero_candidate_infrastructure_failures" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not [bool](Get-Bw22lMapValue $_ "common_execution_integrity" $false) -or
            -not [bool](Get-Bw22lMapValue $_ "outcome_complete" $false)
        }).Count -eq 0
    ) "BW22L_CANDIDATE_INFRASTRUCTURE"

    Add-Bw22lGate $gates 35 "policy_relative_receipt_identity" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            [string](Get-Bw22lMapValue $_ "controller_policy_id" "") -cne
                [string](Get-Bw22lMapValue $_ "declared_controller_policy_id" "") -or
            [string](Get-Bw22lMapValue (
                Get-Bw22lMapValue $_ "policy_relative_common_execution" @{}
            ) "schema_version" "") -cne
                "sporespore_policy_relative_execution_integrity_v1" -or
            -not [bool](Get-Bw22lMapValue (
                Get-Bw22lMapValue $_ "policy_relative_common_execution" @{}
            ) "ok" $false)
        }).Count -eq 0
    ) "BW22L_POLICY_RELATIVE_IDENTITY"

    Add-Bw22lGate $gates 36 "candidate_mechanism_and_application" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not [bool](Get-Bw22lMapValue $_ "mechanism_gate_passed" $false) -or
            -not [bool](Get-Bw22lMapValue $_ "combined_application_gate_passed" $false) -or
            [int](Get-Bw22lMapValue $_ "sdk_effective_application_count" 0) -le 0
        }).Count -eq 0
    ) "BW22L_CANDIDATE_APPLICATION"

    Add-Bw22lGate $gates 37 "candidate_outcomes_and_metrics" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not (Test-Bw22lFinite (Get-Bw22lMapValue $_ "maximum_absolute_cross_track_error_m")) -or
            -not (Test-Bw22lFinite (Get-Bw22lMapValue $_ "cumulative_absolute_cross_track_error_m_s")) -or
            (Get-Bw22lFalseWalkingGateCount (
                Get-Bw22lMapValue $_ "walking_gate_receipts" @{}
            )) -ge 999999
        }).Count -eq 0
    ) "BW22L_CANDIDATE_OUTCOME_METRICS"

    Add-Bw22lGate $gates 38 "candidate_profiles_gains_and_compositions" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            $row = @($script:Bw22lCandidates | Where-Object candidate_id -CEQ (
                [string](Get-Bw22lMapValue $_ "candidate_id" "")
            )) | Select-Object -First 1
            $null -eq $row -or
            [string](Get-Bw22lMapValue $_ "controller_policy_id" "") -cne
                [string]$row.policy_id -or
            [string](Get-Bw22lMapValue $_ "controller_runtime_profile_sha256" "") -cne
                [string]$row.runtime_profile_sha256 -or
            [string](Get-Bw22lMapValue $_ "candidate_composition_digest" "") -cne
                [string]$row.composition_digest
        }).Count -eq 0
    ) "BW22L_CANDIDATE_PROFILE"

    Add-Bw22lGate $gates 39 "corrected_zero_residual_controls" (
        $controls.Count -eq 3 -and @($controls | Where-Object {
            -not [bool](Get-Bw22lMapValue $_ "common_execution_integrity" $false) -or
            [bool](Get-Bw22lMapValue $_ "combined_application_gate_passed" $true) -or
            [int](Get-Bw22lMapValue $_ "sdk_effective_application_count" -1) -ne 0
        }).Count -eq 0
    ) "BW22L_CONTROL_RESIDUAL_SEMANTICS"

    Add-Bw22lGate $gates 40 "active_base_controller_controls" (
        $controls.Count -eq 3 -and @($controls | Where-Object {
            -not [bool](Get-Bw22lMapValue $_ "base_controller_application_observed" $false) -or
            -not [bool](Get-Bw22lMapValue $_ "broad_base_controller_physical_influence_observed" $false)
        }).Count -eq 0
    ) "BW22L_CONTROL_BASE_INFLUENCE"

    $pairFields = @(
        "fixture_spec_sha256",
        "evidence_threshold_configuration_sha256",
        "solver_policy_configuration_sha256",
        "initial_perturbation_sha256",
        "initial_pose_sha256",
        "material_profile_id",
        "material_profile_sha256"
    )
    $pairIdentityPassed = $candidates.Count -eq 24
    $perturbationPassed = $candidates.Count -eq 24
    foreach ($profile in $script:Bw22lProfiles) {
        foreach ($seed in $script:Bw22lSeeds) {
            $group = @($candidates | Where-Object {
                [string](Get-Bw22lMapValue $_ "material_profile_id" "") -ceq
                    [string]$profile.profile_id -and
                [int](Get-Bw22lMapValue $_ "campaign_seed" -1) -eq $seed
            })
            if ($seed -eq 24011) {
                $group += @($controls | Where-Object {
                    [string](Get-Bw22lMapValue $_ "material_profile_id" "") -ceq
                        [string]$profile.profile_id
                })
            }
            $pairIdentityPassed = $pairIdentityPassed -and $group.Count -eq (
                $(if ($seed -eq 24011) { 3 } else { 2 })
            )
            if ($group.Count -gt 0) {
                foreach ($field in $pairFields) {
                    $values = @($group | ForEach-Object {
                        [string](Get-Bw22lMapValue $_ $field "")
                    } | Select-Object -Unique)
                    $pairIdentityPassed = $pairIdentityPassed -and $values.Count -eq 1
                }
                $perturbations = @($group | ForEach-Object {
                    $perturbation = Get-Bw22lMapValue $_ "initial_perturbation" @{}
                    $perturbation | ConvertTo-Json -Compress -Depth 20
                } | Select-Object -Unique)
                $perturbationPassed = $perturbationPassed -and $perturbations.Count -eq 1
            }
        }
    }
    Add-Bw22lGate $gates 41 "paired_configuration_identity" $pairIdentityPassed `
        "BW22L_PAIR_IDENTITY"
    Add-Bw22lGate $gates 42 "paired_initial_perturbations" $perturbationPassed `
        "BW22L_PAIRED_PERTURBATION"

    $safety = if ($safetyCells.Count -eq 1) { $safetyCells[0] } else { @{} }
    Add-Bw22lGate $gates 43 "zero_friction_safety" (
        $safetyCells.Count -eq 1 -and
        [int](Get-Bw22lMapValue $safety "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw22lMapValue $safety "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw22lMapValue $safety "physical_influence" $true)
    ) "BW22L_ZERO_SAFETY"

    Add-Bw22lGate $gates 44 "steering_diagnostics" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not (Test-Bw22lDiagnosticCell -Cell $_)
        }).Count -eq 0
    ) "BW22L_STEERING_DIAGNOSTICS"

    $candidateCompletionPassed = (
        $candidates.Count -eq 24 -and @($script:Bw22lCandidates | Where-Object {
            $id = [string]$_.candidate_id
            @($candidates | Where-Object {
                [string](Get-Bw22lMapValue $_ "candidate_id" "") -ceq $id
            }).Count -ne 12
        }).Count -eq 0
    )
    Add-Bw22lGate $gates 45 "all_candidates_complete_before_selection" `
        $candidateCompletionPassed "BW22L_CANDIDATE_COMPLETION"

    $selector = Get-Bw22lMapValue $Result "selector" @{}
    Add-Bw22lGate $gates 46 "frozen_selector" (
        [string](Get-Bw22lMapValue $selector "selection_mode" "") -ceq
            "complete_preregistered_lexicographic_development_selection" -and
        [string](Get-Bw22lMapValue $selector "baseline_candidate_id" "") -ceq
            "BW22L-A" -and
        @((Get-Bw22lMapValue $selector "selection_vector" @())) -join ',' -ceq
            "walking_conjunction_failure_count,aggregate_failed_production_walking_gate_count,maximum_absolute_cross_track_error_m,aggregate_cumulative_absolute_cross_track_error_m_s,candidate_order" -and
        [bool](Get-Bw22lMapValue $selector "strict_improvement_required" $false) -and
        [int](Get-Bw22lMapValue $selector "maximum_paired_walking_gate_regressions" -1) -eq 0
    ) "BW22L_SELECTOR_DECLARATION"

    $summaries = @(Get-Bw22lCandidateSummaries -CandidateCells $candidates)
    $baseline = @($summaries | Where-Object candidate_id -CEQ "BW22L-A") |
        Select-Object -First 1
    $successor = @($summaries | Where-Object candidate_id -CEQ "BW22L-B") |
        Select-Object -First 1
    $comparison = if ($null -ne $successor -and $null -ne $baseline) {
        Compare-Bw22lCandidateSummary -Left $successor -Right $baseline
    } else { 0 }
    $strictlyBetter = $comparison -lt 0
    $pairedRegressionCount = if ($null -ne $successor) {
        [int]$successor.paired_walking_gate_regression_count
    } else { 999999 }
    $selectedCandidateId = if (
        $candidateCompletionPassed -and $strictlyBetter -and
        $pairedRegressionCount -eq 0
    ) { "BW22L-B" } else { "NONE" }
    Add-Bw22lGate $gates 47 "strict_selection_integrity" (
        $candidateCompletionPassed -and $summaries.Count -eq 2 -and
        $selectedCandidateId -in @("BW22L-B", "NONE") -and
        ($selectedCandidateId -cne "BW22L-B" -or (
            $strictlyBetter -and $pairedRegressionCount -eq 0
        ))
    ) "BW22L_SELECTION_INTEGRITY"

    Add-Bw22lGate $gates 48 "zero_outcome_conditioning" (
        @(@($candidates) + @($controls) | Where-Object {
            [int](Get-Bw22lMapValue $_ "policy_branch_surface_count" -1) -ne 0 -or
            [int](Get-Bw22lMapValue $_ "material_condition_count" -1) -ne 0 -or
            [int](Get-Bw22lMapValue $_ "seed_condition_count" -1) -ne 0 -or
            [int](Get-Bw22lMapValue $_ "failure_identity_condition_count" -1) -ne 0 -or
            [int](Get-Bw22lMapValue $_ "outcome_condition_count" -1) -ne 0
        }).Count -eq 0
    ) "BW22L_OUTCOME_CONDITIONING"

    $claims = Get-Bw22lMapValue $Result "declared_claims" @{}
    $claimsPassed = $claims -is [System.Collections.IDictionary]
    foreach ($claimName in $script:Bw22lFalseClaims) {
        $claimsPassed = $claimsPassed -and
            -not [bool](Get-Bw22lMapValue $claims $claimName $true)
    }
    Add-Bw22lGate $gates 49 "claim_boundary" $claimsPassed `
        "BW22L_CLAIM_INFLATION"

    Add-Bw22lGate $gates 50 "selector_not_preinvoked" (
        [int](Get-Bw22lMapValue $Result "selector_invocation_count_before_evaluation" -1) -eq 0 -and
        [string](Get-Bw22lMapValue $Result "pre_evaluation_selected_candidate_id" "") -ceq
            "NONE"
    ) "BW22L_SELECTOR_PREINVOCATION"

    $failureCodes = @($gates | Where-Object { -not [bool]$_.passed } |
        ForEach-Object { [string]$_.failure_code } | Select-Object -Unique)
    $ok = $gates.Count -eq 50 -and $failureCodes.Count -eq 0
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw22l_lateral_development_evaluation_v1"
        ok = $ok
        campaign_id = $script:Bw22lCampaignId
        gate_id = $script:Bw22lGateId
        reconstructed_passed_gate_count = @($gates | Where-Object passed).Count
        reconstructed_failed_gate_count = @($gates | Where-Object {
            -not $_.passed
        }).Count
        expected_gate_count = 50
        expected_world_count = 28
        observed_world_count = [int](Get-Bw22lMapValue $Result "observed_world_count" -1)
        candidate_count = $candidates.Count
        control_count = $controls.Count
        safety_count = $safetyCells.Count
        candidate_summaries = $summaries
        selected_candidate_id = $selectedCandidateId
        selected_candidate_strictly_better_than_baseline = $strictlyBetter
        selected_candidate_paired_regression_count = $pairedRegressionCount
        development_selection_authority = ($ok -and $selectedCandidateId -ceq "BW22L-B")
        independent_validation_authority = $false
        gates = @($gates)
        failure_codes = $failureCodes
        claims_if_valid = [ordered]@{
            complete_finite_development_result = $ok
            development_candidate_selected = ($ok -and $selectedCandidateId -ceq "BW22L-B")
            walking_acceptance = $false
            bounded_discrete_material_robustness = $false
            material_robustness = $false
            continuous_friction_coverage = $false
            population_inference = $false
            superiority = $false
            noninferiority_or_equivalence = $false
            cross_engine_equivalence = $false
            arbitrary_quadruped_coverage = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
            physical_acceptance_authority = $false
        }
        selection_interpretation =
            "Any selected arm is a development hypothesis requiring a distinct fresh independent validation identity; NONE is a valid complete development outcome."
        physical_acceptance_authority = $false
    }
}

function New-Bw22lPerfectSyntheticLateralDevelopmentResult {
    $expectedCells = @(Get-Bw22lExpectedCells)
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($expected in $expectedCells) {
        $role = [string]$expected.role
        $isCandidate = $role -ceq "candidate"
        $isControl = $role -ceq "control"
        $isSafety = $role -ceq "safety"
        $profileIndex = [math]::Max(0, @($script:Bw22lProfiles.profile_id).IndexOf(
            [string]$expected.profile_id
        ))
        $seedIndex = [math]::Max(0, $script:Bw22lSeeds.IndexOf(
            [int]$expected.campaign_seed
        ))
        $pairNumber = 1 + ($profileIndex * 4) + $seedIndex
        $pairToken = $pairNumber.ToString("x").PadLeft(64, "0")
        $candidateIndex = @($script:Bw22lCandidates.candidate_id).IndexOf(
            [string]$expected.candidate_id
        )
        $controllerToken = (20 + [math]::Max(0, $candidateIndex)).ToString(
            "x"
        ).PadLeft(64, "0")
        $walkingGates = [ordered]@{
            bounded_lateral_drift = $true
            bounded_tilt = $true
            minimum_final_forward_translation = $true
            native_sdk_exclusive_post_settle_actuation = $true
        }
        if ($isCandidate -and [string]$expected.candidate_id -ceq "BW22L-A") {
            $walkingGates.bounded_lateral_drift = $false
        }
        $failedWalking = if ($isSafety) {
            0
        } else { Get-Bw22lFalseWalkingGateCount $walkingGates }
        $isSuccessor = $isCandidate -and
            [string]$expected.candidate_id -ceq "BW22L-B"
        $cell = [ordered]@{
            schema_version =
                "sporespore_balanced_wave_bw22l_lateral_development_cell_v1"
            campaign_id = $script:Bw22lCampaignId
            gate_id = $script:Bw22lGateId
            cell_id = [string]$expected.cell_id
            role = $role
            campaign_seed = [int]$expected.campaign_seed
            authored_friction = [double]$expected.authored_friction
            controller_coefficient = [double]$expected.controller_coefficient
            material_profile_id = [string]$expected.profile_id
            material_profile_sha256 = [string]$expected.profile_digest
            candidate_id = [string]$expected.candidate_id
            candidate_composition_digest = [string]$expected.composition_digest
            controller_policy_id = [string]$expected.policy_id
            declared_controller_policy_id = [string]$expected.policy_id
            controller_runtime_profile_sha256 =
                [string]$expected.runtime_profile_sha256
            proportional_factor = [double]$expected.proportional_factor
            velocity_factor = [double]$expected.velocity_factor
            stability_policy_id = $(if ($isSafety) {
                "NONE"
            } else { $script:Bw22lStabilityPolicyId })
            authority_scope = $(if ($isSafety) { "none" } else { "post_settle_full" })
            execution_mode = $(if ($isSafety) {
                "shadow_only_no_sdk_native_actuation"
            } else { $script:Bw22lExecutionMode })
            global_requested_correction_scale = [double]$expected.global_scale
            world_build_count = 1
            world_reset_count = 0
            physics_engine = "Jolt Physics"
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
            direct_body_write_count = 0
            sdk_mismatch_count = 0
            sdk_failure_count = 0
            policy_branch_surface_count = 0
            material_condition_count = 0
            seed_condition_count = 0
            failure_identity_condition_count = 0
            outcome_condition_count = 0
            fixture_spec_sha256 = "sha256:$pairToken"
            evidence_threshold_configuration_sha256 = "sha256:$pairToken"
            solver_policy_configuration_sha256 = "sha256:$pairToken"
            controller_configuration_sha256 = "sha256:$controllerToken"
            initial_perturbation_sha256 = "sha256:$pairToken"
            initial_perturbation = [ordered]@{
                gait_phase_offset_ticks = $seedIndex
                task_frame_lateral_offset_m = 0.001 * $pairNumber
                task_frame_lateral_velocity_m_s = -0.002 * $pairNumber
            }
            initial_pose_sha256 = "sha256:$pairToken"
            profile_binding_exact = $true
            common_execution_integrity = $true
            outcome_complete = $true
            mechanism_gate_passed = -not $isSafety
            combined_application_gate_passed = $isCandidate
            residual_application_expected = $isCandidate
            residual_application_observed = $isCandidate
            sdk_native_motor_write_count = $(if ($isSafety) { 0 } else { 9232 })
            sdk_effective_application_count = $(if ($isCandidate) { 100 } else { 0 })
            maximum_absolute_applied_velocity_rad_s = $(if ($isCandidate) { 0.02 } else { 0.0 })
            base_controller_application_observed = -not $isSafety
            broad_base_controller_physical_influence_observed = -not $isSafety
            physical_influence = $isCandidate
            walking_observed = $(if ($isSafety) { $false } else { $failedWalking -eq 0 })
            walking_gate_receipts = $(if ($isSafety) { [ordered]@{} } else { $walkingGates })
            failed_production_walking_gate_count = $failedWalking
            final_task_frame_lateral_displacement_m = $(if ($isSuccessor) {
                0.02
            } else { 0.04 })
            minimum_cross_track_error_m = $(if ($isSuccessor) {
                -0.08
            } else { -0.16 })
            maximum_cross_track_error_m = $(if ($isSuccessor) {
                0.10
            } else { 0.20 })
            maximum_absolute_cross_track_error_m = $(if ($isSuccessor) { 0.10 } else { 0.20 })
            cumulative_absolute_cross_track_error_m_s = $(if ($isSuccessor) { 0.40 } else { 0.80 })
            steering_feedback_update_count = $(if ($isCandidate) { 100 } else { 1 })
            steering_filter_application_count = $(if ($isCandidate) { 100 } else { 1 })
            steering_saturation_count = 0
            steering_slew_limited_count = $(if ($isCandidate) { 5 } else { 0 })
            maximum_absolute_requested_steering_fraction = $(if ($isSuccessor) { 0.25 } else { 0.18 })
            maximum_absolute_filtered_steering_fraction = $(if ($isSuccessor) { 0.20 } else { 0.15 })
            maximum_absolute_steering_delta_per_step = $(if ($isCandidate) {
                0.01
            } else { 0.0 })
            policy_relative_common_execution = [ordered]@{
                schema_version = "sporespore_policy_relative_execution_integrity_v1"
                ok = $true
            }
            walking_claim_authorized = $false
            material_acceptance_claim_authorized = $false
            physical_acceptance_authority = $false
        }
        $cells.Add($cell)
    }
    $claims = [ordered]@{}
    foreach ($claimName in $script:Bw22lFalseClaims) { $claims[$claimName] = $false }
    return [ordered]@{
        schema_version = $script:Bw22lReceiptSchema
        campaign_id = $script:Bw22lCampaignId
        gate_id = $script:Bw22lGateId
        study_classification =
            "paired_outcome_exposed_finite_controller_development_screen"
        expected_gate_count = 50
        expected_world_count = 28
        observed_world_count = 28
        integrity_failure_count = 0
        engine = [ordered]@{
            physics_engine = "Jolt Physics"
            godot_version = $script:Bw22lGodotVersion
            godot_executable_sha256 = $script:Bw22lGodotSha256
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
        }
        source = [ordered]@{
            commit = "a" * 40
            worktree_clean = $true
            matches_live_github_main = $true
        }
        prerequisites = [ordered]@{
            bw21l_closure_raw_sha256 =
                "d592e160c1111d05047a545986099ce957226a8d12e81d19013930133b98af4b"
            bw22m_characterization_closure_raw_sha256 =
                "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6"
            bw22m_profile_closure_raw_sha256 =
                "09a7f017a85f9bfe53c6f707985bd9b87083cee564168bf0311d8b57d8b787e9"
            bw21l_infrastructure_invalid = $true
            bw21l_candidate_selected = $false
            bw22m_profiles_closed_positive = $true
            fresh_values_and_seeds_unopened = $true
        }
        declarations = [ordered]@{
            candidates_raw_sha256 =
                "31b02c3cfd6c15ed054d27082c21d8e2fad7811260bfc952e8455ba72a90a55c"
            candidate_order = @("BW22L-A", "BW22L-B")
            material_profile_ids = @($script:Bw22lProfiles.profile_id)
            seeds = $script:Bw22lSeeds
            baseline_candidate_id = "BW22L-A"
        }
        selector = [ordered]@{
            selection_mode =
                "complete_preregistered_lexicographic_development_selection"
            baseline_candidate_id = "BW22L-A"
            selection_vector = @(
                "walking_conjunction_failure_count",
                "aggregate_failed_production_walking_gate_count",
                "maximum_absolute_cross_track_error_m",
                "aggregate_cumulative_absolute_cross_track_error_m_s",
                "candidate_order"
            )
            strict_improvement_required = $true
            maximum_paired_walking_gate_regressions = 0
        }
        selector_invocation_count_before_evaluation = 0
        pre_evaluation_selected_candidate_id = "NONE"
        cells = @($cells)
        declared_claims = $claims
    }
}
