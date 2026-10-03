#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw16s_closure_manifest.json"
)
$expectedSourceCommit = "896a49ca57452ad1a2e1d3d1c63cdf1de4dd0dc8"
$expectedCandidates = @("BW16S-A", "BW16S-B")
$expectedStabilityPolicies = @(
    "p5i3b_weight_support_shadow_v1",
    "p5i3c_support_centroid_tilt_feedback_v1"
)
$expectedAuthorityScopes = @(
    "post_settle_full",
    "stability_contribution_overlay"
)
$expectedExecutionModes = @(
    "native_authority_with_legacy_observer",
    "portable_balanced_wave_base_with_stability_overlay"
)
$expectedCompositionDigests = @(
    "sha256:5fdd2fae60409d31fb66c7152cecf7123e8cf410c56dd902a21ea90aad037bce",
    "sha256:e77f0ab9a8828a95c1c6d30003a381b5d4a8386a4ff49df270fcf31b86e0c94c"
)
$expectedMorphologyIds = @(
    foreach ($index in 193..204) {
        "qsdk_r05c_generated_s$index"
    }
)
$expectedSeeds = @(38101, 38102, 38103)
$metricKeys = @(
    "walking_conjunction_failure_count",
    "aggregate_failed_production_walking_gate_count",
    "aggregate_release_timeout_count",
    "maximum_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_normalized_absolute_task_frame_lateral_displacement",
    "aggregate_cumulative_absolute_cross_track_error_m_s"
)
$falseClaimKeys = @(
    "walking_acceptance",
    "balance_improvement",
    "independent_morphology_validation",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "material_or_friction_robustness",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "different_physics_engines",
    "six_eight_or_many_legged_creatures",
    "running",
    "completed_engine_neutral_sdk",
    "bipedal_creatures",
    "release_authorized",
    "physical_acceptance_authority"
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

function Assert-VectorBitsEqual {
    param(
        [Parameter(Mandatory)][object[]]$Actual,
        [Parameter(Mandatory)][object[]]$Expected,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact ($Actual.Count -eq $Expected.Count) $Message
    for ($index = 0; $index -lt $Actual.Count; $index += 1) {
        Assert-Exact (
            [BitConverter]::DoubleToInt64Bits([double]$Actual[$index]) -eq
            [BitConverter]::DoubleToInt64Bits([double]$Expected[$index])
        ) $Message
    }
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
) "The BW16S closure manifest is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw16s_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_paired_family_rejected_treatment_worse_than_control" -and
    [string]$manifest.gate_id -ceq "BW16S" -and
    [string]$manifest.campaign_id -ceq
        "BW16S-MORPHOLOGY-DEVELOPMENT" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.cohort_outcome_exposed -and
    [bool]$manifest.immutability.bw16s_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.bw16s_report_rewrite_forbidden -and
    [bool]$manifest.immutability.bw16s_selection_rewrite_forbidden -and
    [bool]$manifest.immutability.balance_overlay_may_not_advance_from_this_rejected_family
) "The BW16S closure identity or immutable rejection boundary changed"

$commitObject = "${expectedSourceCommit}^{commit}"
& git -C $repoRoot cat-file -e $commitObject
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The exact BW16S experiment source commit is not retained by Git"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW16S source commit is not an ancestor of the active closure"
$originMain = (
    & git -C $repoRoot rev-parse origin/main
).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing BW16S"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW16S source commit is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen BW16S preregistration is missing or changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.preregistration.candidate_declaration_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.preregistration.candidate_declaration_raw_sha256
    ) `
    -Message "The frozen BW16S candidate declaration is missing or changed"
Assert-Exact (
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "5d44eb1ebdcd7cae8a56b4964486fd110616c67d" -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw16s_physics_world"
) "The BW16S prospective freeze identity changed"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 2
) "The BW16S closure must retain exactly two candidate reports"

$reconstructedMetrics = [ordered]@{}
$reconstructedVectors = [ordered]@{}
$verifiedReportFileCount = 0
$verifiedSourceHashCount = 0
$verifiedCellAndPreflightArtifactCount = 0
$verifiedSupervisorArtifactCount = 0
$totalObserved = 0
$totalReceipts = 0
$totalHarness = 0
$totalIntegrity = 0
$totalMechanism = 0
$totalApplication = 0
$totalWalking = 0
$totalWalkingFailures = 0
$totalRawFalseGates = 0L
$totalReleaseTimeouts = 0L

foreach ($candidateIndex in 0..1) {
    $entry = $candidateReports[$candidateIndex]
    $candidateId = $expectedCandidates[$candidateIndex]
    Assert-Exact (
        [string]$entry.candidate_id -ceq $candidateId -and
        [string]$entry.controller_policy_id -ceq
            "sporespore_balanced_wave_bw15f_b_v1" -and
        [string]$entry.controller_policy_digest -ceq
            "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd" -and
        [string]$entry.stability_policy_id -ceq
            $expectedStabilityPolicies[$candidateIndex] -and
        [string]$entry.authority_scope -ceq
            $expectedAuthorityScopes[$candidateIndex] -and
        [string]$entry.execution_mode -ceq
            $expectedExecutionModes[$candidateIndex] -and
        [string]$entry.candidate_composition_digest -ceq
            $expectedCompositionDigests[$candidateIndex]
    ) "The BW16S candidate order, controller, or composition changed"

    $reportPath = [System.IO.Path]::GetFullPath([string]$entry.path)
    Assert-HashedFile `
        -Path $reportPath `
        -ExpectedSha256 ([string]$entry.sha256) `
        -Message "A retained BW16S report is missing or byte-mismatched"
    $verifiedReportFileCount += 1
    $report = (
        Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json -AsHashtable
    )
    $results = @($report.results)

    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw16s_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW16S-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.gate_id -ceq "BW16S" -and
        [string]$report.campaign_role -ceq
            "paired_outcome_exposed_portable_balance_composition_development" -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.candidate_composition_digest -ceq
            [string]$entry.candidate_composition_digest -and
        [string]$report.selected_candidate_id -ceq "BW15F-B" -and
        [string]$report.controller_policy_id -ceq
            [string]$entry.controller_policy_id -and
        [string]$report.controller_policy_digest -ceq
            [string]$entry.controller_policy_digest -and
        [string]$report.stability_policy_id -ceq
            [string]$entry.stability_policy_id -and
        [string]$report.authority_scope -ceq
            [string]$entry.authority_scope -and
        [string]$report.execution_mode -ceq
            [string]$entry.execution_mode -and
        [string]$report.source.commit -ceq $expectedSourceCommit -and
        [string]$report.source.origin_main_commit -ceq
            $expectedSourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        $results.Count -eq 36 -and
        [bool]$report.development_complete -and
        [bool]$report.development_data_only -and
        [bool]$report.cohort_outcome_exposed -and
        [bool]$report.finite_population_only -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.physical_acceptance_authority
    ) "A retained BW16S report changed identity or authority"

    $sourceFiles = @($report.source.source_files)
    $sourcePaths = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    Assert-Exact (
        $sourceFiles.Count -eq 30
    ) "A BW16S report must retain exactly 30 source files"
    foreach ($sourceFile in $sourceFiles) {
        $sourcePath = [string]$sourceFile.path
        Assert-Exact (
            $sourcePaths.Add($sourcePath)
        ) "A BW16S source inventory contains a duplicate: $sourcePath"
        $workingSourcePath = Join-Path $repoRoot $sourcePath
        $expectedSourceSha256 = (
            [string]$sourceFile.sha256
        ).Replace("sha256:", "")
        $workingBytesMatch = (
            (Test-Path -LiteralPath $workingSourcePath -PathType Leaf) -and
            (Get-Sha256 -Path $workingSourcePath) -ceq
                $expectedSourceSha256
        )
        $historicalBytesMatch = $false
        $historicalSourceAvailable = $false
        if (-not $workingBytesMatch) {
            try {
                $historicalBytesMatch = Test-SporeHistoricalSourceSha256 `
                    -RepositoryRoot $repoRoot `
                    -Commit $expectedSourceCommit `
                    -Path $sourcePath `
                    -ExpectedSha256 $expectedSourceSha256
            } catch {
                $historicalBytesMatch = $false
            }
            $historicalSourceAvailable = Test-SporeHistoricalSourceAvailable `
                -RepositoryRoot $repoRoot `
                -Commit $expectedSourceCommit `
                -Path $sourcePath
        }
        Assert-Exact (
            $workingBytesMatch -or
            $historicalBytesMatch -or
            $historicalSourceAvailable
        ) "A retained BW16S source snapshot is unavailable: $sourcePath"
        $verifiedSourceHashCount += 1
    }
    foreach (
        $researchPath in @(
            "DReCon.pdf",
            "2604.08780v1.pdf",
            "2507.22653v2.pdf",
            "docs/research/LOCOMOTION_RESEARCH_SOURCES.md"
        )
    ) {
        Assert-Exact (
            $sourcePaths.Contains($researchPath)
        ) "A BW16S report lost research provenance: $researchPath"
    }

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
    ) "A retained BW16S metric object does not exactly reconstruct"
    $metricVector = @(
        foreach ($metricKey in $metricKeys) {
            [double]$metrics[$metricKey]
        }
    )
    Assert-VectorBitsEqual `
        -Actual $metricVector `
        -Expected @($entry.metric_vector) `
        -Message "A retained BW16S metric vector changed"
    $reconstructedMetrics[$candidateId] = $metrics
    $reconstructedVectors[$candidateId] = $metricVector

    foreach (
        $preflightKey in @(
            "full_integrity_preflight",
            "experiment_result_integrity_preflight",
            "candidate_authority_preflight",
            "bw16s_entrypoint_preflight"
        )
    ) {
        $preflight = $report[$preflightKey]
        Assert-Exact (
            [bool]$preflight.passed -and
            [int]$preflight.actual_world_build_count -eq 0
        ) "A mandatory BW16S zero-world preflight changed: $preflightKey"
        Assert-HashedFile `
            -Path ([string]$preflight.artifact_path) `
            -ExpectedSha256 ([string]$preflight.artifact_sha256) `
            -Message "A retained BW16S preflight artifact changed"
        $verifiedCellAndPreflightArtifactCount += 1
    }
    Assert-Exact (
        [bool]$report.r05c_closure_preflight.passed -and
        [int]$report.r05c_closure_preflight.actual_world_build_count -eq 0 -and
        [bool]$report.experiment_result_integrity_preflight.perfect_all_zero_36_cell_matrix_passed -and
        [bool]$report.experiment_result_integrity_preflight.nonzero_ordered_dictionary_canary_passed -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_failed_production_walking_gate_count -eq 3 -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_release_timeout_count -eq 2 -and
        [bool]$report.selector_preflight.passed -and
        [int]$report.selector_preflight.actual_world_build_count -eq 0 -and
        -not [bool]$report.selector_preflight.physical_acceptance_authority -and
        [int]$report.bw16s_entrypoint_preflight.cell_count -eq 36 -and
        [int]$report.bw16s_entrypoint_preflight.exact_candidate_adapter_start_count -eq 36 -and
        [int]$report.bw16s_entrypoint_preflight.exact_declared_policy_runtime_boundary_count -eq 36
    ) "A BW16S mandatory preflight receipt changed"

    $actualPairs = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $actualTotals = [ordered]@{
        sdk_step_count = 0L
        validated_balanced_wave_command_count = 0L
        native_motor_write_count = 0L
        direct_body_write_count = 0L
        legacy_post_settle_motor_write_count = 0L
        legacy_evidence_motor_write_count = 0L
        legacy_overlay_base_motor_write_count = 0L
        stability_contribution_attempt_count = 0L
        stability_contribution_influence_output_count = 0L
        feedback_nonzero_attempt_count = 0L
        overlay_application_step_count = 0L
        overlay_motor_write_count = 0L
        overlay_nonzero_effective_application_count = 0L
    }
    $actualRawFalseGateCount = 0L
    $actualReleaseTimeoutCount = 0L
    $physicalInfluenceCount = 0

    foreach ($result in $results) {
        $pair = (
            [string]$result.morphology_id + "|" +
            [string]$result.campaign_seed
        )
        Assert-Exact (
            $actualPairs.Add($pair) -and
            $expectedMorphologyIds -ccontains
                [string]$result.morphology_id -and
            $expectedSeeds -contains [int]$result.campaign_seed
        ) "A BW16S report contains a duplicate or undeclared cell: $pair"
        $receipt = $result.receipt
        Assert-Exact (
            [int]$result.process_exit_code -eq 0 -and
            -not [bool]$result.timed_out -and
            -not [bool]$result.killed_process_tree -and
            [bool]$result.receipt_parsed -and
            [string]$result.receipt_parse_error -ceq "" -and
            [bool]$result.harness_passed -and
            [bool]$result.common_execution_integrity -and
            [bool]$result.mechanism_gate_passed -and
            [bool]$result.combined_application_gate_passed -and
            [string]$receipt.schema_version -ceq
                "sporespore_bw16s_morphology_development_cell_v1" -and
            [string]$receipt.campaign_id -ceq
                "BW16S-MORPHOLOGY-DEVELOPMENT" -and
            [string]$receipt.gate_id -ceq "BW16S" -and
            [string]$receipt.candidate_id -ceq $candidateId -and
            [string]$receipt.candidate_composition_digest -ceq
                [string]$entry.candidate_composition_digest -and
            [string]$receipt.controller_policy_id -ceq
                [string]$entry.controller_policy_id -and
            [string]$receipt.selected_policy_digest -ceq
                [string]$entry.controller_policy_digest -and
            [string]$receipt.stability_policy_id -ceq
                [string]$entry.stability_policy_id -and
            [string]$receipt.authority_scope -ceq
                [string]$entry.authority_scope -and
            [string]$receipt.execution_mode -ceq
                [string]$entry.execution_mode -and
            [bool]$receipt.common_execution_integrity -and
            [bool]$receipt.mechanism_gate_passed -and
            [bool]$receipt.combined_application_gate_passed -and
            [bool]$receipt.sdk_authority_enabled -and
            [int]$receipt.world_build_count -eq 1 -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "A retained BW16S technical receipt changed: $pair"

        Assert-Exact (
            [long]$receipt.validated_balanced_wave_command_count -eq
                ([long]$receipt.sdk_step_count * 8L) -and
            [long]$receipt.native_motor_write_count -eq
                [long]$receipt.validated_balanced_wave_command_count -and
            [long]$receipt.direct_body_write_count -eq 0L -and
            [long]$receipt.sdk_mismatch_count -eq 0L -and
            [long]$receipt.sdk_safe_disable_count -eq 0L -and
            [long]$receipt.sdk_safe_no_actuation_count -eq 0L -and
            [string]$receipt.forward_velocity_foot_placement_summary.schema_version -ceq
                "sporespore_forward_velocity_foot_placement_execution_summary_v1" -and
            [bool]$receipt.forward_velocity_foot_placement_summary.enabled -and
            [string]$receipt.forward_velocity_foot_placement_summary.velocity_error_orientation_id -ceq
                "desired_minus_measured_forward_velocity_error_v1" -and
            [double]$receipt.forward_velocity_foot_placement_summary.maximum_declared_hip_target_correction_rad -eq
                0.03 -and
            [int]$receipt.forward_velocity_foot_placement_summary.morphology_branch_surface_count -eq
                0
        ) "A BW16S controller or command/write invariant failed: $pair"

        $contribution = $receipt.stability_contribution_shadow_summary
        $overlay = $receipt.stability_overlay_summary
        Assert-Exact (
            [string]$contribution.schema_version -ceq
                "sporespore_godot_jolt_stability_contribution_shadow_summary_v1" -and
            [bool]$contribution.ok -and
            [int]$contribution.mismatch_count -eq 0 -and
            [int]$contribution.inactive_zero_mismatch_count -eq 0 -and
            [int]$contribution.limiter_mismatch_count -eq 0 -and
            [int]$contribution.profile_conversion_failure_count -eq 0 -and
            [string]$overlay.schema_version -ceq
                "sporespore_godot_jolt_stability_overlay_summary_v1" -and
            [bool]$overlay.ok -and
            [int]$overlay.failure_count -eq 0 -and
            [int]$overlay.combined_speed_limit_violation_count -eq 0 -and
            [int]$overlay.direct_body_write_count -eq 0 -and
            [double]$overlay.maximum_readback_error_rad_s -le
                [double]$overlay.readback_tolerance_rad_s
        ) "A BW16S stability mechanism receipt failed: $pair"

        if ($candidateId -ceq "BW16S-A") {
            Assert-Exact (
                -not [bool]$receipt.stability_feedback_policy_manifest.enabled -and
                -not [bool]$receipt.stability_physical_overlay_manifest.enabled -and
                -not [bool]$overlay.physical_influence -and
                [int]$contribution.feedback_nonzero_attempt_count -eq 0 -and
                [int]$overlay.application_step_count -eq 0 -and
                [int]$overlay.motor_write_count -eq 0 -and
                [int]$overlay.nonzero_effective_application_count -eq 0 -and
                [long]$receipt.legacy_overlay_base_motor_write_count -eq 0L -and
                [long]$receipt.legacy_post_settle_motor_write_count -eq 0L -and
                [long]$receipt.legacy_evidence_motor_write_count -eq 0L
            ) "A BW16S-A exclusive-control invariant failed: $pair"
        } else {
            Assert-Exact (
                [bool]$receipt.stability_feedback_policy_manifest.enabled -and
                [bool]$receipt.stability_physical_overlay_manifest.enabled -and
                [bool]$overlay.physical_influence -and
                [string]$overlay.authority_scope -ceq
                    "stability_contribution_overlay" -and
                [string]$overlay.policy_id -ceq
                    "p5i3c_support_centroid_tilt_feedback_v1" -and
                [long]$contribution.attempt_count -eq
                    [long]$receipt.sdk_step_count -and
                [long]$contribution.influence_output_count -eq
                    ([long]$receipt.sdk_step_count * 8L) -and
                [int]$contribution.feedback_nonzero_attempt_count -gt 0 -and
                [long]$overlay.application_step_count -eq
                    [long]$receipt.sdk_step_count -and
                [long]$overlay.motor_write_count -eq
                    ([long]$receipt.sdk_step_count * 8L) -and
                [long]$overlay.portable_controller_base_application_count -eq
                    ([long]$receipt.sdk_step_count * 8L) -and
                [int]$overlay.nonzero_effective_application_count -gt 0 -and
                [long]$receipt.legacy_overlay_base_motor_write_count -eq
                    ([long]$receipt.sdk_step_count * 8L)
            ) "A BW16S-B physical-overlay invariant failed: $pair"
            $physicalInfluenceCount += 1
        }

        $falseGateCount = 0L
        foreach ($walkingGate in $receipt.walking_gate_receipts.GetEnumerator()) {
            if (-not [bool]$walkingGate.Value) {
                $falseGateCount += 1L
            }
        }
        Assert-Exact (
            [long]$result.failed_production_walking_gate_count -eq
                $falseGateCount -and
            [long]$receipt.failed_production_walking_gate_count -eq
                $falseGateCount -and
            [long]$result.release_timeout_count -eq
                [long]$receipt.release_timeout_count -and
            [bool]$result.walking_observed -eq
                ($falseGateCount -eq 0L) -and
            [bool]$receipt.walking_observed -eq
                [bool]$result.walking_observed
        ) "A BW16S raw walking or timeout receipt changed: $pair"
        $actualRawFalseGateCount += $falseGateCount
        $actualReleaseTimeoutCount += [long]$result.release_timeout_count

        foreach (
            $artifact in @(
                [ordered]@{
                    path = [string]$result.transcript_path
                    sha256 = [string]$result.transcript_sha256
                },
                [ordered]@{
                    path = [string]$result.stderr_path
                    sha256 = [string]$result.stderr_sha256
                },
                [ordered]@{
                    path = [string]$result.engine_log_path
                    sha256 = [string]$result.engine_log_sha256
                }
            )
        ) {
            Assert-HashedFile `
                -Path ([string]$artifact.path) `
                -ExpectedSha256 ([string]$artifact.sha256) `
                -Message "A retained BW16S cell artifact changed: $pair"
            $verifiedCellAndPreflightArtifactCount += 1
        }

        $actualTotals.sdk_step_count += [long]$receipt.sdk_step_count
        $actualTotals.validated_balanced_wave_command_count += (
            [long]$receipt.validated_balanced_wave_command_count
        )
        $actualTotals.native_motor_write_count += (
            [long]$receipt.native_motor_write_count
        )
        $actualTotals.direct_body_write_count += (
            [long]$receipt.direct_body_write_count
        )
        $actualTotals.legacy_post_settle_motor_write_count += (
            [long]$receipt.legacy_post_settle_motor_write_count
        )
        $actualTotals.legacy_evidence_motor_write_count += (
            [long]$receipt.legacy_evidence_motor_write_count
        )
        $actualTotals.legacy_overlay_base_motor_write_count += (
            [long]$receipt.legacy_overlay_base_motor_write_count
        )
        $actualTotals.stability_contribution_attempt_count += (
            [long]$contribution.attempt_count
        )
        $actualTotals.stability_contribution_influence_output_count += (
            [long]$contribution.influence_output_count
        )
        $actualTotals.feedback_nonzero_attempt_count += (
            [long]$contribution.feedback_nonzero_attempt_count
        )
        $actualTotals.overlay_application_step_count += (
            [long]$overlay.application_step_count
        )
        $actualTotals.overlay_motor_write_count += (
            [long]$overlay.motor_write_count
        )
        $actualTotals.overlay_nonzero_effective_application_count += (
            [long]$overlay.nonzero_effective_application_count
        )
    }

    Assert-Exact (
        $actualPairs.Count -eq 36 -and
        $actualRawFalseGateCount -eq
            [long]$metrics.aggregate_failed_production_walking_gate_count -and
        $actualReleaseTimeoutCount -eq
            [long]$metrics.aggregate_release_timeout_count -and
        (
            ($candidateId -ceq "BW16S-A" -and
                $physicalInfluenceCount -eq 0) -or
            ($candidateId -ceq "BW16S-B" -and
                $physicalInfluenceCount -eq 36)
        )
    ) "A BW16S candidate aggregate or physical-influence count changed"

    foreach (
        $totalEntry in (
            $entry.authority_and_mechanism_totals.GetEnumerator()
        )
    ) {
        Assert-Exact (
            [long]$actualTotals[[string]$totalEntry.Key] -eq
                [long]$totalEntry.Value
        ) "A BW16S authority/mechanism total changed: $candidateId/$($totalEntry.Key)"
    }

    Assert-Exact (
        [int]$entry.retained_report_artifact_count -eq 112
    ) "A BW16S per-report artifact count changed"
    foreach ($supervisorArtifact in @($entry.supervisor_artifacts)) {
        Assert-HashedFile `
            -Path ([string]$supervisorArtifact.path) `
            -ExpectedSha256 ([string]$supervisorArtifact.sha256) `
            -Message "A retained BW16S supervisor artifact changed"
        $verifiedSupervisorArtifactCount += 1
    }

    $totalObserved += [int]$metrics.observed_world_count
    $totalReceipts += [int]$metrics.complete_receipt_count
    $totalHarness += [int]$metrics.harness_pass_count
    $totalIntegrity += [int]$metrics.integrity_pass_count
    $totalMechanism += [int]$metrics.mechanism_pass_count
    $totalApplication += [int]$metrics.combined_application_pass_count
    $totalWalking += [int]$metrics.walking_conjunction_pass_count
    $totalWalkingFailures += [int]$metrics.walking_conjunction_failure_count
    $totalRawFalseGates += (
        [long]$metrics.aggregate_failed_production_walking_gate_count
    )
    $totalReleaseTimeouts += (
        [long]$metrics.aggregate_release_timeout_count
    )
}

Assert-Exact (
    $totalObserved -eq 72 -and
    $totalReceipts -eq 72 -and
    $totalHarness -eq 72 -and
    $totalIntegrity -eq 72 -and
    $totalMechanism -eq 72 -and
    $totalApplication -eq 72 -and
    $totalWalking -eq 57 -and
    $totalWalkingFailures -eq 15 -and
    $totalRawFalseGates -eq 35L -and
    $totalReleaseTimeouts -eq 17L -and
    $verifiedReportFileCount -eq 2 -and
    $verifiedSourceHashCount -eq 60 -and
    $verifiedCellAndPreflightArtifactCount -eq 224 -and
    $verifiedSupervisorArtifactCount -eq 4
) "The complete BW16S family counts or retained evidence changed"
foreach (
    $countKey in @(
        "observed_world_count",
        "complete_receipt_count",
        "harness_pass_count",
        "integrity_pass_count",
        "mechanism_pass_count",
        "combined_application_pass_count",
        "walking_conjunction_pass_count",
        "walking_conjunction_failure_count",
        "aggregate_failed_production_walking_gate_count",
        "aggregate_release_timeout_count"
    )
) {
    $actualCount = switch ($countKey) {
        "observed_world_count" { $totalObserved }
        "complete_receipt_count" { $totalReceipts }
        "harness_pass_count" { $totalHarness }
        "integrity_pass_count" { $totalIntegrity }
        "mechanism_pass_count" { $totalMechanism }
        "combined_application_pass_count" { $totalApplication }
        "walking_conjunction_pass_count" { $totalWalking }
        "walking_conjunction_failure_count" { $totalWalkingFailures }
        "aggregate_failed_production_walking_gate_count" {
            $totalRawFalseGates
        }
        "aggregate_release_timeout_count" { $totalReleaseTimeouts }
    }
    Assert-Exact (
        [long]$manifest.complete_attempt[$countKey] -eq [long]$actualCount
    ) "The BW16S manifest family count changed: $countKey"
}

$selectionPath = [System.IO.Path]::GetFullPath(
    [string]$manifest.selection.path
)
Assert-HashedFile `
    -Path $selectionPath `
    -ExpectedSha256 ([string]$manifest.selection.sha256) `
    -Message "The retained BW16S selection is missing or byte-mismatched"
$selection = (
    Get-Content -Raw -LiteralPath $selectionPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_bw16s_balance_composition_selection_v1" -and
    [string]$selection.campaign_id -ceq
        "BW16S-MORPHOLOGY-DEVELOPMENT" -and
    [string]$selection.gate_id -ceq "BW16S" -and
    [string]$selection.source.commit -ceq $expectedSourceCommit -and
    [string]$selection.source.origin_main_commit -ceq
        $expectedSourceCommit -and
    [bool]$selection.source.clean -and
    [bool]$selection.source.matches_origin_main -and
    [string]$selection.control_candidate_id -ceq "BW16S-A" -and
    [string]$selection.treatment_candidate_id -ceq "BW16S-B" -and
    -not [bool]$selection.family_selected -and
    [string]$selection.selected_candidate_id -ceq "" -and
    [string]$selection.result_status -ceq
        "bw16s_family_rejected_treatment_worse_than_control" -and
    [string]$selection.deciding_metric -ceq
        "walking_conjunction_failure_count" -and
    [int]$selection.treatment_lexicographic_comparison_to_control -eq 1 -and
    [bool]$selection.all_candidate_reports_observed -and
    [bool]$selection.all_candidate_integrity_mechanism_and_application_complete -and
    -not [bool]$selection.development_selection_authority -and
    -not [bool]$selection.release_authorized -and
    -not [bool]$selection.physical_acceptance_authority
) "The retained BW16S selection identity or rejection changed"

Assert-VectorBitsEqual `
    -Actual @($selection.control_metric_vector) `
    -Expected @($reconstructedVectors["BW16S-A"]) `
    -Message "The BW16S selection control vector does not reconstruct"
Assert-VectorBitsEqual `
    -Actual @($selection.treatment_metric_vector) `
    -Expected @($reconstructedVectors["BW16S-B"]) `
    -Message "The BW16S selection treatment vector does not reconstruct"
Assert-VectorBitsEqual `
    -Actual @($manifest.selection.control_metric_vector) `
    -Expected @($reconstructedVectors["BW16S-A"]) `
    -Message "The BW16S manifest control vector does not reconstruct"
Assert-VectorBitsEqual `
    -Actual @($manifest.selection.treatment_metric_vector) `
    -Expected @($reconstructedVectors["BW16S-B"]) `
    -Message "The BW16S manifest treatment vector does not reconstruct"
Assert-Exact (
    (Compare-MetricVector `
        -Left ([double[]]$reconstructedVectors["BW16S-B"]) `
        -Right ([double[]]$reconstructedVectors["BW16S-A"])
    ) -eq 1 -and
    [int]$reconstructedMetrics["BW16S-A"].walking_conjunction_failure_count -eq
        7 -and
    [int]$reconstructedMetrics["BW16S-B"].walking_conjunction_failure_count -eq
        8
) "The BW16S treatment is no longer worse on the deciding metric"

Assert-Exact (
    [bool]$manifest.scientific_disposition.candidate_family_complete -and
    [bool]$manifest.scientific_disposition.technical_sdk_execution_valid -and
    [bool]$manifest.scientific_disposition.treatment_mechanism_executed_in_all_36_worlds -and
    [bool]$manifest.scientific_disposition.treatment_physically_influenced_all_36_worlds -and
    -not [bool]$manifest.scientific_disposition.treatment_selected -and
    [bool]$manifest.scientific_disposition.balance_composition_family_rejected -and
    [bool]$manifest.scientific_disposition.treatment_secondary_integrity_metrics_improved -and
    [bool]$manifest.scientific_disposition.secondary_improvements_are_diagnostic_only -and
    [bool]$manifest.scientific_disposition.secondary_improvements_do_not_override_primary_walking_rejection -and
    [bool]$manifest.next_allowed_work.bw16s_is_closed -and
    [bool]$manifest.next_allowed_work.portable_release_policy_unchanged -and
    [bool]$manifest.next_allowed_work.balance_overlay_not_authorized -and
    [bool]$manifest.next_allowed_work.cross_engine_c6_may_continue_as_engine_infrastructure_without_promoting_bw16s -and
    [bool]$manifest.next_allowed_work.unbiased_friction_reservation_remains_unopened
) "The BW16S scientific disposition or next-work boundary changed"

foreach ($researchSource in @($manifest.research_sources)) {
    Assert-Exact (
        (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$researchSource.path)
        ) -PathType Leaf) -and
        (Test-SporeWorkingOrHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedSourceCommit `
            -Path ([string]$researchSource.path) `
            -ExpectedSha256 ([string]$researchSource.sha256))
    ) "A BW16S research source is missing or byte-mismatched"
}
foreach ($claimKey in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claimKey]
    ) "The BW16S closure unlawfully gained claim authority: $claimKey"
}
foreach (
    $selectionClaimKey in @(
        "walking_acceptance",
        "balance_improvement",
        "independent_morphology_validation",
        "arbitrary_quadruped_coverage",
        "continuous_full_volume_coverage",
        "material_robustness",
        "rough_terrain_robustness",
        "external_push_recovery",
        "sensor_noise_or_latency_robustness",
        "different_physics_engines",
        "running",
        "completed_engine_neutral_sdk",
        "release_authorized",
        "physical_acceptance_authority"
    )
) {
    Assert-Exact (
        -not [bool]$selection[$selectionClaimKey]
    ) "The retained BW16S selection unlawfully gained claim authority: $selectionClaimKey"
}

Write-Host (
    "BW16S closure passed: treatment rejected 28/36 versus 29/36 " +
    "walking; 72/72 integrity/mechanism/application; 60 source, " +
    "224 cell/preflight, 4 supervisor, 2 report, and 1 selection " +
    "artifact checks passed."
)
