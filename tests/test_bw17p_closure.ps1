#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw17p_closure_manifest.json"
)
$expectedSourceCommit = "271cdff4f8fc8896793914ebb911192bd6a5ca96"
$expectedCandidates = @("BW17P-A", "BW17P-B")
$expectedStabilityPolicies = @(
    "p5i3b_weight_support_shadow_v1",
    "sporespore_scheduled_load_transfer_bw13p_a_v3"
)
$expectedAuthorityScopes = @(
    "post_settle_full",
    "post_settle_full"
)
$expectedExecutionModes = @(
    "native_authority_with_legacy_observer",
    "native_balanced_wave_base_with_stability_contribution"
)
$expectedCompositionDigests = @(
    "sha256:7093744b5fe5fcac36b59ba94741fc83b59e42c445d6b01b90711c5f71ba422e",
    "sha256:b25729d73a07007c5cb49d0fe522c3e9e574413ebb19167339091106ca5da212"
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

function Get-GitBlobSha256 {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("-C")
    [void]$start.ArgumentList.Add($repoRoot)
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add("${Commit}:$Path")
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact ($process.Start()) "Failed to start Git source-blob audit"
    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact (
            $process.ExitCode -eq 0
        ) "Git source-blob audit failed for $Path`: $stderr"
        return (
            [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData(
                    $memory.ToArray()
                )
            ).ToLowerInvariant()
        )
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Find-ByteSequence {
    param(
        [Parameter(Mandatory)][byte[]]$Bytes,
        [Parameter(Mandatory)][byte[]]$Sequence
    )
    Assert-Exact (
        $Sequence.Length -gt 0 -and
        $Bytes.Length -ge $Sequence.Length
    ) "A BW17P closure-source reconstruction marker is invalid"
    for (
        $offset = 0;
        $offset -le $Bytes.Length - $Sequence.Length;
        $offset += 1
    ) {
        $matches = $true
        for (
            $sequenceIndex = 0;
            $sequenceIndex -lt $Sequence.Length;
            $sequenceIndex += 1
        ) {
            if (
                $Bytes[$offset + $sequenceIndex] -ne
                    $Sequence[$sequenceIndex]
            ) {
                $matches = $false
                break
            }
        }
        if ($matches) {
            return $offset
        }
    }
    return -1
}

function Get-PreClosureDocumentationSha256 {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$WorkingPath
    )
    $bytes = [System.IO.File]::ReadAllBytes($WorkingPath)
    $utf8 = [System.Text.Encoding]::UTF8
    $historicalBytes = $null
    if (
        $SourcePath -ceq
            "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md"
    ) {
        $marker = $utf8.GetBytes(
            "## BW17P complete negative portable-plan closure"
        )
        $markerOffset = Find-ByteSequence `
            -Bytes $bytes `
            -Sequence $marker
        Assert-Exact (
            $markerOffset -ge 2 -and
            $bytes[$markerOffset - 2] -eq 10 -and
            $bytes[$markerOffset - 1] -eq 10
        ) "The engine-neutral BW17P append boundary changed"
        $historicalLength = $markerOffset - 1
        $historicalBytes = [byte[]]::new($historicalLength)
        [System.Buffer]::BlockCopy(
            $bytes,
            0,
            $historicalBytes,
            0,
            $historicalLength
        )
    } elseif (
        $SourcePath -ceq
            "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    ) {
        $startMarker = $utf8.GetBytes(
            "## BW17P complete negative development closure"
        )
        $endMarker = $utf8.GetBytes(
            "## BW16S prospective portable-balance composition"
        )
        $startOffset = Find-ByteSequence `
            -Bytes $bytes `
            -Sequence $startMarker
        $endOffset = Find-ByteSequence `
            -Bytes $bytes `
            -Sequence $endMarker
        Assert-Exact (
            $startOffset -ge 2 -and
            $endOffset -gt $startOffset -and
            $bytes[$startOffset - 2] -eq 10 -and
            $bytes[$startOffset - 1] -eq 10 -and
            $bytes[$endOffset - 2] -eq 10 -and
            $bytes[$endOffset - 1] -eq 10
        ) "The successor-bootstrap BW17P insertion boundary changed"
        $historicalLength = $startOffset + (
            $bytes.Length - $endOffset
        )
        $historicalBytes = [byte[]]::new($historicalLength)
        [System.Buffer]::BlockCopy(
            $bytes,
            0,
            $historicalBytes,
            0,
            $startOffset
        )
        [System.Buffer]::BlockCopy(
            $bytes,
            $endOffset,
            $historicalBytes,
            $startOffset,
            $bytes.Length - $endOffset
        )
    } else {
        return ""
    }
    return (
        [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                $historicalBytes
            )
        ).ToLowerInvariant()
    )
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
) "The BW17P closure manifest is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw17p_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_paired_family_rejected_treatment_worse_than_control" -and
    [string]$manifest.gate_id -ceq "BW17P" -and
    [string]$manifest.campaign_id -ceq
        "BW17P-MORPHOLOGY-DEVELOPMENT" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.cohort_outcome_exposed -and
    [bool]$manifest.immutability.bw17p_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.bw17p_report_rewrite_forbidden -and
    [bool]$manifest.immutability.bw17p_selection_rewrite_forbidden -and
    [bool]$manifest.immutability.portable_plan_composition_may_not_advance_from_this_rejected_family
) "The BW17P closure identity or immutable rejection boundary changed"

$commitObject = "${expectedSourceCommit}^{commit}"
& git -C $repoRoot cat-file -e $commitObject
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The exact BW17P experiment source commit is not retained by Git"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW17P source commit is not an ancestor of the active closure"
$originMain = (
    & git -C $repoRoot rev-parse origin/main
).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing BW17P"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The BW17P source commit is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen BW17P preregistration is missing or changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.preregistration.candidate_declaration_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.preregistration.candidate_declaration_raw_sha256
    ) `
    -Message "The frozen BW17P candidate declaration is missing or changed"
Assert-Exact (
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "56dffd1fbb1533c5cc138109ccf95aa4dae66499" -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw17p_physics_world"
) "The BW17P prospective freeze identity changed"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 2
) "The BW17P closure must retain exactly two candidate reports"

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
    ) "The BW17P candidate order, controller, or composition changed"

    $reportPath = [System.IO.Path]::GetFullPath([string]$entry.path)
    Assert-HashedFile `
        -Path $reportPath `
        -ExpectedSha256 ([string]$entry.sha256) `
        -Message "A retained BW17P report is missing or byte-mismatched"
    $verifiedReportFileCount += 1
    $report = (
        Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json -AsHashtable
    )
    $results = @($report.results)

    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw17p_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW17P-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.gate_id -ceq "BW17P" -and
        [string]$report.campaign_role -ceq
            "paired_outcome_exposed_portable_core_plan_composition_development" -and
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
    ) "A retained BW17P report changed identity or authority"

    $sourceFiles = @($report.source.source_files)
    $sourcePaths = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    Assert-Exact (
        $sourceFiles.Count -eq 38
    ) "A BW17P report must retain exactly 38 source files"
    foreach ($sourceFile in $sourceFiles) {
        $sourcePath = [string]$sourceFile.path
        Assert-Exact (
            $sourcePaths.Add($sourcePath)
        ) "A BW17P source inventory contains a duplicate: $sourcePath"
        $expectedSourceSha256 = (
            [string]$sourceFile.sha256
        ).Replace("sha256:", "")
        $workingSourcePath = Join-Path $repoRoot $sourcePath
        $workingBytesMatch = (
            (Test-Path -LiteralPath $workingSourcePath -PathType Leaf) -and
            (Get-Sha256 -Path $workingSourcePath) -ceq
                $expectedSourceSha256
        )
        $committedBytesMatch = $false
        if (-not $workingBytesMatch) {
            $committedBytesMatch = Test-SporeHistoricalSourceSha256 `
                -RepositoryRoot $repoRoot `
                -Commit $expectedSourceCommit `
                -Path $sourcePath `
                -ExpectedSha256 $expectedSourceSha256
            if (-not $committedBytesMatch) {
                $committedBytesMatch = Test-SporeHistoricalSourceAvailable `
                    -RepositoryRoot $repoRoot `
                    -Commit $expectedSourceCommit `
                    -Path $sourcePath
            }
        }
        $preClosureDocumentationMatches = $false
        if (
            -not $workingBytesMatch -and
            -not $committedBytesMatch -and
            (Test-Path -LiteralPath $workingSourcePath -PathType Leaf)
        ) {
            $preClosureDocumentationMatches = (
                (Get-PreClosureDocumentationSha256 `
                    -SourcePath $sourcePath `
                    -WorkingPath $workingSourcePath) -ceq
                    $expectedSourceSha256
            )
        }
        Assert-Exact (
            $workingBytesMatch -or
            $committedBytesMatch -or
            $preClosureDocumentationMatches
        ) "A retained BW17P source snapshot changed: $sourcePath"
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
        ) "A BW17P report lost research provenance: $researchPath"
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
    ) "A retained BW17P metric object does not exactly reconstruct"
    $metricVector = @(
        foreach ($metricKey in $metricKeys) {
            [double]$metrics[$metricKey]
        }
    )
    Assert-VectorBitsEqual `
        -Actual $metricVector `
        -Expected @($entry.metric_vector) `
        -Message "A retained BW17P metric vector changed"
    $reconstructedMetrics[$candidateId] = $metrics
    $reconstructedVectors[$candidateId] = $metricVector

    foreach (
        $preflightKey in @(
            "full_integrity_preflight",
            "experiment_result_integrity_preflight",
            "candidate_authority_preflight",
            "bw17p_entrypoint_preflight"
        )
    ) {
        $preflight = $report[$preflightKey]
        Assert-Exact (
            [bool]$preflight.passed -and
            [int]$preflight.actual_world_build_count -eq 0
        ) "A mandatory BW17P zero-world preflight changed: $preflightKey"
        Assert-HashedFile `
            -Path ([string]$preflight.artifact_path) `
            -ExpectedSha256 ([string]$preflight.artifact_sha256) `
            -Message "A retained BW17P preflight artifact changed"
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
        [int]$report.bw17p_entrypoint_preflight.cell_count -eq 36 -and
        [int]$report.bw17p_entrypoint_preflight.exact_candidate_adapter_start_count -eq 36 -and
        [int]$report.bw17p_entrypoint_preflight.exact_declared_policy_runtime_boundary_count -eq 36
    ) "A BW17P mandatory preflight receipt changed"

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
        scheduled_load_transfer_receipt_count = 0L
        scheduled_load_transfer_active_step_count = 0L
        scheduled_load_transfer_preferred_normal_step_count = 0L
        scheduled_load_transfer_remaining_centroid_step_count = 0L
        scheduled_load_transfer_available_receipt_count = 0L
        scheduled_load_transfer_observation_unavailable_receipt_count = 0L
        scheduled_load_transfer_upstream_infeasible_receipt_count = 0L
        stability_contribution_attempt_count = 0L
        stability_contribution_influence_output_count = 0L
        stability_contribution_nonzero_attempt_count = 0L
        overlay_application_step_count = 0L
        overlay_motor_write_count = 0L
        overlay_portable_base_application_count = 0L
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
        ) "A BW17P report contains a duplicate or undeclared cell: $pair"
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
                "sporespore_bw17p_morphology_development_cell_v1" -and
            [string]$receipt.campaign_id -ceq
                "BW17P-MORPHOLOGY-DEVELOPMENT" -and
            [string]$receipt.gate_id -ceq "BW17P" -and
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
        ) "A retained BW17P technical receipt changed: $pair"

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
        ) "A BW17P controller or command/write invariant failed: $pair"

        $loadTransfer = $receipt.scheduled_load_transfer_summary
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
        ) "A BW17P stability mechanism receipt failed: $pair"

        if ($candidateId -ceq "BW17P-A") {
            Assert-Exact (
                -not [bool]$receipt.stability_feedback_policy_manifest.enabled -and
                -not [bool]$receipt.stability_physical_overlay_manifest.enabled -and
                -not [bool]$loadTransfer.enabled -and
                [int]$loadTransfer.receipt_count -eq 0 -and
                -not [bool]$overlay.physical_influence -and
                [int]$contribution.feedback_nonzero_attempt_count -eq 0 -and
                [int]$overlay.application_step_count -eq 0 -and
                [int]$overlay.motor_write_count -eq 0 -and
                [int]$overlay.nonzero_effective_application_count -eq 0 -and
                [long]$receipt.legacy_overlay_base_motor_write_count -eq 0L -and
                [long]$receipt.legacy_post_settle_motor_write_count -eq 0L -and
                [long]$receipt.legacy_evidence_motor_write_count -eq 0L
            ) "A BW17P-A exclusive-control invariant failed: $pair"
        } else {
            Assert-Exact (
                [bool]$receipt.stability_feedback_policy_manifest.enabled -and
                [bool]$receipt.stability_physical_overlay_manifest.enabled -and
                [bool]$loadTransfer.enabled -and
                [string]$loadTransfer.policy_id -ceq
                    "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
                [string]$loadTransfer.portable_plan_operation -ceq
                    "plan_scheduled_load_transfer_v3_json" -and
                [string]$loadTransfer.receipt_schema_version -ceq
                    "sporespore_scheduled_load_transfer_receipt_v3" -and
                [long]$loadTransfer.receipt_count -eq
                    [long]$receipt.sdk_step_count -and
                [long]$loadTransfer.active_step_count -eq 0L -and
                [long]$loadTransfer.preferred_normal_step_count -eq 0L -and
                [long]$loadTransfer.remaining_centroid_step_count -eq 0L -and
                (
                    [long]$loadTransfer.available_receipt_count +
                    [long]$loadTransfer.observation_unavailable_receipt_count +
                    [long]$loadTransfer.upstream_infeasible_receipt_count
                ) -eq [long]$receipt.sdk_step_count -and
                [long]$loadTransfer.fail_zero_receipt_count -eq (
                    [long]$loadTransfer.observation_unavailable_receipt_count +
                    [long]$loadTransfer.upstream_infeasible_receipt_count
                ) -and
                [bool]$loadTransfer.activation_uses_scheduler_boundaries_only -and
                [int]$loadTransfer.morphology_branch_surface_count -eq 0 -and
                [bool]$overlay.physical_influence -and
                [string]$overlay.authority_scope -ceq
                    "post_settle_full" -and
                [string]$overlay.policy_id -ceq
                    "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
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
                [long]$receipt.legacy_overlay_base_motor_write_count -eq 0L -and
                [long]$receipt.legacy_post_settle_motor_write_count -eq 0L -and
                [long]$receipt.legacy_evidence_motor_write_count -eq 0L
            ) "A BW17P-B portable-plan physical-contribution invariant failed: $pair"
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
        ) "A BW17P raw walking or timeout receipt changed: $pair"
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
                -Message "A retained BW17P cell artifact changed: $pair"
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
        $actualTotals.scheduled_load_transfer_receipt_count += (
            [long]$loadTransfer.receipt_count
        )
        $actualTotals.scheduled_load_transfer_active_step_count += (
            [long]$loadTransfer.active_step_count
        )
        $actualTotals.scheduled_load_transfer_preferred_normal_step_count += (
            [long]$loadTransfer.preferred_normal_step_count
        )
        $actualTotals.scheduled_load_transfer_remaining_centroid_step_count += (
            [long]$loadTransfer.remaining_centroid_step_count
        )
        $actualTotals.scheduled_load_transfer_available_receipt_count += (
            [long]$loadTransfer.available_receipt_count
        )
        $actualTotals.scheduled_load_transfer_observation_unavailable_receipt_count += (
            [long]$loadTransfer.observation_unavailable_receipt_count
        )
        $actualTotals.scheduled_load_transfer_upstream_infeasible_receipt_count += (
            [long]$loadTransfer.upstream_infeasible_receipt_count
        )
        $actualTotals.stability_contribution_attempt_count += (
            [long]$contribution.attempt_count
        )
        $actualTotals.stability_contribution_influence_output_count += (
            [long]$contribution.influence_output_count
        )
        $actualTotals.stability_contribution_nonzero_attempt_count += (
            [long]$contribution.feedback_nonzero_attempt_count
        )
        $actualTotals.overlay_application_step_count += (
            [long]$overlay.application_step_count
        )
        $actualTotals.overlay_motor_write_count += (
            [long]$overlay.motor_write_count
        )
        $actualTotals.overlay_portable_base_application_count += (
            [long]$overlay.portable_controller_base_application_count
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
            ($candidateId -ceq "BW17P-A" -and
                $physicalInfluenceCount -eq 0) -or
            ($candidateId -ceq "BW17P-B" -and
                $physicalInfluenceCount -eq 36)
        )
    ) "A BW17P candidate aggregate or physical-influence count changed"

    foreach (
        $totalEntry in (
            $entry.authority_and_mechanism_totals.GetEnumerator()
        )
    ) {
        Assert-Exact (
            [long]$actualTotals[[string]$totalEntry.Key] -eq
                [long]$totalEntry.Value
        ) "A BW17P authority/mechanism total changed: $candidateId/$($totalEntry.Key)"
    }

    Assert-Exact (
        [int]$entry.retained_report_artifact_count -eq 112
    ) "A BW17P per-report artifact count changed"
    foreach ($supervisorArtifact in @($entry.supervisor_artifacts)) {
        Assert-HashedFile `
            -Path ([string]$supervisorArtifact.path) `
            -ExpectedSha256 ([string]$supervisorArtifact.sha256) `
            -Message "A retained BW17P supervisor artifact changed"
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
    $totalWalking -eq 56 -and
    $totalWalkingFailures -eq 16 -and
    $totalRawFalseGates -eq 47L -and
    $totalReleaseTimeouts -eq 25L -and
    $verifiedReportFileCount -eq 2 -and
    $verifiedSourceHashCount -eq 76 -and
    $verifiedCellAndPreflightArtifactCount -eq 224 -and
    $verifiedSupervisorArtifactCount -eq 0
) "The complete BW17P family counts or retained evidence changed"
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
    ) "The BW17P manifest family count changed: $countKey"
}

$selectionPath = [System.IO.Path]::GetFullPath(
    [string]$manifest.selection.path
)
Assert-HashedFile `
    -Path $selectionPath `
    -ExpectedSha256 ([string]$manifest.selection.sha256) `
    -Message "The retained BW17P selection is missing or byte-mismatched"
$selection = (
    Get-Content -Raw -LiteralPath $selectionPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_bw17p_portable_plan_selection_v1" -and
    [string]$selection.campaign_id -ceq
        "BW17P-MORPHOLOGY-DEVELOPMENT" -and
    [string]$selection.gate_id -ceq "BW17P" -and
    [string]$selection.source.commit -ceq $expectedSourceCommit -and
    [string]$selection.source.origin_main_commit -ceq
        $expectedSourceCommit -and
    [bool]$selection.source.clean -and
    [bool]$selection.source.matches_origin_main -and
    [string]$selection.control_candidate_id -ceq "BW17P-A" -and
    [string]$selection.treatment_candidate_id -ceq "BW17P-B" -and
    -not [bool]$selection.family_selected -and
    [string]$selection.selected_candidate_id -ceq "" -and
    [string]$selection.result_status -ceq
        "bw17p_family_rejected_treatment_worse_than_control" -and
    [string]$selection.deciding_metric -ceq
        "walking_conjunction_failure_count" -and
    [int]$selection.treatment_lexicographic_comparison_to_control -eq 1 -and
    [bool]$selection.all_candidate_reports_observed -and
    [bool]$selection.all_candidate_integrity_mechanism_and_application_complete -and
    -not [bool]$selection.development_selection_authority -and
    -not [bool]$selection.release_authorized -and
    -not [bool]$selection.physical_acceptance_authority
) "The retained BW17P selection identity or rejection changed"

Assert-VectorBitsEqual `
    -Actual @($selection.control_metric_vector) `
    -Expected @($reconstructedVectors["BW17P-A"]) `
    -Message "The BW17P selection control vector does not reconstruct"
Assert-VectorBitsEqual `
    -Actual @($selection.treatment_metric_vector) `
    -Expected @($reconstructedVectors["BW17P-B"]) `
    -Message "The BW17P selection treatment vector does not reconstruct"
Assert-VectorBitsEqual `
    -Actual @($manifest.selection.control_metric_vector) `
    -Expected @($reconstructedVectors["BW17P-A"]) `
    -Message "The BW17P manifest control vector does not reconstruct"
Assert-VectorBitsEqual `
    -Actual @($manifest.selection.treatment_metric_vector) `
    -Expected @($reconstructedVectors["BW17P-B"]) `
    -Message "The BW17P manifest treatment vector does not reconstruct"
Assert-Exact (
    (Compare-MetricVector `
        -Left ([double[]]$reconstructedVectors["BW17P-B"]) `
        -Right ([double[]]$reconstructedVectors["BW17P-A"])
    ) -eq 1 -and
    [int]$reconstructedMetrics["BW17P-A"].walking_conjunction_failure_count -eq
        7 -and
    [int]$reconstructedMetrics["BW17P-B"].walking_conjunction_failure_count -eq
        9
) "The BW17P treatment is no longer worse on the deciding metric"

Assert-Exact (
    [bool]$manifest.scientific_disposition.candidate_family_complete -and
    [bool]$manifest.scientific_disposition.technical_sdk_execution_valid -and
    [bool]$manifest.scientific_disposition.treatment_portable_plan_executed_in_all_36_worlds -and
    [bool]$manifest.scientific_disposition.treatment_physically_influenced_all_36_worlds -and
    -not [bool]$manifest.scientific_disposition.treatment_selected -and
    [bool]$manifest.scientific_disposition.portable_plan_composition_family_rejected -and
    [bool]$manifest.scientific_disposition.treatment_secondary_metrics_mixed -and
    [bool]$manifest.scientific_disposition.secondary_diagnostics_do_not_override_primary_walking_rejection -and
    [bool]$manifest.next_allowed_work.bw17p_is_closed -and
    [bool]$manifest.next_allowed_work.portable_release_policy_unchanged -and
    [bool]$manifest.next_allowed_work.portable_plan_composition_not_authorized -and
    [bool]$manifest.next_allowed_work.cross_engine_c6_may_continue_as_engine_infrastructure_without_promoting_bw17p -and
    [bool]$manifest.next_allowed_work.unbiased_friction_reservation_remains_unopened
) "The BW17P scientific disposition or next-work boundary changed"

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
    ) "A BW17P research source is missing or byte-mismatched"
}
foreach ($claimKey in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claimKey]
    ) "The BW17P closure unlawfully gained claim authority: $claimKey"
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
    ) "The retained BW17P selection unlawfully gained claim authority: $selectionClaimKey"
}

Write-Host (
    "BW17P closure passed: treatment rejected 27/36 versus 29/36 " +
    "walking; 72/72 integrity/mechanism/application; 76 source, " +
    "224 cell/preflight, 0 supervisor, 2 report, and 1 selection " +
    "artifact checks passed."
)
