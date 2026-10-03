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
$pythonModuleRoot = Join-Path $sdkRoot "python"
$godotAdapterDebug = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$godotWorker = "res://tests/test_sdk_qsdk_r23d35_godot_jolt_physical_worker.gd"
$evaluator = Join-Path $sdkRoot "turning\r23d35_godot_trace_recovery_evaluator.py"
$evaluatorTests = Join-Path $sdkRoot (
    "turning\test_r23d35_godot_trace_recovery_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d35_supervisor.ps1"
$stageId = "godot_r23d29_trace_recovery"
$arms = @("reference_zero", "positive_heading", "negative_heading")

function Assert-Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D35 $Role role: $Message" }
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
Assert-Role (Test-Path -LiteralPath $godotAdapterDebug -PathType Leaf) (
    "debug Godot adapter is missing; build it before attestation"
)

$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $campaignPythonPath = (
        @($pythonModuleRoot, (Join-Path $sdkRoot "turning")) -join
            [IO.Path]::PathSeparator
    )
    $env:PYTHONPATH = if ([string]::IsNullOrWhiteSpace($savedPythonPath)) {
        $campaignPythonPath
    } else {
        "$campaignPythonPath$([IO.Path]::PathSeparator)$savedPythonPath"
    }
    if ($Role -ceq "worker") {
        foreach ($arm in $arms) {
            $godotOutput = @(
                & $godotPath --headless --path $repoRoot --script $godotWorker -- `
                    --preflight-only --stage $stageId --onset onset_600 --arm $arm 2>&1
            )
            Assert-Role ($LASTEXITCODE -eq 0) ($godotOutput -join "`n")
            Assert-OneMarker $godotOutput "QSDK_R23D35_GODOT_JOLT_PREFLIGHT "
        }
        Write-Host (
            "QSDK_R23D35_CAMPAIGN_WORKER_ROLE_PASS cells=3 " +
            "models=0 worlds=0 physical=False"
        )
    } elseif ($Role -ceq "evaluator") {
        $tests = @(& $pythonPath $evaluatorTests 2>&1)
        Assert-Role ($LASTEXITCODE -eq 0) ($tests -join "`n")
        $preflight = @(& $pythonPath $evaluator preflight 2>&1)
        Assert-Role ($LASTEXITCODE -eq 0) ($preflight -join "`n")
        Assert-OneMarker $preflight "QSDK_R23D35_EVALUATOR_PREFLIGHT "
        Write-Host (
            "QSDK_R23D35_CAMPAIGN_EVALUATOR_ROLE_PASS cells=3 " +
            "tests=7 mutations=2 models=0 worlds=0 physical=False"
        )
    } else {
        $output = @(
            & pwsh -NoLogo -NoProfile -File $supervisor -PreflightOnly `
                -Python $pythonPath -Godot $godotPath 2>&1
        )
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        Assert-OneMarker $output "QSDK_R23D35_ZERO_WORLD_PASS "
        Write-Host (
            "QSDK_R23D35_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=3 " +
            "models=0 worlds=0 physical=False"
        )
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
