#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW25Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
$gateId = "BW25Y"
$sourceCommit = "14c1c3488e858398158be59f608e21f09cf50671"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw25y_yaw_development_closure.json"
$runnerPath = Join-Path $sdkRoot "run_balanced_wave_bw25y_yaw_development.ps1"
$gatePath = Join-Path $sdkRoot "balanced_wave_bw25y_yaw_development_gate.ps1"
$expectedClosureSha256 =
    "c8b5a0a021f84fc929348142ab452414ad990d0cc2682d255e9a6890bc21f5ab"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-HashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$Artifact.byte_length -and
        (Get-RawSha256 -Path $path) -ceq [string]$Artifact.raw_sha256
    ) "$gateId retained $Label is missing or changed"
}

function Get-EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $lines = foreach ($file in @(
        $files | Sort-Object {
            $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        }
    )) {
        $relativePath = $file.FullName.Substring($Root.Length + 1).Replace("\", "/")
        $rawSha256 = Get-RawSha256 -Path $file.FullName
        "$relativePath`t$($file.Length)`t$rawSha256"
    }
    $text = ($lines -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long](
            $files | Measure-Object -Property Length -Sum
        ).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw25y_yaw_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_incomplete_infrastructure_invalid_actual_worker_receipt_composition_failure" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    -not [bool]$closure.disposition.complete_declared_controller_comparison_retained -and
    -not [bool]$closure.disposition.infrastructure_valid -and
    -not [bool]$closure.disposition.development_result_valid -and
    [bool]$closure.disposition.not_a_locomotion_negative -and
    [bool]$closure.disposition.not_a_valid_none_selection -and
    [bool]$closure.disposition.raw_physical_observations_retained_for_successor_design_only
) "$gateId closure identity or disposition changed"

foreach ($binding in $closure.frozen_source_blobs.GetEnumerator()) {
    $relativePath = [string]$binding.Value.path
    $treeLine = (& git -C $repoRoot ls-tree $sourceCommit -- (
        $relativePath
    )).Trim()
    $treeParts = @($treeLine -split "\s+")
    Assert-Exact (
        $treeParts.Count -ge 3 -and
        [string]$treeParts[1] -ceq "blob" -and
        [string]$treeParts[2] -ceq [string]$binding.Value.git_blob_oid -and
        [string]$binding.Value.raw_sha256 -cmatch "^[0-9a-f]{64}$"
    ) "$gateId frozen source binding changed: $($binding.Key)"
    # The historical raw checkout receipt is descriptive. Only the commit-pinned
    # Git blob above is retained source authority across checkout filter changes.
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw25y-yaw-development-14c1c34" -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "$gateId retained evidence root is missing"
foreach ($entry in @(
    @($closure.retained_evidence.attempt, "attempt"),
    @($closure.retained_evidence.raw_result, "raw result"),
    @(
        $closure.retained_evidence.posthoc_execution_diagnostic,
        "posthoc execution diagnostic"
    )
)) {
    Assert-HashedArtifact `
        -Root $evidenceRoot `
        -Artifact $entry[0] `
        -Label $entry[1]
}
Assert-Exact (
    -not [bool]$closure.retained_evidence.evaluation_artifact_present -and
    -not [bool]$closure.retained_evidence.completion_artifact_present -and
    -not [bool]$closure.retained_evidence.report_artifact_present
) "$gateId absent terminal-artifact declaration changed"
foreach ($relativePath in @(
    "evaluation.json", "completion.json", "report.json"
)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath (Join-Path $evidenceRoot $relativePath))
    ) "$gateId absent terminal artifact unexpectedly exists: $relativePath"
}
$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq [int]$closure.retained_evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$closure.retained_evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$closure.retained_evidence.tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "attempt.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$rawResult = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "raw-result.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$diagnostic = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "posthoc-execution-diagnostic.json"
) | ConvertFrom-Json -AsHashtable -Depth 128

Assert-Exact (
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.attempt_id -ceq
        "5939f95610064a8fa4b97a6eb84b936d" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.authority_contract_passed -and
    [bool]$attempt.receipt_parity_passed -and
    [bool]$attempt.worker_entrypoint_preflight_passed -and
    [bool]$attempt.attempt_contract_preflight_passed -and
    [bool]$attempt.stage_one_freeze_verified -and
    [int]$attempt.expected_gate_count -eq 50 -and
    [int]$attempt.expected_world_count -eq 28 -and
    @($attempt.ordered_cell_ids).Count -eq 28 -and
    @($attempt.primary_world_attempt_ids).Count -eq 28 -and
    @($attempt.replacement_world_attempt_ids).Count -eq 28 -and
    [int]$attempt.replacement_budget_per_incomplete_cell -eq 1 -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt changed"

Assert-Exact (
    [string]$rawResult.campaign_id -ceq $campaignId -and
    [string]$rawResult.gate_id -ceq $gateId -and
    [int]$rawResult.expected_world_count -eq 28 -and
    [int]$rawResult.observed_world_count -eq 0 -and
    [int]$rawResult.integrity_failure_count -eq 28 -and
    [int]$rawResult.physical_world_process_attempt_count -eq 56 -and
    [int]$rawResult.complete_final_receipt_count -eq 0 -and
    [int]$rawResult.selector_invocation_count_before_evaluation -eq 0 -and
    [string]$rawResult.pre_evaluation_selected_candidate_id -ceq "NONE" -and
    @($rawResult.cells).Count -eq 28 -and
    @($rawResult.cells | Where-Object { $_.Count -eq 0 }).Count -eq 28 -and
    [string]$rawResult.source.commit -ceq $sourceCommit -and
    [bool]$rawResult.source.worktree_clean -and
    [bool]$rawResult.source.matches_live_github_main
) "$gateId retained raw result changed"
foreach ($claim in $rawResult.declared_claims.Keys) {
    Assert-Exact (
        -not [bool]$rawResult.declared_claims[$claim]
    ) "$gateId retained raw-result claim became true: $claim"
}

$rawReceipts = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "raw-receipt.json"
)
$stderrFiles = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "stderr.log"
)
$transcriptFiles = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "transcript.log"
)
$godotLogFiles = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "godot.log"
)
Assert-Exact (
    $rawReceipts.Count -eq 56 -and
    @($rawReceipts | Where-Object { $_.FullName -match "\\primary\\" }).Count -eq 28 -and
    @($rawReceipts | Where-Object { $_.FullName -match "\\replacement\\" }).Count -eq 28 -and
    $stderrFiles.Count -eq 56 -and
    @($stderrFiles | Where-Object Length -gt 0).Count -eq 56 -and
    $transcriptFiles.Count -eq 56 -and
    $godotLogFiles.Count -eq 56
) "$gateId retained worker artifact cardinality changed"

$candidateOrControlReceiptCount = 0
$safetyReceiptCount = 0
foreach ($file in $rawReceipts) {
    $receipt = Get-Content -Raw -LiteralPath $file.FullName |
        ConvertFrom-Json -AsHashtable -Depth 128
    $attemptKind = Split-Path -Leaf (Split-Path -Parent $file.FullName)
    $cellDirectory = Split-Path -Leaf (
        Split-Path -Parent (Split-Path -Parent $file.FullName)
    )
    $cellId = $cellDirectory -replace "^cell-\d+-", ""
    $expectedWorldAttemptId = if ($attemptKind -ceq "primary") {
        "BW25Y-P1::$cellId"
    } else {
        "BW25Y-R1::$cellId"
    }
    foreach ($requiredMissingKey in @(
        "cell_id", "role", "campaign_seed", "walking_gate_receipts"
    )) {
        Assert-Exact (-not $receipt.ContainsKey($requiredMissingKey)) (
            "$gateId partial raw receipt unexpectedly gained $requiredMissingKey"
        )
    }
    Assert-Exact (
        [bool]$receipt.raw_receipt_complete -and
        -not [bool]$receipt.role_gate_passed -and
        [string]$receipt.campaign_attempt_id -ceq [string]$attempt.attempt_id -and
        [string]$receipt.world_attempt_id -ceq $expectedWorldAttemptId
    ) "$gateId partial raw receipt identity surface changed: $cellId/$attemptKind"
    if ($receipt.Keys.Count -eq 47) {
        $candidateOrControlReceiptCount += 1
    } elseif ($receipt.Keys.Count -eq 14) {
        $safetyReceiptCount += 1
    } else {
        throw "$gateId unexpected partial raw receipt key count: $($receipt.Keys.Count)"
    }
}
Assert-Exact (
    $candidateOrControlReceiptCount -eq 54 -and $safetyReceiptCount -eq 2
) "$gateId partial raw receipt shape counts changed"

$stderrHashGroups = @(
    $stderrFiles | Get-FileHash -Algorithm SHA256 | Group-Object Hash
)
$candidateErrorGroup = @(
    $stderrHashGroups | Where-Object {
        $_.Name.ToLowerInvariant() -ceq
            "09bde6ad3780983a94dc7ed7d06422510927a75a4b0b5a72fbbb160d98624745"
    }
)
$safetyErrorGroup = @(
    $stderrHashGroups | Where-Object {
        $_.Name.ToLowerInvariant() -ceq
            "669ee41a1750b34c3f78ae395233588fb5b4d6551659e9591df7ed4fbc32ad01"
    }
)
Assert-Exact (
    $stderrHashGroups.Count -eq 2 -and
    $candidateErrorGroup.Count -eq 1 -and
    $candidateErrorGroup[0].Count -eq 54 -and
    $safetyErrorGroup.Count -eq 1 -and
    $safetyErrorGroup[0].Count -eq 2 -and
    @(
        $stderrFiles | Select-String -SimpleMatch -Pattern (
            "Invalid access to property or key 'cohort'"
        ) | Select-Object -ExpandProperty Path -Unique
    ).Count -eq 56
) "$gateId retained deterministic cohort errors changed"

Assert-Exact (
    [string]$diagnostic.classification -ceq
        "posthoc_diagnostic_only_not_a_controller_comparison_result_selection_or_reclassification" -and
    [int]$diagnostic.retained_artifact_scan_before_this_diagnostic.file_count -eq 226 -and
    [int]$diagnostic.retained_artifact_scan_before_this_diagnostic.physical_worker_process_attempt_count -eq 56 -and
    [int]$diagnostic.retained_artifact_scan_before_this_diagnostic.complete_final_receipt_count -eq 0 -and
    [int]$diagnostic.raw_receipt_diagnostic.raw_receipt_complete_true_count -eq 56 -and
    [int]$diagnostic.raw_receipt_diagnostic.missing_required_identity_and_walking_projection_count -eq 56 -and
    [bool]$diagnostic.defect.present -and
    [string]$diagnostic.defect.classification -ceq
        "actual_worker_receipt_composition_schema_incompatibility" -and
    -not [bool]$diagnostic.defect.production_controller_or_physics_adapter_defect -and
    [bool]$diagnostic.preflight_gap.actual_inherited_composer_compatibility_was_unproven -and
    [bool]$diagnostic.frozen_evaluator_reproduction.threw -and
    [string]$diagnostic.frozen_evaluator_reproduction.message -ceq
        "Cannot bind argument to parameter 'CandidateCells' because it is an empty array." -and
    -not [bool]$diagnostic.disposition.infrastructure_valid -and
    -not [bool]$diagnostic.disposition.development_result_valid -and
    [bool]$diagnostic.disposition.not_a_locomotion_negative -and
    [bool]$diagnostic.disposition.not_a_valid_none_selection
) "$gateId retained posthoc diagnostic changed"

. $gatePath
$evaluationThrew = $false
$evaluationExceptionType = ""
$evaluationMessage = ""
try {
    [void](Invoke-Bw25yYawDevelopmentEvaluation -Result $rawResult)
} catch {
    $evaluationThrew = $true
    $evaluationExceptionType = $_.Exception.GetType().FullName
    $evaluationMessage = $_.Exception.Message
}
Assert-Exact (
    $evaluationThrew -and
    $evaluationExceptionType -ceq
        "System.Management.Automation.ParameterBindingValidationException" -and
    $evaluationMessage -ceq
        "Cannot bind argument to parameter 'CandidateCells' because it is an empty array."
) "$gateId frozen evaluator failure no longer reproduces"

foreach ($claim in $closure.claim_boundary.Keys) {
    Assert-Exact (
        -not [bool]$closure.claim_boundary[$claim]
    ) "$gateId unsupported closure claim became true: $claim"
}
Assert-Exact (
    [bool]$closure.immutability.first_physical_attempt_is_final_for_source_identity -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_selection_forbidden -and
    [bool]$closure.immutability.posthoc_reclassification_forbidden -and
    [bool]$closure.successor_requirements.new_campaign_id_source_identity_and_preregistration_required -and
    [bool]$closure.successor_requirements.fresh_unexposed_material_values_and_seeds_required_for_any_authoritative_selection -and
    [bool]$closure.successor_requirements.every_real_worker_role_must_traverse_actual_receipt_constructor_with_real_shaped_synthetic_summary_before_physics -and
    [bool]$closure.successor_requirements.raw_receipt_completeness_must_be_computed_from_exact_schema_and_stderr_state -and
    [bool]$closure.successor_requirements.any_worker_script_error_must_make_the_raw_receipt_structurally_incomplete -and
    [bool]$closure.successor_requirements.cross_process_experiment_lock_required
) "$gateId immutability or successor boundary changed"

$rerunOutputRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("bw25y-closure-rerun-" + [Guid]::NewGuid().ToString("N"))
Assert-Exact (
    -not (Test-Path -LiteralPath $rerunOutputRoot)
) "$gateId rerun-canary path already exists"
$rerunOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical `
    -OutputRoot $rerunOutputRoot 2>&1 | Out-String)
Assert-Exact (
    $LASTEXITCODE -ne 0 -and
    $rerunOutput.Contains(
        "$gateId campaign is already closed and may not rerun",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $rerunOutputRoot)
) "$gateId closed-state rerun interlock failed"

Write-Host (
    "BW25Y_YAW_DEVELOPMENT_CLOSURE_PASS status=infrastructure-invalid-incomplete " +
    "cells=28 process_attempts=56 raw_receipts=56 final_receipts=0 " +
    "cohort_errors=56 evaluator_threw=True selector_invocations=0 " +
    "locomotion_negative=False valid_none=False selection_authority=False " +
    "validation_authority=False physical_authority=False rerun_refused=True"
)
