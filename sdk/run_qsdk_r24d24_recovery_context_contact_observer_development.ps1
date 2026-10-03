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
    -GateId "QSDK-R24D24" `
    -CampaignId `
        "QSDK-R24D24-MUJOCO-RECOVERY-CONTEXT-CONTACT-OBSERVER-GHOST" `
    -ContractRelativePath `
        "sdk/recovery/r24d24_recovery_context_contact_observer_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d24-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d24-mujoco-recovery-context-observer-ghost-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d24_recovery_context_observer_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d24_recovery_context_contact_observer_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 2 `
    -ExpectedPairedArmCount 2
