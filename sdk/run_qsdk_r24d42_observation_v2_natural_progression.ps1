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
    -GateId "QSDK-R24D42" `
    -CampaignId `
        "QSDK-R24D42-MUJOCO-OBSERVATION-V2-NATURAL-RECOVERY-PROGRESSION" `
    -ContractRelativePath `
        "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d42-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d42-mujoco-observation-v2-natural-progression-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d42_observation_v2_natural_progression_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d42_observation_v2_natural_progression_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d42_observation_v2_natural_progression_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 1200 `
    -ExpectedPairedArmCount 2
