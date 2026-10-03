#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonModuleRoot = Join-Path $sdkRoot "python"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$coreDebug = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$godotWorker = "res://tests/test_sdk_qsdk_r23d34_godot_jolt_physical_worker.gd"
$mujocoWorker = "sporespore_mujoco_adapter.qsdk_r23d34_physical"
$evaluator = Join-Path $sdkRoot "turning\r23d34_native_r23d29_transfer_evaluator.py"
$evaluatorTests = Join-Path $sdkRoot (
    "turning\test_r23d34_native_r23d29_transfer_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d34_supervisor.ps1"
$stageId = "native_r23d29_implementation_repair_transfer"
$arms = @("reference_zero", "positive_heading", "negative_heading")

function Assert-Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D34 $Role role: $Message" }
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
$godotPath = Resolve-Application $Godot
Assert-Role (Test-Path -LiteralPath $coreDebug -PathType Leaf) (
    "debug locomotion core is missing; build the frozen core before attestation"
)
Assert-Role (Test-Path -LiteralPath $mujocoSitePackages -PathType Container) (
    "locked MuJoCo site-packages root is missing: $mujocoSitePackages"
)

$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $campaignPythonPath = (
        @($pythonModuleRoot, $mujocoRoot, $mujocoSitePackages) -join
            [IO.Path]::PathSeparator
    )
    $env:PYTHONPATH = if ([string]::IsNullOrWhiteSpace($savedPythonPath)) {
        $campaignPythonPath
    } else {
        "$campaignPythonPath$([IO.Path]::PathSeparator)$savedPythonPath"
    }
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreDebug

    if ($Role -ceq "worker") {
        foreach ($arm in $arms) {
            $godotOutput = @(
                & $godotPath --headless --path $repoRoot --script $godotWorker -- `
                    --preflight-only --stage $stageId --onset onset_600 --arm $arm 2>&1
            )
            Assert-Role ($LASTEXITCODE -eq 0) ($godotOutput -join "`n")
            Assert-OneMarker $godotOutput "QSDK_R23D34_GODOT_JOLT_PREFLIGHT "

            $mujocoOutput = @(
                & $pythonPath -m $mujocoWorker preflight --stage $stageId `
                    --onset onset_600 --arm $arm 2>&1
            )
            Assert-Role ($LASTEXITCODE -eq 0) ($mujocoOutput -join "`n")
            Assert-OneMarker $mujocoOutput "QSDK_R23D34_MUJOCO_PREFLIGHT "
        }
        Write-Host (
            "QSDK_R23D34_CAMPAIGN_WORKER_ROLE_PASS cells=6 " +
            "models=0 worlds=0 physical=False"
        )
    } elseif ($Role -ceq "evaluator") {
        $tests = @(& $pythonPath $evaluatorTests 2>&1)
        Assert-Role ($LASTEXITCODE -eq 0) ($tests -join "`n")
        $preflight = @(& $pythonPath $evaluator preflight 2>&1)
        Assert-Role ($LASTEXITCODE -eq 0) ($preflight -join "`n")
        Assert-OneMarker $preflight "QSDK_R23D34_EVALUATOR_PREFLIGHT "
        Write-Host (
            "QSDK_R23D34_CAMPAIGN_EVALUATOR_ROLE_PASS cells=6 " +
            "tests=4 mutations=1 models=0 worlds=0 physical=False"
        )
    } else {
        $output = @(
            & pwsh -NoLogo -NoProfile -File $supervisor -PreflightOnly `
                -Python $pythonPath -Godot $godotPath 2>&1
        )
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        Assert-OneMarker $output "QSDK_R23D34_ZERO_WORLD_PASS "
        Write-Host (
            "QSDK_R23D34_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=6 " +
            "models=0 worlds=0 physical=False"
        )
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
