#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$contractPath = Join-Path $turningRoot (
    "r23d13_stage_two_evidence_contract_v1.json"
)
$stageOneClosurePath = Join-Path $PSScriptRoot (
    "test_qsdk_r23d13_stage_one_closure.ps1"
)
$futurePaths = @(
    "sdk/turning/r23d13_physical_implementation_contract_v1.json",
    "sdk/turning/r23d13_dependency_closure.ps1",
    "sdk/turning/r23d13_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d13_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d13_supervisor.ps1",
    "sdk/run_qsdk_r23d13_zero_world_gate.ps1"
)

function Assert-R23D13StageTwo([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-R23D13StageTwo (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 stage-two repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
$bindings.Add([pscustomobject]@{
    path = [string]$contract.stage_one_boundary.historical_closure_audit_path
    hash = [string]$contract.stage_one_boundary.historical_closure_audit_raw_sha256
})
foreach ($sectionName in @(
    "production_trace_contract",
    "production_evaluator_contract"
)) {
    $section = $contract[$sectionName]
    foreach ($pair in @(
        @("implementation_path", "implementation_raw_sha256"),
        @("test_path", "test_raw_sha256")
    )) {
        $bindings.Add([pscustomobject]@{
            path = [string]$section[$pair[0]]
            hash = [string]$section[$pair[1]]
        })
    }
}
foreach ($pair in @(
    @("publisher_path", "publisher_raw_sha256"),
    @("store_path", "store_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.content_addressed_retention[$pair[0]]
        hash = [string]$contract.content_addressed_retention[$pair[1]]
    })
}
foreach ($pair in @(
    @("preregistration_path", "preregistration_raw_sha256"),
    @("oracle_path", "oracle_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.residual_pose_authority_trace_contract[$pair[0]]
        hash = [string]$contract.residual_pose_authority_trace_contract[$pair[1]]
    })
}
$bindings.Add([pscustomobject]@{
    path = [string]$contract.diagnostic_trace_contract.semantics_path
    hash = [string]$contract.diagnostic_trace_contract.semantics_raw_sha256
})
Assert-R23D13StageTwo ($bindings.Count -eq 10) (
    "QSDK-R23D13 stage-two binding count changed"
)
foreach ($binding in $bindings) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D13StageTwo (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D13 stage-two binding missing: $($binding.path)"
    )
    $digest = "sha256:" + (
        Get-FileHash -LiteralPath $path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R23D13StageTwo ($digest -ceq [string]$binding.hash) (
        "QSDK-R23D13 stage-two binding changed: $($binding.path)"
    )
}
foreach ($futurePath in $futurePaths) {
    Assert-R23D13StageTwo (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D13 stage-two already contains future route: $futurePath"
}

$traceContract = $contract.production_trace_contract
$authorityContract = $contract.residual_pose_authority_trace_contract
$diagnosticContract = $contract.diagnostic_trace_contract
$evaluatorContract = $contract.production_evaluator_contract
$retentionContract = $contract.content_addressed_retention
$nextBoundary = $contract.next_implementation_boundary
$claims = $contract.claim_boundary
Assert-R23D13StageTwo (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d13_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_command_time_residual_pose_authority_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D13-RESIDUAL-POSE-AUTHORITY-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$contract.stage_one_boundary.commit -ceq
        "8d2998c4d8d7a4b4e78232bfd34799945bec656a" -and
    [string]$contract.stage_one_boundary.parent_commit -ceq
        "7ba47f7df2fe0965235f2ecc0e4a522278bd6b92" -and
    [string]$contract.stage_one_boundary.tree -ceq
        "02ad589f03aece450ca6fec371752944ad453ef0" -and
    [int]$contract.stage_one_boundary.historical_native_semantics_route_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_valid_canary_count -eq 30 -and
    [int]$contract.stage_one_boundary.historical_mutation_refusal_count -eq 60 -and
    [int]$contract.stage_one_boundary.historical_critical_invariant_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_positive_no_regression_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_passive_zero_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_physical_refusal_count -eq 3 -and
    [string]$traceContract.trace_schema -ceq
        "sporespore_qsdk_r23d13_physical_trace_v1" -and
    [string]$traceContract.row_schema -ceq
        "sporespore_qsdk_r23d13_physical_trace_row_v1" -and
    [int]$traceContract.trace_row_field_count -eq 51 -and
    [int]$traceContract.complete_trace_rows_per_cell -eq 3892 -and
    [int]$traceContract.declared_trace_identity_count -eq 11 -and
    [int]$traceContract.stage_a_trace_identity_count -eq 2 -and
    [int]$traceContract.stage_b_trace_identity_count -eq 9 -and
    [int]$traceContract.trace_test_count -eq 11 -and
    [bool]$traceContract.inherited_temporal_rows_independently_replayed -and
    [bool]$traceContract.inherited_numeric_outcome_thresholds_unchanged -and
    [bool]$traceContract.terminal_receipt_actuation_composition_authority_and_vector_mutations_rejected -and
    [string]$authorityContract.policy_id -ceq
        "sporespore_residual_pose_authority_quiescent_taper_v1" -and
    [int]$authorityContract.command_time_feedback_fields.Count -eq 4 -and
    [int]$authorityContract.authority_receipt_fields.Count -eq 8 -and
    [int]$authorityContract.ordered_vector_fields.Count -eq 2 -and
    [int]$authorityContract.authority_summary_fields.Count -eq 7 -and
    [bool]$authorityContract.command_time_feedback_must_equal_previous_trace_row_post_step_observation -and
    [bool]$authorityContract.future_post_step_observation_may_not_drive_current_command -and
    [bool]$authorityContract.active_applied_numerator_is_max_of_temporal_and_pose_floor -and
    [bool]$authorityContract.authority_floor_may_never_reduce_temporal_authority -and
    [bool]$authorityContract.complete_combined_velocity_scaled_once_before_host_mapping -and
    [int]$authorityContract.ordered_actuator_count -eq 8 -and
    [bool]$authorityContract.passive_pre_taper_vectors_are_all_null -and
    [bool]$authorityContract.passive_final_vectors_are_exact_zero -and
    [bool]$authorityContract.passive_mode_reactivation_forbidden -and
    [int]$authorityContract.direct_authority_and_time_order_mutation_refusal_count -eq 10 -and
    [int]$authorityContract.cas_retention_authority_rewrite_refusal_count -eq 3 -and
    [int]$authorityContract.new_tunable_gain_count -eq 0 -and
    [int]$authorityContract.new_decision_threshold_count -eq 0 -and
    -not [bool]$authorityContract.arm_identity_heading_sign_or_outcome_branching -and
    -not [bool]$authorityContract.physical_acceptance_authority -and
    [int]$diagnosticContract.field_count -eq 7 -and
    [bool]$diagnosticContract.planner_availability_controls_only_stability_fallback -and
    [bool]$diagnosticContract.support_margin_availability_controls_only_margin_nullability -and
    [bool]$diagnosticContract.planner_and_support_margin_availability_are_independent -and
    [bool]$diagnosticContract.all_six_active_cross_product_states_valid -and
    [bool]$diagnosticContract.both_passive_margin_states_valid -and
    [bool]$diagnosticContract.r23d11_observation_unavailable_with_measured_finite_margin_shape_valid -and
    [int]$diagnosticContract.ordered_applied_delta_count -eq 8 -and
    [double]$diagnosticContract.maximum_absolute_active_available_delta_rad_s -eq 0.075 -and
    [double]$diagnosticContract.maximum_active_available_delta_slew_per_step_rad_s -eq 0.01 -and
    [int]$diagnosticContract.direct_diagnostic_mutation_refusal_count -eq 11 -and
    [int]$diagnosticContract.cas_retention_new_field_rewrite_refusal_count -eq 1 -and
    [int]$diagnosticContract.new_decision_threshold_count -eq 0 -and
    -not [bool]$diagnosticContract.fields_grant_outcome_or_acceptance_authority -and
    [int]$evaluatorContract.evaluator_test_count -eq 12 -and
    [int]$evaluatorContract.actual_evaluator_cli_subprocess_command_count -eq 2 -and
    [string]$evaluatorContract.stage_a_success_marker -ceq
        "QSDK_R23D13_STAGE_A_EVALUATION " -and
    [string]$evaluatorContract.complete_success_marker -ceq
        "QSDK_R23D13_COMPLETE_EVALUATION " -and
    [string]$evaluatorContract.forbidden_generic_success_marker -ceq
        "QSDK_R23D13_EVALUATION " -and
    [bool]$evaluatorContract.exact_expected_source_commit_required_by_both_evaluator_commands -and
    [bool]$evaluatorContract.all_report_source_commits_must_match_expected_source_commit -and
    [bool]$retentionContract.attempt_trace_staging_uses_exclusive_creation -and
    [bool]$retentionContract.digest_derived_cas_path_shape_revalidated -and
    [bool]$retentionContract.trace_retention_required_before_terminal_entry -and
    [int]$retentionContract.actual_trace_retention_cli_subprocess_count -eq 1 -and
    -not [bool]$nextBoundary.serialized_supervisor_implemented -and
    [int]$nextBoundary.production_physical_worker_count -eq 0 -and
    -not [bool]$nextBoundary.physical_execution_authorized -and
    [bool]$claims.production_trace_authority_diagnostics_and_evaluator_zero_world_qualified -and
    -not [bool]$claims.residual_pose_authority_hypothesis_physically_tested -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D13 stage-two contract boundary changed"

& $stageOneClosurePath
Assert-R23D13StageTwo ($LASTEXITCODE -eq 0) (
    "QSDK-R23D13 historical stage-one closure failed"
)

Push-Location -LiteralPath $turningRoot
try {
    & python -m unittest -v `
        test_r23d13_physical_trace.py `
        test_r23d13_physical_evaluator.py
    Assert-R23D13StageTwo ($LASTEXITCODE -eq 0) (
        "QSDK-R23D13 stage-two trace/evaluator tests failed"
    )
} finally {
    Pop-Location
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d13_stage_two_evidence_gate_v1"
    source_binding_count = $bindings.Count
    trace_test_count = 11
    evaluator_test_count = 12
    complete_test_count = 23
    declared_trace_identity_count = 11
    command_time_feedback_field_count = 4
    authority_receipt_field_count = 8
    ordered_authority_vector_field_count = 2
    authority_summary_field_count = 7
    authority_and_time_order_mutation_refusal_count = 13
    actual_evaluator_cli_command_count = 2
    actual_trace_retention_cli_command_count = 1
    diagnostic_field_count = 7
    diagnostic_mutation_refusal_count = 12
    active_diagnostic_cross_product_count = 6
    passive_diagnostic_state_count = 2
    r23d11_critical_failure_shape_count = 1
    physical_worker_implementation_count = 0
    supervisor_implementation_count = 0
    physical_process_launch_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    command_conditioned_turning = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D13_STAGE_TWO_EVIDENCE " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
