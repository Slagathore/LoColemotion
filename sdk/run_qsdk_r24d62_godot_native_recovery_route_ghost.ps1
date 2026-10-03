#requires -Version 7.0

<#
.SYNOPSIS
Thin R62 binding for the shared bounded Godot recovery-route supervisor.

.DESCRIPTION
R62 changes only the first-step candidate-versus-matched-zero application
identity. The supervisor, worker, controller, pose, evaluator, and physics
remain shared.
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
$contractRelativePath = "sdk/recovery/r24d62_godot_candidate_bootstrap_identity_contract_v1.json"
$contractPath = Join-Path (Split-Path $PSScriptRoot -Parent) $contractRelativePath
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
$qualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object { [string]$_ })
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D62"
    GateToken = "R24D62"
    ContractRelativePath = $contractRelativePath
    ClosureRelativePath = "sdk/recovery/r24d62_godot_candidate_bootstrap_identity_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema = "sporespore_qsdk_r24d62_godot_candidate_bootstrap_identity_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema = "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema = "sporespore_qsdk_r24d62_published_closure_authorization_control_v1"
    SourceAuditRelativePath = "sdk/conformance/r24d62_godot_candidate_bootstrap_identity.py"
    WorkerRelativePath = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    EvidenceDirectoryName = "qsdk-r24d62-godot-native-recovery-route-ghost"
    RawMarker = "QSDK_R24D62_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW "
    ReadyMarker = "QSDK_R24D62_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D62_GHOST_SUPERVISOR "
    Seed = 1268887312
    SeedLabel = "QSDK-R24D62/ghost/godot/route-smoke-v1"
    SeedSha256 = "sha256:4ba1af108fcab8e2e822f8dc7756941c6c359878993844996a330ff6af45f253"
    PreflightSchema = "sporespore_qsdk_r24d62_ghost_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d62_ghost_attempt_v1"
    RawSchema = "sporespore_qsdk_r24d62_godot_native_recovery_route_ghost_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d62_ghost_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d62_ghost_terminal_v1"
    SupervisorResultSchema = "sporespore_qsdk_r24d62_ghost_supervisor_result_v1"
    QualifiedPhysicalPaths = $qualifiedPhysicalPaths
}

& $shared @arguments
exit $LASTEXITCODE
