#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$selector = Join-Path $repoRoot "sdk\compile_balanced_wave_bw13p_r3_selection.ps1"
. (Join-Path $repoRoot "sdk\experiment_result_integrity.ps1")
$tempBase = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
)
$testRoot = Join-Path $tempBase (
    "sporespore_bw13p_r3_selector_test_" +
    [Guid]::NewGuid().ToString("N")
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

function Write-SyntheticReport {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$CandidateId,
        [Parameter(Mandatory)]
        [string]$PolicyId,
        [Parameter(Mandatory)]
        [double[]]$MetricVector
    )
    $results = @(
        foreach ($ordinal in 1..36) {
            [ordered]@{
                ordinal = $ordinal
                timed_out = $false
                receipt_parsed = $true
                harness_passed = $true
                common_execution_integrity = $true
                mechanism_gate_passed = $true
                combined_application_gate_passed = $true
                walking_observed = $true
                failed_production_walking_gate_count = 0
                release_timeout_count = 0
                normalized_absolute_task_frame_lateral_displacement = 0.0
                cumulative_absolute_cross_track_error_m_s = 0.0
            }
        }
    )
    for (
        $index = 0;
        $index -lt [int]$MetricVector[0];
        $index += 1
    ) {
        $results[$index]["walking_observed"] = $false
    }
    $results[0]["failed_production_walking_gate_count"] = [int]$MetricVector[1]
    $results[0]["release_timeout_count"] = [int]$MetricVector[2]
    $results[0][
        "normalized_absolute_task_frame_lateral_displacement"
    ] = [double]$MetricVector[3]
    $remainingLateral = (
        [double]$MetricVector[4] - [double]$MetricVector[3]
    )
    Assert-Exact (
        $remainingLateral -ge 0.0 -and
        (
            [double]$MetricVector[3] -gt 0.0 -or
            $remainingLateral -eq 0.0
        )
    ) "Synthetic selector vector has an impossible lateral max/sum pair"
    $lateralIndex = 1
    while ($remainingLateral -gt 0.0) {
        Assert-Exact (
            $lateralIndex -lt 36
        ) "Synthetic selector vector needs more than 36 lateral cells"
        $chunk = [math]::Min(
            [double]$MetricVector[3],
            $remainingLateral
        )
        $results[$lateralIndex][
            "normalized_absolute_task_frame_lateral_displacement"
        ] = $chunk
        $remainingLateral -= $chunk
        $lateralIndex += 1
    }
    $results[0][
        "cumulative_absolute_cross_track_error_m_s"
    ] = [double]$MetricVector[5]
    $metrics = Measure-SporeExperimentResults `
        -Results $results `
        -ExpectedCount 36
    $report = [ordered]@{
        schema_version = "sporespore_bw13p_r3_morphology_development_report_v1"
        campaign_id = "BW13P-R3-MORPHOLOGY-DEVELOPMENT"
        candidate_id = $CandidateId
        complete = $true
        candidate_mechanism_eligible = $true
        expected_world_count = 36
        rejected_r1_family = [ordered]@{
            commit = "06a4ea6efecb91abbcbf73457375b51a1512f59b"
            closure_audit_passed = $true
            candidate_selection_forbidden = $true
            repair_or_rerun_forbidden = $true
        }
        rejected_r2_family = [ordered]@{
            commit = "35348c76cf063af08961a16d8f636fa4aa9278d7"
            closure_audit_passed = $true
            opened_world_count = 36
            reported_failed_gate_count = 0
            reconstructed_failed_gate_count = 1
            candidate_selection_forbidden = $true
            repair_resume_or_unopened_launch_forbidden = $true
        }
        preflight = [ordered]@{
            full_integrity_gate_passed = $true
            declared_policy_runtime_boundary_count = 8
            declared_policy_runtime_boundaries_passed = $true
            worst_case_runtime_horizon_passed = $true
            worst_case_runtime_horizon_step_count = 3232
            worst_case_native_controller_command_count = 25856
            r1_misroute_detected_before_world = $true
            rejected_r1_family_closure_verified = $true
            rejected_r2_family_closure_verified = $true
            experiment_result_integrity_preflight_passed = $true
            nonzero_aggregation_canary_passed = $true
            nonzero_aggregation_canary_failed_gate_count = 3
            nonzero_aggregation_canary_release_timeout_count = 2
        }
        metrics = $metrics
        results = $results
        walking_acceptance = $false
        independent_morphology_validation = $false
        physical_acceptance_authority = $false
        source = [ordered]@{
            commit = "synthetic-selector-test"
        }
        stability_policy_id = $PolicyId
        candidate_policy_digest = "sha256:synthetic-$CandidateId"
    }
    [System.IO.File]::WriteAllText(
        $Path,
        ($report | ConvertTo-Json -Depth 20),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-SelectionScenario {
    param(
        [Parameter(Mandatory)]
        [string]$Scenario,
        [Parameter(Mandatory)]
        [double[][]]$MetricVectors,
        [Parameter(Mandatory)]
        [bool]$ExpectedSelected,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ExpectedCandidate
    )
    $scenarioRoot = Join-Path $testRoot $Scenario
    [void][System.IO.Directory]::CreateDirectory($scenarioRoot)
    $candidateIds = @("BW13P-A", "BW13P-B", "BW13P-C", "BW13P-D")
    $policyIds = @(
        "sporespore_scheduled_load_transfer_bw13p_a_v3",
        "sporespore_scheduled_load_transfer_bw13p_b_v3",
        "sporespore_scheduled_load_transfer_bw13p_c_v3",
        "sporespore_scheduled_load_transfer_bw13p_d_v3"
    )
    $reportPaths = @()
    for ($index = 0; $index -lt 4; $index += 1) {
        $path = Join-Path $scenarioRoot "$($candidateIds[$index]).json"
        Write-SyntheticReport `
            -Path $path `
            -CandidateId $candidateIds[$index] `
            -PolicyId $policyIds[$index] `
            -MetricVector $MetricVectors[$index]
        $reportPaths += $path
    }
    $selectionPath = Join-Path (
        Join-Path $scenarioRoot "selection"
    ) "selection.json"
    & $selector `
        -ReportA $reportPaths[0] `
        -ReportB $reportPaths[1] `
        -ReportC $reportPaths[2] `
        -ReportD $reportPaths[3] `
        -Output $selectionPath
    $selectorSucceeded = $?
    Assert-Exact ($selectorSucceeded) "$Scenario selector process failed"
    $selection = (
        Get-Content -Raw -LiteralPath $selectionPath |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [bool]$selection.family_selected -eq $ExpectedSelected -and
        [string]$selection.selected_candidate_id -ceq $ExpectedCandidate -and
        [int]$selection.reports.Count -eq 4 -and
        -not [bool]$selection.walking_acceptance -and
        -not [bool]$selection.physical_acceptance_authority
    ) "$Scenario selector result failed strict reconciliation"
}

[void][System.IO.Directory]::CreateDirectory($testRoot)
try {
    Invoke-SelectionScenario `
        -Scenario "strict-treatment-win" `
        -MetricVectors @(
            [double[]]@(1, 1, 1, 1, 1, 1),
            [double[]]@(0, 9, 9, 9, 9, 9),
            [double[]]@(1, 0, 0, 0, 0, 0),
            [double[]]@(2, 0, 0, 0, 0, 0)
        ) `
        -ExpectedSelected $true `
        -ExpectedCandidate "BW13P-B"
    Invoke-SelectionScenario `
        -Scenario "no-treatment-win" `
        -MetricVectors @(
            [double[]]@(0, 0, 0, 0, 0, 0),
            [double[]]@(0, 0, 0, 0, 0, 0),
            [double[]]@(1, 0, 0, 0, 0, 0),
            [double[]]@(2, 0, 0, 0, 0, 0)
        ) `
        -ExpectedSelected $false `
        -ExpectedCandidate ""
    Write-Host (
        "BW13P_R3_SELECTOR_TEST_PASS strict_treatment_win=true " +
        "no_treatment_family_rejected=true"
    )
} finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    if (
        (Test-Path -LiteralPath $resolvedTestRoot) -and
        $resolvedTestRoot.StartsWith(
            $tempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $resolvedTestRoot.Length -gt ($tempBase.Length + 30)
    ) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
