extends SceneTree
# gdlint: disable=max-line-length

## Prospective zero-world gate for the Godot/Jolt actuator/phase observation.
##
## The test advances one real native-controller step, writes and reads eight
## unparented HingeJoint3D motor parameters through the production adapter, and
## exercises the production trace projection. It never inserts a Node into a
## SceneTree, constructs a physics model, or opens a physical world.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R23D48WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
)

const STAGE_ID := "three_engine_support_loss_conditioned_turning_validation"
const ONSET_ID := "onset_600"
const ARM_ID := "positive_heading"
const SEMANTIC_STEP := 360
const PHASE_OFFSET_ACTIVATION_STEP := 360
const OBSERVATION_SCHEMA := "sporespore_godot_jolt_actuator_phase_observation_v1"
const APPLICATION_SCHEMA := (
	"sporespore_godot_jolt_full_authority_application_receipt_v1"
)
const POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print("SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_PREFLIGHT ", JSON.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var cell: Dictionary = R23D48WorkerScript._r23d48_cell(STAGE_ID, ONSET_ID, ARM_ID)
	if not bool(cell.get("ok", false)):
		return _failure("ACTUATOR_PHASE_CELL_INVALID", cell)
	var prepared: Dictionary = R23D48WorkerScript._r23d48_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _failure("ACTUATOR_PHASE_PREPARATION_INVALID", prepared)
	var adapter: RefCounted = AdapterScript.new()
	var phase_offset := int(
		(prepared["initial_perturbation"] as Dictionary)["gait_phase_offset_ticks"]
	)
	var start: Dictionary = adapter.start(
		prepared["descriptor"],
		{
			"rear_left": 0,
			"front_left": 0,
			"rear_right": 0,
			"front_right": 0,
		},
		0.0,
		Vector3.ZERO,
		Vector3.BACK,
		PI * 0.5,
		120,
		{
			"solver_policy_id": "jolt_120hz_20v_7p_v1",
			"physics_engine": "Jolt Physics",
			"physics_hz": 120,
			"solver_velocity_steps": 20,
			"solver_position_steps": 7,
		},
		2.5e-7,
		"clocked",
		true,
		phase_offset,
		PHASE_OFFSET_ACTIVATION_STEP,
		"post_settle_full",
		"p5i3b_weight_support_shadow_v1",
		prepared["material_profile"],
		POLICY_ID,
	)
	if not bool(start.get("ok", false)):
		return _failure("ACTUATOR_PHASE_ADAPTER_START_INVALID", start)
	var phase_offset_result: Dictionary = adapter._apply_scheduled_phase_offset_if_due(
		SEMANTIC_STEP
	)
	if not bool(phase_offset_result.get("ok", false)):
		return _failure("ACTUATOR_PHASE_OFFSET_INVALID", phase_offset_result)
	var phase_mode_result: Dictionary = adapter._configure_phase_progression_mode(
		"contact_gated"
	)
	if not bool(phase_mode_result.get("ok", false)):
		return _failure("ACTUATOR_PHASE_MODE_INVALID", phase_mode_result)
	var morphology: Dictionary = (
		(adapter.get("_compiled") as Dictionary).get("morphology", {}) as Dictionary
	)
	var state: Dictionary = adapter._perfect_synthetic_controller_state_frame(
		SEMANTIC_STEP,
		morphology,
	)
	var schedule_result: Dictionary = WaveGaitScript.compile_sdk_heading_schedule_options(
		prepared["schedule"]
	)
	if not bool(schedule_result.get("ok", false)):
		return _failure("ACTUATOR_PHASE_SCHEDULE_INVALID", schedule_result)
	var heading_resolution: Dictionary = WaveGaitScript.resolve_sdk_heading_command_options(
		schedule_result["sdk_heading_schedule_options"],
		SEMANTIC_STEP,
	)
	if not bool(heading_resolution.get("ok", false)):
		return _failure("ACTUATOR_PHASE_HEADING_RESOLUTION_INVALID", heading_resolution)
	var heading: Dictionary = adapter.compile_heading_offset_command(
		float(adapter.get("_canonical_initial_heading_rad")),
		SEMANTIC_STEP,
		heading_resolution["heading_command_options"],
	)
	if not bool(heading.get("ok", false)):
		return _failure("ACTUATOR_PHASE_HEADING_COMMAND_INVALID", heading)
	var motion: Dictionary = adapter._perfect_synthetic_motion_command(
		SEMANTIC_STEP,
		"contact_gated",
	)
	motion["command_id"] = String(heading["command_id"])
	motion["desired_heading_rad"] = float(heading["desired_heading_rad"])
	var memory_before: Dictionary = (adapter.get("_memory") as Dictionary).duplicate(true)
	var runtime: Dictionary = adapter.preflight_explicit_balanced_wave_heading_runtime_boundary(
		state,
		motion,
		true,
	)
	if not bool(runtime.get("ok", false)):
		return _failure("ACTUATOR_PHASE_RUNTIME_INVALID", runtime)
	var authority_receipt: Dictionary = runtime.get("authority_receipt", {})
	var step_result: Dictionary = runtime.get("trace_step_result", {})
	var limb_phase: Dictionary = WaveGaitScript._r23d3_limb_phase_projection(memory_before)
	if not bool(limb_phase.get("ok", false)):
		return _failure("ACTUATOR_PHASE_LIMB_PROJECTION_INVALID", limb_phase)
	var contacts_before := {
		"rear_left": true,
		"front_left": false,
		"rear_right": true,
		"front_right": false,
	}
	var contacts_after := {
		"rear_left": true,
		"front_left": true,
		"rear_right": false,
		"front_right": false,
	}
	var observation_result: Dictionary = WaveGaitScript._compose_sdk_actuator_phase_observation(
		{"actuator_phase_observation_schema_version": OBSERVATION_SCHEMA},
		step_result,
		authority_receipt,
		limb_phase,
		contacts_before,
		SEMANTIC_STEP,
	)
	if not bool(observation_result.get("ok", false)):
		return _failure("ACTUATOR_PHASE_COMPOSITION_INVALID", observation_result)
	var row := {
		"semantic_step": SEMANTIC_STEP,
		"ordered_limb_phase_before": (
			(limb_phase["ordered_limb_phase_before"] as Array).duplicate(true)
		),
		"ordered_foot_contacts_before": contacts_before.duplicate(true),
		"ordered_foot_contacts_after": {},
		"actuator_phase_observation": (
			(observation_result["observation"] as Dictionary).duplicate(true)
		),
	}
	var completed: Dictionary = WaveGaitScript.complete_sdk_actuator_phase_observation(
		row,
		contacts_after,
	)
	if not bool(completed.get("ok", false)):
		return _failure("ACTUATOR_PHASE_COMPLETION_INVALID", completed)
	var complete_row: Dictionary = completed["row"]
	var validation: Dictionary = WaveGaitScript.validate_sdk_actuator_phase_observation(
		complete_row
	)
	if not bool(validation.get("ok", false)):
		return _failure("ACTUATOR_PHASE_VALIDATION_INVALID", validation)

	var trace_request: Dictionary = (prepared["trace_options"] as Dictionary).duplicate(true)
	trace_request.erase("enabled")
	trace_request["actuator_phase_observation_schema_version"] = OBSERVATION_SCHEMA
	var compiled_trace: Dictionary = WaveGaitScript.compile_sdk_physical_trace_options(trace_request)
	var wrong_schema_request := trace_request.duplicate(true)
	wrong_schema_request["actuator_phase_observation_schema_version"] = (
		"sporespore_godot_jolt_actuator_phase_observation_v0"
	)
	var wrong_schema: Dictionary = WaveGaitScript.compile_sdk_physical_trace_options(
		wrong_schema_request
	)

	var receipt_order_mutation := authority_receipt.duplicate(true)
	var receipt_order_rows: Array = receipt_order_mutation["ordered_applications"]
	var first_receipt_row: Variant = receipt_order_rows[0]
	receipt_order_rows[0] = receipt_order_rows[1]
	receipt_order_rows[1] = first_receipt_row
	var receipt_order_rejection: Dictionary = WaveGaitScript._compose_sdk_actuator_phase_observation(
		{"actuator_phase_observation_schema_version": OBSERVATION_SCHEMA},
		step_result,
		receipt_order_mutation,
		limb_phase,
		contacts_before,
		SEMANTIC_STEP,
	)
	var receipt_impulse_mutation := authority_receipt.duplicate(true)
	var receipt_impulse_rows: Array = receipt_impulse_mutation["ordered_applications"]
	(receipt_impulse_rows[0] as Dictionary)["motor_maximum_impulse_readback_nms"] = (
		float((receipt_impulse_rows[0] as Dictionary)["motor_maximum_impulse_readback_nms"])
		+ 0.001
	)
	var receipt_impulse_rejection: Dictionary = WaveGaitScript._compose_sdk_actuator_phase_observation(
		{"actuator_phase_observation_schema_version": OBSERVATION_SCHEMA},
		step_result,
		receipt_impulse_mutation,
		limb_phase,
		contacts_before,
		SEMANTIC_STEP,
	)

	var mutation_rejections := [
		_mutation_rejected(complete_row, "target_readback"),
		_mutation_rejected(complete_row, "impulse_readback"),
		_mutation_rejected(complete_row, "actuator_order"),
		_mutation_rejected(complete_row, "phase"),
		_mutation_rejected(complete_row, "contact_before"),
		_mutation_rejected(complete_row, "contact_after"),
		_mutation_rejected(complete_row, "limb_identity"),
	]
	var applications: Array = authority_receipt.get("ordered_applications", [])
	var all_mutations_rejected := true
	for rejected in mutation_rejections:
		all_mutations_rejected = all_mutations_rejected and bool(rejected)
	var exact := (
		String(authority_receipt.get("schema_version", "")) == APPLICATION_SCHEMA
		and applications.size() == 8
		and int(authority_receipt.get("applied_command_count", -1)) == 8
		and float(authority_receipt.get("maximum_target_velocity_readback_error_rad_s", INF))
		<= float(authority_receipt.get("readback_tolerance", -1.0))
		and float(authority_receipt.get("maximum_impulse_readback_error_nms", INF))
		<= float(authority_receipt.get("readback_tolerance", -1.0))
		and bool(authority_receipt.get("configured_motor_parameters_only", false))
		and not bool(authority_receipt.get("measured_motor_torque_available", true))
		and not bool(authority_receipt.get("measured_motor_impulse_available", true))
		and int(validation.get("validated_application_count", -1)) == 8
		and int(validation.get("validated_limb_count", -1)) == 4
		and bool(compiled_trace.get("ok", false))
		and not bool(wrong_schema.get("ok", true))
		and not bool(receipt_order_rejection.get("ok", true))
		and not bool(receipt_impulse_rejection.get("ok", true))
		and all_mutations_rejected
		and int(runtime.get("host_object_creation_count", -1)) == 8
		and int(runtime.get("scene_tree_insertion_count", -1)) == 0
		and int(runtime.get("world_attempt_count", -1)) == 0
		and int(runtime.get("world_build_count", -1)) == 0
		and not bool(runtime.get("physics_state_modified", true))
	)
	return {
		"schema_version": "sporespore_godot_actuator_phase_observation_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "ACTUATOR_PHASE_PREFLIGHT_INVALID",
		"runtime_api_version": Engine.get_version_info().get("string", ""),
		"application_receipt_schema_version": String(
			authority_receipt.get("schema_version", "")
		),
		"observation_schema_version": OBSERVATION_SCHEMA,
		"validated_application_count": int(
			validation.get("validated_application_count", -1)
		),
		"validated_limb_count": int(validation.get("validated_limb_count", -1)),
		"production_receipt_mutation_rejection_count": 2,
		"retained_row_mutation_rejection_count": mutation_rejections.size(),
		"wrong_schema_rejected": not bool(wrong_schema.get("ok", true)),
		"maximum_target_velocity_readback_error_rad_s": float(
			authority_receipt.get("maximum_target_velocity_readback_error_rad_s", INF)
		),
		"maximum_impulse_readback_error_nms": float(
			authority_receipt.get("maximum_impulse_readback_error_nms", INF)
		),
		"configured_motor_parameters_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"host_object_creation_count": int(runtime.get("host_object_creation_count", -1)),
		"scene_tree_insertion_count": int(runtime.get("scene_tree_insertion_count", -1)),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _mutation_rejected(source: Dictionary, mutation_id: String) -> bool:
	var mutated := source.duplicate(true)
	var observation: Dictionary = mutated["actuator_phase_observation"]
	var applications: Array = observation["ordered_applications"]
	match mutation_id:
		"target_readback":
			(applications[0] as Dictionary)["motor_target_velocity_readback_rad_s"] = (
				float((applications[0] as Dictionary)["motor_target_velocity_readback_rad_s"])
				+ 0.001
			)
		"impulse_readback":
			(applications[0] as Dictionary)["motor_maximum_impulse_readback_nms"] = (
				float((applications[0] as Dictionary)["motor_maximum_impulse_readback_nms"])
				+ 0.001
			)
		"actuator_order":
			var first: Variant = applications[0]
			applications[0] = applications[1]
			applications[1] = first
		"phase":
			var phase_rows: Array = mutated["ordered_limb_phase_before"]
			(phase_rows[0] as Dictionary)["local_phase_step"] = (
				int((phase_rows[0] as Dictionary)["local_phase_step"]) + 1
			)
		"contact_before":
			var limb_id := String((applications[0] as Dictionary)["limb_id"])
			var contacts: Dictionary = mutated["ordered_foot_contacts_before"]
			contacts[limb_id] = not bool(contacts[limb_id])
		"contact_after":
			var limb_id := String((applications[0] as Dictionary)["limb_id"])
			var contacts: Dictionary = mutated["ordered_foot_contacts_after"]
			contacts[limb_id] = not bool(contacts[limb_id])
		"limb_identity":
			(applications[0] as Dictionary)["limb_id"] = "not_a_declared_limb"
		_:
			return false
	observation["ordered_applications"] = applications
	mutated["actuator_phase_observation"] = observation
	return not bool(
		WaveGaitScript.validate_sdk_actuator_phase_observation(mutated).get("ok", true)
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_godot_actuator_phase_observation_preflight_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"configured_motor_parameters_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
