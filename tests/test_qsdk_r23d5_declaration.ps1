#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d5_dependency_closed_preregistration_v1.json"
)
$parentClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d4_physical_closure_v1.json"
)
$parentPreregistrationPath = Join-Path $repoRoot (
    "sdk\turning\r23d4_terminal_stabilization_preregistration_v1.json"
)
$parentImplementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d4_implementation_contract_v1.json"
)
$predecessorMissingDependencyPath = Join-Path $repoRoot (
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d2_heading_response.py"
)

function Assert-R23D5Declaration {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D5RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D5Declaration (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $declarationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $parentClosurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $parentPreregistrationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $parentImplementationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $predecessorMissingDependencyPath -PathType Leaf)
) "QSDK-R23D5 declaration repository or parent inputs changed"

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$parentClosure = Get-Content -Raw -LiteralPath $parentClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$parentPreregistration = Get-Content -Raw -LiteralPath $parentPreregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100

$campaignId = "QSDK-R23D5-DEPENDENCY-CLOSED-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D5"
Assert-R23D5Declaration (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d5_dependency_closed_preregistration_v1" -and
    [string]$declaration.status -ceq
        "stage_zero_preregistered_dependency_and_marker_repairs_no_workers_no_physical_authorization" -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_implementation_repair_successor_with_unexposed_physical_estimand"
) "QSDK-R23D5 declaration identity changed"

Assert-R23D5Declaration (
    (Get-R23D5RawSha256 $parentClosurePath) -ceq
        [string]$declaration.lineage.predecessor_closure_raw_sha256 -and
    (Get-R23D5RawSha256 $parentPreregistrationPath) -ceq
        [string]$declaration.inherited_scientific_contract.r23d4_preregistration_raw_sha256 -and
    (Get-R23D5RawSha256 $parentImplementationPath) -ceq
        [string]$declaration.inherited_scientific_contract.r23d4_implementation_contract_raw_sha256 -and
    [string]$parentClosure.status -ceq
        "closed_consumed_implementation_invalid_zero_world" -and
    [bool]$parentClosure.attempt.one_shot_identity_consumed -and
    -not [bool]$parentClosure.attempt.same_identity_rerun_allowed -and
    [int]$parentClosure.attempt.launched_stage_a_worker_process_count -eq 1 -and
    [int]$parentClosure.attempt.completed_stage_a_cell_count -eq 0 -and
    [int]$parentClosure.attempt.world_attempt_count -eq 0 -and
    [int]$parentClosure.attempt.world_build_count -eq 0 -and
    -not [bool]$parentClosure.claims.scientific_positive -and
    -not [bool]$parentClosure.claims.scientific_negative -and
    [string]$parentClosure.successor_boundary.successor_id -ceq $gateId
) "QSDK-R23D5 immutable predecessor boundary changed"

$inheritance = $declaration.inherited_scientific_contract
Assert-R23D5Declaration (
    [bool]$declaration.lineage.same_physical_estimand_may_be_retained_because_no_world_opened -and
    [bool]$declaration.lineage.predecessor_reclassification_forbidden -and
    [bool]$declaration.lineage.predecessor_completion_rewrite_forbidden -and
    [string]$declaration.lineage.predecessor_missing_dependency_path -ceq
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d2_heading_response.py" -and
    (Get-R23D5RawSha256 $predecessorMissingDependencyPath) -ceq
        [string]$declaration.lineage.predecessor_missing_dependency_raw_sha256 -and
    [string]$declaration.lineage.predecessor_terminal_marker_failure_expression -ceq
        '$terminalLines.Count' -and
    -not [bool]$inheritance.fixture_changed -and
    -not [bool]$inheritance.turning_controller_policy_changed -and
    -not [bool]$inheritance.terminal_restoration_policy_changed -and
    -not [bool]$inheritance.host_profiles_changed -and
    -not [bool]$inheritance.outcome_numeric_thresholds_changed -and
    -not [bool]$inheritance.turn_heading_magnitude_changed -and
    -not [bool]$inheritance.turn_duration_changed -and
    -not [bool]$inheritance.turn_onset_changed -and
    -not [bool]$inheritance.controller_horizon_changed -and
    -not [bool]$inheritance.restoration_horizon_changed -and
    -not [bool]$inheritance.passive_settle_changed -and
    -not [bool]$inheritance.stage_a_schedule_changed -and
    -not [bool]$inheritance.stage_a_selector_changed -and
    -not [bool]$inheritance.stage_b_schedule_changed -and
    -not [bool]$inheritance.result_classification_changed -and
    -not [bool]$inheritance.trace_contract_changed -and
    (@($inheritance.only_implementation_repair_surfaces) -join "|") -ceq
        "complete_worker_dependency_closure|terminal_marker_cardinality_and_retention"
) "QSDK-R23D5 scientific inheritance changed"

$snapshot = $declaration.frozen_schedule_and_gate_snapshot
$parentSchedule = $parentPreregistration.command_and_terminal_schedule
$parentGates = $parentPreregistration.unchanged_outcome_gates
Assert-R23D5Declaration (
    [string]$snapshot.morphology_id -ceq
        [string]$parentPreregistration.fixture.morphology_id -and
    [int]$snapshot.campaign_seed -eq
        [int]$parentPreregistration.fixture.campaign_seed -and
    [int]$snapshot.physics_hz -eq
        [int]$parentPreregistration.fixture.physics_hz -and
    [double]$snapshot.authored_sliding_friction -eq
        [double]$parentPreregistration.fixture.authored_sliding_friction -and
    [string]$snapshot.selected_policy_digest -ceq
        [string]$parentPreregistration.fixture.selected_policy_digest -and
    [int]$snapshot.turn_start_semantic_step -eq
        [int]$parentSchedule.turn_start_semantic_step -and
    [int]$snapshot.turn_duration_steps -eq [int]$parentSchedule.turn_duration_steps -and
    [int]$snapshot.turning_controller_semantic_step_count -eq
        [int]$parentSchedule.turning_controller_semantic_step_count -and
    [int]$snapshot.terminal_restoration_step_count -eq
        [int]$parentSchedule.terminal_restoration_step_count -and
    [int]$snapshot.maximum_four_contact_acquisition_steps -eq
        [int]$parentSchedule.maximum_four_contact_acquisition_steps -and
    [int]$snapshot.required_consecutive_all_four_contact_hold_steps -eq
        [int]$parentSchedule.required_consecutive_all_four_contact_hold_steps -and
    [int]$snapshot.passive_settle_step_count -eq
        [int]$parentSchedule.passive_settle_step_count -and
    [int]$snapshot.total_traced_step_count -eq
        [int]$parentSchedule.total_traced_step_count -and
    [string]$snapshot.terminal_restoration_policy_id -ceq
        [string]$parentSchedule.terminal_restoration_policy_id -and
    [double]$snapshot.maximum_absolute_restoration_joint_velocity_rad_s -eq
        [double]$parentSchedule.maximum_absolute_restoration_joint_velocity_rad_s -and
    [double]$snapshot.maximum_absolute_requested_or_held_steering_fraction -eq
        [double]$parentGates.maximum_absolute_requested_or_held_steering_fraction -and
    [double]$snapshot.minimum_absolute_signed_turn_phase_yaw_delta_rad -eq
        [double]$parentGates.minimum_absolute_signed_turn_phase_yaw_delta_rad -and
    [double]$snapshot.minimum_final_forward_displacement_m -eq
        [double]$parentGates.minimum_final_forward_displacement_m -and
    [double]$snapshot.maximum_tilt_rad -eq [double]$parentGates.maximum_tilt_rad -and
    [double]$snapshot.minimum_torso_height_m -eq
        [double]$parentGates.minimum_torso_height_m -and
    [int]$snapshot.minimum_contact_cycles_per_limb -eq
        [int]$parentGates.minimum_contact_cycles_per_limb -and
    [int]$snapshot.exact_active_native_application_count -eq 28256 -and
    [int]$snapshot.exact_passive_native_application_count -eq 0
) "QSDK-R23D5 inherited schedule or numeric gate changed"

Assert-R23D5Declaration (
    [int]$declaration.stage_a_mujoco_terminal_restoration_screen.declared_cell_count -eq 2 -and
    [int]$declaration.stage_a_mujoco_terminal_restoration_screen.declared_world_count -eq 2 -and
    (@($declaration.stage_a_mujoco_terminal_restoration_screen.ordered_arm_ids) -join "|") -ceq
        "positive_heading|negative_heading" -and
    -not [bool]$declaration.stage_a_mujoco_terminal_restoration_screen.parallel_execution_permitted -and
    -not [bool]$declaration.stage_a_mujoco_terminal_restoration_screen.replacement_or_selective_rerun_permitted -and
    [int]$declaration.stage_b_three_engine_confirmation.declared_cell_count_if_launched -eq 9 -and
    [int]$declaration.stage_b_three_engine_confirmation.declared_world_count_if_launched -eq 9 -and
    (@($declaration.stage_b_three_engine_confirmation.ordered_engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    (@($declaration.stage_b_three_engine_confirmation.ordered_arm_ids) -join "|") -ceq
        "reference_zero|positive_heading|negative_heading" -and
    -not [bool]$declaration.stage_b_three_engine_confirmation.parallel_execution_permitted -and
    -not [bool]$declaration.stage_b_three_engine_confirmation.replacement_or_selective_rerun_permitted -and
    -not [bool]$declaration.stage_b_three_engine_confirmation.stage_a_mujoco_reports_may_substitute_for_stage_b
) "QSDK-R23D5 stage schedule changed"

$dependency = $declaration.worker_dependency_closure_contract
$workerIds = @($dependency.declared_worker_ids)
$allRequired = [Collections.Generic.List[string]]::new()
foreach ($workerId in $workerIds) {
    $paths = @($dependency.required_dependency_paths_by_worker[$workerId])
    Assert-R23D5Declaration (
        $paths.Count -gt 0 -and
        @($paths | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_) -or
            [IO.Path]::IsPathRooted([string]$_) -or
            ([string]$_).Contains("\") -or
            ([string]$_).Contains("*") -or
            ([string]$_).Contains("?")
        }).Count -eq 0 -and
        @($paths | Group-Object | Where-Object Count -gt 1).Count -eq 0
    ) "QSDK-R23D5 required dependency manifest is not exact: $workerId"
    foreach ($path in $paths) { $allRequired.Add([string]$path) }
}
Assert-R23D5Declaration (
    ($workerIds -join "|") -ceq "mujoco|rapier_parry|godot_jolt" -and
    [string]$dependency.manifest_schema_version -ceq
        "sporespore_qsdk_r23d5_worker_dependency_manifest_v1" -and
    [bool]$dependency.dependency_paths_are_repo_relative_exact_case_sensitive_files -and
    -not [bool]$dependency.globs_or_prefixes_permitted_in_worker_required_sets -and
    -not [bool]$dependency.duplicate_dependency_paths_permitted -and
    [bool]$dependency.worker_required_sets_must_be_declared_before_physics -and
    [bool]$dependency.supervisor_source_binding_set_must_be_a_superset_of_every_worker_required_set -and
    [bool]$dependency.worker_recomputes_its_own_required_set_membership_and_raw_hashes -and
    [bool]$dependency.supervisor_recomputes_union_membership_before_input_cas_or_attempt_authorization -and
    [bool]$dependency.zero_world_gate_recomputes_union_membership_through_the_same_composer -and
    [bool]$dependency.one_removal_negative_control_required_for_every_declared_dependency -and
    [bool]$dependency.duplicate_path_negative_control_required -and
    [bool]$dependency.case_changed_path_negative_control_required -and
    [bool]$dependency.unknown_worker_manifest_negative_control_required -and
    [bool]$dependency.empty_worker_manifest_negative_control_required -and
    @($dependency.required_dependency_paths_by_worker.mujoco) -contains
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d2_heading_response.py" -and
    @($dependency.required_dependency_paths_by_worker.mujoco) -contains
        "sdk/python/sporespore_locomotion.py" -and
    @($dependency.required_dependency_paths_by_worker.godot_jolt) -contains
        "sdk/turning/r23d3_physical_closure_v1.json" -and
    @($dependency.required_dependency_paths_by_worker.godot_jolt) -contains
        "sdk/mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json" -and
    @($dependency.required_dependency_paths_by_worker.godot_jolt) -contains
        "sdk/rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json" -and
    @($dependency.required_dependency_paths_by_worker.godot_jolt) -contains
        "sdk/turning/r23d2_development_contract_v1.json" -and
    @($allRequired | Sort-Object -Unique).Count -eq 21
) "QSDK-R23D5 dependency-closure contract changed"

$markers = $declaration.terminal_marker_retention_contract
Assert-R23D5Declaration (
    [string]$markers.parser_schema_version -ceq
        "sporespore_qsdk_r23d5_terminal_marker_classifier_v1" -and
    [bool]$markers.stdout_stderr_process_and_optional_engine_log_retained_before_marker_interpretation -and
    [bool]$markers.all_retained_process_bytes_content_addressed_before_marker_interpretation -and
    [bool]$markers.marker_collections_are_always_materialized_as_arrays_before_cardinality_access -and
    [bool]$markers.scalar_string_count_semantics_forbidden -and
    [bool]$markers.exactly_one_recognized_marker_required -and
    [bool]$markers.zero_marker_case_retained_as_supervisor_process_failure -and
    [bool]$markers.many_marker_case_retained_as_supervisor_process_failure -and
    [bool]$markers.mixed_success_and_failure_case_retained_as_supervisor_process_failure -and
    [bool]$markers.malformed_json_case_retained_as_supervisor_process_failure -and
    [bool]$markers.nonzero_exit_with_one_valid_failure_marker_retained_as_worker_failure -and
    [bool]$markers.zero_exit_with_one_valid_success_marker_retained_as_successful_report -and
    [bool]$markers.zero_exit_with_failure_marker_forbidden -and
    [bool]$markers.nonzero_exit_with_success_marker_forbidden -and
    [bool]$markers.terminal_entry_written_and_content_addressed_for_every_launched_process -and
    [bool]$markers.zero_one_many_mixed_malformed_cases_required_per_marker_family -and
    (@($markers.marker_families) -join "|") -ceq
        "mujoco_single_terminal_prefix|rapier_separate_success_failure_prefixes|godot_jolt_separate_success_failure_prefixes"
) "QSDK-R23D5 terminal-marker retention contract changed"

Assert-R23D5Declaration (
    [int]$declaration.stage_zero_proof_requirements.physical_worker_count -eq 0 -and
    -not [bool]$declaration.stage_zero_proof_requirements.production_evaluator_implemented -and
    -not [bool]$declaration.stage_zero_proof_requirements.aggregate_supervisor_implemented -and
    [int]$declaration.stage_zero_proof_requirements.physical_process_launch_count -eq 0 -and
    [int]$declaration.stage_zero_proof_requirements.model_construction_count -eq 0 -and
    [int]$declaration.stage_zero_proof_requirements.world_attempt_count -eq 0 -and
    [int]$declaration.stage_zero_proof_requirements.world_build_count -eq 0 -and
    -not [bool]$declaration.authorization.physical_execution_authorized -and
    -not [bool]$declaration.claim_boundary.stage_a_result_exists -and
    -not [bool]$declaration.claim_boundary.stage_b_result_exists -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence -and
    -not [bool]$declaration.claim_boundary.q_sdk_r23_satisfied -and
    -not [bool]$declaration.claim_boundary.prone_to_standing -and
    -not [bool]$declaration.claim_boundary.release_authorized -and
    -not [bool]$declaration.claim_boundary.physical_acceptance_authority
) "QSDK-R23D5 stage-zero authorization or claim boundary changed"

Write-Host (
    "QSDK_R23D5_DECLARATION_PASS predecessor_worlds=0 " +
    "stage_a_cells=2 stage_b_cells=9 workers_declared=3 " +
    "unique_dependencies=21 removal_canaries_required=21 " +
    "marker_families=3 marker_cases=zero,one,many,mixed,malformed " +
    "workers_implemented=0 models=0 worlds=0 turning=False " +
    "equivalence=False physical_authority=False"
)
