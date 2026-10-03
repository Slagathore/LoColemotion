[CmdletBinding()]
param(
    [string]$Python = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$expectedRoot = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
if ($repoRoot -cne $expectedRoot) {
    throw "QSDK-R23D65 MuJoCo worker repository root changed: $repoRoot"
}
$gitRoot = [System.IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
if ($LASTEXITCODE -ne 0 -or $gitRoot -cne $expectedRoot) {
    throw "QSDK-R23D65 MuJoCo worker canonical Git root changed: $gitRoot"
}
$remote = (& git -C $repoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $remote -cne $expectedRemote) {
    throw "QSDK-R23D65 MuJoCo worker origin changed: $remote"
}
if ([string]::IsNullOrWhiteSpace($Python)) {
    $Python = Join-Path (
        $repoRoot
    ) "sdk\adapters\mujoco\.venv\Scripts\python.exe"
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw "QSDK-R23D65 MuJoCo pinned Python is missing: $Python"
}

$adapterRoot = Join-Path $repoRoot "sdk\adapters\mujoco"
$unitTest = Join-Path (
    $adapterRoot
) "sporespore_mujoco_adapter\qsdk_r23d65_selected_profile_turning_test.py"
$routeGate = Join-Path (
    $repoRoot
) "tests\test_qsdk_r23d65_mujoco_public_profile_physical_route.ps1"

& $Python $unitTest
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D65 MuJoCo worker unit audit failed: $LASTEXITCODE"
}
& $routeGate -Python $Python
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D65 MuJoCo production route gate failed: $LASTEXITCODE"
}

$module = "sporespore_mujoco_adapter.qsdk_r23d65_selected_profile_turning"
$stage = "runtime_integration_repaired_selected_profile_matched_three_engine_turning_validation"
$onset = "onset_600"
$seed = "23175"
$profile = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$sourceCommit = "0000000000000000000000000000000000000000"
$preflightMarker = "QSDK_R23D65_MUJOCO_PREFLIGHT "

function Invoke-Worker {
    param([string[]]$Arguments)
    $prior = Get-Location
    try {
        Set-Location -LiteralPath $adapterRoot
        $output = @(& $Python -m $module @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        Set-Location -LiteralPath $prior
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines = $output
        Text = ($output -join "`n")
    }
}

$arms = @(
    [pscustomobject]@{ Id = "reference_zero"; Offset = 0.0 },
    [pscustomobject]@{ Id = "positive_heading"; Offset = 0.2 },
    [pscustomobject]@{ Id = "negative_heading"; Offset = -0.2 }
)
$preflightCount = 0
foreach ($arm in $arms) {
    $result = Invoke-Worker -Arguments @(
        "preflight",
        "--stage", $stage,
        "--onset", $onset,
        "--campaign-seed", $seed,
        "--profile", $profile,
        "--arm", $arm.Id
    )
    if ($result.ExitCode -ne 0) {
        throw "QSDK-R23D65 MuJoCo preflight failed for $($arm.Id): $($result.Text)"
    }
    $markers = @(
        $result.Lines |
            ForEach-Object { [string]$_ } |
            Where-Object { $_.StartsWith($preflightMarker) }
    )
    if ($markers.Count -ne 1) {
        throw "QSDK-R23D65 MuJoCo preflight marker invalid for $($arm.Id)"
    }
    $receipt = $markers[0].Substring($preflightMarker.Length) | ConvertFrom-Json
    if (
        $receipt.cell_id -cne "mujoco__s23175__selected_profile__$($arm.Id)" -or
        [double]$receipt.turn_heading_offset_rad -ne [double]$arm.Offset -or
        [int]$receipt.fixed_controller_horizon_step_count -ne 2992 -or
        [int]$receipt.model_construction_count -ne 0 -or
        [int]$receipt.world_attempt_count -ne 0 -or
        [int]$receipt.world_build_count -ne 0 -or
        [bool]$receipt.physical_execution_authorized
    ) {
        throw "QSDK-R23D65 MuJoCo preflight receipt invalid for $($arm.Id)"
    }
    $preflightCount++
}

$controls = @(
    @("preflight", "--stage", "wrong", "--onset", $onset, "--campaign-seed", $seed, "--profile", $profile, "--arm", "reference_zero"),
    @("preflight", "--stage", $stage, "--onset", "onset_601", "--campaign-seed", $seed, "--profile", $profile, "--arm", "reference_zero"),
    @("preflight", "--stage", $stage, "--onset", $onset, "--campaign-seed", "23168", "--profile", $profile, "--arm", "reference_zero"),
    @("preflight", "--stage", $stage, "--onset", $onset, "--campaign-seed", $seed, "--profile", "wrong", "--arm", "reference_zero"),
    @("preflight", "--stage", $stage, "--onset", $onset, "--campaign-seed", $seed, "--profile", $profile, "--arm", "wrong"),
    @("authorization-preflight", "--stage", $stage, "--onset", $onset, "--campaign-seed", $seed, "--profile", $profile, "--arm", "reference_zero", "--source-commit", $sourceCommit),
    @("physical", "--stage", $stage, "--onset", $onset, "--campaign-seed", $seed, "--profile", $profile, "--arm", "reference_zero", "--source-commit", $sourceCommit),
    @("authorization-preflight", "--stage", $stage, "--onset", $onset, "--campaign-seed", $seed, "--profile", $profile, "--arm", "reference_zero", "--source-commit", "bad"),
    @("preflight", "--stage", $stage, "--onset", $onset, "--campaign-seed", $seed, "--arm", "reference_zero"),
    @("preflight", "--stage", $stage, "--onset", $onset, "--campaign-seed", "not-an-integer", "--profile", $profile, "--arm", "reference_zero"),
    @("wrong-command", "--stage", $stage, "--onset", $onset, "--campaign-seed", $seed, "--profile", $profile, "--arm", "reference_zero")
)
$mutationRejections = 0
foreach ($arguments in $controls) {
    $result = Invoke-Worker -Arguments $arguments
    if ($result.ExitCode -eq 0) {
        throw "QSDK-R23D65 MuJoCo negative control was accepted: $($arguments -join ' ')"
    }
    $terminalMarkers = @(
        $result.Lines |
            ForEach-Object { [string]$_ } |
            Where-Object {
                $_.StartsWith("QSDK_R23D65_MUJOCO_TERMINAL ")
            }
    )
    foreach ($marker in $terminalMarkers) {
        $receipt = $marker.Substring(
            "QSDK_R23D65_MUJOCO_TERMINAL ".Length
        ) | ConvertFrom-Json
        if (
            $receipt.PSObject.Properties.Name -contains "world_attempt_count" -and
            [int]$receipt.world_attempt_count -ne 0
        ) {
            throw "QSDK-R23D65 MuJoCo control attempted a world"
        }
        if (
            $receipt.PSObject.Properties.Name -contains "world_build_count" -and
            [int]$receipt.world_build_count -ne 0
        ) {
            throw "QSDK-R23D65 MuJoCo control built a world"
        }
    }
    $mutationRejections++
}
if ($preflightCount -ne 3 -or $mutationRejections -ne 11) {
    throw (
        "QSDK-R23D65 MuJoCo worker cardinality invalid: " +
        "preflights=$preflightCount mutations=$mutationRejections"
    )
}

Write-Output (
    "QSDK_R23D65_MUJOCO_PHYSICAL_WORKER_PASS " +
    "cells=3 mutations=11 models=0 worlds=0 physical=False " +
    "turning=False qsdk_r23=False release=False"
)
