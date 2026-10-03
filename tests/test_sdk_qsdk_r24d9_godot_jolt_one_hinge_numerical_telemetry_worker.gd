extends SceneTree

## QSDK-R24D9 dual-mode worker.
##
## zero_world_preflight validates registration and serializes the exact
## evaluator-shaped template without constructing a physics object. physical is
## reachable only through the supervisor handshake and consumes the separately
## authorized single native world.

const RigScript := preload(
	"res://scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
)

const RAW_SCHEMA := (
	"sporespore_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_raw_report_v1"
)
const TELEMETRY_SCHEMA := "sporespore.godot_jolt_hinge_motor_telemetry.v2"
const CLASS_NAME := &"JoltPhysicsServer3D"
const METHOD_NAME := &"hinge_joint_get_motor_telemetry"
const ZERO_WORLD_TEMPLATE_PATH := "res://zero_world_template.json"
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"
const SUPERVISED_TERMINATION_ENV := "SPORESPORE_R24D9_SUPERVISED_TERMINATION"
const TERMINATION_NONCE_ENV := "SPORESPORE_R24D9_TERMINATION_NONCE"
const EXECUTION_NONCE_ENV := "SPORESPORE_R24D9_EXECUTION_NONCE"
const SOURCE_COMMIT_ENV := "SPORESPORE_R24D9_SOURCE_COMMIT"
const EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
const AUTHORIZATION := {
	"closure_id": "QSDK-R24D8-PH1-CLOSURE",
	"closure_path": (
		"sdk/recovery/" +
		"r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json"
	),
	"closure_raw_sha256": (
		"sha256:a068b13f8fa97db5559572b1a221bff262da4c3d933a2544198ec67156cbba4d"
	),
	"closure_publication_commit": "4088881d92ea335c1cb70ff42e15abe5bf5d42c5",
}
const RUNTIME_PROVENANCE := {
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
	"r24d9_independent_cold_build_required": true,
}
const RECOMPUTATION_CONTRACT := {
	"effective_axis_inertia_kg_m2": "1 / inverse_inertia_axis_kg_inv_m2",
	"independent_angular_momentum_change_nms": (
		"effective_axis_inertia_kg_m2 * " +
		"(post_canonical_relative_rate_rad_s - pre_canonical_relative_rate_rad_s)"
	),
	"independent_kinetic_energy_change_j": (
		"0.5 * effective_axis_inertia_kg_m2 * " +
		"(post_canonical_relative_rate_rad_s^2 - " +
		"pre_canonical_relative_rate_rad_s^2)"
	),
	"impulse_residual_nms": (
		"signed_motor_impulse_nms - independent_angular_momentum_change_nms"
	),
	"work_residual_j": (
		"net_motor_work_j - independent_kinetic_energy_change_j"
	),
	"motor_impulse_cap_nms": (
		"max(abs(min_torque_limit_nm), abs(max_torque_limit_nm)) * solver_step_s"
	),
	"net_work_decomposition_residual_j": (
		"net_motor_work_j - (positive_motor_work_j - absorbed_motor_work_j)"
	),
	"relative_angle_integral_rad": (
		"prior_integrated_angle_rad + 0.5 * (pre_rate + post_rate) * solver_step_s"
	),
	"independent_oracle_uses_instrumented_motor_impulse_or_work_as_input": false,
	"sleeping_stale_samples_enter_numerical_aggregate": false,
}

var _exit_scheduled := false
var _pending_exit_code := 1
var _pending_receipt_kind := ""
var _pending_exit_process_frames := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	var mode := String(arguments.get("mode", ""))
	var source_commit := String(arguments.get("source_commit", ""))
	var nonce := String(arguments.get("nonce", ""))
	var report_path := String(arguments.get("report_path", ""))
	if mode != "zero_world_preflight" and mode != "physical":
		_emit_failure("R24D9_MODE_INVALID", 0, 0, 0)
		return
	if (
		source_commit.length() != 40
		or nonce.length() != 32
		or report_path.is_empty()
		or OS.get_environment(SOURCE_COMMIT_ENV) != source_commit
		or OS.get_environment(EXECUTION_NONCE_ENV) != nonce
	):
		_emit_failure("R24D9_AUTHORIZATION_HANDSHAKE_INVALID", 0, 0, 0)
		return
	if mode == "zero_world_preflight":
		_run_zero_world_preflight(source_commit, nonce, report_path)
		return
	await _run_physical(source_commit, nonce, report_path)


func _run_zero_world_preflight(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := RigScript.describe()
	var invalid_rid_refused := false
	if _engine_receipt_is_frozen(engine):
		invalid_rid_refused = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
		)
	var template_text := FileAccess.get_file_as_string(ZERO_WORLD_TEMPLATE_PATH)
	var template_value: Variant = JSON.parse_string(template_text)
	if not template_value is Dictionary:
		_emit_failure("R24D9_ZERO_WORLD_TEMPLATE_INVALID", 0, 0, 0)
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
		"QSDK_R24D9_WORKER_ZERO_WORLD ",
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
	var description := RigScript.describe()
	if not _engine_receipt_is_frozen(engine):
		_emit_failure("R24D9_ENGINE_OR_SOLVER_FREEZE_DRIFT", 0, 0, 0)
		return
	if not _fixture_description_is_frozen(description):
		_emit_failure("R24D9_FIXTURE_DECLARATION_DRIFT", 0, 0, 0)
		return
	var invalid_rid_refused := (
		JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
	)
	var rig := RigScript.build()
	if not bool(rig.get("ok", false)):
		_emit_failure(
			"R24D9_FIXTURE_BUILD_FAILED",
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
	for cell_value in cells:
		var cell: Dictionary = cell_value
		initial_velocity_write_count += RigScript.activate(cell)
		var cell_id := String(cell["cell_id"])
		retained_by_id[cell_id] = []
		integrated_angle_by_id[cell_id] = 0.0

	var parameter_readbacks := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		parameter_readbacks[String(cell["cell_id"])] = (
			RigScript.parameter_readback(cell)
		)

	var sleep_input_write_count := 0
	var pre_sample_physics_frame_count := 0
	var terminal_physics_server_deactivation_count := 0
	# physics_frame is emitted immediately before PhysicsServer3D.step. This first
	# boundary establishes the pre-step state; each subsequent boundary exposes
	# the completed solve and the v2 current-step snapshot for that same solve.
	await physics_frame
	pre_sample_physics_frame_count += 1
	for step_index in range(1, RigScript.MAXIMUM_PHYSICS_STEP_COUNT + 1):
		var pre_rate_by_id := {}
		for cell_value in cells:
			var cell: Dictionary = cell_value
			pre_rate_by_id[String(cell["cell_id"])] = (
				RigScript.canonical_rate_rad_s(cell)
			)
		await physics_frame
		for cell_value in cells:
			var cell: Dictionary = cell_value
			var cell_id := String(cell["cell_id"])
			if step_index > int(cell["retained_step_count"]):
				continue
			var child: RigidBody3D = cell["child"]
			var joint: HingeJoint3D = cell["joint"]
			var pre_rate := float(pre_rate_by_id[cell_id])
			var post_rate := RigScript.canonical_rate_rad_s(cell)
			var telemetry_value: Variant = (
				JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(
					joint.get_rid()
				)
			)
			var telemetry: Variant = null
			var solver_step_s := 1.0 / 120.0
			if telemetry_value is Dictionary:
				telemetry = (telemetry_value as Dictionary).duplicate(true)
				solver_step_s = float(
					(telemetry as Dictionary).get("solver_step_s", solver_step_s)
				)
			var integrated_angle := float(integrated_angle_by_id[cell_id])
			integrated_angle += 0.5 * (pre_rate + post_rate) * solver_step_s
			integrated_angle_by_id[cell_id] = integrated_angle
			(retained_by_id[cell_id] as Array).append(
				{
					"step_index": step_index,
					"pre_canonical_relative_rate_rad_s": pre_rate,
					"post_canonical_relative_rate_rad_s": post_rate,
					"inverse_inertia_axis_kg_inv_m2": (
						RigScript.inverse_inertia_axis_kg_inv_m2(cell)
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
		if step_index == 1:
			for cell_value in cells:
				var cell: Dictionary = cell_value
				if String(cell["cell_id"]) == "sleep_stale":
					RigScript.force_declared_sleep(cell)
					sleep_input_write_count += 1
					break

	# This boundary follows solve 20 and precedes solve 21. Deactivate the server
	# before serialization and shutdown-drain frames can create an unreported step.
	PhysicsServer3D.set_active(false)
	terminal_physics_server_deactivation_count += 1

	var raw_cells: Array[Dictionary] = []
	var retained_sample_count := 0
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var samples: Array = retained_by_id[cell_id]
		retained_sample_count += samples.size()
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

	var report := _report(
		"native_physical",
		source_commit,
		nonce,
		engine,
		description,
		invalid_rid_refused,
		rig["pre_tree_refusals"],
		raw_cells,
		initial_velocity_write_count,
		sleep_input_write_count,
		pre_sample_physics_frame_count,
		terminal_physics_server_deactivation_count,
		retained_sample_count,
	)
	var wrote_report := _write_json_report(report_path, report)
	print(
		"QSDK_R24D9_PHYSICAL_RAW_REPORT ",
		JSON.stringify(
			{
				"ok": wrote_report,
				"source_commit": source_commit,
				"execution_nonce": nonce,
				"report_path": report_path,
				"world_attempt_count": 1,
				"world_build_count": 1,
				"solver_step_count": RigScript.MAXIMUM_PHYSICS_STEP_COUNT,
				"retained_sample_count": retained_sample_count,
				"pre_sample_physics_frame_count": pre_sample_physics_frame_count,
				"terminal_physics_server_deactivation_count": (
					terminal_physics_server_deactivation_count
				),
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	viewport.queue_free()
	_schedule_quit(0 if wrote_report else 1, "physical_raw_report")


func _report(
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
	pre_sample_physics_frame_count: int,
	terminal_deactivation_count: int,
	retained_sample_count: int,
) -> Dictionary:
	return {
		"schema_version": RAW_SCHEMA,
		"gate_id": "QSDK-R24D9",
		"question_class": "development",
		"evidence_kind": evidence_kind,
		"source_commit": source_commit,
		"execution_nonce": nonce,
		"authorization": AUTHORIZATION.duplicate(true),
		"runtime_provenance": RUNTIME_PROVENANCE.duplicate(true),
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
			"physics_step_count": RigScript.MAXIMUM_PHYSICS_STEP_COUNT,
			"retained_sample_count": retained_sample_count,
			"direct_force_write_count": 0,
			"direct_torque_write_count": 0,
			"direct_impulse_write_count": 0,
			"post_activation_transform_write_count": 0,
			"pre_activation_initial_angular_velocity_write_count": (
				initial_velocity_write_count
			),
			"declared_sleep_input_write_count": sleep_input_write_count,
			"pre_sample_physics_frame_count": pre_sample_physics_frame_count,
			"terminal_physics_server_deactivation_count": terminal_deactivation_count,
			"outcome_dependent_early_stop_count": 0,
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
	for cell_value in cells:
		if not cell_value is Dictionary:
			return false
		var cell: Dictionary = cell_value
		var samples: Array = cell.get("samples", [])
		sample_count += samples.size()
	var authorization: Dictionary = report.get("authorization", {})
	var runtime: Dictionary = report.get("runtime_provenance", {})
	var recomputation: Dictionary = report.get("recomputation_contract", {})
	return (
		String(report.get("schema_version", "")) == RAW_SCHEMA
		and String(report.get("gate_id", "")) == "QSDK-R24D9"
		and String(report.get("question_class", "")) == "development"
		and String(report.get("evidence_kind", "")) == "synthetic_zero_world"
		and cells.size() == 9
		and sample_count == 68
		and String(authorization.get("closure_id", "")) == "QSDK-R24D8-PH1-CLOSURE"
		and String(runtime.get("combined_patch_raw_sha256", "")) == (
			"sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
		)
		and String(recomputation.get("motor_impulse_cap_nms", "")) == (
			"max(abs(min_torque_limit_nm), abs(max_torque_limit_nm)) * solver_step_s"
		)
	)


func _engine_receipt() -> Dictionary:
	var separate_thread := bool(
		ProjectSettings.get_setting("physics/3d/run_on_separate_thread", false)
	)
	return {
		"physics_engine": String(
			ProjectSettings.get_setting("physics/3d/physics_engine", "")
		),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"solver_velocity_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
		"thread_model": "separate" if separate_thread else "single_safe",
		"telemetry_class_registered": ClassDB.class_exists(CLASS_NAME),
		"telemetry_method_registered": ClassDB.class_has_method(
			CLASS_NAME,
			METHOD_NAME,
		),
	}


func _engine_receipt_is_frozen(engine: Dictionary) -> bool:
	return (
		String(engine.get("physics_engine", "")) == "Jolt Physics"
		and int(engine.get("physics_ticks_per_second", -1)) == 120
		and int(engine.get("solver_velocity_steps", -1)) == 20
		and int(engine.get("solver_position_steps", -1)) == 7
		and String(engine.get("thread_model", "")) == "single_safe"
		and bool(engine.get("telemetry_class_registered", false))
		and bool(engine.get("telemetry_method_registered", false))
	)


func _fixture_description_is_frozen(description: Dictionary) -> bool:
	var ids: Array = description.get("cell_ids_in_order", [])
	return (
		String(description.get("fixture_id", "")) == RigScript.FIXTURE_ID
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


func _write_json_report(path: String, report: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "", true, true) + "\n")
	file.close()
	return FileAccess.file_exists(path)


func _write_text_report(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null or text.is_empty():
		return false
	file.store_string(text)
	file.close()
	return FileAccess.file_exists(path)


func _emit_failure(
	code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
) -> void:
	print(
		"QSDK_R24D9_WORKER_FAILURE ",
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
		push_error("QSDK-R24D9 duplicate orderly-exit schedule")
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
	if OS.get_environment(SUPERVISED_TERMINATION_ENV) == "1":
		var termination_nonce := OS.get_environment(TERMINATION_NONCE_ENV)
		if termination_nonce.is_empty():
			quit(1)
			return
		print(
			"QSDK_R24D9_GODOT_SUPERVISOR_TERMINATION_READY ",
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
					"drained_process_frame_count": (
						EXIT_DRAIN_PROCESS_FRAME_COUNT
					),
					"physics_evidence_authority": false,
				},
				"",
				true,
				true,
			),
		)
		return
	quit(_pending_exit_code)


func _parse_user_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in arguments:
		var separator := argument.find("=")
		if not argument.begins_with("--") or separator <= 2:
			continue
		parsed[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return parsed
