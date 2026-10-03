#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$resultPath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_run2_result.json"
$freezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"
$sourceCommit = "5d7b45029a2bbf3e5bcc57c8774db15215fcdccf"
$freezeSha256 = "13dc2eeff72915551f126dabdba844cceee5f88aaaecf7932b6b1ad028e5fac6"
$attestationPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-5d7b4502-20260805T000446Z\attestation.json"
)

function Assert-Drp1Run2 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Drp1Run2RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-Drp1Run2GitText {
    param([Parameter(Mandatory)][string]$RelativePath)
    $lines = @(git -C $repoRoot show "${sourceCommit}:$RelativePath")
    Assert-Drp1Run2 ($LASTEXITCODE -eq 0) (
        "DRP1 run-two source blob is missing: $RelativePath"
    )
    return ($lines -join "`n")
}

Assert-Drp1Run2 (
    (Test-Path -LiteralPath $resultPath -PathType Leaf) -and
    (Test-Path -LiteralPath $freezePath -PathType Leaf) -and
    (Get-Drp1Run2RawSha256 -Path $freezePath) -ceq $freezeSha256
) "DRP1 run-two result or executed revision-two freeze is missing or changed"

git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
$sourceIsAncestor = $LASTEXITCODE -eq 0
Assert-Drp1Run2 (
    $sourceIsAncestor -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "DRP1 run-two source is missing from repository history"

$result = Get-Content -Raw -LiteralPath $resultPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$execution = [System.Collections.IDictionary]$result.execution
$failure = [System.Collections.IDictionary]$result.failure
$successor = [System.Collections.IDictionary]$result.successor_requirements

Assert-Drp1Run2 (
    [string]$result.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_run_result_v1" -and
    [string]$result.status -ceq
        "full_conformance_regression_launch_invalid_freeze_schema_version_mismatch" -and
    [string]$result.regression_id -ceq
        "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1" -and
    [string]$result.gate_id -ceq "DRP1" -and
    [string]$result.run_id -ceq "DRP1-RUN-2-5d7b4502-20260805T000446Z" -and
    [string]$result.source_commit -ceq $sourceCommit -and
    [bool]$result.source_was_clean_pushed_and_equal_to_live_github_main -and
    [string]$result.revision_two_freeze.raw_sha256 -ceq $freezeSha256 -and
    [int]$result.revision_two_freeze.source_binding_count -eq 32 -and
    [bool]$result.revision_two_freeze.all_source_bindings_matched_after_run
) "DRP1 run-two result identity changed"

Assert-Drp1Run2 (
    [bool]$execution.full_godot_conformance_requested -and
    -not [bool]$execution.full_godot_conformance_completed -and
    [int]$execution.top_level_exit_code -eq 1 -and
    [double]$execution.top_level_duration_seconds -eq 956.7 -and
    [bool]$execution.global_operation_lock_released -and
    [bool]$execution.operation_lock_post_failure_probe_acquired -and
    -not [bool]$execution.operation_lock_post_failure_probe_abandoned_owner_recovered -and
    [bool]$execution.regression_launcher_invoked -and
    [bool]$execution.regression_launcher_rejected_before_ephemeral_authorization -and
    [int]$execution.expected_regression_world_count -eq 24 -and
    [int]$execution.regression_world_build_count -eq 0 -and
    [int]$execution.regression_physical_process_launch_count -eq 0 -and
    [int]$execution.dynamic_receipt_count -eq 0 -and
    [int]$execution.worker_exit_code_count -eq 0 -and
    -not [bool]$execution.complete_evaluator_executed -and
    -not [bool]$execution.complete_regression_passed -and
    [bool]$execution.ordinary_repeatable_regression_test_physics -and
    -not [bool]$execution.scientific_campaign -and
    -not [bool]$execution.one_shot_identity_consumed -and
    -not [bool]$execution.scientific_evidence_retained -and
    [int]$execution.fresh_validation_seed_use_count -eq 0
) "DRP1 run-two execution result changed"

$runnerSource = Get-Drp1Run2GitText `
    "sdk/run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
$freezeSource = Get-Drp1Run2GitText `
    "sdk/balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"
Assert-Drp1Run2 (
    $runnerSource.Contains(
        '"sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"',
        [StringComparison]::Ordinal
    ) -and
    $runnerSource.Contains(
        '"sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v1"',
        [StringComparison]::Ordinal
    ) -and
    $freezeSource.Contains(
        '"schema_version": "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v2"',
        [StringComparison]::Ordinal
    )
) "DRP1 run-two exact-source schema contradiction is not reproducible"

Assert-Drp1Run2 (
    [string]$failure.classification -ceq
        "source_proven_pre_world_launcher_contract_contradiction" -and
    [string]$failure.observed_exception -ceq
        "DRP1 stage-one freeze or source bindings changed" -and
    [string]$failure.observed_freeze_schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v2" -and
    [string]$failure.launcher_required_schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v1" -and
    -not [bool]$failure.schema_version_match -and
    [int]$failure.independent_post_run_source_binding_match_count -eq 32 -and
    [int]$failure.independent_post_run_source_binding_mismatch_count -eq 0 -and
    [bool]$failure.freeze_readiness_true -and
    -not [bool]$failure.standalone_regression_physics_authorized -and
    -not [bool]$failure.world_or_locomotion_outcome_exposed -and
    -not [bool]$failure.locomotion_negative -and
    -not [bool]$failure.scientific_result
) "DRP1 run-two failure mechanism or boundary changed"

Assert-Drp1Run2 (
    -not [bool]$result.attestation.published -and
    -not [bool]$result.attestation.parent_directory_created -and
    [bool]$result.attestation.publication_refused_after_conformance_failure -and
    -not (Test-Path -LiteralPath $attestationPath)
) "DRP1 run-two unexpectedly gained an attestation artifact"

Assert-Drp1Run2 (
    [bool]$successor.preserve_run2_source_freeze_and_result -and
    [bool]$successor.preserve_revision_two_route_specific_nested_schema -and
    [bool]$successor.launcher_must_select_and_accept_one_exact_new_freeze_schema -and
    [bool]$successor.worker_controller_evaluator_matrix_seed_and_threshold_changes_forbidden -and
    [bool]$successor.complete_zero_world_gate_required -and
    [bool]$successor.fresh_clean_pushed_source_freeze_required_before_rerun -and
    [bool]$successor.same_repeatable_regression_id_may_rerun_after_new_freeze -and
    [bool]$successor.fresh_validation_seed_use_forbidden
) "DRP1 run-two successor requirements changed"

foreach ($entry in $result.claim_boundary.GetEnumerator()) {
    Assert-Drp1Run2 (-not [bool]$entry.Value) (
        "DRP1 run-two claim inflated: $($entry.Key)"
    )
}

Write-Host (
    "DRP1_RUN2_RESULT_PASS status=infrastructure-invalid worlds=0 receipts=0 " +
    "workers=0 bindings=32/32 mismatch=freeze_v2_selected_schema_v1_required " +
    "attestation=False rerunnable_after_new_freeze=True locomotion_negative=False " +
    "walking_authority=False selection_authority=False physical_authority=False"
)
