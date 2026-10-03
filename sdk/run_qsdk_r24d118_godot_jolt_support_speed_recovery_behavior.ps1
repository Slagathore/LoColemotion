#requires -Version 7.0

<#
.SYNOPSIS
Thin R118 binding for the shared serialized Godot/Jolt behavior supervisor.

.DESCRIPTION
R118 asks the exact R115 candidate-plus-matched-zero development question with
only the R117-qualified controller-v3 support-speed ceiling changed.
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
    "sdk/recovery/r24d118_godot_jolt_support_speed_recovery_behavior_physical_closure_v1.json"
if ($Mode -ceq "Physical" -and $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath (Join-Path $root $physicalClosureRelative) -PathType Leaf)) {
    throw "QSDK_R24D118_PHYSICAL_IDENTITY_CONSUMED"
}
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d118_godot_jolt_support_speed_recovery_behavior_contract_v1.json"
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
    GateId = "QSDK-R24D118"
    GateToken = "R24D118"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d118_godot_jolt_support_speed_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d118_godot_jolt_support_speed_recovery_behavior_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d118_support_speed_recovery_behavior_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d118_godot_jolt_support_speed_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d118-godot-jolt-support-speed-recovery-behavior"
    RawMarker =
        "QSDK_R24D118_GODOT_SUPPORT_SPEED_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D118_GODOT_SUPPORT_SPEED_RECOVERY_BEHAVIOR_READY "
    SupervisorMarker =
        "QSDK_R24D118_SUPPORT_SPEED_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D118/development/godot/r118-v3-support-speed-exact-nominal-prone-to-standing-paired-v1"
    SeedSha256 =
        "sha256:c1fc52f717de2784553fc3a530b68ba3496142ab5e8f6aeba55195d5de378361"
    ActuatorMode =
        "force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3"
    RecoveryControllerId =
        "sporespore_exact_s169_prone_to_standing_controller_v3"
    PreflightSchema = "sporespore_qsdk_r24d118_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d118_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d118_godot_support_speed_recovery_behavior_raw_v1"
    MissingRawSchema = "sporespore_qsdk_r24d118_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d118_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d118_behavior_supervisor_result_v1"
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
        "QSDK-R24D118-GODOT-JOLT-SUPPORT-SPEED-RECOVERY-BEHAVIOR"
    ProgressMarker =
        "QSDK_R24D118_GODOT_SUPPORT_SPEED_RECOVERY_BEHAVIOR_PROGRESS "
    ProgressCadenceSteps = 30
    ProgressStallTimeoutSeconds = 600
    MinimumProgressMarkerCount = 5
    PhysicalTimeoutSeconds = 24000
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
