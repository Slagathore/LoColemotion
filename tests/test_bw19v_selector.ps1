#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$selector = Join-Path $sdkRoot "compile_balanced_wave_bw19v_selection.ps1"
$integrity = Join-Path $sdkRoot "experiment_result_integrity.ps1"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw19v_independent_validation_preregistration.json"
)
. $integrity

$candidateIds = @("BW19V-A", "BW19V-B")
$candidateDigests = @(
    "sha256:2eb8621882b4ae4047821aca415ab1b67de3399d0ab272a91f57fb0fc2ada7a4",
    "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
)
$globalScales = @(0.0, 0.5)
$applicationCounts = @(0, 36)
$tempRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) "sporespore_bw19v_selector_$([Guid]::NewGuid().ToString('N'))"

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Write-Json {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [object]$Value
    )
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
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

function New-SyntheticResults {
    param(
        [Parameter(Mandatory)]
        [int]$CandidateIndex,
        [Parameter(Mandatory)]
        [ValidateRange(0, 36)]
        [int]$WalkingFailureCount
    )
    $results = [System.Collections.Generic.List[object]]::new()
    $ordinal = 0
    foreach ($generatorIndex in 205..216) {
        foreach ($seed in @(39101, 39102, 39103)) {
            $walking = $ordinal -ge $WalkingFailureCount
            $application = $CandidateIndex -eq 1
            $results.Add(
                [ordered]@{
                    morphology_id = "bw19v_generated_s$generatorIndex"
                    seed = $seed
                    timed_out = $false
                    receipt_parsed = $true
                    harness_passed = $true
                    common_execution_integrity = $true
                    mechanism_gate_passed = $true
                    combined_application_gate_passed = $application
                    walking_observed = $walking
                    failed_production_walking_gate_count = $(
                        if ($walking) { 0 } else { 1 }
                    )
                    release_timeout_count = 0
                    normalized_absolute_task_frame_lateral_displacement = 0.0
                    cumulative_absolute_cross_track_error_m_s = 0.0
                    scale_contract_passed = $true
                    global_requested_correction_scale = (
                        [double]$globalScales[$CandidateIndex]
                    )
                }
            )
            $ordinal += 1
        }
    }
    return @($results)
}

function New-SyntheticReport {
    param(
        [Parameter(Mandatory)]
        [int]$CandidateIndex,
        [Parameter(Mandatory)]
        [ValidateRange(0, 36)]
        [int]$WalkingFailureCount
    )
    $results = New-SyntheticResults `
        -CandidateIndex $CandidateIndex `
        -WalkingFailureCount $WalkingFailureCount
    $metrics = Measure-SporePolicyRelativeExperimentResults `
        -Results $results `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount $applicationCounts[$CandidateIndex]
    return [ordered]@{
        schema_version = "sporespore_bw19v_independent_validation_report_v1"
        campaign_id = "BW19V-INDEPENDENT-MORPHOLOGY-VALIDATION"
        gate_id = "BW19V"
        campaign_role = "two_arm_prospective_independent_morphology_validation"
        candidate_id = $candidateIds[$CandidateIndex]
        candidate_composition_digest = $candidateDigests[$CandidateIndex]
        selected_candidate_id = "BW15F-B"
        controller_policy_id = "sporespore_balanced_wave_bw15f_b_v1"
        controller_policy_digest = (
            "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
        )
        stability_policy_id = "sporespore_scheduled_load_transfer_bw13p_a_v3"
        authority_scope = "post_settle_full"
        global_requested_correction_scale = (
            [double]$globalScales[$CandidateIndex]
        )
        expected_application_pass_count = (
            [int]$applicationCounts[$CandidateIndex]
        )
        stability_influence_operation = "bound_stability_influence_v3_json"
        source = [ordered]@{
            commit = "synthetic_bw19v_two_arm_source"
            origin_main_commit = "synthetic_bw19v_two_arm_source"
            clean = $true
            matches_origin_main = $true
        }
        preregistration = [ordered]@{
            path = $preregistrationPath
            sha256 = "sha256:$(
                (
                    Get-FileHash `
                        -Algorithm SHA256 `
                        -LiteralPath $preregistrationPath
                ).Hash.ToLowerInvariant()
            )"
            status = "frozen_before_first_bw19v_physics_world"
        }
        validation_execution_complete = $true
        walking_acceptance = $false
        balance_improvement = $false
        independent_morphology_validation = $false
        expected_world_count = 36
        observed_world_count = 36
        complete_receipt_count = 36
        harness_pass_count = 36
        integrity_pass_count = 36
        metrics = $metrics
        full_integrity_preflight = [ordered]@{ passed = $true }
        experiment_result_integrity_preflight = [ordered]@{
            passed = $true
            policy_relative_perfect_synthetic_gate_passed = $true
            expected_application_pass_count = (
                [int]$applicationCounts[$CandidateIndex]
            )
        }
        candidate_authority_preflight = [ordered]@{
            passed = $true
            candidate_id = $candidateIds[$CandidateIndex]
        }
        selector_preflight = [ordered]@{
            passed = $true
            test_path = "tests/test_bw19v_selector.ps1"
        }
        bw19v_entrypoint_preflight = [ordered]@{
            passed = $true
            candidate_id = $candidateIds[$CandidateIndex]
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
        results = $results
    }
}

function Invoke-SyntheticSelection {
    param(
        [Parameter(Mandatory)]
        [int]$ControlFailures,
        [Parameter(Mandatory)]
        [int]$TreatmentFailures,
        [Parameter(Mandatory)]
        [string]$Scenario
    )
    $scenarioRoot = Join-Path $tempRoot $Scenario
    $reportAPath = Join-Path $scenarioRoot "A\report.json"
    $reportBPath = Join-Path $scenarioRoot "B\report.json"
    $selectionPath = Join-Path $scenarioRoot "selection\selection.json"
    Write-Json `
        -Path $reportAPath `
        -Value (New-SyntheticReport -CandidateIndex 0 -WalkingFailureCount $ControlFailures)
    Write-Json `
        -Path $reportBPath `
        -Value (New-SyntheticReport -CandidateIndex 1 -WalkingFailureCount $TreatmentFailures)
    & $selector `
        -ReportA $reportAPath `
        -ReportB $reportBPath `
        -Output $selectionPath `
        -SyntheticTestOnly | Out-Null
    Assert-Exact `
        -Condition $? `
        -Message "$Scenario selector invocation failed"
    return (
        Get-Content -Raw -LiteralPath $selectionPath |
            ConvertFrom-Json -AsHashtable
    )
}

try {
    [void][System.IO.Directory]::CreateDirectory($tempRoot)

    $perfectTie = Invoke-SyntheticSelection `
        -ControlFailures 0 `
        -TreatmentFailures 0 `
        -Scenario "perfect-policy-relative-tie"
    Assert-Exact (
        -not [bool]$perfectTie.validation_hypothesis_confirmed -and
        [string]$perfectTie.result_status -ceq
            "bw19v_hypothesis_rejected_walking_failure_tie" -and
        [bool]$perfectTie.all_candidate_integrity_and_mechanism_complete -and
        [bool]$perfectTie.policy_relative_application_contract_complete
    ) "Perfect policy-relative synthetic inputs were not eligible and tie-rejected"

    $win = Invoke-SyntheticSelection `
        -ControlFailures 5 `
        -TreatmentFailures 2 `
        -Scenario "strict-win"
    Assert-Exact (
        [bool]$win.validation_hypothesis_confirmed -and
        [string]$win.selected_candidate_id -ceq "BW19V-B" -and
        [int]$win.control_minus_treatment_walking_failure_count -eq 3 -and
        [string]$win.result_status -ceq
            "finite_independent_validation_hypothesis_confirmed" -and
        [bool]$win.bounded_independent_validation_authority -and
        -not [bool]$win.arbitrary_quadruped_coverage -and
        -not [bool]$win.continuous_full_volume_coverage -and
        -not [bool]$win.physical_acceptance_authority
    ) "A strict treatment win did not retain the bounded BW19V claim boundary"

    $tie = Invoke-SyntheticSelection `
        -ControlFailures 5 `
        -TreatmentFailures 5 `
        -Scenario "failure-tie"
    Assert-Exact (
        -not [bool]$tie.validation_hypothesis_confirmed -and
        [string]$tie.selected_candidate_id -ceq "" -and
        [string]$tie.result_status -ceq
            "bw19v_hypothesis_rejected_walking_failure_tie"
    ) "A walking-failure tie did not reject the BW19V hypothesis"

    $worse = Invoke-SyntheticSelection `
        -ControlFailures 5 `
        -TreatmentFailures 6 `
        -Scenario "treatment-worse"
    Assert-Exact (
        -not [bool]$worse.validation_hypothesis_confirmed -and
        [string]$worse.result_status -ceq
            "bw19v_hypothesis_rejected_treatment_walking_failures_worse"
    ) "A worse treatment did not reject the BW19V hypothesis"

    $tamperRoot = Join-Path $tempRoot "tampered-control-application"
    $tamperAPath = Join-Path $tamperRoot "A\report.json"
    $tamperBPath = Join-Path $tamperRoot "B\report.json"
    $tamperedControl = New-SyntheticReport `
        -CandidateIndex 0 `
        -WalkingFailureCount 0
    $tamperedControl.results[0].combined_application_gate_passed = $true
    $tamperedControl.metrics = Measure-SporePolicyRelativeExperimentResults `
        -Results @($tamperedControl.results) `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount 0
    Write-Json -Path $tamperAPath -Value $tamperedControl
    Write-Json `
        -Path $tamperBPath `
        -Value (New-SyntheticReport -CandidateIndex 1 -WalkingFailureCount 0)
    $tamperRejected = $false
    try {
        & $selector `
            -ReportA $tamperAPath `
            -ReportB $tamperBPath `
            -Output (Join-Path $tamperRoot "selection\selection.json") `
            -SyntheticTestOnly | Out-Null
    } catch {
        $tamperRejected = (
            $_.Exception.Message -like
                "*not a complete eligible BW19V report*"
        )
    }
    Assert-Exact (
        $tamperRejected
    ) "A control with one forbidden nonzero application was not rejected"

    Write-Host (
        "BW19V_SELECTOR_TEST_PASS policy_relative_control=0/36 " +
        "policy_relative_treatment=36/36 perfect_tie=rejected " +
        "strict_win=confirmed failure_tie=rejected worse=rejected " +
        "application_tamper=rejected"
    )
} finally {
    $resolvedTempBase = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::GetTempPath()
    )
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    if (
        $resolvedTempRoot.StartsWith(
            $resolvedTempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        (Split-Path -Leaf $resolvedTempRoot).StartsWith(
            "sporespore_bw19v_selector_",
            [System.StringComparison]::Ordinal
        )
    ) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}
