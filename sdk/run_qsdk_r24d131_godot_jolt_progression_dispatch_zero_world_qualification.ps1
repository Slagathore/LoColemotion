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
    GateId = "QSDK-R24D131"
    ContractRelativePath =
        "sdk/recovery/r24d131_godot_jolt_progression_dispatch_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d131_godot_jolt_progression_dispatch.py"
    SourceAuditPassMarker =
        "QSDK_R24D131_GODOT_JOLT_PROGRESSION_DISPATCH_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d131_godot_jolt_progression_dispatch.py"
    CargoTestFilter =
        "r24d126_incomplete_godot_authority_opens_only_development_handoff"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    NativeZeroWorldRuntimePath =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r24d71-godot-solved-contact-telemetry\development-runtime-v3\19dc32b39400-b20323fd08a7\godot.windows.editor.dev.x86_64.console.exe"
    NativeZeroWorldScriptRelativePath =
        "tests/test_sdk_qsdk_r24d131_godot_progression_dispatch_zero_world.gd"
    NativeZeroWorldPassMarker =
        "SPORESPORE_GODOT_R24D131_PROGRESSION_DISPATCH_ZERO_WORLD "
    GodotParseScriptRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    QualificationDirectoryPrefix =
        "qsdk-r24d131-godot-jolt-progression-dispatch-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_zero_world_receipt_v1"
}

& $shared @arguments
exit $LASTEXITCODE
