extends SceneTree

## Zero-world conformance for the warmup-preserving command-onset origin policy.
## This script never constructs a model, fixture, body, or physics world.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const RunnerScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)

const POLICY_ID := "warmup_preserving_command_onset_origin_reanchor_v1"
const R52_POLICY_ID := "heading_segment_origin_reanchor_v1"
const FIXED_POLICY_ID := "fixed_initial_origin_v1"
const SCHEDULE_ID := "r23d53_warmup_preserving_origin_schedule_v1"

var _assertion_count := 0


func _initialize() -> void:
	var result := _run_zero_world_gate()
	if not bool(result.get("ok", false)):
		push_error(JSON.stringify(result))
		print("QSDK_R23D53_TASK_FRAME_ORIGIN_FAILURE ", JSON.stringify(result))
		quit(1)
		return
	print("QSDK_R23D53_TASK_FRAME_ORIGIN_PASS ", JSON.stringify(result))
	quit(0)


func _run_zero_world_gate() -> Dictionary:
	var initial_origin := Vector3(1.0, 2.0, 3.0)
	var warmup_observation := Vector3(10.0, 0.4, 20.0)
	var warmup_command := _command("reference_warmup", "reference_heading", 0.0)
	var fixed := AdapterScript.resolve_task_frame_origin_policy_step(
		FIXED_POLICY_ID,
		initial_origin,
		"",
		"",
		0,
		warmup_observation,
		{},
	)
	_check(bool(fixed.get("ok", false)), "fixed policy must compile")
	_check(
		(fixed.get("origin_world_m", Vector3.INF) as Vector3) == initial_origin,
		"fixed policy must preserve its initial origin",
	)
	_check(not bool(fixed.get("reanchored_this_step", true)), "fixed policy relatch")

	var first := AdapterScript.resolve_task_frame_origin_policy_step(
		POLICY_ID,
		initial_origin,
		"",
		"",
		0,
		warmup_observation,
		warmup_command,
	)
	_check(bool(first.get("ok", false)), "initial segment must compile")
	_check(
		not bool(first.get("reanchored_this_step", true)),
		"initial segment must bind without reanchoring",
	)
	_check(int(first.get("reanchor_count", -1)) == 0, "initial bind count")
	_check(
		(first.get("origin_world_m", Vector3.INF) as Vector3) == initial_origin,
		"initial segment must preserve the fixed origin",
	)
	_check(
		String(first.get("active_schedule_id", "")) == SCHEDULE_ID
		and String(first.get("active_segment_id", "")) == "reference_warmup",
		"initial segment identity must bind",
	)
	_check(
		(first.get("origin_world_m", Vector3.INF) as Vector3)
		== (fixed.get("origin_world_m", Vector3.INF) as Vector3),
		"warmup task origin must equal fixed-policy projection",
	)

	var r52_first := AdapterScript.resolve_task_frame_origin_policy_step(
		R52_POLICY_ID,
		initial_origin,
		"",
		"",
		0,
		warmup_observation,
		warmup_command,
	)
	_check(bool(r52_first.get("ok", false)), "R52 comparison policy must compile")
	_check(
		bool(r52_first.get("reanchored_this_step", false))
		and int(r52_first.get("reanchor_count", -1)) == 1
		and (r52_first.get("origin_world_m", Vector3.INF) as Vector3)
		== warmup_observation,
		"R52 policy must retain its historical initial latch semantics",
	)

	var held := AdapterScript.resolve_task_frame_origin_policy_step(
		POLICY_ID,
		first["origin_world_m"],
		String(first["active_schedule_id"]),
		String(first["active_segment_id"]),
		int(first["reanchor_count"]),
		Vector3(11.0, 0.5, 21.0),
		warmup_command,
	)
	_check(bool(held.get("ok", false)), "same warmup segment must compile")
	_check(not bool(held.get("reanchored_this_step", true)), "warmup relatch")
	_check(int(held.get("reanchor_count", -1)) == 0, "warmup held count")
	_check(
		(held.get("origin_world_m", Vector3.INF) as Vector3) == initial_origin,
		"complete warmup must preserve initial origin",
	)

	var turn_command := _command("commanded_turn", "turn_heading", 0.2)
	var turn_observation := Vector3(12.0, 0.6, 22.0)
	var turn := AdapterScript.resolve_task_frame_origin_policy_step(
		POLICY_ID,
		held["origin_world_m"],
		String(held["active_schedule_id"]),
		String(held["active_segment_id"]),
		int(held["reanchor_count"]),
		turn_observation,
		turn_command,
	)
	_check(bool(turn.get("ok", false)), "turn segment must compile")
	_check(bool(turn.get("reanchored_this_step", false)), "turn onset must reanchor")
	_check(int(turn.get("reanchor_count", -1)) == 1, "turn onset count")
	_check(
		(turn.get("origin_world_m", Vector3.INF) as Vector3) == turn_observation,
		"turn onset must use transition observation",
	)

	var recovery_command := _command(
		"reference_recovery",
		"reference_heading",
		0.0,
	)
	var recovery_observation := Vector3(13.0, 0.7, 23.0)
	var recovery := AdapterScript.resolve_task_frame_origin_policy_step(
		POLICY_ID,
		turn["origin_world_m"],
		String(turn["active_schedule_id"]),
		String(turn["active_segment_id"]),
		int(turn["reanchor_count"]),
		recovery_observation,
		recovery_command,
	)
	_check(bool(recovery.get("ok", false)), "recovery segment must compile")
	_check(
		bool(recovery.get("reanchored_this_step", false))
		and int(recovery.get("reanchor_count", -1)) == 2
		and (recovery.get("origin_world_m", Vector3.INF) as Vector3)
		== recovery_observation,
		"recovery transition must be the second reanchor",
	)

	var missing_command := AdapterScript.resolve_task_frame_origin_policy_step(
		POLICY_ID,
		Vector3.ZERO,
		"",
		"",
		0,
		Vector3.ZERO,
		{},
	)
	_check(not bool(missing_command.get("ok", true)), "missing command must fail")
	_check(
		String(missing_command.get("failure_code", ""))
		== "ADAPTER_TASK_FRAME_ORIGIN_HEADING_COMMAND_REQUIRED",
		"missing command failure identity",
	)
	var invalid_command := warmup_command.duplicate(true)
	invalid_command["schema_version"] = "mutated"
	var invalid := AdapterScript.resolve_task_frame_origin_policy_step(
		POLICY_ID,
		Vector3.ZERO,
		"",
		"",
		0,
		Vector3.ZERO,
		invalid_command,
	)
	_check(not bool(invalid.get("ok", true)), "invalid command must fail")

	var authority_options := {
		"enabled": true,
		"descriptor": {"schema_version": "zero_world_nonempty_descriptor"},
		"comparison_tolerance": 2.5e-7,
		"authority_scope": "post_settle_full",
		"stability_policy_id": "p5i3b_weight_support_shadow_v1",
		"material_profile_id": "r23d3_rapier_transfer_material_v1",
		"controller_policy_id": (
			"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
			+ "stability_guarded_steering_v1"
		),
		"task_frame_origin_policy_id": POLICY_ID,
	}
	var normalized := RunnerScript._normalize_sdk_authority_options(authority_options)
	_check(bool(normalized.get("ok", false)), "runner must accept declared policy")
	_check(
		String(
			(normalized.get("sdk_authority_options", {}) as Dictionary).get(
				"task_frame_origin_policy_id",
				"",
			)
		) == POLICY_ID,
		"runner must preserve declared policy",
	)
	var key_mutation := authority_options.duplicate(true)
	key_mutation.erase("task_frame_origin_policy_id")
	key_mutation["unknown_origin_policy"] = POLICY_ID
	var rejected_keys := RunnerScript._normalize_sdk_authority_options(key_mutation)
	_check(not bool(rejected_keys.get("ok", true)), "unknown key mutation must fail")
	var value_mutation := authority_options.duplicate(true)
	value_mutation["task_frame_origin_policy_id"] = "mutated"
	var rejected_value := RunnerScript._normalize_sdk_authority_options(value_mutation)
	_check(not bool(rejected_value.get("ok", true)), "unknown policy must fail")

	var first_receipt: Dictionary = (first["receipt"] as Dictionary).duplicate(true)
	var first_frame := {"origin_world_m": first_receipt["origin_world_m"]}
	var warmup_heading_receipt := {
		"schedule_id": SCHEDULE_ID,
		"segment_id": "reference_warmup",
	}
	var first_projection := RunnerScript._task_frame_origin_trace_projection(
		first_receipt,
		first_frame,
		warmup_heading_receipt,
	)
	_check(
		bool(first_projection.get("ok", false)),
		"trace projection must accept zero-count initial binding",
	)
	_check(
		not bool(first_projection.get("task_frame_origin_reanchored_this_step", true))
		and int(first_projection.get("task_frame_origin_reanchor_count", -1)) == 0,
		"trace projection must retain initial no-reanchor witness",
	)

	var receipt: Dictionary = (turn["receipt"] as Dictionary).duplicate(true)
	var task_frame := {"origin_world_m": receipt["origin_world_m"]}
	var heading_receipt := {
		"schedule_id": SCHEDULE_ID,
		"segment_id": "commanded_turn",
	}
	var projection := RunnerScript._task_frame_origin_trace_projection(
		receipt,
		task_frame,
		heading_receipt,
	)
	_check(bool(projection.get("ok", false)), "turn trace projection must accept receipt")
	_check(
		bool(projection.get("task_frame_origin_reanchored_this_step", false))
		and int(projection.get("task_frame_origin_reanchor_count", -1)) == 1,
		"turn trace projection must preserve first reanchor",
	)
	var origin_mutation := receipt.duplicate(true)
	(origin_mutation["origin_world_m"] as Dictionary)["x"] = 999.0
	var rejected_origin := RunnerScript._task_frame_origin_trace_projection(
		origin_mutation,
		task_frame,
		heading_receipt,
	)
	_check(not bool(rejected_origin.get("ok", true)), "origin mutation must fail")
	var count_mutation := first_receipt.duplicate(true)
	count_mutation["reanchor_count"] = -1
	var rejected_count := RunnerScript._task_frame_origin_trace_projection(
		count_mutation,
		first_frame,
		warmup_heading_receipt,
	)
	_check(not bool(rejected_count.get("ok", true)), "negative count must fail")

	return {
		"schema_version": "sporespore_qsdk_r23d53_task_frame_origin_preflight_v1",
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"initial_origin_preserved": true,
		"initial_reanchor_count": 0,
		"turn_onset_reanchor_count": 1,
		"assertion_count": _assertion_count,
		"rejected_mutation_count": 6,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func _command(segment_id: String, role: String, offset: float) -> Dictionary:
	return {
		"schema_version": "sporespore_heading_offset_command_v1",
		"schedule_id": SCHEDULE_ID,
		"segment_id": segment_id,
		"command_role": role,
		"heading_offset_rad": offset,
	}


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		push_error(message)
		assert(condition, message)
