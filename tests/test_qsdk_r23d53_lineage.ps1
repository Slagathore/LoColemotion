#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$traceAnalysisRoot = Join-Path $repoRoot "sdk\trace_analysis"
$preregistrationPath = Join-Path $turningRoot (
    "r23d53_godot_warmup_preserving_origin_reanchor_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d53_godot_warmup_preserving_origin_reanchor_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot "r23d53_campaign_attestation_manifest_v1.json"
$provenanceRepairPath = Join-Path $turningRoot (
    "r23d53_checkout_provenance_repair_v1.json"
)
$r48Path = Join-Path $turningRoot (
    "r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
)
$r50Path = Join-Path $turningRoot (
    "r23d50_rapier_cas_path_identity_replay_closure_v1.json"
)
$r31Path = Join-Path $turningRoot (
    "r23d31_cycle_integrated_directional_response_closure_v1.json"
)
$r32Path = Join-Path $turningRoot (
    "r23d32_finite_rapier_turning_replication_closure_v1.json"
)
$r52Path = Join-Path $turningRoot (
    "r23d52_godot_segment_origin_reanchor_closure_v1.json"
)
$diagnosisPath = Join-Path $traceAnalysisRoot (
    "r23d52_godot_origin_timing_diagnosis_closure_v1.json"
)
$shutdownDiagnosticPath = Join-Path $turningRoot (
    "r23d51_godot_47_shutdown_diagnostic_v1.json"
)
$releaseContractPath = Join-Path $repoRoot (
    "sdk\release\quadruped_release_contract.json"
)
$supportMatrixPath = Join-Path $repoRoot (
    "sdk\release\quadruped_support_matrix.json"
)
$terminationHelperPath = Join-Path $repoRoot (
    "sdk\godot_receipt_terminated_process.ps1"
)
$terminalProjectionHelperPath = Join-Path $repoRoot (
    "sdk\locomotion_terminal_execution_projection.ps1"
)
$terminalProjectionGatePath = Join-Path $repoRoot (
    "tests\test_locomotion_terminal_execution_projection.ps1"
)

$expectedHashes = [ordered]@{
    r48 = "sha256:5b2ce3553a78836035c6a7b6ff11ee585cb615f0ebcc70341902e7bca58b7063"
    r50 = "sha256:47bee3d69965e2ffc79fae820223be3bfdfb001fa9fa2d2bc7ee7620ca0e9f48"
    r31 = "sha256:364f44e3a974d81e6b98073e02e4c46abf927cbabed933d0d1aae706e5890b4c"
    r32 = "sha256:40c7f4797916a5780d331f2676b2956875a35f28f79ef2043db30fef0eb09c93"
    r52 = "sha256:7b0a223362b33f58a40c82f7abb472215dead910ab8d2b3f3d4661943c557bea"
    diagnosis = "sha256:e3bb83808b3971d7bb0878d7b17189d32e650aa43510c6602e85fec5858ff50a"
    diagnosis_report = "sha256:2ef06418f3a15c206a456f2e8abf13407ff820d58100ccf29822e8e0b203dbdc"
}

function Assert-R23D53Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D53 LINEAGE: $Message" }
}

function Get-R23D53Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Read-R23D53Json([string]$Path) {
    Assert-R23D53Lineage (Test-Path -LiteralPath $Path -PathType Leaf) (
        "missing retained declaration or closure: $Path"
    )
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-R23D53ProspectiveRecord($Value) {
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("prospective_r23d53_attempt")) {
            return $Value["prospective_r23d53_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D53ProspectiveRecord $child
            if ($null -ne $found) { return $found }
        }
    } elseif ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D53ProspectiveRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

Assert-R23D53Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$preregistration = Read-R23D53Json $preregistrationPath
$implementation = Read-R23D53Json $implementationPath
$manifest = Read-R23D53Json $manifestPath
$provenanceRepair = Read-R23D53Json $provenanceRepairPath
$r48 = Read-R23D53Json $r48Path
$r50 = Read-R23D53Json $r50Path
$r31 = Read-R23D53Json $r31Path
$r32 = Read-R23D53Json $r32Path
$r52 = Read-R23D53Json $r52Path
$diagnosis = Read-R23D53Json $diagnosisPath
$shutdownDiagnostic = Read-R23D53Json $shutdownDiagnosticPath
$releaseContract = Read-R23D53Json $releaseContractPath
$supportMatrix = Read-R23D53Json $supportMatrixPath

$lineage = $preregistration.immutable_lineage
$successor = $preregistration.scientifically_distinct_successor
$matrix = $preregistration.frozen_matrix
$measurement = $preregistration.cycle_integrated_measurement
$thresholds = $preregistration.threshold_provenance
$adequacy = $preregistration.adequacy
$evidence = $preregistration.evidence_integrity
$claims = $preregistration.claims
$mechanism = $implementation.mechanism_development_boundary
$originPolicy = $implementation.task_frame_origin_policy
$sessionFreeze = $implementation.godot_transport_and_session_freeze
$terminalProjection = $implementation.terminal_execution_projection
$hostContainment = $implementation.godot_host_lifecycle_containment
$terminationHelper = Get-Content -Raw -LiteralPath $terminationHelperPath
$terminalProjectionHelper = Get-Content -Raw -LiteralPath $terminalProjectionHelperPath

Assert-R23D53Lineage (
    (Get-R23D53Hash $r48Path) -ceq $expectedHashes.r48 -and
    (Get-R23D53Hash $r50Path) -ceq $expectedHashes.r50 -and
    (Get-R23D53Hash $r31Path) -ceq $expectedHashes.r31 -and
    (Get-R23D53Hash $r32Path) -ceq $expectedHashes.r32 -and
    (Get-R23D53Hash $r52Path) -ceq $expectedHashes.r52 -and
    (Get-R23D53Hash $diagnosisPath) -ceq $expectedHashes.diagnosis -and
    [string]$lineage.r23d48_closure_raw_sha256 -ceq $expectedHashes.r48 -and
    [string]$lineage.r23d52_closure_raw_sha256 -ceq $expectedHashes.r52 -and
    [string]$lineage.r23d52_origin_timing_diagnosis_closure_raw_sha256 -ceq
        $expectedHashes.diagnosis -and
    [string]$lineage.r23d31_closure_raw_sha256 -ceq $expectedHashes.r31 -and
    [string]$lineage.r23d32_closure_raw_sha256 -ceq $expectedHashes.r32
) "immutable closure hashes changed"

Assert-R23D53Lineage (
    [bool]$r48.identity_consumed -and
    -not [bool]$r48.same_identity_rerun_allowed -and
    [int]$r48.physical_evidence.observed_world_build_count -eq 9 -and
    [bool]$r48.engine_results.godot_jolt.all_common_physical_gates_passed -and
    -not [bool]$r48.engine_results.godot_jolt.full_three_arm_turning_gate_passed -and
    [bool]$r48.claims.godot_jolt_seed_21512_all_three_common_walking_gates_passed -and
    -not [bool]$r48.claims.finite_three_engine_turning -and
    [bool]$r50.identity_consumed -and
    -not [bool]$r50.same_identity_rerun_allowed -and
    [bool]$r50.official_result.turning_measurement_passed -and
    -not [bool]$r50.claims.fresh_rapier_turning_replication -and
    [bool]$r31.identity_consumed -and
    [double]$r31.cycle_integrated_evaluation.minimum_cycle_shift_rad -eq 0.01 -and
    [bool]$r32.claims.finite_rapier_turning_validation -and
    -not [bool]$r32.claims.finite_three_engine_turning
) "inherited finite turning lineage changed"

Assert-R23D53Lineage (
    [bool]$r52.identity_consumed -and
    -not [bool]$r52.same_identity_rerun_allowed -and
    -not [bool]$r52.selective_rerun_allowed -and
    [string]$r52.status -ceq
        "closed_consumed_valid_complete_negative_outcome_exposed_godot_segment_origin_implementation_replay" -and
    [int]$r52.physical_evidence.observed_world_attempt_count -eq 3 -and
    [int]$r52.physical_evidence.observed_world_build_count -eq 3 -and
    [int]$r52.physical_evidence.common_physical_gate_pass_count -eq 3 -and
    [bool]$r52.official_result.all_cells_execution_valid -and
    [bool]$r52.official_result.all_cells_common_physical_gates_passed -and
    [bool]$r52.official_result.all_cells_walked_upright_with_zero_torso_contacts -and
    -not [bool]$r52.official_result.turning_measurement_passed -and
    [bool]$r52.official_result.negative_arm_fails_direction_at_zero_floor -and
    -not [bool]$r52.official_result.segment_origin_reanchor_mechanism_selected -and
    -not [bool]$r52.claims.fresh_godot_jolt_turning -and
    -not [bool]$r52.claims.finite_three_engine_turning
) "R52 consumed walking-positive turning-negative boundary changed"

Assert-R23D53Lineage (
    [string]$diagnosis.status -ceq
        "closed_complete_postoutcome_same_seed_godot_origin_timing_diagnosis" -and
    [int]$diagnosis.retained_evidence.source_trace_count -eq 6 -and
    [int]$diagnosis.retained_evidence.source_trace_row_count -eq 17952 -and
    [string]$diagnosis.retained_evidence.report.sha256 -ceq
        $expectedHashes.diagnosis_report -and
    [bool]$diagnosis.findings.same_seed_and_same_initial_physical_observation_per_arm -and
    [bool]$diagnosis.findings.r23d52_initial_segment_reanchored_at_step_zero_per_arm -and
    [int]$diagnosis.findings.first_controller_projection_difference_step -eq 0 -and
    [int]$diagnosis.findings.first_torso_position_difference_step -eq 5 -and
    [int]$diagnosis.findings.first_measured_yaw_difference_step -eq 14 -and
    -not [bool]$diagnosis.findings.r23d52_warmup_trajectory_isolated_from_origin_policy -and
    [bool]$diagnosis.findings.both_commanded_arms_first_cycle_direction_correct -and
    [bool]$diagnosis.findings.both_commanded_arms_later_cycles_reverse_direction -and
    [int]$diagnosis.findings.negative_arm_requested_expected_sign_row_count -eq 1200 -and
    [int]$diagnosis.findings.negative_arm_held_expected_sign_row_count -eq 1200 -and
    [bool]$diagnosis.interpretation.warmup_preserving_command_onset_reanchor_is_distinct_testable_question -and
    -not [bool]$diagnosis.interpretation.r23d52_exact_policy_selected -and
    [int]$diagnosis.successor_constraints.fixed_initial_origin_required_through_semantic_step -eq 599 -and
    [int]$diagnosis.successor_constraints.first_reanchor_permitted_at_commanded_turn_onset_step -eq 600 -and
    [bool]$diagnosis.successor_constraints.initial_schedule_binding_must_not_change_task_origin -and
    [bool]$diagnosis.successor_constraints.fresh_held_out_validation_required_if_selected -and
    -not [bool]$diagnosis.successor_constraints.physical_execution_authorized_by_diagnosis
) "R52 retained-trace diagnosis or successor constraint changed"

Assert-R23D53Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [string]$preregistration.campaign_id -ceq
        "QSDK-R23D53-GODOT-WARMUP-PRESERVING-ORIGIN-REANCHOR-DEVELOPMENT" -and
    [string]$preregistration.study_classification -ceq
        "exact_outcome_exposed_same_seed_godot_jolt_origin_timing_mechanism_development_screen" -and
    [bool]$lineage.r23d48_identity_consumed -and
    [bool]$lineage.r23d52_identity_consumed -and
    [bool]$lineage.r23d52_all_three_common_walking_positive -and
    -not [bool]$lineage.r23d52_turning_positive -and
    -not [bool]$lineage.r23d52_exact_policy_selected -and
    [bool]$lineage.origin_timing_diagnosis_closed -and
    -not [bool]$lineage.historical_result_reinterpreted -and
    -not [bool]$lineage.historical_world_reused_as_a_new_cell -and
    -not [bool]$lineage.same_identity_rerun_permitted
) "R53 prospective lineage declaration changed"

Assert-R23D53Lineage (
    [string]$successor.comparator_campaign_id -ceq
        "QSDK-R23D52-GODOT-SEGMENT-ORIGIN-REANCHOR-IMPLEMENTATION-REPLAY" -and
    [bool]$successor.same_outcome_exposed_seed_as_comparator -and
    [bool]$successor.same_initial_perturbation_as_comparator -and
    [bool]$successor.same_morphology_controller_startup_transform_material_solver_schedule_horizon_measurement_and_thresholds_as_comparator -and
    [int]$successor.declared_physical_change_count -eq 1 -and
    [string]$successor.only_declared_physical_change -ceq
        "task_frame_origin_policy_id=heading_segment_origin_reanchor_v1 becomes warmup_preserving_command_onset_origin_reanchor_v1: bind the initial schedule without changing the fixed origin, preserve it through semantic step 599, and first reanchor at step 600" -and
    -not [bool]$successor.r23d52_exact_policy_reused -and
    -not [bool]$successor.initial_schedule_binding_reanchors -and
    [int]$successor.fixed_initial_origin_preserved_through_semantic_step -eq 599 -and
    [int]$successor.first_permitted_reanchor_semantic_step -eq 600 -and
    [bool]$successor.complete_three_cell_matrix_must_be_rerun -and
    -not [bool]$successor.historical_world_reused_as_r23d53_cell -and
    -not [bool]$successor.controller_source_or_gain_changed -and
    -not [bool]$successor.engine_identity_input_permitted -and
    -not [bool]$successor.arm_identity_input_permitted -and
    -not [bool]$successor.outcome_branching_permitted -and
    -not [bool]$successor.threshold_changed -and
    -not [bool]$successor.fresh_held_out_condition_consumed
) "R53 scientifically distinct successor boundary changed"

Assert-R23D53Lineage (
    [int]$matrix.declared_cell_count -eq 3 -and
    [int]$matrix.declared_world_count -eq 3 -and
    [string]$matrix.stage_id -ceq
        "godot_warmup_preserving_origin_reanchor_development" -and
    (@($matrix.ordered_engine_ids) -join ',') -ceq "godot_jolt" -and
    (@($matrix.ordered_arm_ids) -join ',') -ceq
        "reference_zero,positive_heading,negative_heading" -and
    [int]$matrix.seed -eq 21512 -and
    [string]$matrix.task_frame_origin_policy_id -ceq
        "warmup_preserving_command_onset_origin_reanchor_v1" -and
    [int]$matrix.initial_schedule_bind_semantic_step -eq 0 -and
    [int]$matrix.fixed_origin_last_semantic_step -eq 599 -and
    (@($matrix.expected_reanchor_semantic_steps) -join ',') -ceq
        "600,1800,2400" -and
    [int]$matrix.controller_step_count -eq 2992 -and
    [bool]$matrix.serial_execution_required -and
    [bool]$matrix.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$measurement.inherited_unchanged_from_r23d31 -and
    [double]$measurement.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
    [double]$measurement.minimum_reference_conditioned_cycle_shift_rad -eq 0.01 -and
    [bool]$thresholds.common_physical_gates_inherited_unchanged_from_r23d52_and_r23d48 -and
    [bool]$thresholds.cycle_integrated_floor_inherited_unchanged_from_r23d31_and_r23d32 -and
    [double]$thresholds.cycle_integrated_floor_rad -eq 0.01 -and
    -not [bool]$thresholds.terminal_tilt_threshold -and
    -not [bool]$thresholds.population_margin -and
    -not [bool]$thresholds.cross_engine_equivalence_margin -and
    [int]$thresholds.threshold_change_count -eq 0 -and
    [bool]$adequacy.outcome_exposed_development_screen -and
    [bool]$adequacy.all_three_arms_required -and
    [bool]$adequacy.positive_selects_only_a_held_out_validation_candidate -and
    [bool]$adequacy.negative_or_invalid_closes_the_mechanism_screen_without_retry -and
    -not [bool]$adequacy.population_inference_attempted -and
    -not [bool]$adequacy.cross_engine_equivalence_attempted -and
    [string]$evidence.origin_timing_diagnosis_report_sha256 -ceq
        $expectedHashes.diagnosis_report -and
    [bool]$evidence.fixed_policy_warmup_projection_equivalence_required -and
    [bool]$evidence.initial_binding_and_transition_mutations_rejected
) "R53 finite matrix, threshold, or adequacy declaration changed"

Assert-R23D53Lineage (
    [string]$mechanism.predecessor_closure_path -ceq
        "sdk/turning/r23d52_godot_segment_origin_reanchor_closure_v1.json" -and
    [string]$mechanism.predecessor_closure_raw_sha256 -ceq
        $expectedHashes.r52 -and
    [string]$mechanism.diagnosis_closure_path -ceq
        "sdk/trace_analysis/r23d52_godot_origin_timing_diagnosis_closure_v1.json" -and
    [string]$mechanism.diagnosis_closure_raw_sha256 -ceq
        $expectedHashes.diagnosis -and
    [string]$mechanism.diagnosed_failure_class -ceq
        "initial_segment_origin_reanchor_changed_the_nominal_common_warmup_before_turn_onset" -and
    [int]$mechanism.physical_change_count -eq 1 -and
    [int]$mechanism.controller_change_count -eq 0 -and
    [int]$mechanism.evaluator_change_count_excluding_identity_and_provenance -eq 1 -and
    [int]$mechanism.threshold_change_count -eq 0 -and
    [int]$mechanism.transport_change_count -eq 0 -and
    -not [bool]$mechanism.historical_world_reused_as_r23d53_cell -and
    [bool]$mechanism.complete_three_cell_screen_required -and
    [bool]$mechanism.outcome_exposed -and
    -not [bool]$mechanism.fresh_godot_validation
) "R53 implementation mechanism boundary changed"

Assert-R23D53Lineage (
    [string]$originPolicy.policy_id -ceq
        "warmup_preserving_command_onset_origin_reanchor_v1" -and
    [string]$originPolicy.default_policy_id -ceq "fixed_initial_origin_v1" -and
    [bool]$originPolicy.opt_in_required -and
    [int]$originPolicy.initial_schedule_bind_semantic_step -eq 0 -and
    -not [bool]$originPolicy.initial_schedule_binding_reanchors -and
    [int]$originPolicy.fixed_initial_origin_preserved_through_semantic_step -eq 599 -and
    (@($originPolicy.expected_reanchor_semantic_steps) -join ',') -ceq
        "600,1800,2400" -and
    [int]$originPolicy.expected_reanchor_count -eq 3 -and
    [bool]$originPolicy.same_segment_relatch_forbidden -and
    [bool]$originPolicy.reference_yaw_rebase_forbidden -and
    [bool]$originPolicy.task_axis_rebase_forbidden -and
    [int]$originPolicy.engine_identity_input_count -eq 0 -and
    [int]$originPolicy.arm_identity_input_count -eq 0 -and
    [bool]$originPolicy.zero_world_transition_and_mutation_canaries_required -and
    [bool]$originPolicy.retained_trace_transition_validation_required
) "R53 task-frame-origin implementation contract changed"

Assert-R23D53Lineage (
    [string]$sessionFreeze.transport_execution_contract_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.transport_execution_contract_path))) -and
    [string]$sessionFreeze.persistent_session_contract_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.persistent_session_contract_path))) -and
    [string]$sessionFreeze.c_abi_manifest_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.c_abi_manifest_path))) -and
    [string]$sessionFreeze.schema_registry_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.schema_registry_path))) -and
    [string]$sessionFreeze.portable_core_ffi_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.portable_core_ffi_path))) -and
    [string]$sessionFreeze.godot_adapter_rust_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.godot_adapter_rust_path))) -and
    [string]$sessionFreeze.godot_adapter_gdscript_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.godot_adapter_gdscript_path))) -and
    [string]$sessionFreeze.selected_physical_runner_raw_sha256 -ceq
        (Get-R23D53Hash (Join-Path $repoRoot ([string]$sessionFreeze.selected_physical_runner_path))) -and
    [bool]$sessionFreeze.built_gdextension_sha256_frozen_by_one_shot_supervisor_before_world -and
    [bool]$sessionFreeze.worker_preflight_requires_exact_transport_session_and_shutdown_receipts -and
    [int]$sessionFreeze.world_build_count -eq 0 -and
    -not [bool]$sessionFreeze.physical_acceptance_authority
) "Godot transport or persistent-session source freeze drifted"

Assert-R23D53Lineage (
    [string]$terminalProjection.helper_path -ceq
        "sdk/locomotion_terminal_execution_projection.ps1" -and
    [string]$terminalProjection.independent_gate_path -ceq
        "tests/test_locomotion_terminal_execution_projection.ps1" -and
    [string]$terminalProjection.success_count_source -ceq "execution" -and
    [string]$terminalProjection.failure_count_source -ceq
        "terminal_root_failure" -and
    [int]$terminalProjection.positive_terminal_projection_canary_count -eq 1 -and
    [int]$terminalProjection.failure_terminal_projection_canary_count -eq 2 -and
    [int]$terminalProjection.terminal_projection_mutation_rejection_count -eq 10 -and
    [bool]$terminalProjection.same_shared_function_used_by_preflight_and_physical_post_capture -and
    [bool]$terminalProjection.ambiguous_shape_rejected -and
    [bool]$terminalProjection.uncertain_failure_bounds_preserved -and
    [int]$terminalProjection.world_build_count -eq 0 -and
    (Test-Path -LiteralPath $terminalProjectionGatePath -PathType Leaf) -and
    $terminalProjectionHelper.Contains(
        "function Get-SporeSporeTerminalExecutionProjection"
    ) -and
    $terminalProjectionHelper.Contains(
        "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID"
    )
) "shared terminal projection proof changed"

Assert-R23D53Lineage (
    [string]$hostContainment.scope -ceq "r23d53_worker_process_exit_only" -and
    [string]$hostContainment.termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [string]$hostContainment.diagnostic_path -ceq
        "sdk/turning/r23d51_godot_47_shutdown_diagnostic_v1.json" -and
    [bool]$hostContainment.diagnostic_inherited_unchanged_from_r23d51 -and
    -not [bool]$hostContainment.physics_or_controller_change -and
    [bool]$hostContainment.per_process_nonce_required -and
    [bool]$hostContainment.supervisor_terminates_only_the_exact_launcher_process_tree -and
    [bool]$hostContainment.wrong_nonce_negative_control_required -and
    [int]$hostContainment.world_build_count -eq 0 -and
    [string]$shutdownDiagnostic.diagnosis.mapped_function -ceq
        "GDScriptLanguage::finish" -and
    -not [bool]$shutdownDiagnostic.diagnosis.adapter_dll_was_faulting_module -and
    $terminationHelper.Contains("Test-SporeSporeProcessIsSelfOrDescendant") -and
    $terminationHelper.Contains("GODOT_READY_MARKER_BINDING_INVALID") -and
    $terminationHelper.Contains('$process.Kill($true)')
) "Godot host-lifecycle containment contract changed"

Assert-R23D53Lineage (
    [string]$manifest.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_manifest_v1" -and
    [string]$manifest.status -ceq "prospective_zero_world_physical_candidate" -and
    [string]$manifest.campaign_id -ceq
        "QSDK-R23D53-GODOT-WARMUP-PRESERVING-ORIGIN-REANCHOR-DEVELOPMENT" -and
    [string]$manifest.question_class -ceq "development" -and
    [int]$manifest.declared_physical_world_count -eq 3 -and
    [int]$manifest.declared_lineage_gate_count -eq 3 -and
    [int]$manifest.declared_campaign_gate_count -eq 3 -and
    [int]$manifest.declared_total_gate_count -eq 6 -and
    [int]$manifest.declared_role_binding_count -eq 3 -and
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.physical_acceptance_authority -and
    -not [bool]$manifest.release_authority
) "campaign attestation manifest boundary changed"

Assert-R23D53Lineage (
    [string]$provenanceRepair.schema_version -ceq
        "sporespore_r23d53_checkout_provenance_repair_v1" -and
    [string]$provenanceRepair.status -ceq
        "retained_zero_world_qualification_failure_with_prospective_verifier_repair" -and
    [string]$provenanceRepair.failed_source.commit -ceq
        "64a84efb648cd505c6718e235f30bb9db5c1ca1f" -and
    [string]$provenanceRepair.failed_source.tree_git_oid -ceq
        "c2e197612db748a48e68afb1c223bc41ec293c54" -and
    [string]$provenanceRepair.failed_qualification.failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    (@($provenanceRepair.failed_qualification.passed_gate_ids) -join ',') -ceq
        "CAK1-REPOSITORY-AUTHORITY,CAK1-REPRODUCIBLE-ARTIFACTS,CAK1-OPERATION-LOCK" -and
    [int]$provenanceRepair.failed_qualification.physical_process_launch_count -eq 0 -and
    [int]$provenanceRepair.failed_qualification.model_construction_count -eq 0 -and
    [int]$provenanceRepair.failed_qualification.world_build_count -eq 0 -and
    -not [bool]$provenanceRepair.failed_qualification.physical_attempt_consumed -and
    [bool]$provenanceRepair.mechanism.gitattributes_change_was_bounded_non_migration_extension -and
    -not [bool]$provenanceRepair.mechanism.ambient_text_auto_rule_changed -and
    -not [bool]$provenanceRepair.mechanism.historical_path_rule_changed -and
    -not [bool]$provenanceRepair.mechanism.renormalization_executed -and
    -not [bool]$provenanceRepair.mechanism.physical_or_controller_source_failure -and
    [bool]$provenanceRepair.prospective_repair.requires_fresh_clean_push -and
    [bool]$provenanceRepair.prospective_repair.requires_entirely_new_scoped_attestation_output -and
    [bool]$provenanceRepair.prospective_repair.requires_fresh_adoption -and
    -not [bool]$provenanceRepair.prospective_repair.changes_frozen_physical_question -and
    -not [bool]$provenanceRepair.prospective_repair.changes_physics_controller_threshold_seed_or_world_count -and
    -not [bool]$provenanceRepair.claims.physical_campaign_executed -and
    -not [bool]$provenanceRepair.claims.scientific_result -and
    -not [bool]$provenanceRepair.claims.release_authority
) "R53 retained pre-world provenance refusal or repair boundary changed"

$turningGate = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D53Lineage ($turningGate.Count -eq 1) (
    "release contract must contain exactly one QSDK-R23 gate"
)
$releaseRecord = $turningGate[0].proof.prospective_r23d53_attempt
$matrixRecord = Find-R23D53ProspectiveRecord $supportMatrix
$preregistrationHash = Get-R23D53Hash $preregistrationPath
$implementationHash = Get-R23D53Hash $implementationPath
$manifestHash = Get-R23D53Hash $manifestPath
$provenanceRepairHash = Get-R23D53Hash $provenanceRepairPath

Assert-R23D53Lineage (
    $null -ne $releaseRecord -and
    $null -ne $matrixRecord -and
    [string]$releaseRecord.status -ceq "prospective_zero_world_only" -and
    [string]$matrixRecord.status -ceq "prospective_zero_world_only" -and
    [string]$releaseRecord.preregistration_raw_sha256 -ceq
        $preregistrationHash -and
    [string]$matrixRecord.preregistration_sha256 -ceq
        $preregistrationHash -and
    [string]$releaseRecord.implementation_raw_sha256 -ceq
        $implementationHash -and
    [string]$matrixRecord.implementation_sha256 -ceq
        $implementationHash -and
    [string]$releaseRecord.campaign_attestation_manifest_raw_sha256 -ceq
        $manifestHash -and
    [string]$matrixRecord.campaign_attestation_manifest_sha256 -ceq
        $manifestHash -and
    [string]$releaseRecord.checkout_provenance_repair_path -ceq
        "sdk/turning/r23d53_checkout_provenance_repair_v1.json" -and
    [string]$matrixRecord.checkout_provenance_repair_path -ceq
        "sdk/turning/r23d53_checkout_provenance_repair_v1.json" -and
    [string]$releaseRecord.checkout_provenance_repair_raw_sha256 -ceq
        $provenanceRepairHash -and
    [string]$matrixRecord.checkout_provenance_repair_sha256 -ceq
        $provenanceRepairHash -and
    [string]$releaseRecord.first_scoped_qualification_source_commit -ceq
        "64a84efb648cd505c6718e235f30bb9db5c1ca1f" -and
    [string]$matrixRecord.first_scoped_qualification_source_commit -ceq
        "64a84efb648cd505c6718e235f30bb9db5c1ca1f" -and
    [string]$releaseRecord.first_scoped_qualification_failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$matrixRecord.first_scoped_qualification_failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [bool]$releaseRecord.first_scoped_qualification_failure_retained -and
    [bool]$matrixRecord.first_scoped_qualification_failure_retained -and
    [int]$releaseRecord.first_scoped_qualification_world_build_count -eq 0 -and
    [int]$matrixRecord.first_scoped_qualification_world_build_count -eq 0 -and
    -not [bool]$releaseRecord.first_scoped_qualification_physical_attempt_consumed -and
    -not [bool]$matrixRecord.first_scoped_qualification_physical_attempt_consumed -and
    -not [bool]$releaseRecord.prospective_provenance_repair_changes_physical_question -and
    -not [bool]$matrixRecord.prospective_provenance_repair_changes_physical_question -and
    [string]$releaseRecord.r23d52_closure_raw_sha256 -ceq
        $expectedHashes.r52 -and
    [string]$matrixRecord.r23d52_closure_raw_sha256 -ceq
        $expectedHashes.r52 -and
    [string]$releaseRecord.r23d52_origin_timing_diagnosis_closure_raw_sha256 -ceq
        $expectedHashes.diagnosis -and
    [string]$matrixRecord.r23d52_origin_timing_diagnosis_closure_raw_sha256 -ceq
        $expectedHashes.diagnosis -and
    [int]$releaseRecord.declared_world_count -eq 3 -and
    [int]$matrixRecord.declared_world_count -eq 3 -and
    [int]$releaseRecord.physical_change_count -eq 1 -and
    [int]$matrixRecord.physical_change_count -eq 1 -and
    [int]$releaseRecord.controller_change_count -eq 0 -and
    [int]$matrixRecord.controller_change_count -eq 0 -and
    [int]$releaseRecord.threshold_change_count -eq 0 -and
    [int]$matrixRecord.threshold_change_count -eq 0 -and
    [int]$releaseRecord.transport_change_count -eq 0 -and
    [int]$matrixRecord.transport_change_count -eq 0 -and
    [string]$releaseRecord.task_frame_origin_policy_id -ceq
        "warmup_preserving_command_onset_origin_reanchor_v1" -and
    [string]$matrixRecord.task_frame_origin_policy_id -ceq
        "warmup_preserving_command_onset_origin_reanchor_v1" -and
    -not [bool]$releaseRecord.initial_schedule_binding_reanchors -and
    -not [bool]$matrixRecord.initial_schedule_binding_reanchors -and
    [int]$releaseRecord.fixed_origin_last_semantic_step -eq 599 -and
    [int]$matrixRecord.fixed_origin_last_semantic_step -eq 599 -and
    (@($releaseRecord.expected_reanchor_semantic_steps) -join ',') -ceq
        "600,1800,2400" -and
    (@($matrixRecord.expected_reanchor_semantic_steps) -join ',') -ceq
        "600,1800,2400" -and
    [bool]$releaseRecord.complete_three_cell_matrix_required -and
    [bool]$matrixRecord.complete_three_cell_matrix_required -and
    -not [bool]$releaseRecord.historical_world_reused_as_r23d53_cell -and
    -not [bool]$matrixRecord.historical_world_reused_as_r23d53_cell -and
    [bool]$releaseRecord.r23d50_existing_file_identity_verifier_inherited -and
    [bool]$matrixRecord.r23d50_existing_file_identity_verifier_inherited -and
    [bool]$releaseRecord.authority_repo_root_required_for_complete_evaluation -and
    [bool]$matrixRecord.authority_repo_root_required_for_complete_evaluation -and
    [int]$releaseRecord.local_model_construction_count -eq 0 -and
    [int]$matrixRecord.local_model_construction_count -eq 0 -and
    [int]$releaseRecord.local_world_build_count -eq 0 -and
    [int]$matrixRecord.local_world_build_count -eq 0 -and
    [bool]$releaseRecord.clean_pushed_scoped_qualification_pending -and
    [bool]$matrixRecord.clean_pushed_scoped_qualification_pending -and
    [bool]$releaseRecord.campaign_attestation_adoption_pending -and
    [bool]$matrixRecord.campaign_attestation_adoption_pending -and
    -not [bool]$releaseRecord.physical_world_opened -and
    -not [bool]$matrixRecord.physical_world_opened -and
    -not [bool]$releaseRecord.fresh_godot_jolt_turning_validation -and
    -not [bool]$matrixRecord.fresh_godot_jolt_turning_validation -and
    [bool]$releaseRecord.positive_selects_only_held_out_validation_candidate -and
    [bool]$matrixRecord.positive_selects_only_held_out_validation_candidate -and
    -not [bool]$releaseRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
    -not [bool]$releaseRecord.prone_to_standing -and
    -not [bool]$matrixRecord.prone_to_standing
) "release contract and support matrix prospective R53 records diverged"

Assert-R23D53Lineage (
    -not [bool]$claims.physical_world_opened -and
    -not [bool]$claims.godot_jolt_turning_validation -and
    -not [bool]$claims.finite_three_engine_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$implementation.claims.physical_world_opened -and
    -not [bool]$implementation.claims.godot_jolt_turning_validation -and
    -not [bool]$implementation.claims.finite_three_engine_turning -and
    -not [bool]$implementation.claims.release_authorized
) "prospective false-claim boundary changed"

Write-Host (
    "QSDK_R23D53_LINEAGE_PASS predecessors=R23D31,R23D32,R23D48,R23D50,R23D52 " +
    "diagnosis=R23D52-D1 seed=21512 worlds=3 physical_change_count=1 " +
    "transport_change_count=0 threshold_changes=0 held_out=False physical=False"
)
