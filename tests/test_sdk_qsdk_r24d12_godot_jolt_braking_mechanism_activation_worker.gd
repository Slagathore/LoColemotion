extends "res://tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"

## QSDK-R24D12 minimal braking-mechanism worker.
##
## zero_world_preflight exercises registration, fixture description, refusal,
## template parsing, and report passthrough without constructing a body or joint.
## physical constructs four isolated cells and executes exactly one native step.

const R24D12Rig := preload(
	"res://scripts/lab/rigs/r24d12_godot_jolt_braking_mechanism_activation_rig.gd"
)
const R24D12_RAW_SCHEMA := (
	"sporespore_qsdk_r24d12_godot_jolt_braking_mechanism_activation_raw_report_v1"
)
const R24D12_ZERO_WORLD_TEMPLATE_PATH := "res://zero_world_template.json"
const R24D12_SUPERVISED_TERMINATION_ENV := "SPORESPORE_R24D12_SUPERVISED_TERMINATION"
const R24D12_TERMINATION_NONCE_ENV := "SPORESPORE_R24D12_TERMINATION_NONCE"
const R24D12_EXECUTION_NONCE_ENV := "SPORESPORE_R24D12_EXECUTION_NONCE"
const R24D12_SOURCE_COMMIT_ENV := "SPORESPORE_R24D12_SOURCE_COMMIT"
const R24D12_AUTHORIZATION := {
	"decision_gate_id": "QSDK-R24D11",
	"decision_path": (
		"sdk/recovery/" +
		"r24d11_godot_jolt_instrumented_profile_promotion_decision_v1.json"
	),
	"decision_raw_sha256": (
		"sha256:7418141ac1ac5fd4a6fab8a34956346ccd721792630025939e837f7b698440a4"
	),
	"decision_publication_commit": "324620ee4f228e856a898dff1be96fe4351b8ff0",
	"same_source_rerun": false,
}
const R24D12_RUNTIME_PROVENANCE := {
	"runtime_profile_id": (
		"godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2"
	),
	"godot_source_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
	"combined_patch_raw_sha256": (
		"sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
	),
	"activation_route_id": (
		"godot_jolt_unfreeze_then_public_angular_velocity_write_v1"
	),
	"engine_build_reuse_scope": "exact_unchanged_native_runtime_bytes_only",
}
const R24D12_EXPECTED_REAL_T_RATE := {
	"brake_positive": 0.4000000059604645,
	"brake_negative": -0.4000000059604645,
	"disabled_positive": 0.4000000059604645,
	"disabled_negative": -0.4000000059604645,
}

var _r24d12_context := {}
var _r24d12_schedule_started := false
var _r24d12_schedule_start_boundary_count := 0
var _r24d12_terminal_deactivation_count := 0


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	var mode := String(arguments.get("mode", ""))
	var source_commit := String(arguments.get("source_commit", ""))
	var nonce := String(arguments.get("nonce", ""))
	var report_path := String(arguments.get("report_path", ""))
	if mode != "zero_world_preflight" and mode != "physical":
		_r24d12_emit_failure("R24D12_MODE_INVALID", 0, 0, 0)
		return
	if (
		source_commit.length() != 40
		or nonce.length() != 32
		or report_path.is_empty()
		or OS.get_environment(R24D12_SOURCE_COMMIT_ENV) != source_commit
		or OS.get_environment(R24D12_EXECUTION_NONCE_ENV) != nonce
	):
		_r24d12_emit_failure("R24D12_AUTHORIZATION_HANDSHAKE_INVALID", 0, 0, 0)
		return
	if mode == "zero_world_preflight":
		_r24d12_run_zero_world_preflight(source_commit, nonce, report_path)
		return
	_r24d12_run_physical(source_commit, nonce, report_path)


func _r24d12_run_zero_world_preflight(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := R24D12Rig.describe()
	var invalid_rid_refused := false
	if _engine_receipt_is_frozen(engine):
		invalid_rid_refused = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
		)
	var template_text := FileAccess.get_file_as_string(
		R24D12_ZERO_WORLD_TEMPLATE_PATH
	)
	var template_value: Variant = JSON.parse_string(template_text)
	if not template_value is Dictionary:
		_r24d12_emit_failure("R24D12_ZERO_WORLD_TEMPLATE_INVALID", 0, 0, 0)
		return
	var report: Dictionary = template_value as Dictionary
	var template_shape_matches := _r24d12_template_shape_is_frozen(report)
	var template_identity_matches := (
		String(report.get("source_commit", "")) == source_commit
		and String(report.get("execution_nonce", "")) == nonce
	)
	var active_physics_object_count := float(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	)
	var ok := (
		_engine_receipt_is_frozen(engine)
		and _r24d12_fixture_description_is_frozen(description)
		and invalid_rid_refused
		and template_shape_matches
		and template_identity_matches
		and active_physics_object_count == 0.0
		and _write_text_report(report_path, template_text)
	)
	print(
		"QSDK_R24D12_WORKER_ZERO_WORLD ",
		JSON.stringify(
			{
				"ok": ok,
				"source_commit": source_commit,
				"execution_nonce": nonce,
				"engine_freeze_matches": _engine_receipt_is_frozen(engine),
				"fixture_description_matches": (
					_r24d12_fixture_description_is_frozen(description)
				),
				"invalid_rid_refused": invalid_rid_refused,
				"template_shape_matches": template_shape_matches,
				"template_identity_matches": template_identity_matches,
				"template_byte_passthrough": true,
				"synthetic_report_written": FileAccess.file_exists(report_path),
				"synthetic_embedded_world_count": 1,
				"synthetic_embedded_physics_step_count": 1,
				"synthetic_embedded_retained_sample_count": 4,
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
	_r24d12_schedule_quit(0 if ok else 1, "zero_world_preflight")


func _r24d12_run_physical(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := R24D12Rig.describe()
	if not _engine_receipt_is_frozen(engine):
		_r24d12_emit_failure("R24D12_ENGINE_OR_SOLVER_FREEZE_DRIFT", 0, 0, 0)
		return
	if not _r24d12_fixture_description_is_frozen(description):
		_r24d12_emit_failure("R24D12_FIXTURE_DECLARATION_DRIFT", 0, 0, 0)
		return
	var invalid_rid_refused := (
		JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
	)

	PhysicsServer3D.set_active(false)
	var rig := R24D12Rig.build()
	if not bool(rig.get("ok", false)):
		_r24d12_emit_failure(
			"R24D12_FIXTURE_BUILD_FAILED",
			int(rig.get("world_attempt_count", 1)),
			int(rig.get("world_build_count", 0)),
			0,
		)
		return
	var viewport: SubViewport = rig["viewport"]
	var cells: Array = rig["cells"]
	root.add_child(viewport)

	var activation_receipts: Array[Dictionary] = []
	var pre_rate_by_id := {}
	var parameter_readbacks := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var activation := R24D12Rig.activate_unfreeze_then_write(cell)
		activation["cell_id"] = cell_id
		activation_receipts.append(activation)
		var pre_rate := float(
			activation["physics_server_canonical_rate_readback_rad_s"]
		)
		if (
			not bool(activation.get("ok", false))
			or pre_rate != float(R24D12_EXPECTED_REAL_T_RATE[cell_id])
			or float(activation["scene_canonical_rate_readback_rad_s"]) != pre_rate
		):
			PhysicsServer3D.set_active(false)
			_r24d12_emit_failure("R24D12_INITIAL_NATIVE_RATE_TRANSFER_DRIFT", 1, 1, 0)
			return
		pre_rate_by_id[cell_id] = pre_rate
		parameter_readbacks[cell_id] = R24D12Rig.parameter_readback(cell)

	_r24d12_context = {
		"source_commit": source_commit,
		"nonce": nonce,
		"report_path": report_path,
		"engine": engine,
		"description": description,
		"invalid_rid_refused": invalid_rid_refused,
		"rig": rig,
		"viewport": viewport,
		"cells": cells,
		"activation_receipts": activation_receipts,
		"pre_rate_by_id": pre_rate_by_id,
		"parameter_readbacks": parameter_readbacks,
	}
	_r24d12_schedule_started = false
	_r24d12_schedule_start_boundary_count = 0
	_r24d12_terminal_deactivation_count = 0
	physics_frame.connect(_r24d12_on_physics_frame)


func _r24d12_on_physics_frame() -> void:
	if _r24d12_context.is_empty():
		PhysicsServer3D.set_active(false)
		_r24d12_emit_failure("R24D12_SCHEDULE_CONTEXT_MISSING", 1, 1, 0)
		return
	if not _r24d12_schedule_started:
		_r24d12_schedule_started = true
		_r24d12_schedule_start_boundary_count += 1
		PhysicsServer3D.set_active(true)
		return

	var cells: Array = _r24d12_context["cells"]
	var token := -1
	var raw_cells: Array[Dictionary] = []
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var child: RigidBody3D = cell["child"]
		var joint: HingeJoint3D = cell["joint"]
		var telemetry_value: Variant = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())
		)
		if not telemetry_value is Dictionary:
			_r24d12_abort_schedule("R24D12_ACTIVE_TELEMETRY_MISSING", token)
			return
		var telemetry := (telemetry_value as Dictionary).duplicate(true)
		var cell_token := int(telemetry.get("read_space_step_sequence", -1))
		if token == -1:
			token = cell_token
		elif token != cell_token:
			_r24d12_abort_schedule("R24D12_CELL_STEP_TOKEN_DIVERGENCE", token)
			return
		var pre_rate := float(_r24d12_context["pre_rate_by_id"][cell_id])
		var post_rate := R24D12Rig.canonical_rate_rad_s(cell)
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
				"pre_tree_read_refused": bool(cell["pre_tree_read_refused"]),
				"parameter_readback": (
					_r24d12_context["parameter_readbacks"][cell_id]
				),
				"samples": [
					{
						"step_index": 1,
						"pre_canonical_relative_rate_rad_s": pre_rate,
						"post_canonical_relative_rate_rad_s": post_rate,
						"inverse_inertia_axis_kg_inv_m2": (
							R24D12Rig.inverse_inertia_axis_kg_inv_m2(cell)
						),
						"host_target_velocity_readback_rad_s": joint.get_param(
							HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
						),
						"telemetry": telemetry,
						"child_sleeping": child.sleeping,
					},
				],
			}
		)

	PhysicsServer3D.set_active(false)
	_r24d12_terminal_deactivation_count += 1
	if physics_frame.is_connected(_r24d12_on_physics_frame):
		physics_frame.disconnect(_r24d12_on_physics_frame)
	if token != 1:
		_r24d12_emit_failure("R24D12_OBSERVED_STEP_TOKEN_NOT_ONE", 1, 1, token)
		return
	_r24d12_finalize_physical_report(raw_cells)


func _r24d12_abort_schedule(code: String, observed_token: int) -> void:
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_r24d12_on_physics_frame):
		physics_frame.disconnect(_r24d12_on_physics_frame)
	_r24d12_emit_failure(code, 1, 1, observed_token if observed_token > 0 else 0)


func _r24d12_finalize_physical_report(raw_cells: Array[Dictionary]) -> void:
	var report := _r24d12_report(
		"native_physical",
		String(_r24d12_context["source_commit"]),
		String(_r24d12_context["nonce"]),
		_r24d12_context["engine"],
		_r24d12_context["description"],
		bool(_r24d12_context["invalid_rid_refused"]),
		(_r24d12_context["rig"] as Dictionary)["pre_tree_refusals"],
		_r24d12_context["activation_receipts"],
		raw_cells,
	)
	var report_path := String(_r24d12_context["report_path"])
	var wrote_report := _write_json_report(report_path, report)
	print(
		"QSDK_R24D12_PHYSICAL_RAW_REPORT ",
		JSON.stringify(
			{
				"ok": wrote_report,
				"source_commit": _r24d12_context["source_commit"],
				"execution_nonce": _r24d12_context["nonce"],
				"report_path": report_path,
				"world_attempt_count": 1,
				"world_build_count": 1,
				"solver_step_count": 1,
				"retained_sample_count": 4,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	var viewport: SubViewport = _r24d12_context["viewport"]
	viewport.queue_free()
	_r24d12_context = {}
	_r24d12_schedule_quit(0 if wrote_report else 1, "physical_raw_report")


func _r24d12_report(
	evidence_kind: String,
	source_commit: String,
	nonce: String,
	engine: Dictionary,
	description: Dictionary,
	invalid_rid_refused: bool,
	pre_tree_refusals: Dictionary,
	activation_receipts: Array,
	cells: Array[Dictionary],
) -> Dictionary:
	return {
		"schema_version": R24D12_RAW_SCHEMA,
		"gate_id": "QSDK-R24D12",
		"question_class": "development",
		"evidence_kind": evidence_kind,
		"source_commit": source_commit,
		"execution_nonce": nonce,
		"authorization": R24D12_AUTHORIZATION.duplicate(true),
		"runtime_provenance": R24D12_RUNTIME_PROVENANCE.duplicate(true),
		"engine": engine,
		"fixture": description,
		"refusals": {
			"invalid_rid_refused": invalid_rid_refused,
			"not_in_tree_joint_read_refused_by_cell": pre_tree_refusals,
		},
		"activation_receipts": activation_receipts,
		"cells": cells,
		"execution": {
			"world_attempt_count": 1,
			"world_build_count": 1,
			"physics_step_count": 1,
			"retained_sample_count": 4,
			"direct_force_write_count": 0,
			"direct_torque_write_count": 0,
			"direct_impulse_write_count": 0,
			"post_activation_transform_write_count": 0,
			"unfreeze_write_count": 4,
			"scene_property_angular_velocity_write_count": 4,
			"physics_server_state_write_count": 0,
			"pre_sample_physics_frame_count": 0,
			"schedule_start_physics_frame_boundary_count": (
				_r24d12_schedule_start_boundary_count
			),
			"terminal_physics_server_deactivation_count": (
				_r24d12_terminal_deactivation_count
			),
			"outcome_dependent_early_stop_count": 0,
			"space_step_sequence_initial_value": 0,
			"first_retained_space_step_sequence": 1,
			"last_retained_space_step_sequence": 1,
			"observed_retained_space_step_token_count": 1,
			"extra_unretained_post_activation_step_count": 0,
			"physics_server_disabled_before_step_two": true,
		},
		"evidence_provenance": {
			"synthetic_shape_only": false,
			"native_physical_observation": true,
		},
		"claims": {
			"descriptive_development_characterization_only": true,
			"mechanism_witness_is_performance_threshold": false,
			"numerical_accuracy_accepted": false,
			"instrumented_profile_promoted": false,
			"stock_godot_profile_promoted": false,
			"native_capability_conjunction_complete": false,
			"recovery_world_opened": false,
			"prone_to_standing_world_opened": false,
			"turning_claim_changed": false,
			"cross_engine_equivalence_claimed": false,
			"q_sdk_r24_satisfied": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
	}


func _r24d12_template_shape_is_frozen(report: Dictionary) -> bool:
	var cells: Array = report.get("cells", [])
	var sample_count := 0
	for cell_value in cells:
		if not cell_value is Dictionary:
			return false
		var cell: Dictionary = cell_value
		sample_count += (cell.get("samples", []) as Array).size()
	var execution: Dictionary = report.get("execution", {})
	var runtime: Dictionary = report.get("runtime_provenance", {})
	return (
		String(report.get("schema_version", "")) == R24D12_RAW_SCHEMA
		and String(report.get("gate_id", "")) == "QSDK-R24D12"
		and String(report.get("question_class", "")) == "development"
		and String(report.get("evidence_kind", "")) == "synthetic_zero_world"
		and cells.size() == 4
		and sample_count == 4
		and int(execution.get("physics_step_count", -1)) == 1
		and int(execution.get("extra_unretained_post_activation_step_count", -1)) == 0
		and String(runtime.get("activation_route_id", "")) == (
			R24D12Rig.ACTIVATION_ROUTE_ID
		)
	)


func _r24d12_fixture_description_is_frozen(description: Dictionary) -> bool:
	return (
		String(description.get("fixture_id", "")) == R24D12Rig.FIXTURE_ID
		and String(description.get("activation_route_id", "")) == (
			R24D12Rig.ACTIVATION_ROUTE_ID
		)
		and int(description.get("world_count", -1)) == 1
		and int(description.get("isolated_cell_count", -1)) == 4
		and description.get("cell_ids_in_order", []) == [
			"brake_positive",
			"brake_negative",
			"disabled_positive",
			"disabled_negative",
		]
		and int(description.get("maximum_physics_step_count", -1)) == 1
		and int(description.get("retained_sample_count", -1)) == 4
		and int(description.get("world_attempt_count", -1)) == 0
		and int(description.get("world_build_count", -1)) == 0
		and int(description.get("solver_step_count", -1)) == 0
	)


func _r24d12_emit_failure(
	code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
) -> void:
	PhysicsServer3D.set_active(false)
	print(
		"QSDK_R24D12_WORKER_FAILURE ",
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
	_r24d12_schedule_quit(1, "worker_failure")


func _r24d12_schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		push_error("QSDK-R24D12 duplicate orderly-exit schedule")
		return
	_exit_scheduled = true
	_pending_exit_code = exit_code
	_pending_receipt_kind = receipt_kind
	_pending_exit_process_frames = EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_r24d12_orderly_exit_process_frame, CONNECT_ONE_SHOT)


func _r24d12_orderly_exit_process_frame() -> void:
	_pending_exit_process_frames -= 1
	if _pending_exit_process_frames > 0:
		process_frame.connect(_r24d12_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(R24D12_SUPERVISED_TERMINATION_ENV) == "1":
		var termination_nonce := OS.get_environment(R24D12_TERMINATION_NONCE_ENV)
		if termination_nonce.is_empty():
			quit(1)
			return
		print(
			"QSDK_R24D12_GODOT_SUPERVISOR_TERMINATION_READY ",
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
