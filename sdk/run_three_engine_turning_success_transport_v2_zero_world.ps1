#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$python = "C:\Program Files\Python311\python.exe"
$mujocoPython = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"
$supervisor = Join-Path $repoRoot "sdk\turning\three_engine_turning_route_supervisor.py"
$contract = Join-Path $repoRoot "sdk\turning\three_engine_turning_success_transport_route_v2.json"

if (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -cne $repoRoot.Replace("\", "/") -or
    (git -C $repoRoot remote get-url origin).Trim() -cne $expectedRemote -or
    -not (Test-Path -LiteralPath $python -PathType Leaf) -or
    -not (Test-Path -LiteralPath $mujocoPython -PathType Leaf) -or
    -not (Test-Path -LiteralPath $supervisor -PathType Leaf) -or
    -not (Test-Path -LiteralPath $contract -PathType Leaf)
) {
    throw "[turning/transport] repository, runtime, or contract authority is unavailable"
}

$null = Get-Content -Raw -LiteralPath $contract | ConvertFrom-Json
$env:PYTHONDONTWRITEBYTECODE = "1"

& $python -m unittest `
    tests.test_three_engine_turning_route_evaluator `
    tests.test_three_engine_turning_route_supervisor
if ($LASTEXITCODE -ne 0) {
    throw "[turning/transport] Python zero-world tests failed with exit code $LASTEXITCODE"
}

Push-Location (Join-Path $repoRoot "sdk\adapters\mujoco")
try {
    & $mujocoPython -m unittest `
        sporespore_mujoco_adapter.turning_three_engine_route_test
    if ($LASTEXITCODE -ne 0) {
        throw "[turning/transport] MuJoCo zero-world tests failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Push-Location (Join-Path $repoRoot "sdk\adapters\rapier")
try {
    & cargo test --quiet turning_three_engine_route --lib
    if ($LASTEXITCODE -ne 0) {
        throw "[turning/transport] Rapier zero-world tests failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$supervisorOutput = @(& $python $supervisor --timeout-seconds 600 preflight)
if ($LASTEXITCODE -ne 0) {
    throw "[turning/transport] live supervisor preflight failed with exit code $LASTEXITCODE"
}
$marker = "SPORESPORE_TURNING_ROUTE_SUPERVISOR_PREFLIGHT "
$matches = @($supervisorOutput | Where-Object { [string]$_ -like "$marker*" })
if ($matches.Count -ne 1) {
    throw "[turning/transport] expected one live supervisor preflight receipt"
}
$receipt = ([string]$matches[0]).Substring($marker.Length) | ConvertFrom-Json
if (
    [string]$receipt.schema_version -cne
        "sporespore_three_engine_turning_success_transport_supervisor_preflight_v2" -or
    [string]$receipt.route_id -cne
        "sporespore_three_engine_turning_success_transport_route_v2" -or
    -not [bool]$receipt.complete_zero_world_gate_passed -or
    [int]$receipt.process_count -ne 8 -or
    [int]$receipt.worker_preflight_count -ne 3 -or
    [int]$receipt.evaluator_preflight_count -ne 1 -or
    [int]$receipt.authorization_negative_count -ne 3 -or
    [int]$receipt.embedded_negative_control_count -ne 21 -or
    [int]$receipt.total_negative_control_count -ne 24 -or
    [int]$receipt.model_construction_count -ne 0 -or
    [int]$receipt.world_attempt_count -ne 0 -or
    [int]$receipt.world_build_count -ne 0 -or
    [bool]$receipt.physical_execution_authorized -or
    [bool]$receipt.physical_behavior_thresholds_applied -or
    [bool]$receipt.physical_acceptance_authority
) {
    throw "[turning/transport] live supervisor zero-world receipt changed"
}

Write-Host (
    "[turning/transport] PASS v2 complete zero-world gate: " +
    "processes=8 native_preflights=3 negatives=24 models=0 worlds=0"
)
