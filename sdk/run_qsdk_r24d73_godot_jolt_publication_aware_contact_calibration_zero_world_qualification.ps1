#requires -Version 7.0

<#
.SYNOPSIS
Thin R73 binding for the shared content-addressed zero-world qualifier.
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
    GateId = "QSDK-R24D73"
    ContractRelativePath =
        "sdk/recovery/r24d73_godot_jolt_publication_aware_contact_calibration_contract_v1.json"
    ContractSchema =
        "sporespore_qsdk_r24d73_godot_jolt_publication_aware_contact_calibration_contract_v1"
    AuditRelativePath =
        "sdk/conformance/r24d73_godot_jolt_publication_aware_contact_calibration.py"
    SourceAuditPassMarker =
        "QSDK_R24D73_GODOT_JOLT_PUBLICATION_AWARE_CONTACT_CALIBRATION_SOURCE_PASS"
    PreflightRelativePath =
        "sdk/conformance/r24d73_godot_jolt_publication_aware_contact_calibration.py"
    CargoTestFilter =
        "collector_mutations_fail_closed_without_world_side_effects"
    PythonSmokeTest =
        "sdk.adapters.mujoco.test_recovery_observation_v2_route.RecoveryObservationV2RouteTests.test_complete_route_publishes_source_bound_observation_v2"
    VersioningTest =
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    QualificationDirectoryPrefix =
        "qsdk-r24d73-godot-jolt-publication-aware-contact-calibration-qualification-"
    QualificationAttemptSchema =
        "sporespore_qsdk_r24d73_godot_publication_aware_contact_calibration_zero_world_attempt_v1"
    QualificationFailureSchema =
        "sporespore_qsdk_r24d73_godot_publication_aware_contact_calibration_zero_world_failure_v1"
    QualificationReceiptSchema =
        "sporespore_qsdk_r24d73_godot_publication_aware_contact_calibration_zero_world_receipt_v1"
    ProspectivePhysicalQuestionDeclared = $true
}

& $shared @arguments
exit $LASTEXITCODE
