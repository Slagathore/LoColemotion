[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$modulePath = Join-Path $sdkRoot "turning\r23d2_oracle.py"
$contractPath = Join-Path $sdkRoot "turning\r23d2_oracle_preregistration.json"

foreach ($path in @($modulePath, $contractPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "QSDK-R23D2 oracle input is missing: $path"
    }
}

$testOutput = & $Python -m unittest -v sdk.turning.test_r23d2_oracle 2>&1
$testExitCode = $LASTEXITCODE
$testOutput | ForEach-Object { Write-Host $_ }
if ($testExitCode -ne 0) {
    throw "QSDK-R23D2 oracle unit tests failed with exit code $testExitCode"
}

$preflightOutput = & $Python $modulePath preflight 2>&1
$preflightExitCode = $LASTEXITCODE
$preflightOutput | ForEach-Object { Write-Host $_ }
if ($preflightExitCode -ne 0) {
    throw "QSDK-R23D2 oracle preflight failed with exit code $preflightExitCode"
}

$prefix = "QSDK_R23D2_ORACLE_PREFLIGHT "
$markers = @($preflightOutput | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
if ($markers.Count -ne 1) {
    throw "QSDK-R23D2 oracle emitted $($markers.Count) preflight markers"
}
$receipt = ([string]$markers[0]).Substring($prefix.Length) | ConvertFrom-Json
if (
    [string]$receipt.schema_version -cne
        "sporespore_qsdk_r23d2_oracle_preflight_v1" -or
    [string]$receipt.gate_id -cne "QSDK-R23D2" -or
    [int]$receipt.canary_count -ne 7 -or
    [int]$receipt.canary_pass_count -ne 7 -or
    [int]$receipt.nonzero_cross_track_canary_count -ne 6 -or
    [int]$receipt.legacy_raw_offset_oracle_rejection_count -ne 6 -or
    [int]$receipt.predicate_mutation_rejection_count -ne 35 -or
    [int]$receipt.failure_stage_control_pass_count -ne 6 -or
    [int]$receipt.actual_engine_worker_count -ne 0 -or
    [int]$receipt.world_build_count -ne 0 -or
    [bool]$receipt.physical_execution_authorized -or
    [bool]$receipt.q_sdk_r23_satisfied -or
    [bool]$receipt.physical_acceptance_authority
) {
    throw "QSDK-R23D2 oracle preflight receipt changed"
}

Write-Host (
    "QSDK_R23D2_ORACLE_GATE_PASS canaries=7 nonzero_cross_track=6 " +
    "legacy_oracle_rejections=6 predicate_negative_controls=35 " +
    "failure_stage_controls=6 actual_workers=0 worlds=0 " +
    "physical_authority=False q_sdk_r23=False"
)
