#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Report,
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw9l_preregistration.json"
$outputPath = [System.IO.Path]::GetFullPath($Output)
$candidateOrder = @("BW9L-A", "BW9L-B", "BW9L-C", "BW9L-D")
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$policyByCandidate = [ordered]@{
    "BW9L-A" = "sporespore_scheduled_load_transfer_bw9l_a_v1"
    "BW9L-B" = "sporespore_scheduled_load_transfer_bw9l_b_v1"
    "BW9L-C" = "sporespore_scheduled_load_transfer_bw9l_c_v1"
    "BW9L-D" = "sporespore_scheduled_load_transfer_bw9l_d_v1"
}
$digestByCandidate = [ordered]@{
    "BW9L-A" =
        "sha256:36fff9ffbf953e121e3ea1e3f25ad66d6358be4c9e4bcba383231b9977d98320"
    "BW9L-B" =
        "sha256:ee964cfc22b19ce2aa5fb198c0d646a3bbaa562cd1916e7edd704033998210ff"
    "BW9L-C" =
        "sha256:efb7d388369692731a20c8b0670ad08e7f5fe1a3363ca2e0659969e40cdbe7dd"
    "BW9L-D" =
        "sha256:e3f3074fc39d4aee5f58a8c10cb8e680c802524df21f36ea0a1e5389b227067f"
}
$expectedMetricOrder = @(
    "infrastructure_and_integrity_failure_count:ascending",
    "opened_rough_release_timeout_count:ascending",
    "fresh_rough_release_timeout_count:ascending",
    "all_world_ordinary_nonwalk_count:ascending",
    "aggregate_walking_gate_failure_count:ascending",
    "aggregate_cumulative_absolute_cross_track_error_m_s:ascending",
    "maximum_absolute_task_frame_lateral_displacement_m:ascending"
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

function Get-Sha256 {
    param([string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-FalseGateCount {
    param([System.Collections.IDictionary]$Gates)
    Assert-Exact ($null -ne $Gates) "A walking-gate receipt is missing"
    return @(
        $Gates.GetEnumerator() |
            Where-Object { -not [bool]$_.Value }
    ).Count
}

Assert-Exact (
    $Report.Count -eq 4
) "BW9L family closure requires exactly four candidate reports"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW9L preregistration is missing"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW9L selection filename must be exactly report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW9L selection report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW9L selection directory: $outputDirectory"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
) "BW9L selection requires a clean worktree"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceCommit -ceq $originMain
) "BW9L selection requires HEAD exactly matching origin/main"

$preregistration = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable
$observedMetricOrder = @(
    $preregistration.selection.lexicographic_metrics |
        ForEach-Object {
            "$([string]$_['metric']):$([string]$_['direction'])"
        }
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw9l_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw9l_physics_world" -and
    (@($preregistration.candidate_order) -join ",") -ceq
        ($candidateOrder -join ",") -and
    ($observedMetricOrder -join ",") -ceq
        ($expectedMetricOrder -join ",") -and
    [string]$preregistration.selection.tie_rule -ceq
        "candidate_order_ascending" -and
    [bool]$preregistration.selection.all_candidates_must_complete_before_selection -and
    [bool]$preregistration.selection.selection_requires_zero_release_timeouts_and_zero_ordinary_nonwalks -and
    [int]$preregistration.development_matrix.expected_world_count_per_candidate -eq 12 -and
    [int]$preregistration.development_matrix.expected_complete_world_count -eq 48
) "BW9L preregistration selection contract is invalid"

$inputByCandidate = [ordered]@{}
$sourceCommitFromReports = ""
foreach ($pathValue in $Report) {
    $path = [System.IO.Path]::GetFullPath($pathValue)
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing BW9L candidate report: $path"
    $candidateReport = Get-Content -LiteralPath $path -Raw |
        ConvertFrom-Json -AsHashtable
    $candidate = [string]$candidateReport.candidate_id
    Assert-Exact (
        $candidateOrder -contains $candidate -and
        -not $inputByCandidate.Contains($candidate)
    ) "Duplicate or unknown BW9L candidate report: $candidate"
    if ([string]::IsNullOrWhiteSpace($sourceCommitFromReports)) {
        $sourceCommitFromReports = [string]$candidateReport.source_commit
    }
    Assert-Exact (
        [string]$candidateReport.schema_version -ceq
            "sporespore_balanced_wave_bw9l_development_report_v1" -and
        [bool]$candidateReport.source_worktree_clean -and
        [bool]$candidateReport.source_matches_origin_main -and
        [bool]$candidateReport.development_data_only -and
        [string]$candidateReport.source_commit -ceq $sourceCommitFromReports -and
        [string]$candidateReport.policy_id -ceq
            [string]$policyByCandidate[$candidate] -and
        [string]$candidateReport.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$candidateReport.candidate_policy_digest -ceq
            [string]$digestByCandidate[$candidate] -and
        [string]$candidateReport.receipt.schema_version -ceq
            "sporespore_balanced_wave_bw9l_development_receipt_v1" -and
        [string]$candidateReport.receipt.candidate_id -ceq $candidate -and
        [string]$candidateReport.receipt.policy_id -ceq
            [string]$policyByCandidate[$candidate] -and
        [string]$candidateReport.receipt.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$candidateReport.receipt.candidate_policy_digest -ceq
            [string]$digestByCandidate[$candidate] -and
        [int]$candidateReport.receipt.expected_world_count -eq 12 -and
        [int]$candidateReport.receipt.observed_world_count -eq 12 -and
        @($candidateReport.receipt.cells).Count -eq 12 -and
        [int]$candidateReport.receipt.acquisition_failure_count -eq 0 -and
        [int]$candidateReport.receipt.mechanism_receipt_failure_count -eq 0 -and
        [int]$candidateReport.receipt.nonzero_stability_world_count -eq 12 -and
        [string]$candidateReport.sources.preregistration.sha256 -ceq
            (Get-Sha256 $preregistrationPath) -and
        -not [bool]$candidateReport.walking_acceptance -and
        -not [bool]$candidateReport.cross_engine_c6 -and
        -not [bool]$candidateReport.completed_engine_neutral_sdk -and
        -not [bool]$candidateReport.physical_acceptance_authority
    ) "$candidate report is not a complete 12-world attempt or is source/identity mismatched"
    $integrityComplete = (
        [int]$candidateReport.godot_exit_code -eq 0 -and
        [bool]$candidateReport.receipt.ok -and
        [int]$candidateReport.receipt.passed_gate_count -eq 22 -and
        [int]$candidateReport.receipt.failed_gate_count -eq 0 -and
        [int]$candidateReport.receipt.integrity_failure_count -eq 0
    )
    if ([bool]$candidateReport.complete) {
        Assert-Exact (
            $integrityComplete -and
            [string]$candidateReport.result_status -ceq
                [string]$candidateReport.receipt.result_status
        ) "$candidate complete report disagrees with its execution receipt"
    } else {
        Assert-Exact (
            -not $integrityComplete -and
            [string]$candidateReport.result_status -ceq "incomplete" -and
            -not [bool]$candidateReport.candidate_eligible -and
            [int]$candidateReport.receipt.integrity_failure_count -gt 0
        ) "$candidate incomplete report is not an integrity-failed 12-world attempt"
    }
    $inputByCandidate[$candidate] = [ordered]@{
        path = $path
        sha256 = Get-Sha256 $path
        report = $candidateReport
    }
}
Assert-Exact (
    $inputByCandidate.Count -eq 4
) "The BW9L report set is incomplete"

$allCandidateReportsComplete = @(
    $candidateOrder |
        Where-Object {
            -not [bool]$inputByCandidate[$_].report.complete
        }
).Count -eq 0
if ($allCandidateReportsComplete) {
    Assert-Exact (
        $sourceCommitFromReports -ceq $sourceCommit
    ) "BW9L selection requires candidate reports from the compiler source commit"
} else {
    & git -C $repoRoot merge-base --is-ancestor `
        $sourceCommitFromReports $sourceCommit
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW9L negative closure requires the compiler commit to descend from the experiment source"
}

$metrics = @()
for ($candidateIndex = 0; $candidateIndex -lt $candidateOrder.Count; $candidateIndex++) {
    $candidate = $candidateOrder[$candidateIndex]
    $candidateReport = $inputByCandidate[$candidate].report
    $cells = @($candidateReport.receipt.cells)
    $openedRoughTimeouts = 0
    $freshRoughTimeouts = 0
    $ordinaryNonwalks = 0
    $walkingGateFailures = 0
    $crossTrackIntegral = 0.0
    $maximumAbsoluteLateral = 0.0
    foreach ($cell in $cells) {
        $partition = [string]$cell.partition
        $cohort = [string]$cell.cohort
        $timeouts = [int]$cell.release_timeout_count
        if ($partition -ceq "opened" -and $cohort -ceq "rough") {
            $openedRoughTimeouts += $timeouts
        }
        if ($partition -ceq "fresh" -and $cohort -ceq "rough") {
            $freshRoughTimeouts += $timeouts
        }
        if (-not [bool]$cell.ordinary_walking_gate_passed) {
            $ordinaryNonwalks += 1
        }
        $walkingGateFailures += Get-FalseGateCount $cell.walking_gate_receipts
        $cellIntegral = [double]$cell.cumulative_absolute_cross_track_error_m_s
        $lateral = [double]$cell.final_task_frame_lateral_displacement_m
        Assert-Exact (
            [double]::IsFinite($cellIntegral) -and
            $cellIntegral -ge 0.0 -and
            [double]::IsFinite($lateral)
        ) "$candidate has nonfinite selection metrics"
        $crossTrackIntegral += $cellIntegral
        $maximumAbsoluteLateral = [Math]::Max(
            $maximumAbsoluteLateral,
            [Math]::Abs($lateral)
        )
    }
    $integrityFailures = [int]$candidateReport.receipt.integrity_failure_count
    $eligible = (
        $allCandidateReportsComplete -and
        $integrityFailures -eq 0 -and
        $openedRoughTimeouts -eq 0 -and
        $freshRoughTimeouts -eq 0 -and
        $ordinaryNonwalks -eq 0 -and
        [bool]$candidateReport.candidate_eligible
    )
    $metrics += [pscustomobject][ordered]@{
        candidate_id = $candidate
        policy_id = [string]$policyByCandidate[$candidate]
        base_controller_policy_id = $baseControllerPolicyId
        candidate_policy_digest = [string]$digestByCandidate[$candidate]
        eligible = $eligible
        infrastructure_and_integrity_failure_count = $integrityFailures
        opened_rough_release_timeout_count = $openedRoughTimeouts
        fresh_rough_release_timeout_count = $freshRoughTimeouts
        all_world_ordinary_nonwalk_count = $ordinaryNonwalks
        aggregate_walking_gate_failure_count = $walkingGateFailures
        aggregate_cumulative_absolute_cross_track_error_m_s =
            $crossTrackIntegral
        maximum_absolute_task_frame_lateral_displacement_m =
            $maximumAbsoluteLateral
        candidate_order_index = $candidateIndex
    }
}

$selectionPerformed = $allCandidateReportsComplete
$eligibleMetrics = @($metrics | Where-Object { [bool]$_.eligible })
$ranked = @(
    $eligibleMetrics |
        Sort-Object `
            infrastructure_and_integrity_failure_count,
            opened_rough_release_timeout_count,
            fresh_rough_release_timeout_count,
            all_world_ordinary_nonwalk_count,
            aggregate_walking_gate_failure_count,
            aggregate_cumulative_absolute_cross_track_error_m_s,
            maximum_absolute_task_frame_lateral_displacement_m,
            candidate_order_index
)
$familySelected = $selectionPerformed -and $ranked.Count -gt 0
$selected = if ($familySelected) { $ranked[0] } else { $null }
$inputs = @()
foreach ($candidate in $candidateOrder) {
    $inputs += [ordered]@{
        candidate_id = $candidate
        path = [string]$inputByCandidate[$candidate].path
        sha256 = [string]$inputByCandidate[$candidate].sha256
    }
}
$candidateReportStatuses = @(
    $candidateOrder |
        ForEach-Object {
            $candidateReport = $inputByCandidate[$_].report
            [ordered]@{
                candidate_id = $_
                complete = [bool]$candidateReport.complete
                result_status = [string]$candidateReport.result_status
                godot_exit_code = [int]$candidateReport.godot_exit_code
                passed_gate_count =
                    [int]$candidateReport.receipt.passed_gate_count
                failed_gate_count =
                    [int]$candidateReport.receipt.failed_gate_count
                integrity_failure_count =
                    [int]$candidateReport.receipt.integrity_failure_count
                observed_world_count =
                    [int]$candidateReport.receipt.observed_world_count
            }
        }
)
$completeCandidateCount = @(
    $candidateReportStatuses | Where-Object { [bool]$_.complete }
).Count
$totalIntegrityFailureCount = 0
foreach ($candidateStatus in $candidateReportStatuses) {
    $totalIntegrityFailureCount +=
        [int]$candidateStatus.integrity_failure_count
}
$reportObject = [ordered]@{
    schema_version = $(if ($selectionPerformed) {
        "sporespore_balanced_wave_bw9l_selection_report_v1"
    } else {
        "sporespore_balanced_wave_bw9l_family_closure_report_v1"
    })
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommitFromReports
    compiler_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    development_data_only = $true
    attempted_candidate_count = 4
    complete_candidate_count = $completeCandidateCount
    observed_world_count = 48
    total_integrity_failure_count = $totalIntegrityFailureCount
    selection_performed = $selectionPerformed
    family_selected = $familySelected
    result_status = $(if (-not $selectionPerformed) {
        "candidate_family_invalidated_by_integrity_failure"
    } elseif ($familySelected) {
        "candidate_selected"
    } else {
        "candidate_family_rejected"
    })
    selected_candidate_id = $(if ($familySelected) {
        [string]$selected.candidate_id
    } else {
        $null
    })
    selected_policy_id = $(if ($familySelected) {
        [string]$selected.policy_id
    } else {
        $null
    })
    selected_base_controller_policy_id = $(if ($familySelected) {
        $baseControllerPolicyId
    } else {
        $null
    })
    selected_candidate_policy_digest = $(if ($familySelected) {
        [string]$selected.candidate_policy_digest
    } else {
        $null
    })
    selection_rule = [ordered]@{
        metrics = $expectedMetricOrder
        tie_rule = "candidate_order_ascending"
        eligibility =
            "zero integrity failures, zero release timeouts, and zero ordinary nonwalks"
    }
    candidate_metrics = @($metrics)
    candidate_report_statuses = $candidateReportStatuses
    eligible_candidate_count = $eligibleMetrics.Count
    inputs = $inputs
    preregistration = [ordered]@{
        path = "sdk/balanced_wave_bw9l_preregistration.json"
        sha256 = Get-Sha256 $preregistrationPath
    }
    development_selection_authority = $selectionPerformed
    development_family_rejection_authority = -not $familySelected
    walking_acceptance = $false
    material_robustness = $false
    rough_terrain_robustness = $false
    physical_balance_recovery = $false
    fresh_morphology_validation = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
}
[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$temporaryPath = "$outputPath.tmp"
$json = $reportObject | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)
Write-Host "Retained BW9L selection report: $outputPath"
if (-not $selectionPerformed) {
    Write-Host (
        "BALANCED_WAVE_BW9L_SELECTION_PERFORMED=false " +
        "FAMILY_INVALIDATED_BY_INTEGRITY_FAILURE=true"
    )
} elseif ($familySelected) {
    Write-Host (
        "BALANCED_WAVE_BW9L_SELECTED=true " +
        "CANDIDATE=$([string]$selected.candidate_id)"
    )
} else {
    Write-Host "BALANCED_WAVE_BW9L_SELECTED=false FAMILY_REJECTED=true"
}
