extends "res://tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## R23D71 finite-decision binding of the accepted Godot/Jolt turning worker.
##
## This script owns the fresh campaign identity, seed fixture, compact physical
## authorization, R23D71 trace retention, and terminal projection. The genuine
## Jolt world, public-profile binding, controller loop, schedule compiler, and
## observation path stay in the accepted R23D65/R23D48 worker lineage.

const R23D71BaseWorkerScript := preload("res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd")
const R23D71R48WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
)
const R23D71WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R23D71JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const R23D71ReceiptContractScript := preload(
	"res://sdk/turning/r23d71_receipt_contract.gd"
)

const R23D71_PREREGISTRATION_PATH := "res://sdk/turning/r23d71_success_terminal_projection_repaired_three_engine_turning_preregistration_v1.json"
const R23D71_INHERITED_BEHAVIOR_PATH := "res://sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json"
const R23D71_IMMEDIATE_BASE_PATH := "res://sdk/turning/r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json"
const R23D71_IMPLEMENTATION_PATH := "res://sdk/turning/r23d71_production_route_three_engine_turning_implementation_v1.json"
const R23D71_EVALUATOR_PATH := "res://sdk/turning/r23d71_production_route_three_engine_turning_evaluator.py"
const R23D71_CLOSURE_PATH := "res://sdk/turning/r23d71_production_route_three_engine_turning_validation_closure_v1.json"
const R23D71_WORKER_PATH := "tests/test_sdk_qsdk_r23d71_godot_jolt_worker.gd"
const R23D71_SHARED_KERNEL_PATH := "tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
const R23D71_IMPLEMENTATION_SCHEMA := "sporespore_qsdk_r23d71_production_route_three_engine_turning_implementation_v1"
const R23D71_PREREGISTRATION_SCHEMA := "sporespore_qsdk_r23d71_success_terminal_projection_repaired_three_engine_turning_preregistration_v1"

const R23D71_CAMPAIGN_ID := "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-THREE-ENGINE-TURNING-VALIDATION"
const R23D71_GATE_ID := "QSDK-R23D71"
const R23D71_STAGE_ID := "success_terminal_projection_repaired_three_engine_turning_validation"
const R23D71_ENGINE_ID := "godot_jolt"
const R23D71_ONSET_ID := "onset_600"
const R23D71_CAMPAIGN_SEED := 23191
const R23D71_CONTROLLER_STEPS := 2992
const R23D71_TURN_START_STEP := 600
const R23D71_TURN_END_STEP_EXCLUSIVE := 1800
const R23D71_RECOVERY_END_STEP_EXCLUSIVE := 2400
const R23D71_PROFILE_ID := "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
const R23D71_PROFILE_SHA256 := "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
const R23D71_HOST_MAPPING_ID := "sporespore_godot_hinge_maximum_impulse_cap_mapping_v1"
const R23D71_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const R23D71_TASK_ORIGIN_POLICY_ID := "warmup_preserving_command_onset_origin_reanchor_v1"
const R23D71_LIVE_FIXTURE_BINDING_POLICY_ID := "sporespore_godot_jolt_public_actuator_cap_profile_binding_v1"
const R23D71_GODOT_RUNTIME_VERSION := "4.7-stable (official)"
const R23D71_ORDERED_ENGINE_IDS := ["godot_jolt", "rapier_parry", "mujoco"]
const R23D71_ORDERED_ARM_IDS := [
	"reference_zero",
	"positive_heading",
	"negative_heading",
]
const R23D71_ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}

const R23D71_PREFLIGHT_SCHEMA := "sporespore_qsdk_r23d71_godot_jolt_worker_preflight_v1"
const R23D71_AUTHORIZATION_SCHEMA := "sporespore_qsdk_r23d71_godot_jolt_authorization_v1"
const R23D71_REPORT_SCHEMA := "sporespore_qsdk_r23d71_engine_cell_report_v1"
const R23D71_FAILURE_SCHEMA := "sporespore_qsdk_r23d71_worker_failure_v1"
const R23D71_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d71_turning_trace_row_v1"
const R23D71_TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d71_trace_retention_v1"
const R23D71_TRACE_TRANSPORT_ID := "sporespore_r23d71_full_precision_native_trace_transport_v1"
const R23D71_TRACE_TRANSPORT_INVOCATION := 'JSON.stringify(value, "", true, true)'
const R23D71_FREEZE_SCHEMA := "sporespore_qsdk_r23d71_physical_freeze_v1"
const R23D71_ATTEMPT_SCHEMA := "sporespore_qsdk_r23d71_physical_attempt_v1"

const R23D71_FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D71_FREEZE"
const R23D71_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D71_ATTEMPT"
const R23D71_TOKEN_ENV := "SPORESPORE_QSDK_R23D71_TOKEN"
const R23D71_STAGE_ENV := "SPORESPORE_QSDK_R23D71_STAGE"
const R23D71_CELL_ENV := "SPORESPORE_QSDK_R23D71_CELL"
const R23D71_ENGINE_ENV := "SPORESPORE_QSDK_R23D71_ENGINE"
const R23D71_ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D71_ATTEMPT_ROOT"
const R23D71_AUTHORITY_REPO_ROOT_ENV := "SPORESPORE_QSDK_R23D71_AUTHORITY_REPO_ROOT"
const R23D71_PYTHON_ENV := "SPORESPORE_QSDK_R23D71_PYTHON"
const R23D71_POWERSHELL_ENV := "SPORESPORE_QSDK_R23D71_POWERSHELL"

const R23D71_FALSE_CLAIMS := {
	"r23d71_finite_three_engine_turning": false,
	"finite_three_engine_turning": false,
	"portable_basic_turning": false,
	"q_sdk_r23_satisfied": false,
	"cross_engine_equivalence": false,
	"population_robustness": false,
	"arbitrary_quadruped_coverage": false,
	"prone_to_standing": false,
	"release_authorized": false,
	"physical_acceptance_authority": false,
}


func _run() -> void:
	var parsed := _r23d71_parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D71_GODOT_JOLT_FAILURE ", R23D71JsonTransportScript.stringify(parsed))
		_r23d65_schedule_quit(1, "failure")
		return
	var cell := _r23d71_cell(
		String(parsed["stage_id"]),
		String(parsed["onset_id"]),
		int(parsed["campaign_seed"]),
		String(parsed["profile_id"]),
		String(parsed["arm_id"]),
	)
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D71_GODOT_JOLT_FAILURE ", R23D71JsonTransportScript.stringify(cell))
		_r23d65_schedule_quit(1, "failure")
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _r23d71_run_preflight(cell)
		var preflight_ok := bool(preflight.get("ok", false))
		print(
			(
				"QSDK_R23D71_GODOT_JOLT_PREFLIGHT "
				if preflight_ok
				else "QSDK_R23D71_GODOT_JOLT_FAILURE "
			),
			R23D71JsonTransportScript.stringify(preflight),
		)
		_r23d65_schedule_quit(0 if preflight_ok else 1, "preflight" if preflight_ok else "failure")
		return
	if bool(parsed["authorization_preflight_only"]):
		var authorization := _r23d71_physical_authorization(
			cell,
			String(parsed["source_commit"]),
		)
		var authorization_ok := bool(authorization.get("ok", false))
		print(
			(
				"QSDK_R23D71_GODOT_JOLT_AUTHORIZATION "
				if authorization_ok
				else "QSDK_R23D71_GODOT_JOLT_FAILURE "
			),
			R23D71JsonTransportScript.stringify(authorization),
		)
		_r23d65_schedule_quit(
			0 if authorization_ok else 1,
			"authorization_preflight" if authorization_ok else "failure",
		)
		return
	var terminal: Dictionary = await _r23d48_run_physical(
		cell,
		String(parsed["source_commit"]),
	)
	terminal = _r23d71_terminal(terminal, cell, String(parsed["source_commit"]))
	var success := String(terminal.get("schema_version", "")) == R23D71_REPORT_SCHEMA
	print("QSDK_R23D71_GODOT_JOLT_TERMINAL ", R23D71JsonTransportScript.stringify(terminal))
	_r23d65_schedule_quit(0 if success else 1, "terminal")


func _campaign_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	return _r23d71_physical_authorization(cell, source_commit)


func _campaign_run_preflight(cell: Dictionary) -> Dictionary:
	return await _r23d71_run_preflight(cell)


func _campaign_prepare(cell: Dictionary) -> Dictionary:
	var contract := _r23d71_implementation_contract()
	if not bool(contract.get("ok", false)):
		return contract
	var declaration := R23D71BaseWorkerScript._read_json(R23D71_PREREGISTRATION_PATH)
	var inherited := R23D71BaseWorkerScript._read_json(R23D71_INHERITED_BEHAVIOR_PATH)
	var matrix: Dictionary = declaration.get("frozen_matrix", {})
	var inherited_matrix: Dictionary = inherited.get("frozen_matrix", {})
	var declared_cell := (
		cell.duplicate(true)
		if matrix.get("ordered_cell_ids", []).has(String(cell.get("cell_id", "")))
		else {}
	)
	var declaration_exact: bool = (
		String(declaration.get("schema_version", "")) == R23D71_PREREGISTRATION_SCHEMA
		and (
			String(declaration.get("status", ""))
			== (
				"prospective_declaration_complete_compact_success_terminal_projection_"
				+ "ghost_and_implementation_pending_physical_not_authorized"
			)
		)
		and String(declaration.get("campaign_id", "")) == R23D71_CAMPAIGN_ID
		and String(declaration.get("gate_id", "")) == R23D71_GATE_ID
		and not bool(declaration.get("claims", {}).get("physical_campaign_opened", true))
		and (
			String(declaration.get("inherited_behavior_contract", {}).get("immediate_base_path", ""))
			== R23D71_IMMEDIATE_BASE_PATH.trim_prefix("res://")
		)
		and (
			String(declaration.get("inherited_behavior_contract", {}).get("immediate_base_raw_sha256", ""))
			== R23D71BaseWorkerScript._raw_file_sha256(R23D71_IMMEDIATE_BASE_PATH)
		)
		and matrix.get("engine_order", []) == R23D71_ORDERED_ENGINE_IDS
		and matrix.get("arm_order", []) == R23D71_ORDERED_ARM_IDS
		and matrix.get("arm_heading_offsets_rad", {}) == R23D71_ARM_OFFSETS
		and int(matrix.get("campaign_seed", -1)) == R23D71_CAMPAIGN_SEED
		and int(matrix.get("declared_cell_count", -1)) == 9
		and matrix.get("ordered_cell_ids", []) == _r23d71_expected_cell_ids()
		and bool(matrix.get("complete_population_required", false))
		and not bool(matrix.get("sampling_used", true))
		and int(inherited_matrix.get("controller_step_count", -1)) == R23D71_CONTROLLER_STEPS
		and int(inherited_matrix.get("turn_start_step", -1)) == R23D71_TURN_START_STEP
		and int(inherited_matrix.get("turn_end_step_exclusive", -1)) == R23D71_TURN_END_STEP_EXCLUSIVE
		and (
			int(inherited_matrix.get("recovery_duration_steps", -1))
			== R23D71_RECOVERY_END_STEP_EXCLUSIVE - R23D71_TURN_END_STEP_EXCLUSIVE
		)
		and String(inherited_matrix.get("controller_policy_id", "")) == R23D71_POLICY_ID
		and String(inherited_matrix.get("task_frame_origin_policy_id", "")) == R23D71_TASK_ORIGIN_POLICY_ID
		and bool(inherited_matrix.get("serial_execution_required", false))
		and bool(inherited_matrix.get("fresh_world_required_per_cell", false))
		and (
			String(declaration.get("inherited_behavior_contract", {}).get("root_base_raw_sha256", ""))
			== R23D71BaseWorkerScript._raw_file_sha256(R23D71_INHERITED_BEHAVIOR_PATH)
		)
		and String(declared_cell.get("engine_id", "")) == R23D71_ENGINE_ID
		and String(declared_cell.get("arm_id", "")) == String(cell["arm_id"])
		and (
			float(declared_cell.get("turn_heading_offset_rad", INF))
			== float(cell["turn_heading_offset_rad"])
		)
	)
	if not declaration_exact:
		return _r23d71_failure(
			"QSDK_R23D71_GJT_DECLARATION_INVALID",
			{"declared_cell": declared_cell, "live_cell": cell},
		)

	# Compile the already accepted full-horizon fixture and replace only the
	# prospectively frozen R23D71 identity and deterministic seed fixture.
	var prepared := R23D71BaseWorkerScript._prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r23d71_rebrand_failure(prepared)
	var trace_options: Dictionary = (prepared.get("trace_options", {}) as Dictionary).duplicate(
		true
	)
	trace_options["trace_row_schema_version"] = R23D48_TRACE_ROW_SCHEMA
	trace_options["post_schedule_segment_id"] = "reference_continuation"
	trace_options["actuator_phase_observation_schema_version"] = (
		R23D71WaveGaitScript.SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA
	)
	var trace_result := R23D71WaveGaitScript.compile_sdk_physical_trace_options(trace_options)
	if not bool(trace_result.get("ok", false)):
		return _r23d71_rebrand_failure(trace_result)
	prepared["trace_options"] = trace_options
	prepared["trace_configuration_sha256"] = String(
		trace_result["sdk_physical_trace_configuration_sha256"]
	)
	var perturbation_result := R23D71WaveGaitScript.compile_seeded_initial_perturbation(
		R23D71_CAMPAIGN_SEED
	)
	if not bool(perturbation_result.get("ok", false)):
		return _r23d71_rebrand_failure(perturbation_result)
	var perturbation: Dictionary = perturbation_result["initial_perturbation"]
	var expected: Dictionary = (
		(declaration.get("seed_fixture_compilation", {}).get("compiled_initial_perturbation", {}) as Dictionary)
		. duplicate(true)
	)
	expected.erase("cohort")
	if not R23D71R48WorkerScript._r23d48_perturbation_exact(perturbation, expected):
		return _r23d71_failure(
			"QSDK_R23D71_GJT_INITIAL_PERTURBATION_MISMATCH",
			{
				"compiled": R23D71BaseWorkerScript._json_initial_perturbation(perturbation),
				"declared": expected,
			},
		)
	prepared["initial_perturbation"] = perturbation
	var authority: Dictionary = (prepared["authority_options"] as Dictionary).duplicate(true)
	authority["controller_policy_id"] = R23D71_POLICY_ID
	authority["task_frame_origin_policy_id"] = R23D71_TASK_ORIGIN_POLICY_ID
	authority["live_fixture_actuator_cap_binding_policy_id"] = (R23D71_LIVE_FIXTURE_BINDING_POLICY_ID)
	authority["live_fixture_actuator_cap_binding_profile_id"] = R23D71_PROFILE_ID
	authority["descriptor"] = (prepared["descriptor"] as Dictionary).duplicate(true)
	prepared["authority_options"] = authority
	prepared["profile_id"] = R23D71_PROFILE_ID
	prepared["profile_sha256"] = R23D71_PROFILE_SHA256
	prepared["host_mapping_id"] = R23D71_HOST_MAPPING_ID
	prepared["campaign_seed"] = R23D71_CAMPAIGN_SEED
	prepared["expected_matrix_cell_ids"] = _r23d71_expected_cell_ids()
	prepared["expected_matrix_cell_count"] = 9
	prepared["authorization_validates_complete_nine_cell_matrix"] = true
	return prepared


func _campaign_trace_diagnostic(
	cell: Dictionary,
	trace_container: Dictionary,
) -> Dictionary:
	var diagnostic := R23D71R48WorkerScript._r23d48_trace_diagnostic(cell, trace_container)
	diagnostic["schema_version"] = "sporespore_qsdk_r23d71_trace_diagnostic_v1"
	diagnostic["campaign_id"] = R23D71_CAMPAIGN_ID
	diagnostic["gate_id"] = R23D71_GATE_ID
	diagnostic["stage_id"] = R23D71_STAGE_ID
	diagnostic["campaign_seed"] = int(cell["campaign_seed"])
	diagnostic["profile_id"] = String(cell["profile_id"])
	diagnostic["host_mapping_id"] = String(cell["host_mapping_id"])
	return diagnostic


func _campaign_retain_trace_diagnostic(
	cell: Dictionary,
	diagnostic: Dictionary,
	attempt_root: String,
) -> Dictionary:
	return (
		R23D71R48WorkerScript
		. _r23d48_retain_trace_diagnostic(
			cell,
			diagnostic,
			attempt_root,
			R23D71_POWERSHELL_ENV,
		)
	)


func _campaign_trace_diagnostic_summary(diagnostic: Dictionary) -> Dictionary:
	return R23D71R48WorkerScript._r23d48_trace_diagnostic_summary(diagnostic)


func _campaign_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	return _r23d71_retain_trace(cell, rows, attempt_root)


func _r23d71_run_preflight(cell: Dictionary) -> Dictionary:
	var solver := R23D71BaseWorkerScript._apply_solver_configuration()
	if not bool(solver.get("ok", false)):
		return _r23d71_rebrand_failure(solver)
	var prepared := _campaign_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
	var entrypoint: Dictionary = await _run_wave(prepared, true)
	var trace_options: Dictionary = entrypoint.get("sdk_physical_trace_options", {})
	var ramp: Dictionary = entrypoint.get("sdk_startup_velocity_ramp_preflight", {})
	var authority: Dictionary = prepared.get("authority_options", {})
	var declaration := R23D71BaseWorkerScript._read_json(R23D71_PREREGISTRATION_PATH)
	var expected: Dictionary = (
		declaration
		. get("seed_fixture_compilation", {})
		. get(
			"compiled_initial_perturbation",
			{},
		)
		. duplicate(true)
	)
	expected.erase("cohort")
	var implementation_contract := _r23d71_implementation_contract()
	var dependencies: Dictionary = (
		(implementation_contract.get("implementation", {}) as Dictionary)
		. get("dependency_digests", {})
	)
	var exact: bool = (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and bool(entrypoint.get("candidate_authority_horizon_enabled", false))
		and (
			int(entrypoint.get("candidate_authority_observation_count", -1))
			== R23D71_CONTROLLER_STEPS
		)
		and bool(entrypoint.get("sdk_physical_trace_enabled", false))
		and int(trace_options.get("exact_controller_step_count", -1)) == R23D71_CONTROLLER_STEPS
		and String(trace_options.get("cell_id", "")) == String(cell["cell_id"])
		and String(trace_options.get("trace_row_schema_version", "")) == R23D48_TRACE_ROW_SCHEMA
		and bool(entrypoint.get("sdk_startup_velocity_ramp_enabled", false))
		and bool(ramp.get("ok", false))
		and String(authority.get("controller_policy_id", "")) == R23D71_POLICY_ID
		and String(authority.get("task_frame_origin_policy_id", "")) == R23D71_TASK_ORIGIN_POLICY_ID
		and (
			String(authority.get("live_fixture_actuator_cap_binding_policy_id", ""))
			== R23D71_LIVE_FIXTURE_BINDING_POLICY_ID
		)
		and (
			String(authority.get("live_fixture_actuator_cap_binding_profile_id", ""))
			== R23D71_PROFILE_ID
		)
		and bool(entrypoint.get("sdk_live_fixture_actuator_cap_binding_enabled", false))
		and not bool(entrypoint.get("sdk_live_fixture_actuator_cap_binding_executed", true))
		and (
			R23D71R48WorkerScript
			. _r23d48_perturbation_exact(
				prepared.get("initial_perturbation", {}),
				expected,
			)
		)
		and bool(implementation_contract.get("ok", false))
		and not dependencies.is_empty()
		and String(Engine.get_version_info().get("string", "")) == R23D71_GODOT_RUNTIME_VERSION
	)
	if not exact:
		return _r23d71_failure(
			"QSDK_R23D71_GJT_PREFLIGHT_INVALID",
			{
				"entrypoint": entrypoint,
				"authority_options": authority,
				"runtime": Engine.get_version_info().get("string", ""),
			},
		)
	return {
		"schema_version": R23D71_PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": R23D71_CAMPAIGN_ID,
		"gate_id": R23D71_GATE_ID,
		"question_class": "finite_decision",
		"stage_id": R23D71_STAGE_ID,
		"cell_id": String(cell["cell_id"]),
		"engine_id": R23D71_ENGINE_ID,
		"campaign_seed": R23D71_CAMPAIGN_SEED,
		"profile_id": R23D71_PROFILE_ID,
		"profile_sha256": R23D71_PROFILE_SHA256,
		"host_mapping_id": R23D71_HOST_MAPPING_ID,
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"controller_step_count": R23D71_CONTROLLER_STEPS,
		"turn_start_step": R23D71_TURN_START_STEP,
		"turn_end_step_exclusive": R23D71_TURN_END_STEP_EXCLUSIVE,
		"recovery_end_step_exclusive": R23D71_RECOVERY_END_STEP_EXCLUSIVE,
		"expected_segment_counts":
		{
			"reference_warmup": 600,
			"commanded_turn": 1200,
			"reference_recovery": 600,
			"reference_continuation": 592,
		},
		"implementation_dependency_count": dependencies.size(),
		"public_profile_route_compiled": true,
		"fresh_perturbation_compiled": true,
		"shared_native_kernel_reused": true,
		"physical_worker_implemented": true,
		"returned_before_model": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}


static func _r23d71_project_complete_trace_row(
	source_row: Dictionary,
	semantic_step: int,
	cell: Dictionary,
) -> Dictionary:
	if int(source_row.get("semantic_step", -1)) != semantic_step:
		return _r23d71_failure("QSDK_R23D71_GJT_TRACE_STEP_INVALID")
	var row := source_row.duplicate(true)
	row["schema_version"] = R23D71_TRACE_ROW_SCHEMA
	row["campaign_id"] = R23D71_CAMPAIGN_ID
	row["gate_id"] = R23D71_GATE_ID
	row["stage_id"] = R23D71_STAGE_ID
	row["engine_id"] = R23D71_ENGINE_ID
	row["cell_id"] = String(cell["cell_id"])
	row["campaign_seed"] = R23D71_CAMPAIGN_SEED
	row["trace_step"] = semantic_step
	var observation := R23D71WaveGaitScript.validate_sdk_actuator_phase_observation(row)
	if not bool(observation.get("ok", false)):
		return _r23d71_failure(
			"QSDK_R23D71_GJT_ACTUATOR_PHASE_OBSERVATION_INVALID",
			observation,
		)
	return {
		"ok": true,
		"failure_code": "",
		"row": row,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d71_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	if rows.size() != R23D71_CONTROLLER_STEPS:
		return _r23d71_failure("QSDK_R23D71_GJT_TRACE_ROW_COUNT_INVALID")
	var projected: Array = []
	for semantic_step in range(rows.size()):
		if typeof(rows[semantic_step]) != TYPE_DICTIONARY:
			return _r23d71_failure("QSDK_R23D71_GJT_TRACE_ROW_TYPE_INVALID")
		var projection := _r23d71_project_complete_trace_row(
			rows[semantic_step] as Dictionary,
			semantic_step,
			cell,
		)
		if not bool(projection.get("ok", false)):
			return projection
		projected.append(projection["row"])
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r23d71_failure("QSDK_R23D71_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join("%s.rows.json" % String(cell["cell_id"]))
	if FileAccess.file_exists(rows_path):
		return _r23d71_failure("QSDK_R23D71_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _r23d71_failure("QSDK_R23D71_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(R23D71JsonTransportScript.stringify(projected))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(R23D71_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(R23D71_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := (
		OS
		. execute(
			python,
			PackedStringArray(
				[
					ProjectSettings.globalize_path(R23D71_EVALUATOR_PATH),
					"retain-trace",
					"--stage-id",
					String(cell["stage_id"]),
					"--cell-id",
					String(cell["cell_id"]),
					"--rows-json",
					rows_path,
					"--repo-root",
					ProjectSettings.globalize_path("res://"),
					"--attempt-root",
					attempt_root,
					"--powershell",
					powershell,
				]
			),
			output,
			true,
		)
	)
	var marker := "QSDK_R23D71_TRACE_RETAINED "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r23d71_failure(
			"QSDK_R23D71_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r23d71_failure("QSDK_R23D71_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	var receipt_failures := R23D71ReceiptContractScript.validate_retention_receipt(
		receipt,
		{
			"schema_version": R23D71_TRACE_RETENTION_SCHEMA,
			"stage_id": String(cell["stage_id"]),
			"cell_id": String(cell["cell_id"]),
			"engine_id": R23D71_ENGINE_ID,
			"campaign_seed": R23D71_CAMPAIGN_SEED,
			"profile_id": R23D71_PROFILE_ID,
			"host_mapping_id": R23D71_HOST_MAPPING_ID,
			"row_count": R23D71_CONTROLLER_STEPS,
			"test_only": false,
		},
	)
	if not receipt_failures.is_empty():
		return _r23d71_failure(
			"QSDK_R23D71_GJT_TRACE_RETENTION_RECEIPT_INVALID",
			{"failures": receipt_failures, "receipt": receipt},
		)
	var artifact: Dictionary = (receipt.get("trace_artifact", {}) as Dictionary).duplicate(true)
	artifact["trace_transport_id"] = R23D71_TRACE_TRANSPORT_ID
	artifact["godot_runtime_version"] = String(Engine.get_version_info().get("string", ""))
	artifact["selected_godot_invocation"] = R23D71_TRACE_TRANSPORT_INVOCATION
	artifact["godot_json_sorted_keys"] = true
	artifact["godot_json_full_precision"] = true
	receipt["trace_artifact"] = artifact
	receipt["trace_transport_id"] = R23D71_TRACE_TRANSPORT_ID
	receipt["godot_runtime_version"] = String(Engine.get_version_info().get("string", ""))
	receipt["godot_json_full_precision"] = true
	receipt["ok"] = true
	receipt["failure_code"] = ""
	return receipt


static func _r23d71_implementation_contract() -> Dictionary:
	if FileAccess.file_exists(R23D71_CLOSURE_PATH):
		return _r23d71_failure("QSDK_R23D71_GJT_CLOSED")
	if not FileAccess.file_exists(R23D71_IMPLEMENTATION_PATH):
		return _r23d71_failure("QSDK_R23D71_GJT_IMPLEMENTATION_UNREADABLE")
	var value := R23D71BaseWorkerScript._read_json(R23D71_IMPLEMENTATION_PATH)
	var workers: Dictionary = value.get("workers", {})
	var worker: Dictionary = workers.get(R23D71_ENGINE_ID, {})
	var claims: Dictionary = value.get("claims", {})
	var dependencies: Dictionary = value.get("dependency_digests", {})
	var exact: bool = (
		String(value.get("schema_version", "")) == R23D71_IMPLEMENTATION_SCHEMA
		and (
			String(value.get("status", ""))
			== (
				"implementation_complete_complete_zero_world_gate_passed_"
				+ "physical_not_authorized"
			)
		)
		and String(value.get("campaign_id", "")) == R23D71_CAMPAIGN_ID
		and String(value.get("gate_id", "")) == R23D71_GATE_ID
		and String(value.get("question_class", "")) == "finite_decision"
		and (
			String(value.get("preregistration_path", ""))
			== R23D71_PREREGISTRATION_PATH.trim_prefix("res://")
		)
		and (
			String(value.get("preregistration_raw_sha256", ""))
			== R23D71BaseWorkerScript._raw_file_sha256(R23D71_PREREGISTRATION_PATH)
		)
		and int(value.get("declared_cell_count", -1)) == 9
		and int(value.get("declared_world_count", -1)) == 9
		and value.get("ordered_cell_ids", []) == _r23d71_expected_cell_ids()
		and String(worker.get("path", "")) == R23D71_WORKER_PATH
		and (
			String(worker.get("raw_sha256", ""))
			== R23D71BaseWorkerScript._raw_file_sha256("res://%s" % R23D71_WORKER_PATH)
		)
		and String(worker.get("shared_native_kernel_path", "")) == R23D71_SHARED_KERNEL_PATH
		and bool(worker.get("shared_native_kernel_reused", false))
		and bool(worker.get("implementation_complete", false))
		and bool(claims.get("implementation_complete", false))
		and bool(claims.get("complete_zero_world_gate_passed", false))
		and not bool(claims.get("physical_campaign_opened", true))
		and not bool(claims.get("q_sdk_r23_satisfied", true))
		and not bool(claims.get("release_authorized", true))
		and _r23d71_dependencies_exact(dependencies)
		and String(Engine.get_version_info().get("string", "")) == R23D71_GODOT_RUNTIME_VERSION
	)
	if not exact:
		return _r23d71_failure("QSDK_R23D71_GJT_IMPLEMENTATION_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"implementation": value,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d71_dependencies_exact(values: Variant) -> bool:
	if typeof(values) != TYPE_DICTIONARY or (values as Dictionary).is_empty():
		return false
	for relative_value in values as Dictionary:
		var relative := String(relative_value)
		var digest := String((values as Dictionary).get(relative, ""))
		if (
			relative.is_empty()
			or relative.is_absolute_path()
			or relative.split("/").has("..")
			or not R23D71BaseWorkerScript._valid_lower_hex(digest.trim_prefix("sha256:"), 64)
			or not FileAccess.file_exists("res://%s" % relative)
			or R23D71BaseWorkerScript._raw_file_sha256("res://%s" % relative) != digest
		):
			return false
	return true


static func _r23d71_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	var contract := _r23d71_implementation_contract()
	if not bool(contract.get("ok", false)):
		return contract
	var freeze_path := OS.get_environment(R23D71_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(R23D71_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(R23D71_TOKEN_ENV)
	var attempt_root := OS.get_environment(R23D71_ATTEMPT_ROOT_ENV)
	var authority_repo_root := OS.get_environment(R23D71_AUTHORITY_REPO_ROOT_ENV)
	if (
		freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or authority_repo_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not R23D71BaseWorkerScript._valid_lower_hex(token, 32)
		or not R23D71BaseWorkerScript._valid_lower_hex(source_commit, 40)
	):
		return _r23d71_failure("QSDK_R23D71_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := R23D71BaseWorkerScript._read_json(freeze_path)
	var attempt := R23D71BaseWorkerScript._read_json(attempt_path)
	var implementation: Dictionary = contract.get("implementation", {})
	var normalized_repo := authority_repo_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var expected_repo := (
		ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/")
	)
	var normalized_attempt := attempt_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var production_root := (
		ProjectSettings
		. globalize_path("res://../SporeSpore_Evidence")
		. simplify_path()
		. replace("\\", "/")
		. trim_suffix("/")
	)
	var expected_cells := _r23d71_expected_cell_ids()
	var environment_key := String(freeze.get("dependency_toolchain_environment_key", ""))
	var exact: bool = (
		normalized_repo == expected_repo
		and (
			normalized_attempt == production_root
			or normalized_attempt.begins_with(production_root + "/")
		)
		and String(freeze.get("schema_version", "")) == R23D71_FREEZE_SCHEMA
		and String(freeze.get("status", "")) == "frozen_supervisor_only_physical_authorized"
		and String(freeze.get("campaign_id", "")) == R23D71_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == R23D71_GATE_ID
		and (
			String(freeze.get("preregistration_raw_sha256", ""))
			== R23D71BaseWorkerScript._raw_file_sha256(R23D71_PREREGISTRATION_PATH)
		)
		and (
			String(freeze.get("implementation_contract_raw_sha256", ""))
			== R23D71BaseWorkerScript._raw_file_sha256(R23D71_IMPLEMENTATION_PATH)
		)
		and String(freeze.get("source_commit", "")) == source_commit
		and String(freeze.get("origin_main_commit", "")) == source_commit
		and String(freeze.get("live_github_main_commit", "")) == source_commit
		and R23D71BaseWorkerScript._valid_lower_hex(
			String(freeze.get("source_tree_git_oid", "")), 40
		)
		and bool(freeze.get("source_worktree_clean", false))
		and bool(freeze.get("complete_zero_world_gate_passed", false))
		and (
			freeze.get("implementation_dependency_digests", {})
			== implementation.get("dependency_digests", {})
		)
		and _r23d71_dependencies_exact(implementation.get("dependency_digests", {}))
		and R23D71BaseWorkerScript._valid_lower_hex(environment_key, 64)
		and int(freeze.get("declared_world_count", -1)) == 9
		and freeze.get("ordered_cell_ids", []) == expected_cells
		and bool(freeze.get("serial_execution_required", false))
		and bool(freeze.get("all_cells_run_regardless_of_intermediate_outcome", false))
		and bool(freeze.get("physical_behavior_thresholds_applied", false))
		and bool(freeze.get("physical_execution_authorized", false))
		and not bool(freeze.get("physical_acceptance_authority", true))
		and String(attempt.get("schema_version", "")) == R23D71_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == R23D71_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == R23D71_GATE_ID
		and String(attempt.get("source_commit", "")) == source_commit
		and (
			String(attempt.get("freeze_raw_sha256", ""))
			== R23D71BaseWorkerScript._raw_file_sha256(freeze_path)
		)
		and String(attempt.get("authorization_token", "")) == token
		and R23D71BaseWorkerScript._valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and String(attempt.get("dependency_toolchain_environment_key", "")) == environment_key
		and attempt.get("ordered_cell_ids", []) == expected_cells
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and bool(attempt.get("physical_execution_authorized", false))
		and not bool(attempt.get("physical_acceptance_authority", true))
		and (
			String(attempt.get("attempt_root", "")).simplify_path().replace("\\", "/").trim_suffix(
				"/"
			)
			== normalized_attempt
		)
		and (
			(
				String(attempt.get("authority_repo_root", ""))
				. simplify_path()
				. replace("\\", "/")
				. trim_suffix("/")
			)
			== normalized_repo
		)
		and OS.get_environment(R23D71_STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(R23D71_CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(R23D71_ENGINE_ENV) == R23D71_ENGINE_ID
	)
	if not exact:
		return _r23d71_failure("QSDK_R23D71_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"schema_version": R23D71_AUTHORIZATION_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": R23D71_CAMPAIGN_ID,
		"gate_id": R23D71_GATE_ID,
		"question_class": "finite_decision",
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"engine_id": R23D71_ENGINE_ID,
		"campaign_seed": R23D71_CAMPAIGN_SEED,
		"attempt_root": normalized_attempt,
		"authorization_passed": true,
		"returned_before_model": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _r23d71_terminal(
	value: Dictionary,
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	var result := _r23d65_rebrand_terminal(value, cell, source_commit)
	var success := String(result.get("schema_version", "")) == R23D65_REPORT_SCHEMA
	result["schema_version"] = R23D71_REPORT_SCHEMA if success else R23D71_FAILURE_SCHEMA
	result["campaign_id"] = R23D71_CAMPAIGN_ID
	result["gate_id"] = R23D71_GATE_ID
	result["question_class"] = "finite_decision"
	result["stage_id"] = R23D71_STAGE_ID
	result["engine_id"] = R23D71_ENGINE_ID
	result["cell_id"] = String(cell["cell_id"])
	result["campaign_seed"] = R23D71_CAMPAIGN_SEED
	result["profile_id"] = R23D71_PROFILE_ID
	result["profile_sha256"] = R23D71_PROFILE_SHA256
	result["host_mapping_id"] = R23D71_HOST_MAPPING_ID
	result["arm_id"] = String(cell["arm_id"])
	result["turn_heading_offset_rad"] = float(cell["turn_heading_offset_rad"])
	result["source_commit"] = source_commit
	result["task_frame_origin_policy_id"] = R23D71_TASK_ORIGIN_POLICY_ID
	result["claims"] = R23D71_FALSE_CLAIMS.duplicate(true)
	result["physical_acceptance_authority"] = false
	if success:
		for root_key in [
			"model_construction_count",
			"world_attempt_count",
			"world_build_count",
			"world_build_count_exact",
			"world_build_count_lower_bound",
			"world_build_count_upper_bound",
		]:
			result.erase(root_key)
	if result.has("failure_code"):
		result["failure_code"] = (
			String(result["failure_code"])
			. replace(
				"QSDK_R23D65",
				"QSDK_R23D71",
			)
		)
	return result


static func _r23d71_expected_cell_ids() -> Array[String]:
	var values: Array[String] = []
	for engine_id in R23D71_ORDERED_ENGINE_IDS:
		for arm_id in R23D71_ORDERED_ARM_IDS:
			values.append(
				"r23d71__%s__s%d__%s" % [String(engine_id), R23D71_CAMPAIGN_SEED, String(arm_id)]
			)
	return values


static func _r23d71_declared_cell(matrix: Dictionary, cell_id: String) -> Dictionary:
	for value in matrix.get("cells", []):
		if typeof(value) == TYPE_DICTIONARY and String(value.get("cell_id", "")) == cell_id:
			return (value as Dictionary).duplicate(true)
	return {}


static func _r23d71_cell(
	stage_id: String,
	onset_id: String,
	campaign_seed: int,
	profile_id: String,
	arm_id: String,
) -> Dictionary:
	if (
		stage_id != R23D71_STAGE_ID
		or onset_id != R23D71_ONSET_ID
		or campaign_seed != R23D71_CAMPAIGN_SEED
		or profile_id != R23D71_PROFILE_ID
		or not R23D71_ARM_OFFSETS.has(arm_id)
	):
		return _r23d71_failure("QSDK_R23D71_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": "r23d71__%s__s%d__%s" % [R23D71_ENGINE_ID, campaign_seed, arm_id],
		"engine_id": R23D71_ENGINE_ID,
		"campaign_seed": campaign_seed,
		"profile_id": profile_id,
		"host_mapping_id": R23D71_HOST_MAPPING_ID,
		"onset_id": onset_id,
		"turn_start_semantic_step": R23D71_TURN_START_STEP,
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(R23D71_ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d71_parse_arguments(args: PackedStringArray) -> Dictionary:
	var values := {}
	var preflight_only := false
	var authorization_preflight_only := false
	var index := 0
	while index < args.size():
		var argument := String(args[index])
		if argument == "--preflight-only" and not preflight_only:
			preflight_only = true
			index += 1
			continue
		if argument == "--authorization-preflight-only" and not authorization_preflight_only:
			authorization_preflight_only = true
			index += 1
			continue
		if ["--stage", "--onset", "--seed", "--profile", "--arm", "--source-commit"].has(argument):
			if values.has(argument) or index + 1 >= args.size():
				return _r23d71_failure("QSDK_R23D71_GJT_ARGUMENT_DUPLICATE_OR_MISSING")
			values[argument] = String(args[index + 1])
			index += 2
			continue
		return _r23d71_failure("QSDK_R23D71_GJT_ARGUMENT_UNKNOWN:%s" % argument)
	var source_required := not preflight_only
	var seed_text := String(values.get("--seed", ""))
	var source_commit := String(values.get("--source-commit", ""))
	if (
		not values.has("--stage")
		or not values.has("--onset")
		or not values.has("--seed")
		or not values.has("--profile")
		or not values.has("--arm")
		or not seed_text.is_valid_int()
		or (preflight_only and authorization_preflight_only)
		or source_required != values.has("--source-commit")
		or (source_required and not R23D71BaseWorkerScript._valid_lower_hex(source_commit, 40))
	):
		return _r23d71_failure("QSDK_R23D71_GJT_ARGUMENTS_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": String(values["--stage"]),
		"onset_id": String(values["--onset"]),
		"campaign_seed": seed_text.to_int(),
		"profile_id": String(values["--profile"]),
		"arm_id": String(values["--arm"]),
		"preflight_only": preflight_only,
		"authorization_preflight_only": authorization_preflight_only,
		"source_commit": source_commit,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d71_rebrand_failure(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result["ok"] = false
	result["failure_code"] = (
		String(result.get("failure_code", "QSDK_R23D71_GJT_INHERITED_FAILURE"))
		. replace("QSDK_R23D3", "QSDK_R23D71")
		. replace(
			"QSDK_R23D48",
			"QSDK_R23D71",
		)
		. replace(
			"QSDK_R23D60",
			"QSDK_R23D71",
		)
		. replace(
			"QSDK_R23D65",
			"QSDK_R23D71",
		)
	)
	return result


static func _r23d71_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": R23D71_FAILURE_SCHEMA,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"campaign_id": R23D71_CAMPAIGN_ID,
		"gate_id": R23D71_GATE_ID,
		"question_class": "finite_decision",
		"stage_id": R23D71_STAGE_ID,
		"engine_id": R23D71_ENGINE_ID,
		"campaign_seed": R23D71_CAMPAIGN_SEED,
		"profile_id": R23D71_PROFILE_ID,
		"host_mapping_id": R23D71_HOST_MAPPING_ID,
		"failure_stage": "before_world",
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"claims": R23D71_FALSE_CLAIMS.duplicate(true),
		"physical_acceptance_authority": false,
	}
