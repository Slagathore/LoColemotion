#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")][string]$Mode = "development",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$shared = Join-Path $PSScriptRoot "run_qsdk_core_zero_world_qualification.ps1"
$arguments = @{
    Mode = $Mode; EvidenceRoot = $EvidenceRoot; GateId = "QSDK-R24D74"
    ContractRelativePath = "sdk/recovery/r24d74_core_contact_impulse_source_provenance_contract_v1.json"
    ContractSchema = "sporespore_qsdk_r24d74_core_contact_impulse_source_provenance_contract_v1"
    AuditRelativePath = "sdk/conformance/r24d74_core_contact_impulse_source_provenance.py"
    SourceAuditPassMarker = "QSDK_R24D74_CORE_CONTACT_IMPULSE_SOURCE_PROVENANCE_SOURCE_PASS"
    PreflightRelativePath = "sdk/conformance/r24d74_core_contact_impulse_source_provenance.py"
    CargoTestFilter = "contact_impulse_source_provenance_is_explicit_paired_and_strict"
    PythonSmokeTest = "sdk.adapters.mujoco.test_recovery_observation_v2_route.RecoveryObservationV2RouteTests.test_complete_route_publishes_source_bound_observation_v2"
    VersioningTest = "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report"
    QualificationDirectoryPrefix = "qsdk-r24d74-core-contact-impulse-source-provenance-qualification-"
    QualificationAttemptSchema = "sporespore_qsdk_r24d74_core_contact_impulse_source_provenance_zero_world_attempt_v1"
    QualificationFailureSchema = "sporespore_qsdk_r24d74_core_contact_impulse_source_provenance_zero_world_failure_v1"
    QualificationReceiptSchema = "sporespore_qsdk_r24d74_core_contact_impulse_source_provenance_zero_world_receipt_v1"
    ProspectivePhysicalQuestionDeclared = $true
}

& $shared @arguments
exit $LASTEXITCODE
