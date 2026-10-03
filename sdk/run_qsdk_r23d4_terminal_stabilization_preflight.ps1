[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$modulePath = Join-Path $sdkRoot "turning\r23d4_terminal_stabilization.py"
$contractPath = Join-Path $sdkRoot "turning\r23d4_terminal_stabilization_preregistration_v1.json"
$predecessorClosurePath = Join-Path $sdkRoot "turning\r23d3_physical_closure_v1.json"

foreach ($path in @($modulePath, $contractPath, $predecessorClosurePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "QSDK-R23D4 stage-zero input is missing: $path"
    }
}

$statusBefore = @(& git -C $repoRoot status --short --untracked-files=all)

$testOutput = & $Python -m unittest -v sdk.turning.test_r23d4_terminal_stabilization 2>&1
$testExitCode = $LASTEXITCODE
$testOutput | ForEach-Object { Write-Host $_ }
if ($testExitCode -ne 0) {
    throw "QSDK-R23D4 stage-zero unit tests failed with exit code $testExitCode"
}

$preflightOutput = & $Python $modulePath preflight 2>&1
$preflightExitCode = $LASTEXITCODE
$preflightOutput | ForEach-Object { Write-Host $_ }
if ($preflightExitCode -ne 0) {
    throw "QSDK-R23D4 stage-zero preflight failed with exit code $preflightExitCode"
}

$prefix = "QSDK_R23D4_STAGE_ZERO_PREFLIGHT "
$markers = @($preflightOutput | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
if ($markers.Count -ne 1) {
    throw "QSDK-R23D4 stage-zero emitted $($markers.Count) preflight markers"
}
$receipt = ([string]$markers[0]).Substring($prefix.Length) | ConvertFrom-Json -Depth 100

$shaPattern = '^sha256:[0-9a-f]{64}$'
if (
    [string]$receipt.schema_version -cne
        "sporespore_qsdk_r23d4_stage_zero_preflight_v1" -or
    [string]$receipt.campaign_id -cne
        "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT" -or
    [string]$receipt.gate_id -cne "QSDK-R23D4" -or
    [string]$receipt.contract_raw_sha256 -notmatch $shaPattern -or
    [string]$receipt.predecessor_closure_raw_sha256 -cne
        "sha256:d4e0e1370191aa9cac923d2ec74f0d1679653f307119eaaa56785d55bbf379ab" -or
    [int]$receipt.stage_a_cell_count -ne 2 -or
    [int]$receipt.stage_b_projected_cell_count -ne 9 -or
    [int]$receipt.trace_validation_count -ne 11 -or
    [int]$receipt.trace_row_validation_count -ne 41492 -or
    [int]$receipt.trace_negative_control_rejection_count -ne 8 -or
    [int]$receipt.selector_canary_pass_count -ne 4 -or
    [int]$receipt.empty_manifest_canary_pass_count -ne 2 -or
    [int]$receipt.evaluator_transport_canary_pass_count -ne 3 -or
    [int]$receipt.controller_step_count -ne 2992 -or
    [int]$receipt.terminal_restoration_step_count -ne 540 -or
    [int]$receipt.passive_settle_trace_step_count -ne 240 -or
    [int]$receipt.total_trace_step_count_per_cell -ne 3772 -or
    -not [bool]$receipt.numeric_outcome_thresholds_unchanged -or
    [int]$receipt.stage_a_physical_worker_count -ne 0 -or
    [int]$receipt.stage_b_physical_worker_count -ne 0 -or
    [int]$receipt.physical_process_launch_count -ne 0 -or
    [int]$receipt.world_attempt_count -ne 0 -or
    [int]$receipt.world_build_count -ne 0 -or
    [bool]$receipt.physical_execution_authorized -or
    [bool]$receipt.command_conditioned_turning -or
    [bool]$receipt.bilateral_signed_turning -or
    [bool]$receipt.portable_basic_turning -or
    [bool]$receipt.cross_engine_equivalence -or
    [bool]$receipt.q_sdk_r23_satisfied -or
    [bool]$receipt.release_authorized -or
    [bool]$receipt.physical_acceptance_authority
) {
    throw "QSDK-R23D4 stage-zero receipt changed"
}

$statusAfter = @(& git -C $repoRoot status --short --untracked-files=all)
if ([string]::Join("`n", $statusAfter) -cne [string]::Join("`n", $statusBefore)) {
    throw "QSDK-R23D4 stage-zero changed the working tree"
}

Write-Host (
    "QSDK_R23D4_STAGE_ZERO_PASS stage_a_cells=2 stage_b_projected_cells=9 " +
    "traces=11 trace_rows=41492 trace_negative_controls=8 " +
    "selector_canaries=4 empty_manifest_canaries=2 transport_canaries=3 " +
    "controller_steps=2992 restoration_steps=540 passive_trace_steps=240 " +
    "workers=0 worlds=0 physical_authority=False " +
    "turning=False equivalence=False q_sdk_r23=False"
)
