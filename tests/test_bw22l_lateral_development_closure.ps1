#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT"
$gateId = "BW22L"
$sourceCommit = "0b1883070d05c235609284ab07460233b91a208b"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22l_lateral_development_closure.json"
$expectedClosureSha256 =
    "e35a93c19613a302e72800d1be9222970ef127fd0028baf8e7440e620e2929e5"
$compilerPath = Join-Path (
    $sdkRoot
) "compile_balanced_wave_bw22l_posthoc_receipt_diagnostic.ps1"
$runnerPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw22l_lateral_development.ps1"

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
        [Parameter(Mandatory)]$Artifact,
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
    $rows = @(
        $files |
            ForEach-Object {
                $relative = [System.IO.Path]::GetRelativePath(
                    $Root,
                    $_.FullName
                ).Replace("\", "/")
                "{0}`t{1}`t{2}" -f (
                    $relative,
                    $_.Length,
                    (Get-RawSha256 -Path $_.FullName)
                )
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
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
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw22l_lateral_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_invalid_final_receipt_composition_mismatch" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [bool]$closure.disposition.complete_physical_execution_retained -and
    -not [bool]$closure.disposition.infrastructure_valid -and
    -not [bool]$closure.disposition.development_result_valid -and
    [bool]$closure.disposition.not_a_locomotion_negative -and
    [bool]$closure.disposition.not_a_valid_none_selection -and
    [bool]$closure.disposition.raw_physical_observations_retained_for_successor_design_only
) "$gateId closure identity or disposition changed"

foreach ($binding in $closure.frozen_source_blobs.GetEnumerator()) {
    $path = Join-Path $repoRoot ([string]$binding.Value.path)
    $treeLine = (& git -C $repoRoot ls-tree $sourceCommit -- (
        [string]$binding.Value.path
    )).Trim()
    $treeParts = @($treeLine -split "\s+")
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq
            [string]$binding.Value.raw_sha256 -and
        $treeParts.Count -ge 3 -and
        [string]$treeParts[2] -ceq [string]$binding.Value.git_blob_oid
    ) "$gateId frozen source binding changed: $($binding.Key)"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    Test-Path -LiteralPath $evidenceRoot -PathType Container
) "$gateId retained evidence root is missing"
foreach ($entry in @(
    @($closure.retained_evidence.attempt, "attempt"),
    @($closure.retained_evidence.completion, "completion"),
    @($closure.retained_evidence.evaluation, "evaluation"),
    @($closure.retained_evidence.raw_result, "raw result"),
    @($closure.retained_evidence.primary_report, "primary report"),
    @(
        $closure.retained_evidence.posthoc_receipt_shape_diagnostic,
        "posthoc receipt-shape diagnostic"
    )
)) {
    Assert-HashedArtifact `
        -Root $evidenceRoot `
        -Artifact $entry[0] `
        -Label $entry[1]
}
$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq
        [int]$closure.retained_evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$closure.retained_evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$closure.retained_evidence.tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "attempt.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$rawResult = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "raw-result.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "report.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$diagnostic = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "posthoc-receipt-shape-diagnostic.json"
) | ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.authority_contract_passed -and
    [bool]$attempt.stage_one_freeze_verified -and
    [int]$attempt.expected_world_count -eq 28 -and
    @($attempt.ordered_cell_ids).Count -eq 28 -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.completed_cell_attempt_count -eq 28 -and
    [int]$attempt.parsed_receipt_count -eq 28 -and
    [int]$attempt.integrity_failure_count -eq 0 -and
    -not [bool]$attempt.evaluation_ok
) "$gateId retained attempt changed"

Assert-Exact (
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [int]$completion.expected_world_count -eq 28 -and
    [int]$completion.attempted_world_count -eq 28 -and
    [int]$completion.parsed_receipt_count -eq 28 -and
    [int]$completion.integrity_failure_count -eq 0 -and
    -not [bool]$completion.evaluation_ok -and
    [string]$completion.selected_candidate_id -ceq "NONE" -and
    -not [bool]$completion.development_selection_authority -and
    -not [bool]$completion.independent_validation_authority -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion changed"

Assert-Exact (
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.first_complete_result_final_for_source_identity -and
    -not [bool]$report.evaluation_ok -and
    [string]$report.result_status -ceq "invalid_development_execution" -and
    [string]$report.selected_candidate_id -ceq "NONE" -and
    -not [bool]$report.development_selection_authority -and
    [string]$report.attempt_raw_sha256 -ceq
        [string]$closure.retained_evidence.attempt.raw_sha256 -and
    [string]$report.raw_result_raw_sha256 -ceq
        [string]$closure.retained_evidence.raw_result.raw_sha256 -and
    [string]$report.evaluation_raw_sha256 -ceq
        [string]$closure.retained_evidence.evaluation.raw_sha256 -and
    [string]$report.completion_raw_sha256 -ceq
        [string]$closure.retained_evidence.completion.raw_sha256 -and
    -not [bool]$report.physical_acceptance_authority
) "$gateId retained report changed"

$cellAttempts = @($report.cell_attempts)
Assert-Exact ($cellAttempts.Count -eq 28) "$gateId cell-attempt count changed"
foreach ($cellAttempt in $cellAttempts) {
    Assert-Exact (
        [int]$cellAttempt.ordinal -ge 1 -and
        [int]$cellAttempt.ordinal -le 28 -and
        [int]$cellAttempt.process_exit_code -eq 0 -and
        -not [bool]$cellAttempt.timed_out -and
        -not [bool]$cellAttempt.killed_process_tree -and
        [bool]$cellAttempt.receipt_parsed -and
        [string]$cellAttempt.receipt_parse_error -ceq ""
    ) "$gateId cell execution changed: $($cellAttempt.cell_id)"
    foreach ($artifactName in @("transcript", "stderr")) {
        $path = [System.IO.Path]::GetFullPath(
            [string]$cellAttempt["${artifactName}_path"]
        )
        Assert-Exact (
            $path.StartsWith(
                $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Get-RawSha256 -Path $path) -ceq
                [string]$cellAttempt["${artifactName}_raw_sha256"]
        ) "$gateId cell $artifactName changed: $($cellAttempt.cell_id)"
    }
}

Assert-Exact (
    -not [bool]$evaluation.ok -and
    [int]$evaluation.reconstructed_passed_gate_count -eq 21 -and
    [int]$evaluation.reconstructed_failed_gate_count -eq 29 -and
    @($evaluation.gates).Count -eq 50 -and
    @($evaluation.gates | Where-Object { -not [bool]$_.passed }).Count -eq 29 -and
    @($evaluation.failure_codes) -join "," -ceq
        "BW22L_CELL_GATE,BW22L_CANDIDATE_OUTCOME_METRICS" -and
    [string]$evaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$evaluation.development_selection_authority -and
    -not [bool]$evaluation.physical_acceptance_authority
) "$gateId frozen evaluation changed"

Assert-Exact (
    [string]$rawResult.campaign_id -ceq $campaignId -and
    [string]$rawResult.source.commit -ceq $sourceCommit -and
    [int]$rawResult.expected_gate_count -eq 50 -and
    [int]$rawResult.expected_world_count -eq 28 -and
    [int]$rawResult.observed_world_count -eq 28 -and
    [int]$rawResult.integrity_failure_count -eq 0 -and
    @($rawResult.cells).Count -eq 28
) "$gateId retained raw result changed"
$nonSafety = @($rawResult.cells | Where-Object {
    [string]$_.role -cne "safety"
})
$safety = @($rawResult.cells | Where-Object {
    [string]$_.role -ceq "safety"
}) | Select-Object -First 1
Assert-Exact (
    $nonSafety.Count -eq 27 -and
    @($nonSafety | Where-Object {
        [int]$_.walking_gate_receipts.Count -ne 26
    }).Count -eq 0 -and
    @($rawResult.cells | Where-Object {
        $_.Contains("controller_coefficient")
    }).Count -eq 0 -and
    [bool]$safety.role_gate_passed -and
    [int]$safety.sdk_native_motor_write_count -eq 0 -and
    [int]$safety.sdk_effective_application_count -eq 0 -and
    -not [bool]$safety.physical_influence
) "$gateId retained receipt-shape diagnosis changed"

Assert-Exact (
    [string]$diagnostic.schema_version -ceq
        "sporespore_balanced_wave_bw22l_posthoc_receipt_shape_diagnostic_v1" -and
    [string]$diagnostic.classification -ceq
        "posthoc_diagnostic_only_not_a_reclassification_or_selection" -and
    -not [bool]$diagnostic.original_frozen_evaluation.ok -and
    [bool]$diagnostic.original_frozen_evaluation.result_remains_invalid -and
    [bool]$diagnostic.observed_receipt_composition_defects.synthetic_to_real_final_receipt_parity_defect -and
    [int]$diagnostic.observed_receipt_composition_defects.every_cell_missing_controller_coefficient_count -eq 28 -and
    [int]$diagnostic.observed_receipt_composition_defects.safety_receipt_missing_required_common_field_count -eq 9 -and
    [bool]$diagnostic.reconstructed_prospective_schema_diagnostic.ok_under_in_memory_receipt_shape_reconstruction -and
    [int]$diagnostic.reconstructed_prospective_schema_diagnostic.passed_gate_count -eq 50 -and
    [string]$diagnostic.reconstructed_prospective_schema_diagnostic.selector_output -ceq "NONE" -and
    [int]$diagnostic.reconstructed_prospective_schema_diagnostic.successor_paired_walking_gate_regression_count -eq 4 -and
    -not [bool]$diagnostic.reconstructed_prospective_schema_diagnostic.development_selection_authority -and
    [bool]$diagnostic.immutability.bw22l_status_remains_invalid_development_execution -and
    -not [bool]$diagnostic.immutability.bw22l_reclassified
) "$gateId retained posthoc diagnostic changed"

Assert-Exact (
    (Get-RawSha256 -Path $compilerPath) -ceq
        [string]$closure.posthoc_receipt_shape_diagnostic.compiler_raw_sha256
) "$gateId posthoc compiler changed"
$temporaryDiagnostic = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("bw22l-posthoc-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
    $compilerOutput = (& pwsh `
        -NoLogo `
        -NoProfile `
        -File $compilerPath `
        -RawResultPath (Join-Path $evidenceRoot "raw-result.json") `
        -OutputPath $temporaryDiagnostic 2>&1 | Out-String)
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $compilerOutput.Contains(
            "BW22L_POSTHOC_RECEIPT_DIAGNOSTIC_PASS",
            [StringComparison]::Ordinal
        ) -and
        (Get-RawSha256 -Path $temporaryDiagnostic) -ceq
            [string]$closure.retained_evidence.posthoc_receipt_shape_diagnostic.raw_sha256
    ) "$gateId posthoc diagnostic is not byte reproducible"
} finally {
    if (Test-Path -LiteralPath $temporaryDiagnostic -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryDiagnostic -Force
    }
}

foreach ($claim in $closure.claim_boundary.Keys) {
    Assert-Exact (
        -not [bool]$closure.claim_boundary[$claim]
    ) "$gateId unsupported closure claim became true: $claim"
}
Assert-Exact (
    [bool]$closure.immutability.first_complete_result_is_final_for_source_identity -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_selection_forbidden -and
    [bool]$closure.immutability.posthoc_reclassification_forbidden -and
    [bool]$closure.successor_requirements.real_shaped_candidate_control_and_safety_receipts_must_traverse_the_complete_production_evaluator_before_physics -and
    [bool]$closure.successor_requirements.negative_walking_outcome_receipt_must_pass_execution_integrity_while_remaining_a_physical_failure -and
    [bool]$closure.successor_requirements.fresh_unexposed_material_values_and_seeds_required_for_any_authoritative_selection -and
    [bool]$closure.successor_requirements.bw22l_b_may_not_be_promoted_or_retested_as_the_selected_successor
) "$gateId immutability or successor boundary changed"

$rerunOutputRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("bw22l-closure-rerun-" + [Guid]::NewGuid().ToString("N"))
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
    "BW22L LATERAL_DEVELOPMENT_CLOSURE_PASS status=infrastructure-invalid " +
    "worlds=28 parsed=28 process_failures=0 gates=21/50 cell_gates=0/28 " +
    "receipt_shape_defects=3 reconstructed=50/50 diagnostic_selector=NONE " +
    "paired_regressions=4 selection_authority=False validation_authority=False " +
    "physical_authority=False rerun_refused=True"
)
