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
$rapierManifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$evaluatorTests = Join-Path $sdkRoot (
    "turning\test_r23d49_rapier_retention_repair_replay_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d49_supervisor.ps1"

function Assert-R23D49Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D49 $Role role: $Message" }
}

if ($Role -ceq "worker") {
    $output = @(& cargo test --quiet --locked --offline `
        --manifest-path $rapierManifest r23d49_ 2>&1)
    Assert-R23D49Role ($LASTEXITCODE -eq 0) ($output -join "`n")
    Write-Host (
        "QSDK_R23D49_CAMPAIGN_WORKER_ROLE_PASS tests=2 " +
        "models=0 worlds=0 physical=False"
    )
} elseif ($Role -ceq "evaluator") {
    $output = @(& $Python $evaluatorTests 2>&1)
    Assert-R23D49Role ($LASTEXITCODE -eq 0) ($output -join "`n")
    Write-Host (
        "QSDK_R23D49_CAMPAIGN_EVALUATOR_ROLE_PASS tests=3 " +
        "bypass_wiring=True models=0 worlds=0 physical=False"
    )
} else {
    $output = @(& pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass `
        -File $supervisor -PreflightOnly -Python $Python 2>&1)
    Assert-R23D49Role (
        $LASTEXITCODE -eq 0 -and
        @($output | Where-Object {
            ([string]$_).StartsWith(
                "QSDK_R23D49_ZERO_WORLD_PASS ",
                [StringComparison]::Ordinal
            )
        }).Count -eq 1
    ) ($output -join "`n")
    Write-Host (
        "QSDK_R23D49_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=3 " +
        "focused_gate=True models=0 worlds=0 physical=False"
    )
}
