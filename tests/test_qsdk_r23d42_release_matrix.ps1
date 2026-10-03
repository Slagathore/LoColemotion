#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d42_three_engine_startup_ramp_turning_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d42_closure.ps1"

function Assert-R23D42Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D42 RELEASE MATRIX: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D42Release (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$release = Get-Content -Raw -LiteralPath $releasePath |
    ConvertFrom-Json -Depth 100
$support = Get-Content -Raw -LiteralPath $supportPath |
    ConvertFrom-Json -Depth 100
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100

$releaseGate = @($release.gates | Where-Object gate_id -ceq "QSDK-R23")
Assert-R23D42Release ($releaseGate.Count -eq 1) "release gate count changed"
$releaseProof = $releaseGate[0].proof

# The support matrix has one turning capability. Current-successor status may
# advance after this historical closure, so this R42 audit binds the immutable
# R42 record rather than freezing a mutable "current" pointer forever.
$supportJson = Get-Content -Raw -LiteralPath $supportPath
$supportMatches = [regex]::Matches(
    $supportJson,
    '"current_prospective_successor_status"\s*:\s*"([^"]+)"'
)
Assert-R23D42Release ($supportMatches.Count -eq 1) (
    "support current prospective status count changed"
)
$supportStatus = $supportMatches[0].Groups[1].Value
Assert-R23D42Release (
    [string]$releaseProof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$releaseProof.current_prospective_successor_status
    ) -and
    [string]$releaseProof.current_prospective_successor_status -ceq
        $supportStatus
) "turning release pointer shape changed"

$record = $releaseProof.prospective_r23d42_attempt
Assert-R23D42Release (
    [string]$record.status -ceq [string]$closure.status -and
    [string]$record.physical_source_commit -ceq [string]$closure.source_commit -and
    [string]$record.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$record.closure_raw_sha256 -ceq (Get-Sha256 $closurePath) -and
    [string]$record.closure_audit_raw_sha256 -ceq
        (Get-Sha256 $closureAuditPath) -and
    [int]$record.declared_world_count -eq 9 -and
    [int]$record.world_build_count -eq 9 -and
    [int]$record.execution_valid_cell_count -eq 6 -and
    [int]$record.rapier_trace_retention_failure_count -eq 3 -and
    [bool]$record.godot_jolt_all_common_walking_gates_passed -and
    -not [bool]$record.godot_jolt_turning_passed -and
    [bool]$record.mujoco_all_common_walking_gates_passed -and
    [bool]$record.mujoco_turning_passed -and
    -not [bool]$record.rapier_posthoc_creates_physical_claim -and
    [bool]$record.one_shot_identity_consumed -and
    -not [bool]$record.same_identity_rerun_allowed -and
    -not [bool]$record.successor_campaign_opened -and
    [bool]$record.physical_series_paused_before_successor -and
    -not [bool]$record.finite_three_engine_turning -and
    -not [bool]$record.portable_basic_turning -and
    -not [bool]$record.cross_engine_equivalence -and
    -not [bool]$record.q_sdk_r23_satisfied -and
    -not [bool]$record.physical_acceptance_authority
) "release contract R42 record changed"

$supportRecordCount = [regex]::Matches(
    $supportJson,
    '"campaign_id"\s*:\s*"QSDK-R23D42-TRACE-INTERFACE-REPAIR-REPLICATION"'
).Count
Assert-R23D42Release ($supportRecordCount -eq 1) (
    "support R42 record count changed"
)
foreach ($needle in @(
    '"status": "closed_consumed_implementation_invalid_rapier_production_trace_cas_with_valid_godot_negative_and_mujoco_positive"',
    '"execution_valid_cell_count": 6',
    '"rapier_trace_retention_failure_count": 3',
    '"godot_jolt_turning_passed": false',
    '"mujoco_turning_passed": true',
    '"same_identity_rerun_allowed": false',
    '"physical_series_paused_before_successor": true',
    '"finite_three_engine_turning": false',
    '"q_sdk_r23_satisfied": false'
)) {
    Assert-R23D42Release ($supportJson.Contains($needle)) (
        "support matrix missing exact R42 field: $needle"
    )
}

Write-Output (
    "QSDK_R23D42_RELEASE_MATRIX_PASS official=implementation_invalid " +
    "godot_walking=True godot_turning=False mujoco_turning=True " +
    "rapier_accepted=False unified_three_engine=False paused=True"
)
