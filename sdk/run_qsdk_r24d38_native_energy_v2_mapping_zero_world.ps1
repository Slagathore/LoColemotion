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
    -GateId "QSDK-R24D38" `
    -ContractRelativePath `
        "sdk/recovery/r24d38_native_energy_v2_mapping_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d38_native_energy_v2_mapping_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d38_native_energy_v2_mapping_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D38_NATIVE_ENERGY_V2_MAPPING_SOURCE_PASS" `
    -PreflightRelativePath `
        "sdk/conformance/r24d38_recovery_energy_mapping.py" `
    -CargoTestFilter "recovery_energy" `
    -PythonSmokeTest `
        "sdk.adapters.mujoco.test_recovery_energy_v2_mapping.RecoveryEnergyV2MappingTests.test_signed_components_map_in_order_and_publish_observation_v2" `
    -VersioningTest `
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_complete_v0_v6_report" `
    -QualificationDirectoryPrefix "qsdk-r24d38-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d38_native_energy_v2_mapping_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d38_native_energy_v2_mapping_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d38_native_energy_v2_mapping_zero_world_receipt_v1"
