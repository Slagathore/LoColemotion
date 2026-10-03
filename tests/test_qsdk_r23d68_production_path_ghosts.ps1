#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectionPath = Join-Path $repoRoot "sdk\process_result_projection.ps1"
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d68_supervisor.ps1"
$producerPath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$workerPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d68_godot_jolt_worker.gd"
$ghostPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d68_trace_boundary_ghost.gd"
$godotPath = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"

. $projectionPath

function Assert-R23D68Ghost([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D68 GHOST: $Message" }
}

foreach ($path in @(
    $projectionPath,
    $supervisorPath,
    $producerPath,
    $workerPath,
    $ghostPath,
    $godotPath
)) {
    Assert-R23D68Ghost (Test-Path -LiteralPath $path -PathType Leaf) "missing path: $path"
}
$supervisorSource = Get-Content -LiteralPath $supervisorPath -Raw
$producerSource = Get-Content -LiteralPath $producerPath -Raw
$workerSource = Get-Content -LiteralPath $workerPath -Raw
$ghostSource = Get-Content -LiteralPath $ghostPath -Raw
Assert-R23D68Ghost (
    $supervisorSource.Contains(
        '. (Join-Path $sdkRoot "process_result_projection.ps1")'
    ) -and
    $supervisorSource.Contains(
        '$processProjection = Get-SporeSporeProcessExecutionProjection'
    ) -and
    $supervisorSource.Contains(
        '-ProcessResult $process -GodotProcess $godotProcess'
    )
) "actual terminal-to-cell route is not bound to the shared process helper"
Assert-R23D68Ghost (
    $producerSource -cmatch '_r23d3_trace_segment\(trace_options, semantic_step\)' -and
    $producerSource -cmatch 'trace_options\.get\("post_schedule_segment_id", "after_declared_schedule"\)' -and
    $workerSource.Contains(
        'trace_options["post_schedule_segment_id"] = "reference_continuation"'
    ) -and
    $ghostSource -cmatch 'WaveGaitScript\._r23d3_trace_segment\('
) "production and ghost trace-helper binding changed"

$godotOutput = @(& $godotPath --headless --path $repoRoot `
    --script res://tests/test_sdk_qsdk_r23d68_trace_boundary_ghost.gd 2>&1)
Assert-R23D68Ghost ($LASTEXITCODE -eq 0) (
    "trace-boundary ghost failed: $($godotOutput -join ' ')"
)
$marker = @($godotOutput | Where-Object {
    [string]$_ -clike "QSDK_R23D68_TRACE_BOUNDARY_GHOST *"
})
Assert-R23D68Ghost ($marker.Count -eq 1) "trace-boundary marker population changed"
$traceReceipt = ([string]$marker[0]).Substring(
    "QSDK_R23D68_TRACE_BOUNDARY_GHOST ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D68Ghost (
    [string]$traceReceipt.schema_version -ceq
        "sporespore_qsdk_r23d68_trace_boundary_ghost_v1" -and
    (@($traceReceipt.semantic_steps) -join ",") -ceq
        "599,600,1799,1800,2399,2400,2991" -and
    (@($traceReceipt.observed_segment_ids) -join ",") -ceq
        "reference_warmup,commanded_turn,commanded_turn,reference_recovery,reference_recovery,reference_continuation,reference_continuation" -and
    [bool]$traceReceipt.same_helper_as_production_row_emitter -and
    [int]$traceReceipt.model_construction_count -eq 0 -and
    [int]$traceReceipt.world_attempt_count -eq 0 -and
    [int]$traceReceipt.world_build_count -eq 0 -and
    -not [bool]$traceReceipt.physical_acceptance_authority
) "trace-boundary receipt changed"

$common = [ordered]@{
    exit_code = 17
    timed_out = $false
    started_utc = "2026-08-26T00:00:00Z"
    completed_utc = "2026-08-26T00:00:01Z"
    host_exit_code = 23
    supervisor_terminated = $true
    termination_protocol_valid = $true
}
$dictionaryProjection = Get-SporeSporeProcessExecutionProjection `
    -ProcessResult $common -GodotProcess $true
$pscustomProjection = Get-SporeSporeProcessExecutionProjection `
    -ProcessResult ([PSCustomObject]$common) -GodotProcess $true
$missingOptionals = [PSCustomObject]@{
    exit_code = 17
    timed_out = $false
    started_utc = "2026-08-26T00:00:00Z"
    completed_utc = "2026-08-26T00:00:01Z"
}
$fallbackProjection = Get-SporeSporeProcessExecutionProjection `
    -ProcessResult $missingOptionals -GodotProcess $true
$nonGodotFallback = Get-SporeSporeProcessExecutionProjection `
    -ProcessResult $missingOptionals -GodotProcess $false
Assert-R23D68Ghost (
    ($dictionaryProjection | ConvertTo-Json -Compress) -ceq
        ($pscustomProjection | ConvertTo-Json -Compress) -and
    [int]$dictionaryProjection.host_exit_code -eq 23 -and
    [bool]$dictionaryProjection.supervisor_terminated -and
    [bool]$dictionaryProjection.termination_protocol_valid -and
    [int]$fallbackProjection.host_exit_code -eq 17 -and
    -not [bool]$fallbackProjection.supervisor_terminated -and
    -not [bool]$fallbackProjection.termination_protocol_valid -and
    [bool]$nonGodotFallback.termination_protocol_valid
) "process-shape projection changed"

$unsupportedRejected = $false
try {
    Get-SporeSporeProcessExecutionProjection -ProcessResult 17 -GodotProcess $true | Out-Null
} catch {
    $unsupportedRejected = $_.Exception.Message -ceq
        "SPORESPORE_PROCESS_RESULT_SHAPE_UNSUPPORTED:System.Int32"
}
$missingRequiredRejected = $false
try {
    Get-SporeSporeProcessExecutionProjection `
        -ProcessResult ([PSCustomObject]@{ exit_code = 0 }) -GodotProcess $true | Out-Null
} catch {
    $missingRequiredRejected = $_.Exception.Message -ceq
        "SPORESPORE_PROCESS_RESULT_REQUIRED_PROPERTY_MISSING:timed_out"
}
Assert-R23D68Ghost ($unsupportedRejected -and $missingRequiredRejected) (
    "process-shape negative controls changed"
)

Write-Output (
    "[turning/3e] PASS R23D68 compact production-path ghosts: " +
    "trace_boundaries=7 process_shapes=2 optional_fallbacks=3 negatives=2 " +
    "models=0 worlds=0 behavior_prediction=False"
)
