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
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw7d_preregistration.json"
$outputPath = [System.IO.Path]::GetFullPath($Output)
$candidateOrder = @("BW7D-A", "BW7D-B", "BW7D-C", "BW7D-D")
$policyByCandidate = [ordered]@{
    "BW7D-A" = "sporespore_balanced_wave_bw7d_a_v1"
    "BW7D-B" = "sporespore_balanced_wave_bw7d_b_v1"
    "BW7D-C" = "sporespore_balanced_wave_bw7d_c_v1"
    "BW7D-D" = "sporespore_balanced_wave_bw7d_d_v1"
}
$digestByCandidate = [ordered]@{
    "BW7D-A" =
        "sha256:f02ce514f4afa074774c726155649c49fbf69ceaa953c518d6eaf418fc26cde0"
    "BW7D-B" =
        "sha256:a5e58cd49f90af2d4c404478fbd25dd64b632df707e364aea3b9163268431424"
    "BW7D-C" =
        "sha256:c3ef32cb4688dec23a2e01284fc73defe6cecbbed3738faaa6fb0779ea749b6a"
    "BW7D-D" =
        "sha256:4700b9b7a5ea5379d8839103c04965fe6b4053b8e6adc830b50c6a7b5ff94003"
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
) "BW7D family closure requires exactly four candidate reports"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW7D preregistration is missing"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW7D selection filename must be exactly report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW7D selection report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW7D selection directory: $outputDirectory"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
) "BW7D selection requires a clean worktree"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceCommit -ceq $originMain
) "BW7D selection requires HEAD exactly matching origin/main"

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
        "sporespore_balanced_wave_bw7d_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw7d_physics_world" -and
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
) "BW7D preregistration selection contract is invalid"

$inputByCandidate = [ordered]@{}
$sourceCommitFromReports = ""
foreach ($pathValue in $Report) {
    $path = [System.IO.Path]::GetFullPath($pathValue)
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing BW7D candidate report: $path"
    $candidateReport = Get-Content -LiteralPath $path -Raw |
        ConvertFrom-Json -AsHashtable
    $candidate = [string]$candidateReport.candidate_id
    Assert-Exact (
        $candidateOrder -contains $candidate -and
        -not $inputByCandidate.Contains($candidate)
    ) "Duplicate or unknown BW7D candidate report: $candidate"
    if ([string]::IsNullOrWhiteSpace($sourceCommitFromReports)) {
        $sourceCommitFromReports = [string]$candidateReport.source_commit
    }
    Assert-Exact (
        [string]$candidateReport.schema_version -ceq
            "sporespore_balanced_wave_bw7d_development_report_v1" -and
        [bool]$candidateReport.source_worktree_clean -and
        [bool]$candidateReport.source_matches_origin_main -and
        [bool]$candidateReport.development_data_only -and
        [string]$candidateReport.source_commit -ceq $sourceCommitFromReports -and
        [string]$candidateReport.policy_id -ceq
            [string]$policyByCandidate[$candidate] -and
        [string]$candidateReport.candidate_policy_digest -ceq
            [string]$digestByCandidate[$candidate] -and
        [string]$candidateReport.receipt.schema_version -ceq
            "sporespore_balanced_wave_bw7d_development_receipt_v1" -and
        [string]$candidateReport.receipt.candidate_id -ceq $candidate -and
        [string]$candidateReport.receipt.policy_id -ceq
            [string]$policyByCandidate[$candidate] -and
        [string]$candidateReport.receipt.candidate_policy_digest -ceq
            [string]$digestByCandidate[$candidate] -and
        [int]$candidateReport.receipt.expected_world_count -eq 12 -and
        [int]$candidateReport.receipt.observed_world_count -eq 12 -and
        @($candidateReport.receipt.cells).Count -eq 12 -and
        [int]$candidateReport.receipt.acquisition_failure_count -eq 0 -and
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
        [int]$candidateReport.receipt.passed_gate_count -eq 21 -and
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
) "The BW7D report set is incomplete"

$allCandidateReportsComplete = @(
    $candidateOrder |
        Where-Object {
            -not [bool]$inputByCandidate[$_].report.complete
        }
).Count -eq 0
if ($allCandidateReportsComplete) {
    Assert-Exact (
        $sourceCommitFromReports -ceq $sourceCommit
    ) "BW7D selection requires candidate reports from the compiler source commit"
} else {
    & git -C $repoRoot merge-base --is-ancestor `
        $sourceCommitFromReports $sourceCommit
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW7D negative closure requires the compiler commit to descend from the experiment source"
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
        "sporespore_balanced_wave_bw7d_selection_report_v1"
    } else {
        "sporespore_balanced_wave_bw7d_family_closure_report_v1"
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
        path = "sdk/balanced_wave_bw7d_preregistration.json"
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
Write-Host "Retained BW7D selection report: $outputPath"
if (-not $selectionPerformed) {
    Write-Host (
        "BALANCED_WAVE_BW7D_SELECTION_PERFORMED=false " +
        "FAMILY_INVALIDATED_BY_INTEGRITY_FAILURE=true"
    )
} elseif ($familySelected) {
    Write-Host (
        "BALANCED_WAVE_BW7D_SELECTED=true " +
        "CANDIDATE=$([string]$selected.candidate_id)"
    )
} else {
    Write-Host "BALANCED_WAVE_BW7D_SELECTED=false FAMILY_REJECTED=true"
}
