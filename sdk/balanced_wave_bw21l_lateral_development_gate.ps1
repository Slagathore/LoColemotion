#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw21lCampaignId = "BW21L-MATERIAL-LATERAL-DEVELOPMENT"
$script:Bw21lGateId = "BW21L"
$script:Bw21lResultSchema = (
    "sporespore_balanced_wave_bw21l_lateral_development_result_v1"
)
$script:Bw21lCellSchema = (
    "sporespore_balanced_wave_bw21l_lateral_development_cell_v1"
)
$script:Bw21lStudyClassification = (
    "paired_outcome_exposed_finite_controller_development_screen"
)
$script:Bw21lGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:Bw21lGodotExecutableSha256 = (
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$script:Bw21lPreregistrationRawSha256 = (
    "507382a701b0b091b30f84d33d9f16d3b80c7ae207d0d2b1e6322fa72636a355"
)
$script:Bw21lCandidatesRawSha256 = (
    "4cdb98b341a932ccd69d85839301b54d039e3680cd67a44baeea2b77136d913b"
)
$script:Bw21lBw20fClosureRawSha256 = (
    "bd18cd9a4905182673459b7b203ff7b7ae4cd5f954f00175f14fc721980bc1ef"
)
$script:Bw21lBw20fReportRawSha256 = (
    "69400655be32d09404222a647601aa7a1a0856c5c4f3c0cd6a07dac3841caf03"
)
$script:Bw21lStabilityPolicyId = "sporespore_scheduled_load_transfer_bw13p_a_v3"
$script:Bw21lExecutionMode = "native_balanced_wave_base_with_stability_contribution"
$script:Bw21lControlId = "BW21L-CONTROL"
$script:Bw21lControlDigest = (
    "sha256:496c701335b3cf857ac19e3654475e75b407f7de7e7a4f343651b5691f22a7e7"
)
$script:Bw21lCandidateRows = @(
    [ordered]@{
        candidate_id = "BW21L-A"
        token = "bw21l_a"
        controller_policy_id = "sporespore_balanced_wave_bw15f_b_v1"
        runtime_profile_sha256 = "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"
        candidate_composition_digest = "sha256:2546cae8c4d3312b88289b80c65c0f6cf488c940576c6595c4975617814098d8"
        proportional_factor = 1.0
        velocity_factor = 1.0
    },
    [ordered]@{
        candidate_id = "BW21L-B"
        token = "bw21l_b"
        controller_policy_id = "sporespore_balanced_wave_bw21l_b_v1"
        runtime_profile_sha256 = "sha256:70b1b0c445bc8b53d94a09f70e18271b9727d9f41b772fa843ae9e59174af6f5"
        candidate_composition_digest = "sha256:7278c8ed0afbdd8124a51beef8ca8ca0b11731aafcfe5537051504cc9ee94d0f"
        proportional_factor = 1.5
        velocity_factor = 1.0
    },
    [ordered]@{
        candidate_id = "BW21L-C"
        token = "bw21l_c"
        controller_policy_id = "sporespore_balanced_wave_bw21l_c_v1"
        runtime_profile_sha256 = "sha256:53c443565996a1a7e7c749ca37c7530a99847d7c3a267a9dea83ee1c17926ff3"
        candidate_composition_digest = "sha256:f494931c45fe792242556b78cd87b228dff1a1f2b2362674986979c6616e3853"
        proportional_factor = 1.0
        velocity_factor = 2.0
    },
    [ordered]@{
        candidate_id = "BW21L-D"
        token = "bw21l_d"
        controller_policy_id = "sporespore_balanced_wave_bw21l_d_v1"
        runtime_profile_sha256 = "sha256:9b558419c3b74218b26fa306407b6efb20a680c80059365a405c6fdb06642a59"
        candidate_composition_digest = "sha256:881cb65b226c5e0f934378db8ad556b2a95cbf87b7098cd868de6a3abe7ec8b3"
        proportional_factor = 1.5
        velocity_factor = 2.0
    }
)
$script:Bw21lProfileRows = @(
    [ordered]@{
        token = "009"
        authored_friction = 0.09
        profile_id = "godot_jolt_bw20f_mu009_v1"
        profile_digest = "sha256:92891cfbed2b30c5d6c72fa02a30770fcf75880416a92fe2f69d9ece8246ee55"
    },
    [ordered]@{
        token = "037"
        authored_friction = 0.37
        profile_id = "godot_jolt_bw20f_mu037_v1"
        profile_digest = "sha256:690e5c2f035a7a3efc32fa31c86cfab03299f8c539500e110b5ddf9e35b6dfb9"
    },
    [ordered]@{
        token = "076"
        authored_friction = 0.76
        profile_id = "godot_jolt_bw20f_mu076_v1"
        profile_digest = "sha256:76f42bc89da95e09d081d17d5e3aa520de25fa6a352067dd8c30ace3834667b0"
    },
    [ordered]@{
        token = "118"
        authored_friction = 1.18
        profile_id = "godot_jolt_bw20f_mu118_v1"
        profile_digest = "sha256:e0c6a6d78ae63a129e7ae44088aeb86da44941dba8cfcfd5680f73a236c9b297"
    }
)
$script:Bw21lZeroProfile = [ordered]@{
    profile_id = "godot_jolt_p5m1r1_mu000_v1"
    profile_digest = "sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"
}
$script:Bw21lClaimNames = @(
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

function Get-Bw21lMapValue {
    param(
        [AllowNull()][object]$Map,
        [Parameter(Mandatory)][string]$Key,
        [AllowNull()][object]$Default = $null
    )
    if ($Map -is [System.Collections.IDictionary] -and $Map.Contains($Key)) {
        return $Map[$Key]
    }
    return $Default
}

function Test-Bw21lFinite {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [bool]) {
        return $false
    }
    try {
        $number = [double]$Value
        return -not (
            [double]::IsNaN($number) -or [double]::IsInfinity($number)
        )
    } catch {
        return $false
    }
}

function Test-Bw21lNear {
    param(
        [AllowNull()][object]$Actual,
        [double]$Expected,
        [double]$Tolerance = 1.0e-12
    )
    return (
        (Test-Bw21lFinite $Actual) -and
        [math]::Abs(([double]$Actual) - $Expected) -le $Tolerance
    )
}

function Test-Bw21lBooleanMap {
    param([AllowNull()][object]$Values)
    if ($Values -isnot [System.Collections.IDictionary] -or $Values.Count -eq 0) {
        return $false
    }
    foreach ($value in $Values.Values) {
        if ($value -isnot [bool]) { return $false }
    }
    return $true
}

function Get-Bw21lFalseBooleanCount {
    param([AllowNull()][object]$Values)
    if (-not (Test-Bw21lBooleanMap $Values)) { return -1 }
    return @($Values.Values | Where-Object { -not [bool]$_ }).Count
}

function Test-Bw21lSha256 {
    param([AllowNull()][object]$Value)
    return [string]$Value -cmatch "^sha256:[0-9a-f]{64}$"
}

function Add-Bw21lGate {
    param(
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][System.Collections.Generic.List[object]]$Gates,
        [int]$Ordinal,
        [Parameter(Mandatory)][string]$GateId,
        [bool]$Passed,
        [Parameter(Mandatory)][string]$FailureCode
    )
    $Gates.Add([ordered]@{
        ordinal = $Ordinal
        gate_id = $GateId
        passed = $Passed
        failure_code = $(if ($Passed) { "" } else { $FailureCode })
    })
}

function Get-Bw21lExpectedCells {
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($profile in $script:Bw21lProfileRows) {
        foreach ($seed in @(23001, 23002, 23003)) {
            foreach ($candidate in $script:Bw21lCandidateRows) {
                $cells.Add([ordered]@{
                    cell_id = "development_mu$($profile.token)_s${seed}_$($candidate.token)"
                    cohort = "development"
                    role = "candidate"
                    campaign_seed = $seed
                    authored_friction = [double]$profile.authored_friction
                    profile_id = [string]$profile.profile_id
                    profile_digest = [string]$profile.profile_digest
                    candidate_id = [string]$candidate.candidate_id
                    candidate_composition_digest =
                        [string]$candidate.candidate_composition_digest
                    controller_policy_id = [string]$candidate.controller_policy_id
                    runtime_profile_sha256 =
                        [string]$candidate.runtime_profile_sha256
                    global_requested_correction_scale = 0.5
                    proportional_factor = [double]$candidate.proportional_factor
                    velocity_factor = [double]$candidate.velocity_factor
                })
            }
            if ($seed -eq 23001) {
                $baseline = $script:Bw21lCandidateRows[0]
                $cells.Add([ordered]@{
                    cell_id = "development_mu$($profile.token)_s23001_control"
                    cohort = "development"
                    role = "control"
                    campaign_seed = 23001
                    authored_friction = [double]$profile.authored_friction
                    profile_id = [string]$profile.profile_id
                    profile_digest = [string]$profile.profile_digest
                    candidate_id = $script:Bw21lControlId
                    candidate_composition_digest = $script:Bw21lControlDigest
                    controller_policy_id = [string]$baseline.controller_policy_id
                    runtime_profile_sha256 =
                        [string]$baseline.runtime_profile_sha256
                    global_requested_correction_scale = 0.0
                    proportional_factor = 1.0
                    velocity_factor = 1.0
                })
            }
        }
    }
    $cells.Add([ordered]@{
        cell_id = "negative_mu000_s23001_safety"
        cohort = "negative"
        role = "safety"
        campaign_seed = 23001
        authored_friction = 0.0
        profile_id = [string]$script:Bw21lZeroProfile.profile_id
        profile_digest = [string]$script:Bw21lZeroProfile.profile_digest
        candidate_id = "NONE"
        candidate_composition_digest = "NONE"
        controller_policy_id = "NONE"
        runtime_profile_sha256 = "NONE"
        global_requested_correction_scale = 0.0
        proportional_factor = 0.0
        velocity_factor = 0.0
    })
    return @($cells)
}

function Test-Bw21lCommonCell {
    param(
        [AllowNull()][object]$Cell,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    if ($Cell -isnot [System.Collections.IDictionary]) { return $false }
    return (
        [string](Get-Bw21lMapValue $Cell "schema_version" "") -ceq
            $script:Bw21lCellSchema -and
        [string](Get-Bw21lMapValue $Cell "campaign_id" "") -ceq
            $script:Bw21lCampaignId -and
        [string](Get-Bw21lMapValue $Cell "gate_id" "") -ceq
            $script:Bw21lGateId -and
        [string](Get-Bw21lMapValue $Cell "cell_id" "") -ceq
            [string]$Expected.cell_id -and
        [string](Get-Bw21lMapValue $Cell "cohort" "") -ceq
            [string]$Expected.cohort -and
        [string](Get-Bw21lMapValue $Cell "role" "") -ceq
            [string]$Expected.role -and
        [int](Get-Bw21lMapValue $Cell "campaign_seed" -1) -eq
            [int]$Expected.campaign_seed -and
        (Test-Bw21lNear (
            Get-Bw21lMapValue $Cell "authored_friction"
        ) ([double]$Expected.authored_friction)) -and
        [string](Get-Bw21lMapValue $Cell "material_profile_id" "") -ceq
            [string]$Expected.profile_id -and
        [string](Get-Bw21lMapValue $Cell "material_profile_sha256" "") -ceq
            [string]$Expected.profile_digest -and
        [string](Get-Bw21lMapValue $Cell "candidate_id" "") -ceq
            [string]$Expected.candidate_id -and
        [string](Get-Bw21lMapValue $Cell "candidate_composition_digest" "") -ceq
            [string]$Expected.candidate_composition_digest -and
        (Test-Bw21lNear (
            Get-Bw21lMapValue $Cell "global_requested_correction_scale"
        ) ([double]$Expected.global_requested_correction_scale)) -and
        [int](Get-Bw21lMapValue $Cell "world_build_count" -1) -eq 1 -and
        [int](Get-Bw21lMapValue $Cell "world_reset_count" -1) -eq 0 -and
        [string](Get-Bw21lMapValue $Cell "physics_engine" "") -ceq
            "Jolt Physics" -and
        [int](Get-Bw21lMapValue $Cell "physics_hz" -1) -eq 120 -and
        [int](Get-Bw21lMapValue $Cell "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw21lMapValue $Cell "solver_position_steps" -1) -eq 7 -and
        [int](Get-Bw21lMapValue $Cell "direct_body_write_count" -1) -eq 0 -and
        [int](Get-Bw21lMapValue $Cell "sdk_mismatch_count" -1) -eq 0 -and
        [int](Get-Bw21lMapValue $Cell "sdk_failure_count" -1) -eq 0 -and
        [bool](Get-Bw21lMapValue $Cell "profile_binding_exact" $false) -and
        [bool](Get-Bw21lMapValue $Cell "common_execution_integrity" $false) -and
        [bool](Get-Bw21lMapValue $Cell "outcome_complete" $false) -and
        [bool](Get-Bw21lMapValue $Cell "role_gate_passed" $false) -and
        [bool](Get-Bw21lMapValue $Cell "harness_passed" $false) -and
        (Test-Bw21lFinite (Get-Bw21lMapValue $Cell "maximum_tilt_rad")) -and
        (Test-Bw21lFinite (Get-Bw21lMapValue $Cell "minimum_torso_height_m")) -and
        (Test-Bw21lFinite (Get-Bw21lMapValue $Cell "maximum_anchor_error_m")) -and
        (Test-Bw21lFinite (Get-Bw21lMapValue $Cell "maximum_hinge_axis_error_rad")) -and
        (Test-Bw21lSha256 (Get-Bw21lMapValue $Cell "fixture_spec_sha256")) -and
        (Test-Bw21lSha256 (
            Get-Bw21lMapValue $Cell "evidence_threshold_configuration_sha256"
        )) -and
        (Test-Bw21lSha256 (
            Get-Bw21lMapValue $Cell "solver_policy_configuration_sha256"
        )) -and
        (Test-Bw21lSha256 (
            Get-Bw21lMapValue $Cell "controller_configuration_sha256"
        )) -and
        (Test-Bw21lSha256 (Get-Bw21lMapValue $Cell "initial_perturbation_sha256")) -and
        (Test-Bw21lSha256 (Get-Bw21lMapValue $Cell "initial_pose_sha256")) -and
        -not [bool](Get-Bw21lMapValue $Cell "walking_claim_authorized" $true) -and
        -not [bool](Get-Bw21lMapValue (
            $Cell
        ) "material_acceptance_claim_authorized" $true) -and
        -not [bool](Get-Bw21lMapValue $Cell "physical_acceptance_authority" $true)
    )
}

function Test-Bw21lDiagnosticCell {
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
        if (-not (Test-Bw21lFinite (Get-Bw21lMapValue $Cell $field))) {
            return $false
        }
    }
    $walking = Get-Bw21lMapValue $Cell "walking_gate_receipts" @{}
    $falseCount = Get-Bw21lFalseBooleanCount $walking
    return (
        [int](Get-Bw21lMapValue $Cell "steering_feedback_update_count" -1) -gt 0 -and
        [int](Get-Bw21lMapValue $Cell "steering_filter_application_count" -1) -gt 0 -and
        [int](Get-Bw21lMapValue $Cell "steering_saturation_count" -1) -ge 0 -and
        [int](Get-Bw21lMapValue $Cell "steering_slew_limited_count" -1) -ge 0 -and
        [double](Get-Bw21lMapValue (
            $Cell
        ) "maximum_absolute_requested_steering_fraction" 1.0) -le 0.400000000001 -and
        [double](Get-Bw21lMapValue (
            $Cell
        ) "maximum_absolute_filtered_steering_fraction" 1.0) -le 0.400000000001 -and
        (Get-Bw21lMapValue $Cell "initial_perturbation" @{}) -is
            [System.Collections.IDictionary] -and
        (Get-Bw21lMapValue $Cell "initial_perturbation" @{}).Count -gt 0 -and
        (Get-Bw21lMapValue $Cell "walking_observed" $null) -is [bool] -and
        $falseCount -ge 0 -and
        [int](Get-Bw21lMapValue (
            $Cell
        ) "failed_production_walking_gate_count" -1) -eq $falseCount
    )
}

function Test-Bw21lCell {
    param(
        [AllowNull()][object]$Cell,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    if (-not (Test-Bw21lCommonCell -Cell $Cell -Expected $Expected)) {
        return $false
    }
    $role = [string]$Expected.role
    if ($role -ceq "safety") {
        return (
            [int](Get-Bw21lMapValue $Cell "sdk_native_motor_write_count" -1) -eq 0 -and
            [int](Get-Bw21lMapValue $Cell "sdk_effective_application_count" -1) -eq 0 -and
            -not [bool](Get-Bw21lMapValue $Cell "physical_influence" $true) -and
            -not [bool](Get-Bw21lMapValue $Cell "residual_application_observed" $true) -and
            -not [bool](Get-Bw21lMapValue (
                $Cell
            ) "base_controller_application_observed" $true)
        )
    }
    $policyExact = (
        [string](Get-Bw21lMapValue $Cell "controller_policy_id" "") -ceq
            [string]$Expected.controller_policy_id -and
        [string](Get-Bw21lMapValue (
            $Cell
        ) "controller_policy_digest" "") -ceq
            [string]$Expected.runtime_profile_sha256 -and
        [string](Get-Bw21lMapValue (
            $Cell
        ) "controller_runtime_profile_sha256" "") -ceq
            [string]$Expected.runtime_profile_sha256 -and
        [string](Get-Bw21lMapValue $Cell "stability_policy_id" "") -ceq
            $script:Bw21lStabilityPolicyId -and
        [string](Get-Bw21lMapValue $Cell "authority_scope" "") -ceq
            "post_settle_full" -and
        [string](Get-Bw21lMapValue $Cell "execution_mode" "") -ceq
            $script:Bw21lExecutionMode -and
        [int](Get-Bw21lMapValue $Cell "policy_branch_surface_count" -1) -eq 0 -and
        [int](Get-Bw21lMapValue $Cell "material_condition_count" -1) -eq 0 -and
        [int](Get-Bw21lMapValue $Cell "seed_condition_count" -1) -eq 0 -and
        [int](Get-Bw21lMapValue $Cell "failure_identity_condition_count" -1) -eq 0 -and
        [int](Get-Bw21lMapValue $Cell "outcome_condition_count" -1) -eq 0 -and
        (Test-Bw21lNear (
            Get-Bw21lMapValue $Cell "proportional_factor"
        ) ([double]$Expected.proportional_factor)) -and
        (Test-Bw21lNear (
            Get-Bw21lMapValue $Cell "velocity_factor"
        ) ([double]$Expected.velocity_factor)) -and
        [bool](Get-Bw21lMapValue $Cell "mechanism_gate_passed" $false) -and
        [int](Get-Bw21lMapValue $Cell "sdk_native_motor_write_count" -1) -gt 0 -and
        [bool](Get-Bw21lMapValue (
            $Cell
        ) "base_controller_application_observed" $false) -and
        [bool](Get-Bw21lMapValue (
            $Cell
        ) "broad_base_controller_physical_influence_observed" $false) -and
        [bool](Get-Bw21lMapValue $Cell "physical_influence" $false) -and
        (Test-Bw21lDiagnosticCell -Cell $Cell)
    )
    if ($role -ceq "candidate") {
        return (
            $policyExact -and
            [bool](Get-Bw21lMapValue (
                $Cell
            ) "combined_application_gate_passed" $false) -and
            [bool](Get-Bw21lMapValue $Cell "residual_application_expected" $false) -and
            [bool](Get-Bw21lMapValue $Cell "residual_application_observed" $false) -and
            [int](Get-Bw21lMapValue (
                $Cell
            ) "sdk_effective_application_count" 0) -gt 0 -and
            (Test-Bw21lFinite (
                Get-Bw21lMapValue $Cell "maximum_absolute_applied_velocity_rad_s"
            )) -and
            [double](Get-Bw21lMapValue (
                $Cell
            ) "maximum_absolute_applied_velocity_rad_s" 0.0) -gt 0.0
        )
    }
    return (
        $role -ceq "control" -and
        $policyExact -and
        -not [bool](Get-Bw21lMapValue (
            $Cell
        ) "combined_application_gate_passed" $true) -and
        -not [bool](Get-Bw21lMapValue $Cell "residual_application_expected" $true) -and
        -not [bool](Get-Bw21lMapValue $Cell "residual_application_observed" $true) -and
        [int](Get-Bw21lMapValue (
            $Cell
        ) "sdk_effective_application_count" -1) -eq 0 -and
        (Test-Bw21lNear (
            Get-Bw21lMapValue $Cell "maximum_absolute_applied_velocity_rad_s"
        ) 0.0)
    )
}

function Compare-Bw21lCandidateSummary {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Left,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Right
    )
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

function Get-Bw21lCandidateSummaries {
    param([Parameter(Mandatory)][object[]]$Cells)
    $summaries = [System.Collections.Generic.List[object]]::new()
    $baselineCells = @($Cells | Where-Object {
        [string](Get-Bw21lMapValue $_ "candidate_id" "") -ceq "BW21L-A"
    })
    for ($candidateIndex = 0; $candidateIndex -lt 4; $candidateIndex += 1) {
        $candidateId = [string]$script:Bw21lCandidateRows[$candidateIndex].candidate_id
        $candidateCells = @($Cells | Where-Object {
            [string](Get-Bw21lMapValue $_ "candidate_id" "") -ceq $candidateId
        })
        $eligible = $candidateCells.Count -eq 12
        $walkingFailures = 0
        $failedGates = 0
        $maximumCrossTrack = 0.0
        $aggregateCrossTrack = 0.0
        foreach ($cell in $candidateCells) {
            $eligible = (
                $eligible -and
                [bool](Get-Bw21lMapValue $cell "common_execution_integrity" $false) -and
                [bool](Get-Bw21lMapValue $cell "mechanism_gate_passed" $false) -and
                [bool](Get-Bw21lMapValue $cell "residual_application_observed" $false) -and
                [int](Get-Bw21lMapValue (
                    $cell
                ) "sdk_effective_application_count" 0) -gt 0
            )
            if (-not [bool](Get-Bw21lMapValue $cell "walking_observed" $false)) {
                $walkingFailures += 1
            }
            $failedGates += [int](Get-Bw21lMapValue (
                $cell
            ) "failed_production_walking_gate_count" 999999)
            $maximumCrossTrack = [math]::Max(
                $maximumCrossTrack,
                [double](Get-Bw21lMapValue (
                    $cell
                ) "maximum_absolute_cross_track_error_m" ([double]::PositiveInfinity))
            )
            $aggregateCrossTrack += [double](Get-Bw21lMapValue (
                $cell
            ) "cumulative_absolute_cross_track_error_m_s" ([double]::PositiveInfinity))
        }
        $pairedRegressions = 0
        if ($candidateId -cne "BW21L-A" -and $candidateCells.Count -eq 12) {
            foreach ($candidateCell in $candidateCells) {
                $profile = [string](Get-Bw21lMapValue (
                    $candidateCell
                ) "material_profile_id" "")
                $seed = [int](Get-Bw21lMapValue $candidateCell "campaign_seed" -1)
                $baseline = @($baselineCells | Where-Object {
                    [string](Get-Bw21lMapValue $_ "material_profile_id" "") -ceq $profile -and
                    [int](Get-Bw21lMapValue $_ "campaign_seed" -1) -eq $seed
                }) | Select-Object -First 1
                if ($null -eq $baseline) {
                    $pairedRegressions += 1000
                    continue
                }
                $baselineGates = Get-Bw21lMapValue $baseline "walking_gate_receipts" @{}
                $candidateGates = Get-Bw21lMapValue $candidateCell "walking_gate_receipts" @{}
                foreach ($key in $baselineGates.Keys) {
                    if (
                        [bool]$baselineGates[$key] -and
                        -not [bool](Get-Bw21lMapValue $candidateGates ([string]$key) $false)
                    ) {
                        $pairedRegressions += 1
                    }
                }
            }
        }
        $summaries.Add([ordered]@{
            candidate_id = $candidateId
            eligible = $eligible
            observed_world_count = $candidateCells.Count
            walking_conjunction_failure_count = $walkingFailures
            aggregate_failed_production_walking_gate_count = $failedGates
            maximum_absolute_cross_track_error_m = $maximumCrossTrack
            aggregate_cumulative_absolute_cross_track_error_m_s = $aggregateCrossTrack
            paired_walking_gate_regression_count = $pairedRegressions
            candidate_order = $candidateIndex
        })
    }
    return @($summaries)
}

function Test-Bw21lClaimsFalse {
    param([AllowNull()][object]$Claims)
    if ($Claims -isnot [System.Collections.IDictionary]) { return $false }
    foreach ($name in $script:Bw21lClaimNames) {
        if ([bool](Get-Bw21lMapValue $Claims $name $true)) { return $false }
    }
    return $true
}

function Test-Bw21lLateralDevelopmentResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Result
    )
    $gates = [System.Collections.Generic.List[object]]::new()
    $expectedCells = @(Get-Bw21lExpectedCells)
    $cells = @(Get-Bw21lMapValue $Result "cells" @())

    $identityPassed = (
        [string](Get-Bw21lMapValue $Result "schema_version" "") -ceq
            $script:Bw21lResultSchema -and
        [string](Get-Bw21lMapValue $Result "campaign_id" "") -ceq
            $script:Bw21lCampaignId -and
        [string](Get-Bw21lMapValue $Result "gate_id" "") -ceq
            $script:Bw21lGateId -and
        [string](Get-Bw21lMapValue $Result "study_classification" "") -ceq
            $script:Bw21lStudyClassification -and
        [int](Get-Bw21lMapValue $Result "expected_gate_count" -1) -eq 73 -and
        [int](Get-Bw21lMapValue $Result "expected_world_count" -1) -eq 53
    )
    Add-Bw21lGate $gates 1 "receipt_identity" $identityPassed `
        "BW21L_RECEIPT_IDENTITY"

    $engine = Get-Bw21lMapValue $Result "engine" @{}
    $source = Get-Bw21lMapValue $Result "source" @{}
    $hostPassed = (
        [string](Get-Bw21lMapValue $engine "physics_engine" "") -ceq "Jolt Physics" -and
        [string](Get-Bw21lMapValue $engine "godot_version" "") -ceq
            $script:Bw21lGodotVersion -and
        [string](Get-Bw21lMapValue (
            $engine
        ) "godot_executable_sha256" "") -ceq
            $script:Bw21lGodotExecutableSha256 -and
        [int](Get-Bw21lMapValue $engine "physics_hz" -1) -eq 120 -and
        [int](Get-Bw21lMapValue $engine "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw21lMapValue $engine "solver_position_steps" -1) -eq 7 -and
        [string](Get-Bw21lMapValue $source "commit" "") -cmatch "^[0-9a-f]{40}$" -and
        [bool](Get-Bw21lMapValue $source "worktree_clean" $false) -and
        [bool](Get-Bw21lMapValue $source "matches_live_github_main" $false)
    )
    Add-Bw21lGate $gates 2 "host_and_source" $hostPassed "BW21L_HOST_SOURCE"

    $prerequisites = Get-Bw21lMapValue $Result "prerequisites" @{}
    $prerequisitesPassed = (
        [string](Get-Bw21lMapValue (
            $prerequisites
        ) "bw20f_closure_raw_sha256" "") -ceq
            $script:Bw21lBw20fClosureRawSha256 -and
        [string](Get-Bw21lMapValue (
            $prerequisites
        ) "bw20f_report_raw_sha256" "") -ceq
            $script:Bw21lBw20fReportRawSha256 -and
        [bool](Get-Bw21lMapValue $prerequisites "bw20f_accepted" $true) -eq $false -and
        [bool](Get-Bw21lMapValue (
            $prerequisites
        ) "bw20f_same_identity_reuse_forbidden" $false) -and
        [bool](Get-Bw21lMapValue (
            $prerequisites
        ) "outcomes_are_exposed_development_only" $false)
    )
    Add-Bw21lGate $gates 3 "prerequisite_evidence" $prerequisitesPassed `
        "BW21L_PREREQUISITES"

    $declarations = Get-Bw21lMapValue $Result "declarations" @{}
    $declarationsPassed = (
        [string](Get-Bw21lMapValue (
            $declarations
        ) "preregistration_raw_sha256" "") -ceq
            $script:Bw21lPreregistrationRawSha256 -and
        [string](Get-Bw21lMapValue (
            $declarations
        ) "candidates_raw_sha256" "") -ceq
            $script:Bw21lCandidatesRawSha256 -and
        @((Get-Bw21lMapValue $declarations "candidate_order" @())) -join "," -ceq
            "BW21L-A,BW21L-B,BW21L-C,BW21L-D" -and
        [string](Get-Bw21lMapValue $declarations "baseline_candidate_id" "") -ceq
            "BW21L-A"
    )
    Add-Bw21lGate $gates 4 "frozen_declarations" $declarationsPassed `
        "BW21L_DECLARATIONS"

    $cellPassCount = 0
    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $cell = if ($index -lt $cells.Count) { $cells[$index] } else { @{} }
        $passed = Test-Bw21lCell -Cell $cell -Expected $expectedCells[$index]
        if ($passed) { $cellPassCount += 1 }
        Add-Bw21lGate $gates ($index + 5) (
            "cell_" + [string]$expectedCells[$index].cell_id
        ) $passed "BW21L_CELL_GATE"
    }

    $candidates = @($cells | Where-Object {
        [string](Get-Bw21lMapValue $_ "role" "") -ceq "candidate"
    })
    $controls = @($cells | Where-Object {
        [string](Get-Bw21lMapValue $_ "role" "") -ceq "control"
    })
    $safetyCells = @($cells | Where-Object {
        [string](Get-Bw21lMapValue $_ "role" "") -ceq "safety"
    })

    $cardinalityPassed = (
        $cells.Count -eq 53 -and $candidates.Count -eq 48 -and
        $controls.Count -eq 4 -and $safetyCells.Count -eq 1 -and
        $cellPassCount -eq 53
    )
    Add-Bw21lGate $gates 58 "exact_order_and_role_cardinality" `
        $cardinalityPassed "BW21L_MATRIX_CARDINALITY"

    $candidateInfrastructurePassed = (
        $candidates.Count -eq 48 -and
        @($candidates | Where-Object {
            -not [bool](Get-Bw21lMapValue $_ "common_execution_integrity" $false) -or
            [int](Get-Bw21lMapValue $_ "sdk_mismatch_count" -1) -ne 0 -or
            [int](Get-Bw21lMapValue $_ "sdk_failure_count" -1) -ne 0
        }).Count -eq 0 -and
        [int](Get-Bw21lMapValue $Result "observed_world_count" -1) -eq 53 -and
        [int](Get-Bw21lMapValue $Result "integrity_failure_count" -1) -eq 0
    )
    Add-Bw21lGate $gates 59 "zero_candidate_infrastructure_failures" `
        $candidateInfrastructurePassed "BW21L_CANDIDATE_INFRASTRUCTURE"

    $candidateApplicationPassed = (
        $candidates.Count -eq 48 -and
        @($candidates | Where-Object {
            -not [bool](Get-Bw21lMapValue $_ "mechanism_gate_passed" $false) -or
            -not [bool](Get-Bw21lMapValue (
                $_
            ) "combined_application_gate_passed" $false) -or
            -not [bool](Get-Bw21lMapValue $_ "residual_application_observed" $false) -or
            [int](Get-Bw21lMapValue $_ "sdk_effective_application_count" 0) -le 0
        }).Count -eq 0
    )
    Add-Bw21lGate $gates 60 "candidate_mechanism_and_application" `
        $candidateApplicationPassed "BW21L_CANDIDATE_APPLICATION"

    $candidateProfilesPassed = $candidates.Count -eq 48
    foreach ($cell in $candidates) {
        $row = @($script:Bw21lCandidateRows | Where-Object {
            [string]$_.candidate_id -ceq
                [string](Get-Bw21lMapValue $cell "candidate_id" "")
        }) | Select-Object -First 1
        $candidateProfilesPassed = (
            $candidateProfilesPassed -and $null -ne $row -and
            [string](Get-Bw21lMapValue $cell "controller_policy_id" "") -ceq
                [string]$row.controller_policy_id -and
            [string](Get-Bw21lMapValue (
                $cell
            ) "controller_runtime_profile_sha256" "") -ceq
                [string]$row.runtime_profile_sha256 -and
            [string](Get-Bw21lMapValue (
                $cell
            ) "candidate_composition_digest" "") -ceq
                [string]$row.candidate_composition_digest
        )
    }
    Add-Bw21lGate $gates 61 "candidate_profiles_gains_and_compositions" `
        $candidateProfilesPassed "BW21L_CANDIDATE_PROFILE"

    $candidateOutcomesPassed = (
        $candidates.Count -eq 48 -and
        @($candidates | Where-Object {
            -not [bool](Get-Bw21lMapValue $_ "outcome_complete" $false) -or
            -not (Test-Bw21lDiagnosticCell -Cell $_)
        }).Count -eq 0
    )
    Add-Bw21lGate $gates 62 "candidate_outcomes_and_metrics" `
        $candidateOutcomesPassed "BW21L_CANDIDATE_OUTCOME_METRICS"

    $controlResidualPassed = (
        $controls.Count -eq 4 -and
        @($controls | Where-Object {
            -not [bool](Get-Bw21lMapValue $_ "mechanism_gate_passed" $false) -or
            [bool](Get-Bw21lMapValue $_ "combined_application_gate_passed" $true) -or
            [bool](Get-Bw21lMapValue $_ "residual_application_expected" $true) -or
            [bool](Get-Bw21lMapValue $_ "residual_application_observed" $true) -or
            [int](Get-Bw21lMapValue $_ "sdk_effective_application_count" -1) -ne 0 -or
            -not (Test-Bw21lNear (
                Get-Bw21lMapValue $_ "maximum_absolute_applied_velocity_rad_s"
            ) 0.0)
        }).Count -eq 0
    )
    Add-Bw21lGate $gates 63 "corrected_zero_residual_controls" `
        $controlResidualPassed "BW21L_CONTROL_RESIDUAL_SEMANTICS"

    $controlBasePassed = (
        $controls.Count -eq 4 -and
        @($controls | Where-Object {
            [int](Get-Bw21lMapValue $_ "sdk_native_motor_write_count" -1) -le 0 -or
            -not [bool](Get-Bw21lMapValue (
                $_
            ) "base_controller_application_observed" $false) -or
            -not [bool](Get-Bw21lMapValue (
                $_
            ) "broad_base_controller_physical_influence_observed" $false) -or
            -not [bool](Get-Bw21lMapValue $_ "physical_influence" $false)
        }).Count -eq 0
    )
    Add-Bw21lGate $gates 64 "active_base_controller_controls" `
        $controlBasePassed "BW21L_CONTROL_BASE_INFLUENCE"

    $pairFields = @(
        "fixture_spec_sha256",
        "evidence_threshold_configuration_sha256",
        "solver_policy_configuration_sha256",
        "initial_pose_sha256",
        "material_profile_id",
        "material_profile_sha256"
    )
    $pairIdentityPassed = $candidates.Count -eq 48
    $perturbationPairingPassed = $candidates.Count -eq 48
    foreach ($profile in $script:Bw21lProfileRows) {
        foreach ($seed in @(23001, 23002, 23003)) {
            $group = @($candidates | Where-Object {
                [string](Get-Bw21lMapValue $_ "material_profile_id" "") -ceq
                    [string]$profile.profile_id -and
                [int](Get-Bw21lMapValue $_ "campaign_seed" -1) -eq $seed
            })
            if ($seed -eq 23001) {
                $group += @($controls | Where-Object {
                    [string](Get-Bw21lMapValue $_ "material_profile_id" "") -ceq
                        [string]$profile.profile_id
                })
            }
            $expectedGroupCount = if ($seed -eq 23001) { 5 } else { 4 }
            $pairIdentityPassed = $pairIdentityPassed -and $group.Count -eq $expectedGroupCount
            $perturbationPairingPassed = (
                $perturbationPairingPassed -and $group.Count -eq $expectedGroupCount
            )
            if ($group.Count -gt 0) {
                $reference = $group[0]
                foreach ($cell in $group) {
                    foreach ($field in $pairFields) {
                        $pairIdentityPassed = (
                            $pairIdentityPassed -and
                            [string](Get-Bw21lMapValue $cell $field "") -ceq
                                [string](Get-Bw21lMapValue $reference $field "")
                        )
                    }
                    $perturbationPairingPassed = (
                        $perturbationPairingPassed -and
                        [string](Get-Bw21lMapValue (
                            $cell
                        ) "initial_perturbation_sha256" "") -ceq
                            [string](Get-Bw21lMapValue (
                                $reference
                            ) "initial_perturbation_sha256" "") -and
                        ((Get-Bw21lMapValue $cell "initial_perturbation" @{}) |
                            ConvertTo-Json -Depth 16 -Compress) -ceq
                        ((Get-Bw21lMapValue $reference "initial_perturbation" @{}) |
                            ConvertTo-Json -Depth 16 -Compress)
                    )
                }
            }
        }
    }
    Add-Bw21lGate $gates 65 "paired_configuration_identity" `
        $pairIdentityPassed "BW21L_PAIR_IDENTITY"
    Add-Bw21lGate $gates 66 "paired_initial_perturbations" `
        $perturbationPairingPassed "BW21L_PAIR_PERTURBATION"

    $safety = if ($safetyCells.Count -eq 1) { $safetyCells[0] } else { @{} }
    $safetyPassed = (
        $safetyCells.Count -eq 1 -and
        [int](Get-Bw21lMapValue $safety "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw21lMapValue $safety "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw21lMapValue $safety "physical_influence" $true) -and
        -not [bool](Get-Bw21lMapValue $safety "walking_claim_authorized" $true)
    )
    Add-Bw21lGate $gates 67 "zero_friction_safety" $safetyPassed `
        "BW21L_ZERO_SAFETY"

    $steeringPassed = (
        ($candidates.Count + $controls.Count) -eq 52 -and
        @(@($candidates) + @($controls) | Where-Object {
            -not (Test-Bw21lDiagnosticCell -Cell $_)
        }).Count -eq 0
    )
    Add-Bw21lGate $gates 68 "steering_diagnostics" $steeringPassed `
        "BW21L_STEERING_DIAGNOSTICS"

    $summaries = @(Get-Bw21lCandidateSummaries -Cells $cells)
    $candidateCompletionPassed = (
        $summaries.Count -eq 4 -and
        @($summaries | Where-Object {
            [int]$_.observed_world_count -ne 12 -or -not [bool]$_.eligible
        }).Count -eq 0
    )
    Add-Bw21lGate $gates 69 "all_candidates_complete_before_selection" `
        $candidateCompletionPassed "BW21L_CANDIDATE_COMPLETION"

    $selector = Get-Bw21lMapValue $Result "selector_declaration" @{}
    $selectorPassed = (
        [string](Get-Bw21lMapValue $selector "selection_mode" "") -ceq
            "complete_preregistered_lexicographic_development_selection" -and
        [string](Get-Bw21lMapValue $selector "baseline_candidate_id" "") -ceq
            "BW21L-A" -and
        @((Get-Bw21lMapValue $selector "selection_vector" @())) -join "," -ceq
            (
                "walking_conjunction_failure_count," +
                "aggregate_failed_production_walking_gate_count," +
                "maximum_absolute_cross_track_error_m," +
                "aggregate_cumulative_absolute_cross_track_error_m_s," +
                "candidate_order"
            ) -and
        [bool](Get-Bw21lMapValue $selector "strict_baseline_improvement_required" $false) -and
        [int](Get-Bw21lMapValue $selector "maximum_paired_regression_count" -1) -eq 0
    )
    Add-Bw21lGate $gates 70 "frozen_selector" $selectorPassed `
        "BW21L_SELECTOR_DECLARATION"

    $baseline = @($summaries | Where-Object candidate_id -CEQ "BW21L-A") |
        Select-Object -First 1
    $eligible = @($summaries | Where-Object eligible)
    $best = $null
    foreach ($summary in $eligible) {
        if (
            $null -eq $best -or
            (Compare-Bw21lCandidateSummary -Left $summary -Right $best) -lt 0
        ) {
            $best = $summary
        }
    }
    $selectedCandidateId = "NONE"
    $strictlyBetter = $false
    $pairedRegressionCount = -1
    if ($null -ne $best -and $null -ne $baseline) {
        $strictlyBetter = (
            (Compare-Bw21lCandidateSummary -Left $best -Right $baseline) -lt 0
        )
        $pairedRegressionCount = [int]$best.paired_walking_gate_regression_count
        if (
            [string]$best.candidate_id -cne "BW21L-A" -and
            $strictlyBetter -and $pairedRegressionCount -eq 0
        ) {
            $selectedCandidateId = [string]$best.candidate_id
        }
    }
    $selectionIntegrityPassed = (
        $candidateCompletionPassed -and
        (
            ($selectedCandidateId -ceq "NONE" -and (
                $null -eq $best -or
                [string]$best.candidate_id -ceq "BW21L-A" -or
                -not $strictlyBetter -or
                $pairedRegressionCount -ne 0
            )) -or
            ($selectedCandidateId -cne "NONE" -and
                $strictlyBetter -and $pairedRegressionCount -eq 0)
        )
    )
    Add-Bw21lGate $gates 71 "strict_selection_integrity" `
        $selectionIntegrityPassed "BW21L_SELECTION_INTEGRITY"

    $noConditioningPassed = (
        @(@($candidates) + @($controls) | Where-Object {
            [int](Get-Bw21lMapValue $_ "policy_branch_surface_count" -1) -ne 0 -or
            [int](Get-Bw21lMapValue $_ "material_condition_count" -1) -ne 0 -or
            [int](Get-Bw21lMapValue $_ "seed_condition_count" -1) -ne 0 -or
            [int](Get-Bw21lMapValue $_ "failure_identity_condition_count" -1) -ne 0 -or
            [int](Get-Bw21lMapValue $_ "outcome_condition_count" -1) -ne 0
        }).Count -eq 0
    )
    Add-Bw21lGate $gates 72 "zero_outcome_conditioning" `
        $noConditioningPassed "BW21L_OUTCOME_CONDITIONING"

    $claimsPassed = Test-Bw21lClaimsFalse (
        Get-Bw21lMapValue $Result "declared_claims" @{}
    )
    Add-Bw21lGate $gates 73 "claim_boundary" $claimsPassed `
        "BW21L_CLAIM_INFLATION"

    $failureCodes = @(
        $gates | Where-Object { -not [bool]$_.passed } |
            ForEach-Object { [string]$_.failure_code } |
            Select-Object -Unique
    )
    $ok = $gates.Count -eq 73 -and $failureCodes.Count -eq 0
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw21l_lateral_development_evaluation_v1"
        ok = $ok
        campaign_id = $script:Bw21lCampaignId
        gate_id = $script:Bw21lGateId
        reconstructed_passed_gate_count = @($gates | Where-Object passed).Count
        reconstructed_failed_gate_count = @($gates | Where-Object {
            -not $_.passed
        }).Count
        expected_gate_count = 73
        expected_world_count = 53
        observed_world_count = [int](Get-Bw21lMapValue (
            $Result
        ) "observed_world_count" -1)
        candidate_count = $candidates.Count
        control_count = $controls.Count
        safety_count = $safetyCells.Count
        cell_pass_count = $cellPassCount
        candidate_summaries = $summaries
        selected_candidate_id = $selectedCandidateId
        selected_candidate_strictly_better_than_baseline = $strictlyBetter
        selected_candidate_paired_regression_count = $pairedRegressionCount
        development_selection_authority = ($ok -and $selectedCandidateId -cne "NONE")
        independent_validation_authority = $false
        gates = @($gates)
        failure_codes = $failureCodes
        claims_if_valid = [ordered]@{
            development_result_complete = $ok
            development_candidate_selected = ($ok -and $selectedCandidateId -cne "NONE")
            walking_acceptance = $false
            bounded_discrete_material_robustness = $false
            material_robustness = $false
            continuous_friction_coverage = $false
            arbitrary_material_robustness = $false
            population_inference = $false
            superiority = $false
            noninferiority_or_equivalence = $false
            rough_terrain_robustness = $false
            external_push_recovery = $false
            sensor_noise_or_latency_robustness = $false
            cross_engine_equivalence = $false
            arbitrary_quadruped_coverage = $false
            continuous_full_volume_coverage = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
            physical_acceptance_authority = $false
        }
        interpretation = (
            "A valid result is an outcome-exposed finite development screen only. " +
            "Any selected arm is a hypothesis requiring a new source identity, " +
            "fresh unexposed material values, and fresh unexposed seeds."
        )
        physical_acceptance_authority = $false
    }
}

function New-Bw21lPerfectSyntheticLateralDevelopmentResult {
    $expectedCells = @(Get-Bw21lExpectedCells)
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($expected in $expectedCells) {
        $role = [string]$expected.role
        $isCandidate = $role -ceq "candidate"
        $isControl = $role -ceq "control"
        $isSafety = $role -ceq "safety"
        $profileIndex = [math]::Max(0, @($script:Bw21lProfileRows.profile_id).IndexOf(
            [string]$expected.profile_id
        ))
        $seedIndex = [math]::Max(0, @(23001, 23002, 23003).IndexOf(
            [int]$expected.campaign_seed
        ))
        $pairNumber = 1 + ($profileIndex * 3) + $seedIndex
        $pairToken = $pairNumber.ToString("x").PadLeft(64, "0")
        $candidateIndex = @($script:Bw21lCandidateRows.candidate_id).IndexOf(
            [string]$expected.candidate_id
        )
        $walkingGates = [ordered]@{
            bounded_lateral_drift = $true
            bounded_tilt = $true
            minimum_final_forward_translation = $true
            native_sdk_exclusive_post_settle_actuation = $true
        }
        $walkingObserved = $true
        if (
            $isCandidate -and [string]$expected.candidate_id -ceq "BW21L-A" -and
            [string]$expected.cell_id -ceq "development_mu076_s23001_bw21l_a"
        ) {
            $walkingGates.bounded_lateral_drift = $false
            $walkingObserved = $false
        }
        $failedWalkingGates = if ($isSafety) {
            0
        } else {
            Get-Bw21lFalseBooleanCount $walkingGates
        }
        $maximumCrossTrack = if ($isCandidate) {
            @(0.08, 0.04, 0.05, 0.06)[$candidateIndex]
        } elseif ($isControl) { 0.07 } else { 0.0 }
        $cell = [ordered]@{
            schema_version = $script:Bw21lCellSchema
            campaign_id = $script:Bw21lCampaignId
            gate_id = $script:Bw21lGateId
            cell_id = [string]$expected.cell_id
            cohort = [string]$expected.cohort
            role = $role
            campaign_seed = [int]$expected.campaign_seed
            authored_friction = [double]$expected.authored_friction
            material_profile_id = [string]$expected.profile_id
            material_profile_sha256 = [string]$expected.profile_digest
            candidate_id = [string]$expected.candidate_id
            candidate_composition_digest =
                [string]$expected.candidate_composition_digest
            global_requested_correction_scale =
                [double]$expected.global_requested_correction_scale
            controller_policy_id = [string]$expected.controller_policy_id
            controller_policy_digest = [string]$expected.runtime_profile_sha256
            controller_runtime_profile_sha256 =
                [string]$expected.runtime_profile_sha256
            stability_policy_id = $(if ($isSafety) {
                "NONE"
            } else { $script:Bw21lStabilityPolicyId })
            authority_scope = $(if ($isSafety) { "none" } else { "post_settle_full" })
            execution_mode = $(if ($isSafety) {
                "shadow_only_no_sdk_native_actuation"
            } else { $script:Bw21lExecutionMode })
            proportional_factor = [double]$expected.proportional_factor
            velocity_factor = [double]$expected.velocity_factor
            policy_branch_surface_count = 0
            material_condition_count = 0
            seed_condition_count = 0
            failure_identity_condition_count = 0
            outcome_condition_count = 0
            world_build_count = 1
            world_reset_count = 0
            physics_engine = "Jolt Physics"
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
            fixture_spec_sha256 = "sha256:$pairToken"
            evidence_threshold_configuration_sha256 = "sha256:$pairToken"
            solver_policy_configuration_sha256 = "sha256:$pairToken"
            controller_configuration_sha256 = "sha256:" + (
                (20 + [math]::Max(0, $candidateIndex)).ToString("x").PadLeft(64, "0")
            )
            initial_perturbation_sha256 = "sha256:$pairToken"
            initial_pose_sha256 = "sha256:$pairToken"
            initial_perturbation = [ordered]@{
                campaign_seed = [int]$expected.campaign_seed
                gait_phase_offset_ticks = $seedIndex - 1
                fixture_yaw_rad = 0.0
            }
            profile_binding_exact = $true
            common_execution_integrity = $true
            outcome_complete = $true
            direct_body_write_count = 0
            sdk_mismatch_count = 0
            sdk_failure_count = 0
            sdk_native_motor_write_count = $(if ($isSafety) { 0 } else { 9232 })
            sdk_effective_application_count = $(if ($isCandidate) { 100 } else { 0 })
            maximum_absolute_proposed_velocity_rad_s = $(if ($isSafety) { 0.0 } else { 0.05 })
            maximum_absolute_applied_velocity_rad_s = $(if ($isCandidate) { 0.025 } else { 0.0 })
            residual_application_expected = $isCandidate
            residual_application_observed = $isCandidate
            base_controller_application_observed = (-not $isSafety)
            broad_base_controller_physical_influence_observed = (-not $isSafety)
            physical_influence = (-not $isSafety)
            mechanism_gate_passed = (-not $isSafety)
            combined_application_gate_passed = $isCandidate
            walking_observed = $(if ($isSafety) { $false } else { $walkingObserved })
            walking_gate_receipts = $(if ($isSafety) { [ordered]@{} } else { $walkingGates })
            failed_production_walking_gate_count = $failedWalkingGates
            final_task_frame_lateral_displacement_m = $(if ($isSafety) {
                0.0
            } else { $maximumCrossTrack / 2.0 })
            minimum_cross_track_error_m = $(if ($isSafety) { 0.0 } else { -0.01 })
            maximum_cross_track_error_m = $maximumCrossTrack
            maximum_absolute_cross_track_error_m = $maximumCrossTrack
            cumulative_absolute_cross_track_error_m_s = $(if ($isCandidate) {
                0.5 + (0.1 * $candidateIndex)
            } elseif ($isControl) { 0.6 } else { 0.0 })
            steering_feedback_update_count = $(if ($isSafety) { 0 } else { 1154 })
            steering_filter_application_count = $(if ($isSafety) { 0 } else { 1154 })
            steering_saturation_count = 0
            steering_slew_limited_count = 0
            maximum_absolute_requested_steering_fraction = $(if ($isSafety) { 0.0 } else { 0.25 })
            maximum_absolute_filtered_steering_fraction = $(if ($isSafety) { 0.0 } else { 0.20 })
            maximum_absolute_steering_delta_per_step = $(if ($isSafety) { 0.0 } else { 0.01 })
            walking_claim_authorized = $false
            material_acceptance_claim_authorized = $false
            maximum_tilt_rad = 0.1
            minimum_torso_height_m = 0.4
            maximum_anchor_error_m = 0.01
            maximum_hinge_axis_error_rad = 0.01
            development_only = $true
            physical_acceptance_authority = $false
            role_gate_passed = $true
            harness_passed = $true
        }
        $cells.Add($cell)
    }
    $claims = [ordered]@{}
    foreach ($name in $script:Bw21lClaimNames) { $claims[$name] = $false }
    return [ordered]@{
        schema_version = $script:Bw21lResultSchema
        campaign_id = $script:Bw21lCampaignId
        gate_id = $script:Bw21lGateId
        study_classification = $script:Bw21lStudyClassification
        expected_gate_count = 73
        expected_world_count = 53
        observed_world_count = 53
        integrity_failure_count = 0
        engine = [ordered]@{
            physics_engine = "Jolt Physics"
            godot_version = $script:Bw21lGodotVersion
            godot_executable_sha256 = $script:Bw21lGodotExecutableSha256
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
            bw20f_closure_raw_sha256 = $script:Bw21lBw20fClosureRawSha256
            bw20f_report_raw_sha256 = $script:Bw21lBw20fReportRawSha256
            bw20f_accepted = $false
            bw20f_same_identity_reuse_forbidden = $true
            outcomes_are_exposed_development_only = $true
        }
        declarations = [ordered]@{
            preregistration_raw_sha256 = $script:Bw21lPreregistrationRawSha256
            candidates_raw_sha256 = $script:Bw21lCandidatesRawSha256
            candidate_order = @("BW21L-A", "BW21L-B", "BW21L-C", "BW21L-D")
            baseline_candidate_id = "BW21L-A"
        }
        selector_declaration = [ordered]@{
            selection_mode =
                "complete_preregistered_lexicographic_development_selection"
            baseline_candidate_id = "BW21L-A"
            selection_vector = @(
                "walking_conjunction_failure_count",
                "aggregate_failed_production_walking_gate_count",
                "maximum_absolute_cross_track_error_m",
                "aggregate_cumulative_absolute_cross_track_error_m_s",
                "candidate_order"
            )
            strict_baseline_improvement_required = $true
            maximum_paired_regression_count = 0
        }
        cells = @($cells)
        declared_claims = $claims
    }
}
