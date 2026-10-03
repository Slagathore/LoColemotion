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
    -GateId "QSDK-R24D37" `
    -ContractRelativePath `
        "sdk/recovery/r24d37_engine_neutral_signed_exchange_ledger_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d37_engine_neutral_signed_exchange_ledger_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D37_ENGINE_NEUTRAL_SIGNED_EXCHANGE_LEDGER_SOURCE_PASS" `
    -PreflightRelativePath "sdk/conformance/r24d37_energy_ledger.py" `
    -CargoTestFilter "recovery_energy" `
    -PythonSmokeTest `
        "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_energy_v2_through_real_dynamic_library" `
    -VersioningTest `
        "sdk.versioning.test_conformance.VersioningConformanceTest.test_manifest_symbols_resolve_from_real_library" `
    -QualificationDirectoryPrefix "qsdk-r24d37-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_zero_world_receipt_v1"
