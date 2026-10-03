[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$modulePath = Join-Path $sdkRoot "turning\r23d3_phase_balanced.py"
$contractPath = Join-Path $sdkRoot "turning\r23d3_phase_balanced_preregistration_v1.json"
$predecessorClosurePath = Join-Path $sdkRoot "turning\r23d2_physical_closure_v1.json"

foreach ($path in @($modulePath, $contractPath, $predecessorClosurePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "QSDK-R23D3 stage-zero input is missing: $path"
    }
}

$statusBefore = @(& git -C $repoRoot status --short --untracked-files=all)

$testOutput = & $Python -m unittest -v sdk.turning.test_r23d3_phase_balanced 2>&1
$testExitCode = $LASTEXITCODE
$testOutput | ForEach-Object { Write-Host $_ }
if ($testExitCode -ne 0) {
    throw "QSDK-R23D3 stage-zero unit tests failed with exit code $testExitCode"
}

$preflightOutput = & $Python $modulePath preflight 2>&1
$preflightExitCode = $LASTEXITCODE
$preflightOutput | ForEach-Object { Write-Host $_ }
if ($preflightExitCode -ne 0) {
    throw "QSDK-R23D3 stage-zero preflight failed with exit code $preflightExitCode"
}

$prefix = "QSDK_R23D3_STAGE_ZERO_PREFLIGHT "
$markers = @($preflightOutput | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
if ($markers.Count -ne 1) {
    throw "QSDK-R23D3 stage-zero emitted $($markers.Count) preflight markers"
}
$receipt = ([string]$markers[0]).Substring($prefix.Length) | ConvertFrom-Json -Depth 100

$shaPattern = '^sha256:[0-9a-f]{64}$'
if (
    [string]$receipt.schema_version -cne
        "sporespore_qsdk_r23d3_stage_zero_preflight_v1" -or
    [string]$receipt.campaign_id -cne
        "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT" -or
    [string]$receipt.gate_id -cne "QSDK-R23D3" -or
    [string]$receipt.contract_raw_sha256 -notmatch $shaPattern -or
    [string]$receipt.predecessor_closure_raw_sha256 -cne
        "sha256:83fb890445f1355027ff5062c6d9c3f83792f124a9ee3c2561eab85efe249680" -or
    [int]$receipt.stage_a_cell_count -ne 8 -or
    [int]$receipt.stage_b_projected_cell_count -ne 9 -or
    [int]$receipt.trace_validation_count -ne 17 -or
    [int]$receipt.trace_row_validation_count -ne 50864 -or
    [int]$receipt.trace_negative_control_rejection_count -ne 10 -or
    [int]$receipt.selector_canary_pass_count -ne 4 -or
    [int]$receipt.complete_evaluation_canary_pass_count -ne 5 -or
    [int]$receipt.godot_execution_predicate_count -ne 7 -or
    [int]$receipt.godot_execution_predicate_mutation_rejection_count -ne 7 -or
    -not [bool]$receipt.godot_fixed_horizon_requirement_preregistered -or
    [int]$receipt.godot_fixed_horizon_controller_step_count -ne 2992 -or
    [bool]$receipt.godot_fixed_horizon_zero_world_worker_preflight_implemented -or
    [bool]$receipt.godot_fixed_horizon_physical_worker_implemented -or
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
    throw "QSDK-R23D3 stage-zero receipt changed"
}

$statusAfter = @(& git -C $repoRoot status --short --untracked-files=all)
if ([string]::Join("`n", $statusAfter) -cne [string]::Join("`n", $statusBefore)) {
    throw "QSDK-R23D3 stage-zero changed the working tree"
}

Write-Host (
    "QSDK_R23D3_STAGE_ZERO_PASS stage_a_cells=8 stage_b_projected_cells=9 " +
    "traces=17 trace_rows=50864 trace_negative_controls=10 " +
    "selector_canaries=4 complete_canaries=5 godot_predicates=7 " +
    "godot_mutations=7 fixed_horizon=2992 fixed_horizon_worker=False " +
    "workers=0 worlds=0 physical_authority=False " +
    "turning=False equivalence=False q_sdk_r23=False"
)
