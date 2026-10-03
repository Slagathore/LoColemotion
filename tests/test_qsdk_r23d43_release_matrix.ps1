#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$preregistrationPath = Join-Path $repoRoot (
    "sdk\turning\r23d43_rapier_retention_hardened_turning_preregistration_v1.json"
)
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d43_rapier_retention_hardened_turning_implementation_v1.json"
)
$manifestPath = Join-Path $repoRoot (
    "sdk\turning\r23d43_campaign_attestation_manifest_v1.json"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d43_rapier_retention_hardened_turning_closure_v1.json"
)

function Assert-R23D43Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D43 RELEASE MATRIX: $Message" }
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
Assert-R23D43Release ($gate.Count -eq 1) "QSDK-R23 gate count changed"
$proof = $gate[0].proof
$record = $proof.prospective_r23d43_attempt
$supportStatusMatches = [regex]::Matches(
    $supportJson,
    '"current_prospective_successor_status"\s*:\s*"([^"]+)"'
)
Assert-R23D43Release ($supportStatusMatches.Count -eq 1) (
    "support current prospective status count changed"
)
$supportStatus = $supportStatusMatches[0].Groups[1].Value

Assert-R23D43Release (
    [string]$proof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$proof.current_prospective_successor_status
    ) -and
    [string]$proof.current_prospective_successor_status -ceq $supportStatus -and
    [string]$record.status -ceq
        "closed_consumed_implementation_invalid_windows_extended_path_cas_verifier" -and
    [string]$record.preregistration_raw_sha256 -ceq
        (Get-Sha256 $preregistrationPath) -and
    [string]$record.implementation_raw_sha256 -ceq
        (Get-Sha256 $implementationPath) -and
    [string]$record.campaign_attestation_manifest_raw_sha256 -ceq
        (Get-Sha256 $manifestPath) -and
    [string]$record.closure_path -ceq
        "sdk/turning/r23d43_rapier_retention_hardened_turning_closure_v1.json" -and
    [string]$record.closure_raw_sha256 -ceq (Get-Sha256 $closurePath) -and
    [string]$record.physical_source_commit -ceq
        "0fe05a4e761615113e858fd015eef6ece3cd0b00" -and
    [string]$record.attempt_id -ceq "89c3834f91b147e9a2f46000a7f09034" -and
    [int]$record.fresh_seed -eq 21511 -and
    (@($record.declared_engine_ids) -join "|") -ceq "rapier_parry" -and
    [int]$record.declared_world_count -eq 3 -and
    [int]$record.controller_or_physics_change_count -eq 0 -and
    [int]$record.evidence_implementation_change_count -eq 5 -and
    [bool]$record.worker_and_evaluator_zero_world_green -and
    [bool]$record.materialized_source_test_only_trace_cas_green -and
    [bool]$record.production_retention_canary_required_before_first_world -and
    [bool]$record.production_retention_canary_passed -and
    [int]$record.production_retention_canary_trace_row_count -eq 2992 -and
    [int]$record.production_retention_canary_world_count -eq 0 -and
    [int]$record.production_authorization_pass_count -eq 3 -and
    [bool]$record.physical_attempt_completed -and
    [int]$record.world_attempt_count -eq 3 -and
    [int]$record.world_build_count -eq 3 -and
    [int]$record.retained_production_trace_count -eq 3 -and
    [string]$record.official_classification -ceq
        "invalid_or_incomplete_finite_rapier_turning_replication" -and
    [int]$record.official_path_verifier_failure_count -eq 3 -and
    [string]$record.official_failed_gate_id -ceq
        "R23D42_TRACE_ARTIFACT_CAS_PATH" -and
    [bool]$record.production_trace_publication_succeeded -and
    [bool]$record.posthoc_all_common_walking_gates_passed -and
    -not [bool]$record.posthoc_turning_passed -and
    [Math]::Abs(
        [double]$record.posthoc_positive_reference_conditioned_cycle_shift_rad -
        0.005927633920819846
    ) -le 1.0e-12 -and
    -not [bool]$record.posthoc_creates_physical_claim -and
    [bool]$record.one_shot_identity_consumed -and
    -not [bool]$record.successor_campaign_opened -and
    [bool]$record.physical_series_paused_before_successor -and
    -not [bool]$record.finite_rapier_turning_replication -and
    -not [bool]$record.portable_basic_turning -and
    -not [bool]$record.cross_engine_equivalence -and
    -not [bool]$record.q_sdk_r23_satisfied -and
    -not [bool]$record.release_authorized -and
    -not [bool]$record.physical_acceptance_authority
) "prospective release record changed"

Assert-R23D43Release (
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D43-RAPIER-RETENTION-HARDENED-TURNING-REPLICATION"'
    ).Count -eq 1 -and
    $supportJson.Contains('"production_retention_canary_trace_row_count": 2992') -and
    $supportJson.Contains('"official_path_verifier_failure_count": 3') -and
    $supportJson.Contains('"posthoc_all_common_walking_gates_passed": true') -and
    $supportJson.Contains('"finite_rapier_turning_replication": false')
) "support-matrix R43 record changed"

Write-Host (
    "QSDK_R23D43_RELEASE_MATRIX_PASS closed=True seed=21511 worlds=3 " +
    "traces=3 verifier_failures=3 posthoc_walking=True " +
    "turning=False release=False paused=True"
)
