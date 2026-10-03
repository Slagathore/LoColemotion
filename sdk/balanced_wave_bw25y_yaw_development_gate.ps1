#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw25yCampaignId = "BW25Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
$script:Bw25yGateId = "BW25Y"
$script:Bw25yReceiptSchema =
    "sporespore_balanced_wave_bw25y_yaw_development_result_v1"
$script:Bw25yGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:Bw25yGodotSha256 =
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
$script:Bw25yStabilityPolicyId =
    "sporespore_scheduled_load_transfer_bw13p_a_v3"
$script:Bw25yExecutionMode =
    "native_balanced_wave_base_with_stability_contribution"
$script:Bw25yWalkingGateKeys = @(
    "bounded_lateral_drift",
    "bounded_tilt",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation"
)
$script:Bw25yProfiles = @(
    [ordered]@{
        token = "059"
        authored_friction = 0.59
        controller_coefficient = 0.58
        profile_id = "godot_jolt_bw24m_mu059_v1"
        profile_digest =
            "sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173"
    },
    [ordered]@{
        token = "071"
        authored_friction = 0.71
        controller_coefficient = 0.68
        profile_id = "godot_jolt_bw24m_mu071_v1"
        profile_digest =
            "sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee"
    },
    [ordered]@{
        token = "083"
        authored_friction = 0.83
        controller_coefficient = 0.81
        profile_id = "godot_jolt_bw24m_mu083_v1"
        profile_digest =
            "sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0"
    }
)
$script:Bw25ySeeds = @(26011, 26012, 26013, 26014)
$script:Bw25yCandidates = @(
    [ordered]@{
        candidate_id = "BW25Y-A"
        policy_id = "sporespore_balanced_wave_bw15f_b_v1"
        runtime_profile_sha256 =
            "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"
        composition_digest =
            "sha256:3a2e04cfa76c63f829d9828b125a8de2e0c0fe35e75b29d8caf87866ce1ea913"
        proportional_factor = 1.0
        velocity_factor = 1.0
        yaw_error_stride_gain_per_rad = 1.3
        candidate_order = 0
    },
    [ordered]@{
        candidate_id = "BW25Y-B"
        policy_id = "sporespore_balanced_wave_bw23y_b_v1"
        runtime_profile_sha256 =
            "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570"
        composition_digest =
            "sha256:cba24c1ac86b4cc629723d86609af58a17e88b23c041c4e8bca5deb766704a57"
        proportional_factor = 1.0
        velocity_factor = 1.0
        yaw_error_stride_gain_per_rad = 1.0
        candidate_order = 1
    }
)
$script:Bw25yControlCompositionDigest =
    "sha256:06383da3e7d5701b1547f32193f4989cc38cabbbd49e5eef5a56c33120a62f12"
$script:Bw25yFalseClaims = @(
    "accepted",
    "walking_acceptance",
    "turning_acceptance",
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

function Get-Bw25yMapValue {
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

function Test-Bw25yNear {
    param([object]$Actual, [double]$Expected, [double]$Tolerance = 1.0e-12)
    try {
        $value = [double]$Actual
        return [double]::IsFinite($value) -and
            [math]::Abs($value - $Expected) -le $Tolerance
    } catch {
        return $false
    }
}

function Test-Bw25yFinite {
    param([object]$Value)
    try { return [double]::IsFinite([double]$Value) } catch { return $false }
}

function Test-Bw25yDiagnosticCell {
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
        if (-not (Test-Bw25yFinite (Get-Bw25yMapValue $Cell $field))) {
            return $false
        }
    }
    $initialPerturbation = Get-Bw25yMapValue $Cell "initial_perturbation" @{}
    return (
        [int](Get-Bw25yMapValue $Cell "steering_feedback_update_count" -1) -gt 0 -and
        [int](Get-Bw25yMapValue $Cell "steering_filter_application_count" -1) -gt 0 -and
        [int](Get-Bw25yMapValue $Cell "steering_saturation_count" -1) -ge 0 -and
        [int](Get-Bw25yMapValue $Cell "steering_slew_limited_count" -1) -ge 0 -and
        [double](Get-Bw25yMapValue (
            $Cell
        ) "maximum_absolute_requested_steering_fraction" 1.0) -le 0.400000000001 -and
        [double](Get-Bw25yMapValue (
            $Cell
        ) "maximum_absolute_filtered_steering_fraction" 1.0) -le 0.400000000001 -and
        $initialPerturbation -is [System.Collections.IDictionary] -and
        $initialPerturbation.Count -gt 0
    )
}

function Test-Bw25ySha256 {
    param([object]$Value)
    return [string]$Value -cmatch '^sha256:[0-9a-f]{64}$'
}

function Get-Bw25yFalseWalkingGateCount {
    param([object]$Gates)
    if ($Gates -isnot [System.Collections.IDictionary]) { return 999999 }
    if ($Gates.Count -ne $script:Bw25yWalkingGateKeys.Count) { return 999999 }
    $count = 0
    foreach ($key in $script:Bw25yWalkingGateKeys) {
        if (-not $Gates.Contains($key) -or $Gates[$key] -isnot [bool]) {
            return 999999
        }
        if (-not [bool]$Gates[$key]) { $count += 1 }
    }
    return $count
}

function Add-Bw25yGate {
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

function Get-Bw25yExpectedCells {
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($profile in $script:Bw25yProfiles) {
        foreach ($seed in $script:Bw25ySeeds) {
            foreach ($candidate in $script:Bw25yCandidates) {
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
                    yaw_error_stride_gain_per_rad =
                        [double]$candidate.yaw_error_stride_gain_per_rad
                    global_scale = 0.5
                })
            }
            if ($seed -eq 26011) {
                $cells.Add([ordered]@{
                    cell_id = "development_mu$($profile.token)_s26011_control"
                    role = "control"
                    campaign_seed = 26011
                    authored_friction = [double]$profile.authored_friction
                    controller_coefficient = [double]$profile.controller_coefficient
                    profile_id = [string]$profile.profile_id
                    profile_digest = [string]$profile.profile_digest
                    candidate_id = "BW25Y-CONTROL"
                    policy_id = [string]$script:Bw25yCandidates[0].policy_id
                    runtime_profile_sha256 =
                        [string]$script:Bw25yCandidates[0].runtime_profile_sha256
                    composition_digest = $script:Bw25yControlCompositionDigest
                    proportional_factor = 1.0
                    velocity_factor = 1.0
                    yaw_error_stride_gain_per_rad = 1.3
                    global_scale = 0.0
                })
            }
        }
    }
    $cells.Add([ordered]@{
        cell_id = "negative_mu000_s26011_safety"
        role = "safety"
        campaign_seed = 26011
        authored_friction = 0.0
        controller_coefficient = 0.0
        profile_id = "godot_jolt_p5m1r1_mu000_v1"
        profile_digest =
            "sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"
        candidate_id = "BW25Y-SAFETY"
        policy_id = "NONE"
        runtime_profile_sha256 = "NONE"
        composition_digest = "NONE"
        proportional_factor = 0.0
        velocity_factor = 0.0
        yaw_error_stride_gain_per_rad = 0.0
        global_scale = 0.0
    })
    return @($cells)
}

function ConvertTo-Bw25yFinalCellReceipt {
    <#
    .SYNOPSIS
    Composes the exact final receipt consumed by the BW25Y evaluator.

    .DESCRIPTION
    The physical worker will inherit a broad walking-diagnostic dictionary from
    the gait fixture. This single production function projects that dictionary
    to the four preregistered decision keys, derives walking_observed and the
    failed-gate count once, supplies deterministic declaration/profile fields,
    and completes the zero-friction safety role to the same common schema.

    Observed candidate/control runtime policy identity is never overwritten:
    a missing or mismatched observed policy remains visible and fails closed in
    Test-Bw25yCell. The safety role has no controller and therefore receives
    the declared NONE sentinel.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$RawCell,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Expected
    )

    $cell = $RawCell | ConvertTo-Json -Depth 64 |
        ConvertFrom-Json -AsHashtable -Depth 64
    $role = [string]$Expected.role
    $isSafety = $role -ceq "safety"

    $cell["schema_version"] =
        "sporespore_balanced_wave_bw25y_yaw_development_cell_v1"
    $cell["campaign_id"] = $script:Bw25yCampaignId
    $cell["gate_id"] = $script:Bw25yGateId
    $cell["cell_id"] = [string]$Expected.cell_id
    $cell["role"] = $role
    $cell["campaign_seed"] = [int]$Expected.campaign_seed
    $cell["authored_friction"] = [double]$Expected.authored_friction
    $cell["controller_coefficient"] = [double]$Expected.controller_coefficient
    $cell["material_profile_id"] = [string]$Expected.profile_id
    $cell["material_profile_sha256"] = [string]$Expected.profile_digest
    $cell["candidate_id"] = [string]$Expected.candidate_id
    $cell["candidate_composition_digest"] = [string]$Expected.composition_digest
    $cell["declared_controller_policy_id"] = [string]$Expected.policy_id
    $cell["proportional_factor"] = [double]$Expected.proportional_factor
    $cell["velocity_factor"] = [double]$Expected.velocity_factor
    $cell["yaw_error_stride_gain_per_rad"] =
        [double]$Expected.yaw_error_stride_gain_per_rad
    $cell["global_requested_correction_scale"] = [double]$Expected.global_scale

    if ($isSafety) {
        $cell["controller_policy_id"] = "NONE"
        $cell["controller_runtime_profile_sha256"] = "NONE"
        $cell["policy_branch_surface_count"] = 0
        $cell["material_condition_count"] = 0
        $cell["seed_condition_count"] = 0
        $cell["failure_identity_condition_count"] = 0
        $cell["outcome_condition_count"] = 0
        $cell["walking_gate_receipts"] = [ordered]@{}
        $cell["walking_observed"] = $false
        $cell["failed_production_walking_gate_count"] = 0
        return $cell
    }

    if (-not $cell.Contains("controller_policy_id")) {
        $cell["controller_policy_id"] = ""
    }
    if (-not $cell.Contains("controller_runtime_profile_sha256")) {
        $cell["controller_runtime_profile_sha256"] = ""
    }
    $rawWalking = Get-Bw25yMapValue $cell "walking_gate_receipts" @{}
    if ($rawWalking -isnot [System.Collections.IDictionary]) {
        throw "BW25Y final composer requires a walking receipt dictionary"
    }
    $projectedWalking = [ordered]@{}
    foreach ($key in $script:Bw25yWalkingGateKeys) {
        if (-not $rawWalking.Contains($key) -or $rawWalking[$key] -isnot [bool]) {
            throw "BW25Y final composer is missing decision walking key: $key"
        }
        $projectedWalking[$key] = [bool]$rawWalking[$key]
    }
    $failedWalking = Get-Bw25yFalseWalkingGateCount $projectedWalking
    if ($failedWalking -ge 999999) {
        throw "BW25Y final composer produced an invalid walking projection"
    }
    $cell["walking_gate_receipts"] = $projectedWalking
    $cell["failed_production_walking_gate_count"] = $failedWalking
    $cell["walking_observed"] = $failedWalking -eq 0
    return $cell
}

function Test-Bw25yCell {
    param(
        [Parameter(Mandatory)][object]$Cell,
        [Parameter(Mandatory)][object]$Expected
    )
    if ($Cell -isnot [System.Collections.IDictionary]) { return $false }
    $role = [string]$Expected.role
    $walkingGates = Get-Bw25yMapValue $Cell "walking_gate_receipts" @{}
    $falseWalkingGateCount = if ($role -ceq "safety") {
        0
    } else {
        Get-Bw25yFalseWalkingGateCount $walkingGates
    }
    $walkingObserved = if ($role -ceq "safety") {
        $false
    } else {
        $falseWalkingGateCount -eq 0
    }
    $common = (
        [string](Get-Bw25yMapValue $Cell "schema_version" "") -ceq
            "sporespore_balanced_wave_bw25y_yaw_development_cell_v1" -and
        [string](Get-Bw25yMapValue $Cell "campaign_id" "") -ceq
            $script:Bw25yCampaignId -and
        [string](Get-Bw25yMapValue $Cell "gate_id" "") -ceq $script:Bw25yGateId -and
        [string](Get-Bw25yMapValue $Cell "cell_id" "") -ceq
            [string]$Expected.cell_id -and
        [string](Get-Bw25yMapValue $Cell "role" "") -ceq $role -and
        [int](Get-Bw25yMapValue $Cell "campaign_seed" -1) -eq
            [int]$Expected.campaign_seed -and
        (Test-Bw25yNear (Get-Bw25yMapValue $Cell "authored_friction") (
            [double]$Expected.authored_friction
        )) -and
        (Test-Bw25yNear (Get-Bw25yMapValue $Cell "controller_coefficient") (
            [double]$Expected.controller_coefficient
        )) -and
        [string](Get-Bw25yMapValue $Cell "material_profile_id" "") -ceq
            [string]$Expected.profile_id -and
        [string](Get-Bw25yMapValue $Cell "material_profile_sha256" "") -ceq
            [string]$Expected.profile_digest -and
        [string](Get-Bw25yMapValue $Cell "candidate_id" "") -ceq
            [string]$Expected.candidate_id -and
        [string](Get-Bw25yMapValue $Cell "candidate_composition_digest" "") -ceq
            [string]$Expected.composition_digest -and
        [string](Get-Bw25yMapValue $Cell "controller_policy_id" "") -ceq
            [string]$Expected.policy_id -and
        [string](Get-Bw25yMapValue $Cell "declared_controller_policy_id" "") -ceq
            [string]$Expected.policy_id -and
        [string](Get-Bw25yMapValue $Cell "controller_runtime_profile_sha256" "") -ceq
            [string]$Expected.runtime_profile_sha256 -and
        (Test-Bw25yNear (Get-Bw25yMapValue $Cell "proportional_factor") (
            [double]$Expected.proportional_factor
        )) -and
        (Test-Bw25yNear (Get-Bw25yMapValue $Cell "velocity_factor") (
            [double]$Expected.velocity_factor
        )) -and
        (Test-Bw25yNear (Get-Bw25yMapValue $Cell "yaw_error_stride_gain_per_rad") (
            [double]$Expected.yaw_error_stride_gain_per_rad
        )) -and
        (Test-Bw25yNear (Get-Bw25yMapValue $Cell "global_requested_correction_scale") (
            [double]$Expected.global_scale
        )) -and
        [int](Get-Bw25yMapValue $Cell "world_build_count" -1) -eq 1 -and
        [int](Get-Bw25yMapValue $Cell "world_reset_count" -1) -eq 0 -and
        [string](Get-Bw25yMapValue $Cell "physics_engine" "") -ceq "Jolt Physics" -and
        [int](Get-Bw25yMapValue $Cell "physics_hz" -1) -eq 120 -and
        [int](Get-Bw25yMapValue $Cell "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw25yMapValue $Cell "solver_position_steps" -1) -eq 7 -and
        [int](Get-Bw25yMapValue $Cell "direct_body_write_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "sdk_mismatch_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "sdk_failure_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "policy_branch_surface_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "material_condition_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "seed_condition_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "failure_identity_condition_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "outcome_condition_count" -1) -eq 0 -and
        [bool](Get-Bw25yMapValue $Cell "profile_binding_exact" $false) -and
        [bool](Get-Bw25yMapValue $Cell "common_execution_integrity" $false) -and
        [bool](Get-Bw25yMapValue $Cell "outcome_complete" $false) -and
        (Get-Bw25yMapValue $Cell "walking_observed" $null) -is [bool] -and
        [bool](Get-Bw25yMapValue $Cell "walking_observed" $false) -eq $walkingObserved -and
        [int](Get-Bw25yMapValue $Cell "failed_production_walking_gate_count" -1) -eq
            $falseWalkingGateCount -and
        -not [bool](Get-Bw25yMapValue $Cell "walking_claim_authorized" $true) -and
        -not [bool](Get-Bw25yMapValue $Cell "material_acceptance_claim_authorized" $true) -and
        -not [bool](Get-Bw25yMapValue $Cell "physical_acceptance_authority" $true)
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
        if (-not (Test-Bw25ySha256 (Get-Bw25yMapValue $Cell $field ""))) {
            return $false
        }
    }
    if ($role -ceq "candidate") {
        return (
            [bool](Get-Bw25yMapValue $Cell "mechanism_gate_passed" $false) -and
            [bool](Get-Bw25yMapValue $Cell "combined_application_gate_passed" $false) -and
            [bool](Get-Bw25yMapValue $Cell "residual_application_expected" $false) -and
            [bool](Get-Bw25yMapValue $Cell "residual_application_observed" $false) -and
            [int](Get-Bw25yMapValue $Cell "sdk_effective_application_count" 0) -gt 0 -and
            [int](Get-Bw25yMapValue $Cell "sdk_native_motor_write_count" 0) -gt 0 -and
            (Test-Bw25yFinite (
                Get-Bw25yMapValue $Cell "maximum_absolute_applied_velocity_rad_s"
            )) -and
            [double](Get-Bw25yMapValue (
                $Cell
            ) "maximum_absolute_applied_velocity_rad_s" 0.0) -gt 0.0 -and
            [bool](Get-Bw25yMapValue $Cell "base_controller_application_observed" $false) -and
            [bool](Get-Bw25yMapValue $Cell "broad_base_controller_physical_influence_observed" $false) -and
            (Test-Bw25yDiagnosticCell -Cell $Cell)
        )
    }
    if ($role -ceq "control") {
        return (
            [bool](Get-Bw25yMapValue $Cell "mechanism_gate_passed" $false) -and
            -not [bool](Get-Bw25yMapValue $Cell "combined_application_gate_passed" $true) -and
            -not [bool](Get-Bw25yMapValue $Cell "residual_application_expected" $true) -and
            -not [bool](Get-Bw25yMapValue $Cell "residual_application_observed" $true) -and
            [int](Get-Bw25yMapValue $Cell "sdk_effective_application_count" -1) -eq 0 -and
            [int](Get-Bw25yMapValue $Cell "sdk_native_motor_write_count" 0) -gt 0 -and
            (Test-Bw25yNear (Get-Bw25yMapValue $Cell "maximum_absolute_applied_velocity_rad_s") 0.0) -and
            [bool](Get-Bw25yMapValue $Cell "base_controller_application_observed" $false) -and
            [bool](Get-Bw25yMapValue $Cell "broad_base_controller_physical_influence_observed" $false)
        )
    }
    return (
        -not [bool](Get-Bw25yMapValue $Cell "mechanism_gate_passed" $true) -and
        -not [bool](Get-Bw25yMapValue $Cell "combined_application_gate_passed" $true) -and
        [int](Get-Bw25yMapValue $Cell "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $Cell "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw25yMapValue $Cell "physical_influence" $true)
    )
}

function Get-Bw25yCandidateSummaries {
    param([Parameter(Mandatory)][object[]]$CandidateCells)
    $summaries = [System.Collections.Generic.List[object]]::new()
    $baselineCells = @($CandidateCells | Where-Object {
        [string](Get-Bw25yMapValue $_ "candidate_id" "") -ceq "BW25Y-A"
    })
    foreach ($candidate in $script:Bw25yCandidates) {
        $candidateId = [string]$candidate.candidate_id
        $cells = @($CandidateCells | Where-Object {
            [string](Get-Bw25yMapValue $_ "candidate_id" "") -ceq $candidateId
        })
        $walkingFailures = @($cells | Where-Object {
            -not [bool](Get-Bw25yMapValue $_ "walking_observed" $false)
        }).Count
        $failedGates = 0
        $maxCrossTrack = [double]::NegativeInfinity
        $cumulative = 0.0
        foreach ($cell in $cells) {
            $failedGates += [int](Get-Bw25yMapValue (
                $cell
            ) "failed_production_walking_gate_count" 999999)
            $maxCrossTrack = [math]::Max(
                $maxCrossTrack,
                [double](Get-Bw25yMapValue (
                    $cell
                ) "maximum_absolute_cross_track_error_m" ([double]::PositiveInfinity))
            )
            $cumulative += [double](Get-Bw25yMapValue (
                $cell
            ) "cumulative_absolute_cross_track_error_m_s" ([double]::PositiveInfinity))
        }
        $pairedRegressions = 0
        if ($candidateId -cne "BW25Y-A") {
            foreach ($cell in $cells) {
                $baseline = @($baselineCells | Where-Object {
                    [int](Get-Bw25yMapValue $_ "campaign_seed" -1) -eq
                        [int](Get-Bw25yMapValue $cell "campaign_seed" -2) -and
                    [string](Get-Bw25yMapValue $_ "material_profile_id" "") -ceq
                        [string](Get-Bw25yMapValue $cell "material_profile_id" "")
                }) | Select-Object -First 1
                if ($null -eq $baseline) {
                    $pairedRegressions += 1000
                    continue
                }
                $baselineGates = Get-Bw25yMapValue $baseline "walking_gate_receipts" @{}
                $candidateGates = Get-Bw25yMapValue $cell "walking_gate_receipts" @{}
                foreach ($key in $script:Bw25yWalkingGateKeys) {
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

function Compare-Bw25yCandidateSummary {
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

function Invoke-Bw25yYawDevelopmentEvaluation {
    param([Parameter(Mandatory)][object]$Result)
    $gates = [System.Collections.Generic.List[object]]::new()
    $cells = @((Get-Bw25yMapValue $Result "cells" @()))
    $expectedCells = @(Get-Bw25yExpectedCells)

    Add-Bw25yGate $gates 1 "receipt_identity" (
        [string](Get-Bw25yMapValue $Result "schema_version" "") -ceq
            $script:Bw25yReceiptSchema -and
        [string](Get-Bw25yMapValue $Result "campaign_id" "") -ceq
            $script:Bw25yCampaignId -and
        [string](Get-Bw25yMapValue $Result "gate_id" "") -ceq $script:Bw25yGateId -and
        [string](Get-Bw25yMapValue $Result "study_classification" "") -ceq
            "paired_outcome_unexposed_finite_controller_development_screen" -and
        [int](Get-Bw25yMapValue $Result "expected_gate_count" -1) -eq 50 -and
        [int](Get-Bw25yMapValue $Result "expected_world_count" -1) -eq 28
    ) "BW25Y_RECEIPT_IDENTITY"

    $engine = Get-Bw25yMapValue $Result "engine" @{}
    $source = Get-Bw25yMapValue $Result "source" @{}
    Add-Bw25yGate $gates 2 "host_and_source" (
        [string](Get-Bw25yMapValue $engine "physics_engine" "") -ceq "Jolt Physics" -and
        [string](Get-Bw25yMapValue $engine "godot_version" "") -ceq
            $script:Bw25yGodotVersion -and
        [string](Get-Bw25yMapValue $engine "godot_executable_sha256" "") -ceq
            $script:Bw25yGodotSha256 -and
        [int](Get-Bw25yMapValue $engine "physics_hz" -1) -eq 120 -and
        [int](Get-Bw25yMapValue $engine "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw25yMapValue $engine "solver_position_steps" -1) -eq 7 -and
        [string](Get-Bw25yMapValue $source "commit" "") -cmatch '^[0-9a-f]{40}$' -and
        [bool](Get-Bw25yMapValue $source "worktree_clean" $false) -and
        [bool](Get-Bw25yMapValue $source "matches_live_github_main" $false)
    ) "BW25Y_HOST_SOURCE"

    $prerequisites = Get-Bw25yMapValue $Result "prerequisites" @{}
    Add-Bw25yGate $gates 3 "prerequisite_evidence" (
        [string](Get-Bw25yMapValue $prerequisites "bw22l_closure_raw_sha256" "") -ceq
            "e35a93c19613a302e72800d1be9222970ef127fd0028baf8e7440e620e2929e5" -and
        [string](Get-Bw25yMapValue $prerequisites "bw24p_profile_closure_raw_sha256" "") -ceq
            "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa" -and
        [bool](Get-Bw25yMapValue $prerequisites "bw22l_infrastructure_invalid" $false) -and
        -not [bool](Get-Bw25yMapValue $prerequisites "bw22l_controller_comparison_result" $true) -and
        -not [bool](Get-Bw25yMapValue $prerequisites "bw22l_candidate_selected" $true) -and
        [bool](Get-Bw25yMapValue $prerequisites "bw24p_profiles_closed_positive" $false) -and
        [bool](Get-Bw25yMapValue $prerequisites "fresh_values_and_seeds_unopened" $false)
    ) "BW25Y_PREREQUISITES"

    $declarations = Get-Bw25yMapValue $Result "declarations" @{}
    Add-Bw25yGate $gates 4 "frozen_declarations" (
        [string](Get-Bw25yMapValue $declarations "preregistration_raw_sha256" "") -ceq
            "a102e9e40742fdded2df4c2ec806a1112cf21c2fec1165f9534da59b2153ff39" -and
        [string](Get-Bw25yMapValue $declarations "candidates_raw_sha256" "") -ceq
            "02e7b3de50e9ca108f0c8e1508c10422361b3be6d5aa3d86e1db67348e0afb50" -and
        @((Get-Bw25yMapValue $declarations "candidate_order" @())) -join ',' -ceq
            "BW25Y-A,BW25Y-B" -and
        @((Get-Bw25yMapValue $declarations "material_profile_ids" @())) -join ',' -ceq
            (@($script:Bw25yProfiles.profile_id) -join ',') -and
        @((Get-Bw25yMapValue $declarations "seeds" @())) -join ',' -ceq
            ($script:Bw25ySeeds -join ',') -and
        [string](Get-Bw25yMapValue $declarations "baseline_candidate_id" "") -ceq
            "BW25Y-A"
    ) "BW25Y_DECLARATIONS"

    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $cell = if ($index -lt $cells.Count) { $cells[$index] } else { @{} }
        Add-Bw25yGate $gates ($index + 5) (
            "cell_" + [string]$expectedCells[$index].cell_id
        ) (Test-Bw25yCell -Cell $cell -Expected $expectedCells[$index]) `
            "BW25Y_CELL_GATE"
    }

    $candidates = @($cells | Where-Object {
        [string](Get-Bw25yMapValue $_ "role" "") -ceq "candidate"
    })
    $controls = @($cells | Where-Object {
        [string](Get-Bw25yMapValue $_ "role" "") -ceq "control"
    })
    $safetyCells = @($cells | Where-Object {
        [string](Get-Bw25yMapValue $_ "role" "") -ceq "safety"
    })
    Add-Bw25yGate $gates 33 "exact_order_and_role_cardinality" (
        $cells.Count -eq 28 -and $candidates.Count -eq 24 -and
        $controls.Count -eq 3 -and $safetyCells.Count -eq 1 -and
        [int](Get-Bw25yMapValue $Result "observed_world_count" -1) -eq 28 -and
        [int](Get-Bw25yMapValue $Result "integrity_failure_count" -1) -eq 0
    ) "BW25Y_MATRIX_CARDINALITY"

    Add-Bw25yGate $gates 34 "zero_candidate_infrastructure_failures" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not [bool](Get-Bw25yMapValue $_ "common_execution_integrity" $false) -or
            -not [bool](Get-Bw25yMapValue $_ "outcome_complete" $false)
        }).Count -eq 0
    ) "BW25Y_CANDIDATE_INFRASTRUCTURE"

    Add-Bw25yGate $gates 35 "policy_relative_receipt_identity" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            [string](Get-Bw25yMapValue $_ "controller_policy_id" "") -cne
                [string](Get-Bw25yMapValue $_ "declared_controller_policy_id" "") -or
            [string](Get-Bw25yMapValue (
                Get-Bw25yMapValue $_ "policy_relative_common_execution" @{}
            ) "schema_version" "") -cne
                "sporespore_policy_relative_execution_integrity_v1" -or
            -not [bool](Get-Bw25yMapValue (
                Get-Bw25yMapValue $_ "policy_relative_common_execution" @{}
            ) "ok" $false)
        }).Count -eq 0
    ) "BW25Y_POLICY_RELATIVE_IDENTITY"

    Add-Bw25yGate $gates 36 "candidate_mechanism_and_application" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not [bool](Get-Bw25yMapValue $_ "mechanism_gate_passed" $false) -or
            -not [bool](Get-Bw25yMapValue $_ "combined_application_gate_passed" $false) -or
            [int](Get-Bw25yMapValue $_ "sdk_effective_application_count" 0) -le 0
        }).Count -eq 0
    ) "BW25Y_CANDIDATE_APPLICATION"

    Add-Bw25yGate $gates 37 "candidate_outcomes_and_metrics" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not (Test-Bw25yFinite (Get-Bw25yMapValue $_ "maximum_absolute_cross_track_error_m")) -or
            -not (Test-Bw25yFinite (Get-Bw25yMapValue $_ "cumulative_absolute_cross_track_error_m_s")) -or
            (Get-Bw25yFalseWalkingGateCount (
                Get-Bw25yMapValue $_ "walking_gate_receipts" @{}
            )) -ge 999999
        }).Count -eq 0
    ) "BW25Y_CANDIDATE_OUTCOME_METRICS"

    Add-Bw25yGate $gates 38 "candidate_profiles_gains_and_compositions" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            $row = @($script:Bw25yCandidates | Where-Object candidate_id -CEQ (
                [string](Get-Bw25yMapValue $_ "candidate_id" "")
            )) | Select-Object -First 1
            $null -eq $row -or
            [string](Get-Bw25yMapValue $_ "controller_policy_id" "") -cne
                [string]$row.policy_id -or
            [string](Get-Bw25yMapValue $_ "controller_runtime_profile_sha256" "") -cne
                [string]$row.runtime_profile_sha256 -or
            [string](Get-Bw25yMapValue $_ "candidate_composition_digest" "") -cne
                [string]$row.composition_digest -or
            -not (Test-Bw25yNear (
                Get-Bw25yMapValue $_ "proportional_factor"
            ) ([double]$row.proportional_factor)) -or
            -not (Test-Bw25yNear (
                Get-Bw25yMapValue $_ "velocity_factor"
            ) ([double]$row.velocity_factor)) -or
            -not (Test-Bw25yNear (
                Get-Bw25yMapValue $_ "yaw_error_stride_gain_per_rad"
            ) ([double]$row.yaw_error_stride_gain_per_rad))
        }).Count -eq 0
    ) "BW25Y_CANDIDATE_PROFILE"

    Add-Bw25yGate $gates 39 "corrected_zero_residual_controls" (
        $controls.Count -eq 3 -and @($controls | Where-Object {
            -not [bool](Get-Bw25yMapValue $_ "common_execution_integrity" $false) -or
            [bool](Get-Bw25yMapValue $_ "combined_application_gate_passed" $true) -or
            [int](Get-Bw25yMapValue $_ "sdk_effective_application_count" -1) -ne 0
        }).Count -eq 0
    ) "BW25Y_CONTROL_RESIDUAL_SEMANTICS"

    Add-Bw25yGate $gates 40 "active_base_controller_controls" (
        $controls.Count -eq 3 -and @($controls | Where-Object {
            -not [bool](Get-Bw25yMapValue $_ "base_controller_application_observed" $false) -or
            -not [bool](Get-Bw25yMapValue $_ "broad_base_controller_physical_influence_observed" $false)
        }).Count -eq 0
    ) "BW25Y_CONTROL_BASE_INFLUENCE"

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
    foreach ($profile in $script:Bw25yProfiles) {
        foreach ($seed in $script:Bw25ySeeds) {
            $group = @($candidates | Where-Object {
                [string](Get-Bw25yMapValue $_ "material_profile_id" "") -ceq
                    [string]$profile.profile_id -and
                [int](Get-Bw25yMapValue $_ "campaign_seed" -1) -eq $seed
            })
            if ($seed -eq 26011) {
                $group += @($controls | Where-Object {
                    [string](Get-Bw25yMapValue $_ "material_profile_id" "") -ceq
                        [string]$profile.profile_id
                })
            }
            $pairIdentityPassed = $pairIdentityPassed -and $group.Count -eq (
                $(if ($seed -eq 26011) { 3 } else { 2 })
            )
            if ($group.Count -gt 0) {
                foreach ($field in $pairFields) {
                    $values = @($group | ForEach-Object {
                        [string](Get-Bw25yMapValue $_ $field "")
                    } | Select-Object -Unique)
                    $pairIdentityPassed = $pairIdentityPassed -and $values.Count -eq 1
                }
                $perturbations = @($group | ForEach-Object {
                    $perturbation = Get-Bw25yMapValue $_ "initial_perturbation" @{}
                    $perturbation | ConvertTo-Json -Compress -Depth 20
                } | Select-Object -Unique)
                $perturbationPassed = $perturbationPassed -and $perturbations.Count -eq 1
            }
        }
    }
    Add-Bw25yGate $gates 41 "paired_configuration_identity" $pairIdentityPassed `
        "BW25Y_PAIR_IDENTITY"
    Add-Bw25yGate $gates 42 "paired_initial_perturbations" $perturbationPassed `
        "BW25Y_PAIRED_PERTURBATION"

    $safety = if ($safetyCells.Count -eq 1) { $safetyCells[0] } else { @{} }
    Add-Bw25yGate $gates 43 "zero_friction_safety" (
        $safetyCells.Count -eq 1 -and
        [int](Get-Bw25yMapValue $safety "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw25yMapValue $safety "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw25yMapValue $safety "physical_influence" $true)
    ) "BW25Y_ZERO_SAFETY"

    Add-Bw25yGate $gates 44 "steering_diagnostics" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not (Test-Bw25yDiagnosticCell -Cell $_)
        }).Count -eq 0
    ) "BW25Y_STEERING_DIAGNOSTICS"

    $candidateCompletionPassed = (
        $candidates.Count -eq 24 -and @($script:Bw25yCandidates | Where-Object {
            $id = [string]$_.candidate_id
            @($candidates | Where-Object {
                [string](Get-Bw25yMapValue $_ "candidate_id" "") -ceq $id
            }).Count -ne 12
        }).Count -eq 0
    )
    Add-Bw25yGate $gates 45 "all_candidates_complete_before_selection" `
        $candidateCompletionPassed "BW25Y_CANDIDATE_COMPLETION"

    $selector = Get-Bw25yMapValue $Result "selector" @{}
    Add-Bw25yGate $gates 46 "frozen_selector" (
        [string](Get-Bw25yMapValue $selector "selection_mode" "") -ceq
            "complete_preregistered_paired_lexicographic_development_selection" -and
        [string](Get-Bw25yMapValue $selector "baseline_candidate_id" "") -ceq
            "BW25Y-A" -and
        @((Get-Bw25yMapValue $selector "selection_vector" @())) -join ',' -ceq
            "walking_conjunction_failure_count,aggregate_failed_production_walking_gate_count,maximum_absolute_cross_track_error_m,aggregate_cumulative_absolute_cross_track_error_m_s,candidate_order" -and
        [bool](Get-Bw25yMapValue $selector "strict_improvement_required" $false) -and
        [int](Get-Bw25yMapValue $selector "maximum_paired_walking_gate_regressions" -1) -eq 0
    ) "BW25Y_SELECTOR_DECLARATION"

    $summaries = @(Get-Bw25yCandidateSummaries -CandidateCells $candidates)
    $baseline = @($summaries | Where-Object candidate_id -CEQ "BW25Y-A") |
        Select-Object -First 1
    $successor = @($summaries | Where-Object candidate_id -CEQ "BW25Y-B") |
        Select-Object -First 1
    $comparison = if ($null -ne $successor -and $null -ne $baseline) {
        Compare-Bw25yCandidateSummary -Left $successor -Right $baseline
    } else { 0 }
    $strictlyBetter = $comparison -lt 0
    $pairedRegressionCount = if ($null -ne $successor) {
        [int]$successor.paired_walking_gate_regression_count
    } else { 999999 }
    $selectedCandidateId = if (
        $candidateCompletionPassed -and $strictlyBetter -and
        $pairedRegressionCount -eq 0
    ) { "BW25Y-B" } else { "NONE" }
    Add-Bw25yGate $gates 47 "strict_selection_integrity" (
        $candidateCompletionPassed -and $summaries.Count -eq 2 -and
        $selectedCandidateId -in @("BW25Y-B", "NONE") -and
        ($selectedCandidateId -cne "BW25Y-B" -or (
            $strictlyBetter -and $pairedRegressionCount -eq 0
        ))
    ) "BW25Y_SELECTION_INTEGRITY"

    Add-Bw25yGate $gates 48 "zero_outcome_conditioning" (
        @(@($candidates) + @($controls) | Where-Object {
            [int](Get-Bw25yMapValue $_ "policy_branch_surface_count" -1) -ne 0 -or
            [int](Get-Bw25yMapValue $_ "material_condition_count" -1) -ne 0 -or
            [int](Get-Bw25yMapValue $_ "seed_condition_count" -1) -ne 0 -or
            [int](Get-Bw25yMapValue $_ "failure_identity_condition_count" -1) -ne 0 -or
            [int](Get-Bw25yMapValue $_ "outcome_condition_count" -1) -ne 0
        }).Count -eq 0
    ) "BW25Y_OUTCOME_CONDITIONING"

    $claims = Get-Bw25yMapValue $Result "declared_claims" @{}
    $claimsPassed = $claims -is [System.Collections.IDictionary]
    foreach ($claimName in $script:Bw25yFalseClaims) {
        $claimsPassed = $claimsPassed -and
            -not [bool](Get-Bw25yMapValue $claims $claimName $true)
    }
    Add-Bw25yGate $gates 49 "claim_boundary" $claimsPassed `
        "BW25Y_CLAIM_INFLATION"

    Add-Bw25yGate $gates 50 "selector_not_preinvoked" (
        [int](Get-Bw25yMapValue $Result "selector_invocation_count_before_evaluation" -1) -eq 0 -and
        [string](Get-Bw25yMapValue $Result "pre_evaluation_selected_candidate_id" "") -ceq
            "NONE"
    ) "BW25Y_SELECTOR_PREINVOCATION"

    $failureCodes = @($gates | Where-Object { -not [bool]$_.passed } |
        ForEach-Object { [string]$_.failure_code } | Select-Object -Unique)
    $ok = $gates.Count -eq 50 -and $failureCodes.Count -eq 0
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw25y_yaw_development_evaluation_v1"
        ok = $ok
        campaign_id = $script:Bw25yCampaignId
        gate_id = $script:Bw25yGateId
        reconstructed_passed_gate_count = @($gates | Where-Object passed).Count
        reconstructed_failed_gate_count = @($gates | Where-Object {
            -not $_.passed
        }).Count
        expected_gate_count = 50
        expected_world_count = 28
        observed_world_count = [int](Get-Bw25yMapValue $Result "observed_world_count" -1)
        candidate_count = $candidates.Count
        control_count = $controls.Count
        safety_count = $safetyCells.Count
        candidate_summaries = $summaries
        selected_candidate_id = $selectedCandidateId
        selected_candidate_strictly_better_than_baseline = $strictlyBetter
        selected_candidate_paired_regression_count = $pairedRegressionCount
        development_selection_authority = ($ok -and $selectedCandidateId -ceq "BW25Y-B")
        independent_validation_authority = $false
        gates = @($gates)
        failure_codes = $failureCodes
        claims_if_valid = [ordered]@{
            complete_finite_development_result = $ok
            development_candidate_selected = ($ok -and $selectedCandidateId -ceq "BW25Y-B")
            walking_acceptance = $false
            turning_acceptance = $false
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

function New-Bw25yPerfectSyntheticYawDevelopmentResult {
    $expectedCells = @(Get-Bw25yExpectedCells)
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($expected in $expectedCells) {
        $role = [string]$expected.role
        $isCandidate = $role -ceq "candidate"
        $isControl = $role -ceq "control"
        $isSafety = $role -ceq "safety"
        $profileIndex = [math]::Max(0, @($script:Bw25yProfiles.profile_id).IndexOf(
            [string]$expected.profile_id
        ))
        $seedIndex = [math]::Max(0, $script:Bw25ySeeds.IndexOf(
            [int]$expected.campaign_seed
        ))
        $pairNumber = 1 + ($profileIndex * 4) + $seedIndex
        $pairToken = $pairNumber.ToString("x").PadLeft(64, "0")
        $candidateIndex = @($script:Bw25yCandidates.candidate_id).IndexOf(
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
        if ($isCandidate -and [string]$expected.candidate_id -ceq "BW25Y-A") {
            $walkingGates.bounded_lateral_drift = $false
        }
        $failedWalking = if ($isSafety) {
            0
        } else { Get-Bw25yFalseWalkingGateCount $walkingGates }
        $isSuccessor = $isCandidate -and
            [string]$expected.candidate_id -ceq "BW25Y-B"
        $cell = [ordered]@{
            schema_version =
                "sporespore_balanced_wave_bw25y_yaw_development_cell_v1"
            campaign_id = $script:Bw25yCampaignId
            gate_id = $script:Bw25yGateId
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
            yaw_error_stride_gain_per_rad =
                [double]$expected.yaw_error_stride_gain_per_rad
            stability_policy_id = $(if ($isSafety) {
                "NONE"
            } else { $script:Bw25yStabilityPolicyId })
            authority_scope = $(if ($isSafety) { "none" } else { "post_settle_full" })
            execution_mode = $(if ($isSafety) {
                "shadow_only_no_sdk_native_actuation"
            } else { $script:Bw25yExecutionMode })
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
    foreach ($claimName in $script:Bw25yFalseClaims) { $claims[$claimName] = $false }
    return [ordered]@{
        schema_version = $script:Bw25yReceiptSchema
        campaign_id = $script:Bw25yCampaignId
        gate_id = $script:Bw25yGateId
        study_classification =
            "paired_outcome_unexposed_finite_controller_development_screen"
        expected_gate_count = 50
        expected_world_count = 28
        observed_world_count = 28
        integrity_failure_count = 0
        engine = [ordered]@{
            physics_engine = "Jolt Physics"
            godot_version = $script:Bw25yGodotVersion
            godot_executable_sha256 = $script:Bw25yGodotSha256
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
            bw22l_closure_raw_sha256 =
                "e35a93c19613a302e72800d1be9222970ef127fd0028baf8e7440e620e2929e5"
            bw24p_profile_closure_raw_sha256 =
                "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa"
            bw22l_infrastructure_invalid = $true
            bw22l_controller_comparison_result = $false
            bw22l_candidate_selected = $false
            bw24p_profiles_closed_positive = $true
            fresh_values_and_seeds_unopened = $true
        }
        declarations = [ordered]@{
            preregistration_raw_sha256 =
                "a102e9e40742fdded2df4c2ec806a1112cf21c2fec1165f9534da59b2153ff39"
            candidates_raw_sha256 =
                "02e7b3de50e9ca108f0c8e1508c10422361b3be6d5aa3d86e1db67348e0afb50"
            candidate_order = @("BW25Y-A", "BW25Y-B")
            material_profile_ids = @($script:Bw25yProfiles.profile_id)
            seeds = $script:Bw25ySeeds
            baseline_candidate_id = "BW25Y-A"
        }
        selector = [ordered]@{
            selection_mode =
                "complete_preregistered_paired_lexicographic_development_selection"
            baseline_candidate_id = "BW25Y-A"
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
