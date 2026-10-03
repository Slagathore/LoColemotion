#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")][string]$Mode = "development",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$contractRelative =
    "sdk/recovery/r24d93_godot_jolt_native_engine_health_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$shared = Join-Path $PSScriptRoot "run_qsdk_core_zero_world_qualification.ps1"
$arguments = @{
    Mode = $Mode
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D93"
    ContractRelativePath = $contractRelative
    ContractSchema =
        "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d93_godot_jolt_native_engine_health.py"
    SourceAuditPassMarker =
        "QSDK_R24D93_GODOT_JOLT_NATIVE_ENGINE_HEALTH_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d93_godot_jolt_native_engine_health.py"
    CargoTestFilter =
        "complete_active_recovery_population_has_transport_stable_command_identity"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    QualificationDirectoryPrefix =
        "qsdk-r24d93-godot-jolt-native-engine-health-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_zero_world_receipt_v1"
    NativeZeroWorldRuntimePath = [string]$contract.exact_runtime.console_path
    NativeZeroWorldScriptRelativePath =
        "tests/test_sdk_godot_jolt_native_engine_health_zero_world.gd"
    NativeZeroWorldPassMarker =
        "SPORESPORE_GODOT_JOLT_NATIVE_ENGINE_HEALTH_ZERO_WORLD "
    GodotParseScriptRelativePath =
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
}

& $shared @arguments
exit $LASTEXITCODE
