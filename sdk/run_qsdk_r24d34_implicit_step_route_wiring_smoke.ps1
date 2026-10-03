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
    -GateId "QSDK-R24D34" `
    -CampaignId "QSDK-R24D34-MUJOCO-IMPLICIT-STEP-ROUTE-WIRING" `
    -ContractRelativePath `
        "sdk/recovery/r24d34_mujoco_implicit_step_route_wiring_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_contract_v1" `
    -QualificationDirectoryPrefix "qsdk-r24d34-qualification-" `
    -PhysicalDirectoryPrefix `
        "qsdk-r24d34-mujoco-implicit-step-route-smoke-" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_zero_world_receipt_v1" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d34_implicit_step_route_wiring_worker" `
    -AttemptReservationSchema `
        "sporespore_qsdk_r24d34_implicit_step_route_smoke_attempt_reservation_v1" `
    -SupervisorCompletionSchema `
        "sporespore_qsdk_r24d34_implicit_step_route_smoke_supervisor_completion_v1" `
    -ExpectedCellId "development_recovery_morphology_nominal" `
    -ExpectedSeed 1129522465 `
    -ExpectedHorizonSteps 2 `
    -ExpectedPairedArmCount 2
