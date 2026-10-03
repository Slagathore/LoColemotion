#requires -Version 7.0

param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$worker = "res://tests/test_sdk_qsdk_r23d10_quiescent_taper_godot_jolt_worker.gd"

function Assert-R23D10Godot([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D10Godot([string[]]$Arguments, [string]$Label) {
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d10-godot-preflight\" + [guid]::NewGuid().ToString("N")
    )
    $appData = Join-Path $runRoot "appdata"
    $localAppData = Join-Path $runRoot "localappdata"
    $log = Join-Path $runRoot "$Label.log"
    [void][IO.Directory]::CreateDirectory($appData)
    [void][IO.Directory]::CreateDirectory($localAppData)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($argument in @(
        "--headless", "--path", $repoRoot, "--log-file", $log,
        "--script", $worker, "--"
    ) + $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D10Godot $process.Start() "QSDK-R23D10 Godot process did not start"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(60000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    return [ordered]@{
        exit_code = $process.ExitCode
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-R23D10GodotMarker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.stdout -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D10Godot ($matches.Count -eq 1) (
        "QSDK-R23D10 expected one Godot marker $Prefix"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D10Godot (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "QSDK-R23D10 Godot executable missing: $Godot"
)
Assert-R23D10Godot (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 Godot repository identity changed"

foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D10Godot @(
        "preflight", "--stage", "three_engine_confirmation", "--arm", $arm
    ) $arm
    $combined = [string]$execution.stdout + [string]$execution.stderr
    Assert-R23D10Godot (
        -not [bool]$execution.timed_out -and
        [int]$execution.exit_code -eq 0 -and
        $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
    ) "QSDK-R23D10 Godot preflight failed: $combined"
    $receipt = Get-R23D10GodotMarker (
        $execution
    ) "QSDK_R23D10_GODOT_JOLT_PREFLIGHT "
    Assert-R23D10Godot (
        [string]$receipt.engine_id -ceq "godot_jolt" -and
        [string]$receipt.arm_id -ceq $arm -and
        [int]$receipt.terminal_step_count -eq 900 -and
        [int]$receipt.maximum_active_step_count -eq 540 -and
        [int]$receipt.minimum_quiescent_taper_step_count -eq 120 -and
        [int]$receipt.minimum_passive_step_count -eq 360 -and
        [int]$receipt.oracle_canary_count -eq 5 -and
        [int]$receipt.mutation_control_count -eq 16 -and
        [bool]$receipt.native_temporal_mirror -and
        -not [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "QSDK-R23D10 Godot preflight receipt changed"
}

$refusal = Invoke-R23D10Godot @(
    "physical", "--stage", "three_engine_confirmation", "--arm", "positive_heading"
) "physical-refusal"
$combined = [string]$refusal.stdout + [string]$refusal.stderr
Assert-R23D10Godot (
    -not [bool]$refusal.timed_out -and
    [int]$refusal.exit_code -ne 0 -and
    $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
) "QSDK-R23D10 Godot physical refusal failed: $combined"
$failure = Get-R23D10GodotMarker (
    $refusal
) "QSDK_R23D10_GODOT_JOLT_FAILURE "
Assert-R23D10Godot (
    [string]$failure.failure_stage -ceq "before_model" -and
    [string]$failure.failure_code -ceq
        "QSDK_R23D10_GJT_PHYSICAL_ROUTE_NOT_IMPLEMENTED" -and
    [int]$failure.model_construction_count -eq 0 -and
    [int]$failure.world_build_count -eq 0
) "QSDK-R23D10 Godot physical refusal changed"

Write-Host (
    "QSDK_R23D10_GODOT_JOLT_TEMPORAL_PASS identities=3 canaries=5 " +
    "mutations=16 workers=0 models=0 worlds=0 physical_authority=False"
)
