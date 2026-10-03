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

$expectedCandidates = @("BW19V-A", "BW19V-B")
$expectedGlobalScales = @(0.0, 0.5)
$expectedApplicationPassCounts = @(0, 36)
$expectedCompositionDigests = @(
    "sha256:2eb8621882b4ae4047821aca415ab1b67de3399d0ab272a91f57fb0fc2ada7a4",
    "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
)
$expectedMorphologies = 205..216 | ForEach-Object {
    "bw19v_generated_s$_"
}
$expectedSeeds = @(39101, 39102, 39103)
$controllerPolicyId = "sporespore_balanced_wave_bw15f_b_v1"
$controllerPolicyDigest = (
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
)
$stabilityPolicyId = "sporespore_scheduled_load_transfer_bw13p_a_v3"
$secondaryMetricNames = @(
    "aggregate_failed_production_walking_gate_count",
    "aggregate_release_timeout_count",
    "maximum_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_cumulative_absolute_cross_track_error_m_s"
)
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw19v_independent_validation_preregistration.json"
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

Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "The frozen BW19V preregistration is missing"
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$expectedPreregistrationSha256 = Get-PrefixedSha256 $preregistrationPath
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw19v_independent_validation_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw19v_physics_world" -and
    [string]$preregistration.campaign_id -ceq
        "BW19V-INDEPENDENT-MORPHOLOGY-VALIDATION" -and
    [string]$preregistration.gate_id -ceq "BW19V" -and
    (@($preregistration.candidate_order) -join ",") -ceq
        ($expectedCandidates -join ",") -and
    [bool]$preregistration.selection.all_candidate_reports_required -and
    [bool]$preregistration.selection.all_reports_require_36_of_36_integrity_and_mechanism -and
    (
        @(
            $preregistration.selection.policy_relative_expected_application_pass_counts
        ) -join ","
    ) -ceq ($expectedApplicationPassCounts -join ",") -and
    [string]$preregistration.selection.primary_metric -ceq
        "walking_conjunction_failure_count" -and
    [bool]$preregistration.selection.treatment_walking_failure_count_must_be_strictly_lower_than_control -and
    [bool]$preregistration.selection.walking_failure_tie_or_worse_rejects_hypothesis -and
    [bool]$preregistration.selection.secondary_metrics_are_diagnostic_only -and
    (
        @($preregistration.selection.secondary_metric_order) -join ","
    ) -ceq ($secondaryMetricNames -join ",")
) "The local BW19V preregistration is not the frozen two-arm validation contract"

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
    ) "Refusing BW19V selection from dirty source"
    $selectorSourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $selectorOriginMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($selectorSourceCommit) -and
        $selectorSourceCommit -ceq $selectorOriginMain
    ) "BW19V selector source must equal origin/main"
    $selectorSourceClean = $true
    $selectorSourceMatchesOriginMain = $true
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "selection.json"
) "The BW19V selection filename must be exactly selection.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite an existing BW19V selection: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW19V selection directory: $outputDirectory"
}

$reportPaths = @($ReportA, $ReportB)
$reports = [System.Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $expectedCandidates.Count; $index += 1) {
    $path = [System.IO.Path]::GetFullPath($reportPaths[$index])
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing $($expectedCandidates[$index]) report: $path"
    $report = (
        Get-Content -Raw -LiteralPath $path |
            ConvertFrom-Json -AsHashtable
    )
    $metrics = $report.metrics
    $recomputedMetrics = Measure-SporePolicyRelativeExperimentResults `
        -Results @($report.results) `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount $expectedApplicationPassCounts[$index]
    $scaleCellsExact = @(
        $report.results |
            Where-Object {
                [bool]$_.scale_contract_passed -and
                [double]$_.global_requested_correction_scale -eq
                    [double]$expectedGlobalScales[$index]
            }
    ).Count -eq 36
    $cellKeys = @(
        $report.results |
            ForEach-Object {
                "$([string]$_.morphology_id):$([int]$_.seed)"
            }
    )
    $expectedCellKeys = @(
        foreach ($morphology in $expectedMorphologies) {
            foreach ($seed in $expectedSeeds) {
                "$morphology`:$seed"
            }
        }
    )
    $cellsExact = (
        $cellKeys.Count -eq 36 -and
        @($cellKeys | Select-Object -Unique).Count -eq 36 -and
        (@($cellKeys | Sort-Object) -join ",") -ceq
            (@($expectedCellKeys | Sort-Object) -join ",")
    )
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw19v_independent_validation_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW19V-INDEPENDENT-MORPHOLOGY-VALIDATION" -and
        [string]$report.gate_id -ceq "BW19V" -and
        [string]$report.campaign_role -ceq
            "two_arm_prospective_independent_morphology_validation" -and
        [string]$report.candidate_id -ceq
            $expectedCandidates[$index] -and
        [string]$report.candidate_composition_digest -ceq
            $expectedCompositionDigests[$index] -and
        [string]$report.selected_candidate_id -ceq "BW15F-B" -and
        [string]$report.controller_policy_id -ceq $controllerPolicyId -and
        [string]$report.controller_policy_digest -ceq
            $controllerPolicyDigest -and
        [string]$report.stability_policy_id -ceq $stabilityPolicyId -and
        [string]$report.authority_scope -ceq "post_settle_full" -and
        [double]$report.global_requested_correction_scale -eq
            [double]$expectedGlobalScales[$index] -and
        [int]$report.expected_application_pass_count -eq
            [int]$expectedApplicationPassCounts[$index] -and
        [string]$report.stability_influence_operation -ceq
            "bound_stability_influence_v3_json" -and
        $scaleCellsExact -and
        $cellsExact -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [string]$report.source.commit -ceq
            [string]$report.source.origin_main_commit -and
        -not [string]::IsNullOrWhiteSpace([string]$report.source.commit) -and
        [string]$report.preregistration.sha256 -ceq
            $expectedPreregistrationSha256 -and
        [string]$report.preregistration.status -ceq
            "frozen_before_first_bw19v_physics_world" -and
        [bool]$report.validation_execution_complete -and
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
        [int]$metrics.combined_application_pass_count -eq
            [int]$expectedApplicationPassCounts[$index] -and
        [int]$metrics.expected_application_pass_count -eq
            [int]$expectedApplicationPassCounts[$index] -and
        [bool]$metrics.policy_relative_execution_complete -and
        [bool]$report.full_integrity_preflight.passed -and
        [bool]$report.experiment_result_integrity_preflight.passed -and
        [bool]$report.experiment_result_integrity_preflight.policy_relative_perfect_synthetic_gate_passed -and
        [int]$report.experiment_result_integrity_preflight.expected_application_pass_count -eq
            [int]$expectedApplicationPassCounts[$index] -and
        [bool]$report.candidate_authority_preflight.passed -and
        [string]$report.candidate_authority_preflight.candidate_id -ceq
            $expectedCandidates[$index] -and
        [bool]$report.selector_preflight.passed -and
        [string]$report.selector_preflight.test_path -ceq
            "tests/test_bw19v_selector.ps1" -and
        [bool]$report.bw19v_entrypoint_preflight.passed -and
        [string]$report.bw19v_entrypoint_preflight.candidate_id -ceq
            $expectedCandidates[$index] -and
        [int]$report.bw19v_entrypoint_preflight.cell_count -eq 36 -and
        [int]$report.bw19v_entrypoint_preflight.exact_candidate_adapter_start_count -eq 36 -and
        [int]$report.bw19v_entrypoint_preflight.exact_declared_policy_runtime_boundary_count -eq 36 -and
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
    ) "$($expectedCandidates[$index]) is not a complete eligible BW19V report"

    foreach (
        $metricName in @("walking_conjunction_failure_count") +
            $secondaryMetricNames
    ) {
        Assert-Exact (
            $null -ne $metrics[$metricName]
        ) "$($expectedCandidates[$index]) metric is null: $metricName"
        $value = [double]$metrics[$metricName]
        Assert-Exact (
            -not [double]::IsNaN($value) -and
            -not [double]::IsInfinity($value) -and
            $value -ge 0.0
        ) "$($expectedCandidates[$index]) metric is invalid: $metricName"
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
            expected_application_pass_count = (
                [int]$expectedApplicationPassCounts[$index]
            )
            walking_conjunction_failure_count = (
                [int]$metrics.walking_conjunction_failure_count
            )
            secondary_metrics = [ordered]@{
                aggregate_failed_production_walking_gate_count = (
                    [int]$metrics.aggregate_failed_production_walking_gate_count
                )
                aggregate_release_timeout_count = (
                    [int]$metrics.aggregate_release_timeout_count
                )
                maximum_normalized_absolute_task_frame_lateral_displacement = (
                    [double]$metrics.maximum_normalized_absolute_task_frame_lateral_displacement
                )
                aggregate_normalized_absolute_task_frame_lateral_displacement = (
                    [double]$metrics.aggregate_normalized_absolute_task_frame_lateral_displacement
                )
                aggregate_cumulative_absolute_cross_track_error_m_s = (
                    [double]$metrics.aggregate_cumulative_absolute_cross_track_error_m_s
                )
            }
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
) "Both BW19V reports must share one exact source commit"
if (-not $SyntheticTestOnly) {
    Assert-Exact (
        [string]$sourceCommits[0] -ceq $selectorSourceCommit
    ) "BW19V report source must equal the clean pushed selector source"
}

$control = $reports[0]
$treatment = $reports[1]
$controlFailures = [int]$control.walking_conjunction_failure_count
$treatmentFailures = [int]$treatment.walking_conjunction_failure_count
$hypothesisConfirmed = $treatmentFailures -lt $controlFailures
$failureCountDifference = $controlFailures - $treatmentFailures
$resultStatus = if ($hypothesisConfirmed) {
    "finite_independent_validation_hypothesis_confirmed"
} elseif ($treatmentFailures -eq $controlFailures) {
    "bw19v_hypothesis_rejected_walking_failure_tie"
} else {
    "bw19v_hypothesis_rejected_treatment_walking_failures_worse"
}

$selection = [ordered]@{
    schema_version = "sporespore_bw19v_independent_validation_selection_v1"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    campaign_id = "BW19V-INDEPENDENT-MORPHOLOGY-VALIDATION"
    gate_id = "BW19V"
    campaign_role = "two_arm_prospective_independent_morphology_validation"
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
    primary_metric = "walking_conjunction_failure_count"
    control_candidate_id = "BW19V-A"
    treatment_candidate_id = "BW19V-B"
    control_walking_conjunction_failure_count = $controlFailures
    treatment_walking_conjunction_failure_count = $treatmentFailures
    control_minus_treatment_walking_failure_count = $failureCountDifference
    treatment_must_be_strictly_lower = $true
    walking_failure_tie_or_worse_rejects_hypothesis = $true
    secondary_metric_order = $secondaryMetricNames
    secondary_metrics_are_diagnostic_only = $true
    validation_hypothesis_confirmed = $hypothesisConfirmed
    selected_candidate_id = $(if ($hypothesisConfirmed) { "BW19V-B" } else { "" })
    selected_candidate_composition_digest = $(
        if ($hypothesisConfirmed) {
            $expectedCompositionDigests[1]
        } else {
            ""
        }
    )
    result_status = $resultStatus
    all_candidate_reports_observed = $true
    all_candidate_integrity_and_mechanism_complete = $true
    policy_relative_application_contract_complete = $true
    cohort_outcome_exposed_before_preregistration = $false
    finite_prospectively_frozen_unopened_validation_cohort = $true
    bounded_independent_validation_authority = $hypothesisConfirmed
    arbitrary_quadruped_coverage = $false
    continuous_full_volume_coverage = $false
    walking_acceptance = $false
    balance_improvement = $false
    material_robustness = $false
    rough_terrain_robustness = $false
    external_push_recovery = $false
    sensor_noise_or_latency_robustness = $false
    different_physics_engines = $false
    running = $false
    completed_engine_neutral_sdk = $false
    release_authorized = $false
    physical_acceptance_authority = $false
    synthetic_selector_test = [bool]$SyntheticTestOnly
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
    "BW19V_CONFIRMED=$hypothesisConfirmed " +
    "STATUS=$resultStatus CONTROL_FAILURES=$controlFailures " +
    "TREATMENT_FAILURES=$treatmentFailures"
)
