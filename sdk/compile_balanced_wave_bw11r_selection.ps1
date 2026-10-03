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
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw11r_preregistration.json"
$outputPath = [System.IO.Path]::GetFullPath($Output)
$candidateOrder = @("BW11R-A", "BW11R-B", "BW11R-C", "BW11R-D")
$treatmentCandidates = @("BW11R-B", "BW11R-C", "BW11R-D")
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$policyByCandidate = [ordered]@{
    "BW11R-A" = "sporespore_scheduled_load_transfer_bw11r_a_v3"
    "BW11R-B" = "sporespore_scheduled_load_transfer_bw11r_b_v3"
    "BW11R-C" = "sporespore_scheduled_load_transfer_bw11r_c_v3"
    "BW11R-D" = "sporespore_scheduled_load_transfer_bw11r_d_v3"
}
$digestByCandidate = [ordered]@{
    "BW11R-A" =
        "sha256:673814d0d90499bac22c05b98af99097dfcc121cb0fcce896b9a9d0b419fcc58"
    "BW11R-B" =
        "sha256:38301e919b9a81cac8e75ba571b6941440539f25be3d3964f45236e47448c0d2"
    "BW11R-C" =
        "sha256:7ed6d5a0a15dc6547655760878a5f5e3d0cc7b4b1a04946db77c0694394f9d85"
    "BW11R-D" =
        "sha256:edb4469fcd961c86374fb987a6fd7046acc14fd2d575a9c8d9a18d85dcb9c533"
}
$expectedMetricOrder = @(
    "infrastructure_and_integrity_failure_count:ascending",
    "all_world_ordinary_nonwalk_count:ascending",
    "all_world_release_timeout_count:ascending",
    "rough_world_ordinary_nonwalk_count:ascending",
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

function Compare-MetricVector {
    param(
        [pscustomobject]$Left,
        [pscustomobject]$Right
    )
    $metricNames = @(
        "infrastructure_and_integrity_failure_count",
        "all_world_ordinary_nonwalk_count",
        "all_world_release_timeout_count",
        "rough_world_ordinary_nonwalk_count",
        "aggregate_walking_gate_failure_count",
        "aggregate_cumulative_absolute_cross_track_error_m_s",
        "maximum_absolute_task_frame_lateral_displacement_m"
    )
    foreach ($metricName in $metricNames) {
        $leftValue = [double]$Left.$metricName
        $rightValue = [double]$Right.$metricName
        if ($leftValue -lt $rightValue) {
            return -1
        }
        if ($leftValue -gt $rightValue) {
            return 1
        }
    }
    return 0
}

Assert-Exact (
    $Report.Count -eq 4
) "BW11R selection requires exactly four candidate reports"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW11R preregistration is missing"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW11R selection filename must be exactly report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW11R selection report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW11R selection directory: $outputDirectory"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
) "BW11R selection requires a clean worktree"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceCommit -ceq $originMain
) "BW11R selection requires HEAD exactly matching origin/main"

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
        "sporespore_balanced_wave_bw11r_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw11r_physics_world" -and
    (@($preregistration.candidate_order) -join ",") -ceq
        ($candidateOrder -join ",") -and
    (@($preregistration.selection.selectable_treatment_candidates) -join ",") -ceq
        ($treatmentCandidates -join ",") -and
    [string]$preregistration.selection.control_candidate -ceq "BW11R-A" -and
    ($observedMetricOrder -join ",") -ceq
        ($expectedMetricOrder -join ",") -and
    [string]$preregistration.selection.tie_rule -ceq
        "candidate_order_ascending" -and
    [bool]$preregistration.selection.all_candidates_must_complete_before_selection -and
    [bool]$preregistration.selection.treatment_must_be_strictly_lexicographically_better_than_control -and
    [int]$preregistration.development_matrix.expected_world_count_per_candidate -eq 12 -and
    [int]$preregistration.development_matrix.expected_complete_world_count -eq 48
) "BW11R preregistration selection contract is invalid"

$inputByCandidate = [ordered]@{}
$sourceCommitFromReports = ""
foreach ($pathValue in $Report) {
    $path = [System.IO.Path]::GetFullPath($pathValue)
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing BW11R candidate report: $path"
    $candidateReport = Get-Content -LiteralPath $path -Raw |
        ConvertFrom-Json -AsHashtable
    $candidate = [string]$candidateReport.candidate_id
    Assert-Exact (
        $candidateOrder -contains $candidate -and
        -not $inputByCandidate.Contains($candidate)
    ) "Duplicate or unknown BW11R candidate report: $candidate"
    if ([string]::IsNullOrWhiteSpace($sourceCommitFromReports)) {
        $sourceCommitFromReports = [string]$candidateReport.source_commit
    }
    $expectedSelectable = $treatmentCandidates -contains $candidate
    Assert-Exact (
        [string]$candidateReport.schema_version -ceq
            "sporespore_balanced_wave_bw11r_development_report_v1" -and
        [bool]$candidateReport.source_worktree_clean -and
        [bool]$candidateReport.source_matches_origin_main -and
        [bool]$candidateReport.development_data_only -and
        [bool]$candidateReport.complete -and
        [bool]$candidateReport.all_preflight_processes_passed -and
        [int]$candidateReport.preflight_actual_world_count -eq 0 -and
        [string]$candidateReport.source_commit -ceq $sourceCommitFromReports -and
        [string]$candidateReport.policy_id -ceq
            [string]$policyByCandidate[$candidate] -and
        [string]$candidateReport.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$candidateReport.candidate_policy_digest -ceq
            [string]$digestByCandidate[$candidate] -and
        [bool]$candidateReport.development_selectable -eq $expectedSelectable -and
        [int]$candidateReport.godot_exit_code -eq 0 -and
        [string]$candidateReport.receipt.schema_version -ceq
            "sporespore_balanced_wave_bw11r_development_receipt_v1" -and
        [bool]$candidateReport.receipt.ok -and
        [string]$candidateReport.receipt.candidate_id -ceq $candidate -and
        [string]$candidateReport.receipt.policy_id -ceq
            [string]$policyByCandidate[$candidate] -and
        [string]$candidateReport.receipt.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$candidateReport.receipt.candidate_policy_digest -ceq
            [string]$digestByCandidate[$candidate] -and
        [bool]$candidateReport.receipt.development_selectable -eq
            $expectedSelectable -and
        [bool]$candidateReport.receipt.full_gate_satisfiability_ok -and
        [int]$candidateReport.receipt.passed_gate_count -eq 23 -and
        [int]$candidateReport.receipt.failed_gate_count -eq 0 -and
        [int]$candidateReport.receipt.expected_world_count -eq 12 -and
        [int]$candidateReport.receipt.observed_world_count -eq 12 -and
        @($candidateReport.receipt.cells).Count -eq 12 -and
        [int]$candidateReport.receipt.integrity_failure_count -eq 0 -and
        [int]$candidateReport.receipt.acquisition_failure_count -eq 0 -and
        [int]$candidateReport.receipt.mechanism_receipt_failure_count -eq 0 -and
        [int]$candidateReport.receipt.nonzero_stability_world_count -eq
            $(if ($candidate -ceq "BW11R-A") { 0 } else { 12 }) -and
        [int]$candidateReport.receipt.count_by_cohort.baseline -eq 6 -and
        [int]$candidateReport.receipt.count_by_cohort.rough -eq 6 -and
        [string]$candidateReport.sources.preregistration.sha256 -ceq
            (Get-Sha256 $preregistrationPath) -and
        -not [bool]$candidateReport.walking_acceptance -and
        -not [bool]$candidateReport.cross_engine_c6 -and
        -not [bool]$candidateReport.completed_engine_neutral_sdk -and
        -not [bool]$candidateReport.physical_acceptance_authority
    ) "$candidate report is incomplete or source/identity mismatched"
    $inputByCandidate[$candidate] = [ordered]@{
        path = $path
        sha256 = Get-Sha256 $path
        report = $candidateReport
    }
}
Assert-Exact (
    $inputByCandidate.Count -eq 4 -and
    $sourceCommitFromReports -ceq $sourceCommit
) "BW11R selection requires four reports from the compiler source commit"

$metrics = @()
for ($candidateIndex = 0; $candidateIndex -lt $candidateOrder.Count; $candidateIndex++) {
    $candidate = $candidateOrder[$candidateIndex]
    $candidateReport = $inputByCandidate[$candidate].report
    $cells = @($candidateReport.receipt.cells)
    $ordinaryNonwalks = 0
    $roughNonwalks = 0
    $releaseTimeouts = 0
    $walkingGateFailures = 0
    $crossTrackIntegral = 0.0
    $maximumAbsoluteLateral = 0.0
    foreach ($cell in $cells) {
        if (-not [bool]$cell.ordinary_walking_gate_passed) {
            $ordinaryNonwalks += 1
            if ([string]$cell.cohort -ceq "rough") {
                $roughNonwalks += 1
            }
        }
        $releaseTimeouts += [int]$cell.release_timeout_count
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
    Assert-Exact (
        $ordinaryNonwalks -eq
            [int]$candidateReport.receipt.ordinary_nonwalk_count -and
        $roughNonwalks -eq
            [int]$candidateReport.receipt.rough_ordinary_nonwalk_count -and
        $releaseTimeouts -eq
            [int]$candidateReport.receipt.release_timeout_count
    ) "$candidate aggregate receipt disagrees with its cells"
    $metrics += [pscustomobject][ordered]@{
        candidate_id = $candidate
        policy_id = [string]$policyByCandidate[$candidate]
        base_controller_policy_id = $baseControllerPolicyId
        candidate_policy_digest = [string]$digestByCandidate[$candidate]
        development_selectable = [bool]$candidateReport.development_selectable
        infrastructure_and_integrity_failure_count = 0
        all_world_ordinary_nonwalk_count = $ordinaryNonwalks
        all_world_release_timeout_count = $releaseTimeouts
        rough_world_ordinary_nonwalk_count = $roughNonwalks
        aggregate_walking_gate_failure_count = $walkingGateFailures
        aggregate_cumulative_absolute_cross_track_error_m_s =
            $crossTrackIntegral
        maximum_absolute_task_frame_lateral_displacement_m =
            $maximumAbsoluteLateral
        candidate_order_index = $candidateIndex
    }
}

$control = @($metrics | Where-Object { $_.candidate_id -ceq "BW11R-A" })[0]
$treatmentMetrics = @(
    $metrics |
        Where-Object {
            $treatmentCandidates -contains $_.candidate_id -and
            [bool]$_.development_selectable
        } |
        Sort-Object `
            infrastructure_and_integrity_failure_count,
            all_world_ordinary_nonwalk_count,
            all_world_release_timeout_count,
            rough_world_ordinary_nonwalk_count,
            aggregate_walking_gate_failure_count,
            aggregate_cumulative_absolute_cross_track_error_m_s,
            maximum_absolute_task_frame_lateral_displacement_m,
            candidate_order_index
)
Assert-Exact (
    $treatmentMetrics.Count -eq 3
) "BW11R selection requires all three complete treatments"
$bestTreatment = $treatmentMetrics[0]
$treatmentBeatsControl = (
    (Compare-MetricVector $bestTreatment $control) -lt 0
)
$familySelected = $treatmentBeatsControl
$inputs = @(
    $candidateOrder |
        ForEach-Object {
            [ordered]@{
                candidate_id = $_
                path = [string]$inputByCandidate[$_].path
                sha256 = [string]$inputByCandidate[$_].sha256
            }
        }
)
$reportObject = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw11r_selection_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    development_data_only = $true
    attempted_candidate_count = 4
    complete_candidate_count = 4
    observed_world_count = 48
    selection_performed = $true
    family_selected = $familySelected
    result_status = $(if ($familySelected) {
        "treatment_selected_as_development_hypothesis"
    } else {
        "candidate_family_rejected_no_treatment_beats_control"
    })
    selected_candidate_id = $(if ($familySelected) {
        [string]$bestTreatment.candidate_id
    } else {
        $null
    })
    selected_policy_id = $(if ($familySelected) {
        [string]$bestTreatment.policy_id
    } else {
        $null
    })
    selected_base_controller_policy_id = $(if ($familySelected) {
        $baseControllerPolicyId
    } else {
        $null
    })
    selected_candidate_policy_digest = $(if ($familySelected) {
        [string]$bestTreatment.candidate_policy_digest
    } else {
        $null
    })
    control_candidate_id = "BW11R-A"
    best_treatment_candidate_id = [string]$bestTreatment.candidate_id
    best_treatment_strictly_beats_control = $treatmentBeatsControl
    selection_rule = [ordered]@{
        metrics = $expectedMetricOrder
        tie_rule = "candidate_order_ascending"
        eligibility =
            "all four complete with zero integrity, acquisition, and mechanism failures"
        treatment_requirement =
            "best selectable treatment is strictly lexicographically better than control"
    }
    candidate_metrics = @($metrics)
    inputs = $inputs
    preregistration = [ordered]@{
        path = "sdk/balanced_wave_bw11r_preregistration.json"
        sha256 = Get-Sha256 $preregistrationPath
    }
    development_selection_authority = $true
    independent_validation_required = $true
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
Write-Host "Retained BW11R selection report: $outputPath"
if ($familySelected) {
    Write-Host (
        "BALANCED_WAVE_BW11R_SELECTED=true " +
        "CANDIDATE=$([string]$bestTreatment.candidate_id)"
    )
} else {
    Write-Host (
        "BALANCED_WAVE_BW11R_SELECTED=false " +
        "NO_TREATMENT_STRICTLY_BEATS_CONTROL=true"
    )
}
