extends SceneTree

## Development-only zero-world diagnostic for the R23D34 Godot trace gap.
##
## Unlike the R23D34 hand-built row canary, this test sends the exact native
## R23D29 JSON output and the exact adapter request representation through the
## production trace composer. It creates no Nodes and opens no physics world.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R23D34WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d34_godot_jolt_physical_worker.gd"
)

const POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const STAGE_ID := "native_r23d29_implementation_repair_transfer"
const ONSET_ID := "onset_600"
const ARM_ID := "positive_heading"
const CONTROLLER_STEPS := 2992
const PHASE_OFFSET_ACTIVATION_STEP := 360
const CONTACT_GATED_START_STEP := 472
const CONTACT_GATED_END_STEP := 2632


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _diagnose()
	print("QSDK_R23D35_TRACE_COMPOSITION_DIAGNOSTIC ", JSON.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _diagnose(arm_id: String = ARM_ID) -> Dictionary:
	var cell := R23D34WorkerScript._r23d34_cell(STAGE_ID, ONSET_ID, arm_id)
	if not bool(cell.get("ok", false)):
		return cell
	var prepared := R23D34WorkerScript._r23d34_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
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
		return start
	var morphology: Dictionary = (
		(adapter.get("_compiled") as Dictionary).get("morphology", {}) as Dictionary
	)
	var schedule_result := WaveGaitScript.compile_sdk_heading_schedule_options(
		prepared["schedule"]
	)
	if not bool(schedule_result.get("ok", false)):
		return schedule_result
	var schedule: Dictionary = schedule_result["sdk_heading_schedule_options"]
	var contacts := {
		"rear_left": true,
		"front_left": true,
		"rear_right": true,
		"front_right": true,
	}
	var profile: Dictionary = (
		(start.get("adapter_manifest", {}) as Dictionary).get(
			"controller_profile",
			{},
		) as Dictionary
	)
	var segment_counts := {
		"reference_warmup": 0,
		"commanded_turn": 0,
		"reference_recovery": 0,
		"after_declared_schedule": 0,
	}
	var previous_mode := ""
	var phase_mode_transition_count := 0
	var row_count := 0
	var native_command_count := 0
	var release_hold_variant_type := ""
	var gait_step_variant_type := ""
	var fractional: Dictionary = {}
	for semantic_step in range(CONTROLLER_STEPS):
		var phase_result: Dictionary = adapter._apply_scheduled_phase_offset_if_due(
			semantic_step
		)
		if not bool(phase_result.get("ok", false)):
			return _failure("QSDK_R23D35_PHASE_TRANSITION_INVALID", semantic_step, phase_result)
		var phase_mode := (
			"contact_gated"
			if (
				semantic_step >= CONTACT_GATED_START_STEP
				and semantic_step < CONTACT_GATED_END_STEP
			)
			else "clocked"
		)
		if phase_mode != previous_mode:
			var mode_result: Dictionary = adapter._configure_phase_progression_mode(
				phase_mode
			)
			if not bool(mode_result.get("ok", false)):
				return _failure("QSDK_R23D35_PHASE_MODE_INVALID", semantic_step, mode_result)
			previous_mode = phase_mode
			phase_mode_transition_count += 1
		var state: Dictionary = adapter._perfect_synthetic_controller_state_frame(
			semantic_step,
			morphology,
		)
		var heading_resolution := WaveGaitScript.resolve_sdk_heading_command_options(
			schedule,
			semantic_step,
		)
		if not bool(heading_resolution.get("ok", false)):
			return _failure(
				"QSDK_R23D35_HEADING_RESOLUTION_INVALID",
				semantic_step,
				heading_resolution,
			)
		var heading: Dictionary = adapter.compile_heading_offset_command(
			float(adapter.get("_canonical_initial_heading_rad")),
			semantic_step,
			heading_resolution["heading_command_options"],
		)
		if not bool(heading.get("ok", false)):
			return _failure("QSDK_R23D35_HEADING_COMMAND_INVALID", semantic_step, heading)
		var motion: Dictionary = adapter._perfect_synthetic_motion_command(
			semantic_step,
			phase_mode,
		)
		motion["command_id"] = String(heading["command_id"])
		motion["desired_heading_rad"] = float(heading["desired_heading_rad"])
		var memory: Dictionary = (adapter.get("_memory") as Dictionary).duplicate(true)
		var request: Dictionary = adapter._controller_step_request(memory, state, motion)
		var sample := {
			"ok": true,
			"request": request,
			"heading_command_receipt": (heading["receipt"] as Dictionary).duplicate(true),
		}
		var first_memory: Dictionary = (
			(request["memory"] as Dictionary)["ordered_limb_memory"][0]
		)
		if semantic_step == PHASE_OFFSET_ACTIVATION_STEP:
			gait_step_variant_type = type_string(typeof(first_memory.get("gait_step")))
			release_hold_variant_type = type_string(
				typeof(first_memory.get("release_hold_step_count"))
			)
		var envelope: Dictionary = adapter._call_input(
			adapter._controller_step_method(),
			request,
		)
		if not bool(envelope.get("ok", false)):
			return _failure("QSDK_R23D35_NATIVE_STEP_INVALID", semantic_step, envelope)
		var output: Dictionary = envelope.get("value", {})
		var step_result: Dictionary = adapter._finish_balanced_wave_shadow_step(
			output,
			semantic_step,
			sample,
		)
		if not bool(step_result.get("ok", false)):
			return _failure(
				"QSDK_R23D35_PRODUCTION_VALIDATOR_INVALID",
				semantic_step,
				step_result,
			)
		var commands: Array = (
			((step_result["native_output"] as Dictionary)["actuation"] as Dictionary)[
				"ordered_commands"
			]
		)
		var application := {
			"ok": true,
			"semantic_step": semantic_step,
			"applied_command_count": commands.size(),
		}
		var composed := WaveGaitScript._compose_sdk_physical_trace_row(
			prepared["trace_options"],
			sample,
			step_result,
			application,
			semantic_step,
			contacts,
			0.0,
			false,
			profile,
		)
		if not bool(composed.get("ok", false)):
			return _failure(
				"QSDK_R23D35_TRACE_COMPOSITION_INVALID",
				semantic_step,
				composed,
			)
		var row: Dictionary = composed["row"]
		var segment_id := String(row.get("segment_id", ""))
		if not segment_counts.has(segment_id):
			return _failure("QSDK_R23D35_TRACE_SEGMENT_INVALID", semantic_step, row)
		segment_counts[segment_id] = int(segment_counts[segment_id]) + 1
		row_count += 1
		native_command_count += commands.size()
		if semantic_step == PHASE_OFFSET_ACTIVATION_STEP:
			var fractional_sample: Dictionary = sample.duplicate(true)
			var fractional_memory: Dictionary = (
				(fractional_sample["request"] as Dictionary)["memory"] as Dictionary
			)
			var fractional_rows: Array = fractional_memory["ordered_limb_memory"]
			(fractional_rows[0] as Dictionary)["release_hold_step_count"] = 0.5
			fractional = WaveGaitScript._compose_sdk_physical_trace_row(
				prepared["trace_options"],
				fractional_sample,
				step_result,
				application,
				semantic_step,
				contacts,
				0.0,
				false,
				profile,
			)
	var fractional_rejected := (
		not bool(fractional.get("ok", true))
		and String(fractional.get("failure_code", ""))
		== "SDK_PHYSICAL_TRACE_LIMB_MEMORY_VALUE_INVALID"
	)
	var exact := (
		row_count == CONTROLLER_STEPS
		and native_command_count == CONTROLLER_STEPS * 8
		and phase_mode_transition_count == 3
		and segment_counts == {
			"reference_warmup": 600,
			"commanded_turn": 1200,
			"reference_recovery": 600,
			"after_declared_schedule": 592,
		}
		and gait_step_variant_type == "int"
		and release_hold_variant_type == "float"
		and fractional_rejected
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R23D35_TRACE_HORIZON_INVALID",
		"arm_id": arm_id,
		"controller_step_count": CONTROLLER_STEPS,
		"trace_row_count": row_count,
		"native_controller_command_count": native_command_count,
		"phase_mode_transition_count": phase_mode_transition_count,
		"segment_counts": segment_counts,
		"fractional_counter_rejection": fractional,
		"gait_step_variant_type": gait_step_variant_type,
		"release_hold_variant_type": release_hold_variant_type,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _failure(code: String, semantic_step: int, detail: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"failing_semantic_step": semantic_step,
		"detail": detail.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
