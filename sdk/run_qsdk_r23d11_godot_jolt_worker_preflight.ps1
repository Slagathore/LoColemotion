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
$workerResource = (
    "res://tests/test_sdk_qsdk_r23d11_stability_assisted_taper_godot_jolt_physical_worker.gd"
)
$workerPath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d11_stability_assisted_taper_godot_jolt_physical_worker.gd"
)
$handoffPath = Join-Path $repoRoot (
    "scripts\lab\gait\sdk_godot_jolt_quiescent_taper.gd"
)
$compositionPath = Join-Path $repoRoot (
    "scripts\lab\gait\sdk_godot_jolt_stability_assisted_taper.gd"
)
$neutralPath = Join-Path $repoRoot (
    "scripts\lab\gait\sdk_godot_jolt_neutral_stance.gd"
)
$actuationPath = Join-Path $repoRoot (
    "scripts\lab\gait\sdk_godot_jolt_stability_assisted_taper_actuation.gd"
)
$campaignId = (
    "QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
function Assert-R23D11Godot([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D11Godot {
    param(
        [Parameter(Mandatory)][string[]]$UserArguments,
        [Parameter(Mandatory)][string]$Label
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d11-godot-preflight\" +
        [guid]::NewGuid().ToString("N")
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
        "--headless",
        "--path", $repoRoot,
        "--log-file", $logPath,
        "--script", $workerResource,
        "--"
    ) + $UserArguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D11Godot $process.Start() (
        "QSDK-R23D11 Godot/Jolt process did not start: $Label"
    )
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

function Get-R23D11GodotMarker {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @(([string]$Execution.stdout -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D11Godot ($markers.Count -eq 1) (
        "QSDK-R23D11 expected one $Prefix marker from $($Execution.label)"
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D11Godot (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "QSDK-R23D11 Godot executable missing: $Godot"
)
foreach ($path in @(
    $workerPath,
    $handoffPath,
    $compositionPath,
    $neutralPath,
    $actuationPath
)) {
    Assert-R23D11Godot (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D11 Godot/Jolt input missing: $path"
    )
}
Assert-R23D11Godot (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 Godot/Jolt repository identity changed"
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()

foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D11Godot -Label $arm -UserArguments @(
        "--stage", "three_engine_confirmation", "--arm", $arm, "--preflight-only"
    )
    $combined = (
        [string]$execution.stdout +
        [Environment]::NewLine +
        [string]$execution.stderr
    )
    Assert-R23D11Godot (
        -not [bool]$execution.timed_out -and
        [int]$execution.exit_code -eq 0 -and
        $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
    ) "QSDK-R23D11 Godot/Jolt preflight failed: $arm; $combined"
    $receipt = Get-R23D11GodotMarker (
        $execution
    ) "QSDK_R23D11_GODOT_JOLT_PREFLIGHT "
    Assert-R23D11Godot (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d11_godot_jolt_worker_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.engine_id -ceq "godot_jolt" -and
        [string]$receipt.arm_id -ceq $arm -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
        [int]$receipt.fixed_terminal_quiescent_taper_step_count -eq 900 -and
        [int]$receipt.fixed_total_trace_step_count -eq 3892 -and
        [int]$receipt.maximum_active_neutral_acquisition_step_count -eq 540 -and
        [int]$receipt.minimum_quiescent_taper_step_count -eq 120 -and
        [int]$receipt.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
        [int]$receipt.quiescent_taper_oracle_canary_count -eq 5 -and
        [int]$receipt.quiescent_taper_mutation_control_count -eq 16 -and
        [int]$receipt.stability_composition_canary_count -eq 7 -and
        [int]$receipt.stability_composition_mutation_control_count -eq 18 -and
        [int]$receipt.stability_actuation_bridge_canary_count -eq 3 -and
        [bool]$receipt.canonical_scale_applied_before_host_mapping -and
        [int]$receipt.production_trace_constructor_canary_count -eq 4 -and
        [bool]$receipt.native_temporal_mirror -and
        [bool]$receipt.physical_worker_implemented -and
        [bool]$receipt.physical_worker_dormant_behind_supervisor_authorization -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized
    ) "QSDK-R23D11 Godot/Jolt receipt changed: $arm"
}

$authorizationEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D11_FREEZE",
    "SPORESPORE_QSDK_R23D11_ATTEMPT",
    "SPORESPORE_QSDK_R23D11_TOKEN",
    "SPORESPORE_QSDK_R23D11_STAGE",
    "SPORESPORE_QSDK_R23D11_CELL",
    "SPORESPORE_QSDK_R23D11_ENGINE",
    "SPORESPORE_QSDK_R23D11_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D11_PYTHON",
    "SPORESPORE_QSDK_R23D11_POWERSHELL"
)
$savedAuthorizationEnvironment = @{}
try {
    foreach ($name in $authorizationEnvironmentNames) {
        $savedAuthorizationEnvironment[$name] = [Environment]::GetEnvironmentVariable(
            $name, "Process"
        )
        [Environment]::SetEnvironmentVariable($name, $null, "Process")
    }
    $bypass = Invoke-R23D11Godot -Label "physical-refusal" -UserArguments @(
        "--stage", "three_engine_confirmation", "--arm", "positive_heading",
        "--source-commit", $sourceCommit
    )
} finally {
    foreach ($name in $authorizationEnvironmentNames) {
        [Environment]::SetEnvironmentVariable(
            $name, $savedAuthorizationEnvironment[$name], "Process"
        )
    }
}
$combined = (
    [string]$bypass.stdout +
    [Environment]::NewLine +
    [string]$bypass.stderr
)
Assert-R23D11Godot (
    -not [bool]$bypass.timed_out -and
    [int]$bypass.exit_code -ne 0 -and
    $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
) "QSDK-R23D11 Godot/Jolt physical refusal failed: $combined"
$terminal = Get-R23D11GodotMarker (
    $bypass
) "QSDK_R23D11_GODOT_JOLT_TERMINAL "
Assert-R23D11Godot (
    [string]$terminal.failure_stage -ceq "before_world" -and
    [string]$terminal.failure_code -ceq
        "QSDK_R23D11_GJT_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "QSDK-R23D11 Godot/Jolt physical refusal changed"

Write-Host (
    "QSDK_R23D11_GODOT_JOLT_NATIVE_ROUTE_PASS identities=3 taper_canaries=5 " +
    "taper_mutations=16 composition_canaries=7 composition_mutations=18 " +
    "actuation_canaries=3 trace_canaries=4 physical_worker=True " +
    "dormant=True models=0 " +
    "worlds=0 physical_authority=False"
)
