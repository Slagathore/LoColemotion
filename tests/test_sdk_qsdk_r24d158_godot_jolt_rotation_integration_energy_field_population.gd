extends SceneTree

## Dual-mode R158 worker. With no user arguments it runs only pure declaration,
## binding, and refusal controls. The physical mode is reachable only through
## an exact source/authorization/nonce handshake and consumes one world for two
## outer steps. It observes native v6 population; it does not test recovery.

const RigScript := preload(
	"res://scripts/lab/rigs/r24d158_godot_jolt_rotation_integration_energy_rig.gd"
)
const ConsumerScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_solver_energy_exchange_v2.gd"
)

const GATE_ID := "QSDK-R24D158"
const SOURCE_SUCCESSOR_ID := "QSDK-R24D160"
const EFFECTIVE_WORLD_LOOKUP_ID := "inserted_child_get_world_3d_v1"
const ZERO_WORLD_MARKER := (
	"QSDK_R24D158_GODOT_JOLT_ROTATION_INTEGRATION_ENERGY_ZERO_WORLD "
)
const RAW_MARKER := (
	"QSDK_R24D158_GODOT_JOLT_ROTATION_INTEGRATION_ENERGY_PHYSICAL_RAW "
)
const READY_MARKER := "QSDK_R24D158_GODOT_SUPERVISOR_TERMINATION_READY "
const TELEMETRY_CLASS_NAME := &"JoltPhysicsServer3D"
const TELEMETRY_METHOD_NAME := &"space_get_solver_energy_exchange_telemetry"
const EXPECTED_SEED := 1993948368
const EXPECTED_SEED_LABEL := (
	"sporespore.qsdk.r24d158.godot_jolt.rotation_integration_energy_field_population.development.v1"
)
const EXPECTED_SEED_SHA256 := (
	"sha256:76d93cd048ce43804473bd945688a6ea4619c0a190c98a9f4853afde052de420"
)
const EVIDENCE_ROOT_PREFIX := (
	"C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
)
const SOURCE_COMMIT_ENV := "SPORESPORE_R24D158_SOURCE_COMMIT"
const AUTHORIZATION_SHA_ENV := "SPORESPORE_R24D158_AUTHORIZATION_SHA256"
const ATTEMPT_ID_ENV := "SPORESPORE_R24D158_ATTEMPT_ID"
const EXECUTION_NONCE_ENV := "SPORESPORE_R24D158_EXECUTION_NONCE"
const SUPERVISED_TERMINATION_ENV := "SPORESPORE_R24D158_SUPERVISED_TERMINATION"
const TERMINATION_NONCE_ENV := "SPORESPORE_R24D158_TERMINATION_NONCE"
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"
const EXIT_DRAIN_PROCESS_FRAME_COUNT := 2

var _exit_scheduled := false
var _pending_exit_code := 1
var _pending_receipt_kind := ""
var _pending_exit_process_frames := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	if arguments.is_empty():
		_run_zero_world()
		return
	await _run_physical(arguments)


func _run_zero_world() -> void:
	var engine := _engine_receipt()
	var description := RigScript.describe()
	var valid_request := _synthetic_request()
	var valid_request_accepted := _physical_request_valid(valid_request, false)
	var mutation_rejection_count := 0
	for key in ["source_commit", "authorization_sha256", "seed", "report_path"]:
		var mutation := valid_request.duplicate(true)
		if key == "seed":
			mutation[key] = EXPECTED_SEED + 1
		else:
			mutation.erase(key)
		mutation_rejection_count += int(not _physical_request_valid(mutation, false))
	var invalid_rid_value: Variant = null
	if bool(engine.get("telemetry_method_registered", false)):
		invalid_rid_value = ClassDB.class_call_static(
			TELEMETRY_CLASS_NAME,
			TELEMETRY_METHOD_NAME,
			RID(),
		)
	var invalid_rid_refused := invalid_rid_value == null
	var ok := (
		_engine_receipt_is_frozen(engine)
		and _fixture_description_is_frozen(description)
		and SOURCE_SUCCESSOR_ID == "QSDK-R24D160"
		and EFFECTIVE_WORLD_LOOKUP_ID == "inserted_child_get_world_3d_v1"
		and valid_request_accepted
		and mutation_rejection_count == 4
		and invalid_rid_refused
	)
	var result := {
		"schema_version": (
			"sporespore_qsdk_r24d158_godot_jolt_rotation_integration_energy_zero_world_v1"
		),
		"gate_id": GATE_ID,
		"source_successor_id": SOURCE_SUCCESSOR_ID,
		"ok": ok,
		"status": (
			"passed_zero_world_native_observation_route_controls"
			if ok
			else "failed_zero_world_native_observation_route_controls"
		),
		"telemetry_class_registered": bool(
			engine.get("telemetry_class_registered", false)
		),
		"telemetry_method_registered": bool(
			engine.get("telemetry_method_registered", false)
		),
		"invalid_rid_refusal_observed": invalid_rid_refused,
		"fixture_description_matches": _fixture_description_is_frozen(description),
		"valid_request_accepted": valid_request_accepted,
		"request_mutation_rejection_count": mutation_rejection_count,
		"physical_question_kind": "native_observation_smoke",
		"effective_world_lookup_id": EFFECTIVE_WORLD_LOOKUP_ID,
		"custom_world_property_read_count": 0,
		"explicit_world_null_refusal_declared": true,
		"explicit_space_rid_refusal_declared": true,
		"completed_solver_step_counter_declared": true,
		"declared_world_count": 1,
		"declared_maximum_outer_solver_steps": 2,
		"declared_native_observation_count": 2,
		"positive_case_count": 2,
		"forced_failure_case_count": mutation_rejection_count + 1,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	print(ZERO_WORLD_MARKER, JSON.stringify(result, "", false, true))
	# Zero-world qualification owns no physics objects and needs no shutdown
	# containment drain. Exit directly so a host cannot retain the conformance
	# mutex after the complete receipt has already been emitted.
	quit(0 if ok else 1)


func _run_physical(arguments: Dictionary) -> void:
	if not _physical_request_valid(arguments, true):
		_emit_physical_failure(
			arguments,
			"QSDK_R24D158_AUTHORIZATION_HANDSHAKE_INVALID",
			0,
			0,
			0,
			[],
		)
		return
	var report_path := String(arguments["report_path"])
	if FileAccess.file_exists(report_path):
		_emit_physical_failure(
			arguments,
			"QSDK_R24D158_REPORT_PATH_ALREADY_EXISTS",
			0,
			0,
			0,
			[],
		)
		return
	Engine.physics_ticks_per_second = 120
	var engine := _engine_receipt()
	var description := RigScript.describe()
	if (
		not _engine_receipt_is_frozen(engine)
		or int(engine.get("physics_ticks_per_second", -1)) != 120
	):
		_emit_physical_failure(
			arguments,
			"QSDK_R24D158_ENGINE_OR_SOLVER_FREEZE_DRIFT",
			0,
			0,
			0,
			[],
		)
		return
	if not _fixture_description_is_frozen(description):
		_emit_physical_failure(
			arguments,
			"QSDK_R24D158_FIXTURE_DECLARATION_DRIFT",
			0,
			0,
			0,
			[],
		)
		return
	seed(EXPECTED_SEED)
	var rig := RigScript.build()
	if not bool(rig.get("ok", false)):
		_emit_physical_failure(
			arguments,
			"QSDK_R24D158_FIXTURE_BUILD_FAILED",
			int(rig.get("world_attempt_count", 1)),
			int(rig.get("world_build_count", 0)),
			0,
			[],
		)
		return
	var viewport: SubViewport = rig["viewport"]
	var child: RigidBody3D = rig["child"]
	root.add_child(viewport)
	var world_3d: World3D = child.get_world_3d()
	if world_3d == null:
		PhysicsServer3D.set_active(false)
		viewport.queue_free()
		_emit_physical_failure(
			arguments,
			"QSDK_R24D160_EFFECTIVE_WORLD_MISSING",
			1,
			1,
			0,
			[],
			1,
		)
		return
	var space_rid: RID = world_3d.space
	if not space_rid.is_valid():
		PhysicsServer3D.set_active(false)
		viewport.queue_free()
		_emit_physical_failure(
			arguments,
			"QSDK_R24D160_EFFECTIVE_WORLD_SPACE_INVALID",
			1,
			1,
			0,
			[],
			1,
		)
		return
	RigScript.activate(rig)
	var parameter_readback := RigScript.parameter_readback(rig)
	var world_binding := {
		"source_successor_id": SOURCE_SUCCESSOR_ID,
		"effective_world_lookup_id": EFFECTIVE_WORLD_LOOKUP_ID,
		"inserted_child_inside_tree": child.is_inside_tree(),
		"effective_world_nonnull": true,
		"space_rid_valid_before_first_physics_boundary": space_rid.is_valid(),
		"custom_world_property_read_count": 0,
		"lookup_before_first_physics_boundary": true,
	}
	var samples: Array[Dictionary] = []
	var pre_sample_physics_frame_count := 0
	var completed_solver_step_count := 0
	# SceneTree.physics_frame precedes PhysicsServer3D.step. Consume one boundary
	# so the next boundary observes the first completed solve.
	await physics_frame
	pre_sample_physics_frame_count += 1
	for step_index in range(1, RigScript.MAXIMUM_OUTER_SOLVER_STEPS + 1):
		await physics_frame
		completed_solver_step_count += 1
		var telemetry_value: Variant = ClassDB.class_call_static(
			TELEMETRY_CLASS_NAME,
			TELEMETRY_METHOD_NAME,
			space_rid,
		)
		var telemetry: Dictionary = {}
		var consumer: Dictionary = {
			"ok": false,
			"failure_code": "QSDK_R24D158_NATIVE_TELEMETRY_NOT_DICTIONARY",
		}
		if telemetry_value is Dictionary:
			telemetry = (telemetry_value as Dictionary).duplicate(true)
			var expected_sequence := int(
				telemetry.get("read_space_step_sequence", -1)
			)
			consumer = ConsumerScript.native_solver_energy_exchange_contract_v2(
				telemetry,
				expected_sequence,
				Vector3.ZERO,
			)
		var invariant_receipt := _sample_invariants(
			step_index,
			telemetry,
			consumer,
			samples,
			child,
			world_3d,
			space_rid,
		)
		samples.append(
			{
				"step_index": step_index,
				"telemetry": _json_value(telemetry),
				"consumer": _json_value(consumer),
				"in_run_invariants": invariant_receipt,
			}
		)
	# Disable at the boundary after solve two and before an unreported solve.
	PhysicsServer3D.set_active(false)
	var all_invariants_passed := (
		samples.size() == 2
		and completed_solver_step_count == RigScript.MAXIMUM_OUTER_SOLVER_STEPS
	)
	for sample in samples:
		all_invariants_passed = (
			all_invariants_passed
			and bool(sample["in_run_invariants"].get("passed", false))
		)
	var report := _physical_report(
		arguments,
		engine,
		description,
		parameter_readback,
		world_binding,
		samples,
		all_invariants_passed,
		pre_sample_physics_frame_count,
		completed_solver_step_count,
	)
	var wrote_report := _write_json_report(report_path, report)
	var ok := bool(report["ok"]) and wrote_report
	var raw_receipt := _physical_raw_receipt(
		arguments,
		ok,
		String(report["status"]),
		"" if ok else "QSDK_R24D158_NATIVE_OBSERVATION_INCOMPLETE",
		1,
		1,
		completed_solver_step_count,
		samples,
		1,
	)
	raw_receipt["report_path"] = report_path
	raw_receipt["report_written"] = wrote_report
	print(RAW_MARKER, JSON.stringify(raw_receipt, "", false, true))
	viewport.queue_free()
	_schedule_quit(0 if ok else 1, "physical_raw")


func _physical_report(
	arguments: Dictionary,
	engine: Dictionary,
	description: Dictionary,
	parameter_readback: Dictionary,
	world_binding: Dictionary,
	samples: Array[Dictionary],
	all_invariants_passed: bool,
	pre_sample_physics_frame_count: int,
	completed_solver_step_count: int,
) -> Dictionary:
	var status := (
		"valid_complete_native_observation_smoke"
		if all_invariants_passed
		else "invalid_or_incomplete_native_observation_smoke"
	)
	var rotation_values: Array = []
	for sample in samples:
		var rotation_value := float(
			sample["consumer"].get(
				"rotation_integration_kinetic_exchange_j",
				NAN,
			)
		)
		rotation_values.append(rotation_value if is_finite(rotation_value) else null)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d158_godot_jolt_rotation_integration_energy_native_observation_report_v1"
		),
		"gate_id": GATE_ID,
		"source_successor_id": SOURCE_SUCCESSOR_ID,
		"question_class": "development",
		"physical_question_kind": "native_observation_smoke",
		"ok": all_invariants_passed,
		"status": status,
		"source_commit": String(arguments["source_commit"]),
		"authorization_sha256": String(arguments["authorization_sha256"]),
		"attempt_id": String(arguments["attempt_id"]),
		"execution_nonce": String(arguments["nonce"]),
		"seed": EXPECTED_SEED,
		"seed_label": EXPECTED_SEED_LABEL,
		"seed_sha256": EXPECTED_SEED_SHA256,
		"held_out": false,
		"engine": engine,
		"fixture": description,
		"parameter_readback": parameter_readback,
		"world_binding": world_binding,
		"samples": samples,
		"rotation_integration_kinetic_exchange_j": rotation_values,
		"execution": {
			"model_construction_attempt_count": 1,
			"model_construction_count": 1,
			"world_attempt_count": 1,
			"world_build_count": 1,
			"solver_step_count": completed_solver_step_count,
			"native_readback_count": samples.size(),
			"in_run_physical_invariant_step_count": samples.size(),
			"all_in_run_physical_invariants_passed": all_invariants_passed,
			"pre_sample_physics_frame_count": pre_sample_physics_frame_count,
			"terminal_physics_server_deactivation_count": 1,
			"physics_tick_rate_configuration_write_count": 1,
			"portable_collection_count": 0,
			"portable_control_plan_count": 0,
			"portable_command_application_count": 0,
			"behavior_evaluator_invocation_count": 0,
			"direct_force_write_count": 0,
			"direct_torque_write_count": 0,
			"direct_impulse_write_count": 0,
			"outcome_dependent_early_stop_count": 0,
		},
		"claims": {
			"native_v6_field_population_observed": all_invariants_passed,
			"rotation_exchange_magnitude_recorded": all_invariants_passed,
			"rotation_exchange_nonzero_required": false,
			"rotation_exchange_nonzero_claimed": false,
			"rotational_staging_cause_established": false,
			"behavior_improvement_established": false,
			"recovery_claimed": false,
			"prone_to_standing_claimed": false,
			"population_inference_claimed": false,
			"cross_engine_equivalence_claimed": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
	}


func _sample_invariants(
	step_index: int,
	telemetry: Dictionary,
	consumer: Dictionary,
	prior_samples: Array[Dictionary],
	child: RigidBody3D,
	world_3d: World3D,
	space_rid: RID,
) -> Dictionary:
	var read_sequence := int(telemetry.get("read_space_step_sequence", -1))
	var previous_read_sequence := (
		int(
			prior_samples[-1]["telemetry"].get(
				"read_space_step_sequence",
				-2,
			)
		)
		if not prior_samples.is_empty()
		else read_sequence - 1
	)
	var checks := {
		"step_index_in_declared_range": step_index >= 1 and step_index <= 2,
		"native_telemetry_present": not telemetry.is_empty(),
		"consumer_accepted": bool(consumer.get("ok", false)),
		"consumer_check_count_exact": int(consumer.get("check_count", -1)) == 38,
		"read_sequence_positive": read_sequence > 0,
		"read_sequence_consecutive": read_sequence == previous_read_sequence + 1,
		"capture_sequence_current": (
			int(telemetry.get("capture_space_step_sequence", -1)) == read_sequence
		),
		"snapshot_current": bool(
			telemetry.get("snapshot_is_current_space_step", false)
		),
		"native_complete": bool(telemetry.get("complete", false)),
		"rotation_partition_complete": bool(
			consumer.get("rotation_integration_partition_complete", false)
		),
		"rotation_value_finite": is_finite(
			float(
				consumer.get("rotation_integration_kinetic_exchange_j", NAN)
			)
		),
		"inserted_child_inside_tree": child.is_inside_tree(),
		"effective_world_binding_stable": child.get_world_3d() == world_3d,
		"space_rid_valid": space_rid.is_valid(),
		"space_rid_binding_stable": world_3d.space == space_rid,
	}
	var passed := true
	for key in checks:
		passed = passed and bool(checks[key])
	return {
		"schema_version": (
			"sporespore_qsdk_r24d158_native_observation_in_run_invariants_v1"
		),
		"passed": passed,
		"check_count": checks.size(),
		"checks": checks,
	}


func _emit_physical_failure(
	arguments: Dictionary,
	code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
	samples: Array,
	terminal_physics_server_deactivation_count: int = 0,
) -> void:
	var report_path := String(arguments.get("report_path", ""))
	var receipt := _physical_raw_receipt(
		arguments,
		false,
		"invalid_or_incomplete_native_observation_smoke",
		code,
		world_attempt_count,
		world_build_count,
		solver_step_count,
		samples,
		terminal_physics_server_deactivation_count,
	)
	if _safe_report_path(report_path) and not FileAccess.file_exists(report_path):
		receipt["report_written"] = _write_json_report(report_path, receipt)
		receipt["report_path"] = report_path
	print(RAW_MARKER, JSON.stringify(receipt, "", false, true))
	_schedule_quit(1, "physical_failure")


func _physical_raw_receipt(
	arguments: Dictionary,
	ok: bool,
	status: String,
	failure_code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
	samples: Array,
	terminal_physics_server_deactivation_count: int = 0,
) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d158_godot_jolt_rotation_integration_energy_physical_raw_v1"
		),
		"gate_id": GATE_ID,
		"source_successor_id": SOURCE_SUCCESSOR_ID,
		"question_class": "development",
		"physical_question_kind": "native_observation_smoke",
		"ok": ok,
		"status": status,
		"failure_code": failure_code,
		"source_commit": String(arguments.get("source_commit", "")),
		"authorization_sha256": String(
			arguments.get("authorization_sha256", "")
		),
		"attempt_id": String(arguments.get("attempt_id", "")),
		"execution_nonce": String(arguments.get("nonce", "")),
		"seed": int(arguments.get("seed", -1)),
		"seed_sha256": String(arguments.get("seed_sha256", "")),
		"model_construction_attempt_count": world_attempt_count,
		"model_construction_count": world_build_count,
		"world_attempt_count": world_attempt_count,
		"world_build_count": world_build_count,
		"solver_step_count": solver_step_count,
		"native_readback_count": samples.size(),
		"in_run_physical_invariant_step_count": samples.size(),
		"all_in_run_physical_invariants_passed": (
			ok and samples.size() == 2
		),
		"terminal_physics_server_deactivation_count": (
			terminal_physics_server_deactivation_count
		),
		"portable_collection_count": 0,
		"portable_control_plan_count": 0,
		"portable_command_application_count": 0,
		"behavior_evaluator_invocation_count": 0,
		"physics_state_modified": world_build_count > 0,
		"native_field_population_observed": ok and samples.size() == 2,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _physical_request_valid(arguments: Dictionary, require_environment: bool) -> bool:
	for key in [
		"mode",
		"source_commit",
		"authorization_sha256",
		"attempt_id",
		"nonce",
		"seed",
		"seed_label",
		"seed_sha256",
		"report_path",
	]:
		if not arguments.has(key):
			return false
	var source_commit := String(arguments["source_commit"])
	var authorization_sha := String(arguments["authorization_sha256"])
	var attempt_id := String(arguments["attempt_id"])
	var nonce := String(arguments["nonce"])
	var report_path := String(arguments["report_path"]).replace("\\", "/")
	var valid := (
		String(arguments["mode"]) == "physical"
		and _is_lower_hex(source_commit, 40)
		and authorization_sha.begins_with("sha256:")
		and _is_lower_hex(authorization_sha.trim_prefix("sha256:"), 64)
		and _is_lower_hex(attempt_id, 32)
		and _is_lower_hex(nonce, 32)
		and int(arguments["seed"]) == EXPECTED_SEED
		and String(arguments["seed_label"]) == EXPECTED_SEED_LABEL
		and String(arguments["seed_sha256"]) == EXPECTED_SEED_SHA256
		and _safe_report_path(report_path)
	)
	if not valid or not require_environment:
		return valid
	return (
		OS.get_environment(SOURCE_COMMIT_ENV) == source_commit
		and OS.get_environment(AUTHORIZATION_SHA_ENV) == authorization_sha
		and OS.get_environment(ATTEMPT_ID_ENV) == attempt_id
		and OS.get_environment(EXECUTION_NONCE_ENV) == nonce
	)


func _synthetic_request() -> Dictionary:
	return {
		"mode": "physical",
		"source_commit": "0123456789abcdef0123456789abcdef01234567",
		"authorization_sha256": (
			"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
		),
		"attempt_id": "0123456789abcdef0123456789abcdef",
		"nonce": "fedcba9876543210fedcba9876543210",
		"seed": EXPECTED_SEED,
		"seed_label": EXPECTED_SEED_LABEL,
		"seed_sha256": EXPECTED_SEED_SHA256,
		"report_path": EVIDENCE_ROOT_PREFIX + "r158-zero-world-never-written.json",
	}


func _safe_report_path(path: String) -> bool:
	var normalized := path.replace("\\", "/")
	return normalized.is_absolute_path() and normalized.begins_with(
		EVIDENCE_ROOT_PREFIX
	)


func _engine_receipt() -> Dictionary:
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
		"thread_model": (
			"separate"
			if bool(
				ProjectSettings.get_setting(
					"physics/3d/run_on_separate_thread",
					false,
				)
			)
			else "single_safe"
		),
		"telemetry_class_registered": ClassDB.class_exists(TELEMETRY_CLASS_NAME),
		"telemetry_method_registered": ClassDB.class_has_method(
			TELEMETRY_CLASS_NAME,
			TELEMETRY_METHOD_NAME,
		),
		"telemetry_schema_version": ConsumerScript.TELEMETRY_SCHEMA_VERSION,
		"telemetry_profile_id": ConsumerScript.TELEMETRY_PROFILE_ID,
	}


func _engine_receipt_is_frozen(engine: Dictionary) -> bool:
	return (
		String(engine.get("physics_engine", "")) == "Jolt Physics"
		and int(engine.get("solver_velocity_steps", -1)) == 20
		and int(engine.get("solver_position_steps", -1)) == 4
		and String(engine.get("thread_model", "")) == "single_safe"
		and bool(engine.get("telemetry_class_registered", false))
		and bool(engine.get("telemetry_method_registered", false))
		and String(engine.get("telemetry_schema_version", ""))
		== ConsumerScript.TELEMETRY_SCHEMA_VERSION
		and String(engine.get("telemetry_profile_id", ""))
		== ConsumerScript.TELEMETRY_PROFILE_ID
	)


func _fixture_description_is_frozen(description: Dictionary) -> bool:
	return (
		String(description.get("fixture_id", "")) == RigScript.FIXTURE_ID
		and int(description.get("world_count", -1)) == 1
		and int(description.get("dynamic_body_count", -1)) == 1
		and int(description.get("static_parent_count", -1)) == 1
		and int(description.get("pin_joint_count", -1)) == 1
		and is_equal_approx(
			float(description.get("child_mass_kg", NAN)),
			RigScript.CHILD_MASS_KG,
		)
		and _array_vector3_matches(
			description.get("child_inertia_diagonal_kg_m2", []),
			Vector3(0.031, 0.047, 0.083),
		)
		and _array_vector3_matches(
			description.get("initial_angular_velocity_world_rad_s", []),
			Vector3(1.25, -0.75, 2.0),
		)
		and bool(description.get("off_principal_axis_rotation", false))
		and int(description.get("maximum_outer_solver_steps", -1)) == 2
		and int(description.get("direct_force_write_count", -1)) == 0
		and int(description.get("direct_torque_write_count", -1)) == 0
		and int(description.get("direct_impulse_write_count", -1)) == 0
		and int(description.get("model_construction_count", -1)) == 0
		and int(description.get("world_attempt_count", -1)) == 0
		and int(description.get("world_build_count", -1)) == 0
		and int(description.get("solver_step_count", -1)) == 0
	)


func _array_vector3_matches(value: Variant, expected: Vector3) -> bool:
	return (
		value is Array
		and value.size() == 3
		and is_equal_approx(float(value[0]), expected.x)
		and is_equal_approx(float(value[1]), expected.y)
		and is_equal_approx(float(value[2]), expected.z)
	)


func _write_json_report(path: String, report: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_json_value(report), "", false, true) + "\n")
	file.close()
	return FileAccess.file_exists(path)


func _json_value(value: Variant) -> Variant:
	if value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Dictionary:
		var mapped := {}
		for key in value:
			mapped[String(key)] = _json_value(value[key])
		return mapped
	if value is Array:
		var mapped: Array = []
		for item in value:
			mapped.append(_json_value(item))
		return mapped
	return value


func _parse_user_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in arguments:
		var separator := argument.find("=")
		if not argument.begins_with("--") or separator <= 2:
			continue
		parsed[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return parsed


func _is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		push_error("QSDK-R24D158 duplicate orderly-exit schedule")
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
			READY_MARKER,
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
				false,
				true,
			),
		)
		return
	quit(_pending_exit_code)
