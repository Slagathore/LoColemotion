#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$selector = Join-Path $repoRoot "sdk\compile_balanced_wave_bw13p_selection.ps1"
$tempBase = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
)
$testRoot = Join-Path $tempBase (
    "sporespore_bw13p_selector_test_" +
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
    $report = [ordered]@{
        schema_version = "sporespore_bw13p_morphology_development_report_v1"
        campaign_id = "BW13P-MORPHOLOGY-DEVELOPMENT"
        candidate_id = $CandidateId
        complete = $true
        candidate_mechanism_eligible = $true
        expected_world_count = 36
        metrics = [ordered]@{
            observed_world_count = 36
            complete_receipt_count = 36
            integrity_pass_count = 36
            mechanism_pass_count = 36
            combined_application_pass_count = 36
            integrity_and_mechanism_complete = $true
            walking_conjunction_failure_count = $MetricVector[0]
            aggregate_failed_production_walking_gate_count = $MetricVector[1]
            aggregate_release_timeout_count = $MetricVector[2]
            maximum_normalized_absolute_task_frame_lateral_displacement = (
                $MetricVector[3]
            )
            aggregate_normalized_absolute_task_frame_lateral_displacement = (
                $MetricVector[4]
            )
            aggregate_cumulative_absolute_cross_track_error_m_s = (
                $MetricVector[5]
            )
        }
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
        "BW13P_SELECTOR_TEST_PASS strict_treatment_win=true " +
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
