class_name AdversarialBout
extends RefCounted

## M46 (capstone) — adversarial combat training loop. Two creatures fight in ONE isolated
## world (I1), each driven by its own CPG + StrikeController (and optionally a BlockController),
## scored bidirectionally from combat.resolve_contact impulse-to-vital. reward = damage_dealt -
## damage_taken (+ survival), so locomotion + strike + defense CO-TRAIN. The training loop uses a
## fixed-opponent curriculum (dummy -> frozen champion -> self-play) to avoid self-play collapse.
##
## Anti-cheat: the M38 universal floor still applies to each combatant's movement, so "win by
## flailing/teleporting" fails credibility — `result.a_floor_ok` / `b_floor_ok` report it.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const StrikeControllerScript := preload("res://scripts/sim/strike_controller.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const CombatResolverScript := preload("res://scripts/sim/combat.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CreatureFlavorScript := preload("res://scripts/sim/creature_flavor.gd")

const TICK_RATE := 60.0
const FLUSH_TICKS := 12


class BoutParams:
	var horizon_s := 1.5
	var fixed_dt := 1.0 / TICK_RATE
	var separation := 1.6        # initial gap between the two creatures (m)
	var approach_speed := 4.0    # closing velocity given to the aggressor (a tackle/charge)
	var impulse_threshold := 0.05
	var floor_friction := 1.0
	var a_strikes := true        # A is an active striker
	var b_strikes := false       # B defaults to a no-op opponent (the dummy)


static func run_bout(a_gene: PartGene, b_gene: PartGene, tree: SceneTree,
		params: BoutParams = null) -> Dictionary:
	if a_gene == null or b_gene == null or tree == null:
		return {"ok": false, "error": "missing combatant/tree"}
	var p := params if params != null else BoutParams.new()
	await _flush(tree)
	var host := _make_host()
	var world := Node3D.new()
	host.add_child(world)
	tree.root.add_child(host)
	await _flush(tree)
	SimWorldScript.add_floor(world, p.floor_friction)

	var a_params := CreatureBodyScript.BuildParams.new()
	a_params.creature_id = &"a"
	a_params.contact_monitor = true
	a_params.max_contacts_reported = 16
	var b_params := CreatureBodyScript.BuildParams.new()
	b_params.creature_id = &"b"
	b_params.contact_monitor = true
	b_params.max_contacts_reported = 16

	var ay := _spawn_y(a_gene)
	var by := _spawn_y(b_gene)
	var a_body: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(a_gene),
			Transform3D(Basis.IDENTITY, Vector3(0.0, ay, p.separation)), a_params)
	var b_body: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(b_gene),
			Transform3D(Basis.IDENTITY, Vector3(0.0, by, 0.0)), b_params)
	world.add_child(a_body)
	world.add_child(b_body)

	# A charges B (closing the gap so strikes can land), then drives its weapon in.
	for rb in a_body.call("part_bodies"):
		if rb is RigidBody3D:
			(rb as RigidBody3D).linear_velocity = Vector3(0.0, 0.0, -absf(p.approach_speed))
			(rb as RigidBody3D).set_meta("pre_contact_speed", absf(p.approach_speed))

	var a_ctrl := CpgControllerScript.new()
	a_ctrl.call("bind", a_body, a_gene, _stance_params())
	world.add_child(a_ctrl)
	var b_ctrl := CpgControllerScript.new()
	b_ctrl.call("bind", b_body, b_gene, _stance_params())
	world.add_child(b_ctrl)

	var b_target := Node3D.new()
	var a_target := Node3D.new()
	world.add_child(b_target)
	world.add_child(a_target)
	var a_strike: Node = null
	var b_strike: Node = null
	if p.a_strikes:
		a_strike = StrikeControllerScript.new()
		a_strike.call("bind", a_body, a_gene, b_target)
		world.add_child(a_strike)
	if p.b_strikes:
		b_strike = StrikeControllerScript.new()
		b_strike.call("bind", b_body, b_gene, a_target)
		world.add_child(b_strike)

	var a_root := _root_body(a_body)
	var b_root := _root_body(b_body)
	var a_start := Vector3.ZERO if a_root == null else a_root.global_position
	var b_start := Vector3.ZERO if b_root == null else b_root.global_position
	var ticks := maxi(1, int(round(p.horizon_s / maxf(p.fixed_dt, 0.000001))))
	var dt := p.fixed_dt
	var best_dmg_to_b := 0.0
	var best_dmg_to_a := 0.0
	var contacts := 0
	var a_max_step := 0.0
	var b_max_step := 0.0
	var a_prev := a_start
	var b_prev := b_start
	var finite := true
	for _i in ticks:
		a_ctrl.call("tick", float(_i) * dt, dt)
		b_ctrl.call("tick", float(_i) * dt, dt)
		if a_root != null:
			b_target.global_position = b_root.global_position if b_root != null else b_target.global_position
		if a_strike != null:
			a_strike.call("tick", dt)
		if b_strike != null:
			a_target.global_position = a_root.global_position if a_root != null else a_target.global_position
			b_strike.call("tick", dt)
		await tree.physics_frame
		best_dmg_to_b = maxf(best_dmg_to_b, _resolve_dir(a_body, b_body, a_gene, b_gene, p))
		best_dmg_to_a = maxf(best_dmg_to_a, _resolve_dir(b_body, a_body, b_gene, a_gene, p))
		if best_dmg_to_b > 0.0 or best_dmg_to_a > 0.0:
			contacts += 1
		if a_root != null:
			a_max_step = maxf(a_max_step, (a_root.global_position - a_prev).length())
			a_prev = a_root.global_position
			finite = finite and a_root.global_position.is_finite()
		if b_root != null:
			b_max_step = maxf(b_max_step, (b_root.global_position - b_prev).length())
			b_prev = b_root.global_position
			finite = finite and b_root.global_position.is_finite()

	var a_score := best_dmg_to_b - best_dmg_to_a
	var b_score := best_dmg_to_a - best_dmg_to_b
	var teleport_cap := SimRolloutScript.TELEPORT_MAX_VEL * dt * 1.5
	var winner: StringName = &"a" if a_score > b_score else (&"b" if b_score > a_score else &"draw")
	var a_name := CreatureFlavorScript.name_for(a_gene)
	var b_name := CreatureFlavorScript.name_for(b_gene)
	var quip := CreatureFlavorScript.combat_quip(a_name, b_name, best_dmg_to_b, best_dmg_to_a)
	host.queue_free()
	await _flush(tree)
	return {
		"ok": finite,
		"damage_to_a": best_dmg_to_a,
		"damage_to_b": best_dmg_to_b,
		"a_score": a_score,
		"b_score": b_score,
		"winner": winner,
		"a_name": a_name,
		"b_name": b_name,
		"quip": quip,
		"contacts": contacts,
		"a_floor_ok": finite and a_max_step <= teleport_cap,   # M38 anti-flail floor
		"b_floor_ok": finite and b_max_step <= teleport_cap,
	}


# Fixed-opponent curriculum: beat a no-op dummy, then a frozen champion, then self-play. Returns
# per-stage results; the champion "advances" only by winning the current stage (anti-collapse).
static func run_curriculum(champion: PartGene, opponents: Array, tree: SceneTree,
		params: BoutParams = null) -> Array:
	var out: Array = []
	for opp in opponents:
		var r: Dictionary = await run_bout(champion, opp, tree, params)
		out.append(r)
	return out


static func _resolve_dir(atk_body: Node3D, def_body: Node3D, atk_gene: PartGene,
		def_gene: PartGene, p: BoutParams) -> float:
	var rows := CombatResolverScript.capture_contact_rows(atk_body, def_body)
	var best := 0.0
	for row in rows:
		if float(row.get("normal_impulse_proxy", 0.0)) < p.impulse_threshold:
			continue
		var result := CombatResolverScript.resolve_contact_row(atk_gene, def_gene, row)
		best = maxf(best, float(result.get("damage", 0.0)))
	return best


static func _root_body(body: Node3D) -> RigidBody3D:
	var bodies: Array = body.call("part_bodies")
	return bodies[0] as RigidBody3D if not bodies.is_empty() else null


static func _stance_params() -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	p.amplitude_scale = 0.5
	p.posture_scale = 1.5
	return p


static func _make_host() -> Node:
	var viewport := SubViewport.new()
	viewport.name = "IsolatedBoutWorld"
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return viewport


static func _spawn_y(root_gene: PartGene) -> float:
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	var min_y := 0.0
	for p in fold["parts"]:
		min_y = minf(min_y, p.world_aabb.position.y)
	return maxf(0.4 - min_y, 0.6)


static func _flush(tree: SceneTree) -> void:
	for _i in FLUSH_TICKS:
		await tree.process_frame
		await tree.physics_frame
