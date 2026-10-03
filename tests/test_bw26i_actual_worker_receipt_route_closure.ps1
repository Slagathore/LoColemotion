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

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot `
    "balanced_wave_bw26i_actual_worker_receipt_route_closure.json"
$gatePath = Join-Path $sdkRoot `
    "balanced_wave_bw26i_actual_worker_receipt_route_gate.ps1"
$runnerPath = Join-Path $sdkRoot `
    "run_balanced_wave_bw26i_actual_worker_receipt_route_commissioning.ps1"
$prefix = "BW26I_ACTUAL_WORKER_RECEIPT_ROUTE "

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$RunRoot
    )
    [void][System.IO.Directory]::CreateDirectory($RunRoot)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = Join-Path $RunRoot "appdata"
    $start.Environment["LOCALAPPDATA"] = Join-Path $RunRoot "localappdata"
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact $process.Start() "BW26I closure failed to start $FileName"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return [ordered]@{
        exit_code = $process.ExitCode
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

foreach ($path in @($Godot, $closurePath, $gatePath, $runnerPath)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) `
        "BW26I closure input is missing: $path"
}
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 64
$sourceCommit = [string]$closure.closed_at_source_commit
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw26i_actual_worker_receipt_route_closure_v1" -and
    [string]$closure.status -ceq
        "closed_infrastructure_invalid_synthetic_selection_authority_leak" -and
    $sourceCommit -ceq "e7d55858c999ed48554fbee210ddb65394bff742" -and
    [string]$closure.source_tree_git_oid -ceq
        "e5938fdb365bdfcbe5a8f243967db51872e4a0f2" -and
    [int]$closure.physical_world_count -eq 0 -and
    -not [bool]$closure.locomotion_outcome_exposed -and
    -not [bool]$closure.locomotion_negative -and
    -not [bool]$closure.controller_comparison_result
) "BW26I closure identity or classification changed"

& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "BW26I source commit is not an ancestor of HEAD"
Assert-Exact (
    (& git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid
) "BW26I source tree identity changed"
foreach ($binding in @($closure.source_bindings)) {
    $relativePath = [string]$binding.path
    Assert-Exact (
        [string]$binding.raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        (& git -C $repoRoot rev-parse "${sourceCommit}:$relativePath").Trim() -ceq
            [string]$binding.git_blob_oid
    ) "BW26I frozen source binding changed: $relativePath"
}
foreach ($claimName in @($closure.claims.Keys)) {
    Assert-Exact (-not [bool]$closure.claims[$claimName]) `
        "BW26I closure claim inflated: $claimName"
}

$baseRunRoot = Join-Path $sdkRoot (
    "target\bw26i-closure-" + [Guid]::NewGuid().ToString("N")
)
$runner = Invoke-CapturedProcess `
    -FileName "pwsh" `
    -Arguments @("-NoLogo", "-NoProfile", "-File", $runnerPath, "-Godot", $Godot) `
    -RunRoot (Join-Path $baseRunRoot "published-runner")
$publishedMarkerPresent = (
    [int]$runner.exit_code -eq 0 -and
    ([string]$runner.stdout).Contains(
        "BW26I_ACTUAL_WORKER_RECEIPT_ROUTE_PASS",
        [StringComparison]::Ordinal
    )
)
Assert-Exact $publishedMarkerPresent `
    "BW26I published runner no longer reproduces its false-positive pass marker"

$godotLog = Join-Path $baseRunRoot "direct-route\godot.log"
$direct = Invoke-CapturedProcess `
    -FileName $Godot `
    -Arguments @(
        "--headless", "--path", $repoRoot, "--log-file", $godotLog,
        "--script", "res://tests/test_sdk_balanced_wave_bw26i_actual_worker_receipt_route.gd"
    ) `
    -RunRoot (Join-Path $baseRunRoot "direct-route")
$combined = [string]$direct.stdout + [Environment]::NewLine + [string]$direct.stderr
Assert-Exact (
    [int]$direct.exit_code -eq 0 -and $combined -cnotmatch "(?m)SCRIPT ERROR"
) "BW26I exact zero-world route no longer reproduces cleanly"
$lines = @(([string]$direct.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($prefix, [StringComparison]::Ordinal)
})
Assert-Exact ($lines.Count -eq 1) "BW26I closure expected one aggregate receipt"
$receipt = $lines[0].Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100

. $gatePath
$evaluation = Invoke-Bw26iActualWorkerReceiptRouteEvaluation `
    -RawCells @($receipt.raw_receipts) `
    -WorkerStderr ([string]$direct.stderr)
$nested = $evaluation.production_evaluation
Assert-Exact (
    [bool]$evaluation.ok -and
    -not [bool]$evaluation.candidate_selected -and
    [string]$evaluation.selected_candidate_id -ceq "BW25Y-B" -and
    [bool]$evaluation.development_selection_authority -and
    [string]$nested.selected_candidate_id -ceq "BW25Y-B" -and
    [bool]$nested.development_selection_authority -and
    [int]$nested.reconstructed_passed_gate_count -eq 50 -and
    [int]$nested.reconstructed_failed_gate_count -eq 0 -and
    [int]$receipt.actual_world_build_count -eq 0 -and
    -not [bool]$receipt.locomotion_outcome_exposed -and
    -not [bool]$evaluation.physical_acceptance_authority
) "BW26I synthetic selection-authority contradiction was not reproduced exactly"
Assert-Exact (
    [string]$closure.reproduced_result.exposed_selected_candidate_id -ceq
        [string]$evaluation.selected_candidate_id -and
    [bool]$closure.reproduced_result.exposed_development_selection_authority -eq
        [bool]$evaluation.development_selection_authority -and
    [string]$closure.defect.failure_code -ceq
        "BW26I_SYNTHETIC_SELECTION_AUTHORITY_LEAK" -and
    -not [bool]$closure.defect.commissioning_claim_boundary_was_valid -and
    -not [bool]$closure.disposition.same_identity_repair_allowed -and
    [bool]$closure.disposition.successor_must_use_distinct_campaign_and_gate
) "BW26I closure disposition does not bind the reproduced defect"

Write-Host (
    "BW26I_ACTUAL_WORKER_RECEIPT_ROUTE_CLOSURE_PASS " +
    "status=infrastructure-invalid synthetic_selection=BW25Y-B " +
    "nested_authority=True claimed_pass_marker=True worlds=0 " +
    "locomotion_negative=False physical_authority=False"
)
