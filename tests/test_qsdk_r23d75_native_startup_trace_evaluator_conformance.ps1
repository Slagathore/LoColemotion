param()

$ErrorActionPreference = "Stop"
$env:PYTHONDONTWRITEBYTECODE = "1"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$module = Join-Path $repoRoot "sdk\turning\r23d75_native_startup_trace_evaluator_conformance.py"
$output = & python $module preflight
if ($LASTEXITCODE -ne 0) {
    throw "QSDK_R23D75_ZERO_WORLD_PREFLIGHT_FAILED exit=$LASTEXITCODE output=$output"
}

$marker = "QSDK_R23D75_ZERO_WORLD_PREFLIGHT "
$line = @($output | Where-Object { $_ -is [string] -and $_.StartsWith($marker) })
if ($line.Count -ne 1) {
    throw "QSDK_R23D75_ZERO_WORLD_PREFLIGHT_MARKER_INVALID count=$($line.Count)"
}
$value = $line[0].Substring($marker.Length) | ConvertFrom-Json -Depth 100

if (
    $value.schema_version -ne "sporespore_qsdk_r23d75_zero_world_preflight_v1" -or
    $value.status -ne "complete_zero_world_gate_passed_retained_trace_replay_pending" -or
    $value.campaign_id -ne "QSDK-R23D75-NATIVE-STARTUP-TRACE-EVALUATOR-CONFORMANCE-DEVELOPMENT" -or
    $value.gate_id -ne "QSDK-R23D75" -or
    $value.question_class -ne "development" -or
    $value.declared_engine_count -ne 3 -or
    $value.complete_engine_binding_enumeration_count -ne 3 -or
    $value.compact_positive_sequence_count -ne 6 -or
    $value.compact_row_count_per_sequence -ne 361 -or
    $value.startup_mutation_rejection_count -ne 19 -or
    $value.unsupported_engine_rejection_count -ne 1 -or
    $value.full_seeded_world_ghost_run -ne $false -or
    $value.retained_native_trace_replay_performed -ne $false -or
    $value.behavioral_success_prediction_made -ne $false -or
    $value.turning_result_computed -ne $false -or
    $value.r23d74_result_reinterpreted -ne $false -or
    $value.threshold_invoked -ne $false -or
    $value.equivalence_or_non_inferiority_test_invoked -ne $false -or
    $value.population_inference_attempted -ne $false -or
    $value.model_construction_count -ne 0 -or
    $value.world_attempt_count -ne 0 -or
    $value.world_build_count -ne 0 -or
    $value.solver_step_count -ne 0 -or
    $value.physical_execution_authorized -ne $false -or
    $value.physical_acceptance_authority -ne $false -or
    $value.claims.finite_three_engine_turning -ne $false -or
    $value.claims.q_sdk_r23_satisfied -ne $false -or
    $value.claims.prone_to_standing -ne $false -or
    $value.claims.release_authorized -ne $false
) {
    throw "QSDK_R23D75_ZERO_WORLD_PREFLIGHT_RESULT_INVALID"
}

$expectedSteps = @(0, 1, 3, 4, 358, 359, 360)
if ((ConvertTo-Json @($value.sampled_boundary_steps) -Compress) -ne (ConvertTo-Json $expectedSteps -Compress)) {
    throw "QSDK_R23D75_ZERO_WORLD_BOUNDARY_STEPS_INVALID"
}

Write-Output "QSDK_R23D75_NATIVE_STARTUP_TRACE_EVALUATOR_CONFORMANCE_TEST passed"
