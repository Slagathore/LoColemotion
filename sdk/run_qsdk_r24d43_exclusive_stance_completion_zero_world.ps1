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
    -CoreBuildProfile "release" `
    -GateId "QSDK-R24D43" `
    -ContractRelativePath `
        "sdk/recovery/r24d43_exclusive_stance_completion_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d43_exclusive_stance_completion_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d43_exclusive_stance_completion_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D43_EXCLUSIVE_STANCE_COMPLETION_SOURCE_PASS" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d43_exclusive_stance_completion_worker" `
    -QualificationDirectoryPrefix "qsdk-r24d43-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d43_exclusive_stance_completion_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d43_exclusive_stance_completion_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d43_exclusive_stance_completion_zero_world_receipt_v1"
