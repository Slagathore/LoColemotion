#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonRoot = Join-Path $sdkRoot "python"
$turningRoot = Join-Path $sdkRoot "turning"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$library = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$manifest = Join-Path $sdkRoot "Cargo.toml"
$module = "sporespore_mujoco_adapter.qsdk_r23d17_physical"
$stageId = "finite_three_engine_confirmation_live_composition_recovery"
$campaignId = "QSDK-R23D17-LIVE-COMPOSITION-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION"

function Assert-R23D17Mujoco([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D17Mujoco([string[]]$Arguments, [string]$Label) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $python
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["SPORESPORE_LOCOMOTION_LIBRARY"] = $library
    $start.Environment["PYTHONPATH"] = (
        $mujocoRoot + [IO.Path]::PathSeparator +
        $pythonRoot + [IO.Path]::PathSeparator +
        $turningRoot
    )
    [void]$start.ArgumentList.Add("-m")
    [void]$start.ArgumentList.Add($module)
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D17Mujoco $process.Start() "MuJoCo process did not start: $Label"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(60000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    return [ordered]@{
        label = $Label
        exit_code = $process.ExitCode
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Read-R23D17MujocoMarker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.stdout -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D17Mujoco ($matches.Count -eq 1) (
        "Expected one $Prefix marker from $($Execution.label): " +
        [string]$Execution.stderr
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $python,
    $manifest,
    (Join-Path $mujocoRoot "sporespore_mujoco_adapter\qsdk_r23d17_physical.py"),
    (Join-Path $mujocoRoot "test_qsdk_r23d17_physical.py"),
    (Join-Path $mujocoRoot "test_qsdk_r23d14_tight_gated_horizon.py")
)) {
    Assert-R23D17Mujoco (Test-Path -LiteralPath $path -PathType Leaf) (
        "MuJoCo input missing: $path"
    )
}
Assert-R23D17Mujoco (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "MuJoCo repository identity changed"

& cargo build --quiet --release --locked --offline `
    --manifest-path $manifest --package sporespore-locomotion-core
Assert-R23D17Mujoco ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $library)) (
    "MuJoCo public core build failed"
)

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $library
    $env:PYTHONPATH = (
        $mujocoRoot + [IO.Path]::PathSeparator +
        $pythonRoot + [IO.Path]::PathSeparator +
        $turningRoot
    )
    $unitOutput = & $python -m unittest -v `
        test_qsdk_r23d14_tight_gated_horizon `
        test_qsdk_r23d17_physical 2>&1 | Out-String
    Assert-R23D17Mujoco ($LASTEXITCODE -eq 0) "MuJoCo tests failed: $unitOutput"
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D17Mujoco @(
        "preflight", "--stage-id", $stageId, "--arm-id", $armId
    ) "$stageId`:$armId"
    Assert-R23D17Mujoco (-not $execution.timed_out -and $execution.exit_code -eq 0) (
        "MuJoCo preflight failed: $armId"
    )
    $receipt = Read-R23D17MujocoMarker $execution "QSDK_R23D17_MUJOCO_PREFLIGHT "
    Assert-R23D17Mujoco (
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.cell_id -ceq "mujoco__tight_gated_horizon__$armId" -and
        [bool]$receipt.r23d14_tight_gated_horizon_inherited_unchanged -and
        [bool]$receipt.r23d17_composition_recovery_identity_enabled -and
        [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "MuJoCo preflight receipt changed: $armId"
}

$refusal = Invoke-R23D17Mujoco @(
    "physical", "--stage-id", $stageId, "--arm-id", "positive_heading",
    "--source-commit", $sourceCommit
) "physical-refusal"
Assert-R23D17Mujoco (-not $refusal.timed_out -and $refusal.exit_code -ne 0) (
    "MuJoCo physical route did not refuse"
)
$terminal = Read-R23D17MujocoMarker $refusal "QSDK_R23D17_TERMINAL "
Assert-R23D17Mujoco (
    [string]$terminal.failure_code -ceq "QSDK_R23D17_MJC_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "MuJoCo physical refusal changed"

Write-Host (
    "QSDK_R23D17_MUJOCO_WORKER_PASS identities=3 tests=8 " +
    "temporal_steps=960 models=0 worlds=0 physical_authority=False"
)
