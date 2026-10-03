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
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$pythonModuleRoot = Join-Path $sdkRoot "python"
$turningRoot = Join-Path $sdkRoot "turning"
$coreDebug = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$evaluator = Join-Path $turningRoot (
    "r23d36_mujoco_bw19v_walking_restoration_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d36_supervisor.ps1"
$stageId = "mujoco_r23d29_bw19v_walking_restoration"

function Assert-Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D36 $Role role: $Message" }
}

function Resolve-Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-Role (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Assert-OneMarker([object[]]$Output, [string]$Prefix) {
    $matches = @($Output | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-Role ($matches.Count -eq 1) ($Output -join "`n")
}

$pythonPath = Resolve-Application $Python
Assert-Role (Test-Path -LiteralPath $coreDebug -PathType Leaf) (
    "debug locomotion core is missing; build it before attestation"
)
Assert-Role (Test-Path -LiteralPath $mujocoSitePackages -PathType Container) (
    "locked MuJoCo site-packages are missing"
)

$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = (@(
        $pythonModuleRoot,
        $mujocoRoot,
        $mujocoSitePackages,
        $turningRoot
    ) -join [IO.Path]::PathSeparator)
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreDebug
    if ($Role -ceq "worker") {
        $output = @(
            & $pythonPath -m `
                sporespore_mujoco_adapter.qsdk_r23d36_bw19v_walking_restoration `
                preflight --stage $stageId --onset onset_600 `
                --arm reference_zero 2>&1
        )
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        Assert-OneMarker $output "QSDK_R23D36_MUJOCO_PREFLIGHT "
        Write-Host (
            "QSDK_R23D36_CAMPAIGN_WORKER_ROLE_PASS cells=1 " +
            "composition_canaries=1 mutations=1 models=0 worlds=0 physical=False"
        )
    } elseif ($Role -ceq "evaluator") {
        $output = @(& $pythonPath $evaluator preflight 2>&1)
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        Assert-OneMarker $output "QSDK_R23D36_EVALUATOR_PREFLIGHT "
        Write-Host (
            "QSDK_R23D36_CAMPAIGN_EVALUATOR_ROLE_PASS cells=1 " +
            "trace_canaries=1 mutations=2 models=0 worlds=0 physical=False"
        )
    } else {
        $output = @(
            & pwsh -NoLogo -NoProfile -File $supervisor -PreflightOnly `
                -Python $pythonPath 2>&1
        )
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        Assert-OneMarker $output "QSDK_R23D36_ZERO_WORLD_PASS "
        Write-Host (
            "QSDK_R23D36_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=1 " +
            "models=0 worlds=0 physical=False"
        )
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
