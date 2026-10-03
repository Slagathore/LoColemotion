#requires -Version 7.0

<#
.SYNOPSIS
Thin R76 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R76 runs the unchanged complete R70 candidate-plus-matched-zero recovery
behavior question under the exact post-solve contact source calibrated by R75.
It adds no rehearsal, controller change, threshold change, or physical canary.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl", "AuthorizationControl")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d76_godot_jolt_solved_contact_recovery_behavior_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D76"
    GateToken = "R24D76"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d76_godot_jolt_solved_contact_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d76_godot_jolt_solved_contact_recovery_behavior_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d76_published_closure_authorization_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d76_godot_jolt_solved_contact_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d76-godot-jolt-solved-contact-recovery-behavior"
    RawMarker = "QSDK_R24D76_GODOT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D76_GODOT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_TERMINATION_READY "
    SupervisorMarker =
        "QSDK_R24D76_SOLVED_CONTACT_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D76/development/godot/exact-nominal-solved-contact-paired-v1"
    SeedSha256 =
        "sha256:b920518d5578229a1ae1c36e3289fe578273cf1a9f3370c95e688c0d3b3a9c51"
    PreflightSchema = "sporespore_qsdk_r24d76_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d76_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d76_godot_solved_contact_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d76_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d76_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d76_behavior_supervisor_result_v1"
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
        "QSDK-R24D76-GODOT-JOLT-SOLVED-CONTACT-RECOVERY-BEHAVIOR"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
