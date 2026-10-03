#requires -Version 7.0

<#
.SYNOPSIS
R93 zero-world binding for the shared Godot/Jolt recovery supervisor.

.DESCRIPTION
This wrapper exposes only preflight, runtime-identity, and forced-projection
controls while R93 qualifies reusable native-engine health coverage. R93 has no
physical question or authorization; physical and authorization-control modes
fail before the shared supervisor is invoked.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl", "AuthorizationControl", "RuntimeIdentity")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

if ($RunPhysical.IsPresent -or $Mode -cin @("Physical", "AuthorizationControl")) {
    throw "QSDK_R24D93_PHYSICAL_QUESTION_NOT_DECLARED"
}

$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d93_godot_jolt_native_engine_health_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $false
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    ConsolePath = [string]$contract.exact_runtime.console_path
    ExpectedConsoleSha256 = [string]$contract.exact_runtime.console_sha256
    ExpectedConsoleByteLength = [long]$contract.exact_runtime.console_byte_length
    GateId = "QSDK-R24D93"
    GateToken = "R24D93"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d93_godot_jolt_native_engine_health_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_r24d93_native_engine_health_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d93_native_engine_health_authorization_control_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d93_native_engine_health_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d93_godot_jolt_native_engine_health.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d93-godot-jolt-native-engine-health-no-physical-authority"
    RawMarker = "QSDK_R24D93_GODOT_NATIVE_ENGINE_HEALTH_RAW "
    ReadyMarker = "QSDK_R24D93_GODOT_NATIVE_ENGINE_HEALTH_READY "
    SupervisorMarker = "QSDK_R24D93_NATIVE_ENGINE_HEALTH_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D93/development/godot/native-engine-health-zero-world-only-v1"
    SeedSha256 =
        "sha256:34eb7610bcb6fbc07e1324f53ef374e37542df20a7bd0a5189900dd96e754389"
    ActuatorMode = "force_based_joint_impulse_v1"
    PreflightSchema = "sporespore_qsdk_r24d93_native_engine_health_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d93_native_engine_health_attempt_v1"
    RawSchema = "sporespore_qsdk_r24d93_native_engine_health_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d93_native_engine_health_missing_raw_v1"
    TerminalSchema = "sporespore_qsdk_r24d93_native_engine_health_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d93_native_engine_health_supervisor_result_v1"
    PhysicalQuestionKind = "behavior_development"
    MaximumModelConstructionAttemptCount = 2
    MaximumModelConstructionCount = 2
    MaximumWorldAttemptCount = 2
    MaximumWorldBuildCount = 2
    MaximumOuterSolverSteps = 2400
    ExpectedModelConstructionCount = 2
    ExpectedWorldAttemptCount = 2
    ExpectedWorldBuildCount = 2
    MinimumCompletedSolverSteps = 2
    ExpectedBehaviorEvaluatorInvocationCount = 1
    ValidCompleteStatus = "physical_execution_not_declared"
    InvalidOrIncompleteStatus = "physical_execution_not_declared"
    PhysicalWorkId = "QSDK-R24D93-NO-PHYSICAL-WORK"
    PhysicalTimeoutSeconds = 1
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
