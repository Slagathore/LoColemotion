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
    GateId = "QSDK-R24D127"
    ContractRelativePath =
        "sdk/recovery/r24d127_godot_jolt_solver_coupled_controller_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d127_godot_jolt_solver_coupled_controller.py"
    SourceAuditPassMarker =
        "QSDK_R24D127_GODOT_JOLT_SOLVER_COUPLED_CONTROLLER_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d127_godot_jolt_solver_coupled_controller.py"
    CargoTestFilter =
        "r24d127_controller_v6_preserves_v5_portable_policy"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    NativeZeroWorldRuntimePath =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r24d71-godot-solved-contact-telemetry\development-runtime-v3\19dc32b39400-b20323fd08a7\godot.windows.editor.dev.x86_64.console.exe"
    NativeZeroWorldScriptRelativePath =
        "tests/test_sdk_qsdk_r24d127_godot_solver_coupled_controller_zero_world.gd"
    NativeZeroWorldPassMarker =
        "SPORESPORE_GODOT_R24D127_SOLVER_COUPLED_CONTROLLER_ZERO_WORLD "
    GodotParseScriptRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    QualificationDirectoryPrefix =
        "qsdk-r24d127-godot-jolt-solver-coupled-controller-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_zero_world_receipt_v1"
}

& $shared @arguments
exit $LASTEXITCODE
