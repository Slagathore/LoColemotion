#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
. (Join-Path $sdkRoot "experiment_result_integrity.ps1")
$selector = Join-Path $sdkRoot "compile_balanced_wave_bw16s_selection.ps1"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw16s_morphology_development_preregistration.json"
)
$tempRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) "sporespore_bw16s_selector_$([Guid]::NewGuid().ToString('N'))"

$candidateIds = @("BW16S-A", "BW16S-B")
$stabilityPolicyIds = @(
    "p5i3b_weight_support_shadow_v1",
    "p5i3c_support_centroid_tilt_feedback_v1"
)
$authorityScopes = @(
    "post_settle_full",
    "stability_contribution_overlay"
)
$compositionDigests = @(
    "sha256:5fdd2fae60409d31fb66c7152cecf7123e8cf410c56dd902a21ea90aad037bce",
    "sha256:e77f0ab9a8828a95c1c6d30003a381b5d4a8386a4ff49df270fcf31b86e0c94c"
)
$controllerPolicyId = "sporespore_balanced_wave_bw15f_b_v1"
$controllerPolicyDigest = (
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
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
                generator_index = 193 + [math]::Floor($index / 3)
                campaign_seed = 38101 + ($index % 3)
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
    $results = New-Results -WalkingFailureCount $WalkingFailureCount
    $metrics = Measure-SporeExperimentResults `
        -Results $results `
        -ExpectedCount 36
    return [ordered]@{
        schema_version = "sporespore_bw16s_morphology_development_report_v1"
        campaign_id = "BW16S-MORPHOLOGY-DEVELOPMENT"
        gate_id = "BW16S"
        campaign_role = (
            "paired_outcome_exposed_portable_balance_composition_development"
        )
        candidate_id = $candidateId
        candidate_composition_digest = $compositionDigests[$CandidateIndex]
        selected_candidate_id = "BW15F-B"
        controller_policy_id = $controllerPolicyId
        controller_policy_digest = $controllerPolicyDigest
        stability_policy_id = $stabilityPolicyIds[$CandidateIndex]
        authority_scope = $authorityScopes[$CandidateIndex]
        development_complete = $true
        development_data_only = $true
        walking_acceptance = $false
        balance_improvement = $false
        independent_morphology_validation = $false
        expected_world_count = 36
        source = [ordered]@{
            commit = "synthetic_bw16s_source"
            origin_main_commit = "synthetic_bw16s_source"
            clean = $true
            matches_origin_main = $true
        }
        preregistration = [ordered]@{
            sha256 = Get-PrefixedSha256 $preregistrationPath
            status = "frozen_before_first_bw16s_physics_world"
        }
        metrics = $metrics
        results = $results
        observed_world_count = 36
        complete_receipt_count = 36
        harness_pass_count = 36
        integrity_pass_count = 36
        full_integrity_preflight = [ordered]@{
            passed = $true
        }
        experiment_result_integrity_preflight = [ordered]@{
            passed = $true
            perfect_all_zero_36_cell_matrix_passed = $true
            perfect_failed_production_walking_gate_count = 0
            perfect_release_timeout_count = 0
            nonzero_ordered_dictionary_canary_passed = $true
            nonzero_canary_failed_production_walking_gate_count = 3
            nonzero_canary_release_timeout_count = 2
            nonzero_canary_maximum_normalized_lateral_displacement = 1.25
            nonzero_canary_aggregate_normalized_lateral_displacement = 1.75
            nonzero_canary_aggregate_cross_track_error_m_s = 1.0
        }
        r05c_closure_preflight = [ordered]@{
            passed = $true
        }
        candidate_authority_preflight = [ordered]@{
            passed = $true
            candidate_id = $candidateId
        }
        selector_preflight = [ordered]@{
            passed = $true
            test_path = "tests/test_bw16s_selector.ps1"
        }
        bw16s_entrypoint_preflight = [ordered]@{
            passed = $true
            candidate_id = $candidateId
            cell_count = 36
            exact_candidate_adapter_start_count = 36
            exact_declared_policy_runtime_boundary_count = 36
        }
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        material_robustness = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        different_physics_engines = $false
        running = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Invoke-Selector {
    param(
        [Parameter(Mandatory)]
        [string]$Control,
        [Parameter(Mandatory)]
        [string]$Treatment,
        [Parameter(Mandatory)]
        [string]$Output
    )
    & $selector `
        -ReportA $Control `
        -ReportB $Treatment `
        -Output $Output `
        -SyntheticTestOnly
}

try {
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $reportA = Join-Path $tempRoot "report-a.json"
    $reportB = Join-Path $tempRoot "report-b.json"

    Write-Json -Path $reportA -Value (
        New-Report -CandidateIndex 0 -WalkingFailureCount 2
    )
    Write-Json -Path $reportB -Value (
        New-Report -CandidateIndex 1 -WalkingFailureCount 1
    )
    $winOutput = Join-Path $tempRoot "win\selection.json"
    Invoke-Selector -Control $reportA -Treatment $reportB -Output $winOutput
    $win = (
        Get-Content -Raw -LiteralPath $winOutput |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [bool]$win.family_selected -and
        [string]$win.selected_candidate_id -ceq "BW16S-B" -and
        [int]$win.treatment_lexicographic_comparison_to_control -eq -1 -and
        [string]$win.deciding_metric -ceq
            "walking_conjunction_failure_count" -and
        [string]$win.result_status -ceq
            "development_balance_composition_selected_requires_new_independent_validation" -and
        [bool]$win.requires_new_prospectively_frozen_unopened_independent_validation -and
        [bool]$win.synthetic_selector_test -and
        -not [bool]$win.walking_acceptance -and
        -not [bool]$win.balance_improvement -and
        -not [bool]$win.independent_morphology_validation -and
        -not [bool]$win.physical_acceptance_authority
    ) "A strict BW16S treatment win did not retain the frozen no-claim boundary"

    Write-Json -Path $reportA -Value (
        New-Report -CandidateIndex 0 -WalkingFailureCount 0
    )
    Write-Json -Path $reportB -Value (
        New-Report -CandidateIndex 1 -WalkingFailureCount 0
    )
    $tieOutput = Join-Path $tempRoot "tie\selection.json"
    Invoke-Selector -Control $reportA -Treatment $reportB -Output $tieOutput
    $tie = (
        Get-Content -Raw -LiteralPath $tieOutput |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        -not [bool]$tie.family_selected -and
        [string]$tie.selected_candidate_id -ceq "" -and
        [int]$tie.treatment_lexicographic_comparison_to_control -eq 0 -and
        [string]$tie.deciding_metric -ceq "exact_tie" -and
        [string]$tie.result_status -ceq
            "bw16s_family_rejected_treatment_tied_control"
    ) "A BW16S control tie did not reject the treatment"

    Write-Json -Path $reportA -Value (
        New-Report -CandidateIndex 0 -WalkingFailureCount 0
    )
    Write-Json -Path $reportB -Value (
        New-Report -CandidateIndex 1 -WalkingFailureCount 1
    )
    $lossOutput = Join-Path $tempRoot "loss\selection.json"
    Invoke-Selector -Control $reportA -Treatment $reportB -Output $lossOutput
    $loss = (
        Get-Content -Raw -LiteralPath $lossOutput |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        -not [bool]$loss.family_selected -and
        [int]$loss.treatment_lexicographic_comparison_to_control -eq 1 -and
        [string]$loss.result_status -ceq
            "bw16s_family_rejected_treatment_worse_than_control"
    ) "A worse BW16S treatment was not rejected"

    $missingRejected = $false
    try {
        Invoke-Selector `
            -Control $reportA `
            -Treatment (Join-Path $tempRoot "missing-b.json") `
            -Output (Join-Path $tempRoot "missing\selection.json")
    } catch {
        $missingRejected = (
            $_.Exception.Message -like "*Missing BW16S-B report*"
        )
    }
    Assert-Exact $missingRejected "A missing BW16S treatment report was not rejected"

    $invalid = New-Report -CandidateIndex 1 -WalkingFailureCount 0
    $invalid.results[0].mechanism_gate_passed = $false
    $invalid.metrics = Measure-SporeExperimentResults `
        -Results @($invalid.results) `
        -ExpectedCount 36
    Write-Json -Path $reportB -Value $invalid
    $invalidRejected = $false
    try {
        Invoke-Selector `
            -Control $reportA `
            -Treatment $reportB `
            -Output (Join-Path $tempRoot "invalid\selection.json")
    } catch {
        $invalidRejected = (
            $_.Exception.Message -like
                "*not a complete eligible BW16S report*"
        )
    }
    Assert-Exact (
        $invalidRejected
    ) "A mechanism-incomplete BW16S treatment report was not rejected"

    Write-Host (
        "BW16S selector tests passed: strict treatment win, tie/loss " +
        "rejection, missing-report rejection, and mechanism fail-closed."
    )
} finally {
    $tempBase = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::GetTempPath()
    )
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    if (
        (Test-Path -LiteralPath $resolvedTempRoot) -and
        $resolvedTempRoot.StartsWith(
            $tempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $resolvedTempRoot.Length -gt ($tempBase.Length + 20)
    ) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
    }
}
