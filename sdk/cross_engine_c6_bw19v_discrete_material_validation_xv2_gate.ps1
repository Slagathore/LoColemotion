#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Xv2CampaignId = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV2"
$script:Xv2GateId = "C6-XE-BW19V-XV2"
$script:Xv2ResultSchema = (
    "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_result_v1"
)
$script:Xv2PreregistrationSha256 = (
    "sha256:33127f0534d919dc026320dc6ba9600c0245a35271ad7e53ba9fdf32953b8ea7"
)
$script:Xv2HostCharacterizationSha256 = (
    "sha256:a7b1b3c172b98780f574cec9dbb18bebda35429ece5105a0385ecb7d67d6ddd9"
)
$script:Xv2RapierSpv1Sha256 = (
    "sha256:7830f66de49f1d7c2d5b88d151c0c2d5077782903457837d7ecd0da2fb724203"
)
$script:Xv2RapierVh1Sha256 = (
    "sha256:d94b20ef4767479172408c1dfbd0b7f66e18e3f4bc8b9d8d84193fc157d284aa"
)
$script:Xv2RapierPh1Sha256 = (
    "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
)
$script:Xv2MujocoVh5Sha256 = (
    "sha256:fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
)
$script:Xv2MujocoMv6Sha256 = (
    "sha256:5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09"
)
$script:Xv2Xv1ClosureSha256 = (
    "sha256:67f1347a77a997de25809fd7ceef638e95020ab30df666e4cd9de3490acf8e03"
)
$script:Xv2PolicyId = "sporespore_balanced_wave_bw15f_b_v1"
$script:Xv2PolicyDigest = (
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
)
$script:Xv2CandidateDigest = (
    "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
)
$script:Xv2RestorationPolicyId = (
    "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1"
)
$script:Xv2EvidencePrefix = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

function Get-Xv2MapValue {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Map,
        [Parameter(Mandatory)][string]$Key,
        [AllowNull()][object]$Default = $null
    )

    if ($Map -is [System.Collections.IDictionary]) {
        if ($Map.Contains($Key)) {
            return $Map[$Key]
        }
        return $Default
    }
    $property = $Map.PSObject.Properties[$Key]
    if ($null -ne $property) {
        return $property.Value
    }
    return $Default
}

function Test-Xv2Finite {
    param([AllowNull()][object]$Value)

    if ($Value -isnot [ValueType]) {
        return $false
    }
    $numericTypeCodes = @(
        [TypeCode]::SByte,
        [TypeCode]::Byte,
        [TypeCode]::Int16,
        [TypeCode]::UInt16,
        [TypeCode]::Int32,
        [TypeCode]::UInt32,
        [TypeCode]::Int64,
        [TypeCode]::UInt64,
        [TypeCode]::Single,
        [TypeCode]::Double,
        [TypeCode]::Decimal
    )
    if ($numericTypeCodes -notcontains [Convert]::GetTypeCode($Value)) {
        return $false
    }
    try {
        $number = [double]$Value
        return -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)
    }
    catch {
        return $false
    }
}

function Test-Xv2Sha256 {
    param([AllowNull()][object]$Value)

    return [string]$Value -cmatch '^sha256:[0-9a-f]{64}$'
}

function Test-Xv2Commit {
    param([AllowNull()][object]$Value)

    return [string]$Value -cmatch '^[0-9a-f]{40}$'
}

function Test-Xv2AbsoluteEvidencePath {
    param([AllowNull()][object]$Value)

    try {
        $resolved = [System.IO.Path]::GetFullPath([string]$Value)
        return $resolved.StartsWith(
            $script:Xv2EvidencePrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {
        return $false
    }
}

function Get-Xv2ExpectedCells {
    return @(
        [ordered]@{
            ordinal = 1
            cell_id = "rapier_mu020"
            engine = "rapier"
            engine_version = "0.34.0"
            authored_sliding_friction = 0.2
            authored_friction_vector = @(0.2)
            material_profile_id = "rapier_bw19v_xv2_mu020_v1"
            worker_schema = (
                "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_rapier_cell_v1"
            )
            cold_schema = (
                "sporespore_cross_engine_c6_bw19v_xv2_rapier_cold_evaluation_v1"
            )
            trace_step_count = 3172
        },
        [ordered]@{
            ordinal = 2
            cell_id = "rapier_mu060"
            engine = "rapier"
            engine_version = "0.34.0"
            authored_sliding_friction = 0.6
            authored_friction_vector = @(0.6)
            material_profile_id = "rapier_bw19v_xv2_mu060_v1"
            worker_schema = (
                "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_rapier_cell_v1"
            )
            cold_schema = (
                "sporespore_cross_engine_c6_bw19v_xv2_rapier_cold_evaluation_v1"
            )
            trace_step_count = 3172
        },
        [ordered]@{
            ordinal = 3
            cell_id = "rapier_mu100"
            engine = "rapier"
            engine_version = "0.34.0"
            authored_sliding_friction = 1.0
            authored_friction_vector = @(1.0)
            material_profile_id = "rapier_bw19v_xv2_mu100_v1"
            worker_schema = (
                "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_rapier_cell_v1"
            )
            cold_schema = (
                "sporespore_cross_engine_c6_bw19v_xv2_rapier_cold_evaluation_v1"
            )
            trace_step_count = 3172
        },
        [ordered]@{
            ordinal = 4
            cell_id = "mujoco_mu020"
            engine = "mujoco"
            engine_version = "3.11.0"
            authored_sliding_friction = 0.2
            authored_friction_vector = @(0.2, 0.0, 0.0)
            material_profile_id = "mujoco_bw19v_xv2_mu020_v1"
            worker_schema = (
                "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_mujoco_cell_v1"
            )
            cold_schema = (
                "sporespore_cross_engine_c6_bw19v_xv2_mujoco_cold_evaluation_v1"
            )
            trace_step_count = 2992
        },
        [ordered]@{
            ordinal = 5
            cell_id = "mujoco_mu060"
            engine = "mujoco"
            engine_version = "3.11.0"
            authored_sliding_friction = 0.6
            authored_friction_vector = @(0.6, 0.0, 0.0)
            material_profile_id = "mujoco_bw19v_xv2_mu060_v1"
            worker_schema = (
                "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_mujoco_cell_v1"
            )
            cold_schema = (
                "sporespore_cross_engine_c6_bw19v_xv2_mujoco_cold_evaluation_v1"
            )
            trace_step_count = 2992
        },
        [ordered]@{
            ordinal = 6
            cell_id = "mujoco_mu100"
            engine = "mujoco"
            engine_version = "3.11.0"
            authored_sliding_friction = 1.0
            authored_friction_vector = @(1.0, 0.0, 0.0)
            material_profile_id = "mujoco_bw19v_xv2_mu100_v1"
            worker_schema = (
                "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_mujoco_cell_v1"
            )
            cold_schema = (
                "sporespore_cross_engine_c6_bw19v_xv2_mujoco_cold_evaluation_v1"
            )
            trace_step_count = 2992
        }
    )
}

function Add-Xv2Gate {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Gates,
        [Parameter(Mandatory)][int]$Ordinal,
        [Parameter(Mandatory)][string]$GateId,
        [Parameter(Mandatory)][bool]$Passed,
        [Parameter(Mandatory)][string]$FailureCode
    )

    $Gates.Add([ordered]@{
        ordinal = $Ordinal
        gate_id = $GateId
        passed = $Passed
        failure_code = $(if ($Passed) { $null } else { $FailureCode })
    })
}

function Test-Xv2Cell {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Cell,
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    $actualVector = @((Get-Xv2MapValue $Cell "authored_friction_vector" @()))
    $expectedVector = @($Expected.authored_friction_vector)
    $vectorPassed = $actualVector.Count -eq $expectedVector.Count
    if ($vectorPassed) {
        for ($index = 0; $index -lt $expectedVector.Count; $index++) {
            if (
                -not (Test-Xv2Finite $actualVector[$index]) -or
                [double]$actualVector[$index] -ne [double]$expectedVector[$index]
            ) {
                $vectorPassed = $false
                break
            }
        }
    }

    $reportPath = [string](Get-Xv2MapValue $Cell "report_path" "")
    $reportUnderAttemptRoot = $false
    try {
        $resolvedReport = [System.IO.Path]::GetFullPath($reportPath)
        $resolvedRoot = [System.IO.Path]::GetFullPath($EvidenceRoot).TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar
        ) + [System.IO.Path]::DirectorySeparatorChar
        $reportUnderAttemptRoot = $resolvedReport.StartsWith(
            $resolvedRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {
        $reportUnderAttemptRoot = $false
    }

    return (
        [int](Get-Xv2MapValue $Cell "ordinal" -1) -eq [int]$Expected.ordinal -and
        [string](Get-Xv2MapValue $Cell "cell_id" "") -ceq [string]$Expected.cell_id -and
        [string](Get-Xv2MapValue $Cell "engine" "") -ceq [string]$Expected.engine -and
        [string](Get-Xv2MapValue $Cell "engine_version" "") -ceq [string]$Expected.engine_version -and
        (Test-Xv2Finite (Get-Xv2MapValue $Cell "authored_sliding_friction" $null)) -and
        [double](Get-Xv2MapValue $Cell "authored_sliding_friction" -1) -eq
            [double]$Expected.authored_sliding_friction -and
        $vectorPassed -and
        [string](Get-Xv2MapValue $Cell "material_profile_id" "") -ceq
            [string]$Expected.material_profile_id -and
        [string](Get-Xv2MapValue $Cell "worker_report_schema_version" "") -ceq
            [string]$Expected.worker_schema -and
        [string](Get-Xv2MapValue $Cell "cold_evaluation_schema_version" "") -ceq
            [string]$Expected.cold_schema -and
        [string](Get-Xv2MapValue $Cell "source_commit" "") -ceq $SourceCommit -and
        $reportUnderAttemptRoot -and
        (Test-Xv2Sha256 (Get-Xv2MapValue $Cell "report_raw_sha256" "")) -and
        [int64](Get-Xv2MapValue $Cell "report_size_bytes" 0) -gt 0 -and
        [int](Get-Xv2MapValue $Cell "process_exit_code" -1) -eq 0 -and
        [bool](Get-Xv2MapValue $Cell "worker_report_ok" $false) -and
        [bool](Get-Xv2MapValue $Cell "cold_evaluator_replay_passed" $false) -and
        [int](Get-Xv2MapValue $Cell "cold_evaluator_failure_count" -1) -eq 0 -and
        [int](Get-Xv2MapValue $Cell "cold_evaluation_world_build_count" -1) -eq 0 -and
        [bool](Get-Xv2MapValue $Cell "worker_preflight_passed" $false) -and
        [int](Get-Xv2MapValue $Cell "worker_preflight_world_build_count" -1) -eq 0 -and
        [int](Get-Xv2MapValue $Cell "world_attempt_count" -1) -eq 1 -and
        [int](Get-Xv2MapValue $Cell "world_build_count" -1) -eq 1 -and
        [int](Get-Xv2MapValue $Cell "world_reset_count" -1) -eq 0 -and
        [int](Get-Xv2MapValue $Cell "trace_step_count" -1) -eq
            [int]$Expected.trace_step_count -and
        [int](Get-Xv2MapValue $Cell "gate_failure_count" -1) -eq 0 -and
        [int](Get-Xv2MapValue $Cell "integrity_failure_count" -1) -eq 0 -and
        [string](Get-Xv2MapValue $Cell "candidate_id" "") -ceq "BW19V-B" -and
        [string](Get-Xv2MapValue $Cell "candidate_composition_digest" "") -ceq
            $script:Xv2CandidateDigest -and
        [string](Get-Xv2MapValue $Cell "selected_policy_id" "") -ceq
            $script:Xv2PolicyId -and
        [string](Get-Xv2MapValue $Cell "selected_policy_digest" "") -ceq
            $script:Xv2PolicyDigest -and
        [string](Get-Xv2MapValue $Cell "terminal_restoration_policy_id" "") -ceq
            $script:Xv2RestorationPolicyId -and
        [bool](Get-Xv2MapValue $Cell "host_material_readback_passed" $false) -and
        [bool](Get-Xv2MapValue $Cell "terminal_four_contact_stance" $false) -and
        [bool](Get-Xv2MapValue $Cell "required_consecutive_hold_completed" $false) -and
        (Test-Xv2Finite (Get-Xv2MapValue $Cell "evidence_forward_displacement_m" $null)) -and
        (Test-Xv2Finite (Get-Xv2MapValue $Cell "final_forward_displacement_m" $null)) -and
        -not [bool](Get-Xv2MapValue $Cell "formal_cross_engine_equivalence" $true) -and
        -not [bool](Get-Xv2MapValue $Cell "continuous_friction_coverage" $true) -and
        -not [bool](Get-Xv2MapValue $Cell "arbitrary_material_robustness" $true) -and
        -not [bool](Get-Xv2MapValue $Cell "release_authorized" $true) -and
        -not [bool](Get-Xv2MapValue $Cell "physical_acceptance_authority" $true)
    )
}

function Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result {
    param([Parameter(Mandatory)][AllowNull()][object]$Result)

    $gates = [System.Collections.Generic.List[object]]::new()
    $source = Get-Xv2MapValue $Result "source" @{}
    $sourceCommit = [string](Get-Xv2MapValue $source "commit" "")
    $evidenceRoot = [string](Get-Xv2MapValue $Result "evidence_root" "")

    $identityPassed = (
        [string](Get-Xv2MapValue $Result "schema_version" "") -ceq
            $script:Xv2ResultSchema -and
        [string](Get-Xv2MapValue $Result "campaign_id" "") -ceq
            $script:Xv2CampaignId -and
        [string](Get-Xv2MapValue $Result "gate_id" "") -ceq $script:Xv2GateId -and
        [string](Get-Xv2MapValue $Result "study_classification" "") -ceq
            "exact_finite_cell_successor_validation_after_implementation_invalid_incomplete_predecessor" -and
        [int](Get-Xv2MapValue $Result "expected_gate_count" -1) -eq 12 -and
        [int](Get-Xv2MapValue $Result "expected_world_count" -1) -eq 6 -and
        [int](Get-Xv2MapValue $Result "expected_cell_count" -1) -eq 6 -and
        [string](Get-Xv2MapValue $Result "attempt_id" "") -cmatch '^[0-9a-f]{32}$'
    )
    Add-Xv2Gate $gates 1 "receipt_identity" $identityPassed `
        "C6_XE_BW19V_XV2_RECEIPT_IDENTITY"

    $sourcePassed = (
        (Test-Xv2Commit $sourceCommit) -and
        (Test-Xv2Commit (Get-Xv2MapValue $source "tree_git_oid" "")) -and
        [bool](Get-Xv2MapValue $source "clean" $false) -and
        [bool](Get-Xv2MapValue $source "matches_origin_main" $false) -and
        [bool](Get-Xv2MapValue $source "matches_live_github_main" $false) -and
        [bool](Get-Xv2MapValue $Result "final_integrity_passed" $false) -and
        (Test-Xv2AbsoluteEvidencePath $evidenceRoot)
    )
    Add-Xv2Gate $gates 2 "source_and_evidence_root" $sourcePassed `
        "C6_XE_BW19V_XV2_SOURCE"

    $authority = Get-Xv2MapValue $Result "bound_authority_raw_sha256" @{}
    $authorityPassed = (
        [string](Get-Xv2MapValue $Result "preregistration_raw_sha256" "") -ceq
            $script:Xv2PreregistrationSha256 -and
        [string](Get-Xv2MapValue $authority "cross_engine_host_characterization_r2" "") -ceq
            $script:Xv2HostCharacterizationSha256 -and
        [string](Get-Xv2MapValue $authority "rapier_spv1" "") -ceq
            $script:Xv2RapierSpv1Sha256 -and
        [string](Get-Xv2MapValue $authority "rapier_vh1" "") -ceq
            $script:Xv2RapierVh1Sha256 -and
        [string](Get-Xv2MapValue $authority "rapier_ph1" "") -ceq
            $script:Xv2RapierPh1Sha256 -and
        [string](Get-Xv2MapValue $authority "mujoco_vh5" "") -ceq
            $script:Xv2MujocoVh5Sha256 -and
        [string](Get-Xv2MapValue $authority "mujoco_mv6" "") -ceq
            $script:Xv2MujocoMv6Sha256 -and
        [string](Get-Xv2MapValue $authority "cross_engine_xv1_no_result" "") -ceq
            $script:Xv2Xv1ClosureSha256
    )
    Add-Xv2Gate $gates 3 "bound_authorities" $authorityPassed `
        "C6_XE_BW19V_XV2_AUTHORITY"

    $attestation = Get-Xv2MapValue $Result "full_godot_v2_attestation" @{}
    $attestationPassed = (
        (Test-Xv2AbsoluteEvidencePath (Get-Xv2MapValue $attestation "path" "")) -and
        (Test-Xv2Sha256 (Get-Xv2MapValue $attestation "raw_sha256" "")) -and
        [string](Get-Xv2MapValue $attestation "source_commit" "") -ceq $sourceCommit -and
        [string](Get-Xv2MapValue $attestation "source_tree_git_oid" "") -ceq
            [string](Get-Xv2MapValue $source "tree_git_oid" "") -and
        [bool](Get-Xv2MapValue $attestation "complete_suite_passed" $false) -and
        [bool](Get-Xv2MapValue $attestation "independent_file_verifier_passed" $false) -and
        [int](Get-Xv2MapValue $attestation "verifier_failure_count" -1) -eq 0 -and
        -not [bool](Get-Xv2MapValue $attestation "physical_acceptance_authority" $true)
    )
    Add-Xv2Gate $gates 4 "full_godot_v2_attestation" $attestationPassed `
        "C6_XE_BW19V_XV2_FULL_GODOT_V2"

    $cells = @((Get-Xv2MapValue $Result "ordered_cells" @()))
    $expectedCells = @(Get-Xv2ExpectedCells)
    for ($index = 0; $index -lt $expectedCells.Count; $index++) {
        $cellPassed = $cells.Count -eq 6 -and (
            Test-Xv2Cell $cells[$index] $expectedCells[$index] $sourceCommit $evidenceRoot
        )
        Add-Xv2Gate $gates ($index + 5) (
            "cell_" + $expectedCells[$index].cell_id
        ) $cellPassed ("C6_XE_BW19V_XV2_CELL_" + $expectedCells[$index].cell_id.ToUpperInvariant())
    }

    $matrixPassed = (
        $cells.Count -eq 6 -and
        [int](Get-Xv2MapValue $Result "world_attempt_count" -1) -eq 6 -and
        [int](Get-Xv2MapValue $Result "world_build_count" -1) -eq 6 -and
        [int](Get-Xv2MapValue $Result "world_reset_count" -1) -eq 0 -and
        [int](Get-Xv2MapValue $Result "physical_process_launch_count" -1) -eq 6 -and
        [int](Get-Xv2MapValue $Result "replacement_process_count" -1) -eq 0 -and
        [bool](Get-Xv2MapValue $Result "all_six_cell_attempts_retained" $false) -and
        [bool](Get-Xv2MapValue $Result "global_physical_operation_lock_acquired" $false) -and
        [bool](Get-Xv2MapValue $Result "outcome_based_early_stop_used" $true) -eq $false -and
        [bool](Get-Xv2MapValue $Result "selective_rerun_or_replacement_used" $true) -eq $false
    )
    Add-Xv2Gate $gates 11 "whole_matrix_integrity" $matrixPassed `
        "C6_XE_BW19V_XV2_MATRIX"

    $claims = Get-Xv2MapValue $Result "claims" @{}
    $allPrerequisiteGatesPassed = @($gates | Where-Object {
        $_.ordinal -ge 1 -and $_.ordinal -le 11 -and $_.passed
    }).Count -eq 11
    $claimsPassed = (
        [bool](Get-Xv2MapValue $claims "accepted" $false) -eq $allPrerequisiteGatesPassed -and
        [bool](Get-Xv2MapValue $claims "exact_s169_rapier_three_material_validation" $false) -eq
            $allPrerequisiteGatesPassed -and
        [bool](Get-Xv2MapValue $claims "exact_s169_mujoco_three_material_validation" $false) -eq
            $allPrerequisiteGatesPassed -and
        [bool](Get-Xv2MapValue $claims "qsdk_r14_declared_exact_finite_grid" $false) -eq
            $allPrerequisiteGatesPassed -and
        [bool](Get-Xv2MapValue $claims "qsdk_r15_declared_exact_finite_grid" $false) -eq
            $allPrerequisiteGatesPassed -and
        [bool](Get-Xv2MapValue $claims "different_physics_engines_same_policy_exact_finite_validation" $false) -eq
            $allPrerequisiteGatesPassed -and
        [bool](Get-Xv2MapValue $claims "bounded_discrete_material_validation" $false) -eq
            $allPrerequisiteGatesPassed -and
        -not [bool](Get-Xv2MapValue $claims "formal_cross_engine_equivalence" $true) -and
        -not [bool](Get-Xv2MapValue $claims "trajectory_equivalence" $true) -and
        -not [bool](Get-Xv2MapValue $claims "continuous_friction_coverage" $true) -and
        -not [bool](Get-Xv2MapValue $claims "arbitrary_material_robustness" $true) -and
        -not [bool](Get-Xv2MapValue $claims "population_inference" $true) -and
        -not [bool](Get-Xv2MapValue $claims "arbitrary_quadruped_coverage" $true) -and
        -not [bool](Get-Xv2MapValue $claims "continuous_morphology_coverage" $true) -and
        -not [bool](Get-Xv2MapValue $claims "rough_terrain_robustness" $true) -and
        -not [bool](Get-Xv2MapValue $claims "external_push_recovery" $true) -and
        -not [bool](Get-Xv2MapValue $claims "sensor_noise_or_latency_robustness" $true) -and
        -not [bool](Get-Xv2MapValue $claims "release_authorized" $true) -and
        -not [bool](Get-Xv2MapValue $claims "completed_engine_neutral_sdk" $true) -and
        -not [bool](Get-Xv2MapValue $claims "physical_acceptance_authority" $true)
    )
    Add-Xv2Gate $gates 12 "claim_boundary" $claimsPassed `
        "C6_XE_BW19V_XV2_CLAIMS"

    $failureCodes = @(
        $gates |
            Where-Object { -not $_.passed } |
            ForEach-Object { $_.failure_code }
    )
    $accepted = $gates.Count -eq 12 -and $failureCodes.Count -eq 0
    return [ordered]@{
        schema_version = (
            "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_evaluation_v1"
        )
        campaign_id = $script:Xv2CampaignId
        gate_id = $script:Xv2GateId
        accepted = $accepted
        reconstructed_passed_gate_count = @($gates | Where-Object passed).Count
        reconstructed_failed_gate_count = @($gates | Where-Object { -not $_.passed }).Count
        expected_gate_count = 12
        failure_codes = $failureCodes
        gates = @($gates)
        claims = [ordered]@{
            exact_s169_rapier_three_material_validation = $accepted
            exact_s169_mujoco_three_material_validation = $accepted
            qsdk_r14_declared_exact_finite_grid = $accepted
            qsdk_r15_declared_exact_finite_grid = $accepted
            different_physics_engines_same_policy_exact_finite_validation = $accepted
            bounded_discrete_material_validation = $accepted
            formal_cross_engine_equivalence = $false
            continuous_friction_coverage = $false
            arbitrary_material_robustness = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
            physical_acceptance_authority = $false
        }
    }
}

function New-Xv2PerfectSyntheticResult {
    $sourceCommit = "0000000000000000000000000000000000000000"
    $treeOid = "1111111111111111111111111111111111111111"
    $evidenceRoot = Join-Path $script:Xv2EvidencePrefix "xv2-synthetic-zero-world"
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($expected in (Get-Xv2ExpectedCells)) {
        $cells.Add([ordered]@{
            ordinal = $expected.ordinal
            cell_id = $expected.cell_id
            engine = $expected.engine
            engine_version = $expected.engine_version
            authored_sliding_friction = $expected.authored_sliding_friction
            authored_friction_vector = @($expected.authored_friction_vector)
            material_profile_id = $expected.material_profile_id
            worker_report_schema_version = $expected.worker_schema
            cold_evaluation_schema_version = $expected.cold_schema
            source_commit = $sourceCommit
            report_path = Join-Path $evidenceRoot ("cells\" + $expected.cell_id + "\report.json")
            report_raw_sha256 = ("sha256:" + ("2" * 64))
            report_size_bytes = 1
            process_exit_code = 0
            worker_report_ok = $true
            cold_evaluator_replay_passed = $true
            cold_evaluator_failure_count = 0
            cold_evaluation_world_build_count = 0
            worker_preflight_passed = $true
            worker_preflight_world_build_count = 0
            world_attempt_count = 1
            world_build_count = 1
            world_reset_count = 0
            trace_step_count = $expected.trace_step_count
            gate_failure_count = 0
            integrity_failure_count = 0
            candidate_id = "BW19V-B"
            candidate_composition_digest = $script:Xv2CandidateDigest
            selected_policy_id = $script:Xv2PolicyId
            selected_policy_digest = $script:Xv2PolicyDigest
            terminal_restoration_policy_id = $script:Xv2RestorationPolicyId
            host_material_readback_passed = $true
            terminal_four_contact_stance = $true
            required_consecutive_hold_completed = $true
            evidence_forward_displacement_m = 1.0
            final_forward_displacement_m = 1.1
            formal_cross_engine_equivalence = $false
            continuous_friction_coverage = $false
            arbitrary_material_robustness = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        })
    }
    return [ordered]@{
        schema_version = $script:Xv2ResultSchema
        campaign_id = $script:Xv2CampaignId
        gate_id = $script:Xv2GateId
        study_classification = "exact_finite_cell_successor_validation_after_implementation_invalid_incomplete_predecessor"
        expected_gate_count = 12
        expected_world_count = 6
        expected_cell_count = 6
        attempt_id = "3" * 32
        evidence_root = $evidenceRoot
        source = [ordered]@{
            commit = $sourceCommit
            tree_git_oid = $treeOid
            clean = $true
            matches_origin_main = $true
            matches_live_github_main = $true
        }
        final_integrity_passed = $true
        final_integrity_failure_codes = @()
        preregistration_raw_sha256 = $script:Xv2PreregistrationSha256
        bound_authority_raw_sha256 = [ordered]@{
            cross_engine_host_characterization_r2 = $script:Xv2HostCharacterizationSha256
            rapier_spv1 = $script:Xv2RapierSpv1Sha256
            rapier_vh1 = $script:Xv2RapierVh1Sha256
            rapier_ph1 = $script:Xv2RapierPh1Sha256
            mujoco_vh5 = $script:Xv2MujocoVh5Sha256
            mujoco_mv6 = $script:Xv2MujocoMv6Sha256
            cross_engine_xv1_no_result = $script:Xv2Xv1ClosureSha256
        }
        full_godot_v2_attestation = [ordered]@{
            path = Join-Path $evidenceRoot "attestation.json"
            raw_sha256 = ("sha256:" + ("4" * 64))
            source_commit = $sourceCommit
            source_tree_git_oid = $treeOid
            complete_suite_passed = $true
            independent_file_verifier_passed = $true
            verifier_failure_count = 0
            physical_acceptance_authority = $false
        }
        ordered_cells = @($cells)
        world_attempt_count = 6
        world_build_count = 6
        world_reset_count = 0
        physical_process_launch_count = 6
        replacement_process_count = 0
        all_six_cell_attempts_retained = $true
        global_physical_operation_lock_acquired = $true
        outcome_based_early_stop_used = $false
        selective_rerun_or_replacement_used = $false
        claims = [ordered]@{
            accepted = $true
            exact_s169_rapier_three_material_validation = $true
            exact_s169_mujoco_three_material_validation = $true
            qsdk_r14_declared_exact_finite_grid = $true
            qsdk_r15_declared_exact_finite_grid = $true
            different_physics_engines_same_policy_exact_finite_validation = $true
            bounded_discrete_material_validation = $true
            formal_cross_engine_equivalence = $false
            trajectory_equivalence = $false
            continuous_friction_coverage = $false
            arbitrary_material_robustness = $false
            population_inference = $false
            arbitrary_quadruped_coverage = $false
            continuous_morphology_coverage = $false
            rough_terrain_robustness = $false
            external_push_recovery = $false
            sensor_noise_or_latency_robustness = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
            physical_acceptance_authority = $false
        }
    }
}

function Invoke-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Preflight {
    $perfect = New-Xv2PerfectSyntheticResult
    $evaluation = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result $perfect
    $roundTrip = $perfect | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
    $roundTripEvaluation = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result $roundTrip

    $controls = [ordered]@{}
    $mutations = [ordered]@{
        missing_cell = { param($value) $value.ordered_cells = @($value.ordered_cells)[0..4] }
        wrong_order = { param($value) $temp = $value.ordered_cells[0]; $value.ordered_cells[0] = $value.ordered_cells[1]; $value.ordered_cells[1] = $temp }
        duplicate_cell = { param($value) $value.ordered_cells[1].cell_id = $value.ordered_cells[0].cell_id }
        wrong_engine = { param($value) $value.ordered_cells[0].engine = "mujoco" }
        wrong_engine_version = { param($value) $value.ordered_cells[3].engine_version = "3.10.0" }
        wrong_material_value = { param($value) $value.ordered_cells[0].authored_sliding_friction = 0.6 }
        wrong_material_vector = { param($value) $value.ordered_cells[3].authored_friction_vector = @(0.2, 0.005, 0.0001) }
        wrong_material_profile = { param($value) $value.ordered_cells[0].material_profile_id = "wrong" }
        wrong_worker_schema = { param($value) $value.ordered_cells[0].worker_report_schema_version = "wrong" }
        worker_failure = { param($value) $value.ordered_cells[0].worker_report_ok = $false }
        cold_replay_failure = { param($value) $value.ordered_cells[3].cold_evaluator_replay_passed = $false }
        source_mismatch = { param($value) $value.ordered_cells[0].source_commit = "f" * 40 }
        dirty_source = { param($value) $value.source.clean = $false }
        frozen_file_drift = { param($value) $value.final_integrity_passed = $false }
        wrong_preregistration = { param($value) $value.preregistration_raw_sha256 = "sha256:" + ("f" * 64) }
        wrong_authority = { param($value) $value.bound_authority_raw_sha256.cross_engine_xv1_no_result = "sha256:" + ("f" * 64) }
        bad_attestation = { param($value) $value.full_godot_v2_attestation.complete_suite_passed = $false }
        wrong_trace_count = { param($value) $value.ordered_cells[3].trace_step_count = 3172 }
        nonfinite_metric = { param($value) $value.ordered_cells[0].evidence_forward_displacement_m = [double]::NaN }
        boolean_metric = { param($value) $value.ordered_cells[0].evidence_forward_displacement_m = $true }
        claim_suppression = { param($value) $value.claims.accepted = $false }
        claim_inflation = { param($value) $value.claims.formal_cross_engine_equivalence = $true }
    }
    foreach ($entry in $mutations.GetEnumerator()) {
        $candidate = $perfect | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
        & $entry.Value $candidate
        $candidateEvaluation = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result $candidate
        $controls[$entry.Key] = -not [bool]$candidateEvaluation.accepted
    }
    $allControlsRejected = @($controls.Values | Where-Object { -not $_ }).Count -eq 0
    $ok = (
        [bool]$evaluation.accepted -and
        [bool]$roundTripEvaluation.accepted -and
        $mutations.Count -eq 22 -and
        $allControlsRejected
    )
    return [ordered]@{
        schema_version = (
            "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_preflight_v1"
        )
        campaign_id = $script:Xv2CampaignId
        gate_id = $script:Xv2GateId
        ok = $ok
        perfect_synthetic_result_passed = [bool]$evaluation.accepted
        serialization_round_trip_passed = [bool]$roundTripEvaluation.accepted
        negative_control_count = $mutations.Count
        all_negative_controls_rejected = $allControlsRejected
        negative_control_results = $controls
        rapier_declared_material_cell_count = 3
        mujoco_declared_material_cell_count = 3
        model_or_world_build_count = 0
        scene_insertion_count = 0
        physics_state_mutation_count = 0
        locomotion_outcome_exposed = $false
        physical_acceptance_authority = $false
    }
}
