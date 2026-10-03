#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"

function Assert-R23D47Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D47 RELEASE MATRIX: $Message" }
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
Assert-R23D47Release ($gate.Count -eq 1) "QSDK-R23 gate count changed"
$proof = $gate[0].proof
$r45 = $proof.closed_r23d45_attempt
$r46 = $proof.closed_r23d46_attempt
$r47 = $proof.closed_r23d47_attempt
$status = (
    "r23d47_closed_consumed_valid_complete_exact_mujoco_reference_walking_" +
    "support_loss_conditioned_startup_turning_untested_no_production_" +
    "selection_physical_series_paused"
)

Assert-R23D47Release (
    [string]$proof.kind -ceq "missing" -and
    [string]$proof.current_successor_status -ceq $status -and
    [string]$proof.current_prospective_successor_status -ceq $status
) "current QSDK-R23 boundary changed"

Assert-R23D47Release (
    [string]$r45.status -ceq
        "closed_consumed_invalid_complete_missing_inherited_phase_offsets_interface" -and
    [string]$r45.closure_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r45.closure_path)
    )) -and
    [string]$r45.closure_audit_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r45.closure_audit_path)
    )) -and
    [int]$r45.world_attempt_count -eq 1 -and
    [int]$r45.controller_policy_step_count -eq 0 -and
    [string]$r45.failure_mechanism -ceq "missing_inherited_phase_offsets_interface" -and
    -not [bool]$r45.walking_tested
) "R45 invalid boundary changed"

Assert-R23D47Release (
    [string]$r46.status -ceq
        "closed_consumed_invalid_complete_trace_receipt_contract_mismatch" -and
    [string]$r46.closure_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r46.closure_path)
    )) -and
    [string]$r46.closure_audit_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r46.closure_audit_path)
    )) -and
    [int]$r46.world_attempt_count -eq 1 -and
    [int]$r46.controller_policy_step_count -eq 2992 -and
    [bool]$r46.trace_published_before_terminal_failure -and
    [string]$r46.failure_mechanism -ceq
        "post_world_content_addressed_receipt_schema_mismatch" -and
    -not [bool]$r46.official_walking_positive
) "R46 invalid boundary changed"

Assert-R23D47Release (
    [string]$r47.gate_id -ceq "QSDK-R23D47" -and
    [string]$r47.campaign_id -ceq
        "QSDK-R23D47-SUPPORT-LOSS-CONDITIONED-STARTUP-RETENTION-REPAIR-DEVELOPMENT" -and
    [string]$r47.status -ceq
        "closed_consumed_valid_complete_positive_support_loss_conditioned_startup" -and
    [string]$r47.closure_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r47.closure_path)
    )) -and
    [string]$r47.closure_audit_raw_sha256 -ceq (Get-Sha256 (
        Join-Path $repoRoot ([string]$r47.closure_audit_path)
    )) -and
    [string]$r47.release_matrix_audit_raw_sha256 -ceq (Get-Sha256 $PSCommandPath) -and
    [string]$r47.physical_source_commit -ceq
        "4059eb703428b60a88837e426d38411bdf69058d" -and
    [string]$r47.attempt_id -ceq "c2df3b34cccc4136bd658438ff61ec95" -and
    (@($r47.declared_engine_ids) -join "|") -ceq "mujoco" -and
    [int]$r47.declared_world_count -eq 1 -and
    [bool]$r47.focused_zero_world_gate_passed -and
    -not [bool]$r47.historical_full_suite_rerun -and
    [int]$r47.production_retention_canary_trace_row_count -eq 2992 -and
    [bool]$r47.production_retention_canary_exact_route_passed -and
    [int]$r47.world_attempt_count -eq 1 -and
    [int]$r47.world_build_count -eq 1 -and
    [int]$r47.controller_policy_step_count -eq 2992 -and
    [int]$r47.portable_command_count -eq 23936 -and
    [int]$r47.native_application_count -eq 23936 -and
    [bool]$r47.common_physical_walking_gate_passed -and
    [int]$r47.startup_ramp_trigger_step -eq 3 -and
    [Math]::Abs([double]$r47.forward_displacement_m -
        1.638926076250989) -le 1.0e-12 -and
    [Math]::Abs([double]$r47.maximum_tilt_rad -
        0.08961690764757078) -le 1.0e-12 -and
    [Math]::Abs([double]$r47.minimum_torso_height_m -
        0.42436045664314553) -le 1.0e-12 -and
    [int]$r47.torso_ground_contact_step_count -eq 0 -and
    [bool]$r47.identity_consumed -and
    -not [bool]$r47.same_identity_rerun_allowed -and
    -not [bool]$r47.successor_campaign_opened -and
    [bool]$r47.physical_series_paused_before_successor -and
    -not [bool]$r47.turning_tested -and
    -not [bool]$r47.portable_basic_turning -and
    -not [bool]$r47.finite_three_engine_turning -and
    -not [bool]$r47.cross_engine_equivalence -and
    -not [bool]$r47.q_sdk_r23_satisfied -and
    -not [bool]$r47.release_authorized -and
    -not [bool]$r47.physical_acceptance_authority
) "R47 release record changed"

Assert-R23D47Release (
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D45-SUPPORT-LOSS-CONDITIONED-STARTUP-DEVELOPMENT"'
    ).Count -eq 1 -and
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D46-SUPPORT-LOSS-CONDITIONED-STARTUP-INTERFACE-REPAIR-DEVELOPMENT"'
    ).Count -eq 1 -and
    [regex]::Matches(
        $supportJson,
        '"campaign_id"\s*:\s*"QSDK-R23D47-SUPPORT-LOSS-CONDITIONED-STARTUP-RETENTION-REPAIR-DEVELOPMENT"'
    ).Count -eq 1 -and
    $supportJson.Contains('"current_prospective_successor_status": "' + $status + '"') -and
    $supportJson.Contains('"startup_mechanism_positive_on_exact_mujoco_condition": true') -and
    $supportJson.Contains('"turning_tested": false') -and
    $supportJson.Contains('"q_sdk_r23_satisfied": false')
) "support-matrix R45-R47 boundary changed"

Write-Host (
    "QSDK_R23D47_RELEASE_MATRIX_PASS r45=invalid_interface " +
    "r46=invalid_retention r47=valid_mujoco_reference_walk worlds=1 " +
    "turning=False release=False paused=True"
)
