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
    -GateId "QSDK-R24D41" `
    -CampaignId `
        "QSDK-R24D41-MUJOCO-RECOVERY-MORPHOLOGY-OBSERVATION-V2-SMOKE" `
    -ContractRelativePath `
        "sdk/recovery/r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d41-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d41-mujoco-observation-v2-morphology-smoke-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_smoke_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d41_observation_v2_morphology_smoke_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d41_observation_v2_morphology_smoke_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d41_observation_v2_morphology_smoke_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 1 `
    -ExpectedPairedArmCount 2
