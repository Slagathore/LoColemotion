#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw20fLocomotionCampaignId = "BW20F-BW19V-COLD-MATERIAL-LOCOMOTION"
$script:Bw20fLocomotionGateId = "BW20F-LOCOMOTION"
$script:Bw20fLocomotionReceiptSchema = (
    "sporespore_balanced_wave_bw20f_material_locomotion_result_v1"
)
$script:Bw20fLocomotionGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:Bw20fLocomotionGodotExecutableSha256 = (
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$script:Bw20fLocomotionTreatmentCompositionDigest = (
    "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
)
$script:Bw20fLocomotionControlCompositionDigest = (
    "sha256:2eb8621882b4ae4047821aca415ab1b67de3399d0ab272a91f57fb0fc2ada7a4"
)
$script:Bw20fLocomotionControllerPolicyDigest = (
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
)
$script:Bw20fLocomotionProfileRows = @(
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
$script:Bw20fLocomotionZeroProfile = [ordered]@{
    token = "000"
    authored_friction = 0.0
    profile_id = "godot_jolt_p5m1r1_mu000_v1"
    profile_digest = "sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"
}

function Get-Bw20fLocomotionMapValue {
    param(
        [AllowNull()][object]$Map,
        [Parameter(Mandatory)][string]$Key,
        [AllowNull()][object]$Default = $null
    )
    if (
        $Map -is [System.Collections.IDictionary] -and
        $Map.Contains($Key)
    ) {
        return $Map[$Key]
    }
    return $Default
}

function Test-Bw20fLocomotionFinite {
    param([AllowNull()][object]$Value)
    if (
        $null -eq $Value -or
        $Value -is [string] -or
        $Value -is [bool]
    ) {
        return $false
    }
    try {
        $number = [double]$Value
        return -not (
            [double]::IsNaN($number) -or
            [double]::IsInfinity($number)
        )
    } catch {
        return $false
    }
}

function Test-Bw20fLocomotionNear {
    param(
        [AllowNull()][object]$Actual,
        [double]$Expected,
        [double]$Tolerance = 1.0e-12
    )
    return (
        (Test-Bw20fLocomotionFinite $Actual) -and
        [math]::Abs(([double]$Actual) - $Expected) -le $Tolerance
    )
}

function Test-Bw20fLocomotionAllTrue {
    param([AllowNull()][object]$Values)
    if (
        $Values -isnot [System.Collections.IDictionary] -or
        $Values.Count -eq 0
    ) {
        return $false
    }
    foreach ($value in $Values.Values) {
        if ($value -isnot [bool] -or -not [bool]$value) {
            return $false
        }
    }
    return $true
}

function Add-Bw20fLocomotionGate {
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

function Get-Bw20fLocomotionExpectedCells {
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($profile in $script:Bw20fLocomotionProfileRows) {
        foreach ($seed in @(23001, 23002, 23003)) {
            $cells.Add([ordered]@{
                cell_id = "validation_mu$($profile.token)_s${seed}_treatment"
                cohort = "validation"
                role = "treatment"
                campaign_seed = $seed
                authored_friction = [double]$profile.authored_friction
                profile_id = [string]$profile.profile_id
                profile_digest = [string]$profile.profile_digest
                candidate_id = "BW19V-B"
                candidate_composition_digest =
                    $script:Bw20fLocomotionTreatmentCompositionDigest
                global_requested_correction_scale = 0.5
            })
            if ($seed -eq 23001) {
                $cells.Add([ordered]@{
                    cell_id = "validation_mu$($profile.token)_s23001_control"
                    cohort = "validation"
                    role = "control"
                    campaign_seed = 23001
                    authored_friction = [double]$profile.authored_friction
                    profile_id = [string]$profile.profile_id
                    profile_digest = [string]$profile.profile_digest
                    candidate_id = "BW19V-A"
                    candidate_composition_digest =
                        $script:Bw20fLocomotionControlCompositionDigest
                    global_requested_correction_scale = 0.0
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
        profile_id = [string]$script:Bw20fLocomotionZeroProfile.profile_id
        profile_digest = [string]$script:Bw20fLocomotionZeroProfile.profile_digest
        candidate_id = "NONE"
        candidate_composition_digest = "NONE"
        global_requested_correction_scale = 0.0
    })
    return @($cells)
}

function Test-Bw20fLocomotionCell {
    param(
        [AllowNull()][object]$Cell,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    if ($Cell -isnot [System.Collections.IDictionary]) {
        return $false
    }
    $role = [string]$Expected.role
    $identityExact = (
        [string](Get-Bw20fLocomotionMapValue $Cell "schema_version" "") -ceq
            "sporespore_balanced_wave_bw20f_material_locomotion_cell_v1" -and
        [string](Get-Bw20fLocomotionMapValue $Cell "campaign_id" "") -ceq
            $script:Bw20fLocomotionCampaignId -and
        [string](Get-Bw20fLocomotionMapValue $Cell "gate_id" "") -ceq
            $script:Bw20fLocomotionGateId -and
        [string](Get-Bw20fLocomotionMapValue $Cell "cell_id" "") -ceq
            [string]$Expected.cell_id -and
        [string](Get-Bw20fLocomotionMapValue $Cell "cohort" "") -ceq
            [string]$Expected.cohort -and
        [string](Get-Bw20fLocomotionMapValue $Cell "role" "") -ceq $role -and
        [int](Get-Bw20fLocomotionMapValue $Cell "campaign_seed" -1) -eq
            [int]$Expected.campaign_seed -and
        (Test-Bw20fLocomotionNear (
            Get-Bw20fLocomotionMapValue $Cell "authored_friction"
        ) ([double]$Expected.authored_friction)) -and
        [string](Get-Bw20fLocomotionMapValue $Cell "material_profile_id" "") -ceq
            [string]$Expected.profile_id -and
        [string](Get-Bw20fLocomotionMapValue $Cell "material_profile_sha256" "") -ceq
            [string]$Expected.profile_digest -and
        [string](Get-Bw20fLocomotionMapValue $Cell "candidate_id" "") -ceq
            [string]$Expected.candidate_id -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "candidate_composition_digest" "") -ceq
            [string]$Expected.candidate_composition_digest -and
        (Test-Bw20fLocomotionNear (
            Get-Bw20fLocomotionMapValue (
                $Cell
            ) "global_requested_correction_scale"
        ) ([double]$Expected.global_requested_correction_scale))
    )
    $commonExact = (
        $identityExact -and
        [int](Get-Bw20fLocomotionMapValue $Cell "world_build_count" -1) -eq 1 -and
        [string](Get-Bw20fLocomotionMapValue $Cell "physics_engine" "") -ceq
            "Jolt Physics" -and
        [int](Get-Bw20fLocomotionMapValue $Cell "physics_hz" -1) -eq 120 -and
        [int](Get-Bw20fLocomotionMapValue $Cell "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw20fLocomotionMapValue $Cell "solver_position_steps" -1) -eq 7 -and
        [int](Get-Bw20fLocomotionMapValue $Cell "world_reset_count" -1) -eq 0 -and
        [int](Get-Bw20fLocomotionMapValue $Cell "direct_body_write_count" -1) -eq 0 -and
        [int](Get-Bw20fLocomotionMapValue $Cell "sdk_mismatch_count" -1) -eq 0 -and
        [int](Get-Bw20fLocomotionMapValue $Cell "sdk_failure_count" -1) -eq 0 -and
        [bool](Get-Bw20fLocomotionMapValue $Cell "profile_binding_exact" $false) -and
        [bool](Get-Bw20fLocomotionMapValue $Cell "common_execution_integrity" $false) -and
        [bool](Get-Bw20fLocomotionMapValue $Cell "outcome_complete" $false) -and
        (Test-Bw20fLocomotionFinite (
            Get-Bw20fLocomotionMapValue $Cell "maximum_tilt_rad"
        )) -and
        (Test-Bw20fLocomotionFinite (
            Get-Bw20fLocomotionMapValue $Cell "minimum_torso_height_m"
        )) -and
        (Test-Bw20fLocomotionFinite (
            Get-Bw20fLocomotionMapValue $Cell "maximum_anchor_error_m"
        )) -and
        (Test-Bw20fLocomotionFinite (
            Get-Bw20fLocomotionMapValue $Cell "maximum_hinge_axis_error_rad"
        )) -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "fixture_spec_sha256" "") -cmatch "^sha256:[0-9a-f]{64}$" -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "evidence_threshold_configuration_sha256" "") -cmatch
            "^sha256:[0-9a-f]{64}$" -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "solver_policy_configuration_sha256" "") -cmatch
            "^sha256:[0-9a-f]{64}$" -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "controller_configuration_sha256" "") -cmatch
            "^sha256:[0-9a-f]{64}$" -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "initial_perturbation_sha256" "") -cmatch "^sha256:[0-9a-f]{64}$" -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "initial_pose_sha256" "") -cmatch "^sha256:[0-9a-f]{64}$"
    )

    if ($role -ceq "safety") {
        return (
            $commonExact -and
            [int](Get-Bw20fLocomotionMapValue (
                $Cell
            ) "sdk_native_motor_write_count" -1) -eq 0 -and
            [int](Get-Bw20fLocomotionMapValue (
                $Cell
            ) "sdk_effective_application_count" -1) -eq 0 -and
            -not [bool](Get-Bw20fLocomotionMapValue (
                $Cell
            ) "walking_claim_authorized" $true) -and
            -not [bool](Get-Bw20fLocomotionMapValue (
                $Cell
            ) "material_acceptance_claim_authorized" $true)
        )
    }

    $policyExact = (
        [string](Get-Bw20fLocomotionMapValue $Cell "controller_policy_id" "") -ceq
            "sporespore_balanced_wave_bw15f_b_v1" -and
        [string](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "controller_policy_digest" "") -ceq
            $script:Bw20fLocomotionControllerPolicyDigest -and
        [string](Get-Bw20fLocomotionMapValue $Cell "stability_policy_id" "") -ceq
            "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
        [string](Get-Bw20fLocomotionMapValue $Cell "authority_scope" "") -ceq
            "post_settle_full" -and
        [string](Get-Bw20fLocomotionMapValue $Cell "execution_mode" "") -ceq
            "native_balanced_wave_base_with_stability_contribution" -and
        [int](Get-Bw20fLocomotionMapValue $Cell "policy_branch_surface_count" -1) -eq 0 -and
        [int](Get-Bw20fLocomotionMapValue $Cell "material_condition_count" -1) -eq 0 -and
        [bool](Get-Bw20fLocomotionMapValue $Cell "mechanism_gate_passed" $false) -and
        [bool](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "combined_application_gate_passed" $false) -and
        [int](Get-Bw20fLocomotionMapValue $Cell "sdk_native_motor_write_count" -1) -gt 0
    )
    if ($role -ceq "treatment") {
        return (
            $commonExact -and
            $policyExact -and
            [int](Get-Bw20fLocomotionMapValue (
                $Cell
            ) "sdk_effective_application_count" 0) -gt 0 -and
            [bool](Get-Bw20fLocomotionMapValue $Cell "physical_influence" $false) -and
            [bool](Get-Bw20fLocomotionMapValue $Cell "walking_observed" $false) -and
            (Test-Bw20fLocomotionAllTrue (
                Get-Bw20fLocomotionMapValue $Cell "walking_gate_receipts" @{}
            ))
        )
    }
    return (
        $role -ceq "control" -and
        $commonExact -and
        $policyExact -and
        (Test-Bw20fLocomotionFinite (
            Get-Bw20fLocomotionMapValue $Cell "maximum_absolute_proposed_velocity_rad_s"
        )) -and
        [double](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "maximum_absolute_proposed_velocity_rad_s" 0.0) -gt 0.0 -and
        (Test-Bw20fLocomotionNear (
            Get-Bw20fLocomotionMapValue $Cell "maximum_absolute_applied_velocity_rad_s"
        ) 0.0) -and
        [int](Get-Bw20fLocomotionMapValue (
            $Cell
        ) "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw20fLocomotionMapValue $Cell "physical_influence" $true)
    )
}

function Test-Bw20fMaterialLocomotionResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Result
    )
    $gates = [System.Collections.Generic.List[object]]::new()
    $expectedCells = @(Get-Bw20fLocomotionExpectedCells)
    $cells = @(Get-Bw20fLocomotionMapValue $Result "cells" @())

    $identityPassed = (
        [string](Get-Bw20fLocomotionMapValue $Result "schema_version" "") -ceq
            $script:Bw20fLocomotionReceiptSchema -and
        [string](Get-Bw20fLocomotionMapValue $Result "campaign_id" "") -ceq
            $script:Bw20fLocomotionCampaignId -and
        [string](Get-Bw20fLocomotionMapValue $Result "gate_id" "") -ceq
            $script:Bw20fLocomotionGateId -and
        [string](Get-Bw20fLocomotionMapValue $Result "study_classification" "") -ceq
            "exact_finite_cell_material_acceptance_decision" -and
        [int](Get-Bw20fLocomotionMapValue $Result "expected_gate_count" -1) -eq 28 -and
        [int](Get-Bw20fLocomotionMapValue $Result "expected_world_count" -1) -eq 17
    )
    Add-Bw20fLocomotionGate $gates 1 "receipt_identity" $identityPassed `
        "BW20F_LOCOMOTION_RECEIPT_IDENTITY"

    $engine = Get-Bw20fLocomotionMapValue $Result "engine" @{}
    $source = Get-Bw20fLocomotionMapValue $Result "source" @{}
    $hostPassed = (
        [string](Get-Bw20fLocomotionMapValue $engine "physics_engine" "") -ceq
            "Jolt Physics" -and
        [string](Get-Bw20fLocomotionMapValue $engine "godot_version" "") -ceq
            $script:Bw20fLocomotionGodotVersion -and
        [string](Get-Bw20fLocomotionMapValue (
            $engine
        ) "godot_executable_sha256" "") -ceq
            $script:Bw20fLocomotionGodotExecutableSha256 -and
        [int](Get-Bw20fLocomotionMapValue $engine "physics_hz" -1) -eq 120 -and
        [int](Get-Bw20fLocomotionMapValue $engine "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw20fLocomotionMapValue $engine "solver_position_steps" -1) -eq 7 -and
        [string](Get-Bw20fLocomotionMapValue $source "commit" "") -cmatch
            "^[0-9a-f]{40}$" -and
        [bool](Get-Bw20fLocomotionMapValue $source "worktree_clean" $false) -and
        [bool](Get-Bw20fLocomotionMapValue $source "matches_live_github_main" $false)
    )
    Add-Bw20fLocomotionGate $gates 2 "host_and_source" $hostPassed `
        "BW20F_LOCOMOTION_HOST_SOURCE"

    $prerequisites = Get-Bw20fLocomotionMapValue $Result "prerequisites" @{}
    $prerequisitesPassed = (
        [string](Get-Bw20fLocomotionMapValue (
            $prerequisites
        ) "bw19v_closure_raw_sha256" "") -ceq
            "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7" -and
        [string](Get-Bw20fLocomotionMapValue (
            $prerequisites
        ) "stage_1_closure_raw_sha256" "") -ceq
            "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a" -and
        [string](Get-Bw20fLocomotionMapValue (
            $prerequisites
        ) "stage_2_closure_raw_sha256" "") -ceq
            "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e" -and
        [string](Get-Bw20fLocomotionMapValue (
            $prerequisites
        ) "stage_1_report_raw_sha256" "") -ceq
            "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030" -and
        [string](Get-Bw20fLocomotionMapValue (
            $prerequisites
        ) "stage_2_report_raw_sha256" "") -ceq
            "96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f" -and
        [bool](Get-Bw20fLocomotionMapValue (
            $prerequisites
        ) "profile_publication_closed_positive" $false) -and
        [bool](Get-Bw20fLocomotionMapValue (
            $prerequisites
        ) "bw19v_finite_validation_closed_positive" $false)
    )
    Add-Bw20fLocomotionGate $gates 3 "prerequisite_evidence" `
        $prerequisitesPassed "BW20F_LOCOMOTION_PREREQUISITES"

    $cellPassCount = 0
    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $cell = if ($index -lt $cells.Count) { $cells[$index] } else { @{} }
        $passed = Test-Bw20fLocomotionCell `
            -Cell $cell `
            -Expected $expectedCells[$index]
        if ($passed) { $cellPassCount += 1 }
        Add-Bw20fLocomotionGate $gates ($index + 4) (
            "cell_" + [string]$expectedCells[$index].cell_id
        ) $passed "BW20F_LOCOMOTION_CELL_GATE"
    }

    $rolesPassed = (
        $cells.Count -eq 17 -and
        @($cells | Where-Object {
            [string](Get-Bw20fLocomotionMapValue $_ "role" "") -ceq "treatment"
        }).Count -eq 12 -and
        @($cells | Where-Object {
            [string](Get-Bw20fLocomotionMapValue $_ "role" "") -ceq "control"
        }).Count -eq 4 -and
        @($cells | Where-Object {
            [string](Get-Bw20fLocomotionMapValue $_ "role" "") -ceq "safety"
        }).Count -eq 1 -and
        $cellPassCount -eq 17
    )
    Add-Bw20fLocomotionGate $gates 21 "matrix_cardinality" $rolesPassed `
        "BW20F_LOCOMOTION_MATRIX_CARDINALITY"

    $integrityPassed = (
        $cells.Count -eq 17 -and
        @($cells | Where-Object {
            -not [bool](Get-Bw20fLocomotionMapValue (
                $_
            ) "common_execution_integrity" $false)
        }).Count -eq 0 -and
        [int](Get-Bw20fLocomotionMapValue $Result "observed_world_count" -1) -eq 17 -and
        [int](Get-Bw20fLocomotionMapValue $Result "integrity_failure_count" -1) -eq 0
    )
    Add-Bw20fLocomotionGate $gates 22 "whole_matrix_integrity" $integrityPassed `
        "BW20F_LOCOMOTION_MATRIX_INTEGRITY"

    $treatments = @($cells | Where-Object {
        [string](Get-Bw20fLocomotionMapValue $_ "role" "") -ceq "treatment"
    })
    $treatmentApplicationPassed = (
        $treatments.Count -eq 12 -and
        @($treatments | Where-Object {
            [int](Get-Bw20fLocomotionMapValue (
                $_
            ) "sdk_effective_application_count" 0) -le 0 -or
            -not [bool](Get-Bw20fLocomotionMapValue $_ "physical_influence" $false)
        }).Count -eq 0
    )
    Add-Bw20fLocomotionGate $gates 23 "treatment_application" `
        $treatmentApplicationPassed "BW20F_LOCOMOTION_TREATMENT_APPLICATION"

    $treatmentWalkingPassed = (
        $treatments.Count -eq 12 -and
        @($treatments | Where-Object {
            -not [bool](Get-Bw20fLocomotionMapValue $_ "walking_observed" $false) -or
            -not (Test-Bw20fLocomotionAllTrue (
                Get-Bw20fLocomotionMapValue $_ "walking_gate_receipts" @{}
            ))
        }).Count -eq 0
    )
    Add-Bw20fLocomotionGate $gates 24 "treatment_walking" `
        $treatmentWalkingPassed "BW20F_LOCOMOTION_TREATMENT_WALKING"

    $controls = @($cells | Where-Object {
        [string](Get-Bw20fLocomotionMapValue $_ "role" "") -ceq "control"
    })
    $controlMechanismPassed = (
        $controls.Count -eq 4 -and
        @($controls | Where-Object {
            [int](Get-Bw20fLocomotionMapValue (
                $_
            ) "sdk_effective_application_count" -1) -ne 0 -or
            [bool](Get-Bw20fLocomotionMapValue $_ "physical_influence" $true) -or
            -not [bool](Get-Bw20fLocomotionMapValue (
                $_
            ) "combined_application_gate_passed" $false)
        }).Count -eq 0
    )
    Add-Bw20fLocomotionGate $gates 25 "control_mechanism" `
        $controlMechanismPassed "BW20F_LOCOMOTION_CONTROL_MECHANISM"

    $pairsPassed = $cells.Count -eq 17
    foreach ($profileIndex in 0..3) {
        $treatment = $cells[$profileIndex * 4]
        $control = $cells[$profileIndex * 4 + 1]
        foreach ($field in @(
            "fixture_spec_sha256",
            "evidence_threshold_configuration_sha256",
            "solver_policy_configuration_sha256",
            "controller_configuration_sha256",
            "initial_perturbation_sha256",
            "initial_pose_sha256",
            "material_profile_id",
            "material_profile_sha256"
        )) {
            $pairsPassed = (
                $pairsPassed -and
                [string](Get-Bw20fLocomotionMapValue $treatment $field "") -ceq
                    [string](Get-Bw20fLocomotionMapValue $control $field "")
            )
        }
        $pairsPassed = (
            $pairsPassed -and
            [string](Get-Bw20fLocomotionMapValue $treatment "candidate_id" "") -ceq
                "BW19V-B" -and
            [string](Get-Bw20fLocomotionMapValue $control "candidate_id" "") -ceq
                "BW19V-A" -and
            (Test-Bw20fLocomotionNear (
                Get-Bw20fLocomotionMapValue (
                    $treatment
                ) "global_requested_correction_scale"
            ) 0.5) -and
            (Test-Bw20fLocomotionNear (
                Get-Bw20fLocomotionMapValue (
                    $control
                ) "global_requested_correction_scale"
            ) 0.0)
        )
    }
    Add-Bw20fLocomotionGate $gates 26 "paired_identity_and_policy_contrast" `
        $pairsPassed "BW20F_LOCOMOTION_PAIR_IDENTITY"

    $safety = if ($cells.Count -eq 17) { $cells[16] } else { @{} }
    $safetyPassed = (
        [string](Get-Bw20fLocomotionMapValue $safety "role" "") -ceq "safety" -and
        [int](Get-Bw20fLocomotionMapValue (
            $safety
        ) "sdk_native_motor_write_count" -1) -eq 0 -and
        [int](Get-Bw20fLocomotionMapValue (
            $safety
        ) "sdk_effective_application_count" -1) -eq 0 -and
        -not [bool](Get-Bw20fLocomotionMapValue (
            $safety
        ) "walking_claim_authorized" $true)
    )
    Add-Bw20fLocomotionGate $gates 27 "zero_friction_safety" $safetyPassed `
        "BW20F_LOCOMOTION_ZERO_SAFETY"

    $claims = Get-Bw20fLocomotionMapValue $Result "declared_claims" @{}
    $claimsPassed = $claims -is [System.Collections.IDictionary]
    foreach ($claimName in @(
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
    )) {
        $claimsPassed = (
            $claimsPassed -and
            -not [bool](Get-Bw20fLocomotionMapValue $claims $claimName $true)
        )
    }
    Add-Bw20fLocomotionGate $gates 28 "claim_boundary" $claimsPassed `
        "BW20F_LOCOMOTION_CLAIM_INFLATION"

    $failureCodes = @(
        $gates |
            Where-Object { -not [bool]$_.passed } |
            ForEach-Object { [string]$_.failure_code } |
            Select-Object -Unique
    )
    $accepted = $gates.Count -eq 28 -and $failureCodes.Count -eq 0
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw20f_material_locomotion_evaluation_v1"
        ok = $accepted
        campaign_id = $script:Bw20fLocomotionCampaignId
        gate_id = $script:Bw20fLocomotionGateId
        reconstructed_passed_gate_count = @($gates | Where-Object passed).Count
        reconstructed_failed_gate_count = @($gates | Where-Object { -not $_.passed }).Count
        expected_gate_count = 28
        expected_world_count = 17
        observed_world_count = [int](Get-Bw20fLocomotionMapValue (
            $Result
        ) "observed_world_count" -1)
        treatment_count = $treatments.Count
        control_count = $controls.Count
        safety_count = $(if (
            [string](Get-Bw20fLocomotionMapValue $safety "role" "") -ceq "safety"
        ) { 1 } else { 0 })
        cell_pass_count = $cellPassCount
        pair_identity_pass_count = $(if ($pairsPassed) { 4 } else { 0 })
        gates = @($gates)
        failure_codes = $failureCodes
        claims_if_accepted = [ordered]@{
            exact_finite_godot_jolt_bw19v_b_material_acceptance = $accepted
            walking_acceptance_for_all_twelve_declared_treatment_cells = $accepted
            bounded_discrete_material_robustness = $accepted
            material_robustness = $accepted
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
        comparison_interpretation =
            "Controls establish paired configuration identity and the declared 0.5-versus-0.0 application mechanism only; no treatment-outcome superiority or terminal-separation gate is evaluated."
        physical_acceptance_authority = $false
    }
}

function New-Bw20fPerfectSyntheticMaterialLocomotionResult {
    $expectedCells = @(Get-Bw20fLocomotionExpectedCells)
    $cells = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $expected = $expectedCells[$index]
        $profileIndex = [math]::Min([math]::Floor($index / 4), 3)
        $pairToken = ([int]($profileIndex + 1)).ToString("x").PadLeft(64, "0")
        $isTreatment = [string]$expected.role -ceq "treatment"
        $isControl = [string]$expected.role -ceq "control"
        $isSafety = [string]$expected.role -ceq "safety"
        $cell = [ordered]@{
            schema_version =
                "sporespore_balanced_wave_bw20f_material_locomotion_cell_v1"
            campaign_id = $script:Bw20fLocomotionCampaignId
            gate_id = $script:Bw20fLocomotionGateId
            cell_id = [string]$expected.cell_id
            cohort = [string]$expected.cohort
            role = [string]$expected.role
            campaign_seed = [int]$expected.campaign_seed
            authored_friction = [double]$expected.authored_friction
            material_profile_id = [string]$expected.profile_id
            material_profile_sha256 = [string]$expected.profile_digest
            candidate_id = [string]$expected.candidate_id
            candidate_composition_digest =
                [string]$expected.candidate_composition_digest
            global_requested_correction_scale =
                [double]$expected.global_requested_correction_scale
            controller_policy_id = $(if ($isSafety) {
                "NONE"
            } else { "sporespore_balanced_wave_bw15f_b_v1" })
            controller_policy_digest = $(if ($isSafety) {
                "NONE"
            } else { $script:Bw20fLocomotionControllerPolicyDigest })
            stability_policy_id = $(if ($isSafety) {
                "NONE"
            } else { "sporespore_scheduled_load_transfer_bw13p_a_v3" })
            authority_scope = $(if ($isSafety) { "none" } else { "post_settle_full" })
            execution_mode = $(if ($isSafety) {
                "shadow_only_no_sdk_native_actuation"
            } else { "native_balanced_wave_base_with_stability_contribution" })
            policy_branch_surface_count = 0
            material_condition_count = 0
            world_build_count = 1
            world_reset_count = 0
            physics_engine = "Jolt Physics"
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
            fixture_spec_sha256 = "sha256:$pairToken"
            evidence_threshold_configuration_sha256 = "sha256:$pairToken"
            solver_policy_configuration_sha256 = "sha256:$pairToken"
            controller_configuration_sha256 = "sha256:$pairToken"
            initial_perturbation_sha256 = "sha256:$pairToken"
            initial_pose_sha256 = "sha256:$pairToken"
            profile_binding_exact = $true
            common_execution_integrity = $true
            outcome_complete = $true
            direct_body_write_count = 0
            sdk_mismatch_count = 0
            sdk_failure_count = 0
            sdk_native_motor_write_count = $(if ($isSafety) { 0 } else { 9232 })
            sdk_effective_application_count = $(if ($isTreatment) { 100 } else { 0 })
            maximum_absolute_proposed_velocity_rad_s = $(if ($isSafety) { 0.0 } else { 0.05 })
            maximum_absolute_applied_velocity_rad_s = $(if ($isTreatment) { 0.025 } else { 0.0 })
            physical_influence = $isTreatment
            mechanism_gate_passed = -not $isSafety
            combined_application_gate_passed = -not $isSafety
            walking_observed = $isTreatment
            walking_gate_receipts = $(if ($isTreatment) {
                [ordered]@{
                    finite_physical_state = $true
                    forward_progress = $true
                    lateral_drift = $true
                    upright = $true
                    feet_relocated = $true
                    native_sdk_exclusive_post_settle_actuation = $true
                }
            } else { [ordered]@{} })
            walking_claim_authorized = $false
            material_acceptance_claim_authorized = $false
            maximum_tilt_rad = 0.1
            minimum_torso_height_m = 0.4
            maximum_anchor_error_m = 0.01
            maximum_hinge_axis_error_rad = 0.01
        }
        $cells.Add($cell)
    }
    return [ordered]@{
        schema_version = $script:Bw20fLocomotionReceiptSchema
        campaign_id = $script:Bw20fLocomotionCampaignId
        gate_id = $script:Bw20fLocomotionGateId
        study_classification = "exact_finite_cell_material_acceptance_decision"
        expected_gate_count = 28
        expected_world_count = 17
        observed_world_count = 17
        integrity_failure_count = 0
        engine = [ordered]@{
            physics_engine = "Jolt Physics"
            godot_version = $script:Bw20fLocomotionGodotVersion
            godot_executable_sha256 = $script:Bw20fLocomotionGodotExecutableSha256
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
            bw19v_closure_raw_sha256 =
                "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
            stage_1_closure_raw_sha256 =
                "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a"
            stage_2_closure_raw_sha256 =
                "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
            stage_1_report_raw_sha256 =
                "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030"
            stage_2_report_raw_sha256 =
                "96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f"
            profile_publication_closed_positive = $true
            bw19v_finite_validation_closed_positive = $true
        }
        cells = @($cells)
        declared_claims = [ordered]@{
            accepted = $false
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
    }
}
