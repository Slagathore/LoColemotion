#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")][string]$Mode = "development",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$shared = Join-Path $PSScriptRoot "run_qsdk_core_zero_world_qualification.ps1"
$arguments = @{
    Mode = $Mode
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D118"
    ContractRelativePath =
        "sdk/recovery/r24d118_godot_jolt_support_speed_recovery_behavior_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d118_godot_jolt_support_speed_recovery_behavior_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d118_godot_jolt_support_speed_recovery_behavior.py"
    SourceAuditPassMarker =
        "QSDK_R24D118_GODOT_JOLT_SUPPORT_SPEED_RECOVERY_BEHAVIOR_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d118_godot_jolt_support_speed_recovery_behavior.py"
    CargoTestFilter =
        "r24d117_controller_v3_changes_only_support_speed_ceiling"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    QualificationDirectoryPrefix =
        "qsdk-r24d118-godot-jolt-support-speed-recovery-behavior-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d118_godot_jolt_support_speed_recovery_behavior_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d118_godot_jolt_support_speed_recovery_behavior_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d118_godot_jolt_support_speed_recovery_behavior_zero_world_receipt_v1"
    ProspectivePhysicalQuestionDeclared = $true
}

& $shared @arguments
exit $LASTEXITCODE
