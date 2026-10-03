#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [string]$QualificationReceiptPath = ""
)

$ErrorActionPreference = "Stop"
$baseRunner = Join-Path $PSScriptRoot `
    "run_qsdk_r24d18_mujoco_native_recovery_development.ps1"
& $baseRunner `
    -EvidenceRoot $EvidenceRoot `
    -QualificationReceiptPath $QualificationReceiptPath `
    -GateId "QSDK-R24D26" `
    -CampaignId `
        "QSDK-R24D26-MUJOCO-FIRST-ACTIVE-RECOVERY-COMMAND-GHOST" `
    -ContractRelativePath `
        "sdk/recovery/r24d26_active_receipt_serialization_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d26_active_receipt_serialization_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d26-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d26-mujoco-first-active-command-ghost-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d26_active_receipt_serialization_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d26_active_receipt_serialization_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d26_active_receipt_serialization_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d26_active_receipt_serialization_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 13 `
    -ExpectedPairedArmCount 2
