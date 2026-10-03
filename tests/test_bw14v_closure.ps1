#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw14v_closure_manifest.json"
)
$expectedSourceCommit = "b519fe094196d235a9a09c8c3a5637d2553e2bc2"
$metricKeys = @(
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

function Assert-HashedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Sha256 -Path $Path) -ceq
            $ExpectedSha256.Replace("sha256:", "")
    ) $Message
}

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The BW14V closure manifest is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw14v_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_treatment_family_rejected_treatment_catastrophically_degraded_control" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.immutability.bw14v_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.bw14v_report_rewrite_forbidden -and
    [bool]$manifest.immutability.bw14v_selection_rewrite_forbidden -and
    [bool]$manifest.immutability.bw14v_treatment_selection_forbidden -and
    -not [bool]$manifest.claims.walking_acceptance -and
    -not [bool]$manifest.claims.independent_morphology_validation -and
    -not [bool]$manifest.claims.physical_acceptance_authority
) "The BW14V closure identity or fail-closed boundary changed"

$commitObject = "${expectedSourceCommit}^{commit}"
& git -C $repoRoot cat-file -e $commitObject
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The exact BW14V experiment source commit is not retained by Git"

$preregistrationPath = Join-Path $repoRoot (
    [string]$manifest.preregistration.path
)
Assert-HashedFile `
    -Path $preregistrationPath `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen BW14V preregistration is missing or byte-mismatched"
Assert-Exact (
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "f7d8f2eabc907002ac8d3c540ef18040d4f1de5a" -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw14v_physics_world"
) "The BW14V preregistration identity changed"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 2
) "The BW14V closure must name exactly two candidate reports"

$expectedCandidates = @("BW14V-A", "BW14V-B")
$recomputedByCandidate = [ordered]@{}
$totalArtifacts = 0
$totalWalking = 0
$totalFailures = 0
$totalFailedGates = 0
$totalReleaseTimeouts = 0

foreach ($index in 0..1) {
    $entry = $candidateReports[$index]
    Assert-Exact (
        [string]$entry.candidate_id -ceq $expectedCandidates[$index]
    ) "The BW14V candidate report order changed"

    $reportPath = [System.IO.Path]::GetFullPath([string]$entry.path)
    Assert-HashedFile `
        -Path $reportPath `
        -ExpectedSha256 ([string]$entry.sha256) `
        -Message "A retained BW14V report is missing or byte-mismatched"
    $report = (
        Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json -AsHashtable
    )
    $results = @($report.results)
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw14v_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW14V-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.selected_candidate_id -ceq
            [string]$entry.candidate_id -and
        [string]$report.selected_policy_id -ceq
            [string]$entry.controller_policy_id -and
        [string]$report.selected_policy_digest -ceq
            [string]$entry.candidate_policy_digest -and
        [string]$report.source.commit -ceq $expectedSourceCommit -and
        [string]$report.source.origin_main_commit -ceq
            $expectedSourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        $results.Count -eq 36 -and
        [bool]$report.development_complete -and
        [bool]$report.development_data_only -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.physical_acceptance_authority
    ) "A retained BW14V report changed identity or authority"

    $metrics = Measure-SporeExperimentResults `
        -Results $results `
        -ExpectedCount 36
    Assert-Exact (
        (($report.metrics | ConvertTo-Json -Compress -Depth 20) -ceq
            ($metrics | ConvertTo-Json -Compress -Depth 20)) -and
        [int]$metrics.observed_world_count -eq 36 -and
        [int]$metrics.complete_receipt_count -eq 36 -and
        [int]$metrics.harness_pass_count -eq 36 -and
        [int]$metrics.integrity_pass_count -eq 36 -and
        [int]$metrics.mechanism_pass_count -eq 36 -and
        [int]$metrics.combined_application_pass_count -eq 36 -and
        [bool]$metrics.integrity_and_mechanism_complete
    ) "A retained BW14V metric object does not exactly reconstruct"

    $metricVector = @(
        foreach ($key in $metricKeys) {
            $metrics[$key]
        }
    )
    $pinnedVector = @($entry.metric_vector)
    $vectorMatches = $metricVector.Count -eq $pinnedVector.Count
    if ($vectorMatches) {
        for (
            $metricIndex = 0;
            $metricIndex -lt $metricVector.Count;
            $metricIndex += 1
        ) {
            if (
                [BitConverter]::DoubleToInt64Bits(
                    [double]$metricVector[$metricIndex]
                ) -ne
                [BitConverter]::DoubleToInt64Bits(
                    [double]$pinnedVector[$metricIndex]
                )
            ) {
                $vectorMatches = $false
                break
            }
        }
    }
    Assert-Exact (
        $vectorMatches
    ) "A pinned BW14V metric vector changed"
    $recomputedByCandidate[[string]$entry.candidate_id] = $metricVector

    $candidateArtifacts = 0
    foreach ($result in $results) {
        foreach ($kind in @("transcript", "stderr", "engine_log")) {
            $pathKey = "${kind}_path"
            $hashKey = "${kind}_sha256"
            Assert-HashedFile `
                -Path ([System.IO.Path]::GetFullPath(
                    [string]$result[$pathKey]
                )) `
                -ExpectedSha256 ([string]$result[$hashKey]) `
                -Message "A retained BW14V cell artifact changed"
            $candidateArtifacts += 1
        }

        $mechanism = $result.receipt.forward_velocity_foot_placement_summary
        if ([string]$entry.candidate_id -ceq "BW14V-A") {
            Assert-Exact (
                -not [bool]$mechanism.enabled -and
                [int]$mechanism.receipt_count -eq 0 -and
                [double]$mechanism.maximum_absolute_hip_target_correction_rad -eq
                    0.0
            ) "A BW14V-A receipt no longer proves the disabled control"
        } else {
            Assert-Exact (
                [bool]$mechanism.enabled -and
                [string]$mechanism.mode_id -ceq
                    "forward_velocity_foot_placement_v1" -and
                [int]$mechanism.morphology_branch_surface_count -eq 0 -and
                [int]$mechanism.receipt_count -gt 0 -and
                [double]$mechanism.maximum_absolute_hip_target_correction_rad -le
                    0.3 -and
                [double]$mechanism.maximum_absolute_normalized_forward_velocity_error -le
                    1.0 -and
                -not [bool]$mechanism.walking_claim_authorized -and
                -not [bool]$mechanism.physical_acceptance_authority
            ) "A BW14V-B receipt no longer proves the treatment mechanism"
        }
    }

    foreach ($preflight in @(
        $report.full_integrity_preflight,
        $report.experiment_result_integrity_preflight,
        $report.candidate_mechanism_preflight,
        $report.bw14v_entrypoint_preflight
    )) {
        $pathKey = if ($preflight.Contains("transcript_path")) {
            "transcript_path"
        } else {
            "artifact_path"
        }
        $hashKey = if ($pathKey -ceq "transcript_path") {
            "transcript_sha256"
        } else {
            "artifact_sha256"
        }
        Assert-HashedFile `
            -Path ([System.IO.Path]::GetFullPath(
                [string]$preflight[$pathKey]
            )) `
            -ExpectedSha256 ([string]$preflight[$hashKey]) `
            -Message "A retained BW14V preflight artifact changed"
        $candidateArtifacts += 1
    }

    Assert-HashedFile `
        -Path ([System.IO.Path]::GetFullPath(
            [string]$entry.recovery_script_path
        )) `
        -ExpectedSha256 ([string]$entry.recovery_script_sha256) `
        -Message "A BW14V report recovery compiler changed"
    $candidateArtifacts += 1
    Assert-HashedFile `
        -Path ([System.IO.Path]::GetFullPath(
            [string]$entry.recovery_receipt_path
        )) `
        -ExpectedSha256 ([string]$entry.recovery_receipt_sha256) `
        -Message "A BW14V report recovery receipt changed"
    $candidateArtifacts += 1

    $recoveryReceipt = (
        Get-Content -Raw -LiteralPath ([string]$entry.recovery_receipt_path) |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [string]$recoveryReceipt.schema_version -ceq
            "sporespore_bw14v_report_recovery_receipt_v1" -and
        [string]$recoveryReceipt.candidate_id -ceq
            [string]$entry.candidate_id -and
        [string]$recoveryReceipt.source_commit -ceq
            $expectedSourceCommit -and
        [string]$recoveryReceipt.trigger -ceq
            [string]$entry.recovery_trigger -and
        [string]$recoveryReceipt.report_sha256 -ceq
            "sha256:$([string]$entry.sha256)" -and
        [int]$recoveryReceipt.retained_complete_cell_receipt_count -eq 36 -and
        [int]$recoveryReceipt.physical_worlds_rerun -eq 0 -and
        [int]$recoveryReceipt.physical_results_replaced -eq 0 -and
        [int]$recoveryReceipt.physical_results_deleted -eq 0 -and
        -not [bool]$recoveryReceipt.physical_acceptance_authority
    ) "A BW14V recovery receipt changed its no-rerun boundary"

    Assert-Exact (
        $candidateArtifacts -eq 114 -and
        $candidateArtifacts -eq [int]$entry.retained_artifact_count -and
        [bool]$report.full_integrity_preflight.passed -and
        [bool]$report.experiment_result_integrity_preflight.passed -and
        [bool]$report.experiment_result_integrity_preflight.perfect_all_zero_36_cell_matrix_passed -and
        [bool]$report.experiment_result_integrity_preflight.nonzero_ordered_dictionary_canary_passed -and
        [bool]$report.candidate_mechanism_preflight.passed -and
        [bool]$report.bw14v_entrypoint_preflight.passed
    ) "A BW14V candidate lost its exact 114-artifact bundle"

    $totalArtifacts += $candidateArtifacts
    $totalWalking += [int]$metrics.walking_conjunction_pass_count
    $totalFailures += [int]$metrics.walking_conjunction_failure_count
    $totalFailedGates += (
        [int]$metrics.aggregate_failed_production_walking_gate_count
    )
    $totalReleaseTimeouts += [int]$metrics.aggregate_release_timeout_count
}

Assert-Exact (
    [int]$manifest.complete_attempt.observed_world_count -eq 72 -and
    [int]$manifest.complete_attempt.complete_receipt_count -eq 72 -and
    [int]$manifest.complete_attempt.integrity_pass_count -eq 72 -and
    [int]$manifest.complete_attempt.mechanism_pass_count -eq 72 -and
    [int]$manifest.complete_attempt.combined_application_pass_count -eq 72 -and
    $totalWalking -eq 33 -and
    $totalFailures -eq 39 -and
    $totalFailedGates -eq 347 -and
    $totalReleaseTimeouts -eq 194 -and
    $totalArtifacts -eq 228 -and
    [int]$manifest.report_integrity.physical_worlds_rerun_during_recovery -eq
        0
) "The complete BW14V family totals changed"

$selectionPath = [System.IO.Path]::GetFullPath(
    [string]$manifest.selection.path
)
Assert-HashedFile `
    -Path $selectionPath `
    -ExpectedSha256 ([string]$manifest.selection.sha256) `
    -Message "The retained BW14V selection is missing or byte-mismatched"
$selection = (
    Get-Content -Raw -LiteralPath $selectionPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_bw14v_morphology_development_selection_v1" -and
    [string]$selection.source_commit -ceq $expectedSourceCommit -and
    [bool]$selection.all_candidate_reports_observed -and
    -not [bool]$selection.family_selected -and
    [string]$selection.result_status -ceq
        "bw14v_family_rejected_treatment_did_not_strictly_beat_control" -and
    [string]$selection.selected_candidate_id -ceq "" -and
    @($selection.strictly_better_treatment_candidate_ids).Count -eq 0 -and
    [bool]$selection.reserved_qsdk_r05c_remains_unopened -and
    [bool]$selection.unbiased_friction_reservation_remains_unopened -and
    -not [bool]$selection.walking_acceptance -and
    -not [bool]$selection.physical_acceptance_authority
) "The BW14V no-treatment selection disposition changed"

foreach ($selectedReport in @($selection.reports)) {
    $candidateId = [string]$selectedReport.candidate_id
    $selectedVector = @($selectedReport.metric_vector)
    $recomputedVector = @($recomputedByCandidate[$candidateId])
    $vectorMatches = (
        $recomputedByCandidate.Contains($candidateId) -and
        $selectedVector.Count -eq $recomputedVector.Count
    )
    if ($vectorMatches) {
        for (
            $index = 0;
            $index -lt $selectedVector.Count;
            $index += 1
        ) {
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
        $vectorMatches
    ) "The BW14V selector no longer carries reconstructed raw metrics"
}

Assert-Exact (
    [double]$recomputedByCandidate["BW14V-A"][0] -eq 3.0 -and
    [double]$recomputedByCandidate["BW14V-B"][0] -eq 36.0 -and
    [bool]$manifest.scientific_disposition.control_remains_best_observed_arm -and
    [bool]$manifest.scientific_disposition.forward_velocity_foot_placement_family_rejected -and
    -not [bool]$manifest.scientific_disposition.treatment_selected -and
    -not [bool]$manifest.reservations.r05c_opened -and
    [bool]$manifest.reservations.r05c_may_not_be_opened_as_bw14v_validation -and
    -not [bool]$manifest.reservations.unbiased_friction_reservation_opened
) "The BW14V rejection or sealed reservations changed"

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
    )
) "The shared physical-result aggregator changed"
Assert-Exact (
    [bool]$manifest.report_integrity.perfect_synthetic_full_gate_passed_before_both_candidates -and
    [bool]$manifest.report_integrity.nonzero_ordered_dictionary_canary_passed_before_both_candidates -and
    [bool]$manifest.report_integrity.stored_metrics_equal_exact_reconstruction_for_both_candidates -and
    [int]$manifest.report_integrity.retained_artifacts_hash_verified -eq
        $totalArtifacts
) "The BW14V report-integrity boundary changed"

$runnerPath = Join-Path $repoRoot ([string]$manifest.finalizer_repair.path)
$runnerText = Get-Content -Raw -LiteralPath $runnerPath
Assert-Exact (
    $runnerText.Contains('$freezeParentCommit = if (') -and
    $runnerText.Contains(
        'freeze_parent_commit = $freezeParentCommit'
    ) -and
    $runnerText -notmatch
        'freeze_parent_commit\s*=\s*\(\s*if\s*\(' -and
    [bool]$manifest.finalizer_repair.preflight_now_exercises_same_resolution -and
    -not [bool]$manifest.finalizer_repair.physical_rerun_required
) "The BW14V finalizer regression repair changed"

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
    ) "A pinned locomotion research source changed"
}

Write-Host (
    "BW14V_CLOSURE_TEST_PASS worlds=72 walking=33 failures=39 " +
    "failed_gates=347 release_timeouts=194 artifacts=228 " +
    "family_selected=false r05c_opened=false reruns=0 " +
    "physical_authority=false"
)
