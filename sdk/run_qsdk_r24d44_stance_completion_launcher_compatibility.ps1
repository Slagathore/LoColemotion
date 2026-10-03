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
    -CoreBuildProfile "release" `
    -GateId "QSDK-R24D44" `
    -CampaignId `
        "QSDK-R24D44-MUJOCO-EXCLUSIVE-STANCE-COMPLETION-LAUNCH-REPAIR" `
    -ContractRelativePath `
        "sdk/recovery/r24d44_stance_completion_launcher_compatibility_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d44-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d44-mujoco-exclusive-stance-completion-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d44_stance_completion_launcher_compatibility_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 1200 `
    -ExpectedPairedArmCount 2
