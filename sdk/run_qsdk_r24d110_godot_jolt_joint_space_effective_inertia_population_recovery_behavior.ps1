#requires -Version 7.0

<#
.SYNOPSIS
Thin R110 binding for the shared serialized Godot/Jolt behavior supervisor.

.DESCRIPTION
R110 asks the exact consumed R107 candidate-plus-matched-zero development
question through the already commissioned R109 joint-space effective-inertia
population actuator route. It authorizes at most one two-world attempt after
exact zero-world qualification.
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
    "sdk/recovery/r24d110_godot_jolt_joint_space_effective_inertia_population_recovery_behavior_physical_closure_v1.json"
if ($Mode -ceq "Physical" -and $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath (Join-Path $root $physicalClosureRelative) -PathType Leaf)) {
    throw "QSDK_R24D110_PHYSICAL_IDENTITY_CONSUMED"
}
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d110_godot_jolt_joint_space_effective_inertia_population_recovery_behavior_contract_v1.json"
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
    GateId = "QSDK-R24D110"
    GateToken = "R24D110"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d110_godot_jolt_joint_space_effective_inertia_population_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d110_godot_jolt_joint_space_effective_inertia_population_recovery_behavior_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d110_joint_space_effective_inertia_population_recovery_behavior_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d110_godot_jolt_joint_space_effective_inertia_population_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d110-godot-jolt-joint-space-effective-inertia-population-recovery-behavior"
    RawMarker =
        "QSDK_R24D110_GODOT_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D110_GODOT_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_RECOVERY_BEHAVIOR_READY "
    SupervisorMarker =
        "QSDK_R24D110_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D110/development/godot/r110-joint-space-effective-inertia-exact-nominal-prone-to-standing-paired-v1"
    SeedSha256 =
        "sha256:7d543fb6b06dae2b9202abaefff66597c09abb093bad95a02329e64a908d80e7"
    ActuatorMode =
        "force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3"
    PreflightSchema = "sporespore_qsdk_r24d110_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d110_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d110_godot_joint_space_effective_inertia_population_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d110_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d110_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d110_behavior_supervisor_result_v1"
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
        "QSDK-R24D110-GODOT-JOLT-JOINT-SPACE-EFFECTIVE-INERTIA-POPULATION-RECOVERY-BEHAVIOR"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
