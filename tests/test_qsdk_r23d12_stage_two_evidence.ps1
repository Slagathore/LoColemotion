#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$contractPath = Join-Path $turningRoot (
    "r23d12_stage_two_evidence_contract_v1.json"
)
$stageOneClosurePath = Join-Path $PSScriptRoot (
    "test_qsdk_r23d12_stage_one_closure.ps1"
)
$futurePaths = @(
    "sdk/turning/r23d12_physical_implementation_contract_v1.json",
    "sdk/turning/r23d12_dependency_closure.ps1",
    "sdk/turning/r23d12_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d12_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d12_supervisor.ps1",
    "sdk/run_qsdk_r23d12_zero_world_gate.ps1"
)

function Assert-R23D12StageTwo([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-R23D12StageTwo (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 stage-two repository identity mismatch"

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
$bindings.Add([pscustomobject]@{
    path = [string]$contract.diagnostic_trace_contract.semantics_path
    hash = [string]$contract.diagnostic_trace_contract.semantics_raw_sha256
})
Assert-R23D12StageTwo ($bindings.Count -eq 8) (
    "QSDK-R23D12 stage-two binding count changed"
)
foreach ($binding in $bindings) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D12StageTwo (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D12 stage-two binding missing: $($binding.path)"
    )
    $digest = "sha256:" + (
        Get-FileHash -LiteralPath $path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R23D12StageTwo ($digest -ceq [string]$binding.hash) (
        "QSDK-R23D12 stage-two binding changed: $($binding.path)"
    )
}
foreach ($futurePath in $futurePaths) {
    Assert-R23D12StageTwo (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D12 stage-two already contains future route: $futurePath"
}

Assert-R23D12StageTwo (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d12_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_independent_diagnostic_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.stage_one_boundary.commit -ceq
        "f5c686e94c4702cac9a8aadcbcc3e42e2bb83bbb" -and
    [int]$contract.stage_one_boundary.historical_native_semantics_route_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_valid_canary_count -eq 21 -and
    [int]$contract.stage_one_boundary.historical_active_cross_product_count -eq 18 -and
    [int]$contract.stage_one_boundary.historical_mutation_refusal_count -eq 42 -and
    [string]$contract.production_trace_contract.trace_schema -ceq
        "sporespore_qsdk_r23d12_physical_trace_v1" -and
    [string]$contract.production_trace_contract.row_schema -ceq
        "sporespore_qsdk_r23d12_physical_trace_row_v1" -and
    [int]$contract.production_trace_contract.trace_row_field_count -eq 35 -and
    [int]$contract.production_trace_contract.complete_trace_rows_per_cell -eq 3892 -and
    [int]$contract.production_trace_contract.declared_trace_identity_count -eq 11 -and
    [int]$contract.production_trace_contract.trace_test_count -eq 9 -and
    [int]$contract.diagnostic_trace_contract.field_count -eq 7 -and
    [bool]$contract.diagnostic_trace_contract.planner_availability_controls_only_stability_fallback -and
    [bool]$contract.diagnostic_trace_contract.support_margin_availability_controls_only_margin_nullability -and
    [bool]$contract.diagnostic_trace_contract.planner_and_support_margin_availability_are_independent -and
    [bool]$contract.diagnostic_trace_contract.all_six_active_cross_product_states_valid -and
    [bool]$contract.diagnostic_trace_contract.both_passive_margin_states_valid -and
    [bool]$contract.diagnostic_trace_contract.r23d11_observation_unavailable_with_measured_finite_margin_shape_valid -and
    [int]$contract.diagnostic_trace_contract.ordered_applied_delta_count -eq 8 -and
    [double]$contract.diagnostic_trace_contract.maximum_absolute_active_available_delta_rad_s -eq 0.075 -and
    [double]$contract.diagnostic_trace_contract.maximum_active_available_delta_slew_per_step_rad_s -eq 0.01 -and
    [int]$contract.diagnostic_trace_contract.direct_diagnostic_mutation_refusal_count -eq 11 -and
    [int]$contract.diagnostic_trace_contract.cas_retention_new_field_rewrite_refusal_count -eq 1 -and
    [int]$contract.diagnostic_trace_contract.new_decision_threshold_count -eq 0 -and
    -not [bool]$contract.diagnostic_trace_contract.fields_grant_outcome_or_acceptance_authority -and
    [int]$contract.production_evaluator_contract.evaluator_test_count -eq 11 -and
    [int]$contract.production_evaluator_contract.actual_evaluator_cli_subprocess_command_count -eq 2 -and
    [string]$contract.production_evaluator_contract.stage_a_success_marker -ceq
        "QSDK_R23D12_STAGE_A_EVALUATION " -and
    [string]$contract.production_evaluator_contract.complete_success_marker -ceq
        "QSDK_R23D12_COMPLETE_EVALUATION " -and
    [string]$contract.production_evaluator_contract.forbidden_generic_success_marker -ceq
        "QSDK_R23D12_EVALUATION " -and
    [bool]$contract.production_evaluator_contract.exact_expected_source_commit_required_by_both_evaluator_commands -and
    [bool]$contract.production_evaluator_contract.all_report_source_commits_must_match_expected_source_commit -and
    [bool]$contract.content_addressed_retention.attempt_trace_staging_uses_exclusive_creation -and
    [bool]$contract.content_addressed_retention.digest_derived_cas_path_shape_revalidated -and
    [bool]$contract.content_addressed_retention.trace_retention_required_before_terminal_entry -and
    [int]$contract.content_addressed_retention.actual_trace_retention_cli_subprocess_count -eq 1 -and
    -not [bool]$contract.next_implementation_boundary.serialized_supervisor_implemented -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq 0 -and
    -not [bool]$contract.next_implementation_boundary.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.q_sdk_r23_satisfied -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority
) "QSDK-R23D12 stage-two contract boundary changed"

& $stageOneClosurePath
Assert-R23D12StageTwo ($LASTEXITCODE -eq 0) (
    "QSDK-R23D12 historical stage-one closure failed"
)

Push-Location -LiteralPath $turningRoot
try {
    & python -m unittest -v `
        test_r23d12_physical_trace.py `
        test_r23d12_physical_evaluator.py
    Assert-R23D12StageTwo ($LASTEXITCODE -eq 0) (
        "QSDK-R23D12 stage-two trace/evaluator tests failed"
    )
} finally {
    Pop-Location
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d12_stage_two_evidence_gate_v1"
    source_binding_count = $bindings.Count
    trace_test_count = 9
    evaluator_test_count = 11
    complete_test_count = 20
    declared_trace_identity_count = 11
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
    "QSDK_R23D12_STAGE_TWO_EVIDENCE " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
