#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot "turning\physical_development_contract_v1.json"
$modulePath = Join-Path $sdkRoot "turning\physical_development.py"
$testPath = Join-Path $sdkRoot "turning\test_physical_development.py"

foreach ($requiredPath in @($contractPath, $modulePath, $testPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "QSDK-R23D1 preflight input missing: $requiredPath"
    }
}

$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -AsHashtable
$physicalAuthorized = $contract.authorization.physical_execution_authorized
$expectedStatus = if ($physicalAuthorized -is [bool] -and [bool]$physicalAuthorized) {
    "frozen_physical_authorization_pending_exact_source_attestation"
} else {
    "implemented_prephysical_development_contract"
}
if (
    [string]$contract.schema_version -cne
        "sporespore_qsdk_r23d1_physical_development_contract_v1" -or
    [string]$contract.status -cne $expectedStatus -or
    [string]$contract.gate_id -cne "QSDK-R23D1" -or
    [string]$contract.release_gate_id -cne "QSDK-R23" -or
    -not ($contract.authorization.physical_execution_authorized -is [bool]) -or
    [bool]$contract.authorization.q_sdk_r23_satisfied
) {
    throw "QSDK-R23D1 contract identity or authorization boundary invalid"
}

$testOutput = & python -m unittest -v sdk.turning.test_physical_development 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D1 Python tests failed:`n$testOutput"
}

$receiptText = & python $modulePath 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D1 zero-world design preflight failed:`n$receiptText"
}
$prefix = "QSDK_R23D1_ZERO_WORLD_DESIGN "
$lines = @($receiptText -split "\r?\n" | Where-Object { $_.StartsWith($prefix) })
if ($lines.Count -ne 1) {
    throw "QSDK-R23D1 expected one design receipt, found $($lines.Count)"
}
$receipt = $lines[0].Substring($prefix.Length) | ConvertFrom-Json -AsHashtable
if (
    [int]$receipt.declared_engine_count -ne 3 -or
    [int]$receipt.declared_arm_count -ne 3 -or
    [int]$receipt.declared_cell_count -ne 9 -or
    [int]$receipt.schedule_boundary_check_count -ne 21 -or
    [int]$receipt.perfect_cell_pass_count -ne 9 -or
    -not [bool]$receipt.perfect_aggregate_passed -or
    [int]$receipt.cell_negative_control_count -ne 26 -or
    [int]$receipt.cell_negative_control_rejection_count -ne 26 -or
    [int]$receipt.aggregate_negative_control_count -ne 3 -or
    [int]$receipt.aggregate_negative_control_rejection_count -ne 3 -or
    [int]$receipt.actual_engine_worker_count -ne 3 -or
    [int]$receipt.actual_worker_entrypoint_count_exercised_by_design_preflight -ne 0 -or
    [int]$receipt.world_build_count -ne 0 -or
    [int]$receipt.physical_process_launch_count -ne 0 -or
    [bool]$receipt.physical_execution_authorized -ne [bool]$physicalAuthorized -or
    [bool]$receipt.q_sdk_r23_satisfied -or
    [bool]$receipt.command_conditioned_turning -or
    [bool]$receipt.cross_engine_equivalence -or
    [bool]$receipt.release_authorized -or
    [bool]$receipt.physical_acceptance_authority
) {
    throw "QSDK-R23D1 zero-world design receipt failed strict reconciliation"
}

Write-Host (
    "QSDK_R23D1_DESIGN_PASS engines=3 arms=3 cells=9 " +
    "schedule_checks=21 perfect=9/9 cell_negative_controls=26/26 " +
    "aggregate_negative_controls=3/3 commissioned_workers=3 " +
    "design_worker_entrypoints=0 worlds=0 " +
    "physical_authorized=$([bool]$physicalAuthorized) q_sdk_r23=False release=False"
)
