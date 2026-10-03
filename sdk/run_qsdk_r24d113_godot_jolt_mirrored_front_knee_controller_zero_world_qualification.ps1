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
    GateId = "QSDK-R24D113"
    ContractRelativePath =
        "sdk/recovery/r24d113_godot_jolt_mirrored_front_knee_controller_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_controller_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d113_godot_jolt_mirrored_front_knee_controller.py"
    SourceAuditPassMarker =
        "QSDK_R24D113_GODOT_JOLT_MIRRORED_FRONT_KNEE_CONTROLLER_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d113_godot_jolt_mirrored_front_knee_controller.py"
    CargoTestFilter =
        "r24d113_controller_v2_changes_only_the_two_front_knee_targets"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    NativeZeroWorldRuntimePath =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r24d71-godot-solved-contact-telemetry\development-runtime-v3\19dc32b39400-b20323fd08a7\godot.windows.editor.dev.x86_64.console.exe"
    NativeZeroWorldScriptRelativePath =
        "tests/test_sdk_qsdk_r24d113_godot_mirrored_front_knee_controller_zero_world.gd"
    NativeZeroWorldPassMarker =
        "SPORESPORE_GODOT_R24D113_MIRRORED_FRONT_KNEE_ZERO_WORLD "
    GodotParseScriptRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    QualificationDirectoryPrefix =
        "qsdk-r24d113-godot-jolt-mirrored-front-knee-controller-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_controller_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_controller_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_controller_zero_world_receipt_v1"
}

& $shared @arguments
exit $LASTEXITCODE
