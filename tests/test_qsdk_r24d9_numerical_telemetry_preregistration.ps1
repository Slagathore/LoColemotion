#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$contractRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "characterization_preregistration_v1.json"
)
$contractPath = Join-Path $repoRoot $contractRelative
$parentClosureRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json"
)
$parentAuditRelative = (
    "tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1"
)
$r24d7PreregistrationRelative = (
    "sdk/recovery/" +
    "r24d7_godot_jolt_one_hinge_telemetry_" +
    "characterization_preregistration_v1.json"
)
$r24d7ClosureRelative = (
    "sdk/recovery/" +
    "r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json"
)
$patchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)

function Assert-R24D9 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D9 preregistration: $Code"
    }
}

function Get-R24D9Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Copy-R24D9Value {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R24D9Contract {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Contract)

    Assert-R24D9 (
        [string]$Contract.schema_version -ceq
        "sporespore_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1"
    ) "schema_version"
    Assert-R24D9 ([string]$Contract.gate_id -ceq "QSDK-R24D9") "gate_id"
    Assert-R24D9 (
        [string]$Contract.work_id -ceq
        "QSDK-R24D9-GODOT-JOLT-ONE-HINGE-NUMERICAL-TELEMETRY-CHARACTERIZATION"
    ) "work_id"
    Assert-R24D9 (
        [string]$Contract.status -ceq
        "prospectively_declared_full_one_hinge_numerical_telemetry_characterization_implementation_and_zero_world_pending_physical_execution_forbidden"
    ) "status"
    Assert-R24D9 (
        [string]$Contract.question_class -ceq "development" -and
        -not [string]::IsNullOrWhiteSpace([string]$Contract.question) -and
        -not [string]::IsNullOrWhiteSpace([string]$Contract.purpose)
    ) "question"

    $authorization = $Contract.authorization_source
    Assert-R24D9 (
        [string]$authorization.gate_id -ceq "QSDK-R24D8" -and
        [string]$authorization.closure_id -ceq "QSDK-R24D8-PH1-CLOSURE" -and
        [string]$authorization.closure_path -ceq $parentClosureRelative -and
        [string]$authorization.closure_raw_sha256 -ceq
            "sha256:a068b13f8fa97db5559572b1a221bff262da4c3d933a2544198ec67156cbba4d" -and
        [string]$authorization.closure_audit_path -ceq $parentAuditRelative -and
        [string]$authorization.closure_audit_raw_sha256 -ceq
            "sha256:9f8ef518e3168107188cb2e5dcc488b25e969983bdd48601bc750d4cf93d0cf1" -and
        [string]$authorization.closure_publication_commit -ceq
            "4088881d92ea335c1cb70ff42e15abe5bf5d42c5" -and
        [string]$authorization.timing_result_class -ceq
            "valid_finite_descriptive_development_timing_result" -and
        [bool]$authorization.active_step_snapshot_timing_established -and
        [bool]$authorization.sleeping_stale_snapshot_preservation_established -and
        -not [bool]$authorization.native_numerical_telemetry_characterized -and
        [bool]$authorization.next_declaration_authorized -and
        -not [bool]$authorization.next_physical_execution_authorized -and
        [bool]$authorization.same_source_rerun_forbidden
    ) "authorization_source"

    $nonReuse = $Contract.non_reuse_and_non_reinterpretation
    Assert-R24D9 (
        [string]$nonReuse.r24d7_preregistration_path -ceq
            $r24d7PreregistrationRelative -and
        [string]$nonReuse.r24d7_preregistration_raw_sha256 -ceq
            "sha256:6837bc21d5ea0b16c17a19ce053e6f28f1ef6ec3f14dcc95dd4e763ac52c7dc4" -and
        [string]$nonReuse.r24d7_physical_closure_path -ceq
            $r24d7ClosureRelative -and
        [string]$nonReuse.r24d7_physical_closure_raw_sha256 -ceq
            "sha256:6a71d1051bea9d1b47cb6b4b9ecc5550ef38e0f49cde2495f1815e5f83b27702" -and
        [string]$nonReuse.r24d7_result_class -ceq
            "invalid_development_result_no_characterization" -and
        -not [bool]$nonReuse.r24d7_raw_numerical_values_used_to_select_r24d9_fixture_cells -and
        -not [bool]$nonReuse.r24d7_raw_numerical_values_used_to_select_r24d9_thresholds -and
        -not [bool]$nonReuse.r24d7_result_reinterpreted -and
        -not [bool]$nonReuse.r24d8_raw_numerical_values_used_to_select_r24d9_fixture_cells -and
        -not [bool]$nonReuse.r24d8_raw_numerical_values_used_to_select_r24d9_thresholds -and
        -not [bool]$nonReuse.r24d8_result_reinterpreted -and
        [string]$nonReuse.r24d8_zero_world_receipt_raw_sha256 -ceq
            "sha256:f89f37b077e329c57fde787ddd4adae307dc7ead033b6f896b9497d764014855" -and
        [string]$nonReuse.r24d8_physical_receipt_raw_sha256 -ceq
            "sha256:a4bf658df837eaa991aa4421cbba1398949d1267558c738d5c5eb930800d886b" -and
        -not [bool]$nonReuse.r24d8_result_reuse_claimed -and
        -not [bool]$nonReuse.r24d8_zero_world_reuse_claimed -and
        [bool]$nonReuse.r24d9_complete_zero_world_gate_required -and
        -not [string]::IsNullOrWhiteSpace([string]$nonReuse.design_reuse_rationale)
    ) "non_reuse"

    $engine = $Contract.engine_and_runtime_freeze
    Assert-R24D9 (
        [string]$engine.runtime_profile_id -ceq
            "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2" -and
        [string]$engine.physics_engine -ceq "Jolt Physics" -and
        [string]$engine.godot_source_repository -ceq
            "https://github.com/godotengine/godot.git" -and
        [string]$engine.godot_source_commit -ceq
            "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
        [string]$engine.combined_patch_path -ceq $patchRelative -and
        [string]$engine.combined_patch_raw_sha256 -ceq
            "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c" -and
        [int]$engine.patched_file_count -eq 10 -and
        [int]$engine.physics_ticks_per_second -eq 120 -and
        [int]$engine.solver_velocity_steps -eq 20 -and
        [int]$engine.solver_position_steps -eq 7 -and
        [string]$engine.thread_model -ceq "single_safe" -and
        (@($engine.gravity_vector_m_s2) -join ",") -ceq "0,0,0" -and
        [string]$engine.build_precision -ceq "single" -and
        [string]$engine.telemetry_schema -ceq
            "sporespore.godot_jolt_hinge_motor_telemetry.v2" -and
        [int]$engine.telemetry_field_count -eq 15 -and
        [string]$engine.r24d8_retained_console_binary_raw_sha256 -ceq
            "sha256:8a629f16859f653d447cd7f07f712f0045a1aed3f27be53413d97df6ff1ec0e6" -and
        [long]$engine.r24d8_retained_console_binary_byte_length -eq 293376 -and
        [string]$engine.r24d8_retained_engine_binary_raw_sha256 -ceq
            "sha256:0d77df42106c6d2f6fa51727d8051bf403e8a0273b3242daee581c93c4ba7257" -and
        [long]$engine.r24d8_retained_engine_binary_byte_length -eq 188829184 -and
        [bool]$engine.r24d8_binary_pair_is_toolchain_provenance_not_r24d9_qualification -and
        [bool]$engine.r24d9_independent_cold_build_required -and
        -not [bool]$engine.runtime_substitution_allowed -and
        -not [bool]$engine.solver_setting_substitution_allowed
    ) "engine_freeze"

    $source = $Contract.prospective_source
    Assert-R24D9 (
        [string]$source.preregistration_path -ceq $contractRelative -and
        [string]$source.declaration_audit_path -ceq
            "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1" -and
        [string]$source.future_rig_path -ceq
            "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd" -and
        [string]$source.future_worker_path -ceq
            "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd" -and
        [string]$source.future_evaluator_path -ceq
            "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_evaluator.py" -and
        [string]$source.future_validation_manifest_path -ceq
            "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json" -and
        [string]$source.future_freeze_audit_path -ceq
            "tests/test_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_freeze.ps1" -and
        [string]$source.future_supervisor_path -ceq
            "sdk/run_qsdk_r24d9_one_hinge_numerical_telemetry_characterization.ps1" -and
        [int]$source.implementation_source_file_count_at_declaration -eq 0 -and
        -not [bool]$source.implementation_complete_at_declaration -and
        [bool]$source.all_implementation_sources_must_be_committed_pushed_and_git_blob_bound_before_physics -and
        [bool]$source.complete_zero_world_gate_required_before_physics -and
        [bool]$source.real_evaluator_shaped_synthetic_envelope_required_before_physics -and
        [bool]$source.all_declared_evaluator_negative_controls_required_before_physics -and
        [bool]$source.real_custom_runtime_zero_world_worker_required_before_physics -and
        [bool]$source.cold_build_required_before_physics -and
        [bool]$source.single_global_operation_lock_required -and
        [string]$source.durable_evidence_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence" -and
        -not [bool]$source.same_source_physical_rerun_allowed
    ) "prospective_source"

    $fixture = $Contract.fixture_freeze
    $expectedCellIds = @(
        "drive_positive",
        "drive_negative",
        "brake_positive",
        "brake_negative",
        "disabled_positive",
        "disabled_negative",
        "limit_positive",
        "limit_negative",
        "sleep_stale"
    )
    Assert-R24D9 (
        [string]$fixture.fixture_id -ceq
            "QSDK.R24D9.godot_jolt_one_hinge_numerical_telemetry.v1" -and
        [int]$fixture.world_count -eq 1 -and
        [int]$fixture.isolated_cell_count -eq 9 -and
        [int]$fixture.hinges_per_cell -eq 1 -and
        [int]$fixture.dynamic_bodies_per_cell -eq 1 -and
        [int]$fixture.static_parents_per_cell -eq 1 -and
        [double]$fixture.child_mass_kg -eq 1.0 -and
        (@($fixture.child_inertia_diagonal_kg_m2) -join ",") -ceq "0.05,0.05,0.05" -and
        @($fixture.child_inertia_real_t_binary64_projection_diagonal_kg_m2).Count -eq 3 -and
        [double]$fixture.child_inertia_real_t_binary64_projection_diagonal_kg_m2[0] -eq
            0.05000000074505806 -and
        [double]$fixture.child_inertia_real_t_binary64_projection_diagonal_kg_m2[1] -eq
            0.05000000074505806 -and
        [double]$fixture.child_inertia_real_t_binary64_projection_diagonal_kg_m2[2] -eq
            0.05000000074505806 -and
        (@($fixture.hinge_axis_parent_local) -join ",") -ceq "0,0,1" -and
        [string]$fixture.hinge_axis_symbol -ceq "Vector3.BACK" -and
        [bool]$fixture.hinge_at_child_center_of_mass -and
        [double]$fixture.gravity_scale -eq 0.0 -and
        [double]$fixture.linear_damping -eq 0.0 -and
        [double]$fixture.angular_damping -eq 0.0 -and
        [int]$fixture.collision_layer -eq 0 -and
        [int]$fixture.collision_mask -eq 0 -and
        [int]$fixture.contact_count -eq 0 -and
        [int]$fixture.direct_force_write_count -eq 0 -and
        [int]$fixture.direct_torque_write_count -eq 0 -and
        [int]$fixture.direct_impulse_write_count -eq 0 -and
        [int]$fixture.post_activation_transform_write_count -eq 0 -and
        [int]$fixture.pre_activation_initial_angular_velocity_write_count -eq 4 -and
        [int]$fixture.declared_sleep_input_write_count -eq 1 -and
        [int]$fixture.maximum_physics_step_count -eq 20 -and
        [int]$fixture.retained_sample_count -eq 68 -and
        (@($fixture.cell_ids_in_order) -join "|") -ceq
            ($expectedCellIds -join "|")
    ) "fixture"

    $cells = $Contract.cell_families
    Assert-R24D9 (
        (@($cells.signed_drive.cell_ids) -join "|") -ceq
            "drive_positive|drive_negative" -and
        [bool]$cells.signed_drive.motor_enabled -and
        (@($cells.signed_drive.canonical_target_velocity_rad_s) -join ",") -ceq
            "1,-1" -and
        [double]$cells.signed_drive.public_maximum_motor_impulse_nms -eq 0.002 -and
        [double]$cells.signed_drive.public_maximum_motor_impulse_real_t_projection_nms -eq
            0.0020000000949949026 -and
        [int]$cells.signed_drive.retained_step_count -eq 4 -and
        (@($cells.signed_braking.cell_ids) -join "|") -ceq
            "brake_positive|brake_negative" -and
        [bool]$cells.signed_braking.motor_enabled -and
        (@($cells.signed_braking.initial_canonical_rate_rad_s) -join ",") -ceq
            "0.4,-0.4" -and
        [int]$cells.signed_braking.retained_step_count -eq 4 -and
        (@($cells.motor_disabled.cell_ids) -join "|") -ceq
            "disabled_positive|disabled_negative" -and
        -not [bool]$cells.motor_disabled.motor_enabled -and
        [int]$cells.motor_disabled.retained_step_count -eq 4 -and
        (@($cells.limit_active_separation.cell_ids) -join "|") -ceq
            "limit_positive|limit_negative" -and
        [bool]$cells.limit_active_separation.motor_enabled -and
        [bool]$cells.limit_active_separation.joint_limits_enabled -and
        (@($cells.limit_active_separation.canonical_target_velocity_rad_s) -join ",") -ceq
            "2,-2" -and
        [double]$cells.limit_active_separation.public_maximum_motor_impulse_nms -eq 0.01 -and
        [double]$cells.limit_active_separation.lower_limit_rad -eq -0.02 -and
        [double]$cells.limit_active_separation.upper_limit_rad -eq 0.02 -and
        [int]$cells.limit_active_separation.retained_step_count -eq 20 -and
        (@($cells.sleeping_freshness.cell_ids) -join "|") -ceq "sleep_stale" -and
        [bool]$cells.sleeping_freshness.motor_enabled -and
        [int]$cells.sleeping_freshness.retained_step_count -eq 4 -and
        [int]$cells.sleeping_freshness.force_sleep_after_retained_step -eq 1
    ) "cell_families"

    $expectedMeasurements = @(
        "pre_canonical_relative_rate_rad_s",
        "post_canonical_relative_rate_rad_s",
        "inverse_inertia_axis_kg_inv_m2",
        "integrated_canonical_angle_rad",
        "host_target_velocity_readback_rad_s",
        "joint_limit_lower_readback_rad",
        "joint_limit_upper_readback_rad",
        "telemetry_schema",
        "telemetry_sequence",
        "capture_space_step_sequence",
        "read_space_step_sequence",
        "captured_during_active_step",
        "snapshot_is_current_space_step",
        "solver_step_s",
        "motor_state",
        "target_angular_velocity_rad_s",
        "min_torque_limit_nm",
        "max_torque_limit_nm",
        "signed_motor_impulse_nms",
        "positive_motor_work_j",
        "absorbed_motor_work_j",
        "net_motor_work_j",
        "child_sleeping"
    )
    Assert-R24D9 (
        (@($Contract.required_raw_measurements_per_retained_step) -join "|") -ceq
            ($expectedMeasurements -join "|")
    ) "measurements"

    $timing = $Contract.timing_and_freshness_validity
    Assert-R24D9 (
        [bool]$timing.invalid_rid_must_return_null -and
        [bool]$timing.not_in_tree_joint_read_must_return_null -and
        [bool]$timing.every_awake_retained_sample_requires_captured_during_active_step_true -and
        [bool]$timing.every_awake_retained_sample_requires_current_snapshot_true -and
        [bool]$timing.every_awake_retained_sample_requires_equal_capture_and_read_space_step_sequence -and
        [bool]$timing.every_awake_retained_cell_requires_strictly_increasing_telemetry_sequence -and
        [bool]$timing.sleep_stale_first_sample_requires_current_snapshot_true -and
        [bool]$timing.sleep_stale_later_samples_require_child_sleeping_true -and
        [bool]$timing.sleep_stale_later_samples_require_current_snapshot_false -and
        [bool]$timing.sleep_stale_later_samples_require_constant_telemetry_and_capture_sequence -and
        [bool]$timing.sleep_stale_later_samples_require_strictly_increasing_read_sequence -and
        -not [bool]$timing.stale_snapshot_used_as_fresh_numerical_measurement -and
        -not [bool]$timing.integrate_forces_callback_used_as_active_step_read_oracle -and
        -not [bool]$timing.r24d7_integrate_forces_timing_control_reused
    ) "timing"

    $recompute = $Contract.independent_descriptive_recomputations
    Assert-R24D9 (
        -not [string]::IsNullOrWhiteSpace([string]$recompute.effective_axis_inertia_kg_m2) -and
        -not [string]::IsNullOrWhiteSpace([string]$recompute.independent_angular_momentum_change_nms) -and
        -not [string]::IsNullOrWhiteSpace([string]$recompute.independent_kinetic_energy_change_j) -and
        -not [string]::IsNullOrWhiteSpace([string]$recompute.impulse_residual_nms) -and
        -not [string]::IsNullOrWhiteSpace([string]$recompute.work_residual_j) -and
        -not [string]::IsNullOrWhiteSpace([string]$recompute.motor_impulse_cap_nms) -and
        -not [string]::IsNullOrWhiteSpace([string]$recompute.net_work_decomposition_residual_j) -and
        -not [string]::IsNullOrWhiteSpace([string]$recompute.relative_angle_integral_rad) -and
        -not [bool]$recompute.independent_oracle_uses_instrumented_motor_impulse_or_work_as_input -and
        -not [bool]$recompute.sleeping_stale_samples_enter_numerical_aggregate
    ) "recomputations"

    $evaluation = $Contract.evaluation_contract
    Assert-R24D9 (
        [string]$evaluation.classification -ceq
            "complete_valid_or_invalid_finite_descriptive_development_numerical_characterization" -and
        -not [bool]$evaluation.outcome_dependent_early_stop_allowed -and
        [bool]$evaluation.all_nine_cells_required -and
        [bool]$evaluation.all_68_samples_required -and
        [bool]$evaluation.declared_fixture_and_cell_configuration_must_match_exactly -and
        [bool]$evaluation.runtime_parameter_and_per_sample_public_readbacks_must_match_exactly -and
        [bool]$evaluation.registration_refusal_timing_and_freshness_controls_are_validity_gates -and
        [bool]$evaluation.all_raw_numeric_values_must_be_finite -and
        [bool]$evaluation.descriptive_numerical_findings_are_not_execution_validity_gates -and
        [bool]$evaluation.signed_findings_reported_without_success_threshold -and
        [bool]$evaluation.cap_findings_reported_against_source_derived_hard_solver_bound -and
        [bool]$evaluation.momentum_and_energy_residuals_reported_without_acceptance_threshold -and
        [bool]$evaluation.limit_separation_reported_without_mechanism_selection -and
        [bool]$evaluation.valid_complete_result_may_characterize_exact_fixture_numerical_telemetry -and
        [bool]$evaluation.valid_complete_result_cannot_accept_numerical_accuracy -and
        [bool]$evaluation.valid_complete_result_cannot_promote_runtime_profile -and
        [bool]$evaluation.valid_complete_result_can_authorize_only_distinct_profile_promotion_decision_declaration -and
        -not [bool]$evaluation.turning_evaluator_invoked -and
        -not [bool]$evaluation.recovery_evaluator_invoked -and
        -not [bool]$evaluation.prone_to_standing_evaluator_invoked -and
        -not [bool]$evaluation.physical_acceptance_evaluator_invoked -and
        [bool]$evaluation.same_evaluator_required_for_synthetic_zero_world_canaries_and_physical_report -and
        [bool]$evaluation.synthetic_zero_world_envelope_is_never_a_native_measurement
    ) "evaluation"

    $adequacy = $Contract.threshold_margin_cohort_and_population_adequacy
    Assert-R24D9 (
        [int]$adequacy.empirical_acceptance_threshold_count -eq 0 -and
        [int]$adequacy.superiority_margin_count -eq 0 -and
        [int]$adequacy.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$adequacy.held_out_validation_cohort_count -eq 0 -and
        [int]$adequacy.development_runtime_pair_count -eq 1 -and
        [int]$adequacy.development_world_count -eq 1 -and
        [int]$adequacy.development_fixture_cell_count -eq 9 -and
        [int]$adequacy.population_claim_count -eq 0 -and
        [int]$adequacy.source_derived_hard_configuration_bound_count -eq 1 -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$adequacy.source_derived_hard_configuration_bound
        ) -and
        -not [bool]$adequacy.numerical_residual_acceptance_margin_declared -and
        -not [string]::IsNullOrWhiteSpace([string]$adequacy.adequacy_argument)
    ) "adequacy"

    $expectedNegativeControls = @(
        "duplicate_json_key_rejected",
        "schema_mutation_rejected",
        "gate_id_mutation_rejected",
        "question_class_promotion_rejected",
        "authorization_closure_identity_mutation_rejected",
        "patch_identity_mutation_rejected",
        "runtime_binary_pair_identity_mutation_rejected",
        "world_count_mutation_rejected",
        "cell_count_mutation_rejected",
        "cell_omission_rejected",
        "cell_order_mutation_rejected",
        "duplicate_cell_identity_rejected",
        "sample_omission_rejected",
        "sample_order_mutation_rejected",
        "non_finite_numeric_encoding_rejected",
        "telemetry_schema_mutation_rejected",
        "telemetry_field_omission_rejected",
        "non_integer_telemetry_sequence_rejected",
        "non_integer_capture_sequence_rejected",
        "non_integer_read_sequence_rejected",
        "active_capture_false_rejected",
        "active_current_false_rejected",
        "sleeping_stale_current_true_rejected",
        "sleeping_stale_telemetry_advance_rejected",
        "direct_force_write_mutation_rejected",
        "direct_torque_write_mutation_rejected",
        "direct_impulse_write_mutation_rejected",
        "post_activation_transform_write_mutation_rejected",
        "outcome_dependent_early_stop_mutation_rejected",
        "contact_count_mutation_rejected",
        "fixture_axis_sign_mutation_rejected",
        "fixture_inertia_representation_mutation_rejected",
        "parameter_readback_mutation_rejected",
        "limit_readback_mutation_rejected",
        "invalid_rid_non_refusal_rejected",
        "not_in_tree_non_refusal_rejected",
        "motor_state_mutation_rejected",
        "non_positive_solver_step_rejected",
        "cap_source_mutation_rejected",
        "work_decomposition_mutation_rejected",
        "numerical_accuracy_claim_promotion_rejected",
        "instrumented_profile_promotion_rejected",
        "recovery_claim_promotion_rejected",
        "prone_to_standing_claim_promotion_rejected",
        "cross_engine_claim_promotion_rejected",
        "release_claim_promotion_rejected"
    )
    Assert-R24D9 (
        [int]$Contract.negative_controls.declared_count -eq 46 -and
        (@($Contract.negative_controls.required_rejections) -join "|") -ceq
            ($expectedNegativeControls -join "|")
    ) "negative_controls"

    $implementation = $Contract.implementation_state_at_declaration
    Assert-R24D9 (
        [bool]$implementation.preregistration_written -and
        [bool]$implementation.declaration_audit_written -and
        -not [bool]$implementation.rig_implemented -and
        -not [bool]$implementation.worker_implemented -and
        -not [bool]$implementation.evaluator_implemented -and
        -not [bool]$implementation.validation_manifest_written -and
        -not [bool]$implementation.freeze_audit_written -and
        -not [bool]$implementation.supervisor_implemented -and
        -not [bool]$implementation.complete_zero_world_gate_implemented -and
        -not [bool]$implementation.complete_zero_world_gate_passed -and
        -not [bool]$implementation.physical_world_opened -and
        [int]$implementation.world_attempt_count -eq 0 -and
        [int]$implementation.world_build_count -eq 0 -and
        [int]$implementation.solver_step_count -eq 0
    ) "implementation_state"

    $physical = $Contract.physical_authorization
    Assert-R24D9 (
        -not [bool]$physical.permitted_now -and
        @($physical.required_before_permission).Count -eq 12 -and
        [int]$physical.same_source_physical_attempt_limit -eq 1 -and
        -not [bool]$physical.same_source_physical_rerun_allowed -and
        -not [bool]$physical.physical_result_exists
    ) "physical_authorization"

    $claims = $Contract.claims
    Assert-R24D9 (
        [bool]$claims.prospective_development_question_declared -and
        -not [bool]$claims.complete_zero_world_gate_passed -and
        -not [bool]$claims.physical_characterization_executed -and
        -not [bool]$claims.native_sign_characterized -and
        -not [bool]$claims.native_impulse_cap_characterized -and
        -not [bool]$claims.native_work_energy_characterized -and
        -not [bool]$claims.native_limit_separation_characterized -and
        -not [bool]$claims.native_motor_disabled_zero_characterized -and
        -not [bool]$claims.native_refusal_timing_and_freshness_characterized -and
        -not [bool]$claims.native_numerical_telemetry_characterized -and
        -not [bool]$claims.numerical_accuracy_accepted -and
        -not [bool]$claims.instrumented_profile_promoted -and
        -not [bool]$claims.stock_godot_profile_promoted -and
        -not [bool]$claims.recovery_world_opened -and
        -not [bool]$claims.prone_to_standing_world_opened -and
        -not [bool]$claims.turning_claim_changed -and
        -not [bool]$claims.cross_engine_equivalence_claimed -and
        -not [bool]$claims.q_sdk_r24_satisfied -and
        -not [bool]$claims.physical_acceptance_authority -and
        -not [bool]$claims.release_authority
    ) "claims"
}

$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R24D9 ($LASTEXITCODE -eq 0) "git_root_lookup"
Assert-R24D9 (
    [IO.Path]::GetFullPath($actualRoot) -ceq
    [IO.Path]::GetFullPath($expectedRepoRoot)
) "repo_root"
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R24D9 ($LASTEXITCODE -eq 0) "git_remote_lookup"
Assert-R24D9 ($actualRemote -ceq $expectedRemote) "repo_remote"
Assert-R24D9 (Test-Path -LiteralPath $contractPath -PathType Leaf) "contract_missing"

$rawContract = Get-Content -LiteralPath $contractPath -Raw
Assert-R24D9 (-not $rawContract.Contains("`r")) "contract_not_lf"
$contract = $rawContract | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D9Contract -Contract $contract

$bindings = @(
    @{
        Path = Join-Path $repoRoot $parentClosureRelative
        Sha256 = "a068b13f8fa97db5559572b1a221bff262da4c3d933a2544198ec67156cbba4d"
    },
    @{
        Path = Join-Path $repoRoot $parentAuditRelative
        Sha256 = "9f8ef518e3168107188cb2e5dcc488b25e969983bdd48601bc750d4cf93d0cf1"
    },
    @{
        Path = Join-Path $repoRoot $r24d7PreregistrationRelative
        Sha256 = "6837bc21d5ea0b16c17a19ce053e6f28f1ef6ec3f14dcc95dd4e763ac52c7dc4"
    },
    @{
        Path = Join-Path $repoRoot $r24d7ClosureRelative
        Sha256 = "6a71d1051bea9d1b47cb6b4b9ecc5550ef38e0f49cde2495f1815e5f83b27702"
    },
    @{
        Path = Join-Path $repoRoot $patchRelative
        Sha256 = "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
    }
)
foreach ($binding in $bindings) {
    Assert-R24D9 (
        Test-Path -LiteralPath $binding.Path -PathType Leaf
    ) "binding_missing:$($binding.Path)"
    Assert-R24D9 (
        (Get-R24D9Sha256 -Path $binding.Path) -ceq [string]$binding.Sha256
    ) "binding_hash:$($binding.Path)"
}

$casBindings = @(
    @{
        Sha256 = "8a629f16859f653d447cd7f07f712f0045a1aed3f27be53413d97df6ff1ec0e6"
        ByteLength = 293376L
    },
    @{
        Sha256 = "0d77df42106c6d2f6fa51727d8051bf403e8a0273b3242daee581c93c4ba7257"
        ByteLength = 188829184L
    },
    @{
        Sha256 = "f89f37b077e329c57fde787ddd4adae307dc7ead033b6f896b9497d764014855"
        ByteLength = 19078L
    },
    @{
        Sha256 = "a4bf658df837eaa991aa4421cbba1398949d1267558c738d5c5eb930800d886b"
        ByteLength = 16610L
    }
)
foreach ($binding in $casBindings) {
    $payload = Join-Path (
        Join-Path (
            Join-Path $evidenceRoot "artifacts\sha256"
        ) ([string]$binding.Sha256)
    ) "payload.bin"
    Assert-R24D9 (Test-Path -LiteralPath $payload -PathType Leaf) (
        "cas_missing:$($binding.Sha256)"
    )
    Assert-R24D9 (
        (Get-Item -LiteralPath $payload).Length -eq [long]$binding.ByteLength -and
        (Get-R24D9Sha256 -Path $payload) -ceq [string]$binding.Sha256
    ) "cas_identity:$($binding.Sha256)"
}

$parentOutput = & pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot $parentAuditRelative) 2>&1 | Out-String
Assert-R24D9 (
    $LASTEXITCODE -eq 0 -and
    $parentOutput.Contains(
        "QSDK_R24D8_ACTIVE_STEP_SNAPSHOT_TIMING_POSITIVE_CLOSURE_PASS"
    )
) "parent_closure_audit"
$global:LASTEXITCODE = 0

$mutations = @(
    @{ Name = "schema"; Apply = { param($m) $m.schema_version = "mutated" } },
    @{ Name = "gate"; Apply = { param($m) $m.gate_id = "QSDK-R24D8" } },
    @{ Name = "status"; Apply = { param($m) $m.status = "physical_ready" } },
    @{ Name = "question_class"; Apply = { param($m) $m.question_class = "superiority" } },
    @{ Name = "closure_hash"; Apply = { param($m) $m.authorization_source.closure_raw_sha256 = "sha256:00" } },
    @{ Name = "next_declaration"; Apply = { param($m) $m.authorization_source.next_declaration_authorized = $false } },
    @{ Name = "next_physical"; Apply = { param($m) $m.authorization_source.next_physical_execution_authorized = $true } },
    @{ Name = "r24d7_reinterpretation"; Apply = { param($m) $m.non_reuse_and_non_reinterpretation.r24d7_result_reinterpreted = $true } },
    @{ Name = "r24d8_threshold_selection"; Apply = { param($m) $m.non_reuse_and_non_reinterpretation.r24d8_raw_numerical_values_used_to_select_r24d9_thresholds = $true } },
    @{ Name = "patch_hash"; Apply = { param($m) $m.engine_and_runtime_freeze.combined_patch_raw_sha256 = "sha256:00" } },
    @{ Name = "console_binary"; Apply = { param($m) $m.engine_and_runtime_freeze.r24d8_retained_console_binary_raw_sha256 = "sha256:00" } },
    @{ Name = "engine_binary"; Apply = { param($m) $m.engine_and_runtime_freeze.r24d8_retained_engine_binary_raw_sha256 = "sha256:00" } },
    @{ Name = "ticks"; Apply = { param($m) $m.engine_and_runtime_freeze.physics_ticks_per_second = 60 } },
    @{ Name = "telemetry_fields"; Apply = { param($m) $m.engine_and_runtime_freeze.telemetry_field_count = 14 } },
    @{ Name = "source_count"; Apply = { param($m) $m.prospective_source.implementation_source_file_count_at_declaration = 1 } },
    @{ Name = "world_count"; Apply = { param($m) $m.fixture_freeze.world_count = 2 } },
    @{ Name = "cell_count"; Apply = { param($m) $m.fixture_freeze.isolated_cell_count = 8 } },
    @{ Name = "sample_count"; Apply = { param($m) $m.fixture_freeze.retained_sample_count = 67 } },
    @{ Name = "cell_order"; Apply = { param($m) $m.fixture_freeze.cell_ids_in_order[0] = "drive_negative" } },
    @{ Name = "drive_target"; Apply = { param($m) $m.cell_families.signed_drive.canonical_target_velocity_rad_s[0] = 2.0 } },
    @{ Name = "disabled_motor"; Apply = { param($m) $m.cell_families.motor_disabled.motor_enabled = $true } },
    @{ Name = "limit_upper"; Apply = { param($m) $m.cell_families.limit_active_separation.upper_limit_rad = 0.03 } },
    @{ Name = "sleep_steps"; Apply = { param($m) $m.cell_families.sleeping_freshness.retained_step_count = 3 } },
    @{ Name = "measurement_omission"; Apply = { param($m) $m.required_raw_measurements_per_retained_step = @($m.required_raw_measurements_per_retained_step | Select-Object -Skip 1) } },
    @{ Name = "active_current"; Apply = { param($m) $m.timing_and_freshness_validity.every_awake_retained_sample_requires_current_snapshot_true = $false } },
    @{ Name = "stale_as_fresh"; Apply = { param($m) $m.timing_and_freshness_validity.stale_snapshot_used_as_fresh_numerical_measurement = $true } },
    @{ Name = "empirical_threshold"; Apply = { param($m) $m.threshold_margin_cohort_and_population_adequacy.empirical_acceptance_threshold_count = 1 } },
    @{ Name = "population"; Apply = { param($m) $m.threshold_margin_cohort_and_population_adequacy.population_claim_count = 1 } },
    @{ Name = "negative_count"; Apply = { param($m) $m.negative_controls.declared_count = 45 } },
    @{ Name = "physical_permission"; Apply = { param($m) $m.physical_authorization.permitted_now = $true } },
    @{ Name = "profile_promotion"; Apply = { param($m) $m.claims.instrumented_profile_promoted = $true } },
    @{ Name = "prone_promotion"; Apply = { param($m) $m.claims.prone_to_standing_world_opened = $true } },
    @{ Name = "release_promotion"; Apply = { param($m) $m.claims.release_authority = $true } }
)

$rejected = 0
foreach ($mutation in $mutations) {
    $mutant = Copy-R24D9Value -Value $contract
    & $mutation.Apply $mutant
    $wasRejected = $false
    try {
        Assert-R24D9Contract -Contract $mutant
    } catch {
        $wasRejected = $true
    }
    Assert-R24D9 $wasRejected "mutation_not_rejected:$($mutation.Name)"
    $rejected++
}

Assert-R24D9 ($rejected -eq 33) "mutation_count"

Write-Host (
    "QSDK_R24D9_NUMERICAL_TELEMETRY_PREREGISTRATION_PASS " +
    "question=development cells=9 samples=68 max_steps=20 " +
    "empirical_thresholds=0 margins=0 cohorts=0 population_claims=0 " +
    "declared_negatives=46 declaration_mutations=$rejected " +
    "worlds=0 builds=0 solver_steps=0 physical_authority=False " +
    "profile_promoted=False recovery=False prone=False release=False"
)
