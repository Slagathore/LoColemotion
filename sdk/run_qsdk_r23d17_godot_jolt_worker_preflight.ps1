#requires -Version 7.0

[CmdletBinding()]
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
$workerResource = "res://tests/test_sdk_qsdk_r23d17_godot_jolt_physical_worker.gd"
$stageId = "finite_three_engine_confirmation_live_composition_recovery"
$campaignId = "QSDK-R23D17-LIVE-COMPOSITION-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION"

function Assert-R23D17Godot([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D17Godot([string[]]$UserArguments, [string]$Label) {
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d17-godot-preflight\" + [guid]::NewGuid().ToString("N")
    )
    $appData = Join-Path $runRoot "appdata"
    $localAppData = Join-Path $runRoot "localappdata"
    $logPath = Join-Path $runRoot "$Label.log"
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
        "--headless", "--path", $repoRoot, "--log-file", $logPath,
        "--script", $workerResource, "--"
    ) + $UserArguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D17Godot $process.Start() "Godot process did not start: $Label"
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
        log_path = $logPath
    }
}

function Read-R23D17GodotMarker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.stdout -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D17Godot ($matches.Count -eq 1) (
        "Expected one $Prefix marker from $($Execution.label): " +
        [string]$Execution.stderr
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $Godot,
    (Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"),
    (Join-Path $repoRoot "scripts\lab\gait\sdk_godot_jolt_r23d14_tight_gated_horizon.gd"),
    (Join-Path $repoRoot "tests\test_sdk_qsdk_r23d17_godot_jolt_physical_worker.gd")
)) {
    Assert-R23D17Godot (Test-Path -LiteralPath $path -PathType Leaf) (
        "Godot input missing: $path"
    )
}
Assert-R23D17Godot (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "Godot repository identity changed"

foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D17Godot @(
        "--preflight-only", "--stage", $stageId, "--arm", $armId
    ) "$stageId`-$armId"
    Assert-R23D17Godot (-not $execution.timed_out -and $execution.exit_code -eq 0) (
        "Godot preflight failed: $armId ($($execution.log_path))"
    )
    $receipt = Read-R23D17GodotMarker $execution "QSDK_R23D17_GODOT_JOLT_PREFLIGHT "
    Assert-R23D17Godot (
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.cell_id -ceq "godot_jolt__tight_gated_horizon__$armId" -and
        [int]$receipt.tight_gated_temporal_canary_count -eq 12 -and
        [int]$receipt.fixed_terminal_quiescent_taper_step_count -eq 960 -and
        [int]$receipt.fixed_total_trace_step_count -eq 3952 -and
        [bool]$receipt.r23d14_tight_gated_horizon_inherited_unchanged -and
        [bool]$receipt.r23d17_composition_recovery_identity_enabled -and
        [int]$receipt.nullable_terminal_summary_valid_canary_count -eq 2 -and
        [int]$receipt.nullable_terminal_summary_mutation_control_count -eq 1 -and
        [int]$receipt.production_diagnostics_schema_positive_canary_count -eq 3 -and
        [int]$receipt.production_diagnostics_schema_mutation_control_count -eq 1 -and
        [int]$receipt.live_authority_input_positive_canary_count -eq 8 -and
        [int]$receipt.live_authority_input_mutation_control_count -eq 8 -and
        [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "Godot preflight receipt changed: $armId"
}

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$refusal = Invoke-R23D17Godot @(
    "--stage", $stageId, "--arm", "positive_heading",
    "--source-commit", $sourceCommit
) "physical-refusal"
Assert-R23D17Godot (-not $refusal.timed_out -and $refusal.exit_code -ne 0) (
    "Godot physical route did not refuse"
)
$terminal = Read-R23D17GodotMarker $refusal "QSDK_R23D17_GODOT_JOLT_TERMINAL "
Assert-R23D17Godot (
    [string]$terminal.failure_code -ceq "QSDK_R23D17_GJT_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "Godot physical refusal changed"

Write-Host (
    "QSDK_R23D17_GODOT_JOLT_WORKER_PASS identities=3 temporal_canaries=12 " +
    "nullable_canaries=2 nullable_mutations=1 diagnostic_schema_canaries=3 " +
    "diagnostic_schema_mutations=1 authority_input_canaries=8 " +
    "authority_input_mutations=8 temporal_steps=960 models=0 " +
    "worlds=0 physical_authority=False"
)
