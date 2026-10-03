param()

$ErrorActionPreference = "Stop"
$env:PYTHONDONTWRITEBYTECODE = "1"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceCommit = "440c375cc8d082461fd1de1ccb71d5a696103eb6"
$sourceObjects = @(
    "$sourceCommit`:sdk/turning/r23d75_native_startup_trace_evaluator_conformance.py",
    "$sourceCommit`:sdk/turning/r23d75_native_startup_trace_evaluator_conformance_v1.json",
    "$sourceCommit`:tests/test_qsdk_r23d75_native_startup_trace_evaluator_conformance.ps1"
)
foreach ($sourceObject in $sourceObjects) {
    $blobType = (& git -C $repoRoot cat-file -t $sourceObject 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $blobType -cne "blob") {
        throw "QSDK_R23D75_PINNED_SOURCE_BLOB_MISSING object=$sourceObject"
    }
}

$materializer = Join-Path $repoRoot (
    "sdk\turning\materialize_r23d75_native_startup_trace_evaluator_conformance_closure.py"
)
$output = & python $materializer --audit
if ($LASTEXITCODE -ne 0) {
    throw "QSDK_R23D75_CLOSURE_AUDIT_FAILED exit=$LASTEXITCODE output=$output"
}

$marker = "QSDK_R23D75_CLOSURE_AUDIT "
$line = @($output | Where-Object { $_ -is [string] -and $_.StartsWith($marker) })
if ($line.Count -ne 1) {
    throw "QSDK_R23D75_CLOSURE_AUDIT_MARKER_INVALID count=$($line.Count)"
}
$value = $line[0].Substring($marker.Length) | ConvertFrom-Json -Depth 100
if (
    $value.schema_version -ne "sporespore_qsdk_r23d75_closure_audit_v1" -or
    $value.status -ne "passed" -or
    $value.campaign_id -ne
        "QSDK-R23D75-NATIVE-STARTUP-TRACE-EVALUATOR-CONFORMANCE-DEVELOPMENT" -or
    $value.gate_id -ne "QSDK-R23D75" -or
    $value.closure_status -ne
        "closed_valid_complete_native_startup_trace_evaluator_conformance_development" -or
    $value.source_commit -ne $sourceCommit -or
    $value.retained_trace_count -ne 9 -or
    $value.retained_trace_row_count -ne 26928 -or
    $value.startup_mutation_rejection_count -ne 19 -or
    $value.new_physical_world_count -ne 0 -or
    $value.turning_result_computed -ne $false -or
    $value.r23d74_result_reinterpreted -ne $false -or
    $value.physical_acceptance_authority -ne $false
) {
    throw "QSDK_R23D75_CLOSURE_AUDIT_RESULT_INVALID"
}

Write-Output "QSDK_R23D75_NATIVE_STARTUP_TRACE_EVALUATOR_CONFORMANCE_CLOSURE_TEST passed"
