#requires -Version 7.0

<#
.SYNOPSIS
Thin R64 binding for the shared bounded Godot recovery-route supervisor.

.DESCRIPTION
R64 changes only the derived net-work representation between native float32
members and Godot's binary64 Variant consumer. The supervisor, controller,
pose, physical worker, evaluator, and physics remain shared.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl", "AuthorizationControl")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelativePath = "sdk/recovery/r24d64_godot_exact_net_motor_work_projection_contract_v1.json"
$contractPath = Join-Path (Split-Path $PSScriptRoot -Parent) $contractRelativePath
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
$qualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object { [string]$_ })
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D64"
    GateToken = "R24D64"
    ContractRelativePath = $contractRelativePath
    ClosureRelativePath = "sdk/recovery/r24d64_godot_exact_net_motor_work_projection_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema = "sporespore_qsdk_r24d64_godot_exact_net_motor_work_projection_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema = "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema = "sporespore_qsdk_r24d64_published_closure_authorization_control_v1"
    SourceAuditRelativePath = "sdk/conformance/r24d64_godot_exact_net_motor_work_projection.py"
    WorkerRelativePath = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    EvidenceDirectoryName = "qsdk-r24d64-godot-native-recovery-route-ghost"
    RawMarker = "QSDK_R24D64_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW "
    ReadyMarker = "QSDK_R24D64_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D64_GHOST_SUPERVISOR "
    Seed = 491850074
    SeedLabel = "QSDK-R24D64/ghost/godot/route-smoke-v1"
    SeedSha256 = "sha256:1d51095aad1a7e667a50ced6972dfb1caf18eba354890391794c8a523aed3b9e"
    PreflightSchema = "sporespore_qsdk_r24d64_ghost_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d64_ghost_attempt_v1"
    RawSchema = "sporespore_qsdk_r24d64_godot_native_recovery_route_ghost_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d64_ghost_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d64_ghost_terminal_v1"
    SupervisorResultSchema = "sporespore_qsdk_r24d64_ghost_supervisor_result_v1"
    QualifiedPhysicalPaths = $qualifiedPhysicalPaths
}

& $shared @arguments
exit $LASTEXITCODE
