#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportA,
    [Parameter(Mandatory = $true)]
    [string]$ReportB,
    [Parameter(Mandatory = $true)]
    [string]$ReportC,
    [Parameter(Mandatory = $true)]
    [string]$ReportD,
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$expectedCandidates = @("BW13P-A", "BW13P-B", "BW13P-C", "BW13P-D")
$reportArguments = @($ReportA, $ReportB, $ReportC, $ReportD)
$metricNames = @(
    "walking_conjunction_failure_count",
    "aggregate_failed_production_walking_gate_count",
    "aggregate_release_timeout_count",
    "maximum_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_cumulative_absolute_cross_track_error_m_s"
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
    $hash = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
    return "sha256:$hash"
}

function Compare-MetricVector {
    param(
        [Parameter(Mandatory)]
        [double[]]$Left,
        [Parameter(Mandatory)]
        [double[]]$Right
    )
    for ($index = 0; $index -lt $Left.Count; $index += 1) {
        if ($Left[$index] -lt $Right[$index]) {
            return -1
        }
        if ($Left[$index] -gt $Right[$index]) {
            return 1
        }
    }
    return 0
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "selection.json"
) "The BW13P selection filename must be exactly selection.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite an existing BW13P selection: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW13P selection directory: $outputDirectory"
}

$reports = [System.Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $expectedCandidates.Count; $index += 1) {
    $path = [System.IO.Path]::GetFullPath($reportArguments[$index])
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing $($expectedCandidates[$index]) report: $path"
    $report = (
        Get-Content -Raw -LiteralPath $path |
            ConvertFrom-Json -AsHashtable
    )
    $metrics = $report.metrics
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw13p_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW13P-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.candidate_id -ceq $expectedCandidates[$index] -and
        [bool]$report.complete -and
        [bool]$report.candidate_mechanism_eligible -and
        [int]$report.expected_world_count -eq 36 -and
        [int]$metrics.observed_world_count -eq 36 -and
        [int]$metrics.complete_receipt_count -eq 36 -and
        [int]$metrics.integrity_pass_count -eq 36 -and
        [int]$metrics.mechanism_pass_count -eq 36 -and
        [int]$metrics.combined_application_pass_count -eq 36 -and
        [bool]$metrics.integrity_and_mechanism_complete -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.independent_morphology_validation -and
        -not [bool]$report.physical_acceptance_authority
    ) "$($expectedCandidates[$index]) is not a complete eligible report"
    $vector = [System.Collections.Generic.List[double]]::new()
    foreach ($metricName in $metricNames) {
        Assert-Exact (
            $null -ne $metrics[$metricName]
        ) "$($expectedCandidates[$index]) metric is null: $metricName"
        $value = [double]$metrics[$metricName]
        Assert-Exact (
            -not [double]::IsNaN($value) -and
            -not [double]::IsInfinity($value) -and
            $value -ge 0.0
        ) "$($expectedCandidates[$index]) metric is invalid: $metricName"
        $vector.Add($value)
    }
    $reports.Add(
        [ordered]@{
            candidate_id = $expectedCandidates[$index]
            path = $path
            sha256 = Get-PrefixedSha256 $path
            source_commit = [string]$report.source.commit
            stability_policy_id = [string]$report.stability_policy_id
            candidate_policy_digest = [string]$report.candidate_policy_digest
            metric_vector = @($vector)
            metrics = $metrics
        }
    )
}

$sourceCommits = @($reports | ForEach-Object { $_.source_commit } | Select-Object -Unique)
Assert-Exact (
    $sourceCommits.Count -eq 1 -and
    -not [string]::IsNullOrWhiteSpace([string]$sourceCommits[0])
) "All four BW13P reports must share one exact source commit"

$control = $reports[0]
$strictlyBetterTreatments = [System.Collections.Generic.List[object]]::new()
for ($index = 1; $index -lt $reports.Count; $index += 1) {
    $comparison = Compare-MetricVector `
        -Left ([double[]]$reports[$index].metric_vector) `
        -Right ([double[]]$control.metric_vector)
    if ($comparison -lt 0) {
        $strictlyBetterTreatments.Add($reports[$index])
    }
}

$selected = $null
foreach ($candidate in $strictlyBetterTreatments) {
    if ($null -eq $selected) {
        $selected = $candidate
        continue
    }
    $comparison = Compare-MetricVector `
        -Left ([double[]]$candidate.metric_vector) `
        -Right ([double[]]$selected.metric_vector)
    if ($comparison -lt 0) {
        $selected = $candidate
    }
}

$familySelected = $null -ne $selected
$selection = [ordered]@{
    schema_version = "sporespore_bw13p_morphology_development_selection_v1"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    campaign_id = "BW13P-MORPHOLOGY-DEVELOPMENT"
    source_commit = [string]$sourceCommits[0]
    development_data_only = $true
    all_four_complete_reports_required = $true
    all_four_complete_reports_observed = $true
    control_candidate_id = "BW13P-A"
    selectable_treatment_candidate_ids = @("BW13P-B", "BW13P-C", "BW13P-D")
    metric_order = $metricNames
    metric_directions = @(
        "ascending",
        "ascending",
        "ascending",
        "ascending",
        "ascending",
        "ascending"
    )
    tie_rule = "candidate_order_ascending"
    reports = @($reports)
    strictly_better_treatment_candidate_ids = @(
        $strictlyBetterTreatments |
            ForEach-Object { [string]$_.candidate_id }
    )
    family_selected = $familySelected
    result_status = $(
        if ($familySelected) {
            "development_candidate_selected"
        } else {
            "bw13p_family_rejected_no_treatment_strictly_beats_control"
        }
    )
    selected_candidate_id = $(
        if ($familySelected) { [string]$selected.candidate_id } else { "" }
    )
    selected_stability_policy_id = $(
        if ($familySelected) {
            [string]$selected.stability_policy_id
        } else {
            ""
        }
    )
    selected_candidate_policy_digest = $(
        if ($familySelected) {
            [string]$selected.candidate_policy_digest
        } else {
            ""
        }
    )
    selected_metric_vector = $(
        if ($familySelected) { @($selected.metric_vector) } else { @() }
    )
    requires_new_committed_policy_before_independent_validation = (
        $familySelected
    )
    reserved_qsdk_r05c_remains_unopened = $true
    development_selection_authority = $true
    walking_acceptance = $false
    balance_improvement = $false
    independent_morphology_validation = $false
    arbitrary_quadruped_coverage = $false
    continuous_full_volume_coverage = $false
    material_or_friction_robustness = $false
    rough_terrain_robustness = $false
    external_push_recovery = $false
    sensor_noise_or_latency_robustness = $false
    running = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    release_authorized = $false
    physical_acceptance_authority = $false
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$json = $selection | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText(
    $outputPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
$roundTrip = (
    Get-Content -Raw -LiteralPath $outputPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$roundTrip.schema_version -ceq
        "sporespore_bw13p_morphology_development_selection_v1" -and
    [int]$roundTrip.reports.Count -eq 4 -and
    [bool]$roundTrip.all_four_complete_reports_observed -and
    [bool]$roundTrip.family_selected -eq $familySelected -and
    -not [bool]$roundTrip.walking_acceptance -and
    -not [bool]$roundTrip.physical_acceptance_authority
) "BW13P selection serialization/readback failed"

Write-Host "SELECTION=$outputPath"
Write-Host "SELECTION_SHA256=$(Get-PrefixedSha256 $outputPath)"
Write-Host (
    "BW13P_FAMILY_SELECTED=$familySelected " +
    "SELECTED_CANDIDATE=$([string]$selection.selected_candidate_id)"
)
