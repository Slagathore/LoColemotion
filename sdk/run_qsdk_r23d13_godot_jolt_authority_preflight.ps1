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
$sourcePath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_r23d13_residual_pose_authority.gd"
$workerPath = Join-Path (
    $repoRoot
) "tests\test_sdk_qsdk_r23d13_residual_pose_authority_godot_jolt.gd"
$worker = (
    "res://tests/" +
    "test_sdk_qsdk_r23d13_residual_pose_authority_godot_jolt.gd"
)

function Assert-R23D13Godot([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D13Godot([string]$Command, [string]$Label) {
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d13-godot-authority\" + [guid]::NewGuid().ToString("N")
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
        "--script", $worker, "--", $Command
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D13Godot $process.Start() "QSDK-R23D13 Godot process did not start"
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

function Get-R23D13Marker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.stdout -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D13Godot ($matches.Count -eq 1) (
        "QSDK-R23D13 expected one Godot marker $Prefix"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-TextSha256([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

Assert-R23D13Godot (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 Godot repository identity changed"
foreach ($path in @($Godot, $sourcePath, $workerPath)) {
    Assert-R23D13Godot (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D13 Godot input missing: $path"
    )
}
$sourceText = [IO.File]::ReadAllText($sourcePath)
Assert-R23D13Godot (
    -not $sourceText.Contains("sdk/turning", [StringComparison]::Ordinal) -and
    -not $sourceText.Contains("residual_pose_authority.py", [StringComparison]::Ordinal)
) "QSDK-R23D13 Godot native implementation imports the reference oracle"

$execution = Invoke-R23D13Godot "preflight" "preflight"
$combined = [string]$execution.stdout + [string]$execution.stderr
Assert-R23D13Godot (
    -not [bool]$execution.timed_out -and
    [int]$execution.exit_code -eq 0 -and
    $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
) "QSDK-R23D13 Godot preflight failed: $combined"
$receipt = Get-R23D13Marker (
    $execution
) "QSDK_R23D13_GODOT_JOLT_AUTHORITY_PREFLIGHT "
Assert-R23D13Godot (
    [string]$receipt.engine_id -ceq "godot_jolt" -and
    [string]$receipt.language -ceq "gdscript" -and
    [int]$receipt.valid_canary_count -eq 10 -and
    [int]$receipt.mutation_control_count -eq 20 -and
    [bool]$receipt.critical_r23d12_negative_shape_passed -and
    [bool]$receipt.positive_tight_pose_no_regression_canary_passed -and
    [bool]$receipt.passive_exact_zero_actuation_canary_passed -and
    -not [bool]$receipt.reference_oracle_imported -and
    -not [bool]$receipt.physical_worker_implemented -and
    -not [bool]$receipt.physical_execution_authorized -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    @($receipt.mutation_failure_codes).Count -eq 20
) "QSDK-R23D13 Godot preflight receipt changed"

$refusal = Invoke-R23D13Godot "physical" "physical-refusal"
$combined = [string]$refusal.stdout + [string]$refusal.stderr
Assert-R23D13Godot (
    -not [bool]$refusal.timed_out -and
    [int]$refusal.exit_code -ne 0 -and
    $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
) "QSDK-R23D13 Godot physical refusal failed: $combined"
$failure = Get-R23D13Marker (
    $refusal
) "QSDK_R23D13_GODOT_JOLT_AUTHORITY_FAILURE "
Assert-R23D13Godot (
    [string]$failure.failure_stage -ceq "before_model" -and
    [string]$failure.failure_code -ceq
        "QSDK_R23D13_GJT_PHYSICAL_ROUTE_NOT_IMPLEMENTED" -and
    [int]$failure.model_construction_count -eq 0 -and
    [int]$failure.world_build_count -eq 0
) "QSDK-R23D13 Godot physical refusal changed"

$validHash = Get-TextSha256 ([string]$receipt.valid_canary_vector)
$mutationHash = Get-TextSha256 (
    (@($receipt.mutation_failure_codes) -join "`n")
)
Write-Host (
    "QSDK_R23D13_GODOT_JOLT_AUTHORITY_PASS valid=10 mutations=20 " +
    "critical=True valid_vector_sha256=$validHash " +
    "mutation_vector_sha256=$mutationHash physical_refusals=1 " +
    "workers=0 models=0 worlds=0 physical_authority=False"
)
