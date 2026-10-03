extends "res://tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Godot/Jolt production worker for the shared three-engine turning route.
##
## Development-ghost and future held-out authority use this same worker. The
## route contract selects the seed, cell set, horizon, and authority lane; this
## worker always uses the selected public policy/profile and genuine Jolt world.

const BaseWorkerScript := preload("res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd")
const R48WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
)
const TurningRouteWaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const ROUTE_CONTRACT_PATH := (
	"res://sdk/turning/three_engine_turning_success_transport_route_v2.json"
)
const ROUTE_EVALUATOR_PATH := (
	"res://sdk/turning/three_engine_turning_route_evaluator.py"
)
const ROUTE_ID := "sporespore_three_engine_turning_success_transport_route_v2"
const ROUTE_ENGINE_ID := "godot_jolt"
const ROUTE_CELL_ID := (
	"turning_success_transport_v2__godot_jolt__s21516__positive_heading"
)
const ROUTE_SEED := 21516
const ROUTE_ARM_ID := "positive_heading"
const ROUTE_HEADING_OFFSET_RAD := 0.2
const ROUTE_CONTROLLER_STEPS := 2
const ROUTE_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const ROUTE_MEMORY_SCHEMA := (
	"sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
)
const ROUTE_PROFILE_ID := (
	"sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
)
const ROUTE_PROFILE_SHA256 := (
	"sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
const ROUTE_HOST_MAPPING_ID := (
	"sporespore_godot_hinge_maximum_impulse_cap_mapping_v1"
)
const ROUTE_TASK_ORIGIN_POLICY_ID := "warmup_preserving_command_onset_origin_reanchor_v1"
const ROUTE_LIVE_FIXTURE_BINDING_POLICY_ID := (
	"sporespore_godot_jolt_public_actuator_cap_profile_binding_v1"
)
const ROUTE_HORIZON_POLICY_ID := "sporespore_turning_route_two_step_horizon_v1"
const ROUTE_HORIZON_POLICY_SHA256 := (
	"sha256:51c63281ddf18e22b3b68e19db2352dd9b0731e62fc1fb748f756ce3949b41b9"
)
const ROUTE_TRACE_POLICY_ID := "sporespore_turning_route_two_step_trace_v1"
const ROUTE_TRACE_ROW_SCHEMA := (
	"sporespore_three_engine_turning_success_transport_trace_row_v2"
)
const ROUTE_REPORT_SCHEMA := (
	"sporespore_three_engine_turning_success_transport_cell_report_v2"
)
const ROUTE_FAILURE_SCHEMA := (
	"sporespore_three_engine_turning_success_transport_worker_failure_v2"
)
const ROUTE_RETENTION_SCHEMA := (
	"sporespore_three_engine_turning_success_transport_trace_retention_v2"
)
const ROUTE_PREFLIGHT_SCHEMA := (
	"sporespore_three_engine_turning_success_transport_godot_jolt_preflight_v2"
)
const ROUTE_FREEZE_SCHEMA := (
	"sporespore_three_engine_turning_success_transport_freeze_v2"
)
const ROUTE_ATTEMPT_SCHEMA := (
	"sporespore_three_engine_turning_success_transport_attempt_v2"
)
const ROUTE_GODOT_RUNTIME_VERSION := "4.7-stable (official)"

const ROUTE_FREEZE_PATH_ENV := "SPORESPORE_TURNING_ROUTE_FREEZE"
const ROUTE_ATTEMPT_PATH_ENV := "SPORESPORE_TURNING_ROUTE_ATTEMPT"
const ROUTE_TOKEN_ENV := "SPORESPORE_TURNING_ROUTE_TOKEN"
const ROUTE_ATTEMPT_ROOT_ENV := "SPORESPORE_TURNING_ROUTE_ATTEMPT_ROOT"
const ROUTE_AUTHORITY_REPO_ROOT_ENV := "SPORESPORE_TURNING_ROUTE_AUTHORITY_REPO_ROOT"
const ROUTE_ENGINE_ENV := "SPORESPORE_TURNING_ROUTE_ENGINE"
const ROUTE_CELL_ENV := "SPORESPORE_TURNING_ROUTE_CELL"
const ROUTE_PYTHON_ENV := "SPORESPORE_TURNING_ROUTE_PYTHON"
const ROUTE_POWERSHELL_ENV := "SPORESPORE_TURNING_ROUTE_POWERSHELL"
const ROUTE_SUPERVISED_TERMINATION_ENV := (
	"SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION"
)

const ROUTE_LEDGER_SCOPE := {
	"subsystem": "turning",
	"engine_scope": "3e",
	"authority_mode": "development_ghost",
	"question_class": "development",
}
const ROUTE_FALSE_CLAIMS := {
	"turning_established": false,
	"portable_basic_turning": false,
	"cross_engine_equivalence": false,
	"arbitrary_quadruped_coverage": false,
	"q_sdk_r23_satisfied": false,
	"release_authorized": false,
	"physical_acceptance_authority": false,
}


func _run() -> void:
	var parsed := _route_parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("SPORESPORE_TURNING_ROUTE_GODOT_FAILURE ", JsonTransportScript.stringify(parsed))
		_route_finish(1, "failure")
		return
	var cell := _route_cell()
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _route_run_preflight(cell)
		var preflight_ok := bool(preflight.get("ok", false))
		print(
			(
				"SPORESPORE_TURNING_ROUTE_GODOT_PREFLIGHT "
				if preflight_ok
				else "SPORESPORE_TURNING_ROUTE_GODOT_FAILURE "
			),
			JsonTransportScript.stringify(preflight),
		)
		_route_finish(
			0 if preflight_ok else 1,
			"preflight" if preflight_ok else "failure",
		)
		return
	if bool(parsed["authorization_preflight_only"]):
		var authorization := _route_physical_authorization(
			cell,
			String(parsed["source_commit"]),
		)
		var authorization_ok := bool(authorization.get("ok", false))
		print(
			(
				"SPORESPORE_TURNING_ROUTE_GODOT_AUTHORIZATION_PREFLIGHT "
				if authorization_ok
				else "SPORESPORE_TURNING_ROUTE_GODOT_FAILURE "
			),
			JsonTransportScript.stringify(authorization),
		)
		_route_finish(
			0 if authorization_ok else 1,
			"authorization_preflight" if authorization_ok else "failure",
		)
		return
	var terminal: Dictionary = await _r23d48_run_physical(
		cell,
		String(parsed["source_commit"]),
	)
	terminal = _route_terminal(terminal, cell, String(parsed["source_commit"]))
	var success := String(terminal.get("schema_version", "")) == ROUTE_REPORT_SCHEMA
	print("SPORESPORE_TURNING_ROUTE_GODOT_TERMINAL ", JsonTransportScript.stringify(terminal))
	_route_finish(0 if success else 1, "terminal")


func _route_finish(exit_code: int, receipt_kind: String) -> void:
	if OS.get_environment(ROUTE_SUPERVISED_TERMINATION_ENV) == "1":
		_r23d65_schedule_quit(exit_code, receipt_kind)
		return
	quit(exit_code)


func _campaign_controller_step_count(_cell_value: Dictionary) -> int:
	return ROUTE_CONTROLLER_STEPS


func _campaign_execution_predicates(
	summary: Variant,
	controller_step_count: int,
) -> Dictionary:
	return _route_project_godot_predicates(summary, controller_step_count)


func _campaign_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	return _route_physical_authorization(cell, source_commit)


func _campaign_run_preflight(cell: Dictionary) -> Dictionary:
	return await _route_run_preflight(cell)


func _campaign_prepare(cell: Dictionary) -> Dictionary:
	var contract := BaseWorkerScript._read_json(ROUTE_CONTRACT_PATH)
	var ghost: Dictionary = contract.get("development_ghost", {})
	var semantics: Dictionary = contract.get("canonical_semantics", {})
	var thresholds: Dictionary = contract.get("route_integrity_thresholds", {})
	var transport: Dictionary = contract.get("trace_transport_contract", {})
	if (
		String(contract.get("schema_version", ""))
		!= "sporespore_three_engine_turning_success_transport_route_v2"
		or String(contract.get("route_id", "")) != ROUTE_ID
		or String(contract.get("status", "")) != "prospective_zero_world_only"
		or contract.get("ledger_scope", {}) != ROUTE_LEDGER_SCOPE
		or int(ghost.get("development_seed", -1)) != ROUTE_SEED
		or String(ghost.get("arm_id", "")) != ROUTE_ARM_ID
		or float(ghost.get("turn_heading_offset_rad", NAN)) != ROUTE_HEADING_OFFSET_RAD
		or int(ghost.get("controller_step_count", -1)) != ROUTE_CONTROLLER_STEPS
		or String(ghost.get("fixed_horizon_policy_id", "")) != ROUTE_HORIZON_POLICY_ID
		or String(ghost.get("fixed_horizon_policy_sha256", ""))
		!= ROUTE_HORIZON_POLICY_SHA256
		or String(ghost.get("trace_policy_id", "")) != ROUTE_TRACE_POLICY_ID
		or String(ghost.get("trace_row_schema", "")) != ROUTE_TRACE_ROW_SCHEMA
		or not (ghost.get("ordered_engine_ids", []) as Array).has(ROUTE_ENGINE_ID)
		or String(semantics.get("controller_policy_id", "")) != ROUTE_POLICY_ID
		or String(semantics.get("controller_memory_schema", "")) != ROUTE_MEMORY_SCHEMA
		or String(semantics.get("actuator_cap_profile_id", "")) != ROUTE_PROFILE_ID
		or String(semantics.get("actuator_cap_profile_sha256", ""))
		!= ROUTE_PROFILE_SHA256
		or int(thresholds.get("exact_required_artifact_transport_field_count", -1)) != 4
		or int(thresholds.get("exact_terminal_question_class_count", -1)) != 3
		or String(transport.get("trace_transport_id", ""))
		!= "sporespore_three_engine_turning_success_transport_v2"
		or String(transport.get("artifact_schema_version", ""))
		!= "sporespore_content_addressed_artifact_receipt_v1"
		or not bool(transport.get("canonical_ndjson", false))
		or not bool(transport.get("full_precision", false))
		or String(transport.get("terminal_question_class", "")) != "development"
	):
		return _route_failure("TURNING_ROUTE_GODOT_CONTRACT_INVALID")

	# Compile the accepted descriptor/controller fixture, then replace only the
	# route-selected deterministic seed, schedule, horizon, and trace identity.
	var base_cell := cell.duplicate(true)
	base_cell["onset_id"] = "onset_600"
	base_cell["turn_start_semantic_step"] = 600
	var prepared := BaseWorkerScript._prepare(base_cell)
	if not bool(prepared.get("ok", false)):
		return _route_failure(
			"TURNING_ROUTE_GODOT_BASE_PREPARE_FAILED",
			{"base": prepared},
		)
	var perturbation_result := TurningRouteWaveGaitScript.compile_seeded_initial_perturbation(
		ROUTE_SEED
	)
	if not bool(perturbation_result.get("ok", false)):
		return _route_failure(
			"TURNING_ROUTE_GODOT_PERTURBATION_FAILED",
			{"result": perturbation_result},
		)
	var schedule := {
		"schema_version": "sporespore_heading_offset_schedule_v1",
		"schedule_id": "sporespore_turning_route_positive_two_step_schedule_v1",
		"domain": "controller_semantic_step",
		"reference_heading_source": "state.task_frame.reference_yaw_rad",
		"segments": [
			{
				"segment_id": "commanded_turn",
				"start_step_inclusive": 0,
				"end_step_exclusive": ROUTE_CONTROLLER_STEPS,
				"heading_offset_rad": ROUTE_HEADING_OFFSET_RAD,
				"command_role": "turn_heading",
			}
		],
		"after_last_segment": "hold_reference_heading",
	}
	var schedule_result := TurningRouteWaveGaitScript.compile_sdk_heading_schedule_options(
		schedule
	)
	if not bool(schedule_result.get("ok", false)):
		return _route_failure(
			"TURNING_ROUTE_GODOT_SCHEDULE_FAILED",
			{"result": schedule_result},
		)
	var fixed_horizon := {
		"candidate_specific_horizon_extension_count": 0,
		"exact_candidate_authority_observation_count": ROUTE_CONTROLLER_STEPS,
		"first_candidate_authority_observation_index": 0,
		"last_candidate_authority_observation_index": ROUTE_CONTROLLER_STEPS - 1,
		"policy_id": ROUTE_HORIZON_POLICY_ID,
		"policy_sha256": ROUTE_HORIZON_POLICY_SHA256,
	}
	var horizon_result := TurningRouteWaveGaitScript.compile_candidate_authority_horizon_options(
		fixed_horizon
	)
	if not bool(horizon_result.get("ok", false)):
		return _route_failure(
			"TURNING_ROUTE_GODOT_HORIZON_FAILED",
			{"result": horizon_result},
		)
	var trace_options := {
		"cell_id": ROUTE_CELL_ID,
		"exact_controller_step_count": ROUTE_CONTROLLER_STEPS,
		"policy_id": ROUTE_TRACE_POLICY_ID,
		"recovery_duration_steps": 0,
		"turn_duration_steps": ROUTE_CONTROLLER_STEPS,
		"turn_heading_offset_rad": ROUTE_HEADING_OFFSET_RAD,
		"turn_start_semantic_step": 0,
		"trace_row_schema_version": ROUTE_TRACE_ROW_SCHEMA,
	}
	var trace_result := TurningRouteWaveGaitScript.compile_sdk_physical_trace_options(
		trace_options
	)
	if not bool(trace_result.get("ok", false)):
		return _route_failure(
			"TURNING_ROUTE_GODOT_TRACE_CONFIGURATION_FAILED",
			{"result": trace_result},
		)
	var authority: Dictionary = (
		(prepared.get("authority_options", {}) as Dictionary).duplicate(true)
	)
	authority["controller_policy_id"] = ROUTE_POLICY_ID
	authority["task_frame_origin_policy_id"] = ROUTE_TASK_ORIGIN_POLICY_ID
	authority["live_fixture_actuator_cap_binding_policy_id"] = (
		ROUTE_LIVE_FIXTURE_BINDING_POLICY_ID
	)
	authority["live_fixture_actuator_cap_binding_profile_id"] = ROUTE_PROFILE_ID
	authority["descriptor"] = (prepared["descriptor"] as Dictionary).duplicate(true)
	prepared["authority_options"] = authority
	prepared["initial_perturbation"] = (
		(perturbation_result["initial_perturbation"] as Dictionary).duplicate(true)
	)
	prepared["schedule"] = schedule
	prepared["schedule_sha256"] = String(schedule_result["sdk_heading_schedule_sha256"])
	prepared["fixed_horizon_options"] = fixed_horizon
	prepared["trace_options"] = trace_options
	prepared["trace_configuration_sha256"] = String(
		trace_result["sdk_physical_trace_configuration_sha256"]
	)
	prepared["profile_id"] = ROUTE_PROFILE_ID
	prepared["profile_sha256"] = ROUTE_PROFILE_SHA256
	prepared["host_mapping_id"] = ROUTE_HOST_MAPPING_ID
	prepared["campaign_seed"] = ROUTE_SEED
	return prepared


func _campaign_trace_diagnostic(
	cell: Dictionary,
	trace_container: Dictionary,
) -> Dictionary:
	var rows_value: Variant = trace_container.get("rows", null)
	var failures_value: Variant = trace_container.get("failure_codes", null)
	var rows: Array = []
	if typeof(rows_value) == TYPE_ARRAY:
		rows = (rows_value as Array).duplicate(true)
	var failure_codes: Array = []
	if typeof(failures_value) == TYPE_ARRAY:
		failure_codes = (failures_value as Array).duplicate(true)
	else:
		failure_codes.append("TURNING_ROUTE_TRACE_FAILURE_CODES_TYPE_INVALID")
	var contiguous := 0
	for index in range(rows.size()):
		if (
			typeof(rows[index]) != TYPE_DICTIONARY
			or int((rows[index] as Dictionary).get("semantic_step", -1)) != index
		):
			break
		contiguous += 1
	var complete := (
		typeof(rows_value) == TYPE_ARRAY
		and typeof(failures_value) == TYPE_ARRAY
		and failure_codes.is_empty()
		and int(trace_container.get("row_count", -1)) == ROUTE_CONTROLLER_STEPS
		and rows.size() == ROUTE_CONTROLLER_STEPS
		and contiguous == ROUTE_CONTROLLER_STEPS
	)
	return {
		"schema_version": "sporespore_three_engine_turning_route_trace_diagnostic_v1",
		"route_id": ROUTE_ID,
		"ledger_scope": ROUTE_LEDGER_SCOPE.duplicate(true),
		"question_class": "development",
		"engine_id": ROUTE_ENGINE_ID,
		"cell_id": String(cell["cell_id"]),
		"campaign_seed": ROUTE_SEED,
		"declared_row_count": ROUTE_CONTROLLER_STEPS,
		"reported_row_count": int(trace_container.get("row_count", -1)),
		"actual_row_count": rows.size(),
		"contiguous_row_count": contiguous,
		"first_missing_semantic_step": contiguous,
		"failure_codes": failure_codes,
		"complete": complete,
		"rows": rows,
		"retained_before_terminal_entry": true,
		"physical_acceptance_authority": false,
	}


func _campaign_trace_diagnostic_summary(diagnostic: Dictionary) -> Dictionary:
	return R48WorkerScript._r23d48_trace_diagnostic_summary(diagnostic)


func _campaign_retain_trace_diagnostic(
	cell: Dictionary,
	diagnostic: Dictionary,
	attempt_root: String,
) -> Dictionary:
	return R48WorkerScript._r23d48_retain_trace_diagnostic(
		cell,
		diagnostic,
		attempt_root,
		ROUTE_POWERSHELL_ENV,
	)


func _campaign_retain_trace(
	_cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var projected: Array = []
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			return _route_failure("TURNING_ROUTE_GODOT_TRACE_ROW_TYPE_INVALID")
		var row: Dictionary = (row_value as Dictionary).duplicate(true)
		row["schema_version"] = ROUTE_TRACE_ROW_SCHEMA
		row["route_id"] = ROUTE_ID
		row["engine_id"] = ROUTE_ENGINE_ID
		row["cell_id"] = ROUTE_CELL_ID
		row["campaign_seed"] = ROUTE_SEED
		row["native_step_completed"] = (
			int(row.get("native_actuation_application_count", -1)) == 8
		)
		projected.append(row)
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _route_failure("TURNING_ROUTE_GODOT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join("%s.rows.json" % ROUTE_CELL_ID)
	if FileAccess.file_exists(rows_path):
		return _route_failure("TURNING_ROUTE_GODOT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _route_failure("TURNING_ROUTE_GODOT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(JsonTransportScript.stringify(projected))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(ROUTE_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(ROUTE_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(ROUTE_EVALUATOR_PATH),
				"retain-trace",
				"--engine-id",
				ROUTE_ENGINE_ID,
				"--cell-id",
				ROUTE_CELL_ID,
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
	var marker := "SPORESPORE_TURNING_ROUTE_TRACE_RETAINED "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _route_failure(
			"TURNING_ROUTE_GODOT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"child_output": output.duplicate(true), "marker_count": matches.size()},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _route_failure("TURNING_ROUTE_GODOT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != ROUTE_RETENTION_SCHEMA
		or String(receipt.get("route_id", "")) != ROUTE_ID
		or String(receipt.get("engine_id", "")) != ROUTE_ENGINE_ID
		or String(receipt.get("cell_id", "")) != ROUTE_CELL_ID
		or int(receipt.get("row_count", -1)) != ROUTE_CONTROLLER_STEPS
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _route_failure(
			"TURNING_ROUTE_GODOT_TRACE_RETENTION_RECEIPT_INVALID",
			{"receipt": receipt},
		)
	receipt["ok"] = true
	receipt["failure_code"] = ""
	return receipt


func _route_run_preflight(cell: Dictionary) -> Dictionary:
	var solver := BaseWorkerScript._apply_solver_configuration()
	if not bool(solver.get("ok", false)):
		return _route_failure("TURNING_ROUTE_GODOT_SOLVER_PREFLIGHT_FAILED", {"solver": solver})
	var prepared := _campaign_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
	var entrypoint: Dictionary = await _run_wave(prepared, true)
	var trace_options: Dictionary = entrypoint.get("sdk_physical_trace_options", {})
	var schedule: Dictionary = entrypoint.get("sdk_heading_schedule_options", {})
	var segments: Array = schedule.get("segments", [])
	var invalid_horizon: Dictionary = (
		(prepared["fixed_horizon_options"] as Dictionary).duplicate(true)
	)
	invalid_horizon["policy_sha256"] = "sha256:" + "0".repeat(64)
	var rejected_horizon := TurningRouteWaveGaitScript.compile_candidate_authority_horizon_options(
		invalid_horizon
	)
	var invalid_trace: Dictionary = (prepared["trace_options"] as Dictionary).duplicate(true)
	invalid_trace["exact_controller_step_count"] = ROUTE_CONTROLLER_STEPS + 1
	var rejected_trace := TurningRouteWaveGaitScript.compile_sdk_physical_trace_options(
		invalid_trace
	)
	var execution_probe := _route_project_godot_predicates(
		{
			"failure_code": "",
			"failure_codes": [],
			"started": true,
			"balanced_wave_shadow_valid": true,
			"step_count": ROUTE_CONTROLLER_STEPS,
			"safe_no_actuation_count": 0,
			"mismatch_count": 0,
			"validated_balanced_wave_command_count": (
				ROUTE_CONTROLLER_STEPS * 8
			),
			"native_actuation_application_count": ROUTE_CONTROLLER_STEPS * 8,
			"controller_policy_id": ROUTE_POLICY_ID,
			"r23d65_public_profile_binding_integrity_passed": true,
			"balanced_wave_command_validation_summary": {
				"ok": true,
				"native_validation_step_count": ROUTE_CONTROLLER_STEPS,
				"heading_command_conditioned_step_count": ROUTE_CONTROLLER_STEPS,
				"unconditioned_step_count": 0,
			},
		},
		ROUTE_CONTROLLER_STEPS,
	)
	var integral_artifact_projection := _route_canonical_trace_artifact(
		{"byte_length": 5414.0}
	)
	var fractional_artifact_projection := _route_canonical_trace_artifact(
		{"byte_length": 5414.5}
	)
	var exact: bool = (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and int(entrypoint.get("candidate_authority_observation_count", -1))
		== ROUTE_CONTROLLER_STEPS
		and int(trace_options.get("exact_controller_step_count", -1))
		== ROUTE_CONTROLLER_STEPS
		and String(trace_options.get("policy_id", "")) == ROUTE_TRACE_POLICY_ID
		and String(trace_options.get("trace_row_schema_version", ""))
		== ROUTE_TRACE_ROW_SCHEMA
		and String(trace_options.get("cell_id", "")) == ROUTE_CELL_ID
		and segments.size() == 1
		and String((segments[0] as Dictionary).get("command_role", "")) == "turn_heading"
		and float((segments[0] as Dictionary).get("heading_offset_rad", NAN))
		== ROUTE_HEADING_OFFSET_RAD
		and not bool(rejected_horizon.get("ok", true))
		and not bool(rejected_trace.get("ok", true))
		and bool(execution_probe.get("ok", false))
		and bool(integral_artifact_projection.get("ok", false))
		and typeof(
			(integral_artifact_projection.get("artifact", {}) as Dictionary).get(
				"byte_length",
				null,
			)
		) == TYPE_INT
		and int(
			(integral_artifact_projection.get("artifact", {}) as Dictionary).get(
				"byte_length",
				-1,
			)
		) == 5414
		and not bool(fractional_artifact_projection.get("ok", true))
		and String(Engine.get_version_info().get("string", ""))
		== ROUTE_GODOT_RUNTIME_VERSION
	)
	if not exact:
		return _route_failure(
			"TURNING_ROUTE_GODOT_PREFLIGHT_INVALID",
			{
				"entrypoint": entrypoint,
				"rejected_horizon": rejected_horizon,
				"rejected_trace": rejected_trace,
				"execution_probe": execution_probe,
				"runtime": Engine.get_version_info().get("string", ""),
			},
		)
	return {
		"schema_version": ROUTE_PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"route_id": ROUTE_ID,
		"ledger_scope": ROUTE_LEDGER_SCOPE.duplicate(true),
		"engine_id": ROUTE_ENGINE_ID,
		"cell_id": ROUTE_CELL_ID,
		"campaign_seed": ROUTE_SEED,
		"controller_step_count": ROUTE_CONTROLLER_STEPS,
		"nonzero_turn_command_compiled": true,
		"public_profile_route_compiled": true,
		"two_step_execution_projection_checked": true,
		"integral_json_artifact_length_projection_checked": true,
		"negative_control_count": 3,
		"negative_controls_rejected": 3,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
		"physical_behavior_thresholds_applied": false,
		"physical_acceptance_authority": false,
	}


static func _route_project_godot_predicates(
	summary: Variant,
	controller_step_count: int,
) -> Dictionary:
	var source: Dictionary = summary if typeof(summary) == TYPE_DICTIONARY else {}
	var validation_value: Variant = source.get(
		"balanced_wave_command_validation_summary",
		null,
	)
	var validation: Dictionary = (
		validation_value if typeof(validation_value) == TYPE_DICTIONARY else {}
	)
	var failure_codes_value: Variant = source.get("failure_codes", null)
	var declarations := [
		[
			"sdk_failure_code_empty",
			"sdk_authority_summary.failure_code",
			source.has("failure_code"),
			source.get("failure_code", null),
			"",
		],
		[
			"sdk_failure_codes_empty",
			"sdk_authority_summary.failure_codes",
			source.has("failure_codes"),
			failure_codes_value,
			[],
		],
		[
			"sdk_started",
			"sdk_authority_summary.started",
			source.has("started"),
			source.get("started", null),
			true,
		],
		[
			"sdk_balanced_wave_shadow_valid",
			"sdk_authority_summary.balanced_wave_shadow_valid",
			source.has("balanced_wave_shadow_valid"),
			source.get("balanced_wave_shadow_valid", null),
			true,
		],
		[
			"sdk_step_count",
			"sdk_authority_summary.step_count",
			source.has("step_count"),
			source.get("step_count", null),
			controller_step_count,
		],
		[
			"sdk_safe_no_actuation_count",
			"sdk_authority_summary.safe_no_actuation_count",
			source.has("safe_no_actuation_count"),
			source.get("safe_no_actuation_count", null),
			0,
		],
		[
			"sdk_mismatch_count",
			"sdk_authority_summary.mismatch_count",
			source.has("mismatch_count"),
			source.get("mismatch_count", null),
			0,
		],
		[
			"sdk_validated_command_count",
			"sdk_authority_summary.validated_balanced_wave_command_count",
			source.has("validated_balanced_wave_command_count"),
			source.get("validated_balanced_wave_command_count", null),
			controller_step_count * 8,
		],
		[
			"sdk_native_application_count",
			"sdk_authority_summary.native_actuation_application_count",
			source.has("native_actuation_application_count"),
			source.get("native_actuation_application_count", null),
			controller_step_count * 8,
		],
		[
			"sdk_controller_policy",
			"sdk_authority_summary.controller_policy_id",
			source.has("controller_policy_id"),
			source.get("controller_policy_id", null),
			ROUTE_POLICY_ID,
		],
		[
			"sdk_public_profile_binding",
			"sdk_authority_summary.r23d65_public_profile_binding_integrity_passed",
			source.has("r23d65_public_profile_binding_integrity_passed"),
			source.get("r23d65_public_profile_binding_integrity_passed", null),
			true,
		],
		[
			"sdk_command_validation_ok",
			"sdk_authority_summary.balanced_wave_command_validation_summary.ok",
			validation.has("ok"),
			validation.get("ok", null),
			true,
		],
		[
			"sdk_native_validation_step_count",
			(
				"sdk_authority_summary.balanced_wave_command_validation_summary."
				+ "native_validation_step_count"
			),
			validation.has("native_validation_step_count"),
			validation.get("native_validation_step_count", null),
			controller_step_count,
		],
		[
			"sdk_heading_conditioned_step_count",
			(
				"sdk_authority_summary.balanced_wave_command_validation_summary."
				+ "heading_command_conditioned_step_count"
			),
			validation.has("heading_command_conditioned_step_count"),
			validation.get("heading_command_conditioned_step_count", null),
			controller_step_count,
		],
		[
			"sdk_unconditioned_step_count",
			(
				"sdk_authority_summary.balanced_wave_command_validation_summary."
				+ "unconditioned_step_count"
			),
			validation.has("unconditioned_step_count"),
			validation.get("unconditioned_step_count", null),
			0,
		],
	]
	var rows: Array[Dictionary] = []
	var failed: Array[String] = []
	for declaration_value in declarations:
		var declaration: Array = declaration_value
		var observed: Variant = declaration[3]
		var expected: Variant = declaration[4]
		var passed := (
			bool(declaration[2])
			and R23D3WorkerScript._strict_equal(observed, expected)
		)
		var predicate_id := String(declaration[0])
		rows.append(
			{
				"predicate_id": predicate_id,
				"source_path": String(declaration[1]),
				"field_present": bool(declaration[2]),
				"observed_value": observed,
				"observed_value_type": type_string(typeof(observed)),
				"expected_value": expected,
				"passed": passed,
			}
		)
		if not passed:
			failed.append(predicate_id)
	return {
		"schema_version": (
			"sporespore_three_engine_turning_route_godot_execution_"
			+ "predicate_summary_v1"
		),
		"ok": failed.is_empty(),
		"ordered_predicates": rows,
		"failed_predicate_ids": failed,
		"aggregate_sdk_summary_ok_observed": bool(source.get("ok", false)),
		"aggregate_sdk_summary_not_route_execution_authority": true,
		"route_execution_only_scope": true,
		"physical_acceptance_authority": false,
	}


func _route_physical_authorization(cell: Dictionary, source_commit: String) -> Dictionary:
	var freeze_path := OS.get_environment(ROUTE_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(ROUTE_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(ROUTE_TOKEN_ENV)
	var attempt_root := OS.get_environment(ROUTE_ATTEMPT_ROOT_ENV)
	var authority_repo_root := OS.get_environment(ROUTE_AUTHORITY_REPO_ROOT_ENV)
	if (
		freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or authority_repo_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not BaseWorkerScript._valid_lower_hex(token, 32)
		or not BaseWorkerScript._valid_lower_hex(source_commit, 40)
	):
		return _route_failure("TURNING_ROUTE_GODOT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := BaseWorkerScript._read_json(freeze_path)
	var attempt := BaseWorkerScript._read_json(attempt_path)
	var contract_sha := BaseWorkerScript._raw_file_sha256(ROUTE_CONTRACT_PATH)
	var normalized_repo := authority_repo_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var expected_repo := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/")
	var normalized_attempt := attempt_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var production_root := ProjectSettings.globalize_path("res://../SporeSpore_Evidence").simplify_path().replace("\\", "/").trim_suffix("/")
	var expected_cells := [
		"turning_success_transport_v2__godot_jolt__s21516__positive_heading",
		"turning_success_transport_v2__rapier_parry__s21516__positive_heading",
		"turning_success_transport_v2__mujoco__s21516__positive_heading",
	]
	var exact: bool = (
		normalized_repo == expected_repo
		and (normalized_attempt == production_root or normalized_attempt.begins_with(production_root + "/"))
		and String(freeze.get("schema_version", "")) == ROUTE_FREEZE_SCHEMA
		and String(freeze.get("route_id", "")) == ROUTE_ID
		and String(freeze.get("authority_mode", "")) == "development_ghost"
		and String(freeze.get("source_commit", "")) == source_commit
		and String(freeze.get("origin_main_commit", "")) == source_commit
		and String(freeze.get("live_github_main_commit", "")) == source_commit
		and String(freeze.get("contract_raw_sha256", "")) == contract_sha
		and bool(freeze.get("source_worktree_clean", false))
		and bool(freeze.get("complete_zero_world_gate_passed", false))
		and int(freeze.get("declared_world_count", -1)) == 3
		and freeze.get("ordered_cell_ids", []) == expected_cells
		and bool(freeze.get("serial_execution_required", false))
		and bool(freeze.get("physical_execution_authorized", false))
		and not bool(freeze.get("physical_behavior_thresholds_applied", true))
		and String(attempt.get("schema_version", "")) == ROUTE_ATTEMPT_SCHEMA
		and String(attempt.get("route_id", "")) == ROUTE_ID
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("freeze_raw_sha256", ""))
		== BaseWorkerScript._raw_file_sha256(freeze_path)
		and String(attempt.get("authorization_token", "")) == token
		and BaseWorkerScript._valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and String(attempt.get("attempt_root", "")).simplify_path().replace("\\", "/").trim_suffix("/")
		== normalized_attempt
		and attempt.get("ordered_cell_ids", []) == expected_cells
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and bool(attempt.get("physical_execution_authorized", false))
		and OS.get_environment(ROUTE_ENGINE_ENV) == ROUTE_ENGINE_ID
		and OS.get_environment(ROUTE_CELL_ENV) == ROUTE_CELL_ID
		and String(cell.get("cell_id", "")) == ROUTE_CELL_ID
	)
	if not exact:
		return _route_failure("TURNING_ROUTE_GODOT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"schema_version": (
			"sporespore_three_engine_turning_success_transport_godot_authorization_v2"
		),
		"ok": true,
		"failure_code": "",
		"route_id": ROUTE_ID,
		"ledger_scope": ROUTE_LEDGER_SCOPE.duplicate(true),
		"engine_id": ROUTE_ENGINE_ID,
		"cell_id": ROUTE_CELL_ID,
		"attempt_root": normalized_attempt,
		"authorization_passed": true,
		"returned_before_model": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _route_terminal(
	value: Dictionary,
	_cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	var success := (
		String(value.get("schema_version", ""))
		== "sporespore_qsdk_r23d48_engine_cell_report_v1"
	)
	var result := value.duplicate(true)
	result["schema_version"] = ROUTE_REPORT_SCHEMA if success else ROUTE_FAILURE_SCHEMA
	result["campaign_id"] = ROUTE_ID
	result["gate_id"] = ROUTE_ID
	result["route_id"] = ROUTE_ID
	result["ledger_scope"] = ROUTE_LEDGER_SCOPE.duplicate(true)
	result["question_class"] = "development"
	result["stage_id"] = "turning_3e_success_transport_development_ghost"
	result["engine_id"] = ROUTE_ENGINE_ID
	result["cell_id"] = ROUTE_CELL_ID
	result["campaign_seed"] = ROUTE_SEED
	result["profile_id"] = ROUTE_PROFILE_ID
	result["profile_sha256"] = ROUTE_PROFILE_SHA256
	result["host_mapping_id"] = ROUTE_HOST_MAPPING_ID
	result["arm_id"] = ROUTE_ARM_ID
	result["turn_heading_offset_rad"] = ROUTE_HEADING_OFFSET_RAD
	result["source_commit"] = source_commit
	result["physical_behavior_thresholds_applied"] = false
	result["claims"] = ROUTE_FALSE_CLAIMS.duplicate(true)
	result["physical_acceptance_authority"] = false
	if success:
		var artifact_projection := _route_canonical_trace_artifact(
			result.get("trace_artifact", null)
		)
		if not bool(artifact_projection.get("ok", false)):
			success = false
			result["schema_version"] = ROUTE_FAILURE_SCHEMA
			result["failure_code"] = (
				"TURNING_ROUTE_GODOT_TRACE_ARTIFACT_BYTE_LENGTH_INVALID"
			)
		else:
			result["trace_artifact"] = (
				(artifact_projection["artifact"] as Dictionary).duplicate(true)
			)
	if success:
		var summary: Dictionary = result.get("trace_summary", {})
		result["trace_retention"] = {
			"schema_version": ROUTE_RETENTION_SCHEMA,
			"route_id": ROUTE_ID,
			"ledger_scope": ROUTE_LEDGER_SCOPE.duplicate(true),
			"question_class": "development",
			"engine_id": ROUTE_ENGINE_ID,
			"cell_id": ROUTE_CELL_ID,
			"campaign_seed": ROUTE_SEED,
			"row_count": int(summary.get("row_count", -1)),
			"first_semantic_step": int(summary.get("first_semantic_step", -1)),
			"last_semantic_step": int(summary.get("last_semantic_step", -1)),
			"nonzero_turn_command_step_count": int(
				summary.get("nonzero_turn_command_step_count", -1)
			),
			"canonical_ndjson": true,
			"retained_before_terminal_entry": true,
			"trace_artifact": (result.get("trace_artifact", {}) as Dictionary).duplicate(true),
			"physical_behavior_thresholds_applied": false,
			"physical_acceptance_authority": false,
		}
		var execution: Dictionary = (result.get("execution", {}) as Dictionary).duplicate(true)
		execution["nonzero_turn_command_step_count"] = int(
			summary.get("nonzero_turn_command_step_count", -1)
		)
		result["execution"] = execution
		result["actuator_cap_profile_resolution_receipt"] = (
			_r23d65_last_resolution_receipt.duplicate(true)
		)
		result["actuator_cap_profile_host_mapping_receipt"] = (
			_r23d65_last_host_mapping_receipt.duplicate(true)
		)
		result["actuator_cap_profile_physical_binding_receipt"] = (
			_r23d65_last_physical_binding_receipt.duplicate(true)
		)
		result.erase("model_construction_count")
		result.erase("world_attempt_count")
		result.erase("world_build_count")
	else:
		var world_attempts := int(result.get("world_attempt_count", 0))
		var world_builds := int(result.get("world_build_count", 0))
		result["model_construction_count"] = world_builds
		result["world_attempt_count"] = world_attempts
		result["world_build_count"] = world_builds
	return result


static func _route_canonical_trace_artifact(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "failure_code": "TRACE_ARTIFACT_TYPE_INVALID"}
	var artifact: Dictionary = (value as Dictionary).duplicate(true)
	var byte_length_value: Variant = artifact.get("byte_length", null)
	if typeof(byte_length_value) != TYPE_INT and typeof(byte_length_value) != TYPE_FLOAT:
		return {"ok": false, "failure_code": "TRACE_ARTIFACT_BYTE_LENGTH_TYPE_INVALID"}
	var byte_length_float := float(byte_length_value)
	var byte_length_int := int(byte_length_value)
	if (
		is_nan(byte_length_float)
		or is_inf(byte_length_float)
		or byte_length_int < 0
		or byte_length_float != float(byte_length_int)
	):
		return {"ok": false, "failure_code": "TRACE_ARTIFACT_BYTE_LENGTH_VALUE_INVALID"}
	artifact["byte_length"] = byte_length_int
	return {"ok": true, "failure_code": "", "artifact": artifact}


static func _route_cell() -> Dictionary:
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": "three_engine_turning_success_transport_route_v2",
		"cell_id": ROUTE_CELL_ID,
		"engine_id": ROUTE_ENGINE_ID,
		"campaign_seed": ROUTE_SEED,
		"profile_id": ROUTE_PROFILE_ID,
		"host_mapping_id": ROUTE_HOST_MAPPING_ID,
		"onset_id": "route_turn_start_0",
		"turn_start_semantic_step": 0,
		"arm_id": ROUTE_ARM_ID,
		"turn_heading_offset_rad": ROUTE_HEADING_OFFSET_RAD,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _route_parse_arguments(args: PackedStringArray) -> Dictionary:
	var preflight_only := false
	var authorization_preflight_only := false
	var source_commit := ""
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
		if argument == "--source-commit" and source_commit.is_empty() and index + 1 < args.size():
			source_commit = String(args[index + 1])
			index += 2
			continue
		return _route_failure("TURNING_ROUTE_GODOT_ARGUMENT_INVALID:%s" % argument)
	if (
		(preflight_only and authorization_preflight_only)
		or (not preflight_only and not BaseWorkerScript._valid_lower_hex(source_commit, 40))
		or (preflight_only and not source_commit.is_empty())
	):
		return _route_failure("TURNING_ROUTE_GODOT_ARGUMENTS_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"preflight_only": preflight_only,
		"authorization_preflight_only": authorization_preflight_only,
		"source_commit": source_commit,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _route_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
