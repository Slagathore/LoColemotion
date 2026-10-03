#requires -Version 7.0

<#
.SYNOPSIS
Thin R101 binding for the shared serialized Godot/Jolt behavior supervisor.

.DESCRIPTION
R101 asks the exact finite R99 candidate-plus-matched-zero development question
through the R100 refinement-safe component-norm nested guarded actuator route.
It authorizes at most one two-world attempt after exact zero-world qualification.
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
    "sdk/recovery/r24d101_godot_jolt_refinement_safe_recovery_behavior_physical_closure_v1.json"
if ($Mode -ceq "Physical" -and $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath (Join-Path $root $physicalClosureRelative) -PathType Leaf)) {
    throw "QSDK_R24D101_PHYSICAL_IDENTITY_CONSUMED"
}
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d101_godot_jolt_refinement_safe_recovery_behavior_contract_v1.json"
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
    GateId = "QSDK-R24D101"
    GateToken = "R24D101"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d101_godot_jolt_refinement_safe_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d101_godot_jolt_refinement_safe_recovery_behavior_zero_world_qualification_closure_v1"
    RuntimeIdentitySchema =
        "sporespore_qsdk_r24d101_refinement_safe_behavior_runtime_identity_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d101_godot_jolt_refinement_safe_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d101-godot-jolt-refinement-safe-recovery-behavior"
    RawMarker =
        "QSDK_R24D101_GODOT_REFINEMENT_SAFE_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D101_GODOT_REFINEMENT_SAFE_RECOVERY_BEHAVIOR_READY "
    SupervisorMarker =
        "QSDK_R24D101_REFINEMENT_SAFE_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D101/development/godot/r101-refinement-safe-exact-nominal-prone-to-standing-paired-v1"
    SeedSha256 =
        "sha256:a0f8dff7e30ec231c0c423c5403eb5a01466dbb791b711fff204ce352947bbe3"
    ActuatorMode =
        "force_based_refinement_safe_component_norm_nested_native_angular_velocity_guarded_v1"
    PreflightSchema = "sporespore_qsdk_r24d101_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d101_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d101_godot_refinement_safe_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d101_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d101_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d101_behavior_supervisor_result_v1"
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
        "QSDK-R24D101-GODOT-JOLT-REFINEMENT-SAFE-RECOVERY-BEHAVIOR"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
