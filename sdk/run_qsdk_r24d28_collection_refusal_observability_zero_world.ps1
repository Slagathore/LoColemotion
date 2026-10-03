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
    -GateId "QSDK-R24D28" `
    -ContractRelativePath `
        "sdk/recovery/r24d28_collection_refusal_observability_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d28_collection_refusal_observability_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D28_COLLECTION_REFUSAL_OBSERVABILITY_SOURCE_PASS" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d28_collection_refusal_observability_worker" `
    -QualificationDirectoryPrefix "qsdk-r24d28-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_zero_world_receipt_v1"
