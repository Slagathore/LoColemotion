extends "res://tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"

## QSDK-R24D10 exact-step dual-mode worker.
##
## The inherited worker supplies only stable engine/refusal/serialization and
## shutdown helpers. R24D10 owns a new physical state machine: construct and
## activate while the server is disabled, capture every initial pre-rate, arm
## at one physics_frame boundary, then read token N and leave the server active
## for token N+1. At the boundary after token 20 it disables the server before
## step 21 can begin. No pre-sample active physics frame exists.

const R24D10Rig := preload(
	"res://scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd"
)

const R24D10_RAW_SCHEMA := (
	"sporespore_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_raw_report_v1"
)
const R24D10_ZERO_WORLD_TEMPLATE_PATH := "res://zero_world_template.json"
const R24D10_SUPERVISED_TERMINATION_ENV := (
	"SPORESPORE_R24D10_SUPERVISED_TERMINATION"
)
const R24D10_TERMINATION_NONCE_ENV := "SPORESPORE_R24D10_TERMINATION_NONCE"
const R24D10_EXECUTION_NONCE_ENV := "SPORESPORE_R24D10_EXECUTION_NONCE"
const R24D10_SOURCE_COMMIT_ENV := "SPORESPORE_R24D10_SOURCE_COMMIT"
const R24D10_AUTHORIZATION := {
	"closure_id": "QSDK-R24D9-PH1-CLOSURE",
	"closure_path": (
		"sdk/recovery/" +
		"r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
		"physical_failure_closure_v1.json"
	),
	"closure_raw_sha256": (
		"sha256:ef054432bf3aa15673a49c9765a3221ffd337c2becb9ba96f1951c81f87b4fde"
	),
	"closure_publication_commit": "fa4001578e244deff25cce4dd32d7a0c9e5d3418",
	"authorization_kind": "distinct_corrective_development_declaration_only",
	"r24d9_result_reused_or_reinterpreted": false,
}
const R24D10_RUNTIME_PROVENANCE := {
	"runtime_profile_id": (
		"godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2"
	),
	"godot_source_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
	"combined_patch_raw_sha256": (
		"sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
	),
	"toolchain_provenance_console_binary_raw_sha256": (
		"sha256:8a629f16859f653d447cd7f07f712f0045a1aed3f27be53413d97df6ff1ec0e6"
	),
	"toolchain_provenance_console_binary_byte_length": 293376,
	"toolchain_provenance_engine_binary_raw_sha256": (
		"sha256:0d77df42106c6d2f6fa51727d8051bf403e8a0273b3242daee581c93c4ba7257"
	),
	"toolchain_provenance_engine_binary_byte_length": 188829184,
	"r24d10_independent_cold_build_required": true,
}
const R24D10_PHYSICS_STEP_COUNT_SOURCE := (
	"max_retained_awake_read_space_step_sequence_minus_" +
	"zero_initialized_space_step_sequence"
)
const EXPECTED_INITIAL_RATE_PROJECTION := {
	"drive_positive": 0.0,
	"drive_negative": 0.0,
	"brake_positive": 0.4000000059604645,
	"brake_negative": -0.4000000059604645,
	"disabled_positive": 0.4000000059604645,
	"disabled_negative": -0.4000000059604645,
	"limit_positive": 0.0,
	"limit_negative": 0.0,
	"sleep_stale": 0.0,
}

var _r24d10_context := {}
var _r24d10_schedule_started := false
var _r24d10_schedule_start_boundary_count := 0
var _r24d10_sleep_input_write_count := 0
var _r24d10_terminal_deactivation_count := 0


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	var mode := String(arguments.get("mode", ""))
	var source_commit := String(arguments.get("source_commit", ""))
	var nonce := String(arguments.get("nonce", ""))
	var report_path := String(arguments.get("report_path", ""))
	if mode != "zero_world_preflight" and mode != "physical":
		_emit_failure("R24D10_MODE_INVALID", 0, 0, 0)
		return
	if (
		source_commit.length() != 40
		or nonce.length() != 32
		or report_path.is_empty()
		or OS.get_environment(R24D10_SOURCE_COMMIT_ENV) != source_commit
		or OS.get_environment(R24D10_EXECUTION_NONCE_ENV) != nonce
	):
		_emit_failure("R24D10_AUTHORIZATION_HANDSHAKE_INVALID", 0, 0, 0)
		return
	if mode == "zero_world_preflight":
		_run_zero_world_preflight(source_commit, nonce, report_path)
		return
	_run_physical(source_commit, nonce, report_path)


func _run_zero_world_preflight(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := R24D10Rig.describe()
	var invalid_rid_refused := false
	if _engine_receipt_is_frozen(engine):
		invalid_rid_refused = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
		)
	var template_text := FileAccess.get_file_as_string(
		R24D10_ZERO_WORLD_TEMPLATE_PATH
	)
	var template_value: Variant = JSON.parse_string(template_text)
	if not template_value is Dictionary:
		_emit_failure("R24D10_ZERO_WORLD_TEMPLATE_INVALID", 0, 0, 0)
		return
	var report: Dictionary = template_value as Dictionary
	var template_shape_matches := _template_shape_is_frozen(report)
	var template_identity_matches := (
		String(report.get("source_commit", "")) == source_commit
		and String(report.get("execution_nonce", "")) == nonce
	)
	var active_physics_object_count := float(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	)
	var ok := (
		_engine_receipt_is_frozen(engine)
		and _fixture_description_is_frozen(description)
		and invalid_rid_refused
		and template_shape_matches
		and template_identity_matches
		and active_physics_object_count == 0.0
		and _write_text_report(report_path, template_text)
	)
	print(
		"QSDK_R24D10_WORKER_ZERO_WORLD ",
		JSON.stringify(
			{
				"ok": ok,
				"source_commit": source_commit,
				"execution_nonce": nonce,
				"telemetry_schema": TELEMETRY_SCHEMA,
				"telemetry_field_count": 15,
				"engine_freeze_matches": _engine_receipt_is_frozen(engine),
				"fixture_description_matches": (
					_fixture_description_is_frozen(description)
				),
				"invalid_rid_refused": invalid_rid_refused,
				"template_shape_matches": template_shape_matches,
				"template_identity_matches": template_identity_matches,
				"template_byte_passthrough": true,
				"synthetic_report_written": FileAccess.file_exists(report_path),
				"synthetic_embedded_world_count": 1,
				"synthetic_embedded_physics_step_count": 20,
				"synthetic_embedded_retained_sample_count": 68,
				"synthetic_first_retained_space_step_sequence": 1,
				"synthetic_last_retained_space_step_sequence": 20,
				"synthetic_pre_sample_physics_frame_count": 0,
				"synthetic_envelope_is_physical_observation": false,
				"active_physics_object_count": active_physics_object_count,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"solver_step_count": 0,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	_schedule_quit(0 if ok else 1, "zero_world_preflight")


func _run_physical(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := R24D10Rig.describe()
	if not _engine_receipt_is_frozen(engine):
		_emit_failure("R24D10_ENGINE_OR_SOLVER_FREEZE_DRIFT", 0, 0, 0)
		return
	if not _fixture_description_is_frozen(description):
		_emit_failure("R24D10_FIXTURE_DECLARATION_DRIFT", 0, 0, 0)
		return
	var invalid_rid_refused := (
		JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
	)

	# A newly built viewport world cannot consume a step before its initial state
	# is retained. The first later physics_frame callback enables the server for
	# that same boundary's step, so it is the start of token 1, not a pre-sample.
	PhysicsServer3D.set_active(false)
	var rig := R24D10Rig.build()
	if not bool(rig.get("ok", false)):
		_emit_failure(
			"R24D10_FIXTURE_BUILD_FAILED",
			int(rig.get("world_attempt_count", 1)),
			int(rig.get("world_build_count", 0)),
			0,
		)
		return
	var viewport: SubViewport = rig["viewport"]
	var cells: Array = rig["cells"]
	root.add_child(viewport)

	var initial_velocity_write_count := 0
	var retained_by_id := {}
	var integrated_angle_by_id := {}
	var first_pre_rate_by_id := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		initial_velocity_write_count += R24D10Rig.activate(cell)
		var cell_id := String(cell["cell_id"])
		retained_by_id[cell_id] = []
		integrated_angle_by_id[cell_id] = 0.0
		first_pre_rate_by_id[cell_id] = R24D10Rig.canonical_rate_rad_s(cell)
		if float(first_pre_rate_by_id[cell_id]) != float(
			EXPECTED_INITIAL_RATE_PROJECTION[cell_id]
		):
			PhysicsServer3D.set_active(false)
			_emit_failure("R24D10_INITIAL_RATE_PROJECTION_DRIFT", 1, 1, 0)
			return

	var parameter_readbacks := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		parameter_readbacks[String(cell["cell_id"])] = (
			R24D10Rig.parameter_readback(cell)
		)

	_r24d10_context = {
		"source_commit": source_commit,
		"nonce": nonce,
		"report_path": report_path,
		"engine": engine,
		"description": description,
		"invalid_rid_refused": invalid_rid_refused,
		"rig": rig,
		"viewport": viewport,
		"cells": cells,
		"retained_by_id": retained_by_id,
		"integrated_angle_by_id": integrated_angle_by_id,
		"pre_rate_by_id": first_pre_rate_by_id,
		"parameter_readbacks": parameter_readbacks,
		"initial_velocity_write_count": initial_velocity_write_count,
	}
	_r24d10_schedule_started = false
	_r24d10_schedule_start_boundary_count = 0
	_r24d10_sleep_input_write_count = 0
	_r24d10_terminal_deactivation_count = 0
	physics_frame.connect(_on_r24d10_exact_step_physics_frame)


func _on_r24d10_exact_step_physics_frame() -> void:
	if _r24d10_context.is_empty():
		PhysicsServer3D.set_active(false)
		_emit_failure("R24D10_SCHEDULE_CONTEXT_MISSING", 1, 1, 0)
		return
	if not _r24d10_schedule_started:
		_r24d10_schedule_started = true
		_r24d10_schedule_start_boundary_count += 1
		PhysicsServer3D.set_active(true)
		return

	var cells: Array = _r24d10_context["cells"]
	var retained_by_id: Dictionary = _r24d10_context["retained_by_id"]
	var integrated_angle_by_id: Dictionary = _r24d10_context[
		"integrated_angle_by_id"
	]
	var pre_rate_by_id: Dictionary = _r24d10_context["pre_rate_by_id"]
	var token := -1
	var post_rate_by_id := {}
	var telemetry_by_id := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var joint: HingeJoint3D = cell["joint"]
		post_rate_by_id[cell_id] = R24D10Rig.canonical_rate_rad_s(cell)
		var telemetry_value: Variant = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())
		)
		if not telemetry_value is Dictionary:
			_r24d10_abort_schedule("R24D10_ACTIVE_TELEMETRY_MISSING", token)
			return
		var telemetry := (telemetry_value as Dictionary).duplicate(true)
		telemetry_by_id[cell_id] = telemetry
		if cell_id == "limit_positive":
			token = int(telemetry.get("read_space_step_sequence", -1))
	if token < 1 or token > R24D10Rig.MAXIMUM_PHYSICS_STEP_COUNT:
		_r24d10_abort_schedule("R24D10_OBSERVED_STEP_TOKEN_OUT_OF_RANGE", token)
		return

	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		if token > int(cell["retained_step_count"]):
			continue
		var child: RigidBody3D = cell["child"]
		var joint: HingeJoint3D = cell["joint"]
		var pre_rate := float(pre_rate_by_id[cell_id])
		var post_rate := float(post_rate_by_id[cell_id])
		var telemetry: Dictionary = telemetry_by_id[cell_id]
		var solver_step_s := float(telemetry.get("solver_step_s", 1.0 / 120.0))
		var integrated_angle := float(integrated_angle_by_id[cell_id])
		integrated_angle += 0.5 * (pre_rate + post_rate) * solver_step_s
		integrated_angle_by_id[cell_id] = integrated_angle
		(retained_by_id[cell_id] as Array).append(
			{
				"step_index": token,
				"pre_canonical_relative_rate_rad_s": pre_rate,
				"post_canonical_relative_rate_rad_s": post_rate,
				"inverse_inertia_axis_kg_inv_m2": (
					R24D10Rig.inverse_inertia_axis_kg_inv_m2(cell)
				),
				"integrated_canonical_angle_rad": integrated_angle,
				"host_target_velocity_readback_rad_s": joint.get_param(
					HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
				),
				"joint_limit_lower_readback_rad": joint.get_param(
					HingeJoint3D.PARAM_LIMIT_LOWER
				),
				"joint_limit_upper_readback_rad": joint.get_param(
					HingeJoint3D.PARAM_LIMIT_UPPER
				),
				"telemetry": telemetry,
				"child_sleeping": child.sleeping,
			}
		)
	if token == 1:
		for cell_value in cells:
			var cell: Dictionary = cell_value
			if String(cell["cell_id"]) == "sleep_stale":
				R24D10Rig.force_declared_sleep(cell)
				_r24d10_sleep_input_write_count += 1
				break

	if token == R24D10Rig.MAXIMUM_PHYSICS_STEP_COUNT:
		PhysicsServer3D.set_active(false)
		_r24d10_terminal_deactivation_count += 1
		if physics_frame.is_connected(_on_r24d10_exact_step_physics_frame):
			physics_frame.disconnect(_on_r24d10_exact_step_physics_frame)
		_r24d10_finalize_physical_report()
		return

	_r24d10_context["pre_rate_by_id"] = post_rate_by_id
	_r24d10_context["retained_by_id"] = retained_by_id
	_r24d10_context["integrated_angle_by_id"] = integrated_angle_by_id


func _r24d10_abort_schedule(code: String, observed_token: int) -> void:
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_on_r24d10_exact_step_physics_frame):
		physics_frame.disconnect(_on_r24d10_exact_step_physics_frame)
	var observed_steps := observed_token if observed_token > 0 else 0
	_emit_failure(code, 1, 1, observed_steps)


func _r24d10_finalize_physical_report() -> void:
	var cells: Array = _r24d10_context["cells"]
	var retained_by_id: Dictionary = _r24d10_context["retained_by_id"]
	var parameter_readbacks: Dictionary = _r24d10_context["parameter_readbacks"]
	var raw_cells: Array[Dictionary] = []
	var retained_sample_count := 0
	var observed_tokens := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var samples: Array = retained_by_id[cell_id]
		retained_sample_count += samples.size()
		for sample_value in samples:
			var sample: Dictionary = sample_value
			var telemetry: Dictionary = sample["telemetry"]
			if bool(telemetry.get("snapshot_is_current_space_step", false)):
				observed_tokens[int(telemetry["read_space_step_sequence"])] = true
		raw_cells.append(
			{
				"cell_id": cell_id,
				"family": String(cell["family"]),
				"motor_enabled": bool(cell["motor_enabled"]),
				"canonical_target_velocity_rad_s": (
					float(cell["canonical_target_velocity_rad_s"])
				),
				"initial_canonical_rate_rad_s": (
					float(cell["initial_canonical_rate_rad_s"])
				),
				"public_maximum_motor_impulse_nms": (
					float(cell["public_maximum_motor_impulse_nms"])
				),
				"joint_limits_enabled": bool(cell["joint_limits_enabled"]),
				"lower_limit_rad": float(cell["lower_limit_rad"]),
				"upper_limit_rad": float(cell["upper_limit_rad"]),
				"retained_step_count": int(cell["retained_step_count"]),
				"pre_tree_read_refused": bool(cell["pre_tree_read_refused"]),
				"parameter_readback": parameter_readbacks[cell_id],
				"samples": samples,
			}
		)

	var token_values: Array = observed_tokens.keys()
	token_values.sort()
	var first_token := int(token_values[0]) if not token_values.is_empty() else -1
	var last_token := int(token_values[-1]) if not token_values.is_empty() else -1
	var derived_step_count := last_token
	var report := _r24d10_report(
		"native_physical",
		String(_r24d10_context["source_commit"]),
		String(_r24d10_context["nonce"]),
		_r24d10_context["engine"],
		_r24d10_context["description"],
		bool(_r24d10_context["invalid_rid_refused"]),
		(_r24d10_context["rig"] as Dictionary)["pre_tree_refusals"],
		raw_cells,
		int(_r24d10_context["initial_velocity_write_count"]),
		_r24d10_sleep_input_write_count,
		retained_sample_count,
		first_token,
		last_token,
		token_values.size(),
		derived_step_count,
	)
	var report_path := String(_r24d10_context["report_path"])
	var wrote_report := _write_json_report(report_path, report)
	print(
		"QSDK_R24D10_PHYSICAL_RAW_REPORT ",
		JSON.stringify(
			{
				"ok": wrote_report,
				"source_commit": _r24d10_context["source_commit"],
				"execution_nonce": _r24d10_context["nonce"],
				"report_path": report_path,
				"world_attempt_count": 1,
				"world_build_count": 1,
				"solver_step_count": derived_step_count,
				"solver_step_count_source": R24D10_PHYSICS_STEP_COUNT_SOURCE,
				"first_retained_space_step_sequence": first_token,
				"last_retained_space_step_sequence": last_token,
				"observed_retained_awake_space_step_token_count": token_values.size(),
				"retained_sample_count": retained_sample_count,
				"pre_sample_physics_frame_count": 0,
				"terminal_physics_server_deactivation_count": (
					_r24d10_terminal_deactivation_count
				),
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	var viewport: SubViewport = _r24d10_context["viewport"]
	viewport.queue_free()
	_r24d10_context = {}
	_schedule_quit(0 if wrote_report else 1, "physical_raw_report")


func _r24d10_report(
	evidence_kind: String,
	source_commit: String,
	nonce: String,
	engine: Dictionary,
	description: Dictionary,
	invalid_rid_refused: bool,
	pre_tree_refusals: Dictionary,
	cells: Array[Dictionary],
	initial_velocity_write_count: int,
	sleep_input_write_count: int,
	retained_sample_count: int,
	first_token: int,
	last_token: int,
	observed_token_count: int,
	derived_step_count: int,
) -> Dictionary:
	return {
		"schema_version": R24D10_RAW_SCHEMA,
		"gate_id": "QSDK-R24D10",
		"question_class": "development",
		"evidence_kind": evidence_kind,
		"source_commit": source_commit,
		"execution_nonce": nonce,
		"authorization": R24D10_AUTHORIZATION.duplicate(true),
		"runtime_provenance": R24D10_RUNTIME_PROVENANCE.duplicate(true),
		"engine": engine,
		"fixture": description,
		"refusals": {
			"invalid_rid_refused": invalid_rid_refused,
			"not_in_tree_joint_read_refused_by_cell": pre_tree_refusals,
		},
		"recomputation_contract": RECOMPUTATION_CONTRACT.duplicate(true),
		"cells": cells,
		"execution": {
			"world_attempt_count": 1,
			"world_build_count": 1,
			"physics_step_count": derived_step_count,
			"retained_sample_count": retained_sample_count,
			"direct_force_write_count": 0,
			"direct_torque_write_count": 0,
			"direct_impulse_write_count": 0,
			"post_activation_transform_write_count": 0,
			"pre_activation_initial_angular_velocity_write_count": (
				initial_velocity_write_count
			),
			"declared_sleep_input_write_count": sleep_input_write_count,
			"schedule_start_physics_frame_boundary_count": (
				_r24d10_schedule_start_boundary_count
			),
			"pre_sample_physics_frame_count": 0,
			"terminal_physics_server_deactivation_count": (
				_r24d10_terminal_deactivation_count
			),
			"outcome_dependent_early_stop_count": 0,
			"space_step_sequence_initial_value": 0,
			"first_retained_space_step_sequence": first_token,
			"last_retained_space_step_sequence": last_token,
			"observed_retained_awake_space_step_token_count": observed_token_count,
			"extra_unretained_post_activation_step_count": 0,
			"first_pre_rate_capture_before_physics_server_enable": true,
			"physics_server_disabled_before_step_twenty_one": true,
			"physics_step_count_source": R24D10_PHYSICS_STEP_COUNT_SOURCE,
		},
		"evidence_provenance": {
			"synthetic_shape_only": false,
			"native_physical_observation": true,
		},
		"claims": {
			"descriptive_development_characterization_only": true,
			"descriptive_findings_are_acceptance_gates": false,
			"numerical_accuracy_accepted": false,
			"instrumented_profile_promoted": false,
			"stock_godot_profile_promoted": false,
			"recovery_claimed": false,
			"prone_to_standing_claimed": false,
			"turning_claim_changed": false,
			"cross_engine_equivalence_claimed": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
	}


func _template_shape_is_frozen(report: Dictionary) -> bool:
	var cells: Array = report.get("cells", [])
	var sample_count := 0
	var limit_positive_tokens: Array[int] = []
	var initial_rates_match := true
	for cell_value in cells:
		if not cell_value is Dictionary:
			return false
		var cell: Dictionary = cell_value
		var cell_id := String(cell.get("cell_id", ""))
		var samples: Array = cell.get("samples", [])
		sample_count += samples.size()
		if samples.is_empty() or not EXPECTED_INITIAL_RATE_PROJECTION.has(cell_id):
			return false
		var first_sample: Dictionary = samples[0]
		initial_rates_match = initial_rates_match and (
			float(first_sample.get("pre_canonical_relative_rate_rad_s", NAN)) ==
			float(EXPECTED_INITIAL_RATE_PROJECTION[cell_id])
		)
		if cell_id == "limit_positive":
			for sample_value in samples:
				var sample: Dictionary = sample_value
				var telemetry: Dictionary = sample.get("telemetry", {})
				limit_positive_tokens.append(
					int(telemetry.get("read_space_step_sequence", -1))
				)
	var execution: Dictionary = report.get("execution", {})
	var authorization: Dictionary = report.get("authorization", {})
	var runtime: Dictionary = report.get("runtime_provenance", {})
	var expected_tokens: Array[int] = []
	for token in range(1, 21):
		expected_tokens.append(token)
	return (
		String(report.get("schema_version", "")) == R24D10_RAW_SCHEMA
		and String(report.get("gate_id", "")) == "QSDK-R24D10"
		and String(report.get("question_class", "")) == "development"
		and String(report.get("evidence_kind", "")) == "synthetic_zero_world"
		and cells.size() == 9
		and sample_count == 68
		and initial_rates_match
		and limit_positive_tokens == expected_tokens
		and String(authorization.get("closure_id", "")) == "QSDK-R24D9-PH1-CLOSURE"
		and String(runtime.get("combined_patch_raw_sha256", "")) == (
			"sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
		)
		and int(execution.get("physics_step_count", -1)) == 20
		and int(execution.get("pre_sample_physics_frame_count", -1)) == 0
		and int(execution.get("first_retained_space_step_sequence", -1)) == 1
		and int(execution.get("last_retained_space_step_sequence", -1)) == 20
		and int(execution.get("extra_unretained_post_activation_step_count", -1)) == 0
		and String(execution.get("physics_step_count_source", "")) == (
			R24D10_PHYSICS_STEP_COUNT_SOURCE
		)
	)


func _fixture_description_is_frozen(description: Dictionary) -> bool:
	var ids: Array = description.get("cell_ids_in_order", [])
	return (
		String(description.get("fixture_id", "")) == R24D10Rig.FIXTURE_ID
		and int(description.get("world_count", -1)) == 1
		and int(description.get("isolated_cell_count", -1)) == 9
		and ids == [
			"drive_positive",
			"drive_negative",
			"brake_positive",
			"brake_negative",
			"disabled_positive",
			"disabled_negative",
			"limit_positive",
			"limit_negative",
			"sleep_stale",
		]
		and description.get("hinge_axis_parent_local", []) == [0.0, 0.0, 1.0]
		and int(description.get("maximum_physics_step_count", -1)) == 20
		and int(description.get("retained_sample_count", -1)) == 68
		and int(description.get("world_attempt_count", -1)) == 0
		and int(description.get("world_build_count", -1)) == 0
		and int(description.get("solver_step_count", -1)) == 0
	)


func _emit_failure(
	code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
) -> void:
	PhysicsServer3D.set_active(false)
	print(
		"QSDK_R24D10_WORKER_FAILURE ",
		JSON.stringify(
			{
				"ok": false,
				"failure_code": code,
				"world_attempt_count": world_attempt_count,
				"world_build_count": world_build_count,
				"solver_step_count": solver_step_count,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	_schedule_quit(1, "worker_failure")


func _schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		push_error("QSDK-R24D10 duplicate orderly-exit schedule")
		return
	_exit_scheduled = true
	_pending_exit_code = exit_code
	_pending_receipt_kind = receipt_kind
	_pending_exit_process_frames = EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_orderly_exit_process_frame, CONNECT_ONE_SHOT)


func _orderly_exit_process_frame() -> void:
	_pending_exit_process_frames -= 1
	if _pending_exit_process_frames > 0:
		process_frame.connect(_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(R24D10_SUPERVISED_TERMINATION_ENV) == "1":
		var termination_nonce := OS.get_environment(R24D10_TERMINATION_NONCE_ENV)
		if termination_nonce.is_empty():
			quit(1)
			return
		print(
			"QSDK_R24D10_GODOT_SUPERVISOR_TERMINATION_READY ",
			JSON.stringify(
				{
					"schema_version": (
						"sporespore_godot_supervised_termination_ready_v1"
					),
					"termination_protocol_id": TERMINATION_PROTOCOL_ID,
					"termination_nonce": termination_nonce,
					"process_id": OS.get_process_id(),
					"requested_exit_code": _pending_exit_code,
					"worker_receipt_kind": _pending_receipt_kind,
					"worker_receipt_emitted": true,
					"drained_process_frame_count": EXIT_DRAIN_PROCESS_FRAME_COUNT,
					"physics_evidence_authority": false,
				},
				"",
				true,
				true,
			),
		)
		return
	quit(_pending_exit_code)
