extends SceneTree

## Minimal STAND-ONLY probe: settle + hold, print body_y/up every 0.5 s. No SimRollout, no contact
## sensing — isolates whether the creature can hold a stand under the controller alone.

const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var g = PartCatalog.make_quadruped_v2()
	var spawn_y: float = SimRolloutScript.spawn_y(g)
	print("=== stand-only: quad_v2  spawn_y=%.3f  weld=%s ===" % [
		spawn_y, OS.get_environment("SPORE_ABD_WELD")])
	var world := Node3D.new()
	root.add_child(world)
	SimWorldScript.add_floor(world, 1.0)
	var body: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(g),
			Transform3D(Basis.IDENTITY, Vector3(0, spawn_y, 0)), null)
	world.add_child(body)
	var cp := CpgControllerScript.Params.new()
	if g.gait != null:
		cp.amplitude_scale = g.gait.amplitude_scale; cp.frequency_scale = g.gait.frequency_scale
		cp.gain_scale = g.gait.gain_scale; cp.traction_scale = g.gait.traction_scale
		cp.posture_scale = g.gait.posture_scale
		if g.gait.locomotion_mode != &"":
			cp.locomotion_mode = g.gait.locomotion_mode
	var ctrl := CpgControllerScript.new()
	ctrl.bind(body, g, cp)
	world.add_child(ctrl)
	var bodies: Array = body.call("part_bodies")
	var rb0 := bodies[0] as RigidBody3D
	var stand: bool = ctrl.has_method("wants_settle_tick") and bool(ctrl.call("wants_settle_tick"))
	# part index -> id map for torque readout
	var parts: Array = body.call("parts")
	for i in 300:
		if stand:
			ctrl.call("settle_tick", 1.0 / 60.0)
		await physics_frame
		if i % 15 == 14:
			var tens: Dictionary = ctrl.call("joint_tensions")
			var top := ""
			var pairs := []
			for pidx in tens:
				pairs.append([absf(float(tens[pidx])), int(pidx)])
			pairs.sort_custom(func(a, b): return a[0] > b[0])
			for k in mini(3, pairs.size()):
				var pi: int = pairs[k][1]
				var pid := str(parts[pi].part_id) if pi < parts.size() else str(pi)
				top += "%s=%.0f " % [pid, pairs[k][0]]
			print("  t=%.2f  y=%.3f  up=%.3f  vy=%+.2f  | %s" % [
				(i + 1) / 60.0, rb0.global_position.y,
				rb0.global_basis.y.dot(Vector3.UP), rb0.linear_velocity.y, top])
	print("DONE")
	quit(0)
