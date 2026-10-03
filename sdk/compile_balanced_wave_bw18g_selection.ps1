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
    [string]$Output,
    [switch]$SyntheticTestOnly
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
. (Join-Path $sdkRoot "experiment_result_integrity.ps1")

$expectedCandidates = @("BW18G-A", "BW18G-B", "BW18G-C", "BW18G-D")
$expectedStabilityPolicies = @(
    "sporespore_scheduled_load_transfer_bw13p_a_v3",
    "sporespore_scheduled_load_transfer_bw13p_a_v3",
    "sporespore_scheduled_load_transfer_bw13p_a_v3",
    "sporespore_scheduled_load_transfer_bw13p_a_v3"
)
$expectedAuthorityScopes = @(
    "post_settle_full",
    "post_settle_full",
    "post_settle_full",
    "post_settle_full"
)
$expectedGlobalScales = @(0.0, 0.25, 0.5, 1.0)
$expectedCompositionDigests = @(
    "sha256:1bbb4e46b3d3e2d70bf17eb86717df19942912280a56e534aa3d47dee2e814e1",
    "sha256:45826fbec95b544186a2dd9822bb1d641c3359120e900aeda729ba691b927446",
    "sha256:1707317f2e1c74adcdd5908ea7daf845233afda42d2f08d0b2a9007480bb2e1e",
    "sha256:8f27e50fa5d6033bf1a5ca69588c246d9a395f331ed6ba4cd405fd69b985641e"
)
$controllerPolicyId = "sporespore_balanced_wave_bw15f_b_v1"
$controllerPolicyDigest = (
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
)
$metricNames = @(
    "walking_conjunction_failure_count",
    "aggregate_failed_production_walking_gate_count",
    "aggregate_release_timeout_count",
    "maximum_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_cumulative_absolute_cross_track_error_m_s"
)
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw18g_morphology_development_preregistration.json"
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

function Compare-MetricVector {
    param(
        [Parameter(Mandatory)]
        [double[]]$Left,
        [Parameter(Mandatory)]
        [double[]]$Right
    )
    Assert-Exact (
        $Left.Count -eq $metricNames.Count -and
        $Right.Count -eq $metricNames.Count
    ) "BW18G metric vectors have the wrong length"
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

Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "The frozen BW18G preregistration is missing"
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$expectedPreregistrationSha256 = Get-PrefixedSha256 $preregistrationPath
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw18g_morphology_development_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw18g_physics_world" -and
    [string]$preregistration.campaign_id -ceq
        "BW18G-MORPHOLOGY-DEVELOPMENT" -and
    [string]$preregistration.gate_id -ceq "BW18G" -and
    (@($preregistration.candidate_order) -join ",") -ceq
        ($expectedCandidates -join ",") -and
    (@($preregistration.selection.metric_order) -join ",") -ceq
        ($metricNames -join ",") -and
    [bool]$preregistration.selection.all_candidate_reports_required -and
    [bool]$preregistration.selection.all_reports_require_36_of_36_integrity_mechanism_and_combined_application -and
    [bool]$preregistration.selection.best_treatment_must_be_strictly_lexicographically_better_than_control -and
    [bool]$preregistration.selection.tie_or_control_win_rejects_family -and
    [bool]$preregistration.selection.treatment_ties_resolve_to_lower_global_scale
) "The local BW18G preregistration is not the frozen four-arm selection contract"

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
    ) "Refusing BW18G selection from dirty source"
    $selectorSourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $selectorOriginMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($selectorSourceCommit) -and
        $selectorSourceCommit -ceq $selectorOriginMain
    ) "BW18G selector source must equal origin/main"
    $selectorSourceClean = $true
    $selectorSourceMatchesOriginMain = $true
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "selection.json"
) "The BW18G selection filename must be exactly selection.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite an existing BW18G selection: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW18G selection directory: $outputDirectory"
}

$reportPaths = @($ReportA, $ReportB, $ReportC, $ReportD)
$reports = [System.Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt 4; $index += 1) {
    $path = [System.IO.Path]::GetFullPath($reportPaths[$index])
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
    $scaleCellsExact = @(
        $report.results |
            Where-Object {
                [bool]$_.scale_contract_passed -and
                [double]$_.global_requested_correction_scale -eq
                    [double]$expectedGlobalScales[$index]
            }
    ).Count -eq 36
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw18g_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW18G-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.gate_id -ceq "BW18G" -and
        [string]$report.campaign_role -ceq
            "four_arm_outcome_exposed_global_portable_residual_scale_development" -and
        [string]$report.candidate_id -ceq
            $expectedCandidates[$index] -and
        [string]$report.candidate_composition_digest -ceq
            $expectedCompositionDigests[$index] -and
        [string]$report.selected_candidate_id -ceq "BW15F-B" -and
        [string]$report.controller_policy_id -ceq $controllerPolicyId -and
        [string]$report.controller_policy_digest -ceq
            $controllerPolicyDigest -and
        [string]$report.stability_policy_id -ceq
            $expectedStabilityPolicies[$index] -and
        [string]$report.authority_scope -ceq
            $expectedAuthorityScopes[$index] -and
        [double]$report.global_requested_correction_scale -eq
            [double]$expectedGlobalScales[$index] -and
        [string]$report.stability_influence_operation -ceq
            "bound_stability_influence_v3_json" -and
        $scaleCellsExact -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [string]$report.source.commit -ceq
            [string]$report.source.origin_main_commit -and
        -not [string]::IsNullOrWhiteSpace([string]$report.source.commit) -and
        [string]$report.preregistration.sha256 -ceq
            $expectedPreregistrationSha256 -and
        [string]$report.preregistration.status -ceq
            "frozen_before_first_bw18g_physics_world" -and
        [bool]$report.development_complete -and
        [bool]$report.development_data_only -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.balance_improvement -and
        -not [bool]$report.independent_morphology_validation -and
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
        [bool]$report.experiment_result_integrity_preflight.passed -and
        [bool]$report.experiment_result_integrity_preflight.perfect_all_zero_36_cell_matrix_passed -and
        [int]$report.experiment_result_integrity_preflight.perfect_failed_production_walking_gate_count -eq 0 -and
        [int]$report.experiment_result_integrity_preflight.perfect_release_timeout_count -eq 0 -and
        [bool]$report.experiment_result_integrity_preflight.nonzero_ordered_dictionary_canary_passed -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_failed_production_walking_gate_count -eq 3 -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_release_timeout_count -eq 2 -and
        [double]$report.experiment_result_integrity_preflight.nonzero_canary_maximum_normalized_lateral_displacement -eq 1.25 -and
        [double]$report.experiment_result_integrity_preflight.nonzero_canary_aggregate_normalized_lateral_displacement -eq 1.75 -and
        [double]$report.experiment_result_integrity_preflight.nonzero_canary_aggregate_cross_track_error_m_s -eq 1.0 -and
        [bool]$report.r05c_closure_preflight.passed -and
        [bool]$report.candidate_authority_preflight.passed -and
        [string]$report.candidate_authority_preflight.candidate_id -ceq
            $expectedCandidates[$index] -and
        [bool]$report.selector_preflight.passed -and
        [string]$report.selector_preflight.test_path -ceq
            "tests/test_bw18g_selector.ps1" -and
        [bool]$report.bw18g_entrypoint_preflight.passed -and
        [string]$report.bw18g_entrypoint_preflight.candidate_id -ceq
            $expectedCandidates[$index] -and
        [int]$report.bw18g_entrypoint_preflight.cell_count -eq 36 -and
        [int]$report.bw18g_entrypoint_preflight.exact_candidate_adapter_start_count -eq 36 -and
        [int]$report.bw18g_entrypoint_preflight.exact_declared_policy_runtime_boundary_count -eq 36 -and
        (
            $metrics |
                ConvertTo-Json -Compress -Depth 20
        ) -ceq (
            $recomputedMetrics |
                ConvertTo-Json -Compress -Depth 20
        ) -and
        -not [bool]$report.arbitrary_quadruped_coverage -and
        -not [bool]$report.continuous_full_volume_coverage -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.rough_terrain_robustness -and
        -not [bool]$report.external_push_recovery -and
        -not [bool]$report.sensor_noise_or_latency_robustness -and
        -not [bool]$report.different_physics_engines -and
        -not [bool]$report.running -and
        -not [bool]$report.completed_engine_neutral_sdk -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.physical_acceptance_authority
    ) "$($expectedCandidates[$index]) is not a complete eligible BW18G report"
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
            controller_policy_id = [string]$report.controller_policy_id
            controller_policy_digest = [string]$report.controller_policy_digest
            stability_policy_id = [string]$report.stability_policy_id
            authority_scope = [string]$report.authority_scope
            candidate_composition_digest = (
                [string]$report.candidate_composition_digest
            )
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
) "All four BW18G reports must share one exact source commit"
if (-not $SyntheticTestOnly) {
    Assert-Exact (
        [string]$sourceCommits[0] -ceq $selectorSourceCommit
    ) "BW18G report source must equal the clean pushed selector source"
}

$control = $reports[0]
$bestTreatmentIndex = 1
for ($index = 2; $index -lt 4; $index += 1) {
    $candidateComparison = Compare-MetricVector `
        -Left ([double[]]$reports[$index].metric_vector) `
        -Right ([double[]]$reports[$bestTreatmentIndex].metric_vector)
    if ($candidateComparison -lt 0) {
        $bestTreatmentIndex = $index
    }
}
$treatment = $reports[$bestTreatmentIndex]
$comparison = Compare-MetricVector `
    -Left ([double[]]$treatment.metric_vector) `
    -Right ([double[]]$control.metric_vector)
$treatmentComparisonsToControl = [ordered]@{}
for ($index = 1; $index -lt 4; $index += 1) {
    $treatmentComparisonsToControl[$expectedCandidates[$index]] = (
        Compare-MetricVector `
            -Left ([double[]]$reports[$index].metric_vector) `
            -Right ([double[]]$control.metric_vector)
    )
}
$familySelected = $comparison -lt 0
$resultStatus = if ($familySelected) {
    "development_residual_scale_selected_requires_new_independent_validation"
} elseif ($comparison -eq 0) {
    "bw18g_family_rejected_best_treatment_tied_control"
} else {
    "bw18g_family_rejected_all_treatments_worse_than_control"
}
$decidingMetric = "exact_tie"
for ($index = 0; $index -lt $metricNames.Count; $index += 1) {
    if (
        [double]$treatment.metric_vector[$index] -ne
            [double]$control.metric_vector[$index]
    ) {
        $decidingMetric = $metricNames[$index]
        break
    }
}

$selection = [ordered]@{
    schema_version = "sporespore_bw18g_residual_scale_selection_v1"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    campaign_id = "BW18G-MORPHOLOGY-DEVELOPMENT"
    gate_id = "BW18G"
    campaign_role = (
        "four_arm_outcome_exposed_global_portable_residual_scale_development"
    )
    source = [ordered]@{
        commit = $selectorSourceCommit
        origin_main_commit = $selectorOriginMain
        clean = $selectorSourceClean
        matches_origin_main = $selectorSourceMatchesOriginMain
    }
    preregistration = [ordered]@{
        path = $preregistrationPath
        sha256 = $expectedPreregistrationSha256
        status = [string]$preregistration.status
    }
    reports = @($reports)
    metric_order = $metricNames
    control_candidate_id = "BW18G-A"
    treatment_candidate_ids = @("BW18G-B", "BW18G-C", "BW18G-D")
    best_treatment_candidate_id = $expectedCandidates[$bestTreatmentIndex]
    control_metric_vector = @($control.metric_vector)
    best_treatment_metric_vector = @($treatment.metric_vector)
    treatment_lexicographic_comparisons_to_control = (
        $treatmentComparisonsToControl
    )
    best_treatment_lexicographic_comparison_to_control = $comparison
    selected_global_requested_correction_scale = $(
        if ($familySelected) {
            [double]$expectedGlobalScales[$bestTreatmentIndex]
        } else {
            $null
        }
    )
    deciding_metric = $decidingMetric
    family_selected = $familySelected
    selected_candidate_id = $(
        if ($familySelected) {
            $expectedCandidates[$bestTreatmentIndex]
        } else {
            ""
        }
    )
    selected_candidate_composition_digest = $(
        if ($familySelected) {
            $expectedCompositionDigests[$bestTreatmentIndex]
        } else {
            ""
        }
    )
    result_status = $resultStatus
    all_candidate_reports_observed = $true
    all_candidate_integrity_mechanism_and_application_complete = $true
    strict_best_treatment_improvement_required = $true
    tie_or_control_win_rejects_family = $true
    treatment_ties_resolve_to_lower_global_scale = $true
    cohort_outcome_exposed = $true
    development_selection_authority = $familySelected
    requires_new_prospectively_frozen_unopened_independent_validation = (
        $familySelected
    )
    synthetic_selector_test = [bool]$SyntheticTestOnly
    walking_acceptance = $false
    balance_improvement = $false
    independent_morphology_validation = $false
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

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
[System.IO.File]::WriteAllText(
    $outputPath,
    (
        $selection |
            ConvertTo-Json -Depth 100 |
            ForEach-Object { $_ + [Environment]::NewLine }
    ),
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host "SELECTION=$outputPath"
Write-Host "SELECTION_SHA256=$(Get-PrefixedSha256 $outputPath)"
Write-Host (
    "BW18G_SELECTED=$familySelected " +
    "STATUS=$resultStatus DECIDING_METRIC=$decidingMetric"
)
