#requires -Version 7.0

<#
.SYNOPSIS
Thin R69 binding for the shared content-addressed zero-world qualifier.
#>

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")]
    [string]$Mode = "development",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$shared = Join-Path $PSScriptRoot "run_qsdk_core_zero_world_qualification.ps1"
$arguments = @{
    Mode = $Mode
    EvidenceRoot = $EvidenceRoot
    GateId = "QSDK-R24D69"
    ContractRelativePath =
        "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d69_godot_native_effective_impulse_limit.py"
    SourceAuditPassMarker =
        "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d69_godot_native_effective_impulse_limit.py"
    CargoTestFilter =
        "morphology_aware_recovery_entrypoints_fail_closed_through_public_buffer_abi"
    PythonSmokeTest =
        "sdk.adapters.mujoco.test_recovery_observation_v2_route.RecoveryObservationV2RouteTests.test_complete_route_publishes_source_bound_observation_v2"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    QualificationDirectoryPrefix =
        "qsdk-r24d69-godot-native-effective-impulse-limit-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_receipt_v1"
    ProspectivePhysicalQuestionDeclared = $true
}

& $shared @arguments
exit $LASTEXITCODE
