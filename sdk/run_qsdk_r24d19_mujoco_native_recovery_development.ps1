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
    -GateId "QSDK-R24D19" `
    -CampaignId `
        "QSDK-R24D19-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST" `
    -ContractRelativePath `
        "sdk/recovery/r24d19_public_profile_validator_successor_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d19_public_profile_validator_successor_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d19-qualification-" `
    -PhysicalDirectoryPrefix "qsdk-r24d19-mujoco-recovery-ghost-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d19_mujoco_recovery_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d19_recovery_development_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d19_recovery_ghost_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d19_recovery_ghost_supervisor_completion_v1"
