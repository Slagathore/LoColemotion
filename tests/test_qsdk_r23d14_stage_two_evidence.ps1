#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$contractPath = Join-Path $turningRoot "r23d14_stage_two_evidence_contract_v1.json"
$stageOneClosurePath = Join-Path $PSScriptRoot "test_qsdk_r23d14_stage_one_closure.ps1"
$futurePaths = @(
    "sdk/turning/r23d14_physical_implementation_contract_v1.json",
    "sdk/turning/r23d14_dependency_closure.ps1",
    "sdk/turning/r23d14_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d14_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d14_supervisor.ps1",
    "sdk/run_qsdk_r23d14_zero_world_gate.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_physical.rs",
    "tests/test_sdk_qsdk_r23d14_godot_jolt_physical_worker.gd"
)

function Assert-R23D14StageTwo([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-R23D14StageTwo (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 stage-two repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
$bindings.Add([pscustomobject]@{
    path = [string]$contract.stage_one_boundary.historical_closure_audit_path
    hash = [string]$contract.stage_one_boundary.historical_closure_audit_raw_sha256
})
foreach ($pair in @(
    @("preregistration_path", "preregistration_raw_sha256"),
    @("temporal_oracle_path", "temporal_oracle_raw_sha256"),
    @("residual_pose_authority_path", "residual_pose_authority_raw_sha256"),
    @("diagnostic_semantics_path", "diagnostic_semantics_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.temporal_and_inherited_semantics[$pair[0]]
        hash = [string]$contract.temporal_and_inherited_semantics[$pair[1]]
    })
}
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
$bindings.Add([pscustomobject]@{
    path = [string]$contract.production_trace_contract.inherited_core_path
    hash = [string]$contract.production_trace_contract.inherited_core_raw_sha256
})
$bindings.Add([pscustomobject]@{
    path = [string]$contract.production_evaluator_contract.inherited_cell_evaluator_core_path
    hash = [string]$contract.production_evaluator_contract.inherited_cell_evaluator_core_raw_sha256
})
foreach ($pair in @(
    @("publisher_path", "publisher_raw_sha256"),
    @("store_path", "store_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.content_addressed_retention[$pair[0]]
        hash = [string]$contract.content_addressed_retention[$pair[1]]
    })
}
Assert-R23D14StageTwo ($bindings.Count -eq 13) (
    "QSDK-R23D14 stage-two binding count changed"
)
foreach ($binding in $bindings) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D14StageTwo (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D14 stage-two binding missing: $($binding.path)"
    )
    $digest = "sha256:" + (
        Get-FileHash -LiteralPath $path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R23D14StageTwo ($digest -ceq [string]$binding.hash) (
        "QSDK-R23D14 stage-two binding changed: $($binding.path)"
    )
}
foreach ($futurePath in $futurePaths) {
    Assert-R23D14StageTwo (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D14 stage-two already contains future route: $futurePath"
}

$trace = $contract.production_trace_contract
$semantics = $contract.temporal_and_inherited_semantics
$retention = $contract.content_addressed_retention
$evaluator = $contract.production_evaluator_contract
$next = $contract.next_implementation_boundary
$claims = $contract.claim_boundary
Assert-R23D14StageTwo (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d14_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_direct_matrix_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION" -and
    [string]$contract.gate_id -ceq "QSDK-R23D14" -and
    [string]$contract.stage_one_boundary.native_source_commit -ceq
        "d91ca5cf860da229e01d3102f715d06948d8281d" -and
    [string]$contract.stage_one_boundary.native_source_tree_git_oid -ceq
        "cd363a264efa7073af7cf49e427d655ffe8ba51e" -and
    [string]$contract.stage_one_boundary.publication_commit -ceq
        "0c91c212ca982963952e53ba4619922232d38448" -and
    [string]$contract.stage_one_boundary.publication_tree_git_oid -ceq
        "255642a10fd67cc71f4577ad7ac332ebbd93b630" -and
    [int]$contract.stage_one_boundary.historical_native_semantics_route_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_valid_canary_count -eq 36 -and
    [int]$contract.stage_one_boundary.historical_mutation_refusal_count -eq 42 -and
    [int]$contract.stage_one_boundary.historical_positive_timing_shape_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_negative_timing_shape_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_passive_zero_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_physical_refusal_count -eq 3 -and
    [string]$trace.trace_schema -ceq
        "sporespore_qsdk_r23d14_physical_trace_v1" -and
    [string]$trace.row_schema -ceq
        "sporespore_qsdk_r23d14_physical_trace_row_v1" -and
    [int]$trace.trace_row_field_count -eq 51 -and
    [int]$trace.controller_semantic_step_count -eq 2992 -and
    [int]$trace.terminal_tight_gated_step_count -eq 960 -and
    [int]$trace.complete_trace_rows_per_cell -eq 3952 -and
    [int]$trace.declared_trace_identity_count -eq 9 -and
    [int]$trace.trace_test_count -eq 6 -and
    [bool]$trace.private_inherited_module_instance_prevents_cross_campaign_global_mutation -and
    [bool]$trace.r23d14_temporal_oracle_replaces_inherited_temporal_module -and
    [bool]$trace.inherited_controller_diagnostic_composition_and_authority_semantics_unchanged -and
    [bool]$trace.all_nine_synthetic_traces_replayed -and
    [bool]$trace.retained_positive_and_negative_timing_shapes_replayed -and
    [bool]$trace.deadline_reset_and_contact_loss_negative_shapes_retained -and
    [bool]$trace.schema_time_order_authority_vector_and_passive_rewrites_rejected -and
    [string]$semantics.policy_id -ceq
        "sporespore_tight_gated_acquisition_active600_v1" -and
    [int]$semantics.terminal_step_count -eq 960 -and
    [int]$semantics.maximum_active_step_count -eq 600 -and
    [int]$semantics.minimum_taper_step_count -eq 120 -and
    [int]$semantics.minimum_passive_step_count -eq 360 -and
    [double]$semantics.tight_maximum_torso_tilt_rad -eq 0.01 -and
    [double]$semantics.tight_maximum_joint_position_error_rad -eq 0.2 -and
    [bool]$semantics.tight_pose_loss_resets_full_acquisition -and
    -not [bool]$semantics.deadline_forced_handoff_can_pass -and
    [int]$semantics.ordered_actuator_count -eq 8 -and
    [bool]$semantics.command_time_feedback_must_equal_previous_trace_row_post_step_observation -and
    [bool]$semantics.complete_combined_velocity_scaled_once_before_host_mapping -and
    [bool]$semantics.passive_final_vectors_are_exact_zero -and
    -not [bool]$semantics.arm_identity_heading_sign_or_outcome_branching -and
    [int]$semantics.new_tunable_gain_count -eq 0 -and
    [int]$semantics.new_decision_threshold_count -eq 0 -and
    -not [bool]$semantics.physical_acceptance_authority -and
    [string]$retention.media_type -ceq "application/x-ndjson" -and
    [string]$retention.production_evidence_root -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence" -and
    [bool]$retention.production_override_forbidden -and
    [bool]$retention.test_override_requires_test_only -and
    [bool]$retention.worker_digest_and_byte_length_verified_before_copy -and
    [bool]$retention.stored_payload_digest_and_byte_length_verified_after_copy -and
    [bool]$retention.attempt_trace_staging_uses_exclusive_creation -and
    [bool]$retention.digest_derived_cas_path_shape_revalidated -and
    [bool]$retention.trace_retention_required_before_terminal_entry -and
    -not [bool]$retention.physical_acceptance_authority -and
    [int]$evaluator.evaluator_test_count -eq 7 -and
    [int]$evaluator.retained_test_trace_identity_count -eq 10 -and
    [string]$evaluator.complete_report_schema -ceq
        "sporespore_qsdk_r23d14_complete_evaluation_v1" -and
    [string]$evaluator.complete_command -ceq "evaluate-complete" -and
    [string]$evaluator.complete_success_marker -ceq
        "QSDK_R23D14_COMPLETE_EVALUATION " -and
    [bool]$evaluator.forbidden_stage_a_route -and
    [int]$evaluator.actual_evaluator_cli_subprocess_command_count -eq 1 -and
    [bool]$evaluator.exact_expected_source_commit_required -and
    [bool]$evaluator.all_report_source_commits_must_match_expected_source_commit -and
    [bool]$evaluator.all_nine_ordered_cells_always_required -and
    [bool]$evaluator.missing_extra_duplicate_out_of_order_and_execution_invalid_cells_rejected -and
    [bool]$evaluator.valid_negative_outcomes_preserved_without_invalidating_execution -and
    [bool]$evaluator.complete_positive_requires_all_nine_outcome_gates -and
    [bool]$evaluator.reference_zero_straight_walk_compatibility_required -and
    [bool]$evaluator.signed_yaw_required_for_both_nonzero_arms -and
    [bool]$evaluator.trace_artifact_and_replayed_summary_revalidated -and
    [bool]$evaluator.unknown_fields_source_rewrites_and_cas_path_rewrites_rejected -and
    [int]$next.production_physical_worker_count -eq 0 -and
    -not [bool]$next.serialized_direct_matrix_supervisor_implemented -and
    -not [bool]$next.dependency_closure_implemented -and
    -not [bool]$next.authorization_canary_runner_implemented -and
    -not [bool]$next.complete_zero_world_gate_implemented -and
    [bool]$next.next_zero_world_implementation_authorized -and
    -not [bool]$next.physical_execution_authorized -and
    [bool]$claims.production_trace_and_direct_matrix_evaluator_zero_world_qualified -and
    -not [bool]$claims.selected_policy_physically_confirmed_under_r23d14 -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.finite_three_engine_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D14 stage-two contract boundary changed"

& $stageOneClosurePath
Assert-R23D14StageTwo ($LASTEXITCODE -eq 0) (
    "QSDK-R23D14 historical stage-one closure failed"
)

Push-Location -LiteralPath $turningRoot
try {
    & python -m unittest -v `
        test_r23d14_physical_trace.py `
        test_r23d14_physical_evaluator.py
    Assert-R23D14StageTwo ($LASTEXITCODE -eq 0) (
        "QSDK-R23D14 stage-two trace/evaluator tests failed"
    )
} finally {
    Pop-Location
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d14_stage_two_evidence_gate_v1"
    source_binding_count = $bindings.Count
    trace_test_count = 6
    evaluator_test_count = 7
    complete_test_count = 13
    declared_trace_identity_count = 9
    trace_rows_per_identity = 3952
    retained_test_trace_identity_count = 10
    actual_evaluator_cli_command_count = 1
    direct_matrix_aggregate_count = 1
    stage_a_route_count = 0
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
    "QSDK_R23D14_STAGE_TWO_EVIDENCE " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
