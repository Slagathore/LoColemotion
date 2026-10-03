#requires -Version 7.0

<#
.SYNOPSIS
Thin R66 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R66 repeats the finite R65 behavior question under a distinct source identity
whose only runtime change is exact scalar-space quaternion projection plus
complete collection-refusal diagnostics. No physical ghost precedes it.
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
    "sdk/recovery/r24d66_godot_exact_quaternion_projection_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D66"
    GateToken = "R24D66"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d66_godot_exact_quaternion_projection_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d66_godot_exact_quaternion_projection_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d66_published_closure_authorization_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d66_godot_exact_quaternion_projection.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d66-godot-exact-quaternion-projection"
    RawMarker = "QSDK_R24D66_GODOT_EXACT_QUATERNION_PROJECTION_RAW "
    ReadyMarker = "QSDK_R24D66_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D66_BEHAVIOR_SUPERVISOR "
    Seed = 1976530392
    SeedLabel = "QSDK-R24D66/development/godot/exact-nominal-paired-v1"
    SeedSha256 =
        "sha256:75cf75d8f8c1036398f736e9fa7fba4529abfc49ba78f14fa5551f545ae63299"
    PreflightSchema = "sporespore_qsdk_r24d66_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d66_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d66_godot_exact_quaternion_projection_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d66_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d66_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d66_behavior_supervisor_result_v1"
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
    PhysicalWorkId = "QSDK-R24D66-GODOT-JOLT-EXACT-QUATERNION-PROJECTION"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
