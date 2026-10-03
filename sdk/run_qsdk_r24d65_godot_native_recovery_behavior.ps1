#requires -Version 7.0

<#
.SYNOPSIS
Thin R65 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R65 opens one finite two-world behavior development pair. It accepts a valid
positive, negative, or incomplete frozen-evaluator outcome and rejects only an
invalid or incomplete route/evidence execution. No physical ghost precedes it.
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
$shared = Join-Path $PSScriptRoot `
    "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d65_godot_native_recovery_behavior_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D65"
    GateToken = "R24D65"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d65_godot_native_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d65_godot_native_recovery_behavior_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d65_published_closure_authorization_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d65_godot_native_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d65-godot-native-recovery-behavior"
    RawMarker = "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker = "QSDK_R24D65_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D65_BEHAVIOR_SUPERVISOR "
    Seed = 260226999
    SeedLabel = "QSDK-R24D65/development/godot/exact-nominal-paired-v1"
    SeedSha256 =
        "sha256:0017cfd5c0c9868607a4655bb89fc74d2f3bfda437aac974b8ac928b5b69b4e7"
    PreflightSchema = "sporespore_qsdk_r24d65_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d65_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d65_godot_native_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d65_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d65_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d65_behavior_supervisor_result_v1"
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
    PhysicalWorkId = "QSDK-R24D65-GODOT-JOLT-NATIVE-RECOVERY-BEHAVIOR"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
