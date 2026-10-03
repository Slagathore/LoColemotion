#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$manifest = Join-Path $sdkRoot "Cargo.toml"
$oracleTests = Join-Path $sdkRoot "turning\test_r23d31_cycle_integrated_measurement.py"
$evaluatorTests = Join-Path $sdkRoot (
    "turning\test_r23d32_finite_rapier_turning_replication_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d32_supervisor.ps1"

function Assert-Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D32 $Role role: $Message" }
}

if ($Role -ceq "worker") {
    $output = @(
        & cargo test --quiet --locked --manifest-path $manifest `
            -p sporespore-rapier-adapter --lib r23d32_turning_replication_worker 2>&1
    )
    Assert-Role ($LASTEXITCODE -eq 0) ($output -join " ")
    Write-Host (
        "QSDK_R23D32_CAMPAIGN_WORKER_ROLE_PASS tests=1 " +
        "models=0 worlds=0 physical=False"
    )
} elseif ($Role -ceq "evaluator") {
    $oracle = @(& $Python $oracleTests 2>&1)
    Assert-Role ($LASTEXITCODE -eq 0) ($oracle -join " ")
    $evaluator = @(& $Python $evaluatorTests 2>&1)
    Assert-Role ($LASTEXITCODE -eq 0) ($evaluator -join " ")
    Write-Host (
        "QSDK_R23D32_CAMPAIGN_EVALUATOR_ROLE_PASS cells=3 " +
        "tests=9 mutations=12 models=0 worlds=0 physical=False"
    )
} else {
    $output = @(
        & pwsh -NoLogo -NoProfile -File $supervisor `
            -PreflightOnly -Python $Python 2>&1
    )
    Assert-Role (
        $LASTEXITCODE -eq 0 -and
        @($output | Where-Object {
            ([string]$_).StartsWith(
                "QSDK_R23D32_ZERO_WORLD_PASS ",
                [StringComparison]::Ordinal
            )
        }).Count -eq 1
    ) ($output -join " ")
    Write-Host (
        "QSDK_R23D32_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=3 " +
        "models=0 worlds=0 physical=False"
    )
}
