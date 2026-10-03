#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"

function Assert-R23D48Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D48 RELEASE MATRIX: $Message" }
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
Assert-R23D48Release ($gate.Count -eq 1) "QSDK-R23 gate count changed"
$proof = $gate[0].proof
$r48 = $proof.closed_r23d48_attempt
$status = (
    "r23d48_closed_consumed_invalid_complete_rapier_trace_publication_" +
    "failure_mujoco_turning_positive_godot_walking_positive_turning_" +
    "negative_no_successor_series_paused"
)

Assert-R23D48Release (
    [string]$proof.kind -ceq "missing" -and
    [string]$proof.current_successor_status -ceq $status -and
    [string]$proof.current_prospective_successor_status -ceq $status
) "current QSDK-R23 boundary changed"

Assert-R23D48Release (
    [string]$r48.gate_id -ceq "QSDK-R23D48" -and
    [string]$r48.campaign_id -ceq
        "QSDK-R23D48-SUPPORT-LOSS-CONDITIONED-THREE-ENGINE-TURNING" -and
    [string]$r48.status -ceq
        "closed_consumed_invalid_complete_rapier_trace_publication_failure_with_valid_mujoco_turning_and_godot_turning_negative" -and
    [string]$r48.closure_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r48.closure_path)
    )) -and
    [string]$r48.closure_audit_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r48.closure_audit_path)
    )) -and
    [string]$r48.release_matrix_audit_raw_sha256 -ceq
        (Get-Sha256 $PSCommandPath) -and
    [string]$r48.physical_source_commit -ceq
        "0a9edce0e5b85c84020087b121f7c6fb239afc97" -and
    [string]$r48.attempt_id -ceq "824211f004f048fcbf0ecd6b7108dbc0" -and
    (@($r48.declared_engine_ids) -join "|") -ceq
        "rapier_parry|godot_jolt|mujoco" -and
    [int]$r48.fresh_seed -eq 21512 -and
    [int]$r48.declared_world_count -eq 9 -and
    [int]$r48.qualification_gate_count -eq 17 -and
    [int]$r48.qualification_world_count -eq 0 -and
    -not [bool]$r48.historical_full_suite_rerun -and
    [int]$r48.world_attempt_count -eq 9 -and
    [int]$r48.world_build_count -eq 9 -and
    [int]$r48.execution_valid_cell_count -eq 6 -and
    [int]$r48.rapier_trace_publication_failure_count -eq 3 -and
    [int]$r48.official_retained_trace_count -eq 6 -and
    [int]$r48.post_failure_diagnostic_trace_count -eq 3 -and
    [bool]$r48.mujoco_all_common_walking_gates_passed -and
    [bool]$r48.mujoco_turning_passed -and
    [bool]$r48.godot_jolt_all_common_walking_gates_passed -and
    -not [bool]$r48.godot_jolt_turning_passed -and
    -not [bool]$r48.rapier_turning_officially_passed -and
    [bool]$r48.rapier_post_failure_diagnostic_turning_passed -and
    -not [bool]$r48.rapier_post_failure_diagnostic_creates_claim -and
    [string]$r48.failure_mechanism -ceq
        "rapier_child_powershell_authorization_failure_during_trace_cas_publication" -and
    [bool]$r48.one_shot_identity_consumed -and
    -not [bool]$r48.same_identity_rerun_allowed -and
    -not [bool]$r48.successor_campaign_opened -and
    [bool]$r48.physical_series_paused_before_successor -and
    -not [bool]$r48.finite_three_engine_turning -and
    -not [bool]$r48.portable_basic_turning -and
    -not [bool]$r48.cross_engine_equivalence -and
    -not [bool]$r48.q_sdk_r23_satisfied -and
    -not [bool]$r48.release_authorized -and
    -not [bool]$r48.physical_acceptance_authority
) "R48 release record changed"

Assert-R23D48Release (
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D48-SUPPORT-LOSS-CONDITIONED-THREE-ENGINE-TURNING"'
    ).Count -eq 1 -and
    $supportJson.Contains('"current_prospective_successor_status": "' + $status + '"') -and
    $supportJson.Contains('"rapier_trace_publication_failure_count": 3') -and
    $supportJson.Contains('"mujoco_turning_passed": true') -and
    $supportJson.Contains('"godot_jolt_turning_passed": false') -and
    $supportJson.Contains('"finite_three_engine_turning": false') -and
    $supportJson.Contains('"q_sdk_r23_satisfied": false')
) "support-matrix R48 boundary changed"

Write-Host (
    "QSDK_R23D48_RELEASE_MATRIX_PASS worlds=9 valid=6 rapier_failures=3 " +
    "mujoco_turning=True godot_turning=False three_engine=False release=False paused=True"
)
