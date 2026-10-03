#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$dependencyMarkerPath = Join-Path $PSScriptRoot (
    "test_qsdk_r23d9_dependency_and_marker_contract.ps1"
)

function Assert-R23D9StageTwo {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-R23D9StageTwo (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 stage-two repository identity mismatch"

Push-Location -LiteralPath $turningRoot
try {
    & python -m unittest -v `
        test_r23d9_physical_trace.py `
        test_r23d9_physical_evaluator.py
    Assert-R23D9StageTwo ($LASTEXITCODE -eq 0) (
        "QSDK-R23D9 stage-two trace/evaluator tests failed"
    )
} finally {
    Pop-Location
}

& $dependencyMarkerPath
Assert-R23D9StageTwo ($LASTEXITCODE -eq 0) (
    "QSDK-R23D9 stage-two dependency/marker tests failed"
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d9_stage_two_evidence_gate_v1"
    trace_test_count = 5
    evaluator_test_count = 8
    dependency_removal_canary_count = 4
    dependency_structural_canary_count = 5
    terminal_marker_family_count = 3
    terminal_marker_case_count = 15
    exit_marker_pairing_canary_count = 6
    pre_retention_interpretation_refusal_count = 1
    physical_worker_implementation_count = 0
    supervisor_implementation_count = 0
    physical_process_launch_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D9_STAGE_TWO_EVIDENCE " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
