#requires -Version 7.0

<#
.SYNOPSIS
Thin R69 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R69 repeats the finite R68 behavior question under a distinct source identity
that inverse-projects each unchanged cap through the complete frozen Godot/Jolt
binary32 impulse-to-torque-to-effective-impulse path. The immediately higher
binary32 input is unsafe for every actuator. No physical ghost precedes the
finite pair.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl", "AuthorizationControl")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D69"
    GateToken = "R24D69"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d69_godot_native_effective_impulse_limit_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d69_published_closure_authorization_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d69_godot_native_effective_impulse_limit.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d69-godot-native-effective-impulse-limit"
    RawMarker = "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_RAW "
    ReadyMarker = "QSDK_R24D69_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D69_BEHAVIOR_SUPERVISOR "
    Seed = 739575220
    SeedLabel = "QSDK-R24D69/development/godot/exact-nominal-paired-v1"
    SeedSha256 =
        "sha256:2c1505b493884863c5a5dcfa638b98fe2b8beacd9e1dbb4648637a26cc135e3d"
    PreflightSchema = "sporespore_qsdk_r24d69_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d69_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d69_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d69_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d69_behavior_supervisor_result_v1"
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
    PhysicalWorkId = "QSDK-R24D69-GODOT-JOLT-NATIVE-EFFECTIVE-IMPULSE-LIMIT"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
