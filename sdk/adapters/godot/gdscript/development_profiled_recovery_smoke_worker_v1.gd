extends "res://sdk/adapters/godot/gdscript/development_recovery_smoke_worker_v1.gd"

## Opt-in timing wrappers call the same production methods once, unchanged.
const CostProfiler := preload(
	"res://sdk/adapters/godot/gdscript/development_step_cost_profiler_v1.gd"
)
const PROFILE_MARKER := "SPORESPORE_DEVELOPMENT_STEP_COST_PROFILE "
const PROFILE_ID := "recovery_step_cost_wall_clock_v1"
var _cost := CostProfiler.new()
var _profile_start_us := 0
var _previous_callback_end_us := -1
var _profile_callback := ""


func _initialize() -> void:
	_profile_start_us = Time.get_ticks_usec()
	super._initialize()


func _development_step_profiler_v1() -> RefCounted:
	return _cost


func _on_physics_frame() -> void:
	if _exit_scheduled or _finalizing:
		super._on_physics_frame()
		return
	var now := Time.get_ticks_usec()
	var gap := (
		"between_callbacks" if _previous_callback_end_us >= 0 else "startup_before_first_callback"
	)
	_cost.begin_v1(
		gap, _previous_callback_end_us if _previous_callback_end_us >= 0 else _profile_start_us
	)
	_cost.end_v1(gap, now)
	_profile_callback = "step_callback" if _physics_schedule_started else "activation_callback"
	_cost.begin_v1(_profile_callback)
	super._on_physics_frame()
	# Publication closes the final callback before taking its immutable snapshot.
	if not _profile_callback.is_empty():
		_cost.end_v1(_profile_callback)
		_profile_callback = ""
	_previous_callback_end_us = Time.get_ticks_usec()
	if not _exit_scheduled and _total_solver_step_count > 0 and _total_solver_step_count % 60 == 0:
		_cost.begin_v1("progress_publication")
		print("DEVELOPMENT_PROFILE_PROGRESS step=", _total_solver_step_count)
		_cost.end_v1("progress_publication")
		_previous_callback_end_us = Time.get_ticks_usec()


func _collect_arm_completed_step_v1(arm_id: String, global_step: int) -> Dictionary:
	var label := "collect_step/" + String(_arms[arm_id]["orchestrator_state"]["phase"])
	_cost.begin_v1(label)
	var result := super._collect_arm_completed_step_v1(arm_id, global_step)
	_cost.end_v1(label)
	return result


func _retain_compact_step_v1(
	arm_id: String, collection: Dictionary, application: Dictionary, phase: String
) -> Dictionary:
	_cost.begin_v1("retain_step/" + phase)
	var result := super._retain_compact_step_v1(arm_id, collection, application, phase)
	_cost.end_v1("retain_step/" + phase)
	return result


func _process_completed_arm_step_v1(
	arm_id: String, global_step: int, active_terminal_after_step: bool
) -> Dictionary:
	var label := "process_step/" + String(_arms[arm_id]["orchestrator_state"]["phase"])
	_cost.begin_v1(label)
	var result := super._process_completed_arm_step_v1(
		arm_id, global_step, active_terminal_after_step
	)
	_cost.end_v1(label)
	return result


func _plan_next_process_isolated_frame_v1(global_step: int) -> Dictionary:
	var label := "plan_step/" + String(_arms[_authorized_arm_id]["orchestrator_state"]["phase"])
	_cost.begin_v1(label)
	var result := super._plan_next_process_isolated_frame_v1(global_step)
	_cost.end_v1(label)
	return result


func _prepare_completed_process_isolated_interaction_v1(global_step: int) -> Dictionary:
	_cost.begin_v1("interaction_receipt")
	var result := super._prepare_completed_process_isolated_interaction_v1(global_step)
	_cost.end_v1("interaction_receipt")
	return result


func _publish_profiled_report_wire_v1(report: Dictionary) -> Dictionary:
	# The legacy wire remains the default. Discovery may provide a retained file
	# with the same full-precision JSON bytes instead of one enormous console line.
	var raw := super._publish_smoke_report_v1(report)
	return {"raw": raw, "raw_sha256": "sha256:" + raw.sha256_text(), "byte_length": raw.to_utf8_buffer().size()}

func _publish_smoke_report_v1(report: Dictionary) -> String:
	if not _profile_callback.is_empty():
		_cost.end_v1(_profile_callback)
		_profile_callback = ""
	_cost.begin_v1("final_report_publication")
	var wire := _publish_profiled_report_wire_v1(report)
	var raw: String = wire.raw
	var raw_sha: String = wire.raw_sha256
	var raw_bytes: int = wire.byte_length
	_cost.end_v1("final_report_publication")
	var timing := _cost.snapshot_v1(_profile_start_us, Time.get_ticks_usec())
	var receipt := {
		"schema_version": "sporespore_development_step_cost_profile_v1",
		"profile_id": PROFILE_ID,
		"clock": "Time.get_ticks_usec_monotonic_wall_time",
		"source_commit": report["source_commit"],
		"parent_attempt_id": report["parent_attempt_id"],
		"child_attempt_id": report["child_attempt_id"],
		"arm_id": report["arm_id"],
		"process_id": report["process_id"],
		"diagnostic_declaration_sha256": report["diagnostic_declaration_sha256"],
		"solver_step_count": report["solver_step_count"],
		"raw_report_sha256": raw_sha,
		"raw_report_byte_length": raw_bytes,
		"timing": timing,
		"physics_solver_time_isolated": false,
		"controller_inputs_changed": false,
		"telemetry_reduced": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var context_cache_profile := _development_context_cache_profile_v1()
	if not context_cache_profile.is_empty():
		receipt["context_cache"] = context_cache_profile
	print(PROFILE_MARKER, JsonTransportScript.stringify(receipt))
	return raw


func _development_context_cache_profile_v1() -> Dictionary:
	return {}
