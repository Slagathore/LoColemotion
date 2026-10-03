#requires -Version 7.0

<#
.SYNOPSIS
Thin R80 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R80 keeps the complete R78 candidate-plus-matched-zero recovery question after
R79 qualified every declared command shape through the guarded production
transport. RuntimeIdentity parses the real worker without constructing a model
or world.
#>

[CmdletBinding()]
param(
    [ValidateSet(
        "Preflight",
        "Physical",
        "ProjectionControl",
        "AuthorizationControl",
        "RuntimeIdentity"
    )]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$contractRelative =
    "sdk/recovery/r24d80_godot_jolt_guarded_command_recovery_behavior_contract_v1.json"
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
    GateId = "QSDK-R24D80"
    GateToken = "R24D80"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d80_godot_jolt_guarded_command_recovery_behavior_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d80_godot_jolt_guarded_command_recovery_behavior_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d80_published_closure_authorization_control_v1"
    RuntimeIdentitySchema = "sporespore_qsdk_r24d80_runtime_identity_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d80_godot_jolt_guarded_command_recovery_behavior.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d80-godot-jolt-guarded-command-recovery-behavior"
    RawMarker =
        "QSDK_R24D80_GODOT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_RAW "
    ReadyMarker =
        "QSDK_R24D80_GODOT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_TERMINATION_READY "
    SupervisorMarker =
        "QSDK_R24D80_GUARDED_COMMAND_RECOVERY_BEHAVIOR_SUPERVISOR "
    Seed = 278151771
    SeedLabel =
        "QSDK-R24D80/development/godot/exact-nominal-guarded-command-transport-paired-v1"
    SeedSha256 =
        "sha256:44f84af9664efe1f32c34152c1daaeee97b57b29bfc5c9a4f15c7fcec301b08b"
    PreflightSchema = "sporespore_qsdk_r24d80_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d80_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d80_godot_guarded_command_recovery_behavior_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d80_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d80_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d80_behavior_supervisor_result_v1"
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
        "QSDK-R24D80-GODOT-JOLT-GUARDED-COMMAND-RECOVERY-BEHAVIOR"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
