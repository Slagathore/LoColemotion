extends "res://tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"

## QSDK-R24D13 minimal braking-mechanism worker.
##
## zero_world_preflight exercises registration, fixture description, refusal,
## native real_t readback, full-precision JSON serialization, and the complete
## evaluator-shaped report path without constructing a body or joint.
## physical constructs four isolated cells and executes exactly one native step.

const R24D13Rig := preload(
	"res://scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd"
)
const R24D13_RAW_SCHEMA := (
	"sporespore_qsdk_r24d13_godot_jolt_braking_mechanism_activation_raw_report_v1"
)
const R24D13_ZERO_WORLD_TEMPLATE_PATH := "res://zero_world_template.json"
const R24D13_SUPERVISED_TERMINATION_ENV := "SPORESPORE_R24D13_SUPERVISED_TERMINATION"
const R24D13_TERMINATION_NONCE_ENV := "SPORESPORE_R24D13_TERMINATION_NONCE"
const R24D13_EXECUTION_NONCE_ENV := "SPORESPORE_R24D13_EXECUTION_NONCE"
const R24D13_SOURCE_COMMIT_ENV := "SPORESPORE_R24D13_SOURCE_COMMIT"
const R24D13_AUTHORIZATION := {
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
const R24D13_RUNTIME_PROVENANCE := {
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
const R24D13_EXPECTED_REAL_T_RATE := {
	"brake_positive": 0.4000000059604645,
	"brake_negative": -0.4000000059604645,
	"disabled_positive": 0.4000000059604645,
	"disabled_negative": -0.4000000059604645,
}

var _r24d13_context := {}
var _r24d13_schedule_started := false
var _r24d13_schedule_start_boundary_count := 0
var _r24d13_terminal_deactivation_count := 0


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	var mode := String(arguments.get("mode", ""))
	var source_commit := String(arguments.get("source_commit", ""))
	var nonce := String(arguments.get("nonce", ""))
	var report_path := String(arguments.get("report_path", ""))
	if mode != "zero_world_preflight" and mode != "physical":
		_r24d13_emit_failure("R24D13_MODE_INVALID", 0, 0, 0)
		return
	if (
		source_commit.length() != 40
		or nonce.length() != 32
		or report_path.is_empty()
		or OS.get_environment(R24D13_SOURCE_COMMIT_ENV) != source_commit
		or OS.get_environment(R24D13_EXECUTION_NONCE_ENV) != nonce
	):
		_r24d13_emit_failure("R24D13_AUTHORIZATION_HANDSHAKE_INVALID", 0, 0, 0)
		return
	if mode == "zero_world_preflight":
		_r24d13_run_zero_world_preflight(source_commit, nonce, report_path)
		return
	_r24d13_run_physical(source_commit, nonce, report_path)


func _r24d13_run_zero_world_preflight(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := R24D13Rig.describe()
	var invalid_rid_refused := false
	if _engine_receipt_is_frozen(engine):
		invalid_rid_refused = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
		)
	var template_text := FileAccess.get_file_as_string(
		R24D13_ZERO_WORLD_TEMPLATE_PATH
	)
	var template_value: Variant = JSON.parse_string(template_text)
	if not template_value is Dictionary:
		_r24d13_emit_failure("R24D13_ZERO_WORLD_TEMPLATE_INVALID", 0, 0, 0)
		return
	var report: Dictionary = template_value as Dictionary
	var template_shape_matches := _r24d13_template_shape_is_frozen(report)
	var template_identity_matches := (
		String(report.get("source_commit", "")) == source_commit
		and String(report.get("execution_nonce", "")) == nonce
	)
	var active_physics_object_count := float(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	)
	var native_inertia_readback: Array = description.get(
		"child_inertia_diagonal_kg_m2",
		[],
	)
	var native_float32_inertia_readback_matches := native_inertia_readback == [
		0.05000000074505806,
		0.05000000074505806,
		0.05000000074505806,
	]
	var pre_tree_refusals := {
		"brake_positive": true,
		"brake_negative": true,
		"disabled_positive": true,
		"disabled_negative": true,
	}
	var serialized_report := _r24d13_report(
		"synthetic_zero_world",
		source_commit,
		nonce,
		engine,
		description,
		invalid_rid_refused,
		pre_tree_refusals,
		_r24d13_zero_world_activation_receipts(),
		_r24d13_zero_world_cells(native_inertia_readback),
	)
	var ok := (
		_engine_receipt_is_frozen(engine)
		and _r24d13_fixture_description_is_frozen(description)
		and invalid_rid_refused
		and template_shape_matches
		and template_identity_matches
		and native_float32_inertia_readback_matches
		and active_physics_object_count == 0.0
		and _write_json_report(report_path, serialized_report)
	)
	print(
		"QSDK_R24D13_WORKER_ZERO_WORLD ",
		JSON.stringify(
			{
				"ok": ok,
				"source_commit": source_commit,
				"execution_nonce": nonce,
				"engine_freeze_matches": _engine_receipt_is_frozen(engine),
				"fixture_description_matches": (
					_r24d13_fixture_description_is_frozen(description)
				),
				"invalid_rid_refused": invalid_rid_refused,
				"template_shape_matches": template_shape_matches,
				"template_identity_matches": template_identity_matches,
				"template_byte_passthrough": false,
				"native_serializer_path_exercised": true,
				"native_float32_inertia_readback_matches": (
					native_float32_inertia_readback_matches
				),
				"native_inertia_readback": native_inertia_readback,
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
	_r24d13_schedule_quit(0 if ok else 1, "zero_world_preflight")


func _r24d13_zero_world_activation_receipts() -> Array:
	var receipts: Array = []
	for spec_value in _r24d13_zero_world_specs():
		var spec: Dictionary = spec_value
		receipts.append(
			{
				"cell_id": spec["cell_id"],
				"ok": true,
				"activation_route_id": R24D13Rig.ACTIVATION_ROUTE_ID,
				"unfreeze_write_count": 1,
				"can_sleep_write_count": 1,
				"sleeping_write_count": 1,
				"scene_property_angular_velocity_write_count": 1,
				"physics_server_state_write_count": 0,
				"declared_canonical_rate_rad_s": spec["declared_rate"],
				"scene_canonical_rate_readback_rad_s": spec["native_rate"],
				"physics_server_canonical_rate_readback_rad_s": (
					spec["native_rate"]
				),
			}
		)
	return receipts


func _r24d13_zero_world_cells(native_inertia: Array) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for spec_value in _r24d13_zero_world_specs():
		var spec: Dictionary = spec_value
		var enabled := bool(spec["motor_enabled"])
		var rate := float(spec["native_rate"])
		var impulse := 0.0
		var post_rate := rate
		var absorbed_work := 0.0
		if enabled:
			impulse = -0.0020000000949949026 if rate > 0.0 else 0.0020000000949949026
			post_rate = rate + impulse / 0.05
			absorbed_work = 0.0007600000244565308
		cells.append(
			{
				"cell_id": spec["cell_id"],
				"family": spec["family"],
				"motor_enabled": enabled,
				"canonical_target_velocity_rad_s": 0.0,
				"initial_canonical_rate_rad_s": spec["declared_rate"],
				"public_maximum_motor_impulse_nms": 0.002,
				"pre_tree_read_refused": true,
				"parameter_readback": {
					"child_mass_kg": 1.0,
					"child_inertia_diagonal_kg_m2": native_inertia.duplicate(),
					"gravity_scale": 0.0,
					"linear_damping": 0.0,
					"angular_damping": 0.0,
					"collision_layer": 0,
					"collision_mask": 0,
					"motor_enabled": enabled,
					"joint_limits_enabled": false,
					"host_target_velocity_rad_s": 0.0,
					"public_maximum_motor_impulse_nms": 0.0020000000949949026,
					"lower_limit_rad": -1.0,
					"upper_limit_rad": 1.0,
					"anchor_error_m": 0.0,
					"axis_error_rad": 0.0,
				},
				"samples": [
					{
						"step_index": 1,
						"pre_canonical_relative_rate_rad_s": rate,
						"post_canonical_relative_rate_rad_s": post_rate,
						"inverse_inertia_axis_kg_inv_m2": 20.0,
						"host_target_velocity_readback_rad_s": 0.0,
						"telemetry": {
							"schema": (
								"sporespore.godot_jolt_hinge_motor_telemetry.v2"
							),
							"telemetry_sequence": 1,
							"capture_space_step_sequence": 1,
							"read_space_step_sequence": 1,
							"captured_during_active_step": true,
							"snapshot_is_current_space_step": true,
							"solver_step_s": 0.008333333767950535,
							"motor_state": "velocity" if enabled else "off",
							"target_angular_velocity_rad_s": 0.0,
							"min_torque_limit_nm": -0.24000000953674316,
							"max_torque_limit_nm": 0.24000000953674316,
							"signed_motor_impulse_nms": impulse,
							"positive_motor_work_j": 0.0,
							"absorbed_motor_work_j": absorbed_work,
							"net_motor_work_j": -absorbed_work,
						},
						"child_sleeping": false,
					}
				],
			}
		)
	return cells


func _r24d13_zero_world_specs() -> Array:
	return [
		{
			"cell_id": "brake_positive",
			"family": "signed_braking",
			"motor_enabled": true,
			"declared_rate": 0.4,
			"native_rate": 0.4000000059604645,
		},
		{
			"cell_id": "brake_negative",
			"family": "signed_braking",
			"motor_enabled": true,
			"declared_rate": -0.4,
			"native_rate": -0.4000000059604645,
		},
		{
			"cell_id": "disabled_positive",
			"family": "motor_disabled",
			"motor_enabled": false,
			"declared_rate": 0.4,
			"native_rate": 0.4000000059604645,
		},
		{
			"cell_id": "disabled_negative",
			"family": "motor_disabled",
			"motor_enabled": false,
			"declared_rate": -0.4,
			"native_rate": -0.4000000059604645,
		},
	]


func _r24d13_run_physical(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := R24D13Rig.describe()
	if not _engine_receipt_is_frozen(engine):
		_r24d13_emit_failure("R24D13_ENGINE_OR_SOLVER_FREEZE_DRIFT", 0, 0, 0)
		return
	if not _r24d13_fixture_description_is_frozen(description):
		_r24d13_emit_failure("R24D13_FIXTURE_DECLARATION_DRIFT", 0, 0, 0)
		return
	var invalid_rid_refused := (
		JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
	)

	PhysicsServer3D.set_active(false)
	var rig := R24D13Rig.build()
	if not bool(rig.get("ok", false)):
		_r24d13_emit_failure(
			"R24D13_FIXTURE_BUILD_FAILED",
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
		var activation := R24D13Rig.activate_unfreeze_then_write(cell)
		activation["cell_id"] = cell_id
		activation_receipts.append(activation)
		var pre_rate := float(
			activation["physics_server_canonical_rate_readback_rad_s"]
		)
		if (
			not bool(activation.get("ok", false))
			or pre_rate != float(R24D13_EXPECTED_REAL_T_RATE[cell_id])
			or float(activation["scene_canonical_rate_readback_rad_s"]) != pre_rate
		):
			PhysicsServer3D.set_active(false)
			_r24d13_emit_failure("R24D13_INITIAL_NATIVE_RATE_TRANSFER_DRIFT", 1, 1, 0)
			return
		pre_rate_by_id[cell_id] = pre_rate
		parameter_readbacks[cell_id] = R24D13Rig.parameter_readback(cell)

	_r24d13_context = {
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
	_r24d13_schedule_started = false
	_r24d13_schedule_start_boundary_count = 0
	_r24d13_terminal_deactivation_count = 0
	physics_frame.connect(_r24d13_on_physics_frame)


func _r24d13_on_physics_frame() -> void:
	if _r24d13_context.is_empty():
		PhysicsServer3D.set_active(false)
		_r24d13_emit_failure("R24D13_SCHEDULE_CONTEXT_MISSING", 1, 1, 0)
		return
	if not _r24d13_schedule_started:
		_r24d13_schedule_started = true
		_r24d13_schedule_start_boundary_count += 1
		PhysicsServer3D.set_active(true)
		return

	var cells: Array = _r24d13_context["cells"]
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
			_r24d13_abort_schedule("R24D13_ACTIVE_TELEMETRY_MISSING", token)
			return
		var telemetry := (telemetry_value as Dictionary).duplicate(true)
		var cell_token := int(telemetry.get("read_space_step_sequence", -1))
		if token == -1:
			token = cell_token
		elif token != cell_token:
			_r24d13_abort_schedule("R24D13_CELL_STEP_TOKEN_DIVERGENCE", token)
			return
		var pre_rate := float(_r24d13_context["pre_rate_by_id"][cell_id])
		var post_rate := R24D13Rig.canonical_rate_rad_s(cell)
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
					_r24d13_context["parameter_readbacks"][cell_id]
				),
				"samples": [
					{
						"step_index": 1,
						"pre_canonical_relative_rate_rad_s": pre_rate,
						"post_canonical_relative_rate_rad_s": post_rate,
						"inverse_inertia_axis_kg_inv_m2": (
							R24D13Rig.inverse_inertia_axis_kg_inv_m2(cell)
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
	_r24d13_terminal_deactivation_count += 1
	if physics_frame.is_connected(_r24d13_on_physics_frame):
		physics_frame.disconnect(_r24d13_on_physics_frame)
	if token != 1:
		_r24d13_emit_failure("R24D13_OBSERVED_STEP_TOKEN_NOT_ONE", 1, 1, token)
		return
	_r24d13_finalize_physical_report(raw_cells)


func _r24d13_abort_schedule(code: String, observed_token: int) -> void:
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_r24d13_on_physics_frame):
		physics_frame.disconnect(_r24d13_on_physics_frame)
	_r24d13_emit_failure(code, 1, 1, observed_token if observed_token > 0 else 0)


func _r24d13_finalize_physical_report(raw_cells: Array[Dictionary]) -> void:
	var report := _r24d13_report(
		"native_physical",
		String(_r24d13_context["source_commit"]),
		String(_r24d13_context["nonce"]),
		_r24d13_context["engine"],
		_r24d13_context["description"],
		bool(_r24d13_context["invalid_rid_refused"]),
		(_r24d13_context["rig"] as Dictionary)["pre_tree_refusals"],
		_r24d13_context["activation_receipts"],
		raw_cells,
	)
	var report_path := String(_r24d13_context["report_path"])
	var wrote_report := _write_json_report(report_path, report)
	print(
		"QSDK_R24D13_PHYSICAL_RAW_REPORT ",
		JSON.stringify(
			{
				"ok": wrote_report,
				"source_commit": _r24d13_context["source_commit"],
				"execution_nonce": _r24d13_context["nonce"],
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
	var viewport: SubViewport = _r24d13_context["viewport"]
	viewport.queue_free()
	_r24d13_context = {}
	_r24d13_schedule_quit(0 if wrote_report else 1, "physical_raw_report")


func _r24d13_report(
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
	var synthetic := evidence_kind == "synthetic_zero_world"
	return {
		"schema_version": R24D13_RAW_SCHEMA,
		"gate_id": "QSDK-R24D13",
		"question_class": "development",
		"evidence_kind": evidence_kind,
		"source_commit": source_commit,
		"execution_nonce": nonce,
		"authorization": R24D13_AUTHORIZATION.duplicate(true),
		"runtime_provenance": R24D13_RUNTIME_PROVENANCE.duplicate(true),
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
				1 if synthetic else _r24d13_schedule_start_boundary_count
			),
			"terminal_physics_server_deactivation_count": (
				1 if synthetic else _r24d13_terminal_deactivation_count
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
			"synthetic_shape_only": synthetic,
			"native_physical_observation": not synthetic,
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


func _r24d13_template_shape_is_frozen(report: Dictionary) -> bool:
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
		String(report.get("schema_version", "")) == R24D13_RAW_SCHEMA
		and String(report.get("gate_id", "")) == "QSDK-R24D13"
		and String(report.get("question_class", "")) == "development"
		and String(report.get("evidence_kind", "")) == "synthetic_zero_world"
		and cells.size() == 4
		and sample_count == 4
		and int(execution.get("physics_step_count", -1)) == 1
		and int(execution.get("extra_unretained_post_activation_step_count", -1)) == 0
		and String(runtime.get("activation_route_id", "")) == (
			R24D13Rig.ACTIVATION_ROUTE_ID
		)
	)


func _r24d13_fixture_description_is_frozen(description: Dictionary) -> bool:
	return (
		String(description.get("fixture_id", "")) == R24D13Rig.FIXTURE_ID
		and String(description.get("activation_route_id", "")) == (
			R24D13Rig.ACTIVATION_ROUTE_ID
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


func _r24d13_emit_failure(
	code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
) -> void:
	PhysicsServer3D.set_active(false)
	print(
		"QSDK_R24D13_WORKER_FAILURE ",
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
	_r24d13_schedule_quit(1, "worker_failure")


func _r24d13_schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		push_error("QSDK-R24D13 duplicate orderly-exit schedule")
		return
	_exit_scheduled = true
	_pending_exit_code = exit_code
	_pending_receipt_kind = receipt_kind
	_pending_exit_process_frames = EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_r24d13_orderly_exit_process_frame, CONNECT_ONE_SHOT)


func _r24d13_orderly_exit_process_frame() -> void:
	_pending_exit_process_frames -= 1
	if _pending_exit_process_frames > 0:
		process_frame.connect(_r24d13_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(R24D13_SUPERVISED_TERMINATION_ENV) == "1":
		var termination_nonce := OS.get_environment(R24D13_TERMINATION_NONCE_ENV)
		if termination_nonce.is_empty():
			quit(1)
			return
		print(
			"QSDK_R24D13_GODOT_SUPERVISOR_TERMINATION_READY ",
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
