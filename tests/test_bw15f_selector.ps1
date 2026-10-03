#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
. (Join-Path $sdkRoot "experiment_result_integrity.ps1")
$selector = Join-Path $sdkRoot "compile_balanced_wave_bw15f_selection.ps1"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw15f_morphology_development_preregistration.json"
)
$tempRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) "sporespore_bw15f_selector_$([Guid]::NewGuid().ToString('N'))"

$candidateIds = @("BW15F-A", "BW15F-B", "BW15F-C", "BW15F-D")
$policyIds = @(
    "sporespore_balanced_wave_bw5r_b_v1",
    "sporespore_balanced_wave_bw15f_b_v1",
    "sporespore_balanced_wave_bw15f_c_v1",
    "sporespore_balanced_wave_bw15f_d_v1"
)
$policyDigests = @(
    "sha256:ac9fe7e62493ed2d21d3c95f0eb51cde45d7a53e7e22365ce422c68ad031a423",
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd",
    "sha256:7ba445b2756a8fc43e245334f3215fc77dd5c68142dd0be33a3dfeaf2c75433f",
    "sha256:f26320a4019a86f1ec700f297af12156a61ea41a026d489b69d1b649fafdcf60"
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

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$(
        (
            Get-FileHash -Algorithm SHA256 -LiteralPath $Path
        ).Hash.ToLowerInvariant()
    )"
}

function Write-Json {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [object]$Value
    )
    [void][System.IO.Directory]::CreateDirectory(
        (Split-Path -Parent $Path)
    )
    [System.IO.File]::WriteAllText(
        $Path,
        (
            $Value |
                ConvertTo-Json -Depth 100 |
                ForEach-Object { $_ + [Environment]::NewLine }
        ),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function New-Results {
    param([int]$WalkingFailureCount)
    $results = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt 36; $index += 1) {
        $walking = $index -ge $WalkingFailureCount
        $results.Add(
            [ordered]@{
                morphology_id = "synthetic_$index"
                generator_index = 181 + [math]::Floor($index / 3)
                campaign_seed = 21601 + ($index % 3)
                process_exit_code = 0
                timed_out = $false
                killed_process_tree = $false
                duration_seconds = 0.0
                receipt_parsed = $true
                receipt_parse_error = ""
                harness_passed = $true
                walking_observed = $walking
                common_execution_integrity = $true
                mechanism_gate_passed = $true
                combined_application_gate_passed = $true
                failed_production_walking_gate_count = $(if ($walking) {
                    0
                } else {
                    1
                })
                release_timeout_count = 0
                normalized_absolute_task_frame_lateral_displacement = 0.25
                cumulative_absolute_cross_track_error_m_s = 0.50
                receipt = [ordered]@{}
                transcript_path = "synthetic"
                transcript_sha256 = "sha256:synthetic"
                stderr_path = "synthetic"
                stderr_sha256 = "sha256:synthetic"
                engine_log_path = "synthetic"
                engine_log_sha256 = "sha256:synthetic"
            }
        )
    }
    return @($results)
}

function New-Report {
    param(
        [int]$CandidateIndex,
        [int]$WalkingFailureCount
    )
    $candidateId = $candidateIds[$CandidateIndex]
    $policyId = $policyIds[$CandidateIndex]
    $results = New-Results -WalkingFailureCount $WalkingFailureCount
    $metrics = Measure-SporeExperimentResults `
        -Results $results `
        -ExpectedCount 36
    return [ordered]@{
        schema_version = "sporespore_bw15f_morphology_development_report_v1"
        campaign_id = "BW15F-MORPHOLOGY-DEVELOPMENT"
        gate_id = "BW15F"
        campaign_role = (
            "paired_outcome_exposed_global_sign_gain_hypothesis_selection"
        )
        selected_candidate_id = $candidateId
        selected_policy_id = $policyId
        selected_policy_digest = $policyDigests[$CandidateIndex]
        development_complete = $true
        development_data_only = $true
        same_selected_policy_independent_morphology_evidence = $false
        expected_world_count = 36
        source = [ordered]@{
            commit = "synthetic_bw15f_source"
            origin_main_commit = "synthetic_bw15f_source"
            clean = $true
            matches_origin_main = $true
        }
        preregistration = [ordered]@{
            sha256 = Get-PrefixedSha256 $preregistrationPath
            status = "frozen_before_first_bw15f_physics_world"
        }
        metrics = $metrics
        results = $results
        observed_world_count = 36
        complete_receipt_count = 36
        harness_pass_count = 36
        integrity_pass_count = 36
        material_profile_id = "godot_jolt_bw5c_mu095_v1"
        authored_friction = 0.95
        full_integrity_preflight = [ordered]@{
            passed = $true
            scope = "baseline_regression_all_declared_bw13p_policies"
        }
        experiment_result_integrity_preflight = [ordered]@{
            passed = $true
            perfect_all_zero_36_cell_matrix_passed = $true
            perfect_observed_world_count = 36
            perfect_failed_production_walking_gate_count = 0
            perfect_release_timeout_count = 0
            nonzero_ordered_dictionary_canary_passed = $true
            nonzero_canary_failed_production_walking_gate_count = 3
            nonzero_canary_release_timeout_count = 2
            nonzero_canary_maximum_normalized_lateral_displacement = 1.25
            nonzero_canary_aggregate_normalized_lateral_displacement = 1.75
            nonzero_canary_aggregate_cross_track_error_m_s = 1.0
        }
        candidate_mechanism_preflight = [ordered]@{
            required = $true
            passed = $true
            candidate_id = $candidateId
            controller_policy_id = $policyId
        }
        candidate_selector_preflight = [ordered]@{
            required = $true
            passed = $true
            test_path = "tests/test_bw15f_selector.ps1"
            actual_world_build_count = 0
            physical_acceptance_authority = $false
        }
        bw15f_entrypoint_preflight = [ordered]@{
            passed = $true
            candidate_id = $candidateId
            controller_policy_id = $policyId
            cell_count = 36
            exact_candidate_full_authority_start_count = 36
            exact_candidate_declared_policy_runtime_boundary_count = 36
        }
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        material_robustness = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        running = $false
        cross_engine_c6 = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Invoke-Selector {
    param(
        [Parameter(Mandatory)]
        [string[]]$Reports,
        [Parameter(Mandatory)]
        [string]$Output
    )
    & $selector `
        -ReportA $Reports[0] `
        -ReportB $Reports[1] `
        -ReportC $Reports[2] `
        -ReportD $Reports[3] `
        -Output $Output `
        -SyntheticTestOnly
}

try {
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $reportPaths = @(
        0..3 | ForEach-Object {
            Join-Path $tempRoot "report-$_.json"
        }
    )

    # C and D tie for the best vector. The frozen treatment order must select
    # C, while still recording all three treatments as strictly above control.
    $failureCounts = @(2, 1, 0, 0)
    foreach ($index in 0..3) {
        Write-Json `
            -Path $reportPaths[$index] `
            -Value (
                New-Report `
                    -CandidateIndex $index `
                    -WalkingFailureCount $failureCounts[$index]
            )
    }
    $winOutput = Join-Path $tempRoot "win\selection.json"
    Invoke-Selector -Reports $reportPaths -Output $winOutput
    $win = (
        Get-Content -Raw -LiteralPath $winOutput |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [bool]$win.family_selected -and
        [string]$win.best_treatment_candidate_id -ceq "BW15F-C" -and
        [string]$win.selected_candidate_id -ceq "BW15F-C" -and
        (@($win.strictly_better_treatment_candidate_ids) -join ",") -ceq
            "BW15F-B,BW15F-C,BW15F-D" -and
        [string]$win.result_status -ceq
            "development_candidate_selected_requires_independent_validation" -and
        [bool]$win.requires_new_prospectively_frozen_independent_validation -and
        [bool]$win.reserved_qsdk_r05c_remains_unopened -and
        [bool]$win.synthetic_selector_test -and
        -not [bool]$win.walking_acceptance -and
        -not [bool]$win.independent_morphology_validation -and
        -not [bool]$win.physical_acceptance_authority
    ) "A strict four-arm treatment win did not retain the exact tie/no-claim rules"

    # A complete tie with control rejects the family; treatment tie order may
    # identify the best treatment for diagnostics but cannot authorize it.
    foreach ($index in 0..3) {
        Write-Json `
            -Path $reportPaths[$index] `
            -Value (
                New-Report `
                    -CandidateIndex $index `
                    -WalkingFailureCount 0
            )
    }
    $tieOutput = Join-Path $tempRoot "tie\selection.json"
    Invoke-Selector -Reports $reportPaths -Output $tieOutput
    $tie = (
        Get-Content -Raw -LiteralPath $tieOutput |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        -not [bool]$tie.family_selected -and
        [string]$tie.best_treatment_candidate_id -ceq "BW15F-B" -and
        [string]$tie.selected_candidate_id -ceq "" -and
        @($tie.strictly_better_treatment_candidate_ids).Count -eq 0 -and
        [string]$tie.result_status -ceq
            "bw15f_family_rejected_no_treatment_strictly_beat_control"
    ) "A control tie did not reject every BW15F treatment"

    $missingRejected = $false
    try {
        $missingReports = @($reportPaths)
        $missingReports[3] = Join-Path $tempRoot "missing-report-d.json"
        Invoke-Selector `
            -Reports $missingReports `
            -Output (Join-Path $tempRoot "missing\selection.json")
    } catch {
        $missingRejected = (
            $_.Exception.Message -like "*Missing BW15F-D report*"
        )
    }
    Assert-Exact $missingRejected "A missing fourth-arm report was not rejected"

    $invalid = New-Report -CandidateIndex 3 -WalkingFailureCount 0
    $invalid.selected_policy_id = "sporespore_wrong_policy_v1"
    Write-Json -Path $reportPaths[3] -Value $invalid
    $invalidRejected = $false
    try {
        Invoke-Selector `
            -Reports $reportPaths `
            -Output (Join-Path $tempRoot "invalid\selection.json")
    } catch {
        $invalidRejected = (
            $_.Exception.Message -like "*not a complete eligible BW15F report*"
        )
    }
    Assert-Exact $invalidRejected "An identity-invalid fourth-arm report was not rejected"

    Write-Host (
        "BW15F_SELECTOR_TEST_PASS strict_best_treatment=true " +
        "treatment_tie_order=true control_tie_rejects=true " +
        "missing_report_rejected=true invalid_report_rejected=true"
    )
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith(
            [System.IO.Path]::GetTempPath(),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
