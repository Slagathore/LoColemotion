#requires -Version 7.0

<#
.SYNOPSIS
Thin R61 binding for the shared bounded Godot recovery-route supervisor.

.DESCRIPTION
R61 changes only native contact-identity provenance projection. The bounded
supervisor, worker, controller, pose, evaluator, and physics remain shared.
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
$contractRelativePath = "sdk/recovery/r24d61_godot_contact_identity_projection_contract_v1.json"
$contractPath = Join-Path (Split-Path $PSScriptRoot -Parent) $contractRelativePath
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
$qualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object { [string]$_ })
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D61"
    GateToken = "R24D61"
    ContractRelativePath = $contractRelativePath
    ClosureRelativePath = "sdk/recovery/r24d61_godot_contact_identity_projection_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema = "sporespore_qsdk_r24d61_godot_contact_identity_projection_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema = "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema = "sporespore_qsdk_r24d61_published_closure_authorization_control_v1"
    SourceAuditRelativePath = "sdk/conformance/r24d61_godot_contact_identity_projection.py"
    WorkerRelativePath = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    EvidenceDirectoryName = "qsdk-r24d61-godot-native-recovery-route-ghost"
    RawMarker = "QSDK_R24D61_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW "
    ReadyMarker = "QSDK_R24D61_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D61_GHOST_SUPERVISOR "
    Seed = 1825763330
    SeedLabel = "QSDK-R24D61/ghost/godot/route-smoke-v1"
    SeedSha256 = "sha256:ecd2f002153c76bc8166e88be338607412b1a637947df48f4ebdc4a1af7c059d"
    PreflightSchema = "sporespore_qsdk_r24d61_ghost_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d61_ghost_attempt_v1"
    RawSchema = "sporespore_qsdk_r24d61_godot_native_recovery_route_ghost_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d61_ghost_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d61_ghost_terminal_v1"
    SupervisorResultSchema = "sporespore_qsdk_r24d61_ghost_supervisor_result_v1"
    QualifiedPhysicalPaths = $qualifiedPhysicalPaths
}

& $shared @arguments
exit $LASTEXITCODE
