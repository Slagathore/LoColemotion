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
    GateId = "QSDK-R24D126"
    ContractRelativePath =
        "sdk/recovery/r24d126_godot_jolt_energy_authority_development_progression_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d126_godot_jolt_energy_authority_development_progression_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d126_godot_jolt_energy_authority_development_progression.py"
    SourceAuditPassMarker =
        "QSDK_R24D126_GODOT_JOLT_ENERGY_AUTHORITY_DEVELOPMENT_PROGRESSION_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d126_godot_jolt_energy_authority_development_progression.py"
    CargoTestFilter = "r24d126"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_v5_malformed_request_refuses_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_manifest_symbols_resolve_from_real_library"
    NativeZeroWorldRuntimePath =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r24d71-godot-solved-contact-telemetry\development-runtime-v3\19dc32b39400-b20323fd08a7\godot.windows.editor.dev.x86_64.console.exe"
    NativeZeroWorldScriptRelativePath =
        "tests/test_sdk_qsdk_r24d126_godot_energy_authority_development_progression_zero_world.gd"
    NativeZeroWorldPassMarker =
        "QSDK_R24D126_GODOT_ENERGY_AUTHORITY_ZERO_WORLD "
    GodotParseScriptRelativePath =
        "tests/test_sdk_qsdk_r24d126_godot_energy_authority_development_progression_zero_world.gd"
    QualificationDirectoryPrefix =
        "qsdk-r24d126-godot-jolt-energy-authority-development-progression-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d126_godot_jolt_energy_authority_development_progression_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d126_godot_jolt_energy_authority_development_progression_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d126_godot_jolt_energy_authority_development_progression_zero_world_receipt_v1"
}

& $shared @arguments
exit $LASTEXITCODE
