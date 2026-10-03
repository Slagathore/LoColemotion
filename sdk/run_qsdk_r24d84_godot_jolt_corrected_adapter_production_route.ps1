#requires -Version 7.0

<#
.SYNOPSIS
Thin R84 binding for the shared serialized Godot/Jolt route supervisor.

.DESCRIPTION
R84 reuses the production two-step worker to cover only the construction and
post-application integration risk left after R83. It does not evaluate recovery
behavior and does not run a full seed horizon.
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
    "sdk/recovery/r24d84_godot_jolt_corrected_adapter_production_route_contract_v1.json"
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
    GateId = "QSDK-R24D84"
    GateToken = "R24D84"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d84_godot_jolt_corrected_adapter_production_route_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d84_godot_jolt_corrected_adapter_production_route_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d84_corrected_adapter_route_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d84_godot_jolt_corrected_adapter_production_route.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    EvidenceDirectoryName =
        "qsdk-r24d84-godot-jolt-corrected-adapter-production-route"
    RawMarker = "QSDK_R24D84_GODOT_CORRECTED_ADAPTER_ROUTE_RAW "
    ReadyMarker = "QSDK_R24D84_GODOT_CORRECTED_ADAPTER_ROUTE_READY "
    SupervisorMarker = "QSDK_R24D84_CORRECTED_ADAPTER_ROUTE_SUPERVISOR "
    Seed = 622754850
    SeedLabel =
        "QSDK-R24D84/development/godot/corrected-adapter-production-route-two-step-v1"
    SeedSha256 =
        "sha256:251e7c2211988cbd57716b0cbd74f2852f395480321a398408be82d4fe230ac1"
    PreflightSchema = "sporespore_qsdk_r24d84_route_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d84_route_attempt_v1"
    RawSchema = "sporespore_qsdk_r24d84_godot_corrected_adapter_route_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d84_route_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d84_route_terminal_v1"
    SupervisorResultSchema = "sporespore_qsdk_r24d84_route_supervisor_result_v1"
    PhysicalQuestionKind = "integration_ghost"
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
        "QSDK-R24D84-GODOT-JOLT-CORRECTED-ADAPTER-PRODUCTION-ROUTE"
    PhysicalTimeoutSeconds = 180
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
