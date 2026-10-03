#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$preregistrationPath = Join-Path $repoRoot (
    "sdk\turning\r23d44_rapier_paired_startup_transform_preregistration_v1.json"
)
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d44_rapier_paired_startup_transform_implementation_v1.json"
)
$manifestPath = Join-Path $repoRoot (
    "sdk\turning\r23d44_campaign_attestation_manifest_v1.json"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d44_rapier_paired_startup_transform_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d44_closure.ps1"

function Assert-R23D44Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D44 RELEASE MATRIX: $Message" }
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
Assert-R23D44Release ($gate.Count -eq 1) "QSDK-R23 gate count changed"
$proof = $gate[0].proof
$record = $proof.closed_r23d44_attempt
$status = (
    "r23d44_closed_consumed_valid_complete_ramp_induced_turning_gate_" +
    "regression_at_outcome_exposed_seed_21504_no_production_selection_" +
    "physical_series_paused"
)

Assert-R23D44Release (
    [string]$proof.kind -ceq "missing" -and
    [string]$proof.current_prospective_successor_status -ceq $status -and
    [string]$record.status -ceq
        "closed_consumed_valid_complete_ramp_induced_turning_gate_regression_at_seed_21504" -and
    [string]$record.preregistration_raw_sha256 -ceq
        (Get-Sha256 $preregistrationPath) -and
    [string]$record.implementation_raw_sha256 -ceq
        (Get-Sha256 $implementationPath) -and
    [string]$record.campaign_attestation_manifest_raw_sha256 -ceq
        (Get-Sha256 $manifestPath) -and
    [string]$record.closure_path -ceq
        "sdk/turning/r23d44_rapier_paired_startup_transform_closure_v1.json" -and
    [string]$record.closure_raw_sha256 -ceq (Get-Sha256 $closurePath) -and
    [string]$record.closure_audit_raw_sha256 -ceq
        (Get-Sha256 $closureAuditPath) -and
    [string]$record.release_matrix_audit_raw_sha256 -ceq
        (Get-Sha256 $PSCommandPath) -and
    [string]$record.physical_source_commit -ceq
        "a3e76a1bebb5a1a6bc57b024b4de78946c92e07a" -and
    [string]$record.attempt_id -ceq "9816e0ef545340c7bb0030bed18ecc33" -and
    [int]$record.outcome_exposed_seed -eq 21504 -and
    (@($record.declared_engine_ids) -join "|") -ceq "rapier_parry" -and
    [int]$record.declared_world_count -eq 6 -and
    [int]$record.controller_or_physics_change_count -eq 0 -and
    [int]$record.startup_transform_candidate_count -eq 2 -and
    [bool]$record.production_retention_canary_passed -and
    [int]$record.production_retention_canary_trace_count -eq 2 -and
    [int]$record.production_retention_canary_trace_row_count -eq 5984 -and
    [int]$record.production_retention_canary_world_count -eq 0 -and
    [int]$record.same_file_positive_control_count -eq 2 -and
    [int]$record.wrong_existing_file_rejection_count -eq 1 -and
    [int]$record.qualification_gate_count -eq 17 -and
    [int]$record.qualification_world_count -eq 0 -and
    [int]$record.production_authorization_pass_count -eq 6 -and
    [bool]$record.physical_attempt_completed -and
    [int]$record.world_attempt_count -eq 6 -and
    [int]$record.world_build_count -eq 6 -and
    [int]$record.execution_valid_cell_count -eq 6 -and
    [int]$record.common_physical_gate_pass_count -eq 6 -and
    [int]$record.retained_production_trace_count -eq 6 -and
    [bool]$record.no_ramp_all_common_walking_gates_passed -and
    [bool]$record.ramp_all_common_walking_gates_passed -and
    [bool]$record.no_ramp_full_three_arm_turning_gate_passed -and
    -not [bool]$record.ramp_full_three_arm_turning_gate_passed -and
    [Math]::Abs(
        [double]$record.no_ramp_positive_reference_conditioned_cycle_shift_rad -
        0.010030533017876247
    ) -le 1.0e-12 -and
    [Math]::Abs(
        [double]$record.ramp_positive_reference_conditioned_cycle_shift_rad -
        0.005445810376779353
    ) -le 1.0e-12 -and
    [string]$record.official_classification -ceq
        "valid_complete_ramp_induced_turning_gate_regression_at_seed_21504" -and
    [bool]$record.paired_same_seed_startup_transform_effect_characterized -and
    -not [bool]$record.fresh_or_held_out_condition_consumed -and
    -not [bool]$record.candidate_selection_invoked -and
    [bool]$record.one_shot_identity_consumed -and
    -not [bool]$record.same_identity_rerun_allowed -and
    -not [bool]$record.successor_campaign_opened -and
    [bool]$record.physical_series_paused_before_successor -and
    -not [bool]$record.finite_rapier_turning_validation -and
    -not [bool]$record.portable_basic_turning -and
    -not [bool]$record.finite_three_engine_turning -and
    -not [bool]$record.cross_engine_equivalence -and
    -not [bool]$record.q_sdk_r23_satisfied -and
    -not [bool]$record.release_authorized -and
    -not [bool]$record.physical_acceptance_authority
) "closed release record changed"

Assert-R23D44Release (
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D44-RAPIER-PAIRED-STARTUP-TRANSFORM-DEVELOPMENT"'
    ).Count -eq 1 -and
    $supportJson.Contains('"current_prospective_successor_status": "' + $status + '"') -and
    $supportJson.Contains('"production_retention_canary_trace_row_count": 5984') -and
    $supportJson.Contains('"execution_valid_cell_count": 6') -and
    $supportJson.Contains('"no_ramp_full_three_arm_turning_gate_passed": true') -and
    $supportJson.Contains('"ramp_full_three_arm_turning_gate_passed": false') -and
    $supportJson.Contains('"paired_same_seed_startup_transform_effect_characterized": true') -and
    $supportJson.Contains('"finite_rapier_turning_validation": false')
) "support-matrix R44 record changed"

Write-Host (
    "QSDK_R23D44_RELEASE_MATRIX_PASS closed=True seed=21504 worlds=6 " +
    "traces=6 both_walk=True control_turning=True ramp_turning=False " +
    "validation=False release=False paused=True"
)
