#requires -Version 7.0

<#
.SYNOPSIS
Thin R96 binding for the shared serialized Godot/Jolt route supervisor.

.DESCRIPTION
R96 preserves the frozen R94/R95 native readback guard while selecting a
source-derived inner mathematical projection target. It authorizes at most one
two-step development route ghost after exact zero-world qualification.
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
    "sdk/recovery/r24d96_godot_jolt_nested_guarded_recovery_route_contract_v1.json"
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
    GateId = "QSDK-R24D96"
    GateToken = "R24D96"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d96_godot_jolt_nested_guarded_recovery_route_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_recovery_route_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d96_nested_guarded_recovery_route_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d96_godot_jolt_nested_guarded_recovery_route.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    EvidenceDirectoryName =
        "qsdk-r24d96-godot-jolt-nested-guarded-recovery-route"
    RawMarker = "QSDK_R24D96_GODOT_JOLT_NESTED_GUARDED_RECOVERY_ROUTE_RAW "
    ReadyMarker = "QSDK_R24D96_GODOT_JOLT_NESTED_GUARDED_RECOVERY_ROUTE_READY "
    SupervisorMarker = "QSDK_R24D96_NESTED_GUARDED_RECOVERY_ROUTE_SUPERVISOR "
    Seed = 312063631
    SeedLabel =
        "QSDK-R24D96/development/godot/nested-native-angular-velocity-guard-production-route-two-step-v1"
    SeedSha256 =
        "sha256:1299b68facd058b437b6e24ee17bafad8c5838a2d998c5c629f01f0d6df88424"
    PreflightSchema = "sporespore_qsdk_r24d96_route_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d96_route_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_recovery_route_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d96_route_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d96_route_terminal_v1"
    SupervisorResultSchema = "sporespore_qsdk_r24d96_route_supervisor_result_v1"
    PhysicalQuestionKind = "integration_ghost"
    ActuatorMode = "force_based_nested_native_angular_velocity_guarded_v1"
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
        "QSDK-R24D96-GODOT-JOLT-NESTED-GUARDED-RECOVERY-ROUTE"
    PhysicalTimeoutSeconds = 180
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
