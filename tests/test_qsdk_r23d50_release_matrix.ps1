#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"

function Assert-R23D50Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D50 RELEASE MATRIX: $Message" }
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
Assert-R23D50Release ($gate.Count -eq 1) "QSDK-R23 gate count changed"
$proof = $gate[0].proof
$r50 = $proof.closed_r23d50_attempt
$status = (
    "r23d50_closed_consumed_valid_complete_positive_outcome_exposed_" +
    "rapier_cas_path_identity_replay_three_engine_turning_still_missing_" +
    "series_paused"
)

Assert-R23D50Release (
    [string]$proof.kind -ceq "missing" -and
    [string]$proof.current_successor_status -ceq $status -and
    [string]$proof.current_prospective_successor_status -ceq $status
) "current QSDK-R23 boundary changed"

Assert-R23D50Release (
    [string]$r50.gate_id -ceq "QSDK-R23D50" -and
    [string]$r50.campaign_id -ceq
        "QSDK-R23D50-RAPIER-CAS-PATH-IDENTITY-REPLAY" -and
    [string]$r50.status -ceq
        "closed_consumed_valid_complete_positive_outcome_exposed_rapier_cas_path_identity_replay" -and
    [string]$r50.study_classification -ceq
        "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay" -and
    [string]$r50.preregistration_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r50.preregistration_path)
    )) -and
    [string]$r50.implementation_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r50.implementation_path)
    )) -and
    [string]$r50.campaign_attestation_manifest_raw_sha256 -ceq
        (Get-Sha256 (Join-Path $repoRoot (
            [string]$r50.campaign_attestation_manifest_path
        ))) -and
    [string]$r50.prephysical_incident_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r50.prephysical_incident_path)
    )) -and
    [string]$r50.closure_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r50.closure_path)
    )) -and
    [string]$r50.closure_audit_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r50.closure_audit_path)
    )) -and
    [string]$r50.release_matrix_audit_raw_sha256 -ceq
        (Get-Sha256 $PSCommandPath) -and
    [string]$r50.physical_source_commit -ceq
        "4908b3ed2d228897fa1b15a1adcac5a0881b93b1" -and
    [string]$r50.physical_source_tree_git_oid -ceq
        "ad62e25daf1ef65f42a5886be9a2037b8ecc08b1" -and
    [string]$r50.attempt_id -ceq "af5e516c258f4317b142b4746eaa30cf" -and
    (@($r50.declared_engine_ids) -join "|") -ceq "rapier_parry" -and
    [int]$r50.outcome_exposed_seed -eq 21512 -and
    -not [bool]$r50.fresh_held_out_condition -and
    [int]$r50.declared_world_count -eq 3 -and
    [int]$r50.qualification_gate_count -eq 17 -and
    [int]$r50.qualification_world_count -eq 0 -and
    -not [bool]$r50.historical_full_suite_rerun -and
    [int]$r50.prephysical_incident_world_count -eq 0 -and
    -not [bool]$r50.prephysical_incident_consumed_identity -and
    [bool]$r50.production_retention_canary_passed -and
    [int]$r50.production_retention_canary_trace_row_count -eq 2992 -and
    [bool]$r50.canary_exercised_complete_evaluator_cas_binding -and
    [int]$r50.same_file_positive_control_count -eq 1 -and
    [int]$r50.wrong_existing_file_rejection_count -eq 1 -and
    [int]$r50.world_attempt_count -eq 3 -and
    [int]$r50.world_build_count -eq 3 -and
    [int]$r50.process_exit_zero_count -eq 3 -and
    [int]$r50.production_trace_retention_count -eq 3 -and
    [int]$r50.official_execution_valid_cell_count -eq 3 -and
    [int]$r50.common_physical_gate_pass_count -eq 3 -and
    [string]$r50.official_classification -ceq
        "valid_complete_positive_outcome_exposed_rapier_cas_path_identity_replay" -and
    [bool]$r50.official_turning_measurement_passed -and
    [bool]$r50.repaired_cas_path_identity_route_observed_successfully -and
    [bool]$r50.one_shot_identity_consumed -and
    -not [bool]$r50.same_identity_rerun_allowed -and
    -not [bool]$r50.successor_campaign_opened -and
    [bool]$r50.physical_series_paused_before_successor -and
    [bool]$r50.finite_outcome_exposed_rapier_cas_path_identity_replay -and
    -not [bool]$r50.fresh_rapier_turning_replication -and
    -not [bool]$r50.finite_three_engine_turning -and
    -not [bool]$r50.portable_basic_turning -and
    -not [bool]$r50.cross_engine_equivalence -and
    -not [bool]$r50.q_sdk_r23_satisfied -and
    -not [bool]$r50.release_authorized -and
    -not [bool]$r50.physical_acceptance_authority
) "R50 release record changed"

Assert-R23D50Release (
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D50-RAPIER-CAS-PATH-IDENTITY-REPLAY"'
    ).Count -eq 1 -and
    $supportJson.Contains(
        '"current_prospective_successor_status": "' + $status + '"'
    ) -and
    $supportJson.Contains('"canary_exercised_complete_evaluator_cas_binding": true') -and
    $supportJson.Contains('"official_execution_valid_cell_count": 3') -and
    $supportJson.Contains('"official_turning_measurement_passed": true') -and
    $supportJson.Contains('"finite_outcome_exposed_rapier_cas_path_identity_replay": true') -and
    $supportJson.Contains('"fresh_rapier_turning_replication": false') -and
    $supportJson.Contains('"finite_three_engine_turning": false') -and
    $supportJson.Contains('"q_sdk_r23_satisfied": false')
) "support-matrix R50 boundary changed"

Write-Host (
    "QSDK_R23D50_RELEASE_MATRIX_PASS official=positive_exposed_replay " +
    "worlds=3 walking=3 turning=True fresh=False three_engine=False " +
    "release=False paused=True"
)
