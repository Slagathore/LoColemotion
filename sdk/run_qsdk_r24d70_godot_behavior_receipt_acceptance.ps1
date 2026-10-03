#requires -Version 7.0

<#
.SYNOPSIS
Thin R70 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R70 asks the finite R69 behavior question under a distinct source and seed
after repairing only the worker's evaluator-receipt consumer predicate and
terminal invariant-summary retention. The controller, evaluator, thresholds,
actuator caps, world, and physical envelope remain frozen. No physical ghost
precedes the finite pair.
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
    "sdk/recovery/r24d70_godot_behavior_receipt_acceptance_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D70"
    GateToken = "R24D70"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d70_godot_behavior_receipt_acceptance_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d70_published_closure_authorization_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d70_godot_behavior_receipt_acceptance.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d70-godot-behavior-receipt-acceptance"
    RawMarker = "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_RAW "
    ReadyMarker = "QSDK_R24D70_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D70_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel = "QSDK-R24D70/development/godot/exact-nominal-receipt-successor-paired-v1"
    SeedSha256 =
        "sha256:1094425b184083ae94c43d40ea1e0c7914fcde3e81d3f72995b1401030119646"
    PreflightSchema = "sporespore_qsdk_r24d70_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d70_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d70_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d70_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d70_behavior_supervisor_result_v1"
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
    PhysicalWorkId = "QSDK-R24D70-GODOT-JOLT-BEHAVIOR-RECEIPT-ACCEPTANCE"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
