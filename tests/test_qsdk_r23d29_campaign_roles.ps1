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
$evaluatorTests = Join-Path $sdkRoot (
    "turning\test_r23d29_two_swing_persistent_predictive_stability_guarded_steering_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d29_supervisor.ps1"

function Assert-Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D29 $Role role: $Message" }
}

if ($Role -ceq "worker") {
    $arguments = @(
        "test", "--quiet", "--locked", "--manifest-path", $manifest,
        "-p", "sporespore-rapier-adapter", "--lib",
        "r23d29_persistent_worker"
    )
    $output = @(& cargo @arguments 2>&1)
    Assert-Role ($LASTEXITCODE -eq 0) ($output -join " ")
    Write-Host (
        "QSDK_R23D29_CAMPAIGN_WORKER_ROLE_PASS tests=1 " +
        "models=0 worlds=0 physical=False"
    )
} elseif ($Role -ceq "evaluator") {
    $output = @(& $Python $evaluatorTests 2>&1)
    Assert-Role ($LASTEXITCODE -eq 0) ($output -join " ")
    Write-Host (
        "QSDK_R23D29_CAMPAIGN_EVALUATOR_ROLE_PASS cells=3 " +
        "tests=3 receipt_mutations=1 models=0 worlds=0 physical=False"
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
                "QSDK_R23D29_ZERO_WORLD_PASS ",
                [StringComparison]::Ordinal
            )
        }).Count -eq 1
    ) ($output -join " ")
    Write-Host (
        "QSDK_R23D29_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=3 " +
        "models=0 worlds=0 physical=False"
    )
}
