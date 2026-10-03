#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$resultPath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_run1_result.json"
$freezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze.json"
$sourceCommit = "5a7d576a47e3e9232928fdbd07c2c359959edaff"
$freezeSha256 = "19d46d3ac1237f7f483f14d8e4f70de7375fa0919232b6900d91f1e46de2f4e2"
$attestationPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-5a7d576a-20260804T223946Z\attestation.json"
)

function Assert-Drp1Run1 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Drp1Run1RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Assert-Drp1Run1 (
    (Test-Path -LiteralPath $resultPath -PathType Leaf) -and
    (Test-Path -LiteralPath $freezePath -PathType Leaf) -and
    (Get-Drp1Run1RawSha256 -Path $freezePath) -ceq $freezeSha256
) "DRP1 run-one result or executed freeze is missing or changed"

git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
$sourceIsAncestor = $LASTEXITCODE -eq 0
Assert-Drp1Run1 (
    $sourceIsAncestor -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "DRP1 run-one source is missing from repository history"

$result = Get-Content -Raw -LiteralPath $resultPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$execution = [System.Collections.IDictionary]$result.execution
$evaluation = [System.Collections.IDictionary]$result.evaluation
$diagnosis = [System.Collections.IDictionary]$result.mechanism_diagnosis
$successor = [System.Collections.IDictionary]$result.successor_requirements

Assert-Drp1Run1 (
    [string]$result.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_run_result_v1" -and
    [string]$result.status -ceq
        "complete_repeatable_regression_run_invalid_nested_route_schema" -and
    [string]$result.regression_id -ceq
        "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1" -and
    [string]$result.gate_id -ceq "DRP1" -and
    [string]$result.run_id -ceq "DRP1-RUN-1-5a7d576a-20260804T223946Z" -and
    [string]$result.source_commit -ceq $sourceCommit -and
    [bool]$result.source_was_clean_pushed_and_equal_to_live_github_main -and
    [string]$result.stage_one_freeze.raw_sha256 -ceq $freezeSha256
) "DRP1 run-one result identity changed"

Assert-Drp1Run1 (
    [bool]$execution.full_godot_conformance -and
    [int]$execution.top_level_exit_code -eq 1 -and
    [double]$execution.top_level_duration_seconds -eq 3250.9 -and
    [bool]$execution.global_operation_lock_released -and
    [int]$execution.expected_regression_world_count -eq 24 -and
    [int]$execution.regression_world_build_count -eq 24 -and
    [int]$execution.dynamic_receipt_count -eq 24 -and
    [int]$execution.worker_exit_code_count -eq 24 -and
    [bool]$execution.all_cells_present_in_exact_declared_order -and
    [bool]$execution.complete_evaluator_executed -and
    -not [bool]$execution.complete_regression_passed -and
    [bool]$execution.ordinary_repeatable_regression_test_physics -and
    -not [bool]$execution.scientific_campaign -and
    -not [bool]$execution.one_shot_identity_consumed -and
    -not [bool]$execution.scientific_evidence_retained -and
    [int]$execution.cell_retry_or_replacement_count -eq 0
) "DRP1 run-one execution result changed"

$expectedPassed = @(
    "exact_noncampaign_identity",
    "exact_matrix_cardinality_and_order",
    "route_identity_projection",
    "candidate_authority_horizon",
    "pre_authority_exclusion",
    "challenge_realization",
    "measurement_acquisition",
    "candidate_application",
    "all_scientific_and_release_claims_false"
)
$expectedFailed = @(
    "shared_final_receipt_schema",
    "outcome_complete",
    "common_execution_integrity"
)
Assert-Drp1Run1 (
    [int]$evaluation.expected_gate_count -eq 12 -and
    [int]$evaluation.passed_gate_count -eq 9 -and
    [int]$evaluation.failed_gate_count -eq 3 -and
    (@($evaluation.passed_gate_ids) -join "|") -ceq ($expectedPassed -join "|") -and
    (@($evaluation.failed_gate_ids) -join "|") -ceq ($expectedFailed -join "|") -and
    $null -eq $evaluation.walking_observed_count_descriptive_only -and
    -not [bool]$evaluation.walking_count_used_by_evaluator -and
    -not [bool]$evaluation.candidate_or_policy_selected
) "DRP1 run-one frozen evaluator result changed"

Assert-Drp1Run1 (
    -not [bool]$result.attestation.published -and
    -not [bool]$result.attestation.parent_directory_created -and
    [bool]$result.attestation.publication_refused_after_conformance_failure -and
    -not (Test-Path -LiteralPath $attestationPath)
) "DRP1 run-one unexpectedly gained an attestation artifact"

$commonSource = @(
    git -C $repoRoot show "${sourceCommit}:scripts/lab/gait/sdk_drp1_worker_common.gd"
) -join "`n"
$physicalSource = @(
    git -C $repoRoot show "${sourceCommit}:scripts/lab/gait/physical_wave_gait_quadruped.gd"
) -join "`n"
$successorSource = @(
    git -C $repoRoot show "${sourceCommit}:tests/test_sdk_drp1_successor_worker.gd"
) -join "`n"
Assert-Drp1Run1 (
    $commonSource.Contains(
        '"sdk_stability_overlay_evidence_actuation"',
        [StringComparison]::Ordinal
    ) -and
    -not $commonSource.Contains(
        '"native_sdk_exclusive_post_settle_actuation"',
        [StringComparison]::Ordinal
    ) -and
    $commonSource.Contains(
        "walking_receipt_structurally_complete(walking_receipts)",
        [StringComparison]::Ordinal
    ) -and
    $physicalSource.Contains(
        'walking_gate_receipts["sdk_stability_overlay_evidence_actuation"]',
        [StringComparison]::Ordinal
    ) -and
    $physicalSource.Contains(
        'walking_gate_receipts["native_sdk_exclusive_post_settle_actuation"]',
        [StringComparison]::Ordinal
    ) -and
    $successorSource.Contains(
        "Drp1Common.compose_final_receipt(ROUTE_ID, cell, summary, {})",
        [StringComparison]::Ordinal
    )
) "DRP1 run-one source mechanism witness changed"

Assert-Drp1Run1 (
    [string]$diagnosis.classification -ceq
        "source_proven_nested_route_schema_overconstraint" -and
    -not [bool]$diagnosis.retained_per_cell_diagnostic_receipts_available -and
    [string]$diagnosis.shared_contract_required_one_actuation_key_for_both_routes -ceq
        "sdk_stability_overlay_evidence_actuation" -and
    [string]$diagnosis.successor_runtime_actuation_key -ceq
        "native_sdk_exclusive_post_settle_actuation" -and
    [bool]$diagnosis.successor_runtime_key_was_absent_from_shared_nested_schema -and
    [bool]$diagnosis.shared_overlay_key_was_absent_from_successor_runtime_receipts -and
    [bool]$diagnosis.schema_failure_forces_outcome_complete_false -and
    [bool]$diagnosis.outcome_failure_forces_common_integrity_false -and
    [bool]$diagnosis.common_integrity_failure_forces_worker_nonzero_exit -and
    [bool]$diagnosis.observed_failed_gate_triad_is_fully_explained -and
    -not [bool]$diagnosis.original_bw31n_identity_challenge_and_application_escape_reproduced
) "DRP1 run-one diagnosis or inference boundary changed"

Assert-Drp1Run1 (
    [bool]$successor.preserve_run1_source_freeze_and_result -and
    [bool]$successor.route_specific_nested_walking_receipt_schemas_required -and
    [bool]$successor.outer_final_receipt_schema_must_remain_shared -and
    [bool]$successor.zero_world_gate_must_reject_cross_route_nested_schema_substitution -and
    [bool]$successor.fresh_clean_pushed_source_freeze_required_before_rerun -and
    [bool]$successor.same_repeatable_regression_id_may_rerun_after_new_freeze -and
    [bool]$successor.fresh_validation_seed_use_forbidden
) "DRP1 run-one successor requirements changed"

foreach ($entry in $result.claim_boundary.GetEnumerator()) {
    Assert-Drp1Run1 (-not [bool]$entry.Value) (
        "DRP1 run-one claim inflated: $($entry.Key)"
    )
}

Write-Host (
    "DRP1_RUN1_RESULT_PASS status=invalid worlds=24 receipts=24 gates=9/12 " +
    "failed=shared_final_receipt_schema,outcome_complete,common_execution_integrity " +
    "mechanism=route_specific_nested_actuation_key_overconstraint attestation=False " +
    "rerunnable_after_new_freeze=True walking_authority=False selection_authority=False " +
    "physical_authority=False"
)
