#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")]
    [string]$Mode = "development",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$baseRunner = Join-Path $PSScriptRoot `
    "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1"
& $baseRunner `
    -Mode $Mode `
    -EvidenceRoot $EvidenceRoot `
    -GateId "QSDK-R24D24" `
    -ContractRelativePath `
        "sdk/recovery/r24d24_recovery_context_contact_observer_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d24_recovery_context_contact_observer_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D24_RECOVERY_CONTEXT_CONTACT_OBSERVER_SOURCE_PASS" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d24_recovery_context_observer_worker" `
    -QualificationDirectoryPrefix "qsdk-r24d24-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_zero_world_receipt_v1"
