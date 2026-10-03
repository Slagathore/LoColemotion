class_name KinestheticTrainer
extends RefCounted

## The AI-drive training mode's engine. A DEMONSTRATOR (the reference-tracking controller — an "AI" that
## drives the joints under the REAL muscle cap) walks the creature; we RECORD each joint's angle + the
## torque it actually applied, binned by gait phase, then BAKE that into a MotionClip on the creature.
## Afterwards the creature REPLAYS the clip (drive toward the recorded angles + recorded torque
## feed-forward) — reproducing the motion it just performed. Every recorded force is one the muscle could
## produce (it was captured under the cap), so the honest body can replay it. Per Cole's friend: this is
## the feed-forward half; SIMBICON is the feedback half; together they're a complete controller.

const CPG := preload("res://scripts/sim/cpg_controller.gd")
const SimWorld := preload("res://scripts/sim/sim_world.gd")
const CreatureBody := preload("res://scripts/sim/creature_body.gd")
const SR := preload("res://scripts/sim/sim_rollout.gd")


static func _params_for(g) -> CPG.Params:
	var cp := CPG.Params.new()
	if g.gait != null:
		cp.amplitude_scale = g.gait.amplitude_scale
		cp.frequency_scale = g.gait.frequency_scale
		cp.gain_scale = g.gait.gain_scale
		cp.traction_scale = g.gait.traction_scale
		cp.posture_scale = g.gait.posture_scale
		if g.gait.locomotion_mode != &"":
			cp.locomotion_mode = g.gait.locomotion_mode
	return cp


# Demonstrate a walk on `root_gene`, capture its joint trajectories+torques, BAKE the clip onto
# root_gene.gait.motion_clip, and return {clip, joints, peak_torque}. warmup_s lets the gait reach steady
# state before recording; record_s is how long to record (several cycles average into the phase bins).
static func capture_and_bake(root_gene, tree, warmup_s := 2.0, record_s := 5.0, bins := 24) -> Dictionary:
	var world := Node3D.new()
	tree.get_root().add_child(world)
	SimWorld.add_floor(world, 1.0)
	# Demonstrate WITHOUT any existing clip (drive live), even if one was baked before.
	var clip_backup = root_gene.gait.motion_clip if root_gene.gait != null else null
	if root_gene.gait != null:
		root_gene.gait.motion_clip = null
	var body: Node3D = CreatureBody.build(
		root_gene, Transform3D(Basis.IDENTITY, Vector3(0, SR.spawn_y(root_gene), 0)), null)
	world.add_child(body)
	var ctrl = CPG.new()
	ctrl.call("bind", body, root_gene, _params_for(root_gene))
	world.add_child(ctrl)
	var settle: bool = ctrl.has_method("wants_settle_tick") and bool(ctrl.call("wants_settle_tick"))
	for _k in 90:
		if settle:
			ctrl.call("settle_tick", 1.0 / 60.0)
		await tree.physics_frame
	var t := 0.0
	var dt := 1.0 / 60.0
	for _k in int(warmup_s * 60.0):
		ctrl.call("tick", t, dt); await tree.physics_frame; t += dt
	ctrl.call("start_capture", bins)
	for _k in int(record_s * 60.0):
		ctrl.call("tick", t, dt); await tree.physics_frame; t += dt
	var clip = ctrl.call("finish_capture")
	if root_gene.gait != null:
		root_gene.gait.motion_clip = clip
	else:
		root_gene.gait.motion_clip = clip_backup   # unreachable, keeps analyzers happy
	world.queue_free()
	await tree.physics_frame
	return {
		"clip": clip,
		"joints": int(clip.joint_count()),
		"peak_torque": float(clip.peak_torque()),
	}
