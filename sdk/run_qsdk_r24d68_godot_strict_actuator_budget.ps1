#requires -Version 7.0

<#
.SYNOPSIS
Thin R68 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R68 repeats the finite R67 behavior question under a distinct source identity
that floors only the binary32 host cap when nearest rounding would exceed the
unchanged published cap, and applies the core's exact strict budget predicate
with complete diagnostics. No physical ghost precedes the finite pair.
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
    "sdk/recovery/r24d68_godot_strict_actuator_budget_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D68"
    GateToken = "R24D68"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d68_godot_strict_actuator_budget_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d68_godot_strict_actuator_budget_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d68_published_closure_authorization_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d68_godot_strict_actuator_budget.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d68-godot-strict-actuator-budget"
    RawMarker = "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_RAW "
    ReadyMarker = "QSDK_R24D68_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D68_BEHAVIOR_SUPERVISOR "
    Seed = 368340612
    SeedLabel = "QSDK-R24D68/development/godot/exact-nominal-paired-v1"
    SeedSha256 =
        "sha256:15f46e84f3681611a7caf9c136d6a08cb6181abe2d926507539346d1343a22fa"
    PreflightSchema = "sporespore_qsdk_r24d68_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d68_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d68_godot_strict_actuator_budget_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d68_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d68_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d68_behavior_supervisor_result_v1"
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
    PhysicalWorkId = "QSDK-R24D68-GODOT-JOLT-STRICT-ACTUATOR-BUDGET"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
