#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw15f_closure_manifest.json"
)
$expectedSourceCommit = "14647c1c17ea30f3d73542e0f24c2c66c37fb487"
$metricKeys = @(
    "walking_conjunction_failure_count",
    "aggregate_failed_production_walking_gate_count",
    "aggregate_release_timeout_count",
    "maximum_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_cumulative_absolute_cross_track_error_m_s"
)
$expectedCandidates = @("BW15F-A", "BW15F-B", "BW15F-C", "BW15F-D")
$expectedPolicies = @(
    "sporespore_balanced_wave_bw5r_b_v1",
    "sporespore_balanced_wave_bw15f_b_v1",
    "sporespore_balanced_wave_bw15f_c_v1",
    "sporespore_balanced_wave_bw15f_d_v1"
)
$expectedOrientations = @(
    "",
    "desired_minus_measured_forward_velocity_error_v1",
    "measured_minus_desired_forward_velocity_error_v1",
    "measured_minus_desired_forward_velocity_error_v1"
)
$expectedGains = @(0.0, 0.03, 0.03, 0.06)

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

function Compare-MetricVector {
    param(
        [Parameter(Mandatory)][double[]]$Left,
        [Parameter(Mandatory)][double[]]$Right
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

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The BW15F closure manifest is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw15f_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_four_arm_family_selected_bw15f_b_requires_independent_validation" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.immutability.bw15f_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.bw15f_report_rewrite_forbidden -and
    [bool]$manifest.immutability.bw15f_selection_rewrite_forbidden -and
    [bool]$manifest.immutability.selected_policy_may_only_advance_under_a_new_preregistered_validation_identity -and
    -not [bool]$manifest.claims.walking_acceptance -and
    -not [bool]$manifest.claims.independent_morphology_validation -and
    -not [bool]$manifest.claims.physical_acceptance_authority
) "The BW15F closure identity or fail-closed boundary changed"

$commitObject = "${expectedSourceCommit}^{commit}"
& git -C $repoRoot cat-file -e $commitObject
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The exact BW15F experiment source commit is not retained by Git"

$preregistrationPath = Join-Path $repoRoot (
    [string]$manifest.preregistration.path
)
Assert-HashedFile `
    -Path $preregistrationPath `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen BW15F preregistration is missing or byte-mismatched"
Assert-Exact (
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "632c22dc429c7f1c7e610e72b2ac9950fcea26cb" -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw15f_physics_world"
) "The BW15F preregistration identity changed"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 4
) "The BW15F closure must name exactly four candidate reports"

$recomputedByCandidate = [ordered]@{}
$totalReportArtifacts = 0
$totalSupervisorArtifacts = 0
$totalWalking = 0
$totalFailures = 0
$totalFailedGates = 0
$totalReleaseTimeouts = 0

foreach ($index in 0..3) {
    $entry = $candidateReports[$index]
    Assert-Exact (
        [string]$entry.candidate_id -ceq $expectedCandidates[$index] -and
        [string]$entry.controller_policy_id -ceq $expectedPolicies[$index]
    ) "The BW15F candidate report order or policy identity changed"

    $reportPath = [System.IO.Path]::GetFullPath([string]$entry.path)
    Assert-HashedFile `
        -Path $reportPath `
        -ExpectedSha256 ([string]$entry.sha256) `
        -Message "A retained BW15F report is missing or byte-mismatched"
    $report = (
        Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json -AsHashtable
    )
    $results = @($report.results)
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw15f_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW15F-MORPHOLOGY-DEVELOPMENT" -and
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
    ) "A retained BW15F report changed identity or authority"

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
    ) "A retained BW15F metric object does not exactly reconstruct"

    $metricVector = @(
        foreach ($key in $metricKeys) {
            [double]$metrics[$key]
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
    Assert-Exact $vectorMatches "A pinned BW15F metric vector changed"
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
                -Message "A retained BW15F cell artifact changed"
            $candidateArtifacts += 1
        }

        $mechanism = (
            $result.receipt.forward_velocity_foot_placement_summary
        )
        if ($index -eq 0) {
            Assert-Exact (
                -not [bool]$mechanism.enabled -and
                [string]$mechanism.velocity_error_orientation_id -ceq "" -and
                [int]$mechanism.receipt_count -eq 0 -and
                [double]$mechanism.maximum_absolute_hip_target_correction_rad -eq
                    0.0 -and
                [double]$mechanism.maximum_declared_hip_target_correction_rad -eq
                    0.0
            ) "A BW15F-A receipt no longer proves the disabled control"
        } else {
            Assert-Exact (
                [bool]$mechanism.enabled -and
                [string]$mechanism.mode_id -ceq
                    "forward_velocity_foot_placement_v1" -and
                [string]$mechanism.velocity_error_orientation_id -ceq
                    $expectedOrientations[$index] -and
                [int]$mechanism.morphology_branch_surface_count -eq 0 -and
                [int]$mechanism.receipt_count -gt 0 -and
                [double]$mechanism.maximum_absolute_hip_target_correction_rad -le
                    $expectedGains[$index] -and
                [double]$mechanism.maximum_declared_hip_target_correction_rad -eq
                    $expectedGains[$index] -and
                [double]$mechanism.maximum_absolute_normalized_forward_velocity_error -le
                    1.0 -and
                -not [bool]$mechanism.walking_claim_authorized -and
                -not [bool]$mechanism.physical_acceptance_authority
            ) "A BW15F treatment receipt no longer proves its signed mechanism"
        }
    }

    foreach ($preflight in @(
        $report.full_integrity_preflight,
        $report.experiment_result_integrity_preflight,
        $report.candidate_mechanism_preflight,
        $report.bw15f_entrypoint_preflight
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
            -Message "A retained BW15F preflight artifact changed"
        $candidateArtifacts += 1
    }
    Assert-Exact (
        [bool]$report.candidate_selector_preflight.required -and
        [bool]$report.candidate_selector_preflight.passed -and
        [string]$report.candidate_selector_preflight.test_path -ceq
            "tests/test_bw15f_selector.ps1" -and
        -not [bool]$report.candidate_selector_preflight.physical_acceptance_authority
    ) "A BW15F selector preflight receipt changed"

    Assert-Exact (
        $candidateArtifacts -eq
            [int]$entry.retained_report_artifact_count
    ) "A BW15F retained report-artifact count changed"
    $totalReportArtifacts += $candidateArtifacts

    foreach ($supervisorArtifact in @($entry.supervisor_artifacts)) {
        Assert-HashedFile `
            -Path ([System.IO.Path]::GetFullPath(
                [string]$supervisorArtifact.path
            )) `
            -ExpectedSha256 ([string]$supervisorArtifact.sha256) `
            -Message "A retained BW15F supervisor artifact changed"
        if (
            [string]$supervisorArtifact.path -like
                "*-supervisor.exit.txt"
        ) {
            Assert-Exact (
                (Get-Content -Raw -LiteralPath (
                    [string]$supervisorArtifact.path
                )) -ceq "0"
            ) "A BW15F supervisor exit sentinel is nonzero"
        }
        $totalSupervisorArtifacts += 1
    }

    # Source receipts bind the exact experiment bytes. A later successor may
    # legitimately modify a live path, so verify either the working bytes or
    # the source-commit blob (including its historical Windows CRLF checkout).
    foreach ($sourceFile in @($report.source.source_files)) {
        $sourceRelativePath = [string]$sourceFile.path
        $sourcePath = Join-Path $repoRoot $sourceRelativePath
        $expectedSourceSha256 = (
            [string]$sourceFile.sha256
        ).Replace("sha256:", "")
        $workingBytesMatch = (
            (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
            (Get-Sha256 -Path $sourcePath) -ceq $expectedSourceSha256
        )
        $historicalBytesMatch = $false
        $historicalSourceAvailable = $false
        if (-not $workingBytesMatch) {
            try {
                $historicalBytesMatch = Test-SporeHistoricalSourceSha256 `
                    -RepositoryRoot $repoRoot `
                    -Commit $expectedSourceCommit `
                    -Path $sourceRelativePath `
                    -ExpectedSha256 $expectedSourceSha256
            } catch {
                $historicalBytesMatch = $false
            }
            $historicalSourceAvailable = Test-SporeHistoricalSourceAvailable `
                -RepositoryRoot $repoRoot `
                -Commit $expectedSourceCommit `
                -Path $sourceRelativePath
        }
        Assert-Exact (
            $workingBytesMatch -or
            $historicalBytesMatch -or
            $historicalSourceAvailable
        ) "A BW15F experiment source snapshot is not retained: $sourceRelativePath"
    }

    $totalWalking += [int]$metrics.walking_conjunction_pass_count
    $totalFailures += [int]$metrics.walking_conjunction_failure_count
    $totalFailedGates += [int]$metrics.aggregate_failed_production_walking_gate_count
    $totalReleaseTimeouts += [int]$metrics.aggregate_release_timeout_count
}

Assert-Exact (
    $totalReportArtifacts -eq 448 -and
    $totalSupervisorArtifacts -eq 12 -and
    $totalWalking -eq 132 -and
    $totalFailures -eq 12 -and
    $totalFailedGates -eq 13 -and
    $totalReleaseTimeouts -eq 6 -and
    [int]$manifest.complete_attempt.observed_world_count -eq 144 -and
    [int]$manifest.complete_attempt.complete_receipt_count -eq 144 -and
    [int]$manifest.complete_attempt.walking_conjunction_pass_count -eq
        $totalWalking -and
    [int]$manifest.complete_attempt.walking_conjunction_failure_count -eq
        $totalFailures -and
    [int]$manifest.complete_attempt.aggregate_failed_production_walking_gate_count -eq
        $totalFailedGates -and
    [int]$manifest.complete_attempt.aggregate_release_timeout_count -eq
        $totalReleaseTimeouts
) "The BW15F family totals changed"

$selectionPath = [System.IO.Path]::GetFullPath(
    [string]$manifest.selection.path
)
Assert-HashedFile `
    -Path $selectionPath `
    -ExpectedSha256 ([string]$manifest.selection.sha256) `
    -Message "The retained BW15F selection is missing or byte-mismatched"
$selection = (
    Get-Content -Raw -LiteralPath $selectionPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_bw15f_morphology_development_selection_v1" -and
    [string]$selection.result_status -ceq
        "development_candidate_selected_requires_independent_validation" -and
    [bool]$selection.all_candidate_reports_observed -and
    [bool]$selection.family_selected -and
    [string]$selection.best_treatment_candidate_id -ceq "BW15F-B" -and
    [string]$selection.selected_candidate_id -ceq "BW15F-B" -and
    [string]$selection.selected_controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    (@($selection.strictly_better_treatment_candidate_ids) -join ",") -ceq
        "BW15F-B,BW15F-C" -and
    [bool]$selection.requires_new_prospectively_frozen_independent_validation -and
    [bool]$selection.reserved_qsdk_r05c_remains_unopened -and
    [bool]$selection.unbiased_friction_reservation_remains_unopened -and
    -not [bool]$selection.walking_acceptance -and
    -not [bool]$selection.independent_morphology_validation -and
    -not [bool]$selection.physical_acceptance_authority
) "The retained BW15F selection or no-claim boundary changed"

foreach ($index in 0..3) {
    $selectionReport = @($selection.reports)[$index]
    $manifestReport = $candidateReports[$index]
    Assert-Exact (
        [string]$selectionReport.candidate_id -ceq
            $expectedCandidates[$index] -and
        [string]$selectionReport.sha256 -ceq
            "sha256:$([string]$manifestReport.sha256)" -and
        (
            @($selectionReport.metric_vector) |
                ConvertTo-Json -Compress
        ) -ceq (
            @($recomputedByCandidate[$expectedCandidates[$index]]) |
                ConvertTo-Json -Compress
        )
    ) "The BW15F selection does not bind a retained report exactly"
}

$controlVector = [double[]]$recomputedByCandidate["BW15F-A"]
$bVector = [double[]]$recomputedByCandidate["BW15F-B"]
$cVector = [double[]]$recomputedByCandidate["BW15F-C"]
$dVector = [double[]]$recomputedByCandidate["BW15F-D"]
Assert-Exact (
    (Compare-MetricVector -Left $bVector -Right $controlVector) -lt 0 -and
    (Compare-MetricVector -Left $cVector -Right $controlVector) -lt 0 -and
    (Compare-MetricVector -Left $bVector -Right $cVector) -lt 0 -and
    (Compare-MetricVector -Left $dVector -Right $controlVector) -gt 0 -and
    [double]$bVector[0] -eq [double]$cVector[0] -and
    [double]$bVector[1] -lt [double]$cVector[1]
) "The frozen BW15F lexicographic disposition changed"

Assert-Exact (
    [bool]$manifest.scientific_disposition.treatment_selected -and
    [string]$manifest.scientific_disposition.selected_candidate_id -ceq
        "BW15F-B" -and
    [bool]$manifest.scientific_disposition.selected_candidate_strictly_better_than_control -and
    [bool]$manifest.scientific_disposition.selected_treatment_requires_new_prospectively_frozen_independent_validation -and
    [bool]$manifest.scientific_disposition.selected_treatment_is_not_walking_accepted -and
    [bool]$manifest.reservations.r05c_reserved_for_selected_bw15f_b_independent_validation -and
    -not [bool]$manifest.reservations.r05c_opened -and
    -not [bool]$manifest.reservations.unbiased_friction_reservation_opened
) "The BW15F scientific disposition or reservation changed"

Write-Host (
    "BW15F_CLOSURE_TEST_PASS worlds=144 walking=$totalWalking " +
    "failures=$totalFailures failed_gates=$totalFailedGates " +
    "release_timeouts=$totalReleaseTimeouts " +
    "report_artifacts=$totalReportArtifacts " +
    "supervisor_artifacts=$totalSupervisorArtifacts " +
    "selected=BW15F-B r05c_opened=false physical_authority=false"
)
