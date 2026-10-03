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
    -GateId "QSDK-R24D28" `
    -CampaignId `
        "QSDK-R24D28-MUJOCO-NATURAL-RECOVERY-PROGRESSION-OBSERVABLE-DEVELOPMENT" `
    -ContractRelativePath `
        "sdk/recovery/r24d28_collection_refusal_observability_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d28-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d28-mujoco-natural-recovery-progression-observable-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d28_collection_refusal_observability_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d28_collection_refusal_observability_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 1200 `
    -ExpectedPairedArmCount 2
