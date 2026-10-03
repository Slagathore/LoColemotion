#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")]
    [string]$Mode = "development",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$baseRunner = Join-Path $PSScriptRoot `
    "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1"
& $baseRunner `
    -Mode $Mode `
    -EvidenceRoot $EvidenceRoot `
    -GateId "QSDK-R24D41" `
    -ContractRelativePath `
        "sdk/recovery/r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1.json" `
    -ContractSchema `
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1" `
    -AuditRelativePath `
        "tests/test_qsdk_r24d41_observation_v2_morphology_smoke_source.py" `
    -SourceAuditPassMarker `
        "QSDK_R24D41_OBSERVATION_V2_MORPHOLOGY_SMOKE_SOURCE_PASS" `
    -WorkerModule `
        "sporespore_mujoco_adapter.qsdk_r24d41_observation_v2_morphology_smoke_worker" `
    -QualificationDirectoryPrefix "qsdk-r24d41-qualification-" `
    -QualificationAttemptSchema `
        "sporespore_qsdk_r24d41_observation_v2_morphology_smoke_zero_world_attempt_v1" `
    -QualificationFailureSchema `
        "sporespore_qsdk_r24d41_observation_v2_morphology_smoke_zero_world_failure_v1" `
    -QualificationReceiptSchema `
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_smoke_zero_world_receipt_v1"
