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
    -GateId "QSDK-R24D23" `
    -CampaignId "QSDK-R24D23-MUJOCO-RECOVERY-MORPHOLOGY-ROUTE-GHOST" `
    -ContractRelativePath `
        "sdk/recovery/r24d23_mujoco_recovery_morphology_route_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d23_mujoco_recovery_morphology_route_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d23-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d23-mujoco-recovery-morphology-ghost-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d23_mujoco_recovery_morphology_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d23_recovery_morphology_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d23_recovery_morphology_ghost_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d23_recovery_morphology_ghost_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 2 `
    -ExpectedPairedArmCount 2
