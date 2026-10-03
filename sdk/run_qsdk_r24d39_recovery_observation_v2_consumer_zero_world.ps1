#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")]
    [string]$Mode = "development",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$sharedRunner = Join-Path $PSScriptRoot `
    "run_qsdk_core_zero_world_qualification.ps1"
& $sharedRunner `
    -Mode $Mode `
    -EvidenceRoot $EvidenceRoot `
    -GateId "QSDK-R24D39" `
    -ContractRelativePath `
        "sdk/recovery/r24d39_recovery_observation_v2_consumer_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d39_recovery_observation_v2_consumer_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D39_RECOVERY_OBSERVATION_V2_CONSUMER_SOURCE_PASS" `
    -PreflightRelativePath `
        "sdk/conformance/r24d39_recovery_observation_v2_consumer.py" `
    -CargoTestFilter "observation_v2" `
    -PythonSmokeTest `
        "sdk.adapters.mujoco.test_recovery_observation_v2_route.RecoveryObservationV2RouteTests.test_complete_route_publishes_source_bound_observation_v2" `
    -VersioningTest `
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report" `
    -QualificationDirectoryPrefix "qsdk-r24d39-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_zero_world_receipt_v1"
