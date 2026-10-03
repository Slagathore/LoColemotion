#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw19v_closure_manifest.json"
)
$expectedSourceCommit = "c7b9ec8691b54c707898853bee0539cf3ebce27f"
$expectedCandidates = @("BW19V-A", "BW19V-B")
$expectedScales = @(0.0, 0.5)
$expectedApplications = @(0, 36)
$expectedCompositionDigests = @(
    "sha256:2eb8621882b4ae4047821aca415ab1b67de3399d0ab272a91f57fb0fc2ada7a4",
    "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
)
$expectedMorphologyIds = @(
    foreach ($index in 205..216) {
        "bw19v_generated_s$index"
    }
)
$expectedSeeds = @(39101, 39102, 39103)
$falseClaimKeys = @(
    "walking_acceptance",
    "balance_improvement",
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
) "The BW19V closure manifest is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw19v_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_finite_independent_validation_hypothesis_confirmed" -and
    [string]$manifest.gate_id -ceq "BW19V" -and
    [string]$manifest.campaign_id -ceq
        "BW19V-INDEPENDENT-MORPHOLOGY-VALIDATION" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    -not [bool]$manifest.cohort_outcome_exposed_before_preregistration -and
    [bool]$manifest.finite_prospectively_frozen_unopened_validation_cohort -and
    [bool]$manifest.immutability.bw19v_reports_may_not_be_rewritten -and
    [bool]$manifest.immutability.bw19v_selection_may_not_be_recompiled
) "The BW19V closure identity or immutability boundary changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The exact BW19V experiment source commit is not retained by Git"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW19V experiment source is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing BW19V"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW19V experiment source is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen BW19V preregistration is missing or changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.preregistration.candidate_declaration_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.preregistration.candidate_declaration_raw_sha256
    ) `
    -Message "The frozen BW19V candidate declaration is missing or changed"
Assert-Exact (
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "7024efdddde6c1ad889987f43c2018f4a6ac7069" -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw19v_physics_world" -and
    [string]$manifest.preregistration.primary_metric -ceq
        "walking_conjunction_failure_count"
) "The BW19V prospective freeze identity changed"

Assert-HashedFile `
    -Path ([string]$manifest.complete_attempt.launch_manifest_path) `
    -ExpectedSha256 (
        [string]$manifest.complete_attempt.launch_manifest_sha256
    ) `
    -Message "The retained BW19V launch manifest is missing or changed"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 2
) "The BW19V closure must retain exactly two candidate reports"

$totals = [ordered]@{
    worlds = 0
    receipts = 0
    harness = 0
    integrity = 0
    mechanism = 0
    application = 0
    walking = 0
    walking_failures = 0
    source_files = 0
    preflight_artifacts = 0
    cell_artifacts = 0
}

for ($candidateIndex = 0; $candidateIndex -lt 2; $candidateIndex += 1) {
    $declared = $candidateReports[$candidateIndex]
    $candidateId = $expectedCandidates[$candidateIndex]
    $expectedScale = [double]$expectedScales[$candidateIndex]
    $expectedApplication = [int]$expectedApplications[$candidateIndex]
    Assert-Exact (
        [string]$declared.candidate_id -ceq $candidateId -and
        [double]$declared.global_requested_correction_scale -eq
            $expectedScale -and
        [int]$declared.expected_application_pass_count -eq
            $expectedApplication -and
        [string]$declared.candidate_composition_digest -ceq
            $expectedCompositionDigests[$candidateIndex] -and
        [bool]$declared.policy_relative_execution_complete
    ) "$candidateId closure declaration changed"

    foreach ($stream in @("stdout", "stderr")) {
        Assert-HashedFile `
            -Path ([string]$declared["supervisor_${stream}_path"]) `
            -ExpectedSha256 (
                [string]$declared["supervisor_${stream}_sha256"]
            ) `
            -Message (
                "$candidateId retained supervisor $stream is missing or changed"
            )
    }

    Assert-HashedFile `
        -Path ([string]$declared.path) `
        -ExpectedSha256 ([string]$declared.sha256) `
        -Message "$candidateId retained report is missing or changed"
    $report = (
        Get-Content -Raw -LiteralPath ([string]$declared.path) |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw19v_independent_validation_report_v1" -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.source.commit -ceq $expectedSourceCommit -and
        [string]$report.source.origin_main_commit -ceq
            $expectedSourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [double]$report.global_requested_correction_scale -eq
            $expectedScale -and
        [int]$report.expected_application_pass_count -eq
            $expectedApplication -and
        [string]$report.candidate_composition_digest -ceq
            $expectedCompositionDigests[$candidateIndex] -and
        [bool]$report.validation_execution_complete -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.physical_acceptance_authority
    ) "$candidateId retained report identity changed"

    foreach ($sourceFile in @($report.source.source_files)) {
        $path = [string]$sourceFile.path
        $expectedSourceSha256 = [string]$sourceFile.sha256
        $workingSourcePath = Join-Path $repoRoot $path
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
                    -Path $path `
                    -ExpectedSha256 $expectedSourceSha256
            ) -or
            (
                Test-SporeHistoricalSourceAvailable `
                    -RepositoryRoot $repoRoot `
                    -Commit $expectedSourceCommit `
                    -Path $path
            )
        ) "$candidateId source file is not retained: $path"
        $totals.source_files += 1
    }

    foreach (
        $preflightName in @(
            "full_integrity_preflight",
            "experiment_result_integrity_preflight",
            "candidate_authority_preflight",
            "bw19v_entrypoint_preflight"
        )
    ) {
        $preflight = $report[$preflightName]
        Assert-Exact (
            [bool]$preflight.passed -and
            [int]$preflight.actual_world_build_count -eq 0
        ) "$candidateId $preflightName did not remain a zero-world pass"
        Assert-HashedFile `
            -Path ([string]$preflight.artifact_path) `
            -ExpectedSha256 ([string]$preflight.artifact_sha256) `
            -Message "$candidateId $preflightName artifact changed"
        $totals.preflight_artifacts += 1
    }

    Assert-Exact (
        [bool]$report.bw18g_closure_preflight.passed -and
        -not [bool]$report.bw18g_closure_preflight.source_family_valid_selection -and
        [bool]$report.bw18g_closure_preflight.hypothesis_generation_only -and
        [bool]$report.selector_preflight.passed -and
        -not [bool]$report.selector_preflight.physical_acceptance_authority
    ) "$candidateId predecessor or selector preflight changed"

    $results = @($report.results)
    Assert-Exact (
        $results.Count -eq 36
    ) "$candidateId does not retain exactly 36 ordered results"
    $resultIndex = 0
    foreach ($morphologyId in $expectedMorphologyIds) {
        foreach ($seed in $expectedSeeds) {
            $result = $results[$resultIndex]
            $expectedGeneratorIndex = 205 + [array]::IndexOf(
                $expectedMorphologyIds,
                $morphologyId
            )
            Assert-Exact (
                [string]$result.morphology_id -ceq $morphologyId -and
                [int]$result.generator_index -eq $expectedGeneratorIndex -and
                [int]$result.campaign_seed -eq $seed -and
                [int]$result.process_exit_code -eq 0 -and
                -not [bool]$result.timed_out -and
                -not [bool]$result.killed_process_tree -and
                [bool]$result.receipt_parsed -and
                [bool]$result.harness_passed -and
                [bool]$result.common_execution_integrity -and
                [bool]$result.mechanism_gate_passed -and
                [bool]$result.scale_contract_passed -and
                [double]$result.global_requested_correction_scale -eq
                    $expectedScale -and
                [string]$result.receipt.schema_version -ceq
                    "sporespore_bw19v_independent_validation_cell_v1" -and
                [string]$result.receipt.candidate_id -ceq $candidateId -and
                [int]$result.receipt.generator_index -eq
                    $expectedGeneratorIndex -and
                [int]$result.receipt.campaign_seed -eq $seed -and
                [int]$result.receipt.assertions_failed -eq 0 -and
                [bool]$result.receipt.sdk_authority_enabled -and
                [string]$result.receipt.sdk_authority_failure_code -ceq "" -and
                [int]$result.receipt.world_build_count -eq 1
            ) "$candidateId result ordering or cell identity changed at $resultIndex"

            foreach ($artifactName in @("transcript", "stderr", "engine_log")) {
                Assert-HashedFile `
                    -Path ([string]$result["${artifactName}_path"]) `
                    -ExpectedSha256 (
                        [string]$result["${artifactName}_sha256"]
                    ) `
                    -Message (
                        "$candidateId $morphologyId seed $seed " +
                        "$artifactName artifact changed"
                    )
                $totals.cell_artifacts += 1
            }
            $resultIndex += 1
        }
    }

    $metrics = Measure-SporePolicyRelativeExperimentResults `
        -Results $results `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount $expectedApplication
    Assert-Exact (
        [bool]$metrics.policy_relative_execution_complete -and
        [int]$metrics.walking_conjunction_pass_count -eq
            [int]$declared.walking_conjunction_pass_count -and
        [int]$metrics.walking_conjunction_failure_count -eq
            [int]$declared.walking_conjunction_failure_count -and
        [int]$metrics.combined_application_pass_count -eq
            $expectedApplication
    ) "$candidateId retained metrics did not independently reconstruct"

    foreach (
        $fieldName in @(
            "observed_world_count",
            "complete_receipt_count",
            "harness_pass_count",
            "integrity_pass_count",
            "mechanism_pass_count",
            "combined_application_pass_count",
            "walking_conjunction_pass_count",
            "walking_conjunction_failure_count"
        )
    ) {
        Assert-Exact (
            [double]$declared[$fieldName] -eq [double]$metrics[$fieldName]
        ) "$candidateId closure metric changed: $fieldName"
    }

    $totals.worlds += [int]$metrics.observed_world_count
    $totals.receipts += [int]$metrics.complete_receipt_count
    $totals.harness += [int]$metrics.harness_pass_count
    $totals.integrity += [int]$metrics.integrity_pass_count
    $totals.mechanism += [int]$metrics.mechanism_pass_count
    $totals.application += [int]$metrics.combined_application_pass_count
    $totals.walking += [int]$metrics.walking_conjunction_pass_count
    $totals.walking_failures +=
        [int]$metrics.walking_conjunction_failure_count
}

Assert-Exact (
    $totals.worlds -eq 72 -and
    $totals.receipts -eq 72 -and
    $totals.harness -eq 72 -and
    $totals.integrity -eq 72 -and
    $totals.mechanism -eq 72 -and
    $totals.application -eq 36 -and
    $totals.walking -eq 64 -and
    $totals.walking_failures -eq 8 -and
    [int]$manifest.complete_attempt.observed_world_count -eq 72 -and
    [int]$manifest.complete_attempt.walking_conjunction_pass_count -eq 64 -and
    [int]$manifest.complete_attempt.walking_conjunction_failure_count -eq 8
) "The BW19V retained family aggregate changed"

Assert-HashedFile `
    -Path ([string]$manifest.selection.path) `
    -ExpectedSha256 ([string]$manifest.selection.sha256) `
    -Message "The retained one-shot BW19V selection is missing or changed"
$selection = (
    Get-Content -Raw -LiteralPath ([string]$manifest.selection.path) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_bw19v_independent_validation_selection_v1" -and
    [string]$selection.source.commit -ceq $expectedSourceCommit -and
    [bool]$selection.validation_hypothesis_confirmed -and
    [string]$selection.result_status -ceq
        "finite_independent_validation_hypothesis_confirmed" -and
    [int]$selection.control_walking_conjunction_failure_count -eq 5 -and
    [int]$selection.treatment_walking_conjunction_failure_count -eq 3 -and
    [int]$selection.control_minus_treatment_walking_failure_count -eq 2 -and
    [string]$selection.selected_candidate_id -ceq "BW19V-B" -and
    [bool]$selection.bounded_independent_validation_authority -and
    -not [bool]$selection.arbitrary_quadruped_coverage -and
    -not [bool]$selection.continuous_full_volume_coverage -and
    -not [bool]$selection.walking_acceptance -and
    -not [bool]$selection.physical_acceptance_authority -and
    [int]$manifest.selection.invocation_count_on_physical_reports -eq 1
) "The BW19V one-shot selection identity or bounded authority changed"

Assert-Exact (
    [bool]$manifest.claims.finite_independent_validation_hypothesis_confirmed -and
    [bool]$manifest.claims.bounded_independent_validation_authority
) "The two allowed BW19V bounded claims were lost"
foreach ($claimKey in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claimKey]
    ) "BW19V may not authorize the broad claim $claimKey"
}

foreach ($source in @($manifest.research_sources)) {
    Assert-Exact (
        (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$source.path)
        ) -PathType Leaf) -and
        (Test-SporeWorkingOrHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedSourceCommit `
            -Path ([string]$source.path) `
            -ExpectedSha256 ([string]$source.sha256))
    ) "A BW19V research source is missing or changed"
}

Write-Output (
    "BW19V_CLOSURE_PASS reports=2 worlds=$($totals.worlds) " +
    "walking=$($totals.walking) walking_failures=" +
    "$($totals.walking_failures) source_files=$($totals.source_files) " +
    "preflight_artifacts=$($totals.preflight_artifacts) " +
    "cell_artifacts=$($totals.cell_artifacts) selected=BW19V-B " +
    "bounded_independent_validation=True physical_authority=False"
)
