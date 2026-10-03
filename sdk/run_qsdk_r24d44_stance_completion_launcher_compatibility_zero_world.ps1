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
    -GateId "QSDK-R24D44" `
    -ContractRelativePath `
        "sdk/recovery/r24d44_stance_completion_launcher_compatibility_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d44_stance_completion_launcher_compatibility_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D44_STANCE_COMPLETION_LAUNCHER_COMPATIBILITY_SOURCE_PASS" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d44_stance_completion_launcher_compatibility_worker" `
    -QualificationDirectoryPrefix "qsdk-r24d44-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_zero_world_receipt_v1"
