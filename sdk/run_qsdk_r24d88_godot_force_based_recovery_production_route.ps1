#requires -Version 7.0

<#
.SYNOPSIS
Thin R88 binding for the shared serialized Godot/Jolt route supervisor.

.DESCRIPTION
R88 runs the generic production two-step worker in its force-based actuator
mode. It covers construction, one body-impulse application, one post-command
native step, finalization, retention, and publication. It does not evaluate
recovery behavior or run a full seed horizon.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl", "RuntimeIdentity")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d88_godot_force_based_recovery_production_route_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    ConsolePath = [string]$contract.exact_runtime.console_path
    ExpectedConsoleSha256 = [string]$contract.exact_runtime.console_sha256
    ExpectedConsoleByteLength = [long]$contract.exact_runtime.console_byte_length
    GateId = "QSDK-R24D88"
    GateToken = "R24D88"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d88_godot_force_based_recovery_production_route_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d88_godot_force_based_recovery_production_route_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d88_force_based_recovery_route_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d88_godot_force_based_recovery_production_route.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    EvidenceDirectoryName =
        "qsdk-r24d88-godot-force-based-recovery-production-route"
    RawMarker = "QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_ROUTE_RAW "
    ReadyMarker = "QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_ROUTE_READY "
    SupervisorMarker = "QSDK_R24D88_FORCE_BASED_RECOVERY_ROUTE_SUPERVISOR "
    Seed = 362738678
    SeedLabel =
        "QSDK-R24D88/development/godot/force-based-recovery-production-route-two-step-v1"
    SeedSha256 =
        "sha256:959ef3f645667dd6c90bcb38d5ad6e28f663e2702dd21b721d48eaaa1ac93586"
    PreflightSchema = "sporespore_qsdk_r24d88_route_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d88_route_attempt_v1"
    RawSchema = "sporespore_qsdk_r24d88_godot_force_based_recovery_route_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d88_route_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d88_route_terminal_v1"
    SupervisorResultSchema = "sporespore_qsdk_r24d88_route_supervisor_result_v1"
    PhysicalQuestionKind = "integration_ghost"
    ActuatorMode = "force_based_joint_impulse_v1"
    MaximumModelConstructionAttemptCount = 1
    MaximumModelConstructionCount = 1
    MaximumWorldAttemptCount = 1
    MaximumWorldBuildCount = 1
    MaximumOuterSolverSteps = 2
    ExpectedModelConstructionCount = 1
    ExpectedWorldAttemptCount = 1
    ExpectedWorldBuildCount = 1
    MinimumCompletedSolverSteps = 2
    ExpectedBehaviorEvaluatorInvocationCount = 0
    ValidCompleteStatus = "valid_complete_integration_ghost"
    InvalidOrIncompleteStatus = "invalid_or_incomplete_integration_ghost"
    PhysicalWorkId =
        "QSDK-R24D88-GODOT-FORCE-BASED-RECOVERY-PRODUCTION-ROUTE"
    PhysicalTimeoutSeconds = 180
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
