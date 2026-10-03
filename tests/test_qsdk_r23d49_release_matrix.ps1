#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"

function Assert-R23D49Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D49 RELEASE MATRIX: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

$release = Get-Content -Raw -LiteralPath $releasePath |
    ConvertFrom-Json -Depth 100
$supportJson = Get-Content -Raw -LiteralPath $supportPath
$gate = @($release.gates | Where-Object gate_id -ceq "QSDK-R23")
Assert-R23D49Release ($gate.Count -eq 1) "QSDK-R23 gate count changed"
$proof = $gate[0].proof
$r49 = $proof.closed_r23d49_attempt
$status = (
    "r23d49_closed_consumed_invalid_complete_path_identity_false_negative_" +
    "bypass_retention_observed_diagnostic_walking_and_turning_only_no_" +
    "successor_series_paused"
)

Assert-R23D49Release (
    [string]$proof.kind -ceq "missing" -and
    [string]$proof.current_successor_status -ceq $status -and
    [string]$proof.current_prospective_successor_status -ceq $status
) "current QSDK-R23 boundary changed"

Assert-R23D49Release (
    [string]$r49.gate_id -ceq "QSDK-R23D49" -and
    [string]$r49.campaign_id -ceq
        "QSDK-R23D49-RAPIER-RETENTION-REPAIR-REPLAY" -and
    [string]$r49.status -ceq
        "closed_consumed_invalid_complete_evaluator_windows_namespace_path_identity_false_negative_with_successful_production_trace_retention" -and
    [string]$r49.study_classification -ceq
        "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay" -and
    [string]$r49.preregistration_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r49.preregistration_path)
    )) -and
    [string]$r49.implementation_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r49.implementation_path)
    )) -and
    [string]$r49.campaign_attestation_manifest_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r49.campaign_attestation_manifest_path)
    )) -and
    [string]$r49.closure_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r49.closure_path)
    )) -and
    [string]$r49.closure_audit_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r49.closure_audit_path)
    )) -and
    [string]$r49.release_matrix_audit_raw_sha256 -ceq
        (Get-Sha256 $PSCommandPath) -and
    [string]$r49.diagnostic_source_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r49.diagnostic_source_path)
    )) -and
    [string]$r49.physical_source_commit -ceq
        "5f79f244e517dd7d2cd55164d1db92cd5eb9d638" -and
    [string]$r49.physical_source_tree_git_oid -ceq
        "f2c698231c5ccbb0bc48579ce8392010dfa412d2" -and
    [string]$r49.attempt_id -ceq "6a96746105324921bdbcdc8c8e8bd3fd" -and
    (@($r49.declared_engine_ids) -join "|") -ceq "rapier_parry" -and
    [int]$r49.outcome_exposed_seed -eq 21512 -and
    -not [bool]$r49.fresh_held_out_condition -and
    [int]$r49.declared_world_count -eq 3 -and
    [int]$r49.qualification_gate_count -eq 17 -and
    [int]$r49.qualification_world_count -eq 0 -and
    -not [bool]$r49.historical_full_suite_rerun -and
    [bool]$r49.production_retention_canary_passed -and
    [int]$r49.production_retention_canary_trace_row_count -eq 2992 -and
    -not [bool]$r49.canary_exercised_complete_evaluator_cas_binding -and
    [int]$r49.world_attempt_count -eq 3 -and
    [int]$r49.world_build_count -eq 3 -and
    [int]$r49.process_exit_zero_count -eq 3 -and
    [int]$r49.production_trace_retention_count -eq 3 -and
    [int]$r49.official_execution_valid_cell_count -eq 0 -and
    [int]$r49.official_path_identity_false_negative_count -eq 3 -and
    [string]$r49.official_classification -ceq
        "invalid_or_incomplete_outcome_exposed_rapier_retention_repair_replay" -and
    [string]$r49.failure_mechanism -ceq
        "frozen_evaluator_compared_extended_and_ordinary_Windows_CAS_paths_by_text_instead_of_existing_file_identity" -and
    [bool]$r49.all_recorded_paths_identify_expected_files -and
    [bool]$r49.process_scoped_bypass_publication_route_observed_successfully -and
    [int]$r49.post_failure_diagnostic_execution_valid_cell_count -eq 3 -and
    [int]$r49.post_failure_diagnostic_common_physical_gate_pass_count -eq 3 -and
    [bool]$r49.post_failure_diagnostic_turning_passed -and
    -not [bool]$r49.post_failure_diagnostic_creates_claim -and
    [bool]$r49.one_shot_identity_consumed -and
    -not [bool]$r49.same_identity_rerun_allowed -and
    -not [bool]$r49.successor_campaign_opened -and
    [bool]$r49.physical_series_paused_before_successor -and
    -not [bool]$r49.finite_rapier_turning_from_r23d49 -and
    -not [bool]$r49.finite_three_engine_turning -and
    -not [bool]$r49.portable_basic_turning -and
    -not [bool]$r49.cross_engine_equivalence -and
    -not [bool]$r49.q_sdk_r23_satisfied -and
    -not [bool]$r49.release_authorized -and
    -not [bool]$r49.physical_acceptance_authority
) "R49 release record changed"

Assert-R23D49Release (
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D49-RAPIER-RETENTION-REPAIR-REPLAY"'
    ).Count -eq 1 -and
    $supportJson.Contains(
        '"current_prospective_successor_status": "' + $status + '"'
    ) -and
    $supportJson.Contains('"official_path_identity_false_negative_count": 3') -and
    $supportJson.Contains('"production_trace_retention_count": 3') -and
    $supportJson.Contains('"post_failure_diagnostic_turning_passed": true') -and
    $supportJson.Contains('"post_failure_diagnostic_creates_claim": false') -and
    $supportJson.Contains('"finite_three_engine_turning": false') -and
    $supportJson.Contains('"q_sdk_r23_satisfied": false')
) "support-matrix R49 boundary changed"

Write-Host (
    "QSDK_R23D49_RELEASE_MATRIX_PASS official=invalid_complete worlds=3 " +
    "traces=3 path_false_negatives=3 diagnostic_turning=True " +
    "official_rapier_claim=False three_engine=False release=False paused=True"
)
