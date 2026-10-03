[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$modulePath = Join-Path $sdkRoot "turning\r23d2_development.py"
$testPath = Join-Path $sdkRoot "turning\test_r23d2_development.py"
$contractPath = Join-Path $sdkRoot "turning\r23d2_development_contract_v1.json"
$oraclePath = Join-Path $sdkRoot "turning\r23d2_oracle.py"

foreach ($path in @($modulePath, $testPath, $contractPath, $oraclePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "QSDK-R23D2 shared-evaluator input is missing: $path"
    }
}

$source = Get-Content -Raw -LiteralPath $modulePath
$closedEvaluatorName = "physical" + "_development"
if (
    $source -cmatch "from\s+\.?$closedEvaluatorName\s+import" -or
    $source -cmatch "import\s+$closedEvaluatorName(?:\s|$)"
) {
    throw "QSDK-R23D2 shared evaluator imports the closed R23D1 evaluator"
}
foreach ($forbidden in @(
    "PhysicsServer3D", "RigidBody3D", "mj_step", "mjModel", "RapierPhysicsPipeline",
    "physical_wave_gait", "--headless", "physics_frame"
)) {
    if ($source.Contains($forbidden, [StringComparison]::Ordinal)) {
        throw "QSDK-R23D2 shared evaluator contains physical surface '$forbidden'"
    }
}

Push-Location $repoRoot
try {
    $testOutput = & $Python -m unittest -v sdk.turning.test_r23d2_development 2>&1
    $testExitCode = $LASTEXITCODE
    $testOutput | ForEach-Object { Write-Host $_ }
    if ($testExitCode -ne 0) {
        throw "QSDK-R23D2 shared-evaluator tests failed with exit code $testExitCode"
    }

    $preflightOutput = & $Python $modulePath preflight 2>&1
    $preflightExitCode = $LASTEXITCODE
    $preflightOutput | ForEach-Object { Write-Host $_ }
    if ($preflightExitCode -ne 0) {
        throw "QSDK-R23D2 shared-evaluator preflight failed with exit code $preflightExitCode"
    }
} finally {
    Pop-Location
}

$prefix = "QSDK_R23D2_DEVELOPMENT_PREFLIGHT "
$markers = @($preflightOutput | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
if ($markers.Count -ne 1) {
    throw "QSDK-R23D2 shared evaluator emitted $($markers.Count) preflight markers"
}
$receipt = ([string]$markers[0]).Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
if (
    [string]$receipt.schema_version -cne
        "sporespore_qsdk_r23d2_development_preflight_v1" -or
    [string]$receipt.campaign_id -cne
        "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT" -or
    [string]$receipt.gate_id -cne "QSDK-R23D2" -or
    [string]$receipt.contract_sha256 -cnotmatch '^sha256:[0-9a-f]{64}$' -or
    [int]$receipt.declared_engine_count -ne 3 -or
    [int]$receipt.declared_arm_count -ne 3 -or
    [int]$receipt.declared_cell_count -ne 9 -or
    [int]$receipt.schedule_boundary_check_count -ne 21 -or
    [int]$receipt.synthetic_positive_cell_count -ne 9 -or
    [int]$receipt.synthetic_positive_aggregate_pass_count -ne 1 -or
    [int]$receipt.synthetic_valid_negative_aggregate_count -ne 1 -or
    [int]$receipt.structural_negative_control_count -ne 18 -or
    [int]$receipt.structural_negative_control_rejection_count -ne 18 -or
    [int]$receipt.valid_outcome_negative_control_count -ne 9 -or
    [int]$receipt.aggregate_negative_control_count -ne 4 -or
    [int]$receipt.aggregate_negative_control_rejection_count -ne 4 -or
    [int]$receipt.failure_stage_control_count -ne 6 -or
    [int]$receipt.failure_stage_control_pass_count -ne 6 -or
    [int]$receipt.failure_provenance_mutation_count -ne 5 -or
    [int]$receipt.failure_provenance_mutation_rejection_count -ne 5 -or
    [int]$receipt.synthetic_projected_world_attempt_count -ne 9 -or
    [int]$receipt.synthetic_projected_world_build_count -ne 9 -or
    [int]$receipt.actual_physical_process_launch_count -ne 0 -or
    [int]$receipt.actual_world_attempt_count -ne 0 -or
    [int]$receipt.actual_world_build_count -ne 0 -or
    -not [bool]$receipt.physical_execution_authorized -or
    [bool]$receipt.q_sdk_r23_satisfied -or
    [bool]$receipt.command_conditioned_turning -or
    [bool]$receipt.cross_engine_equivalence -or
    [bool]$receipt.release_authorized -or
    [bool]$receipt.physical_acceptance_authority
) {
    throw "QSDK-R23D2 shared-evaluator preflight receipt changed"
}

$stageCounts = [Collections.IDictionary]$receipt.stage_aggregate_projected_counts
if (
    (@($stageCounts.before_world) -join ",") -cne "8,8" -or
    (@($stageCounts.world_construction_failed) -join ",") -cne "9,8" -or
    (@($stageCounts.controller_validation_failed) -join ",") -cne "9,9"
) {
    throw "QSDK-R23D2 stage-aware aggregate counter projection changed"
}

Write-Host (
    "QSDK_R23D2_DEVELOPMENT_GATE_PASS cells=9 positive=9/9 " +
    "valid_negative_controls=9 structural_rejections=18/18 " +
    "aggregate_rejections=4/4 failure_stages=6/6 failure_mutations=5/5 " +
    "projected_worlds=9 actual_worlds=0 physical_authority=False"
)
