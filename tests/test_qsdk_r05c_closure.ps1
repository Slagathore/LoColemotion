#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\qsdk_r05c_independent_morphology_validation_manifest.json"
)
$expectedSourceCommit = "c41522cbffa2a2f8c6f504a07e532aeef57f1dbd"
$expectedPolicyId = "sporespore_balanced_wave_bw15f_b_v1"
$expectedPolicyDigest = (
    "sha256:" +
    "7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
)
$expectedMorphologyIds = @(
    foreach ($generatorIndex in 193..204) {
        "qsdk_r05c_generated_s$generatorIndex"
    }
)
$expectedSeeds = @(38101, 38102, 38103)
$expectedFalseReceiptFrequency = [ordered]@{
    bounded_lateral_drift = 5
    bounded_tilt = 2
    bounded_torso_height = 2
    bounded_yaw_drift = 2
    contact_gated_evidence_horizon_completed = 1
    contact_gating_completed_without_timeout = 4
    every_limb_completed_evidence_gait_horizon = 1
    every_limb_forward_relocation = 1
    every_limb_two_contact_cycles = 1
    minimum_evidence_forward_translation = 1
    minimum_final_forward_translation = 1
    terminal_four_contact_recovery = 2
    zero_torso_contact = 2
}
$expectedFalseGateSignatures = @(
    (
        "qsdk_r05c_generated_s196|38101|" +
        "bounded_lateral_drift,bounded_tilt,bounded_torso_height," +
        "bounded_yaw_drift,contact_gating_completed_without_timeout," +
        "terminal_four_contact_recovery,zero_torso_contact"
    ),
    (
        "qsdk_r05c_generated_s196|38103|" +
        "bounded_lateral_drift,bounded_tilt,bounded_torso_height," +
        "bounded_yaw_drift,contact_gated_evidence_horizon_completed," +
        "contact_gating_completed_without_timeout," +
        "every_limb_completed_evidence_gait_horizon," +
        "every_limb_forward_relocation,every_limb_two_contact_cycles," +
        "minimum_evidence_forward_translation," +
        "minimum_final_forward_translation,terminal_four_contact_recovery," +
        "zero_torso_contact"
    ),
    "qsdk_r05c_generated_s198|38101|bounded_lateral_drift",
    "qsdk_r05c_generated_s198|38103|bounded_lateral_drift",
    "qsdk_r05c_generated_s201|38103|bounded_lateral_drift",
    (
        "qsdk_r05c_generated_s204|38102|" +
        "contact_gating_completed_without_timeout"
    ),
    (
        "qsdk_r05c_generated_s204|38103|" +
        "contact_gating_completed_without_timeout"
    )
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

function Assert-DoubleBitsEqual {
    param(
        [double]$Actual,
        [double]$Expected,
        [string]$Message
    )
    Assert-Exact (
        [BitConverter]::DoubleToInt64Bits($Actual) -eq
        [BitConverter]::DoubleToInt64Bits($Expected)
    ) $Message
}

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The QSDK-R05C closure manifest is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r05c_independent_morphology_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R05C" -and
    [string]$manifest.campaign_id -ceq "QSDK-R05C" -and
    [string]$manifest.status -ceq "rejected_complete_result" -and
    -not [bool]$manifest.accepted -and
    [string]$manifest.source.commit -ceq $expectedSourceCommit -and
    [bool]$manifest.source.clean -and
    [bool]$manifest.source.matches_origin_main -and
    [bool]$manifest.immutability.first_complete_result_is_final -and
    [bool]$manifest.immutability.r05c_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.r05c_report_rewrite_forbidden -and
    [bool]$manifest.immutability.threshold_relaxation_forbidden -and
    [bool]$manifest.immutability.failed_cell_deletion_replacement_or_averaging_forbidden -and
    [bool]$manifest.immutability.outcome_driven_policy_change_under_r05c_forbidden -and
    [bool]$manifest.immutability.new_successor_source_and_preregistration_identity_required_for_any_policy_change
) "The QSDK-R05C closure identity or immutable rejection boundary changed"

$commitObject = "${expectedSourceCommit}^{commit}"
& git -C $repoRoot cat-file -e $commitObject
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The exact QSDK-R05C experiment source commit is not retained by Git"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The QSDK-R05C source commit is not an ancestor of the active closure"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit origin/main
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The QSDK-R05C source commit is not retained on origin/main"

$preregistrationPath = Join-Path $repoRoot (
    [string]$manifest.preregistration.path
)
Assert-HashedFile `
    -Path $preregistrationPath `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen QSDK-R05C preregistration is missing or byte-mismatched"
Assert-Exact (
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_qsdk_r05c_physics_world" -and
    [string]$manifest.preregistration.freeze_parent_commit -ceq
        "1f7acce979b4b2e3a139ee45fbe7596b9afab947"
) "The QSDK-R05C prospective freeze identity changed"

$selectedPolicyPath = Join-Path $repoRoot (
    [string]$manifest.selected_policy.selected_policy_capsule_path
)
Assert-HashedFile `
    -Path $selectedPolicyPath `
    -ExpectedSha256 (
        [string]$manifest.selected_policy.selected_policy_capsule_raw_sha256
    ) `
    -Message "The selected BW15F-B policy capsule is missing or byte-mismatched"
Assert-Exact (
    [string]$manifest.selected_policy.candidate_id -ceq "BW15F-B" -and
    [string]$manifest.selected_policy.controller_policy_id -ceq
        $expectedPolicyId -and
    [string]$manifest.selected_policy.candidate_policy_digest -ceq
        $expectedPolicyDigest -and
    [bool]$manifest.selected_policy.unchanged_from_preregistration
) "The selected QSDK-R05C policy identity changed"

$reportPath = [System.IO.Path]::GetFullPath(
    [string]$manifest.report.path
)
Assert-HashedFile `
    -Path $reportPath `
    -ExpectedSha256 ([string]$manifest.report.sha256) `
    -Message "The retained QSDK-R05C report is missing or byte-mismatched"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable
)
$results = @($report.results)

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r05c_independent_morphology_report_v1" -and
    [string]$manifest.report.schema_version -ceq
        [string]$report.schema_version -and
    [string]$report.generated_utc -ceq
        [string]$manifest.report.generated_utc -and
    [string]$report.campaign_id -ceq "QSDK-R05C" -and
    [string]$report.gate_id -ceq "QSDK-R05C" -and
    [string]$report.campaign_role -ceq "independent_validation" -and
    [string]$report.selected_candidate_id -ceq "BW15F-B" -and
    [string]$report.selected_policy_id -ceq $expectedPolicyId -and
    [string]$report.selected_policy_digest -ceq $expectedPolicyDigest -and
    [string]$report.source.commit -ceq $expectedSourceCommit -and
    [string]$report.source.origin_main_commit -ceq $expectedSourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    $results.Count -eq 36
) "The retained QSDK-R05C report identity or clean-source receipt changed"

$metrics = Measure-SporeExperimentResults `
    -Results $results `
    -ExpectedCount 36
Assert-Exact (
    (($report.metrics | ConvertTo-Json -Compress -Depth 20) -ceq
        ($metrics | ConvertTo-Json -Compress -Depth 20)) -and
    [int]$metrics.observed_world_count -eq 36 -and
    [int]$metrics.complete_receipt_count -eq 36 -and
    [int]$metrics.harness_pass_count -eq 29 -and
    [int]$metrics.integrity_pass_count -eq 36 -and
    [int]$metrics.mechanism_pass_count -eq 36 -and
    [int]$metrics.combined_application_pass_count -eq 36 -and
    [int]$metrics.walking_conjunction_pass_count -eq 29 -and
    [int]$metrics.walking_conjunction_failure_count -eq 7 -and
    [int]$metrics.aggregate_failed_production_walking_gate_count -eq 7 -and
    [int]$metrics.aggregate_release_timeout_count -eq 0 -and
    -not [bool]$metrics.integrity_and_mechanism_complete
) "The QSDK-R05C stored metrics do not exactly reconstruct"

Assert-Exact (
    [int]$report.expected_world_count -eq 36 -and
    [int]$report.observed_world_count -eq 36 -and
    [int]$report.complete_receipt_count -eq 36 -and
    [int]$report.harness_pass_count -eq 29 -and
    [int]$report.walking_pass_count -eq 29 -and
    [int]$report.integrity_pass_count -eq 36 -and
    [int]$report.failure_count -eq 7 -and
    -not [bool]$report.r05c_passed -and
    -not [bool]$report.same_selected_policy_independent_morphology_evidence -and
    -not [bool]$report.development_data_only
) "The QSDK-R05C top-level rejection outcome changed"

Assert-Exact (
    @($report.morphology_ids).Count -eq 12 -and
    (@($report.morphology_ids) -join "|") -ceq
        ($expectedMorphologyIds -join "|") -and
    (@($report.generator_indices) -join "|") -ceq
        ((193..204) -join "|") -and
    (@($report.campaign_seeds) -join "|") -ceq
        ($expectedSeeds -join "|") -and
    [string]$report.material_profile_id -ceq
        "godot_jolt_bw5c_mu095_v1"
) "The QSDK-R05C frozen population or material identity changed"
Assert-DoubleBitsEqual `
    -Actual ([double]$report.authored_friction) `
    -Expected 0.95 `
    -Message "The QSDK-R05C authored friction changed"

$sourceFiles = @($report.source.source_files)
Assert-Exact (
    $sourceFiles.Count -eq 28 -and
    @($sourceFiles.path | Sort-Object -Unique).Count -eq 28
) "QSDK-R05C must retain exactly 28 unique source files"
$verifiedSourceCount = 0
foreach ($sourceFile in $sourceFiles) {
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
    ) (
        "A retained QSDK-R05C source snapshot is unavailable: " +
        $sourceRelativePath
    )
    $verifiedSourceCount += 1
}
$requiredResearchPaths = @(
    "DReCon.pdf",
    "2604.08780v1.pdf",
    "2507.22653v2.pdf",
    "docs/research/LOCOMOTION_RESEARCH_SOURCES.md"
)
foreach ($researchPath in $requiredResearchPaths) {
    Assert-Exact (
        @($sourceFiles | Where-Object {
            [string]$_.path -ceq $researchPath
        }).Count -eq 1
    ) "The R05C source inventory lost research provenance: $researchPath"
}

$preflightArtifacts = @(
    [ordered]@{
        path = [string]$report.full_integrity_preflight.transcript_path
        sha256 = [string]$report.full_integrity_preflight.transcript_sha256
    },
    [ordered]@{
        path = [string]$report.experiment_result_integrity_preflight.artifact_path
        sha256 = [string]$report.experiment_result_integrity_preflight.artifact_sha256
    },
    [ordered]@{
        path = [string]$report.r05c_entrypoint_preflight.transcript_path
        sha256 = [string]$report.r05c_entrypoint_preflight.transcript_sha256
    }
)
$verifiedPreflightArtifactCount = 0
foreach ($artifact in $preflightArtifacts) {
    Assert-HashedFile `
        -Path ([string]$artifact.path) `
        -ExpectedSha256 ([string]$artifact.sha256) `
        -Message "A retained QSDK-R05C preflight artifact is missing or changed"
    $verifiedPreflightArtifactCount += 1
}
Assert-Exact (
    [bool]$report.full_integrity_preflight.passed -and
    [int]$report.full_integrity_preflight.actual_world_build_count -eq 0 -and
    [bool]$report.experiment_result_integrity_preflight.passed -and
    [bool]$report.experiment_result_integrity_preflight.perfect_all_zero_36_cell_matrix_passed -and
    [bool]$report.experiment_result_integrity_preflight.nonzero_ordered_dictionary_canary_passed -and
    [int]$report.experiment_result_integrity_preflight.actual_world_build_count -eq 0 -and
    [bool]$report.r05c_entrypoint_preflight.passed -and
    [int]$report.r05c_entrypoint_preflight.cell_count -eq 36 -and
    [int]$report.r05c_entrypoint_preflight.exact_candidate_full_authority_start_count -eq 36 -and
    [int]$report.r05c_entrypoint_preflight.exact_candidate_declared_policy_runtime_boundary_count -eq 36 -and
    [int]$report.r05c_entrypoint_preflight.actual_world_build_count -eq 0 -and
    -not [bool]$report.candidate_mechanism_preflight.required -and
    [bool]$report.candidate_mechanism_preflight.passed -and
    -not [bool]$report.candidate_selector_preflight.required -and
    [bool]$report.candidate_selector_preflight.passed
) "A QSDK-R05C mandatory zero-world preflight changed"

$actualPairs = [System.Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
$falseReceiptFrequency = [ordered]@{}
$actualFalseGateSignatures = @()
$verifiedCellArtifactCount = 0
$processExitZeroCount = 0
$processExitOneCount = 0
$timedOutCount = 0
$killedProcessTreeCount = 0
$receiptParseFailureCount = 0
$commonIntegrityCount = 0
$mechanismCount = 0
$combinedApplicationCount = 0
$walkingCount = 0
$harnessCount = 0
$fullAuthorityCount = 0
$selectedPolicyIdentityCount = 0
$storedFailedProductionGateCount = 0L
$storedReleaseTimeoutCount = 0L
$rawFalseReceiptCount = 0L
$rawFalseContactGatingWithoutTimeoutCount = 0L
$sdkStepCount = 0L
$validatedCommandCount = 0L
$nativeMotorWriteCount = 0L
$directBodyWriteCount = 0L
$legacyPostSettleWriteCount = 0L
$legacyEvidenceWriteCount = 0L
$sdkMismatchCount = 0L
$sdkSafeDisableCount = 0L
$sdkSafeNoActuationCount = 0L
$summedDurationSeconds = 0.0

foreach ($result in $results) {
    $pair = (
        [string]$result.morphology_id + "|" +
        [string]$result.campaign_seed
    )
    Assert-Exact (
        $actualPairs.Add($pair)
    ) "QSDK-R05C contains a duplicate morphology/seed cell: $pair"
    Assert-Exact (
        $expectedMorphologyIds -ccontains [string]$result.morphology_id -and
        $expectedSeeds -contains [int]$result.campaign_seed
    ) "QSDK-R05C contains an undeclared morphology/seed cell: $pair"

    if ([int]$result.process_exit_code -eq 0) {
        $processExitZeroCount += 1
    } elseif ([int]$result.process_exit_code -eq 1) {
        $processExitOneCount += 1
    } else {
        throw "QSDK-R05C contains an unexpected cell exit code: $pair"
    }
    if ([bool]$result.timed_out) {
        $timedOutCount += 1
    }
    if ([bool]$result.killed_process_tree) {
        $killedProcessTreeCount += 1
    }
    if (-not [bool]$result.receipt_parsed) {
        $receiptParseFailureCount += 1
    }

    $receipt = $result.receipt
    Assert-Exact (
        [bool]$result.receipt_parsed -and
        [string]$result.receipt_parse_error -ceq "" -and
        -not [bool]$result.timed_out -and
        -not [bool]$result.killed_process_tree -and
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r05c_independent_morphology_cell_v1" -and
        [string]$receipt.campaign_id -ceq "QSDK-R05C" -and
        [string]$receipt.gate_id -ceq "QSDK-R05C" -and
        [string]$receipt.campaign_role -ceq "independent_validation" -and
        [string]$receipt.morphology_id -ceq [string]$result.morphology_id -and
        [int]$receipt.generator_index -eq [int]$result.generator_index -and
        [int]$receipt.campaign_seed -eq [int]$result.campaign_seed -and
        [string]$receipt.selected_candidate_id -ceq "BW15F-B" -and
        [string]$receipt.controller_policy_id -ceq $expectedPolicyId -and
        [string]$receipt.selected_policy_digest -ceq $expectedPolicyDigest
    ) "A retained QSDK-R05C cell identity changed: $pair"

    Assert-Exact (
        [bool]$receipt.common_execution_integrity -and
        [bool]$result.common_execution_integrity -and
        [bool]$result.mechanism_gate_passed -and
        [bool]$result.combined_application_gate_passed -and
        [bool]$receipt.sdk_authority_enabled -and
        [string]$receipt.sdk_authority_scope -ceq "post_settle_full" -and
        [bool]$receipt.sdk_authority_start_result.ok -and
        [bool]$receipt.sdk_authority_start_result.actuation_authority -and
        [string]$receipt.sdk_authority_start_result.controller_policy_id -ceq
            $expectedPolicyId -and
        [string]$receipt.sdk_authority_start_result.authority_scope -ceq
            "post_settle_full" -and
        [int]$receipt.world_build_count -eq 1 -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "A QSDK-R05C technical authority receipt is invalid: $pair"

    Assert-Exact (
        [long]$receipt.validated_balanced_wave_command_count -eq
            ([long]$receipt.sdk_step_count * 8L) -and
        [long]$receipt.native_motor_write_count -eq
            [long]$receipt.validated_balanced_wave_command_count -and
        [long]$receipt.direct_body_write_count -eq 0 -and
        [long]$receipt.legacy_post_settle_motor_write_count -eq 0 -and
        [long]$receipt.legacy_evidence_motor_write_count -eq 0 -and
        [long]$receipt.sdk_mismatch_count -eq 0 -and
        [long]$receipt.sdk_safe_disable_count -eq 0 -and
        [long]$receipt.sdk_safe_no_actuation_count -eq 0
    ) "A QSDK-R05C command/write arithmetic or exclusivity invariant failed: $pair"

    if ([bool]$result.common_execution_integrity) {
        $commonIntegrityCount += 1
    }
    if ([bool]$result.mechanism_gate_passed) {
        $mechanismCount += 1
    }
    if ([bool]$result.combined_application_gate_passed) {
        $combinedApplicationCount += 1
    }
    if ([bool]$result.walking_observed) {
        $walkingCount += 1
    }
    if ([bool]$result.harness_passed) {
        $harnessCount += 1
    }
    if (
        [bool]$receipt.sdk_authority_enabled -and
        [string]$receipt.sdk_authority_scope -ceq "post_settle_full"
    ) {
        $fullAuthorityCount += 1
    }
    if (
        [string]$receipt.controller_policy_id -ceq $expectedPolicyId -and
        [string]$receipt.selected_policy_digest -ceq $expectedPolicyDigest
    ) {
        $selectedPolicyIdentityCount += 1
    }

    $storedFailedProductionGateCount += (
        [long]$result.failed_production_walking_gate_count
    )
    $storedReleaseTimeoutCount += [long]$result.release_timeout_count
    $sdkStepCount += [long]$receipt.sdk_step_count
    $validatedCommandCount += (
        [long]$receipt.validated_balanced_wave_command_count
    )
    $nativeMotorWriteCount += [long]$receipt.native_motor_write_count
    $directBodyWriteCount += [long]$receipt.direct_body_write_count
    $legacyPostSettleWriteCount += (
        [long]$receipt.legacy_post_settle_motor_write_count
    )
    $legacyEvidenceWriteCount += (
        [long]$receipt.legacy_evidence_motor_write_count
    )
    $sdkMismatchCount += [long]$receipt.sdk_mismatch_count
    $sdkSafeDisableCount += [long]$receipt.sdk_safe_disable_count
    $sdkSafeNoActuationCount += [long]$receipt.sdk_safe_no_actuation_count
    $summedDurationSeconds += [double]$result.duration_seconds

    $falseGateNames = @()
    foreach (
        $gate in (
            $receipt.walking_gate_receipts.GetEnumerator() |
                Sort-Object Key
        )
    ) {
        if (-not [bool]$gate.Value) {
            $gateName = [string]$gate.Key
            $falseGateNames += $gateName
            $rawFalseReceiptCount += 1
            if (
                $gateName -ceq
                    "contact_gating_completed_without_timeout"
            ) {
                $rawFalseContactGatingWithoutTimeoutCount += 1
            }
            if ($falseReceiptFrequency.Contains($gateName)) {
                $falseReceiptFrequency[$gateName] += 1
            } else {
                $falseReceiptFrequency[$gateName] = 1
            }
        }
    }

    Assert-Exact (
        [bool]$result.walking_observed -eq
            ($falseGateNames.Count -eq 0) -and
        [bool]$result.harness_passed -eq
            [bool]$result.walking_observed -and
        [bool]$receipt.walking_observed -eq
            [bool]$result.walking_observed -and
        [bool]$receipt.harness_passed -eq
            [bool]$result.harness_passed -and
        (
            ([int]$result.process_exit_code -eq 0) -eq
            [bool]$result.harness_passed
        )
    ) "A QSDK-R05C walking conjunction or harness disposition changed: $pair"

    if ($falseGateNames.Count -gt 0) {
        $actualFalseGateSignatures += (
            [string]$result.morphology_id + "|" +
            [string]$result.campaign_seed + "|" +
            ($falseGateNames -join ",")
        )
    }

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
            -Message "A retained QSDK-R05C cell artifact changed: $pair"
        $verifiedCellArtifactCount += 1
    }
}

Assert-Exact (
    $actualPairs.Count -eq 36 -and
    $processExitZeroCount -eq 29 -and
    $processExitOneCount -eq 7 -and
    $timedOutCount -eq 0 -and
    $killedProcessTreeCount -eq 0 -and
    $receiptParseFailureCount -eq 0 -and
    $commonIntegrityCount -eq 36 -and
    $mechanismCount -eq 36 -and
    $combinedApplicationCount -eq 36 -and
    $walkingCount -eq 29 -and
    $harnessCount -eq 29 -and
    $fullAuthorityCount -eq 36 -and
    $selectedPolicyIdentityCount -eq 36 -and
    $verifiedCellArtifactCount -eq 108
) "QSDK-R05C completeness, process, authority, or outcome counts changed"

Assert-Exact (
    ($actualFalseGateSignatures -join "`n") -ceq
        ($expectedFalseGateSignatures -join "`n") -and
    $rawFalseReceiptCount -eq 25 -and
    $rawFalseContactGatingWithoutTimeoutCount -eq 4 -and
    $falseReceiptFrequency.Count -eq
        $expectedFalseReceiptFrequency.Count
) "The raw QSDK-R05C failed-cell or false-receipt reconstruction changed"
foreach ($gateName in $expectedFalseReceiptFrequency.Keys) {
    Assert-Exact (
        $falseReceiptFrequency.Contains($gateName) -and
        [int]$falseReceiptFrequency[$gateName] -eq
            [int]$expectedFalseReceiptFrequency[$gateName] -and
        [int]$manifest.raw_walking_receipt_analysis.false_receipt_frequency[
            $gateName
        ] -eq [int]$expectedFalseReceiptFrequency[$gateName]
    ) "The false-receipt frequency changed for $gateName"
}

Assert-Exact (
    [long]$manifest.raw_walking_receipt_analysis.false_boolean_receipt_count -eq
        25 -and
    [int]$manifest.raw_walking_receipt_analysis.cells_with_any_false_walking_receipt -eq
        7 -and
    [long]$manifest.aggregate_reporting_limitation.stored_aggregate_failed_production_walking_gate_count -eq
        7 -and
    [long]$manifest.aggregate_reporting_limitation.actual_false_boolean_walking_receipt_count -eq
        25 -and
    [long]$manifest.aggregate_reporting_limitation.stored_aggregate_release_timeout_count -eq
        0 -and
    [long]$manifest.aggregate_reporting_limitation.actual_false_contact_gating_completed_without_timeout_count -eq
        4 -and
    [string]$manifest.aggregate_reporting_limitation.acceptance_impact -ceq
        "none" -and
    [bool]$manifest.aggregate_reporting_limitation.report_rewrite_forbidden -and
    $storedFailedProductionGateCount -eq 7 -and
    $storedReleaseTimeoutCount -eq 0 -and
    $storedFailedProductionGateCount -ne $rawFalseReceiptCount -and
    $storedReleaseTimeoutCount -ne
        $rawFalseContactGatingWithoutTimeoutCount
) "The QSDK-R05C aggregate-reporting limitation is no longer explicit"

Assert-Exact (
    $sdkStepCount -eq 101008 -and
    $validatedCommandCount -eq 808064 -and
    $nativeMotorWriteCount -eq 808064 -and
    $directBodyWriteCount -eq 0 -and
    $legacyPostSettleWriteCount -eq 0 -and
    $legacyEvidenceWriteCount -eq 0 -and
    $sdkMismatchCount -eq 0 -and
    $sdkSafeDisableCount -eq 0 -and
    $sdkSafeNoActuationCount -eq 0 -and
    [long]$manifest.authority_and_integrity.sdk_step_count -eq
        $sdkStepCount -and
    [long]$manifest.authority_and_integrity.validated_balanced_wave_command_count -eq
        $validatedCommandCount -and
    [long]$manifest.authority_and_integrity.native_motor_write_count -eq
        $nativeMotorWriteCount
) "QSDK-R05C command or forbidden-write totals changed"
Assert-DoubleBitsEqual `
    -Actual $summedDurationSeconds `
    -Expected (
        [double]$manifest.authority_and_integrity.summed_cell_duration_seconds
    ) `
    -Message "The QSDK-R05C summed cell duration changed"

$failedCells = @($manifest.failed_cells)
Assert-Exact (
    $failedCells.Count -eq 7
) "The QSDK-R05C manifest must retain exactly seven failed cells"
foreach ($failedCell in $failedCells) {
    $matches = @($results | Where-Object {
        [string]$_.morphology_id -ceq [string]$failedCell.morphology_id -and
        [int]$_.campaign_seed -eq [int]$failedCell.campaign_seed
    })
    Assert-Exact (
        $matches.Count -eq 1
    ) "A manifest QSDK-R05C failed cell is missing from the report"
    $result = $matches[0]
    $receipt = $result.receipt
    $falseNames = @(
        $receipt.walking_gate_receipts.GetEnumerator() |
            Where-Object { -not [bool]$_.Value } |
            Sort-Object Key |
            ForEach-Object { [string]$_.Key }
    )
    Assert-Exact (
        [int]$failedCell.generator_index -eq
            [int]$result.generator_index -and
        [int]$failedCell.process_exit_code -eq
            [int]$result.process_exit_code -and
        (@($failedCell.false_walking_gate_receipts) -join "|") -ceq
            ($falseNames -join "|") -and
        [long]$failedCell.sdk_step_count -eq
            [long]$receipt.sdk_step_count -and
        [long]$failedCell.native_motor_write_count -eq
            [long]$receipt.native_motor_write_count -and
        [bool]$failedCell.common_execution_integrity -and
        [bool]$receipt.common_execution_integrity
    ) "A QSDK-R05C manifest failed-cell receipt changed"
    foreach (
        $fieldName in @(
            "evidence_task_frame_forward_displacement_m",
            "final_task_frame_forward_displacement_m",
            "final_task_frame_lateral_displacement_m",
            "maximum_tilt_rad",
            "minimum_torso_height_m"
        )
    ) {
        Assert-DoubleBitsEqual `
            -Actual ([double]$failedCell[$fieldName]) `
            -Expected ([double]$receipt[$fieldName]) `
            -Message (
                "A QSDK-R05C failed-cell diagnostic changed: " +
                [string]$failedCell.morphology_id + "/" +
                [string]$failedCell.campaign_seed + "/" + $fieldName
            )
    }
}

$verifiedSupervisorArtifactCount = 0
foreach (
    $artifact in @(
        $manifest.supervisor_artifacts.stdout,
        $manifest.supervisor_artifacts.stderr
    )
) {
    Assert-HashedFile `
        -Path ([string]$artifact.path) `
        -ExpectedSha256 ([string]$artifact.sha256) `
        -Message "A retained QSDK-R05C supervisor artifact changed"
    $verifiedSupervisorArtifactCount += 1
}
$expectedExitMarkerPath = (
    [string]$manifest.supervisor_artifacts.stdout.path
).Replace("-supervisor.stdout.log", "-supervisor.exit.txt")
Assert-Exact (
    -not [bool]$manifest.supervisor_artifacts.exit_marker_present -and
    -not (Test-Path -LiteralPath $expectedExitMarkerPath) -and
    [string]$manifest.supervisor_artifacts.exit_marker_interpretation -ne ""
) "The QSDK-R05C absent exit-marker disposition changed"

Assert-Exact (
    $verifiedSourceCount -eq
        [int]$manifest.completeness.verified_source_file_count -and
    $verifiedCellArtifactCount -eq
        [int]$manifest.completeness.verified_cell_artifact_count -and
    $verifiedPreflightArtifactCount -eq
        [int]$manifest.completeness.verified_preflight_artifact_count -and
    $verifiedSupervisorArtifactCount -eq
        [int]$manifest.completeness.verified_supervisor_artifact_count -and
    [int]$manifest.completeness.referenced_hash_failure_count -eq 0 -and
    -not [bool]$manifest.completeness.early_stop_used -and
    [int]$manifest.completeness.physical_worlds_rerun_replaced_or_deleted -eq 0
) "The QSDK-R05C retained-artifact completeness boundary changed"

Assert-Exact (
    [bool]$manifest.scientific_disposition.complete_result_valid -and
    [bool]$manifest.scientific_disposition.technical_sdk_execution_valid -and
    [bool]$manifest.scientific_disposition.independent_validation_rejected -and
    [bool]$manifest.scientific_disposition.failure_identity_is_diagnostic_only -and
    [bool]$manifest.scientific_disposition.failure_identity_may_not_be_used_to_repair_or_rerun_r05c -and
    [bool]$manifest.next_allowed_work.r05c_is_closed -and
    [bool]$manifest.next_allowed_work.new_global_mechanism_requires_new_identity -and
    [bool]$manifest.next_allowed_work.new_mechanism_may_not_condition_on_r05c_failure_identities -and
    [bool]$manifest.next_allowed_work.later_independent_validation_requires_unopened_morphologies_and_fresh_seeds -and
    [bool]$manifest.next_allowed_work.unbiased_friction_reservation_remains_unopened
) "The QSDK-R05C scientific disposition or next-experiment boundary changed"

$falseClaimKeys = @(
    "same_selected_policy_independent_morphology_evidence",
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
Assert-Exact (
    [bool]$manifest.claim_boundary.finite_population_only
) "The QSDK-R05C closure must retain its finite-population boundary"
foreach ($claimKey in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$manifest.claim_boundary[$claimKey]
    ) "QSDK-R05C unlawfully gained claim authority: $claimKey"
}

$falseReportClaimKeys = @(
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "material_robustness",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "running",
    "cross_engine_c6",
    "completed_engine_neutral_sdk",
    "release_authorized",
    "physical_acceptance_authority"
)
foreach ($claimKey in $falseReportClaimKeys) {
    Assert-Exact (
        -not [bool]$report[$claimKey]
    ) "The retained R05C report unlawfully gained claim authority: $claimKey"
}

Write-Host (
    "QSDK-R05C closure passed: rejected 29/36 walking, " +
    "36/36 integrity/mechanism/application, 25 raw false receipts, " +
    "28 source + 108 cell + 3 preflight + 2 supervisor artifacts verified."
)
