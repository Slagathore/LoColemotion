#requires -Version 7.0

<#
.SYNOPSIS
Thin R72 binding for the shared serialized Godot/Jolt route supervisor.

.DESCRIPTION
R72 constructs one existing exact-S169 world and executes exactly two native
steps. It calibrates whether the newly qualified current-step solved-contact
source is nonzero on the production route; it does not evaluate recovery.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$root = Split-Path $PSScriptRoot -Parent
$shared = Join-Path $PSScriptRoot (
    "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
)
$contractRelative =
    "sdk/recovery/r24d72_godot_jolt_minimal_contact_calibration_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    ConsolePath = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r24d71-godot-solved-contact-telemetry\development-runtime-v3\" +
        "19dc32b39400-b20323fd08a7\" +
        "godot.windows.editor.dev.x86_64.console.exe"
    )
    ExpectedConsoleSha256 =
        "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
    ExpectedConsoleByteLength = 293376
    GateId = "QSDK-R24D72"
    GateToken = "R24D72"
    ContractRelativePath = $contractRelative
    ClosureRelativePath =
        "sdk/recovery/r24d72_godot_jolt_minimal_contact_calibration_zero_world_qualification_closure_v1.json"
    AuthorizationClosureSchema =
        "sporespore_qsdk_r24d72_godot_jolt_minimal_contact_calibration_zero_world_qualification_closure_v1"
    SourceAuditRelativePath =
        "sdk/conformance/r24d72_godot_jolt_minimal_contact_calibration.py"
    WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    EvidenceDirectoryName =
        "qsdk-r24d72-godot-jolt-minimal-contact-calibration"
    RawMarker = "QSDK_R24D72_GODOT_MINIMAL_CONTACT_CALIBRATION_RAW "
    ReadyMarker = "QSDK_R24D72_GODOT_SUPERVISOR_TERMINATION_READY "
    SupervisorMarker = "QSDK_R24D72_CONTACT_CALIBRATION_SUPERVISOR "
    Seed = 1752993918
    SeedLabel =
        "QSDK-R24D72/development/godot/minimal-native-contact-calibration-v1"
    SeedSha256 =
        "sha256:e87c907e754cb5506cec250e732c77d894d56f5d05394c999fcb2249062869cb"
    PreflightSchema =
        "sporespore_qsdk_r24d72_minimal_contact_calibration_preflight_v1"
    AttemptSchema =
        "sporespore_qsdk_r24d72_minimal_contact_calibration_attempt_v1"
    RawSchema =
        "sporespore_qsdk_r24d72_godot_minimal_contact_calibration_raw_v1"
    MissingRawSchema =
        "sporespore_qsdk_r24d72_minimal_contact_calibration_missing_raw_v1"
    TerminalSchema =
        "sporespore_qsdk_r24d72_minimal_contact_calibration_terminal_v1"
    SupervisorResultSchema =
        "sporespore_qsdk_r24d72_minimal_contact_calibration_supervisor_v1"
    PhysicalQuestionKind = "integration_ghost"
    MaximumModelConstructionAttemptCount = 1
    MaximumModelConstructionCount = 1
    MaximumWorldAttemptCount = 1
    MaximumWorldBuildCount = 1
    MaximumOuterSolverSteps = 2
    ExpectedModelConstructionCount = 1
    ExpectedWorldAttemptCount = 1
    ExpectedWorldBuildCount = 1
    MinimumCompletedSolverSteps = 2
    ExpectedBehaviorEvaluatorInvocationCount = 0
    ValidCompleteStatus = "valid_complete_integration_ghost"
    InvalidOrIncompleteStatus = "invalid_or_incomplete_integration_ghost"
    PhysicalWorkId =
        "QSDK-R24D72-GODOT-JOLT-MINIMAL-NATIVE-CONTACT-CALIBRATION"
    PhysicalTimeoutSeconds = 120
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
