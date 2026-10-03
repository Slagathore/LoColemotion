#requires -Version 7.0

<#
.SYNOPSIS
Thin R92 binding for the shared serialized Godot/Jolt behavior supervisor.

.DESCRIPTION
R92 repeats the exact finite R91 candidate-plus-matched-zero behavior question
after the shared authorization harness selects the permission bit by question
kind. All physical behavior semantics and the seed value remain unchanged.
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

$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_contract_v1.json"
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
    GateId = "QSDK-R24D92"
    GateToken = "R24D92"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_behavior_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_r24d92_behavior_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d92_published_closure_authorization_control_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d92_force_based_behavior_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d92_godot_jolt_force_based_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d92-godot-jolt-force-based-recovery-behavior"
    RawMarker =
        "QSDK_R24D92_GODOT_FORCE_BASED_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D92_GODOT_FORCE_BASED_RECOVERY_BEHAVIOR_READY "
    SupervisorMarker =
        "QSDK_R24D92_FORCE_BASED_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D92/development/godot/r92-future-state-stable-wrapper-control-reachability-exact-nominal-prone-to-standing-paired-v1"
    SeedSha256 =
        "sha256:34eb7610bcb6fbc07e1324f53ef374e37542df20a7bd0a5189900dd96e754389"
    ActuatorMode = "force_based_joint_impulse_v1"
    PreflightSchema = "sporespore_qsdk_r24d92_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d92_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d92_godot_force_based_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d92_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d92_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d92_behavior_supervisor_result_v1"
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
        "QSDK-R24D92-GODOT-JOLT-FORCE-BASED-RECOVERY-BEHAVIOR"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
