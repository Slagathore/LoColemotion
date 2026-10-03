#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw28yCampaignId = "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
$script:Bw28yGateId = "BW28Y"
$script:Bw28yReceiptSchema =
    "sporespore_balanced_wave_bw28y_yaw_development_result_v1"
$script:Bw28yGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:Bw28yGodotSha256 =
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
$script:Bw28yStabilityPolicyId =
    "sporespore_scheduled_load_transfer_bw13p_a_v3"
$script:Bw28yExecutionMode =
    "native_balanced_wave_base_with_stability_contribution"
$script:Bw28yWalkingGateKeys = @(
    "bounded_lateral_drift",
    "bounded_tilt",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation"
)
$script:Bw28yProfiles = @(
    [ordered]@{
        token = "062"
        authored_friction = 0.62
        controller_coefficient = 0.61
        profile_id = "godot_jolt_bw27m_mu062_v1"
        profile_digest =
            "sha256:62bd8b2543c7c3cdb9b389029e5ae3de777cbcc29c5a5ba5b769863442c854c3"
    },
    [ordered]@{
        token = "074"
        authored_friction = 0.74
        controller_coefficient = 0.73
        profile_id = "godot_jolt_bw27m_mu074_v1"
        profile_digest =
            "sha256:6a8128171b87ad824b3675cbf731927681b55c0f529d179e3dbb32c842752857"
    },
    [ordered]@{
        token = "086"
        authored_friction = 0.86
        controller_coefficient = 0.84
        profile_id = "godot_jolt_bw27m_mu086_v1"
        profile_digest =
            "sha256:29735973a8334064f1a1a1fb8c8d679c335e68b4a97a396c550f68b76321863d"
    }
)
$script:Bw28ySeeds = @(27011, 27012, 27013, 27014)
$script:Bw28yCandidates = @(
    [ordered]@{
        candidate_id = "BW28Y-A"
        policy_id = "sporespore_balanced_wave_bw15f_b_v1"
        runtime_profile_sha256 =
            "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"
        composition_digest =
            "sha256:62c9ace116b4c7eae8bfe2253d2eb929673e3ee92a51f53ae7508fc6463f0547"
        proportional_factor = 1.0
        velocity_factor = 1.0
        yaw_error_stride_gain_per_rad = 1.3
        candidate_order = 0
    },
    [ordered]@{
        candidate_id = "BW28Y-B"
        policy_id = "sporespore_balanced_wave_bw23y_b_v1"
        runtime_profile_sha256 =
            "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570"
        composition_digest =
            "sha256:2dc42e65615e7472cdcc50f77b4d9d200aeb06be93c3db271f882be0a062b333"
        proportional_factor = 1.0
        velocity_factor = 1.0
        yaw_error_stride_gain_per_rad = 1.0
        candidate_order = 1
    }
)
$script:Bw28yControlCompositionDigest =
    "sha256:1cab3e88229ab79779fcf10b7d2b0bfa354a8cd6c05efe924d4cfcaee1602a02"
$script:Bw28yFalseClaims = @(
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

function Get-Bw28yMapValue {
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

function Test-Bw28yNear {
    param([object]$Actual, [double]$Expected, [double]$Tolerance = 1.0e-12)
    try {
        $value = [double]$Actual
        return [double]::IsFinite($value) -and
            [math]::Abs($value - $Expected) -le $Tolerance
    } catch {
        return $false
    }
}

function Test-Bw28yFinite {
    param([object]$Value)
    try { return [double]::IsFinite([double]$Value) } catch { return $false }
}

function Test-Bw28yDiagnosticCell {
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
        if (-not (Test-Bw28yFinite (Get-Bw28yMapValue $Cell $field))) {
            return $false
        }
    }
    $initialPerturbation = Get-Bw28yMapValue $Cell "initial_perturbation" @{}
    return (
        [int](Get-Bw28yMapValue $Cell "steering_feedback_update_count" -1) -gt 0 -and
        [int](Get-Bw28yMapValue $Cell "steering_filter_application_count" -1) -gt 0 -and
        [int](Get-Bw28yMapValue $Cell "steering_saturation_count" -1) -ge 0 -and
        [int](Get-Bw28yMapValue $Cell "steering_slew_limited_count" -1) -ge 0 -and
        [double](Get-Bw28yMapValue (
            $Cell
        ) "maximum_absolute_requested_steering_fraction" 1.0) -le 0.400000000001 -and
        [double](Get-Bw28yMapValue (
            $Cell
        ) "maximum_absolute_filtered_steering_fraction" 1.0) -le 0.400000000001 -and
        $initialPerturbation -is [System.Collections.IDictionary] -and
        $initialPerturbation.Count -gt 0
    )
}

function Test-Bw28ySha256 {
    param([object]$Value)
    return [string]$Value -cmatch '^sha256:[0-9a-f]{64}$'
}

function Test-Bw28yRawWorkerReceipt {
    <#
    .SYNOPSIS
    Determines whether a worker process produced one structurally complete raw
    receipt that is safe to pass to the sole production final composer.

    .DESCRIPTION
    Process success and scientific outcome are intentionally separate. A
    complete walking-negative receipt is accepted here, while a script error,
    nonzero process exit, missing route field, identity mismatch, or worker
    assertion of physical authority makes the receipt incomplete and eligible
    only for the preregistered infrastructure replacement policy.
    #>
    param(
        [Parameter(Mandatory)][object]$RawCell,
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][int]$ProcessExitCode,
        [AllowEmptyString()][string]$ProcessOutput = ""
    )
    if ($RawCell -isnot [System.Collections.IDictionary] -or
        $Expected -isnot [System.Collections.IDictionary]) {
        return $false
    }
    if ($ProcessExitCode -ne 0 -or
        [regex]::IsMatch($ProcessOutput, '(?im)^\s*(?:ERROR:|SCRIPT ERROR:)')) {
        return $false
    }
    return (
        [string](Get-Bw28yMapValue $RawCell "schema_version" "") -ceq
            "sporespore_balanced_wave_bw28y_yaw_development_raw_cell_v1" -and
        [string](Get-Bw28yMapValue $RawCell "campaign_id" "") -ceq
            $script:Bw28yCampaignId -and
        [string](Get-Bw28yMapValue $RawCell "gate_id" "") -ceq
            $script:Bw28yGateId -and
        [string](Get-Bw28yMapValue $RawCell "cell_id" "") -ceq
            [string]$Expected.cell_id -and
        [string](Get-Bw28yMapValue $RawCell "cohort" "") -ceq
            [string]$Expected.cohort -and
        [string](Get-Bw28yMapValue $RawCell "role" "") -ceq
            [string]$Expected.role -and
        [int](Get-Bw28yMapValue $RawCell "campaign_seed" -1) -eq
            [int]$Expected.campaign_seed -and
        [string](Get-Bw28yMapValue $RawCell "receipt_route_schema" "") -ceq
            "sporespore_actual_worker_receipt_route_v1" -and
        [bool](Get-Bw28yMapValue $RawCell "raw_receipt_complete" $false) -and
        @((Get-Bw28yMapValue $RawCell "receipt_route_failure_codes" @())).Count -eq 0 -and
        -not [string]::IsNullOrWhiteSpace([string](
            Get-Bw28yMapValue $RawCell "campaign_attempt_id" ""
        )) -and
        -not [string]::IsNullOrWhiteSpace([string](
            Get-Bw28yMapValue $RawCell "world_attempt_id" ""
        )) -and
        -not [bool](Get-Bw28yMapValue (
            $RawCell
        ) "walking_result_controls_process_exit" $true) -and
        -not [bool](Get-Bw28yMapValue $RawCell "physical_acceptance_authority" $true)
    )
}

function Get-Bw28yFalseWalkingGateCount {
    param([object]$Gates)
    if ($Gates -isnot [System.Collections.IDictionary]) { return 999999 }
    if ($Gates.Count -ne $script:Bw28yWalkingGateKeys.Count) { return 999999 }
    $count = 0
    foreach ($key in $script:Bw28yWalkingGateKeys) {
        if (-not $Gates.Contains($key) -or $Gates[$key] -isnot [bool]) {
            return 999999
        }
        if (-not [bool]$Gates[$key]) { $count += 1 }
    }
    return $count
}

function Add-Bw28yGate {
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

function Get-Bw28yExpectedCells {
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($profile in $script:Bw28yProfiles) {
        foreach ($seed in $script:Bw28ySeeds) {
            foreach ($candidate in $script:Bw28yCandidates) {
                $candidateToken = ([string]$candidate.candidate_id).ToLowerInvariant().Replace(
                    "-", "_"
                )
                $cells.Add([ordered]@{
                    cell_id = "development_mu$($profile.token)_s${seed}_${candidateToken}"
                    cohort = "paired_yaw_development"
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
            if ($seed -eq 27011) {
                $cells.Add([ordered]@{
                    cell_id = "development_mu$($profile.token)_s27011_control"
                    cohort = "material_matched_zero_residual_control"
                    role = "control"
                    campaign_seed = 27011
                    authored_friction = [double]$profile.authored_friction
                    controller_coefficient = [double]$profile.controller_coefficient
                    profile_id = [string]$profile.profile_id
                    profile_digest = [string]$profile.profile_digest
                    candidate_id = "BW28Y-CONTROL"
                    policy_id = [string]$script:Bw28yCandidates[0].policy_id
                    runtime_profile_sha256 =
                        [string]$script:Bw28yCandidates[0].runtime_profile_sha256
                    composition_digest = $script:Bw28yControlCompositionDigest
                    proportional_factor = 1.0
                    velocity_factor = 1.0
                    yaw_error_stride_gain_per_rad = 1.3
                    global_scale = 0.0
                })
            }
        }
    }
    $cells.Add([ordered]@{
        cell_id = "negative_mu000_s27011_safety"
        cohort = "zero_friction_safety"
        role = "safety"
        campaign_seed = 27011
        authored_friction = 0.0
        controller_coefficient = 0.0
        profile_id = "godot_jolt_p5m1r1_mu000_v1"
        profile_digest =
            "sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"
        candidate_id = "BW28Y-SAFETY"
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

function ConvertTo-Bw28yFinalCellReceipt {
    <#
    .SYNOPSIS
    Composes the exact final receipt consumed by the BW28Y evaluator.

    .DESCRIPTION
    The physical worker will inherit a broad walking-diagnostic dictionary from
    the gait fixture. This single production function projects that dictionary
    to the four preregistered decision keys, derives walking_observed and the
    failed-gate count once, supplies deterministic declaration/profile fields,
    and completes the zero-friction safety role to the same common schema.

    Observed candidate/control runtime policy identity is never overwritten:
    a missing or mismatched observed policy remains visible and fails closed in
    Test-Bw28yCell. The safety role has no controller and therefore receives
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
        "sporespore_balanced_wave_bw28y_yaw_development_cell_v1"
    $cell["campaign_id"] = $script:Bw28yCampaignId
    $cell["gate_id"] = $script:Bw28yGateId
    $cell["cell_id"] = [string]$Expected.cell_id
    $cell["cohort"] = [string]$Expected.cohort
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
    $rawWalking = Get-Bw28yMapValue $cell "walking_gate_receipts" @{}
    if ($rawWalking -isnot [System.Collections.IDictionary]) {
        throw "BW28Y final composer requires a walking receipt dictionary"
    }
    $projectedWalking = [ordered]@{}
    foreach ($key in $script:Bw28yWalkingGateKeys) {
        if (-not $rawWalking.Contains($key) -or $rawWalking[$key] -isnot [bool]) {
            throw "BW28Y final composer is missing decision walking key: $key"
        }
        $projectedWalking[$key] = [bool]$rawWalking[$key]
    }
    $failedWalking = Get-Bw28yFalseWalkingGateCount $projectedWalking
    if ($failedWalking -ge 999999) {
        throw "BW28Y final composer produced an invalid walking projection"
    }
    $cell["walking_gate_receipts"] = $projectedWalking
    $cell["failed_production_walking_gate_count"] = $failedWalking
    $cell["walking_observed"] = $failedWalking -eq 0
    return $cell
}

function Test-Bw28yCell {
    param(
        [Parameter(Mandatory)][object]$Cell,
        [Parameter(Mandatory)][object]$Expected
    )
    if ($Cell -isnot [System.Collections.IDictionary]) { return $false }
    $role = [string]$Expected.role
    $walkingGates = Get-Bw28yMapValue $Cell "walking_gate_receipts" @{}
    $falseWalkingGateCount = if ($role -ceq "safety") {
        0
    } else {
        Get-Bw28yFalseWalkingGateCount $walkingGates
    }
    $walkingObserved = if ($role -ceq "safety") {
        $false
    } else {
        $falseWalkingGateCount -eq 0
    }
    $common = (
        [string](Get-Bw28yMapValue $Cell "schema_version" "") -ceq
            "sporespore_balanced_wave_bw28y_yaw_development_cell_v1" -and
        [string](Get-Bw28yMapValue $Cell "campaign_id" "") -ceq
            $script:Bw28yCampaignId -and
        [string](Get-Bw28yMapValue $Cell "gate_id" "") -ceq $script:Bw28yGateId -and
        [string](Get-Bw28yMapValue $Cell "cell_id" "") -ceq
            [string]$Expected.cell_id -and
        [string](Get-Bw28yMapValue $Cell "cohort" "") -ceq
            [string]$Expected.cohort -and
        [string](Get-Bw28yMapValue $Cell "role" "") -ceq $role -and
        [int](Get-Bw28yMapValue $Cell "campaign_seed" -1) -eq
            [int]$Expected.campaign_seed -and
        (Test-Bw28yNear (Get-Bw28yMapValue $Cell "authored_friction") (
            [double]$Expected.authored_friction
        )) -and
        (Test-Bw28yNear (Get-Bw28yMapValue $Cell "controller_coefficient") (
            [double]$Expected.controller_coefficient
        )) -and
        [string](Get-Bw28yMapValue $Cell "material_profile_id" "") -ceq
            [string]$Expected.profile_id -and
        [string](Get-Bw28yMapValue $Cell "material_profile_sha256" "") -ceq
            [string]$Expected.profile_digest -and
        [string](Get-Bw28yMapValue $Cell "candidate_id" "") -ceq
            [string]$Expected.candidate_id -and
        [string](Get-Bw28yMapValue $Cell "candidate_composition_digest" "") -ceq
            [string]$Expected.composition_digest -and
        [string](Get-Bw28yMapValue $Cell "controller_policy_id" "") -ceq
            [string]$Expected.policy_id -and
        [string](Get-Bw28yMapValue $Cell "declared_controller_policy_id" "") -ceq
            [string]$Expected.policy_id -and
        [string](Get-Bw28yMapValue $Cell "controller_runtime_profile_sha256" "") -ceq
            [string]$Expected.runtime_profile_sha256 -and
        (Test-Bw28yNear (Get-Bw28yMapValue $Cell "proportional_factor") (
            [double]$Expected.proportional_factor
        )) -and
        (Test-Bw28yNear (Get-Bw28yMapValue $Cell "velocity_factor") (
            [double]$Expected.velocity_factor
        )) -and
        (Test-Bw28yNear (Get-Bw28yMapValue $Cell "yaw_error_stride_gain_per_rad") (
            [double]$Expected.yaw_error_stride_gain_per_rad
        )) -and
        (Test-Bw28yNear (Get-Bw28yMapValue $Cell "global_requested_correction_scale") (
            [double]$Expected.global_scale
        )) -and
        [int](Get-Bw28yMapValue $Cell "world_build_count" -1) -eq 1 -and
        [int](Get-Bw28yMapValue $Cell "world_reset_count" -1) -eq 0 -and
        [string](Get-Bw28yMapValue $Cell "physics_engine" "") -ceq "Jolt Physics" -and
        [int](Get-Bw28yMapValue $Cell "physics_hz" -1) -eq 120 -and
        [int](Get-Bw28yMapValue $Cell "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw28yMapValue $Cell "solver_position_steps" -1) -eq 7 -and
        [int](Get-Bw28yMapValue $Cell "direct_body_write_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "sdk_mismatch_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "sdk_failure_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "policy_branch_surface_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "material_condition_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "seed_condition_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "failure_identity_condition_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "outcome_condition_count" -1) -eq 0 -and
        [string](Get-Bw28yMapValue $Cell "receipt_route_schema" "") -ceq
            "sporespore_actual_worker_receipt_route_v1" -and
        [bool](Get-Bw28yMapValue $Cell "raw_receipt_complete" $false) -and
        @((Get-Bw28yMapValue $Cell "receipt_route_failure_codes" @())).Count -eq 0 -and
        -not [bool](Get-Bw28yMapValue $Cell "walking_result_controls_process_exit" $true) -and
        [bool](Get-Bw28yMapValue $Cell "profile_binding_exact" $false) -and
        [bool](Get-Bw28yMapValue $Cell "common_execution_integrity" $false) -and
        [bool](Get-Bw28yMapValue $Cell "outcome_complete" $false) -and
        (Get-Bw28yMapValue $Cell "walking_observed" $null) -is [bool] -and
        [bool](Get-Bw28yMapValue $Cell "walking_observed" $false) -eq $walkingObserved -and
        [int](Get-Bw28yMapValue $Cell "failed_production_walking_gate_count" -1) -eq
            $falseWalkingGateCount -and
        -not [bool](Get-Bw28yMapValue $Cell "walking_claim_authorized" $true) -and
        -not [bool](Get-Bw28yMapValue $Cell "material_acceptance_claim_authorized" $true) -and
        -not [bool](Get-Bw28yMapValue $Cell "physical_acceptance_authority" $true)
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
        if (-not (Test-Bw28ySha256 (Get-Bw28yMapValue $Cell $field ""))) {
            return $false
        }
    }
    if ($role -ceq "candidate") {
        return (
            [bool](Get-Bw28yMapValue $Cell "mechanism_gate_passed" $false) -and
            [bool](Get-Bw28yMapValue $Cell "combined_application_gate_passed" $false) -and
            [bool](Get-Bw28yMapValue $Cell "residual_application_expected" $false) -and
            [bool](Get-Bw28yMapValue $Cell "residual_application_observed" $false) -and
            [int](Get-Bw28yMapValue $Cell "sdk_effective_application_count" 0) -gt 0 -and
            [int](Get-Bw28yMapValue $Cell "sdk_native_motor_write_count" 0) -gt 0 -and
            (Test-Bw28yFinite (
                Get-Bw28yMapValue $Cell "maximum_absolute_applied_velocity_rad_s"
            )) -and
            [double](Get-Bw28yMapValue (
                $Cell
            ) "maximum_absolute_applied_velocity_rad_s" 0.0) -gt 0.0 -and
            [bool](Get-Bw28yMapValue $Cell "base_controller_application_observed" $false) -and
            [bool](Get-Bw28yMapValue $Cell "broad_base_controller_physical_influence_observed" $false) -and
            (Test-Bw28yDiagnosticCell -Cell $Cell)
        )
    }
    if ($role -ceq "control") {
        return (
            [bool](Get-Bw28yMapValue $Cell "mechanism_gate_passed" $false) -and
            -not [bool](Get-Bw28yMapValue $Cell "combined_application_gate_passed" $true) -and
            -not [bool](Get-Bw28yMapValue $Cell "residual_application_expected" $true) -and
            -not [bool](Get-Bw28yMapValue $Cell "residual_application_observed" $true) -and
            [int](Get-Bw28yMapValue $Cell "sdk_effective_application_count" -1) -eq 0 -and
            [int](Get-Bw28yMapValue $Cell "sdk_native_motor_write_count" 0) -gt 0 -and
            (Test-Bw28yNear (Get-Bw28yMapValue $Cell "maximum_absolute_applied_velocity_rad_s") 0.0) -and
            [bool](Get-Bw28yMapValue $Cell "base_controller_application_observed" $false) -and
            [bool](Get-Bw28yMapValue $Cell "broad_base_controller_physical_influence_observed" $false)
        )
    }
    return (
        -not [bool](Get-Bw28yMapValue $Cell "mechanism_gate_passed" $true) -and
        -not [bool](Get-Bw28yMapValue $Cell "combined_application_gate_passed" $true) -and
        [int](Get-Bw28yMapValue $Cell "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $Cell "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw28yMapValue $Cell "physical_influence" $true)
    )
}

function Get-Bw28yCandidateSummaries {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()]
        [object[]]$CandidateCells
    )
    $summaries = [System.Collections.Generic.List[object]]::new()
    $baselineCells = @($CandidateCells | Where-Object {
        [string](Get-Bw28yMapValue $_ "candidate_id" "") -ceq "BW28Y-A"
    })
    foreach ($candidate in $script:Bw28yCandidates) {
        $candidateId = [string]$candidate.candidate_id
        $cells = @($CandidateCells | Where-Object {
            [string](Get-Bw28yMapValue $_ "candidate_id" "") -ceq $candidateId
        })
        $walkingFailures = @($cells | Where-Object {
            -not [bool](Get-Bw28yMapValue $_ "walking_observed" $false)
        }).Count
        $failedGates = 0
        $maxCrossTrack = [double]::NegativeInfinity
        $cumulative = 0.0
        foreach ($cell in $cells) {
            $failedGates += [int](Get-Bw28yMapValue (
                $cell
            ) "failed_production_walking_gate_count" 999999)
            $maxCrossTrack = [math]::Max(
                $maxCrossTrack,
                [double](Get-Bw28yMapValue (
                    $cell
                ) "maximum_absolute_cross_track_error_m" ([double]::PositiveInfinity))
            )
            $cumulative += [double](Get-Bw28yMapValue (
                $cell
            ) "cumulative_absolute_cross_track_error_m_s" ([double]::PositiveInfinity))
        }
        $pairedRegressions = 0
        if ($candidateId -cne "BW28Y-A") {
            foreach ($cell in $cells) {
                $baseline = @($baselineCells | Where-Object {
                    [int](Get-Bw28yMapValue $_ "campaign_seed" -1) -eq
                        [int](Get-Bw28yMapValue $cell "campaign_seed" -2) -and
                    [string](Get-Bw28yMapValue $_ "material_profile_id" "") -ceq
                        [string](Get-Bw28yMapValue $cell "material_profile_id" "")
                }) | Select-Object -First 1
                if ($null -eq $baseline) {
                    $pairedRegressions += 1000
                    continue
                }
                $baselineGates = Get-Bw28yMapValue $baseline "walking_gate_receipts" @{}
                $candidateGates = Get-Bw28yMapValue $cell "walking_gate_receipts" @{}
                foreach ($key in $script:Bw28yWalkingGateKeys) {
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

function Compare-Bw28yCandidateSummary {
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

function Invoke-Bw28yYawDevelopmentEvaluation {
    param([Parameter(Mandatory)][object]$Result)
    $gates = [System.Collections.Generic.List[object]]::new()
    $cells = @((Get-Bw28yMapValue $Result "cells" @()))
    $expectedCells = @(Get-Bw28yExpectedCells)

    Add-Bw28yGate $gates 1 "receipt_identity" (
        [string](Get-Bw28yMapValue $Result "schema_version" "") -ceq
            $script:Bw28yReceiptSchema -and
        [string](Get-Bw28yMapValue $Result "campaign_id" "") -ceq
            $script:Bw28yCampaignId -and
        [string](Get-Bw28yMapValue $Result "gate_id" "") -ceq $script:Bw28yGateId -and
        [string](Get-Bw28yMapValue $Result "study_classification" "") -ceq
            "paired_outcome_unexposed_finite_controller_development_screen" -and
        [int](Get-Bw28yMapValue $Result "expected_gate_count" -1) -eq 50 -and
        [int](Get-Bw28yMapValue $Result "expected_world_count" -1) -eq 28
    ) "BW28Y_RECEIPT_IDENTITY"

    $engine = Get-Bw28yMapValue $Result "engine" @{}
    $source = Get-Bw28yMapValue $Result "source" @{}
    Add-Bw28yGate $gates 2 "host_and_source" (
        [string](Get-Bw28yMapValue $engine "physics_engine" "") -ceq "Jolt Physics" -and
        [string](Get-Bw28yMapValue $engine "godot_version" "") -ceq
            $script:Bw28yGodotVersion -and
        [string](Get-Bw28yMapValue $engine "godot_executable_sha256" "") -ceq
            $script:Bw28yGodotSha256 -and
        [int](Get-Bw28yMapValue $engine "physics_hz" -1) -eq 120 -and
        [int](Get-Bw28yMapValue $engine "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw28yMapValue $engine "solver_position_steps" -1) -eq 7 -and
        [string](Get-Bw28yMapValue $source "commit" "") -cmatch '^[0-9a-f]{40}$' -and
        [bool](Get-Bw28yMapValue $source "worktree_clean" $false) -and
        [bool](Get-Bw28yMapValue $source "matches_live_github_main" $false)
    ) "BW28Y_HOST_SOURCE"

    $prerequisites = Get-Bw28yMapValue $Result "prerequisites" @{}
    Add-Bw28yGate $gates 3 "prerequisite_evidence" (
        [string](Get-Bw28yMapValue $prerequisites "bw25y_closure_raw_sha256" "") -ceq
            "c8b5a0a021f84fc929348142ab452414ad990d0cc2682d255e9a6890bc21f5ab" -and
        [string](Get-Bw28yMapValue $prerequisites "bw27p_profile_closure_raw_sha256" "") -ceq
            "1709a79a2929159cca075c43e516bdfaa7dd1f87806dde648f6629e6069f41de" -and
        [bool](Get-Bw28yMapValue $prerequisites "bw25y_infrastructure_invalid" $false) -and
        -not [bool](Get-Bw28yMapValue $prerequisites "bw25y_controller_comparison_result" $true) -and
        -not [bool](Get-Bw28yMapValue $prerequisites "bw25y_candidate_selected" $true) -and
        [bool](Get-Bw28yMapValue $prerequisites "bw27p_profiles_closed_positive" $false) -and
        [bool](Get-Bw28yMapValue $prerequisites "fresh_values_and_seeds_unopened" $false)
    ) "BW28Y_PREREQUISITES"

    $declarations = Get-Bw28yMapValue $Result "declarations" @{}
    Add-Bw28yGate $gates 4 "frozen_declarations" (
        [string](Get-Bw28yMapValue $declarations "preregistration_raw_sha256" "") -ceq
            "90a5bd3e6a72e3c038e6a4b6446790a09dea72eb7fb72a4dbb98048e8dc732b4" -and
        [string](Get-Bw28yMapValue $declarations "candidates_raw_sha256" "") -ceq
            "51a03c46cccc877857d312679e19018fbc77c2e78a3586ff0f29085997e073e1" -and
        [string](Get-Bw28yMapValue $declarations "manifest_raw_sha256" "") -ceq
            "6540b94753bd7e19a661d326ad678e47034d227d5c1dd660c88132360f0d20a9" -and
        @((Get-Bw28yMapValue $declarations "candidate_order" @())) -join ',' -ceq
            "BW28Y-A,BW28Y-B" -and
        @((Get-Bw28yMapValue $declarations "material_profile_ids" @())) -join ',' -ceq
            (@($script:Bw28yProfiles.profile_id) -join ',') -and
        @((Get-Bw28yMapValue $declarations "seeds" @())) -join ',' -ceq
            ($script:Bw28ySeeds -join ',') -and
        [string](Get-Bw28yMapValue $declarations "baseline_candidate_id" "") -ceq
            "BW28Y-A"
    ) "BW28Y_DECLARATIONS"

    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $cell = if ($index -lt $cells.Count) { $cells[$index] } else { @{} }
        Add-Bw28yGate $gates ($index + 5) (
            "cell_" + [string]$expectedCells[$index].cell_id
        ) (Test-Bw28yCell -Cell $cell -Expected $expectedCells[$index]) `
            "BW28Y_CELL_GATE"
    }

    $candidates = @($cells | Where-Object {
        [string](Get-Bw28yMapValue $_ "role" "") -ceq "candidate"
    })
    $controls = @($cells | Where-Object {
        [string](Get-Bw28yMapValue $_ "role" "") -ceq "control"
    })
    $safetyCells = @($cells | Where-Object {
        [string](Get-Bw28yMapValue $_ "role" "") -ceq "safety"
    })
    Add-Bw28yGate $gates 33 "exact_order_and_role_cardinality" (
        $cells.Count -eq 28 -and $candidates.Count -eq 24 -and
        $controls.Count -eq 3 -and $safetyCells.Count -eq 1 -and
        [int](Get-Bw28yMapValue $Result "observed_world_count" -1) -eq 28 -and
        [int](Get-Bw28yMapValue $Result "integrity_failure_count" -1) -eq 0
    ) "BW28Y_MATRIX_CARDINALITY"

    Add-Bw28yGate $gates 34 "zero_candidate_infrastructure_failures" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not [bool](Get-Bw28yMapValue $_ "common_execution_integrity" $false) -or
            -not [bool](Get-Bw28yMapValue $_ "outcome_complete" $false)
        }).Count -eq 0
    ) "BW28Y_CANDIDATE_INFRASTRUCTURE"

    Add-Bw28yGate $gates 35 "policy_relative_receipt_identity" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            [string](Get-Bw28yMapValue $_ "controller_policy_id" "") -cne
                [string](Get-Bw28yMapValue $_ "declared_controller_policy_id" "") -or
            [string](Get-Bw28yMapValue (
                Get-Bw28yMapValue $_ "policy_relative_common_execution" @{}
            ) "schema_version" "") -cne
                "sporespore_policy_relative_execution_integrity_v1" -or
            -not [bool](Get-Bw28yMapValue (
                Get-Bw28yMapValue $_ "policy_relative_common_execution" @{}
            ) "ok" $false)
        }).Count -eq 0
    ) "BW28Y_POLICY_RELATIVE_IDENTITY"

    Add-Bw28yGate $gates 36 "candidate_mechanism_and_application" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not [bool](Get-Bw28yMapValue $_ "mechanism_gate_passed" $false) -or
            -not [bool](Get-Bw28yMapValue $_ "combined_application_gate_passed" $false) -or
            [int](Get-Bw28yMapValue $_ "sdk_effective_application_count" 0) -le 0
        }).Count -eq 0
    ) "BW28Y_CANDIDATE_APPLICATION"

    Add-Bw28yGate $gates 37 "candidate_outcomes_and_metrics" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not (Test-Bw28yFinite (Get-Bw28yMapValue $_ "maximum_absolute_cross_track_error_m")) -or
            -not (Test-Bw28yFinite (Get-Bw28yMapValue $_ "cumulative_absolute_cross_track_error_m_s")) -or
            (Get-Bw28yFalseWalkingGateCount (
                Get-Bw28yMapValue $_ "walking_gate_receipts" @{}
            )) -ge 999999
        }).Count -eq 0
    ) "BW28Y_CANDIDATE_OUTCOME_METRICS"

    Add-Bw28yGate $gates 38 "candidate_profiles_gains_and_compositions" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            $row = @($script:Bw28yCandidates | Where-Object candidate_id -CEQ (
                [string](Get-Bw28yMapValue $_ "candidate_id" "")
            )) | Select-Object -First 1
            $null -eq $row -or
            [string](Get-Bw28yMapValue $_ "controller_policy_id" "") -cne
                [string]$row.policy_id -or
            [string](Get-Bw28yMapValue $_ "controller_runtime_profile_sha256" "") -cne
                [string]$row.runtime_profile_sha256 -or
            [string](Get-Bw28yMapValue $_ "candidate_composition_digest" "") -cne
                [string]$row.composition_digest -or
            -not (Test-Bw28yNear (
                Get-Bw28yMapValue $_ "proportional_factor"
            ) ([double]$row.proportional_factor)) -or
            -not (Test-Bw28yNear (
                Get-Bw28yMapValue $_ "velocity_factor"
            ) ([double]$row.velocity_factor)) -or
            -not (Test-Bw28yNear (
                Get-Bw28yMapValue $_ "yaw_error_stride_gain_per_rad"
            ) ([double]$row.yaw_error_stride_gain_per_rad))
        }).Count -eq 0
    ) "BW28Y_CANDIDATE_PROFILE"

    Add-Bw28yGate $gates 39 "corrected_zero_residual_controls" (
        $controls.Count -eq 3 -and @($controls | Where-Object {
            -not [bool](Get-Bw28yMapValue $_ "common_execution_integrity" $false) -or
            [bool](Get-Bw28yMapValue $_ "combined_application_gate_passed" $true) -or
            [int](Get-Bw28yMapValue $_ "sdk_effective_application_count" -1) -ne 0
        }).Count -eq 0
    ) "BW28Y_CONTROL_RESIDUAL_SEMANTICS"

    Add-Bw28yGate $gates 40 "active_base_controller_controls" (
        $controls.Count -eq 3 -and @($controls | Where-Object {
            -not [bool](Get-Bw28yMapValue $_ "base_controller_application_observed" $false) -or
            -not [bool](Get-Bw28yMapValue $_ "broad_base_controller_physical_influence_observed" $false)
        }).Count -eq 0
    ) "BW28Y_CONTROL_BASE_INFLUENCE"

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
    foreach ($profile in $script:Bw28yProfiles) {
        foreach ($seed in $script:Bw28ySeeds) {
            $group = @($candidates | Where-Object {
                [string](Get-Bw28yMapValue $_ "material_profile_id" "") -ceq
                    [string]$profile.profile_id -and
                [int](Get-Bw28yMapValue $_ "campaign_seed" -1) -eq $seed
            })
            if ($seed -eq 27011) {
                $group += @($controls | Where-Object {
                    [string](Get-Bw28yMapValue $_ "material_profile_id" "") -ceq
                        [string]$profile.profile_id
                })
            }
            $pairIdentityPassed = $pairIdentityPassed -and $group.Count -eq (
                $(if ($seed -eq 27011) { 3 } else { 2 })
            )
            if ($group.Count -gt 0) {
                foreach ($field in $pairFields) {
                    $values = @($group | ForEach-Object {
                        [string](Get-Bw28yMapValue $_ $field "")
                    } | Select-Object -Unique)
                    $pairIdentityPassed = $pairIdentityPassed -and $values.Count -eq 1
                }
                $perturbations = @($group | ForEach-Object {
                    $perturbation = Get-Bw28yMapValue $_ "initial_perturbation" @{}
                    $perturbation | ConvertTo-Json -Compress -Depth 20
                } | Select-Object -Unique)
                $perturbationPassed = $perturbationPassed -and $perturbations.Count -eq 1
            }
        }
    }
    Add-Bw28yGate $gates 41 "paired_configuration_identity" $pairIdentityPassed `
        "BW28Y_PAIR_IDENTITY"
    Add-Bw28yGate $gates 42 "paired_initial_perturbations" $perturbationPassed `
        "BW28Y_PAIRED_PERTURBATION"

    $safety = if ($safetyCells.Count -eq 1) { $safetyCells[0] } else { @{} }
    Add-Bw28yGate $gates 43 "zero_friction_safety" (
        $safetyCells.Count -eq 1 -and
        [int](Get-Bw28yMapValue $safety "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw28yMapValue $safety "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw28yMapValue $safety "physical_influence" $true)
    ) "BW28Y_ZERO_SAFETY"

    Add-Bw28yGate $gates 44 "steering_diagnostics" (
        $candidates.Count -eq 24 -and @($candidates | Where-Object {
            -not (Test-Bw28yDiagnosticCell -Cell $_)
        }).Count -eq 0
    ) "BW28Y_STEERING_DIAGNOSTICS"

    $candidateCompletionPassed = (
        $candidates.Count -eq 24 -and @($script:Bw28yCandidates | Where-Object {
            $id = [string]$_.candidate_id
            @($candidates | Where-Object {
                [string](Get-Bw28yMapValue $_ "candidate_id" "") -ceq $id
            }).Count -ne 12
        }).Count -eq 0
    )
    Add-Bw28yGate $gates 45 "all_candidates_complete_before_selection" `
        $candidateCompletionPassed "BW28Y_CANDIDATE_COMPLETION"

    $selector = Get-Bw28yMapValue $Result "selector" @{}
    Add-Bw28yGate $gates 46 "frozen_selector" (
        [string](Get-Bw28yMapValue $selector "selection_mode" "") -ceq
            "complete_preregistered_paired_lexicographic_development_selection" -and
        [string](Get-Bw28yMapValue $selector "baseline_candidate_id" "") -ceq
            "BW28Y-A" -and
        @((Get-Bw28yMapValue $selector "selection_vector" @())) -join ',' -ceq
            "walking_conjunction_failure_count,aggregate_failed_production_walking_gate_count,maximum_absolute_cross_track_error_m,aggregate_cumulative_absolute_cross_track_error_m_s,candidate_order" -and
        [bool](Get-Bw28yMapValue $selector "strict_improvement_required" $false) -and
        [int](Get-Bw28yMapValue $selector "maximum_paired_walking_gate_regressions" -1) -eq 0
    ) "BW28Y_SELECTOR_DECLARATION"

    $summaries = @(Get-Bw28yCandidateSummaries -CandidateCells $candidates)
    $baseline = @($summaries | Where-Object candidate_id -CEQ "BW28Y-A") |
        Select-Object -First 1
    $successor = @($summaries | Where-Object candidate_id -CEQ "BW28Y-B") |
        Select-Object -First 1
    $comparison = if ($null -ne $successor -and $null -ne $baseline) {
        Compare-Bw28yCandidateSummary -Left $successor -Right $baseline
    } else { 0 }
    $strictlyBetter = $comparison -lt 0
    $pairedRegressionCount = if ($null -ne $successor) {
        [int]$successor.paired_walking_gate_regression_count
    } else { 999999 }
    $selectedCandidateId = if (
        $candidateCompletionPassed -and $strictlyBetter -and
        $pairedRegressionCount -eq 0
    ) { "BW28Y-B" } else { "NONE" }
    Add-Bw28yGate $gates 47 "strict_selection_integrity" (
        $candidateCompletionPassed -and $summaries.Count -eq 2 -and
        $selectedCandidateId -in @("BW28Y-B", "NONE") -and
        ($selectedCandidateId -cne "BW28Y-B" -or (
            $strictlyBetter -and $pairedRegressionCount -eq 0
        ))
    ) "BW28Y_SELECTION_INTEGRITY"

    Add-Bw28yGate $gates 48 "zero_outcome_conditioning" (
        @(@($candidates) + @($controls) | Where-Object {
            [int](Get-Bw28yMapValue $_ "policy_branch_surface_count" -1) -ne 0 -or
            [int](Get-Bw28yMapValue $_ "material_condition_count" -1) -ne 0 -or
            [int](Get-Bw28yMapValue $_ "seed_condition_count" -1) -ne 0 -or
            [int](Get-Bw28yMapValue $_ "failure_identity_condition_count" -1) -ne 0 -or
            [int](Get-Bw28yMapValue $_ "outcome_condition_count" -1) -ne 0
        }).Count -eq 0
    ) "BW28Y_OUTCOME_CONDITIONING"

    $claims = Get-Bw28yMapValue $Result "declared_claims" @{}
    $claimsPassed = $claims -is [System.Collections.IDictionary]
    foreach ($claimName in $script:Bw28yFalseClaims) {
        $claimsPassed = $claimsPassed -and
            -not [bool](Get-Bw28yMapValue $claims $claimName $true)
    }
    Add-Bw28yGate $gates 49 "claim_boundary" $claimsPassed `
        "BW28Y_CLAIM_INFLATION"

    Add-Bw28yGate $gates 50 "selector_not_preinvoked" (
        [int](Get-Bw28yMapValue $Result "selector_invocation_count_before_evaluation" -1) -eq 0 -and
        [string](Get-Bw28yMapValue $Result "pre_evaluation_selected_candidate_id" "") -ceq
            "NONE"
    ) "BW28Y_SELECTOR_PREINVOCATION"

    $failureCodes = @($gates | Where-Object { -not [bool]$_.passed } |
        ForEach-Object { [string]$_.failure_code } | Select-Object -Unique)
    $ok = $gates.Count -eq 50 -and $failureCodes.Count -eq 0
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw28y_yaw_development_evaluation_v1"
        ok = $ok
        campaign_id = $script:Bw28yCampaignId
        gate_id = $script:Bw28yGateId
        reconstructed_passed_gate_count = @($gates | Where-Object passed).Count
        reconstructed_failed_gate_count = @($gates | Where-Object {
            -not $_.passed
        }).Count
        expected_gate_count = 50
        expected_world_count = 28
        observed_world_count = [int](Get-Bw28yMapValue $Result "observed_world_count" -1)
        candidate_count = $candidates.Count
        control_count = $controls.Count
        safety_count = $safetyCells.Count
        candidate_summaries = $summaries
        selected_candidate_id = $selectedCandidateId
        selected_candidate_strictly_better_than_baseline = $strictlyBetter
        selected_candidate_paired_regression_count = $pairedRegressionCount
        development_selection_authority = ($ok -and $selectedCandidateId -ceq "BW28Y-B")
        independent_validation_authority = $false
        gates = @($gates)
        failure_codes = $failureCodes
        claims_if_valid = [ordered]@{
            complete_finite_development_result = $ok
            development_candidate_selected = ($ok -and $selectedCandidateId -ceq "BW28Y-B")
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

function New-Bw28yPerfectSyntheticYawDevelopmentResult {
    $expectedCells = @(Get-Bw28yExpectedCells)
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($expected in $expectedCells) {
        $role = [string]$expected.role
        $isCandidate = $role -ceq "candidate"
        $isControl = $role -ceq "control"
        $isSafety = $role -ceq "safety"
        $profileIndex = [math]::Max(0, @($script:Bw28yProfiles.profile_id).IndexOf(
            [string]$expected.profile_id
        ))
        $seedIndex = [math]::Max(0, $script:Bw28ySeeds.IndexOf(
            [int]$expected.campaign_seed
        ))
        $pairNumber = 1 + ($profileIndex * 4) + $seedIndex
        $pairToken = $pairNumber.ToString("x").PadLeft(64, "0")
        $candidateIndex = @($script:Bw28yCandidates.candidate_id).IndexOf(
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
        $failedWalking = if ($isSafety) {
            0
        } else { Get-Bw28yFalseWalkingGateCount $walkingGates }
        $cell = [ordered]@{
            schema_version =
                "sporespore_balanced_wave_bw28y_yaw_development_cell_v1"
            campaign_id = $script:Bw28yCampaignId
            gate_id = $script:Bw28yGateId
            cell_id = [string]$expected.cell_id
            cohort = [string]$expected.cohort
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
            } else { $script:Bw28yStabilityPolicyId })
            authority_scope = $(if ($isSafety) { "none" } else { "post_settle_full" })
            execution_mode = $(if ($isSafety) {
                "shadow_only_no_sdk_native_actuation"
            } else { $script:Bw28yExecutionMode })
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
            final_task_frame_lateral_displacement_m = 0.02
            minimum_cross_track_error_m = -0.08
            maximum_cross_track_error_m = 0.10
            maximum_absolute_cross_track_error_m = 0.10
            cumulative_absolute_cross_track_error_m_s = 0.40
            steering_feedback_update_count = $(if ($isCandidate) { 100 } else { 1 })
            steering_filter_application_count = $(if ($isCandidate) { 100 } else { 1 })
            steering_saturation_count = 0
            steering_slew_limited_count = $(if ($isCandidate) { 5 } else { 0 })
            maximum_absolute_requested_steering_fraction = 0.18
            maximum_absolute_filtered_steering_fraction = 0.15
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
            receipt_route_schema = "sporespore_actual_worker_receipt_route_v1"
            receipt_route_failure_codes = @()
            raw_receipt_complete = $true
            role_gate_passed = $true
            walking_result_controls_process_exit = $false
        }
        $cells.Add($cell)
    }
    $claims = [ordered]@{}
    foreach ($claimName in $script:Bw28yFalseClaims) { $claims[$claimName] = $false }
    return [ordered]@{
        schema_version = $script:Bw28yReceiptSchema
        campaign_id = $script:Bw28yCampaignId
        gate_id = $script:Bw28yGateId
        study_classification =
            "paired_outcome_unexposed_finite_controller_development_screen"
        expected_gate_count = 50
        expected_world_count = 28
        observed_world_count = 28
        integrity_failure_count = 0
        engine = [ordered]@{
            physics_engine = "Jolt Physics"
            godot_version = $script:Bw28yGodotVersion
            godot_executable_sha256 = $script:Bw28yGodotSha256
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
            bw25y_closure_raw_sha256 =
                "c8b5a0a021f84fc929348142ab452414ad990d0cc2682d255e9a6890bc21f5ab"
            bw27p_profile_closure_raw_sha256 =
                "1709a79a2929159cca075c43e516bdfaa7dd1f87806dde648f6629e6069f41de"
            bw25y_infrastructure_invalid = $true
            bw25y_controller_comparison_result = $false
            bw25y_candidate_selected = $false
            bw27p_profiles_closed_positive = $true
            fresh_values_and_seeds_unopened = $true
        }
        declarations = [ordered]@{
            preregistration_raw_sha256 =
                "90a5bd3e6a72e3c038e6a4b6446790a09dea72eb7fb72a4dbb98048e8dc732b4"
            candidates_raw_sha256 =
                "51a03c46cccc877857d312679e19018fbc77c2e78a3586ff0f29085997e073e1"
            manifest_raw_sha256 =
                "6540b94753bd7e19a661d326ad678e47034d227d5c1dd660c88132360f0d20a9"
            candidate_order = @("BW28Y-A", "BW28Y-B")
            material_profile_ids = @($script:Bw28yProfiles.profile_id)
            seeds = $script:Bw28ySeeds
            baseline_candidate_id = "BW28Y-A"
        }
        selector = [ordered]@{
            selection_mode =
                "complete_preregistered_paired_lexicographic_development_selection"
            baseline_candidate_id = "BW28Y-A"
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
