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
    -GateId "QSDK-R24D20" `
    -CampaignId `
        "QSDK-R24D20-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST" `
    -ContractRelativePath `
        "sdk/recovery/r24d20_production_timestep_identity_successor_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d20_production_timestep_identity_successor_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d20-qualification-" `
    -PhysicalDirectoryPrefix "qsdk-r24d20-mujoco-recovery-ghost-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d20_mujoco_recovery_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d20_recovery_development_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d20_recovery_ghost_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d20_recovery_ghost_supervisor_completion_v1"
