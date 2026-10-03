extends SceneTree
const Worker := preload("res://sdk/discovery/recovery_discovery_worker_v1.gd")
const Discovery := Worker.Discovery
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
var checks: Dictionary = {}

class Probe:
	extends "res://sdk/discovery/recovery_discovery_worker_v1.gd"
	var finished: Dictionary = {}
	var impulse_calls: Array = []
	func _initialize() -> void: pass
	func _apply_discovery_impulse(_torso: RigidBody3D, impulse: Vector3) -> void:
		impulse_calls.append(impulse)
	func _finish_walking_session_v1(_arm_id: String) -> Dictionary: return {"ok": true}
	func _measure_tail(local_step: int, global_step: int) -> Dictionary:
		return {"ok": true, "local_step": local_step, "global_step": global_step}
	func _finish_discovery(valid: bool, reason: String, detail: Dictionary = {}) -> void:
		finished = {"valid": valid, "reason": reason, "detail": detail}
		_exit_scheduled = true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	checks.closed_by_default = not Discovery.selected() and not Discovery.take_world_permission()
	checks.unknown_prefix = Facade.initial_gait_steps_v1(80140, "walking_prefix", "", Discovery.PREFIX).is_empty()
	Discovery.declaration = {"seed": 80140, "discovery_cell": {"phase": 140, "tail_steps": 240}}
	checks.explicit_phase = Facade.initial_gait_steps_v1(80140, "walking_prefix", "", Discovery.PREFIX) == {"front_left":140,"front_right":140,"rear_left":140,"rear_right":140}
	checks.crossed_seed = Facade.initial_gait_steps_v1(80141, "walking_prefix", "", Discovery.PREFIX).is_empty()
	checks.crossed_segment = Facade.initial_gait_steps_v1(80140, "walking_resume", "", Discovery.PREFIX).is_empty()
	checks.no_qualification_world = not Discovery.take_world_permission()
	for mode in ["passive", "zero_velocity_brake"]:
		for impulse in [0.0, 0.25]:
			var probe := Probe.new()
			var torso := RigidBody3D.new()
			var facade := Facade.new()
			var joints := {}
			for id in Facade.JOINT_IDS:
				var joint := HingeJoint3D.new()
				joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.1)
				joints[id] = joint
			facade._binding = {"joint_nodes": joints}
			var arm := {"orchestrator_state": {"phase": Worker.Orchestrator.PHASE_INTERACTION},
				"facade": facade, "model": {"body_nodes": {"torso": torso}, "joint_nodes": joints, "host_step_count":271},
				"prefix_session_start_receipt": {"task_frame_lateral_axis_world_host_real": [1.0,0.0,0.0]}}
			probe._authorized_arm_id = "kick_passive_recovery_resume"
			probe._arms[probe._authorized_arm_id] = arm
			Discovery.declaration.discovery_cell = {"phase":140,"tail_steps":240,"actuation":mode,"impulse_ns":impulse}
			var tag: String = mode + "_" + str(impulse)
			var result := probe._plan_next_process_isolated_frame_v1(271)
			checks[tag + "_schedule"] = result.get("ok") == true and probe._tail_active
			checks[tag + "_count"] = probe._external_kick_application_count == int(impulse > 0)
			checks[tag + "_boundary_call"] = probe.impulse_calls.size() == int(impulse > 0)
			checks[tag + "_impulse"] = probe._disturbance.impulse_world_ns == [impulse,0.0,0.0]
			checks[tag + "_repeat_refused"] = probe._plan_next_process_isolated_frame_v1(271).get("ok") == false
			for id in joints:
				checks[tag + "_motor_" + id] = joints[id].get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR) == (mode == "zero_velocity_brake") and joints[id].get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY) == 0.0 and is_equal_approx(joints[id].get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE),0.1)
			probe._observed_global_solver_frames = 271
			probe._total_solver_step_count = 271
			for i in range(240): probe._on_physics_frame()
			checks[tag + "_bounded"] = probe.finished.get("valid") == true and probe._tail_rows.size() == 240 and probe._total_solver_step_count == 511
			probe._on_physics_frame()
			checks[tag + "_stopped"] = probe._total_solver_step_count == 511
			for joint in joints.values(): joint.free()
			torso.free()
			probe._arms.clear()
			probe.free()
	Discovery.declaration.clear()
	checks.restored_closed = not Discovery.selected()
	var ok := checks.values().all(func(v): return v == true)
	var args := OS.get_cmdline_user_args()
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"checks":checks,"world_build_count":0,"solver_step_count":0}))
	file.close()
	print("DISCOVERY_ZERO_WORLD ", checks.size(), " checks, ok=",ok)
	quit(0 if ok else 1)
