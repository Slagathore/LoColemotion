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
    GateId = "QSDK-R24D96"
    ContractRelativePath =
        "sdk/recovery/r24d96_godot_jolt_nested_guarded_recovery_route_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_recovery_route_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d96_godot_jolt_nested_guarded_recovery_route.py"
    SourceAuditPassMarker =
        "QSDK_R24D96_GODOT_JOLT_NESTED_GUARDED_ROUTE_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d96_godot_jolt_nested_guarded_recovery_route.py"
    CargoTestFilter =
        "complete_active_recovery_population_has_transport_stable_command_identity"
    PythonSmokeTest =
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    QualificationDirectoryPrefix =
        "qsdk-r24d96-godot-jolt-nested-guarded-route-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_route_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_route_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_route_zero_world_receipt_v1"
    ProspectivePhysicalQuestionDeclared = $true
}

& $shared @arguments
exit $LASTEXITCODE
