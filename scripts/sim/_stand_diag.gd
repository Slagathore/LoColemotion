extends SceneTree

## STAND diagnostic (temp). Answers: can quad_v2 hold itself off its belly with NO gait — just
## settle + stand? And WHICH part is dragging (body box vs thigh/shin)? Prints spawn height, the
## body height + up-dot through a stand-only hold, and the drag_parts breakdown from a gait rollout.

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")


func _initialize() -> void:
	call_deferred("_run")


func _pf(g) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if g.gait != null:
		p.amplitude_scale = g.gait.amplitude_scale; p.frequency_scale = g.gait.frequency_scale
		p.gain_scale = g.gait.gain_scale; p.traction_scale = g.gait.traction_scale
		p.posture_scale = g.gait.posture_scale
		if g.gait.locomotion_mode != &"":
			p.locomotion_mode = g.gait.locomotion_mode
	return p


func _run() -> void:
	var g = PartCatalog.make_quadruped_v2()
	var spawn_y: float = SimRolloutScript.spawn_y(g)
	print("=== STAND diag: quad_v2 ===")
	print("spawn_y = %.3f" % spawn_y)

	# --- part id -> label map (for drag_parts readout) ---
	var labels := {}
	_collect_labels(g, labels)

	# --- STAND-ONLY: settle, then hold stance with NO gait tick for 4 s ---
	var world := Node3D.new()
	root.add_child(world)
	SimWorldScript.add_floor(world, 1.0)
	var body: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(g),
			Transform3D(Basis.IDENTITY, Vector3(0, spawn_y, 0)), null)
	world.add_child(body)
	var cp := _pf(g)
	var ctrl := CpgControllerScript.new()
	ctrl.bind(body, g, cp)
	world.add_child(ctrl)
	var bodies: Array = body.call("part_bodies")
	var rb0 := bodies[0] as RigidBody3D
	var stand := ctrl.has_method("wants_settle_tick") and bool(ctrl.call("wants_settle_tick"))
	print("wants_settle_tick(stand) = %s" % str(stand))
	# settle
	for _i in 90:
		if stand:
			ctrl.call("settle_tick", 1.0 / 60.0)
		await physics_frame
	print("after settle: body_y=%.3f  up=%.3f" % [rb0.global_position.y, rb0.global_basis.y.dot(Vector3.UP)])
	# hold stance, NO gait, 4 s — does it stay up or sink to belly?
	for i in 240:
		if stand:
			ctrl.call("settle_tick", 1.0 / 60.0)
		await physics_frame
		if i % 60 == 59:
			print("  stand t=%.1f  body_y=%.3f  up=%.3f" % [
				(i + 1) / 60.0, rb0.global_position.y, rb0.global_basis.y.dot(Vector3.UP)])
	world.queue_free()
	await _flush()

	# --- GAIT rollout with contact sensing: get drag_parts (WHICH parts touch the floor) ---
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _pf(g)
	rp.sense_contacts = true
	var r: Dictionary = await SimRolloutScript.run(g, 8.0, 7, self, rp)
	print("--- gait rollout (8s) ---")
	print("fwd=%.2f up_min=%.2f body_drag=%.2f plants=%d" % [
		float(r.get("forward", 0.0)), float(r.get("root_up_min", 1.0)),
		float(r.get("body_drag_frac", 0.0)), int(r.get("foot_plants", 0))])
	var dp: Dictionary = r.get("drag_parts", {})
	print("drag_parts (part touching floor -> tick count):")
	if dp.is_empty():
		print("  (none)")
	for pid in dp:
		print("  %-22s  %d ticks  [%s]" % [str(pid), int(dp[pid]), str(labels.get(pid, "?"))])
	quit(0)


func _collect_labels(gene, out: Dictionary) -> void:
	if gene == null:
		return
	var pid = gene.get("part_id") if gene.get("part_id") != null else null
	# PartGene stores id / tags; capture id -> tags for readout
	var idv = gene.get("id")
	if idv != null:
		out[idv] = str(gene.get("tags"))
	for c in gene.children:
		_collect_labels(c, out)


func _flush() -> void:
	await physics_frame
	await physics_frame
