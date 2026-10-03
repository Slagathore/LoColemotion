#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw13p_r3_closure_manifest.json"
)
$expectedSourceCommit = "6080c964bdf0c3cd231c29bccb956d86df826322"
$expectedMetricKeys = @(
    "walking_conjunction_failure_count",
    "aggregate_failed_production_walking_gate_count",
    "aggregate_release_timeout_count",
    "maximum_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_cumulative_absolute_cross_track_error_m_s"
)

. (Join-Path $repoRoot "sdk\experiment_result_integrity.ps1")
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")

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
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The BW13P-R3 closure manifest is missing"
$manifest = (
    Get-Content -LiteralPath $manifestPath -Raw |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw13p_r3_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_candidate_family_rejected_no_treatment_strictly_beats_control" -and
    [string]$manifest.experiment_source_commit -ceq $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.immutability.r3_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.r3_report_rewrite_forbidden -and
    [bool]$manifest.immutability.r3_selection_rewrite_forbidden -and
    [bool]$manifest.immutability.r3_treatment_selection_forbidden -and
    -not [bool]$manifest.claims.walking_acceptance -and
    -not [bool]$manifest.claims.independent_morphology_validation -and
    -not [bool]$manifest.claims.physical_acceptance_authority
) "The BW13P-R3 closure identity or fail-closed boundary changed"

$preregistrationPath = Join-Path $repoRoot (
    [string]$manifest.preregistration.path
)
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-Sha256 -Path $preregistrationPath) -ceq
        [string]$manifest.preregistration.raw_sha256 -and
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "1360f5247aa7a262d7d6f9899f823d309bcc1a54" -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw13p_r3_physics_world"
) "The frozen BW13P-R3 preregistration is missing or byte-mismatched"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 4
) "The BW13P-R3 closure must name exactly four candidate reports"

$recomputedByCandidate = [ordered]@{}
$totalArtifacts = 0
$totalWalking = 0
$totalFailures = 0
$totalFailedGates = 0
$totalReleaseTimeouts = 0
foreach ($entry in $candidateReports) {
    $reportPath = [System.IO.Path]::GetFullPath([string]$entry.path)
    Assert-Exact (
        (Test-Path -LiteralPath $reportPath -PathType Leaf) -and
        (Get-Sha256 -Path $reportPath) -ceq [string]$entry.sha256
    ) "A retained BW13P-R3 candidate report is missing or byte-mismatched"

    $report = (
        Get-Content -LiteralPath $reportPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    $results = @($report.results)
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw13p_r3_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW13P-R3-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.candidate_id -ceq [string]$entry.candidate_id -and
        [string]$report.stability_policy_id -ceq
            [string]$entry.stability_policy_id -and
        [string]$report.candidate_policy_digest -ceq
            [string]$entry.candidate_policy_digest -and
        [string]$report.source.commit -ceq $expectedSourceCommit -and
        [string]$report.source.origin_main_commit -ceq $expectedSourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        $results.Count -eq 36 -and
        [bool]$report.complete -and
        [bool]$report.candidate_mechanism_eligible -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.physical_acceptance_authority
    ) "A retained BW13P-R3 candidate report changed identity or authority"

    $metrics = Measure-SporeExperimentResults -Results $results -ExpectedCount 36
    Assert-Exact (
        (($report.metrics | ConvertTo-Json -Compress -Depth 10) -ceq
            ($metrics | ConvertTo-Json -Compress -Depth 10)) -and
        [int]$metrics.observed_world_count -eq 36 -and
        [int]$metrics.complete_receipt_count -eq 36 -and
        [int]$metrics.harness_pass_count -eq 36 -and
        [int]$metrics.integrity_pass_count -eq 36 -and
        [int]$metrics.mechanism_pass_count -eq 36 -and
        [int]$metrics.combined_application_pass_count -eq 36 -and
        [bool]$metrics.integrity_and_mechanism_complete
    ) "A retained BW13P-R3 metric object does not exactly reconstruct"

    $metricVector = @(
        foreach ($key in $expectedMetricKeys) {
            $metrics[$key]
        }
    )
    Assert-Exact (
        (($entry.metric_vector | ConvertTo-Json -Compress) -ceq
            ($metricVector | ConvertTo-Json -Compress))
    ) "A pinned BW13P-R3 candidate metric vector changed"
    $recomputedByCandidate[[string]$entry.candidate_id] = $metricVector

    $candidateArtifacts = 0
    foreach ($result in $results) {
        foreach ($kind in @("transcript", "stderr", "engine_log")) {
            $pathKey = "${kind}_path"
            $hashKey = "${kind}_sha256"
            $artifactPath = [System.IO.Path]::GetFullPath(
                [string]$result[$pathKey]
            )
            $expectedHash = (
                [string]$result[$hashKey]
            ).Replace("sha256:", "")
            Assert-Exact (
                (Test-Path -LiteralPath $artifactPath -PathType Leaf) -and
                (Get-Sha256 -Path $artifactPath) -ceq $expectedHash
            ) "A retained BW13P-R3 cell artifact is missing or byte-mismatched"
            $candidateArtifacts += 1
        }
    }
    $reportRoot = Split-Path -Parent $reportPath
    foreach ($artifact in @($report.preflight.retained_artifacts)) {
        $artifactPath = Join-Path $reportRoot ([string]$artifact.path)
        $expectedHash = (
            [string]$artifact.sha256
        ).Replace("sha256:", "")
        Assert-Exact (
            (Test-Path -LiteralPath $artifactPath -PathType Leaf) -and
            (Get-Sha256 -Path $artifactPath) -ceq $expectedHash
        ) "A retained BW13P-R3 preflight artifact is missing or byte-mismatched"
        $candidateArtifacts += 1
    }
    Assert-Exact (
        $candidateArtifacts -eq 117 -and
        $candidateArtifacts -eq [int]$entry.referenced_artifact_count -and
        [bool]$report.preflight.experiment_result_integrity_preflight_passed -and
        [bool]$report.preflight.runner_report_serialization_hash_readback_passed -and
        [bool]$report.preflight.nonzero_aggregation_canary_passed -and
        [int]$report.preflight.actual_world_build_count -eq 0
    ) "A BW13P-R3 report lost its exact 117-artifact preflight/cell bundle"

    $totalArtifacts += $candidateArtifacts
    $totalWalking += [int]$metrics.walking_conjunction_pass_count
    $totalFailures += [int]$metrics.walking_conjunction_failure_count
    $totalFailedGates += (
        [int]$metrics.aggregate_failed_production_walking_gate_count
    )
    $totalReleaseTimeouts += [int]$metrics.aggregate_release_timeout_count
}

Assert-Exact (
    [int]$manifest.complete_attempt.observed_world_count -eq 144 -and
    [int]$manifest.complete_attempt.complete_receipt_count -eq 144 -and
    [int]$manifest.complete_attempt.integrity_pass_count -eq 144 -and
    [int]$manifest.complete_attempt.mechanism_pass_count -eq 144 -and
    [int]$manifest.complete_attempt.combined_application_pass_count -eq 144 -and
    [int]$manifest.complete_attempt.walking_conjunction_pass_count -eq
        $totalWalking -and
    [int]$manifest.complete_attempt.walking_conjunction_failure_count -eq
        $totalFailures -and
    [int]$manifest.complete_attempt.aggregate_failed_production_walking_gate_count -eq
        $totalFailedGates -and
    [int]$manifest.complete_attempt.aggregate_release_timeout_count -eq
        $totalReleaseTimeouts -and
    $totalWalking -eq 133 -and
    $totalFailures -eq 11 -and
    $totalFailedGates -eq 11 -and
    $totalReleaseTimeouts -eq 4 -and
    $totalArtifacts -eq 468
) "The complete BW13P-R3 family totals changed"

$selectionPath = [System.IO.Path]::GetFullPath(
    [string]$manifest.selection.path
)
Assert-Exact (
    (Test-Path -LiteralPath $selectionPath -PathType Leaf) -and
    (Get-Sha256 -Path $selectionPath) -ceq
        [string]$manifest.selection.sha256
) "The retained BW13P-R3 selection is missing or byte-mismatched"
$selection = (
    Get-Content -LiteralPath $selectionPath -Raw |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_bw13p_r3_morphology_development_selection_v1" -and
    [string]$selection.source_commit -ceq $expectedSourceCommit -and
    [bool]$selection.all_four_complete_reports_observed -and
    -not [bool]$selection.family_selected -and
    [string]$selection.result_status -ceq
        "bw13p_r3_family_rejected_no_treatment_strictly_beats_control" -and
    [string]$selection.selected_candidate_id -ceq "" -and
    @($selection.strictly_better_treatment_candidate_ids).Count -eq 0 -and
    -not [bool]$selection.walking_acceptance -and
    -not [bool]$selection.physical_acceptance_authority
) "The BW13P-R3 no-treatment selection disposition changed"

foreach ($selectedReport in @($selection.reports)) {
    $candidateId = [string]$selectedReport.candidate_id
    $selectedVector = @($selectedReport.metric_vector)
    $recomputedVector = @($recomputedByCandidate[$candidateId])
    $vectorMatches = $selectedVector.Count -eq $recomputedVector.Count
    if ($vectorMatches) {
        for ($index = 0; $index -lt $selectedVector.Count; $index += 1) {
            if (
                [double]$selectedVector[$index] -ne
                    [double]$recomputedVector[$index]
            ) {
                $vectorMatches = $false
                break
            }
        }
    }
    Assert-Exact (
        $recomputedByCandidate.Contains($candidateId) -and
        $vectorMatches
    ) "The BW13P-R3 selector no longer carries exact reconstructed metrics"
}

Assert-Exact (
    [double]$recomputedByCandidate["BW13P-A"][0] -eq 1.0 -and
    [double]$recomputedByCandidate["BW13P-B"][0] -eq 4.0 -and
    [double]$recomputedByCandidate["BW13P-C"][0] -eq 3.0 -and
    [double]$recomputedByCandidate["BW13P-D"][0] -eq 3.0 -and
    [bool]$manifest.scientific_disposition.control_remains_best_observed_arm -and
    -not [bool]$manifest.scientific_disposition.treatment_selected -and
    -not [bool]$manifest.reservations.r05c_opened -and
    [bool]$manifest.reservations.r05c_may_not_be_opened_as_bw13p_r3_validation -and
    -not [bool]$manifest.reservations.unbiased_friction_reservation_opened
) "The BW13P-R3 rejection or sealed reservations changed"

$aggregatorPath = Join-Path $repoRoot (
    [string]$manifest.report_integrity.shared_aggregator_path
)
Assert-Exact (
    (Test-Path -LiteralPath $aggregatorPath -PathType Leaf) -and
    (
        Test-SporeHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedSourceCommit `
            -Path ([string]$manifest.report_integrity.shared_aggregator_path) `
            -ExpectedSha256 (
                [string]$manifest.report_integrity.shared_aggregator_raw_sha256
            )
    ) -and
    [bool]$manifest.report_integrity.perfect_synthetic_full_gate_passed_before_every_candidate -and
    [bool]$manifest.report_integrity.nonzero_ordered_dictionary_canary_passed_before_every_candidate -and
    [bool]$manifest.report_integrity.stored_metrics_equal_exact_reconstruction_for_all_candidates -and
    [int]$manifest.report_integrity.report_references_hash_verified -eq
        $totalArtifacts
) "The BW13P-R3 report-integrity boundary changed"

foreach ($source in @($manifest.research_sources)) {
    if (-not $source.Contains("sha256")) {
        continue
    }
    Assert-Exact (
        (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$source.path)
        ) -PathType Leaf) -and
        (Test-SporeWorkingOrHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedSourceCommit `
            -Path ([string]$source.path) `
            -ExpectedSha256 ([string]$source.sha256))
    ) "A pinned locomotion research source is missing or byte-mismatched"
}

Write-Host (
    "BW13P_R3_CLOSURE_TEST_PASS worlds=144 walking=133 " +
    "failures=11 failed_gates=11 release_timeouts=4 artifacts=468 " +
    "family_selected=false r05c_opened=false physical_authority=false"
)
