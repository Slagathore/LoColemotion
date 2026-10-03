#requires -Version 7.0

<#
.SYNOPSIS
Thin R67 binding for the shared serialized Godot/Jolt physical supervisor.

.DESCRIPTION
R67 repeats the finite R66 behavior question under a distinct source identity
whose only runtime change is collision-safe lossless portable contact identity
projection. The unchanged worker and supervisor already crossed construction,
native stepping, quaternion projection, and collection through step 81 in R66.
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
    "sdk/recovery/r24d67_godot_portable_contact_identity_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D67"
    GateToken = "R24D67"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d67_godot_portable_contact_identity_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d67_godot_portable_contact_identity_zero_world_qualification_closure_v1"
    AuthorizationProjectionSchema =
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    AuthorizationControlSchema =
        "sporespore_qsdk_r24d67_published_closure_authorization_control_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d67_godot_portable_contact_identity.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    EvidenceDirectoryName =
        "qsdk-r24d67-godot-portable-contact-identity"
    RawMarker = "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_RAW "
    ReadyMarker = "QSDK_R24D67_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D67_BEHAVIOR_SUPERVISOR "
    Seed = 1497255095
    SeedLabel = "QSDK-R24D67/development/godot/exact-nominal-paired-v1"
    SeedSha256 =
        "sha256:593e4cb7b7560788af8cb8601369267df40509260feeed86e63c024729a30aa5"
    PreflightSchema = "sporespore_qsdk_r24d67_behavior_preflight_v1"
    AttemptSchema = "sporespore_qsdk_r24d67_behavior_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d67_godot_portable_contact_identity_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d67_behavior_missing_raw_result_v1"
    TerminalSchema = "sporespore_qsdk_r24d67_behavior_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d67_behavior_supervisor_result_v1"
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
    PhysicalWorkId = "QSDK-R24D67-GODOT-JOLT-PORTABLE-CONTACT-IDENTITY"
    PhysicalTimeoutSeconds = 900
    QualifiedPhysicalPaths = @($contract.source_inventory | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
