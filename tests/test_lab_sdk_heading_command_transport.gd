extends SceneTree
# gdlint: disable=max-line-length

## Zero-world regression for the Godot/Jolt absolute-heading transport.
##
## The generic physical runner compiles the same schedule used by R23D1, the
## adapter resolves each segment against the task-frame reference heading, and
## the real BW5R-B native controller produces signed steering receipts. No node
## is inserted and no physics world is constructed.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const CONTRACT_PATH := "res://sdk/turning/physical_development_contract_v1.json"
const POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const STABILITY_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const PHYSICS_HZ := 120
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const GAIT_STEPS := {
	"front_left": 0,
	"front_right": 0,
	"rear_left": 0,
	"rear_right": 0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt heading-command transport ===")
	var root_child_count_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	var contract := _read_json(CONTRACT_PATH)
	var descriptor: Dictionary = (
		(contract.get("fixture", {}) as Dictionary).get("descriptor", {}) as Dictionary
	).duplicate(true)
	var positive_schedule := _schedule(0.2)
	var compiled := WaveGaitScript.compile_sdk_heading_schedule_options(positive_schedule)
	_check(
		(
			bool(compiled.get("ok", false))
			and int(compiled.get("world_build_count", -1)) == 0
			and String(compiled.get("sdk_heading_schedule_sha256", "")).begins_with("sha256:")
		),
		"1 exact R23D1 heading schedule compiles before any world",
	)
	var compiled_schedule: Dictionary = compiled.get("sdk_heading_schedule_options", {})
	var expected_boundaries := {
		0: ["reference_warmup", 0.0],
		599: ["reference_warmup", 0.0],
		600: ["commanded_turn", 0.2],
		1799: ["commanded_turn", 0.2],
		1800: ["reference_recovery", 0.0],
		2399: ["reference_recovery", 0.0],
		2400: ["reference_continuation", 0.0],
	}
	var boundaries_exact := true
	for step_value in expected_boundaries:
		var resolved := WaveGaitScript.resolve_sdk_heading_command_options(
			compiled_schedule,
			int(step_value),
		)
		var options: Dictionary = resolved.get("heading_command_options", {})
		var expected: Array = expected_boundaries[step_value]
		boundaries_exact = (
			boundaries_exact
			and bool(resolved.get("ok", false))
			and String(options.get("segment_id", "")) == String(expected[0])
			and absf(float(options.get("heading_offset_rad", NAN)) - float(expected[1]))
			<= 1.0e-15
		)
	_check(boundaries_exact, "2 all seven schedule boundaries resolve exactly")

	var invalid_schedule := positive_schedule.duplicate(true)
	var invalid_segments: Array = invalid_schedule["segments"]
	var invalid_turn_segment: Dictionary = (
		(invalid_segments[1] as Dictionary).duplicate(true)
	)
	invalid_turn_segment["start_step_inclusive"] = 601
	invalid_segments[1] = invalid_turn_segment
	var invalid_compiled := WaveGaitScript.compile_sdk_heading_schedule_options(invalid_schedule)
	_check(
		(
			not bool(invalid_compiled.get("ok", false))
			and String(invalid_compiled.get("failure_code", ""))
			== "INVALID_SDK_HEADING_SEGMENT_VALUE"
			and int(invalid_compiled.get("world_build_count", -1)) == 0
		),
		"3 a schedule gap fails closed before any world",
	)

	var positive_resolution := WaveGaitScript.resolve_sdk_heading_command_options(
		compiled_schedule,
		600,
	)
	var positive_command: Dictionary = positive_resolution.get("heading_command_options", {})
	var direct := AdapterScript.compile_heading_offset_command(3.05, 600, positive_command)
	_check(
		(
			bool(direct.get("ok", false))
			and float(direct.get("desired_heading_rad", INF)) < -3.0
			and absf(
				float((direct.get("receipt", {}) as Dictionary).get("heading_offset_rad", NAN))
				- 0.2
			) <= 1.0e-15
		),
		"4 adapter resolves absolute heading with shortest-arc wrapping",
	)

	var responses: Dictionary = {}
	for arm_id in ["reference_zero", "positive_heading", "negative_heading"]:
		var offset := 0.0
		if arm_id == "positive_heading":
			offset = 0.2
		elif arm_id == "negative_heading":
			offset = -0.2
		responses[arm_id] = _native_response(descriptor, offset)
	var native_exact := true
	for response_value in responses.values():
		var response: Dictionary = response_value
		var validation: Dictionary = response.get(
			"balanced_wave_command_validation_receipt",
			{},
		)
		native_exact = (
			native_exact
			and bool(response.get("ok", false))
			and int(response.get("actual_world_build_count", -1)) == 0
			and not bool(response.get("physical_acceptance_authority", true))
			and String(validation.get("schema_version", ""))
			== "sporespore_balanced_wave_command_validation_receipt_v1"
			and bool(validation.get("ok", false))
			and bool(validation.get("enabled", false))
			and String(validation.get("validation_mode", ""))
			== "native_balanced_wave_structure_and_receipts_v1"
			and bool(validation.get("heading_command_conditioned", false))
			and not bool(validation.get("legacy_command_parity_applicable", true))
			and not bool(validation.get("legacy_command_parity_checked", true))
			and not bool(validation.get("legacy_command_parity_waived", true))
		)
	_check(
		native_exact,
		"5 all three arms cross the explicit BW5R-B native validator at zero worlds",
	)
	var zero_controller: Dictionary = (responses["reference_zero"] as Dictionary).get(
		"controller_heading_receipt", {}
	)
	var positive_controller: Dictionary = (responses["positive_heading"] as Dictionary).get(
		"controller_heading_receipt", {}
	)
	var negative_controller: Dictionary = (responses["negative_heading"] as Dictionary).get(
		"controller_heading_receipt", {}
	)
	_check(
		(
			absf(float(zero_controller.get("held_steering_fraction", NAN))) <= 1.0e-15
			and float(positive_controller.get("held_steering_fraction", NAN)) < 0.0
			and float(negative_controller.get("held_steering_fraction", NAN)) > 0.0
		),
		"6 zero and signed heading commands produce the declared steering signs",
	)

	var malformed := positive_command.duplicate(true)
	malformed["undeclared"] = true
	var malformed_result := AdapterScript.compile_heading_offset_command(0.0, 600, malformed)
	var invalid_reference_role := positive_command.duplicate(true)
	invalid_reference_role["command_role"] = "reference_heading"
	var invalid_reference_result := AdapterScript.compile_heading_offset_command(
		0.0,
		600,
		invalid_reference_role,
	)
	_check(
		(
			not bool(malformed_result.get("ok", false))
			and String(malformed_result.get("failure_code", ""))
			== "ADAPTER_HEADING_COMMAND_KEYS_INVALID"
			and int(malformed_result.get("world_build_count", -1)) == 0
			and not bool(invalid_reference_result.get("ok", false))
			and String(invalid_reference_result.get("failure_code", ""))
			== "ADAPTER_HEADING_COMMAND_VALUE_INVALID"
			and int(invalid_reference_result.get("world_build_count", -1)) == 0
		),
		"7 undeclared fields and a nonzero reference role fail closed",
	)
	_check(
		root.get_child_count() == root_child_count_before,
		"8 the complete transport test inserts no scene node",
	)
	Engine.physics_ticks_per_second = physics_hz_before
	_finish()


func _native_response(descriptor: Dictionary, offset: float) -> Dictionary:
	var profile_result := MaterialProfilesScript.resolve(MATERIAL_PROFILE_ID)
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = adapter.start(
		descriptor,
		GAIT_STEPS,
		0.0,
		Vector3.ZERO,
		Vector3.BACK,
		PI * 0.5,
		PHYSICS_HZ,
		SOLVER_POLICY,
		2.5e-7,
		"clocked",
		true,
		0,
		0,
		"post_settle_full",
		STABILITY_POLICY_ID,
		profile_result["profile"],
		POLICY_ID,
	)
	if not bool(start.get("ok", false)):
		return start
	var command := {
		"schema_version": "sporespore_heading_offset_command_v1",
		"schedule_id": "qsdk_r23d1_step_turn_return_v1",
		"segment_id": "commanded_turn",
		"command_role": "turn_heading",
		"heading_offset_rad": offset,
	}
	if offset == 0.0:
		command["segment_id"] = "reference_warmup"
		command["command_role"] = "reference_heading"
	return adapter.preflight_perfect_declared_policy_runtime_boundary(command)


static func _schedule(turn_offset_rad: float) -> Dictionary:
	return {
		"schema_version": "sporespore_heading_offset_schedule_v1",
		"schedule_id": "qsdk_r23d1_step_turn_return_v1",
		"domain": "controller_semantic_step",
		"reference_heading_source": "state.task_frame.reference_yaw_rad",
		"segments":
		[
			{
				"segment_id": "reference_warmup",
				"start_step_inclusive": 0,
				"end_step_exclusive": 600,
				"heading_offset_rad": 0.0,
				"command_role": "reference_heading",
			},
			{
				"segment_id": "commanded_turn",
				"start_step_inclusive": 600,
				"end_step_exclusive": 1800,
				"heading_offset_rad": turn_offset_rad,
				"command_role": "turn_heading",
			},
			{
				"segment_id": "reference_recovery",
				"start_step_inclusive": 1800,
				"end_step_exclusive": 2400,
				"heading_offset_rad": 0.0,
				"command_role": "reference_heading",
			},
		],
		"after_last_segment": "hold_reference_heading",
	}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % message)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
