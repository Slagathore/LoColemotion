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
    -GateId "QSDK-R24D35" `
    -CampaignId "QSDK-R24D35-MUJOCO-SPARSE-ACTUATOR-MOMENT" `
    -ContractRelativePath `
        "sdk/recovery/r24d35_mujoco_sparse_actuator_moment_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d35-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d35-mujoco-sparse-actuator-moment-smoke-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d35_sparse_actuator_moment_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d35_sparse_actuator_moment_smoke_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d35_sparse_actuator_moment_smoke_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 2 `
    -ExpectedPairedArmCount 2
