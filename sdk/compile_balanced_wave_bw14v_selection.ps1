#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportA,
    [Parameter(Mandatory = $true)]
    [string]$ReportB,
    [Parameter(Mandatory = $true)]
    [string]$Output,
    [switch]$SyntheticTestOnly
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
. (Join-Path $sdkRoot "experiment_result_integrity.ps1")

$expectedCandidates = @("BW14V-A", "BW14V-B")
$expectedPolicies = @(
    "sporespore_balanced_wave_bw5r_b_v1",
    "sporespore_balanced_wave_bw14v_b_v1"
)
$expectedDigests = @(
    "sha256:288012fe4af5e93f1ecd2f007821a03e95c316c27cda196317617b8130017292",
    "sha256:3404217d991b8eaf6b9c0d74e84768ffd36264b6d664a7c02fc14f57b176713b"
)
$expectedPreregistrationSha256 = (
    "sha256:5030239a59fa477f0dab6cf749572edf7c9040569fff93d42d40c18da3dedd33"
)
$reportArguments = @($ReportA, $ReportB)
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

$selectorSourceCommit = "synthetic_selector_test"
$selectorOriginMain = "synthetic_selector_test"
$selectorSourceClean = $false
$selectorSourceMatchesOriginMain = $false
if (-not $SyntheticTestOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
    ) "Refusing BW14V selection from dirty source"
    $selectorSourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($selectorSourceCommit)
    ) "Could not resolve the BW14V selector source commit"
    $selectorOriginMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $selectorSourceCommit -ceq $selectorOriginMain
    ) "BW14V selector source must equal origin/main"
    $selectorSourceClean = $true
    $selectorSourceMatchesOriginMain = $true
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "selection.json"
) "The BW14V selection filename must be exactly selection.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite an existing BW14V selection: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW14V selection directory: $outputDirectory"
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
    $recomputedMetrics = Measure-SporeExperimentResults `
        -Results @($report.results) `
        -ExpectedCount 36
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw14v_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW14V-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.gate_id -ceq "BW14V" -and
        [string]$report.campaign_role -ceq
            "paired_outcome_exposed_base_controller_hypothesis_selection" -and
        [string]$report.selected_candidate_id -ceq
            $expectedCandidates[$index] -and
        [string]$report.selected_policy_id -ceq
            $expectedPolicies[$index] -and
        [string]$report.selected_policy_digest -ceq
            $expectedDigests[$index] -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [string]$report.source.commit -ceq
            [string]$report.source.origin_main_commit -and
        -not [string]::IsNullOrWhiteSpace([string]$report.source.commit) -and
        [string]$report.preregistration.sha256 -ceq
            $expectedPreregistrationSha256 -and
        [string]$report.preregistration.status -ceq
            "frozen_before_first_bw14v_physics_world" -and
        [bool]$report.development_complete -and
        [bool]$report.development_data_only -and
        -not [bool]$report.same_selected_policy_independent_morphology_evidence -and
        [string]$report.material_profile_id -ceq
            "godot_jolt_bw5c_mu095_v1" -and
        [double]$report.authored_friction -eq 0.95 -and
        [int]$report.expected_world_count -eq 36 -and
        [int]$report.observed_world_count -eq 36 -and
        [int]$report.complete_receipt_count -eq 36 -and
        [int]$report.harness_pass_count -eq 36 -and
        [int]$report.integrity_pass_count -eq 36 -and
        [int]$metrics.observed_world_count -eq 36 -and
        [int]$metrics.complete_receipt_count -eq 36 -and
        [int]$metrics.harness_pass_count -eq 36 -and
        [int]$metrics.integrity_pass_count -eq 36 -and
        [int]$metrics.mechanism_pass_count -eq 36 -and
        [int]$metrics.combined_application_pass_count -eq 36 -and
        [bool]$metrics.integrity_and_mechanism_complete -and
        [bool]$report.full_integrity_preflight.passed -and
        [string]$report.full_integrity_preflight.scope -ceq
            "baseline_regression_all_declared_bw13p_policies" -and
        [bool]$report.experiment_result_integrity_preflight.passed -and
        [bool]$report.experiment_result_integrity_preflight.perfect_all_zero_36_cell_matrix_passed -and
        [int]$report.experiment_result_integrity_preflight.perfect_observed_world_count -eq 36 -and
        [int]$report.experiment_result_integrity_preflight.perfect_failed_production_walking_gate_count -eq 0 -and
        [int]$report.experiment_result_integrity_preflight.perfect_release_timeout_count -eq 0 -and
        [bool]$report.experiment_result_integrity_preflight.nonzero_ordered_dictionary_canary_passed -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_failed_production_walking_gate_count -eq 3 -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_release_timeout_count -eq 2 -and
        [double]$report.experiment_result_integrity_preflight.nonzero_canary_maximum_normalized_lateral_displacement -eq 1.25 -and
        [double]$report.experiment_result_integrity_preflight.nonzero_canary_aggregate_normalized_lateral_displacement -eq 1.75 -and
        [double]$report.experiment_result_integrity_preflight.nonzero_canary_aggregate_cross_track_error_m_s -eq 1.0 -and
        [bool]$report.candidate_mechanism_preflight.required -and
        [bool]$report.candidate_mechanism_preflight.passed -and
        [string]$report.candidate_mechanism_preflight.candidate_id -ceq
            $expectedCandidates[$index] -and
        [string]$report.candidate_mechanism_preflight.controller_policy_id -ceq
            $expectedPolicies[$index] -and
        [bool]$report.bw14v_entrypoint_preflight.passed -and
        [string]$report.bw14v_entrypoint_preflight.candidate_id -ceq
            $expectedCandidates[$index] -and
        [string]$report.bw14v_entrypoint_preflight.controller_policy_id -ceq
            $expectedPolicies[$index] -and
        [int]$report.bw14v_entrypoint_preflight.cell_count -eq 36 -and
        [int]$report.bw14v_entrypoint_preflight.exact_candidate_full_authority_start_count -eq 36 -and
        [int]$report.bw14v_entrypoint_preflight.exact_candidate_declared_policy_runtime_boundary_count -eq 36 -and
        (
            $metrics |
                ConvertTo-Json -Compress -Depth 10
        ) -ceq (
            $recomputedMetrics |
                ConvertTo-Json -Compress -Depth 10
        ) -and
        -not [bool]$report.arbitrary_quadruped_coverage -and
        -not [bool]$report.continuous_full_volume_coverage -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.rough_terrain_robustness -and
        -not [bool]$report.external_push_recovery -and
        -not [bool]$report.sensor_noise_or_latency_robustness -and
        -not [bool]$report.running -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.completed_engine_neutral_sdk -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.physical_acceptance_authority
    ) "$($expectedCandidates[$index]) is not a complete eligible BW14V report"
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
            controller_policy_id = [string]$report.selected_policy_id
            candidate_policy_digest = [string]$report.selected_policy_digest
            metric_vector = @($vector)
            metrics = $metrics
        }
    )
}

$sourceCommits = @(
    $reports |
        ForEach-Object { $_.source_commit } |
        Select-Object -Unique
)
Assert-Exact (
    $sourceCommits.Count -eq 1 -and
    -not [string]::IsNullOrWhiteSpace([string]$sourceCommits[0])
) "Both BW14V reports must share one exact source commit"
if (-not $SyntheticTestOnly) {
    Assert-Exact (
        [string]$sourceCommits[0] -ceq $selectorSourceCommit
    ) "BW14V report source must equal the clean pushed selector source"
}

$control = $reports[0]
$treatment = $reports[1]
$comparison = Compare-MetricVector `
    -Left ([double[]]$treatment.metric_vector) `
    -Right ([double[]]$control.metric_vector)
$familySelected = $comparison -lt 0
$selection = [ordered]@{
    schema_version = "sporespore_bw14v_morphology_development_selection_v1"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    campaign_id = "BW14V-MORPHOLOGY-DEVELOPMENT"
    gate_id = "BW14V"
    source_commit = [string]$sourceCommits[0]
    selector_source_commit = $selectorSourceCommit
    selector_origin_main_commit = $selectorOriginMain
    selector_source_clean = $selectorSourceClean
    selector_source_matches_origin_main = $selectorSourceMatchesOriginMain
    synthetic_selector_test = [bool]$SyntheticTestOnly
    development_data_only = $true
    outcome_exposed_cohort = $true
    all_candidate_reports_required = $true
    all_candidate_reports_observed = $true
    control_candidate_id = "BW14V-A"
    selectable_treatment_candidate_ids = @("BW14V-B")
    metric_order = $metricNames
    metric_directions = @(
        "ascending",
        "ascending",
        "ascending",
        "ascending",
        "ascending",
        "ascending"
    )
    tie_rule = "ties_reject_treatment"
    reports = @($reports)
    strictly_better_treatment_candidate_ids = @(
        if ($familySelected) { "BW14V-B" }
    )
    family_selected = $familySelected
    result_status = $(
        if ($familySelected) {
            "development_candidate_selected_requires_independent_validation"
        } else {
            "bw14v_family_rejected_treatment_did_not_strictly_beat_control"
        }
    )
    selected_candidate_id = $(
        if ($familySelected) { "BW14V-B" } else { "" }
    )
    selected_controller_policy_id = $(
        if ($familySelected) {
            [string]$treatment.controller_policy_id
        } else {
            ""
        }
    )
    selected_candidate_policy_digest = $(
        if ($familySelected) {
            [string]$treatment.candidate_policy_digest
        } else {
            ""
        }
    )
    selected_metric_vector = $(
        if ($familySelected) { @($treatment.metric_vector) } else { @() }
    )
    requires_new_prospectively_frozen_independent_validation = (
        $familySelected
    )
    reserved_qsdk_r05c_remains_unopened = $true
    unbiased_friction_reservation_remains_unopened = $true
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
        "sporespore_bw14v_morphology_development_selection_v1" -and
    [int]$roundTrip.reports.Count -eq 2 -and
    [bool]$roundTrip.all_candidate_reports_observed -and
    [bool]$roundTrip.family_selected -eq $familySelected -and
    (
        [bool]$roundTrip.synthetic_selector_test -eq
            [bool]$SyntheticTestOnly
    ) -and
    (
        $SyntheticTestOnly -or (
            [bool]$roundTrip.selector_source_clean -and
            [bool]$roundTrip.selector_source_matches_origin_main -and
            [string]$roundTrip.selector_source_commit -ceq
                [string]$roundTrip.source_commit
        )
    ) -and
    -not [bool]$roundTrip.walking_acceptance -and
    -not [bool]$roundTrip.independent_morphology_validation -and
    -not [bool]$roundTrip.physical_acceptance_authority
) "BW14V selection serialization/readback failed"

Write-Host "SELECTION=$outputPath"
Write-Host "SELECTION_SHA256=$(Get-PrefixedSha256 $outputPath)"
Write-Host (
    "BW14V_FAMILY_SELECTED=$familySelected " +
    "SELECTED_CANDIDATE=$([string]$selection.selected_candidate_id)"
)
