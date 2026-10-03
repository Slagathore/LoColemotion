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
    GateId = "QSDK-R24D129"
    ContractRelativePath =
        "sdk/recovery/r24d129_godot_jolt_solver_coupled_recovery_behavior_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d129_godot_jolt_solver_coupled_recovery_behavior_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d129_godot_jolt_solver_coupled_recovery_behavior.py"
    SourceAuditPassMarker =
        "QSDK_R24D129_GODOT_JOLT_SOLVER_COUPLED_RECOVERY_BEHAVIOR_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d129_godot_jolt_solver_coupled_recovery_behavior.py"
    CargoTestFilter =
        "r24d127_controller_v6_preserves_v5_portable_policy"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    QualificationDirectoryPrefix =
        "qsdk-r24d129-godot-jolt-solver-coupled-recovery-behavior-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d129_godot_jolt_solver_coupled_recovery_behavior_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d129_godot_jolt_solver_coupled_recovery_behavior_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d129_godot_jolt_solver_coupled_recovery_behavior_zero_world_receipt_v1"
    ProspectivePhysicalQuestionDeclared = $true
}

& $shared @arguments
exit $LASTEXITCODE
