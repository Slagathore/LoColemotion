#requires -Version 7.0

<#
.SYNOPSIS
Thin R99 binding for the shared serialized Godot/Jolt behavior supervisor.

.DESCRIPTION
R99 asks the exact finite R98 candidate-plus-matched-zero development question
through the versioned component-norm nested guarded actuator route. It
authorizes at most one two-world attempt after exact zero-world qualification.
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

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$physicalClosureRelative =
    "sdk/recovery/r24d99_godot_jolt_component_norm_recovery_behavior_invalid_closure_v1.json"
if ($Mode -ceq "Physical" -and $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath (Join-Path $root $physicalClosureRelative) -PathType Leaf)) {
    throw "QSDK_R24D99_PHYSICAL_IDENTITY_CONSUMED"
}
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d99_godot_jolt_component_norm_recovery_behavior_contract_v1.json"
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
    GateId = "QSDK-R24D99"
    GateToken = "R24D99"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d99_godot_jolt_component_norm_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_behavior_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d99_component_norm_behavior_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d99_godot_jolt_component_norm_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d99-godot-jolt-component-norm-recovery-behavior"
    RawMarker =
        "QSDK_R24D99_GODOT_COMPONENT_NORM_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D99_GODOT_COMPONENT_NORM_RECOVERY_BEHAVIOR_READY "
    SupervisorMarker =
        "QSDK_R24D99_COMPONENT_NORM_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D99/development/godot/r99-component-norm-exact-nominal-prone-to-standing-paired-v1"
    SeedSha256 =
        "sha256:f1446a1853e3d6886e96232e80384be334bd2607fed79ad942fe0dc19e118a6d"
    ActuatorMode =
        "force_based_component_norm_nested_native_angular_velocity_guarded_v1"
    PreflightSchema = "sporespore_qsdk_r24d99_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d99_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d99_godot_component_norm_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d99_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d99_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d99_behavior_supervisor_result_v1"
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
    ValidCompleteStatus = "valid_complete_behavior_development"
    InvalidOrIncompleteStatus = "invalid_or_incomplete_behavior_development"
    PhysicalWorkId =
        "QSDK-R24D99-GODOT-JOLT-COMPONENT-NORM-RECOVERY-BEHAVIOR"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
