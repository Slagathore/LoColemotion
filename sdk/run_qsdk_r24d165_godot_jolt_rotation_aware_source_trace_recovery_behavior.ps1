#requires -Version 7.0

<#
.SYNOPSIS
Thin R165 binding for the shared serialized Godot/Jolt behavior supervisor.

.DESCRIPTION
R165 preserves R164's finite development question while changing only the
consumer-side native-source-trace schema selection from the stale R152 literal
to the R162 rotation-aware trace under a distinct content-bound context.
#>

[CmdletBinding()]
param(
    [ValidateSet(
        "Preflight",
        "Physical",
        "RawBindingControl",
        "ProjectionControl",
        "RuntimeIdentity"
    )]
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
    "sdk/recovery/r24d165_godot_jolt_rotation_aware_source_trace_recovery_behavior_physical_closure_v1.json"
if ($Mode -ceq "Physical" -and $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath (Join-Path $root $physicalClosureRelative) -PathType Leaf)) {
    throw "QSDK_R24D165_PHYSICAL_IDENTITY_CONSUMED"
}
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d165_godot_jolt_rotation_aware_source_trace_recovery_behavior_contract_v1.json"
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
    GateId = "QSDK-R24D165"
    GateToken = "R24D165"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d165_godot_jolt_rotation_aware_source_trace_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d165_godot_jolt_rotation_aware_source_trace_recovery_behavior_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d165_rotation_aware_source_trace_recovery_behavior_runtime_identity_v1"
    RawBindingControlSchema =
        "sporespore_qsdk_r24d165_rotation_aware_source_trace_recovery_behavior_raw_binding_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d165_godot_jolt_rotation_aware_source_trace_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d165-godot-jolt-rotation-aware-source-trace-recovery-behavior"
    RawMarker =
        "QSDK_R24D165_GODOT_ROTATION_AWARE_SOURCE_TRACE_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D165_GODOT_ROTATION_AWARE_SOURCE_TRACE_RECOVERY_BEHAVIOR_READY "
    SupervisorMarker =
        "QSDK_R24D165_ROTATION_AWARE_SOURCE_TRACE_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D121/development/godot/r121-v4-raise-body-speed-exact-nominal-prone-to-standing-paired-v1"
    SeedSha256 =
        "sha256:56acbb13436024d64c4373a9dac5299155c853d599aab1a7269b2bba6b8fbfda"
    ActuatorMode = "solver_coupled_native_constraint_motor_v1"
    RecoveryControllerId =
        "sporespore_exact_s169_prone_to_standing_controller_v6"
    RecoveryEnergyRouteId =
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1"
    PreflightSchema =
        "sporespore_qsdk_r24d165_rotation_aware_source_trace_recovery_behavior_preflight_v1"
    AttemptSchema =
        "sporespore_qsdk_r24d165_rotation_aware_source_trace_recovery_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d165_rotation_aware_source_trace_recovery_behavior_missing_raw_result_v1"
    TerminalSchema =
        "sporespore_qsdk_r24d165_rotation_aware_source_trace_recovery_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d165_rotation_aware_source_trace_recovery_behavior_supervisor_result_v1"
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
        "QSDK-R24D165-GODOT-JOLT-ROTATION-AWARE-SOURCE-TRACE-RECOVERY-BEHAVIOR"
    ProgressMarker =
        "QSDK_R24D165_GODOT_ROTATION_AWARE_SOURCE_TRACE_RECOVERY_BEHAVIOR_PROGRESS "
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
