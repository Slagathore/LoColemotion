#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw18g_closure_manifest.json"
)
$expectedSourceCommit = "7024efdddde6c1ad889987f43c2018f4a6ac7069"
$expectedCandidates = @("BW18G-A", "BW18G-B", "BW18G-C", "BW18G-D")
$expectedScales = @(0.0, 0.25, 0.5, 1.0)
$expectedCompositionDigests = @(
    "sha256:1bbb4e46b3d3e2d70bf17eb86717df19942912280a56e534aa3d47dee2e814e1",
    "sha256:45826fbec95b544186a2dd9822bb1d641c3359120e900aeda729ba691b927446",
    "sha256:1707317f2e1c74adcdd5908ea7daf845233afda42d2f08d0b2a9007480bb2e1e",
    "sha256:8f27e50fa5d6033bf1a5ca69588c246d9a395f331ed6ba4cd405fd69b985641e"
)
$expectedMorphologyIds = @(
    foreach ($index in 193..204) {
        "qsdk_r05c_generated_s$index"
    }
)
$expectedSeeds = @(38101, 38102, 38103)
$metricKeys = @(
    "observed_world_count",
    "complete_receipt_count",
    "harness_pass_count",
    "integrity_pass_count",
    "mechanism_pass_count",
    "combined_application_pass_count",
    "walking_conjunction_pass_count",
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

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The BW18G closure manifest is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw18g_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_four_arm_family_invalid_preregistration_control_application_unsatisfiable" -and
    [string]$manifest.gate_id -ceq "BW18G" -and
    [string]$manifest.campaign_id -ceq
        "BW18G-MORPHOLOGY-DEVELOPMENT" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.cohort_outcome_exposed -and
    [bool]$manifest.immutability.bw18g_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.bw18g_report_rewrite_forbidden -and
    [bool]$manifest.immutability.bw18g_selector_repair_forbidden -and
    [bool]$manifest.immutability.bw18g_posthoc_selection_forbidden
) "The BW18G closure identity or immutable rejection boundary changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The exact BW18G experiment source commit is not retained by Git"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW18G experiment source is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing BW18G"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW18G experiment source is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen BW18G preregistration is missing or changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.preregistration.candidate_declaration_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.preregistration.candidate_declaration_raw_sha256
    ) `
    -Message "The frozen BW18G candidate declaration is missing or changed"
Assert-Exact (
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "4f3b9d6ec5aaedb37c07fa26fdb0478f1de74624" -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw18g_physics_world"
) "The BW18G prospective freeze identity changed"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 4
) "The BW18G closure must retain exactly four candidate reports"

$totalWorlds = 0
$totalReceipts = 0
$totalHarness = 0
$totalIntegrity = 0
$totalMechanism = 0
$totalApplication = 0
$totalWalking = 0
$totalWalkingFailures = 0
$totalFalseGates = 0
$totalTimeouts = 0
$verifiedSourceFiles = 0
$verifiedPreflightArtifacts = 0
$verifiedCellArtifacts = 0

for ($candidateIndex = 0; $candidateIndex -lt 4; $candidateIndex += 1) {
    $declared = $candidateReports[$candidateIndex]
    $candidateId = $expectedCandidates[$candidateIndex]
    $expectedScale = [double]$expectedScales[$candidateIndex]
    Assert-Exact (
        [string]$declared.candidate_id -ceq $candidateId -and
        [double]$declared.global_requested_correction_scale -eq
            $expectedScale -and
        [string]$declared.candidate_composition_digest -ceq
            $expectedCompositionDigests[$candidateIndex] -and
        [bool]$declared.policy_relative_execution_complete
    ) "$candidateId closure declaration changed"

    $reportPath = [string]$declared.path
    Assert-HashedFile `
        -Path $reportPath `
        -ExpectedSha256 ([string]$declared.sha256) `
        -Message "$candidateId retained report is missing or changed"
    $report = (
        Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw18g_morphology_development_report_v1" -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.source.commit -ceq $expectedSourceCommit -and
        [string]$report.source.origin_main_commit -ceq
            $expectedSourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [double]$report.global_requested_correction_scale -eq
            $expectedScale -and
        [string]$report.candidate_composition_digest -ceq
            $expectedCompositionDigests[$candidateIndex] -and
        [bool]$report.development_data_only -and
        [bool]$report.cohort_outcome_exposed -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.physical_acceptance_authority
    ) "$candidateId retained report identity changed"

    $results = @($report.results)
    Assert-Exact (
        $results.Count -eq 36
    ) "$candidateId does not retain exactly 36 ordered results"
    $resultIndex = 0
    foreach ($morphologyId in $expectedMorphologyIds) {
        foreach ($seed in $expectedSeeds) {
            $result = $results[$resultIndex]
            Assert-Exact (
                [string]$result.morphology_id -ceq $morphologyId -and
                [int]$result.generator_index -eq
                    (193 + [array]::IndexOf(
                        $expectedMorphologyIds,
                        $morphologyId
                    )) -and
                [int]$result.campaign_seed -eq $seed -and
                [bool]$result.receipt_parsed -and
                [bool]$result.harness_passed -and
                [bool]$result.common_execution_integrity -and
                [bool]$result.mechanism_gate_passed -and
                [bool]$result.scale_contract_passed -and
                [double]$result.global_requested_correction_scale -eq
                    $expectedScale
            ) "$candidateId result $resultIndex identity or gate changed"
            if ($expectedScale -eq 0.0) {
                Assert-Exact (
                    -not [bool]$result.combined_application_gate_passed
                ) "$candidateId zero-scale control unexpectedly applied influence"
            } else {
                Assert-Exact (
                    [bool]$result.combined_application_gate_passed
                ) "$candidateId treatment did not apply its declared influence"
            }
            foreach ($artifactName in @("transcript", "stderr", "engine_log")) {
                Assert-HashedFile `
                    -Path ([string]$result["${artifactName}_path"]) `
                    -ExpectedSha256 (
                        [string]$result["${artifactName}_sha256"]
                    ) `
                    -Message (
                        "$candidateId result $resultIndex $artifactName " +
                        "artifact is missing or changed"
                    )
                $verifiedCellArtifacts += 1
            }
            $resultIndex += 1
        }
    }

    $reconstructed = Measure-SporeExperimentResults `
        -Results $results `
        -ExpectedCount 36
    foreach ($metricKey in $metricKeys) {
        Assert-Exact (
            [double]$report.metrics[$metricKey] -eq
                [double]$reconstructed[$metricKey] -and
            [double]$declared[$metricKey] -eq
                [double]$reconstructed[$metricKey]
        ) "$candidateId metric $metricKey does not reconstruct exactly"
    }
    Assert-Exact (
        [int]$reconstructed.observed_world_count -eq 36 -and
        [int]$reconstructed.complete_receipt_count -eq 36 -and
        [int]$reconstructed.harness_pass_count -eq 36 -and
        [int]$reconstructed.integrity_pass_count -eq 36 -and
        [int]$reconstructed.mechanism_pass_count -eq 36 -and
        (
            (
                $expectedScale -eq 0.0 -and
                [int]$reconstructed.combined_application_pass_count -eq 0 -and
                -not [bool]$report.development_complete
            ) -or
            (
                $expectedScale -gt 0.0 -and
                [int]$reconstructed.combined_application_pass_count -eq 36 -and
                [bool]$report.development_complete
            )
        )
    ) "$candidateId candidate-relative execution completion changed"

    foreach ($sourceFile in @($report.source.source_files)) {
        $sourcePath = [string]$sourceFile.path
        $expectedSourceSha256 = [string]$sourceFile.sha256
        $workingSourcePath = Join-Path $repoRoot $sourcePath
        Assert-Exact (
            (
                (Test-Path -LiteralPath $workingSourcePath -PathType Leaf) -and
                (Get-Sha256 -Path $workingSourcePath) -ceq
                    $expectedSourceSha256.Replace("sha256:", "")
            ) -or
            (
                Test-SporeHistoricalSourceSha256 `
                    -RepositoryRoot $repoRoot `
                    -Commit $expectedSourceCommit `
                    -Path $sourcePath `
                    -ExpectedSha256 $expectedSourceSha256
            ) -or
            (
                Test-SporeHistoricalSourceAvailable `
                    -RepositoryRoot $repoRoot `
                    -Commit $expectedSourceCommit `
                    -Path $sourcePath
            )
        ) "$candidateId source file is not retained: $sourcePath"
        $verifiedSourceFiles += 1
    }

    foreach (
        $preflightName in @(
            "full_integrity_preflight",
            "experiment_result_integrity_preflight",
            "candidate_authority_preflight",
            "bw18g_entrypoint_preflight"
        )
    ) {
        $preflight = $report[$preflightName]
        Assert-Exact (
            [bool]$preflight.passed -and
            [int]$preflight.actual_world_build_count -eq 0
        ) "$candidateId $preflightName receipt changed"
        Assert-HashedFile `
            -Path ([string]$preflight.artifact_path) `
            -ExpectedSha256 ([string]$preflight.artifact_sha256) `
            -Message "$candidateId $preflightName artifact is missing or changed"
        $verifiedPreflightArtifacts += 1
    }

    $totalWorlds += [int]$reconstructed.observed_world_count
    $totalReceipts += [int]$reconstructed.complete_receipt_count
    $totalHarness += [int]$reconstructed.harness_pass_count
    $totalIntegrity += [int]$reconstructed.integrity_pass_count
    $totalMechanism += [int]$reconstructed.mechanism_pass_count
    $totalApplication += [int]$reconstructed.combined_application_pass_count
    $totalWalking += [int]$reconstructed.walking_conjunction_pass_count
    $totalWalkingFailures += (
        [int]$reconstructed.walking_conjunction_failure_count
    )
    $totalFalseGates += (
        [int]$reconstructed.aggregate_failed_production_walking_gate_count
    )
    $totalTimeouts += (
        [int]$reconstructed.aggregate_release_timeout_count
    )
}

Assert-Exact (
    $totalWorlds -eq 144 -and
    $totalReceipts -eq 144 -and
    $totalHarness -eq 144 -and
    $totalIntegrity -eq 144 -and
    $totalMechanism -eq 144 -and
    $totalApplication -eq 108 -and
    $totalWalking -eq 117 -and
    $totalWalkingFailures -eq 27 -and
    $totalFalseGates -eq 65 -and
    $totalTimeouts -eq 31 -and
    $verifiedSourceFiles -eq 156 -and
    $verifiedPreflightArtifacts -eq 16 -and
    $verifiedCellArtifacts -eq 432
) "The BW18G retained family totals changed"

$selection = $manifest.selection_attempt
Assert-Exact (
    [string]$selection.compiler_path -ceq
        "sdk/compile_balanced_wave_bw18g_selection.ps1" -and
    -not [bool]$selection.selection_artifact_created -and
    [int]$selection.process_exit_code -eq 1 -and
    -not (Test-Path -LiteralPath ([string]$selection.output_path)) -and
    -not [bool]$selection.family_selected -and
    [string]$selection.selected_candidate_id -ceq "" -and
    [bool]$selection.failure_is_frozen_contract_behavior
) "The BW18G failed-closed selection disposition changed"
Assert-HashedFile `
    -Path ([string]$selection.stdout_path) `
    -ExpectedSha256 ([string]$selection.stdout_sha256) `
    -Message "The BW18G selection stdout transcript changed"
Assert-HashedFile `
    -Path ([string]$selection.stderr_path) `
    -ExpectedSha256 ([string]$selection.stderr_sha256) `
    -Message "The BW18G selection stderr transcript changed"
$selectionStderr = Get-Content -Raw -LiteralPath (
    [string]$selection.stderr_path
)
Assert-Exact (
    $selectionStderr.Contains(
        [string]$selection.expected_failure_text,
        [StringComparison]::Ordinal
    )
) "The BW18G selector did not retain the expected fail-closed reason"

Assert-Exact (
    [bool]$manifest.preflight_defect.generic_all_zero_aggregate_gate_passed -and
    -not [bool]$manifest.preflight_defect.candidate_specific_zero_scale_application_gate_was_exercised -and
    [bool]$manifest.preflight_defect.selector_was_unsatisfiable_for_the_declared_control_policy -and
    [bool]$manifest.preflight_defect.should_have_failed_before_first_world -and
    -not [bool]$manifest.scientific_disposition.frozen_selection_contract_valid -and
    -not [bool]$manifest.scientific_disposition.family_selected -and
    [string]$manifest.scientific_disposition.apparent_best_development_candidate_id -ceq
        "BW18G-C" -and
    [bool]$manifest.scientific_disposition.apparent_improvement_is_hypothesis_generation_only -and
    [bool]$manifest.scientific_disposition.apparent_improvement_may_not_be_promoted_from_bw18g -and
    [bool]$manifest.next_allowed_work.policy_relative_synthetic_satisfiability_required
) "The BW18G defect or scientific non-claim boundary changed"

foreach ($claimKey in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claimKey]
    ) "BW18G closure overclaims $claimKey"
}

Write-Output (
    "BW18G_CLOSURE_TEST_PASS reports=4 worlds=$totalWorlds " +
    "integrity=$totalIntegrity mechanism=$totalMechanism " +
    "application=$totalApplication walking=$totalWalking " +
    "failures=$totalWalkingFailures source_files=$verifiedSourceFiles " +
    "cell_artifacts=$verifiedCellArtifacts " +
    "preflight_artifacts=$verifiedPreflightArtifacts " +
    "selector_status=failed_closed_unsatisfiable_control"
)
