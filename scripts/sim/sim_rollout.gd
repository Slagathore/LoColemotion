class_name SimRollout
extends RefCounted

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const ReachControllerScript := preload("res://scripts/sim/reach_controller.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const WorldObjectScript := preload("res://scripts/sim/world_object.gd")
const CombatResolverScript := preload("res://scripts/sim/combat.gd")

## Headless measured rollout. The returned dictionary is MEASURED data only;
## analytic evaluator output stays separate and is combined by Reconcile.

const TICK_RATE := 60.0
const SETTLE_TICKS := 90
const FLUSH_TICKS := 20
const CREDIBLE_FORWARD_M := 3.0
const CREDIBLE_TAIL_M := 1.25
const MIN_STRAIGHTNESS := 0.35
const MIN_ROOT_UP_DOT := 0.45
const MAX_ROOT_HEIGHT_DROP_M := 1.0
const FLIGHT_CLEARANCE_M := 0.04   # a foot bottom above this (post-settle) counts as off the floor
const MAX_YAW_FOR_CREDIBLE := 1.4
const MAX_ASSIST_PER_METER := 8000.0
const MAX_ASSIST_RATIO := 0.995        # the assist IS the locomotion model; the real anti-ride gate is leg motion below
const MAX_SLIP_RATIO := 4.0            # M37: slip/forward. Loose default — see note below.
# M37 calibration note: in the current soft-contact sim, feet never fully plant, so even
# the cleanest validated walkers measure slip_ratio ~0.9-1.1 and the spread up to ~3.5 tracks
# MORPHOLOGY (foot count), not cheating: quad 0.90, hex 1.02, spider 1.06, flagship 2.19,
# biped 3.50. A tight ceiling would brand the suite's own validated champions as skaters. So
# the default sits above the worst validated champion; the gate's teeth are the per-track
# `slip_ratio_ceiling` param (a ratchet that only tightens) plus a re-baseline after M42's
# re-optimization teaches feet to plant. The metric is live on every rollout regardless.
const MAX_LATERAL_RATIO := 0.6         # sideways motion vs total horizontal = skating
const MAX_YAW_RATE := 2.2              # rad/s of accumulated turning = spinning
const MIN_THETA_SPAN := 0.25           # min hinge swing range — a rigid body skating on the assist has ~0
const MIN_MAX_OMEGA := 0.4             # min peak joint angular velocity — legs must actually move
const TELEPORT_MAX_VEL := 30.0         # M38: m/s ceiling; a >1.5x single-tick CoM jump = non-physical
const RESERVED_MODES: Array[StringName] = [&"swim", &"climb"]   # M52: fly/glide now implemented
# M39: contact-subset modes are probe-BLIND (Principle 16) — scored by the live sim, excluded
# from the analytic-probe correlation harness. Declared here so the harness can consult it.
const MEASURED_ONLY_MODES: Array[StringName] = [&"pogo", &"radial", &"urchin"]


static func is_measured_only_mode(mode: StringName) -> bool:
	return MEASURED_ONLY_MODES.has(mode)
const GRASP_RANGE := 1.2              # M8B: carrier-to-object distance that triggers a grasp weld
const GRASP_FOLLOW_TOL := 0.3         # max drift in carrier->object distance while held (rigid follow)


class Params:
	var horizon_s := 3.0
	var settle_ticks := SETTLE_TICKS
	var fixed_dt := 1.0 / TICK_RATE
	var seed := 0
	var forward_axis := Vector3.FORWARD
	var floor_friction := 1.0
	var build_params: CreatureBodyScript.BuildParams = null
	var controller_params: CpgControllerScript.Params = null
	# Opt-in REAL ground-contact sensing (Jolt contact_monitor). OFF by default because contact
	# monitoring nudges the solver and perturbs the chaos-fragile champion goldens; diagnostics +
	# honest-motion validation set it true to get true_airborne_frac / body_drag_frac / foot_plants.
	var sense_contacts := false
	var track = null   # optional Track: builds the world (obstacles) + defines scoring
	var assist_ratio_ceiling := -1.0
	var slip_ratio_ceiling := -1.0     # M37: <0 uses MAX_SLIP_RATIO; ratchets only down


class CombatParams:
	var horizon_s := 1.0
	var fixed_dt := 1.0 / TICK_RATE
	var strike_speed := 6.0
	var impulse_threshold := 0.05
	var floor_friction := 1.0
	# Note: rollouts are ALWAYS isolated in a per-rollout SubViewport World3D (measurement
	# isolation is a correctness invariant, not a toggle — see _make_rollout_host).


static func run(root_gene: PartGene, horizon_s: float, seed: int, tree: SceneTree,
		params: Params = null) -> Dictionary:
	if root_gene == null or tree == null:
		return {"ok": false, "error": "missing root/tree"}
	await _flush_tree(tree)
	var p := params if params != null else Params.new()
	p.horizon_s = horizon_s
	p.seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var host := _make_rollout_host()
	var world := Node3D.new()
	host.add_child(world)
	tree.root.add_child(host)
	await _flush_tree(tree)
	var floor_body: Node = null
	if p.track != null:
		p.track.build_world(world)         # track owns floor + obstacles
		floor_body = world.find_child("SimFloor", true, false)
	else:
		floor_body = SimWorldScript.add_floor(world, p.floor_friction)
	var start_xform := Transform3D(Basis.IDENTITY, Vector3(0.0, _spawn_y(root_gene), 0.0))
	var body_params := p.build_params if p.build_params != null else CreatureBodyScript.BuildParams.new()
	if p.sense_contacts:
		body_params.contact_monitor = true   # opt-in REAL ground-contact sensing
	var body: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(root_gene), start_xform, body_params)
	world.add_child(body)
	# M53 Toybox: apply arena hazards (low-g / mud drag) to the creature's bodies. Wind is a
	# per-tick force, applied in the loop below.
	var hazard := {}
	if p.track != null and p.track.has_method("has_hazard") and p.track.has_hazard():
		hazard = p.track.hazard_physics()
		for rb in body.call("part_bodies"):
			if rb is RigidBody3D:
				(rb as RigidBody3D).gravity_scale = float(hazard.get("gravity_scale", 1.0))
				(rb as RigidBody3D).linear_damp = float(hazard.get("linear_damp", 0.0))
	var wind: Vector3 = hazard.get("wind", Vector3.ZERO)
	var ctrl: Node = CpgControllerScript.new()
	ctrl.call("bind", body, root_gene, p.controller_params)
	world.add_child(ctrl)

	# A honest legged walker holds its stance while settling (an animal doesn't go limp when set down);
	# otherwise its unbraced legs fold to belly before the walk even starts. Other creatures settle limp.
	var settle_stand: bool = ctrl.has_method("wants_settle_tick") and bool(ctrl.call("wants_settle_tick"))
	for _i in p.settle_ticks:
		if settle_stand:
			ctrl.call("settle_tick", 1.0 / 60.0)
		await tree.physics_frame

	var bodies: Array = body.call("part_bodies")
	var root_body := bodies[0] as RigidBody3D if not bodies.is_empty() else null
	var start_pos := Vector3.ZERO if root_body == null else root_body.global_position
	var start_basis := Basis.IDENTITY if root_body == null else root_body.global_basis
	var heading := _horizontal_axis(start_basis, p.forward_axis)
	var right := Vector3(heading.z, 0.0, -heading.x).normalized()
	var start_yaw := _yaw_from_heading(heading)
	var ticks := maxi(1, int(round(p.horizon_s / maxf(p.fixed_dt, 0.000001))))
	var dt := p.fixed_dt
	var min_cog_y := INF
	var min_root_y := INF
	var max_root_y := -INF
	var total_yaw := 0.0          # accumulated |yaw change| — catches spinners that wrap
	var prev_yaw := start_yaw
	var min_root_up_dot := 1.0
	var shimmy_flips := 0     # root vertical-velocity sign changes = motion-quality read (chatter/vibration)
	var prev_vy := 0.0
	var finite := true
	var path_len := 0.0
	var airborne_ticks := 0       # ticks where ALL feet are clear of the floor = a real flight phase
	var sampled_ticks := 0
	var max_foot_clear := 0.0     # highest any foot's bottom rose above the floor (ballistic clearance)
	var max_com_step := 0.0       # M38: largest single-tick CoM jump — catches teleport/explosion
	var prev_pos := start_pos
	var mid_pos := start_pos
	var trajectory: Array = [start_pos]   # sampled root path, for track scoring (curves)
	@warning_ignore("integer_division")
	var mid_tick := ticks / 2   # loop index; must stay int so `i == mid_tick` can match
	var theta_min := INF
	var theta_max := -INF
	var max_omega := 0.0
	var phase_coherence_sum := 0.0   # M60: real per-segment phase-coherence accumulator
	var phase_coherence_ticks := 0
	var ran_ticks := 0
	# M8B grasp: when the track wants it, weld a graspable object to a carrier on contact
	# and measure carry distance + object-follows-hand. Prefer a manipulator-tagged limb,
	# else the root body (the safe primitive: weld holds + carries + releases cleanly).
	var grasp_on: bool = p.track != null and p.track.has_method("auto_grasp") and p.track.auto_grasp()
	var carrier := root_body
	var grasp_targets: Array = []
	if grasp_on:
		for rb in p.track.runtime_objects:
			if rb != null and bool(rb.get_meta("graspable", false)):
				grasp_targets.append(rb)
		for part in CE.fold_graph(root_gene, Transform3D.IDENTITY)["parts"]:
			if part.tags.has(&"manipulator") and int(part.index) < bodies.size():
				carrier = bodies[int(part.index)] as RigidBody3D
				break
	var grasp_joint: Joint3D = null
	var grasped := false
	var grasp_obj: RigidBody3D = null
	var grasp_ticks := 0
	var grasp_obj_start := Vector3.ZERO
	var follow_min := INF
	var follow_max := -INF
	var reach: Node = null
	if grasp_on and not grasp_targets.is_empty():
		reach = ReachControllerScript.new()
		reach.call("bind", body, root_gene, grasp_targets[0])
		world.add_child(reach)
	# REAL ground-contact sensing (Jolt contact_monitor): which parts actually touch the floor each
	# tick. Honest answers to "is it ever airborne", "does it drag its body", "do the feet step".
	var parts_meta: Array = body.call("parts")
	var is_foot: Array = []
	for pm in parts_meta:
		is_foot.append(pm.tags.has(&"foot"))
	var ground_sampled := 0
	var true_air_ticks := 0           # ticks with ZERO parts touching the floor = a real flight phase
	var nonfoot_touch_ticks := 0      # ticks where a NON-foot part touches = body drag / worming
	var foot_touch_ticks := 0         # ticks where >=1 foot touches
	var foot_plants := 0              # foot lift->plant transitions = real steps / hop landings
	var feet_lifted_ever := false     # did EVERY foot leave the ground at once (a real step/jump)
	var drag_parts := {}              # part_id -> tick count, for NON-foot parts that touch (what drags)
	var prev_foot_down: Array = []
	for _b in bodies.size():
		prev_foot_down.append(true)
	for i in ticks:
		ctrl.call("tick", float(i) * dt, dt)
		if wind != Vector3.ZERO:                          # M53: steady gust (accel) -> force = m·a
			for rb in body.call("part_bodies"):
				if rb is RigidBody3D:
					(rb as RigidBody3D).apply_central_force(wind * (rb as RigidBody3D).mass)
		if reach != null:
			reach.call("tick", dt)
		await tree.physics_frame
		ran_ticks = i + 1
		# Real contact read (post-step): who is touching the floor right now? (opt-in)
		if p.sense_contacts:
			var on_floor := _parts_on_floor(bodies, floor_body)
			ground_sampled += 1
			var any_touch := false
			var any_nonfoot := false
			var any_foot := false
			var all_feet_up := true
			for pi in on_floor.size():
				var down: bool = on_floor[pi]
				if down:
					any_touch = true
					if bool(is_foot[pi]):
						any_foot = true
					else:
						any_nonfoot = true
						var pid := String(parts_meta[pi].part_id)
						drag_parts[pid] = int(drag_parts.get(pid, 0)) + 1
				if bool(is_foot[pi]):
					if down:
						all_feet_up = false
					if down and not bool(prev_foot_down[pi]):
						foot_plants += 1   # this foot just landed = a step
					prev_foot_down[pi] = down
			if not any_touch:
				true_air_ticks += 1
			if any_nonfoot:
				nonfoot_touch_ticks += 1
			if any_foot:
				foot_touch_ticks += 1
			if all_feet_up:
				feet_lifted_ever = true
		if grasp_on and carrier != null:
			if not grasped:
				for obj in grasp_targets:
					if obj != null and carrier.global_position.distance_to(obj.global_position) <= GRASP_RANGE:
						grasp_joint = WorldObjectScript.make_grasp_joint(world, carrier, obj)
						if grasp_joint != null:
							grasped = true
							grasp_obj = obj
							grasp_obj_start = obj.global_position
						break
			if grasped and grasp_obj != null:
				grasp_ticks += 1
				var fd := carrier.global_position.distance_to(grasp_obj.global_position)
				follow_min = minf(follow_min, fd)
				follow_max = maxf(follow_max, fd)
		var tick_phases: Array = []
		for cmd in ctrl.call("last_commands"):
			var theta := float(cmd.get("theta", 0.0))
			theta_min = minf(theta_min, theta)
			theta_max = maxf(theta_max, theta)
			max_omega = maxf(max_omega, absf(float(cmd.get("omega", 0.0))))
			tick_phases.append([int(cmd.get("index", 0)), float(cmd.get("phase_t", 0.0))])
		# M60: per-segment phase coherence — a clean traveling body wave has near-constant phase
		# offsets between consecutive segments (low variance => high coherence). Replaces the
		# theta_span "articulation proxy" for the undulation gesture with a real wave measure.
		if tick_phases.size() >= 3:
			tick_phases.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
			var diffs: Array = []
			for k in range(1, tick_phases.size()):
				diffs.append(wrapf(float(tick_phases[k][1]) - float(tick_phases[k - 1][1]), -0.5, 0.5))
			var dmean := 0.0
			for d in diffs:
				dmean += float(d)
			dmean /= float(diffs.size())
			var dvar := 0.0
			for d in diffs:
				dvar += (float(d) - dmean) * (float(d) - dmean)
			dvar /= float(diffs.size())
			phase_coherence_sum += 1.0 / (1.0 + dvar * 20.0)
			phase_coherence_ticks += 1
		var cur_pos := Vector3.ZERO if root_body == null else root_body.global_position
		if root_body != null:
			min_root_y = minf(min_root_y, root_body.global_position.y)
			max_root_y = maxf(max_root_y, root_body.global_position.y)
			min_root_up_dot = minf(min_root_up_dot, root_body.global_basis.y.normalized().dot(Vector3.UP))
			var yaw := _yaw_from_heading(_horizontal_axis(root_body.global_basis, p.forward_axis))
			total_yaw += absf(wrapf(yaw - prev_yaw, -PI, PI))
			prev_yaw = yaw
		path_len += _horizontal_delta(cur_pos - prev_pos).length()
		max_com_step = maxf(max_com_step, (cur_pos - prev_pos).length())
		var vy := (cur_pos.y - prev_pos.y) / maxf(dt, 1.0e-6)
		if signf(vy) != signf(prev_vy) and absf(vy) > 0.05:
			shimmy_flips += 1     # a bounce/sec ~ real gait; 10+/sec = vibration, not walking
		prev_vy = vy
		prev_pos = cur_pos
		if i == mid_tick:
			mid_pos = cur_pos
		if i % 6 == 0:
			trajectory.append(cur_pos)
		var m: Dictionary = body.call("measure")
		var cog: Vector3 = m["cog"]
		min_cog_y = minf(min_cog_y, cog.y)
		finite = finite and bool(m["finite"])
		# Real flight phase: AFTER the spawn-drop settles, count ticks where every foot is clear of the
		# floor. A body-shift / front-leg-push cheat keeps a foot planted, so it can't earn this.
		if i >= SETTLE_TICKS and body.has_method("min_foot_bottom_y"):
			var fb := float(body.call("min_foot_bottom_y"))
			sampled_ticks += 1
			if fb > FLIGHT_CLEARANCE_M:
				airborne_ticks += 1
			max_foot_clear = maxf(max_foot_clear, fb)
		if not finite or max_com_step > TELEPORT_MAX_VEL * dt * 1.5:
			break   # M47/§C: abort before a NaN/teleport propagates (exploding chains)
		if root_body != null and (min_root_up_dot < 0.0 or start_pos.y - min_root_y > 1.0):
			break
	var grasp_carry := 0.0
	var grasp_follows := false
	if grasped and grasp_obj != null:
		grasp_carry = _horizontal_delta(grasp_obj.global_position - grasp_obj_start).length()
		grasp_follows = follow_max != -INF and (follow_max - follow_min) <= GRASP_FOLLOW_TOL
		WorldObjectScript.release_grasp(grasp_joint, grasp_obj)   # proves clean release
	var end_pos := Vector3.ZERO if root_body == null else root_body.global_position
	var delta := end_pos - start_pos
	var horizontal := _horizontal_delta(delta)
	var forward := horizontal.dot(heading)
	var lateral := horizontal.dot(right)
	# Back-half forward progress: distinguishes sustained walking from a single
	# lurch that then jams (the lurch scores high on total `forward`, ~0 here).
	var forward_tail := _horizontal_delta(end_pos - mid_pos).dot(heading)
	var end_heading := heading if root_body == null else _horizontal_axis(root_body.global_basis, p.forward_axis)
	var yaw_delta := wrapf(_yaw_from_heading(end_heading) - start_yaw, -PI, PI)
	var energy := float(ctrl.call("total_energy"))
	var final_measure: Dictionary = body.call("measure")
	var mass := float(final_measure.get("total_mass", 0.0))
	var cot := energy / maxf(mass * CE.GRAVITY * absf(forward), 0.000001)
	var assist: Dictionary = ctrl.call("assist_metrics", forward)
	var spring: Dictionary = ctrl.call("spring_metrics")
	var tendon: Dictionary = ctrl.call("tendon_metrics")
	var root_height_drop := start_pos.y - min_root_y
	var straightness := forward / maxf(path_len, 0.000001)
	var theta_span := 0.0 if theta_min == INF or theta_max == -INF else theta_max - theta_min
	# M60: 1.0 = perfectly coherent wave (or N/A for <3 driven segments, so non-undulators aren't
	# penalized); lower = scrambled segment phases.
	var phase_coherence := 1.0 if phase_coherence_ticks == 0 \
			else phase_coherence_sum / float(phase_coherence_ticks)
	# Exploit metrics: skating (sideways vs total), spinning (turn accumulated/sec),
	# pogo (vertical excursion vs spawn height).
	var lateral_ratio := absf(lateral) / maxf(absf(forward) + absf(lateral), 0.000001)
	var yaw_rate := total_yaw / maxf(p.horizon_s, 0.000001)
	var bounce := (max_root_y - min_root_y) if max_root_y > -INF else 0.0
	var bounce_ratio := bounce / maxf(start_pos.y, 0.000001)
	var airborne_frac := float(airborne_ticks) / maxf(float(sampled_ticks), 1.0)
	var fell := min_cog_y < -0.25 or min_root_up_dot < MIN_ROOT_UP_DOT \
			or root_height_drop > MAX_ROOT_HEIGHT_DROP_M or not finite
	var assist_ceiling := p.assist_ratio_ceiling if p.assist_ratio_ceiling >= 0.0 else MAX_ASSIST_RATIO
	var slip_ceiling := p.slip_ratio_ceiling if p.slip_ratio_ceiling >= 0.0 else MAX_SLIP_RATIO
	var slip_ratio := float(assist.get("slip_ratio", 0.0))
	var locomotion := classify_locomotion(forward, forward_tail, straightness, yaw_delta,
			min_root_up_dot, root_height_drop, finite,
			float(assist["assist_per_meter"]), float(assist["assist_ratio"]),
			lateral_ratio, yaw_rate, theta_span, max_omega, assist_ceiling,
			slip_ratio, slip_ceiling)
	var diagnosis := _locomotion_diagnosis(locomotion, forward, forward_tail, straightness,
			min_root_up_dot, root_height_drop, lateral_ratio, yaw_rate, theta_span, max_omega,
			float(assist["assist_per_meter"]), float(assist["assist_ratio"]), slip_ratio)
	var measured := {
		"ok": finite,
		"seed": p.seed,
		"horizon_s": p.horizon_s,
		"ticks": ran_ticks,
		"heading": heading,
		"displacement": horizontal,
		"trajectory": trajectory,
		"forward": forward,
		"forward_distance": forward,
		"forward_tail": forward_tail,
		"lateral_distance": lateral,
		"path_len": path_len,
		"straightness": straightness,
		"mean_speed": forward / maxf(p.horizon_s, 0.000001),
		"yaw_delta": yaw_delta,
		"root_up_min": min_root_up_dot,
		"root_height_drop": root_height_drop,
		"shimmy_per_s": shimmy_flips / maxf(p.horizon_s, 0.000001),   # motion smoothness (low = clean)
		"bounce": bounce,
		"airborne_frac": airborne_frac,
		"max_foot_clear": max_foot_clear,
		# REAL contact metrics (Jolt contact_monitor) — the honest motion shape. -1 when not sensed
		# (sense_contacts off) so callers never mistake "not measured" for "never touched".
		"true_airborne_frac": (float(true_air_ticks) / maxf(float(ground_sampled), 1.0)) if p.sense_contacts else -1.0,
		"body_drag_frac": (float(nonfoot_touch_ticks) / maxf(float(ground_sampled), 1.0)) if p.sense_contacts else -1.0,
		"foot_contact_frac": (float(foot_touch_ticks) / maxf(float(ground_sampled), 1.0)) if p.sense_contacts else -1.0,
		"foot_plants": foot_plants if p.sense_contacts else -1,
		"feet_lifted_ever": feet_lifted_ever,
		"drag_parts": drag_parts,
		"theta_span": theta_span,
		"max_omega": max_omega,
		"phase_coherence": phase_coherence,
		"credible_walk": bool(locomotion["credible_walk"]),
		"locomotion_class": locomotion["class"],
		"locomotion_reasons": locomotion["reasons"],
		"locomotion_diagnosis": diagnosis,
		"distance": forward,
		"distance_abs": Vector2(delta.x, delta.z).length(),
		"lateral": lateral,
		"stability": maxf(min_cog_y, -10.0),
		"energy": energy,
		"spring_energy_stored": float(spring.get("spring_energy_stored", 0.0)),
		"spring_energy_released": float(spring.get("spring_energy_released", 0.0)),
		"spring_return_work": float(spring.get("spring_return_work", 0.0)),
		"tendon_energy_stored": float(tendon.get("tendon_energy_stored", 0.0)),
		"tendon_energy_released": float(tendon.get("tendon_energy_released", 0.0)),
		"cost_of_transport": cot,
		"traction_impulse": float(assist["traction_impulse"]),
		"posture_impulse": float(assist["posture_impulse"]),
		"assist_work": float(assist["assist_work"]),
		"assist_per_meter": float(assist["assist_per_meter"]),
		"assist_ratio": float(assist["assist_ratio"]),
		"assist_ratio_ceiling": assist_ceiling,
		"mean_foot_slip": float(assist.get("mean_foot_slip", 0.0)),
		"slip_ratio": slip_ratio,
		"slip_ratio_ceiling": slip_ceiling,
		"max_com_step": max_com_step,
		"teleport": max_com_step > TELEPORT_MAX_VEL * dt * 1.5,
		"lateral_ratio": lateral_ratio,
		"yaw_rate": yaw_rate,
		"bounce_ratio": bounce_ratio,
		"fell": fell,
		"drive_count": int(ctrl.call("drive_count")),
		"spring_drive_count": int(ctrl.call("spring_drive_count")),
		"contact_subset_drives": int(ctrl.call("contact_subset_drive_count")),
		"torn_joints": int(final_measure.get("torn_joints", 0)),
		"reach_used": reach != null and int(reach.call("effector_index")) >= 0,
		"reach_effector_index": -1 if reach == null else int(reach.call("effector_index")),
		"reach_distance": INF if reach == null else float(reach.call("last_distance")),
		"grasp_grasped": grasped,
		"grasp_ticks": grasp_ticks,
		"grasp_carry": grasp_carry,
		"grasp_follows": grasp_follows,
	}
	# M38: mode-aware credibility. The objective mode is the track's hint; the achieved
	# mode is detected from behaviour (a ball-roller on a walk track is
	# scored under `roll`, not failed under `walk`). The strict walk classification above
	# is preserved unchanged for back-compat; these are additive.
	var objective_mode: StringName = &"walk"
	if p.track != null and p.track.has_method("objective_mode"):
		objective_mode = p.track.objective_mode()
	var achieved_mode := detect_mode(measured)
	var mode_verdict := classify_mode(achieved_mode, measured, assist_ceiling, slip_ceiling)
	measured["objective_mode"] = objective_mode
	measured["achieved_mode"] = achieved_mode
	measured["mode_class"] = mode_verdict["class"]
	measured["mode_credible"] = bool(mode_verdict["credible"])
	measured["mode_reasons"] = mode_verdict["reasons"]
	if p.track != null and p.track.has_method("collect_metrics"):
		measured.merge(p.track.collect_metrics(measured), true)
	host.queue_free()
	await _flush_tree(tree)
	return measured


static func run_combat_contact(attacker_gene: PartGene, defender_gene: PartGene,
		tree: SceneTree, params: CombatParams = null) -> Dictionary:
	if attacker_gene == null or defender_gene == null or tree == null:
		return {"ok": false, "error": "missing attacker/defender/tree"}
	await _flush_tree(tree)
	var p := params if params != null else CombatParams.new()
	var host := _make_rollout_host()
	var world := Node3D.new()
	host.add_child(world)
	tree.root.add_child(host)
	await _flush_tree(tree)
	SimWorldScript.add_floor(world, p.floor_friction)
	var attacker_params := CreatureBodyScript.BuildParams.new()
	attacker_params.creature_id = &"attacker"
	attacker_params.contact_monitor = true
	attacker_params.max_contacts_reported = 16
	var defender_params := CreatureBodyScript.BuildParams.new()
	defender_params.creature_id = &"defender"
	defender_params.contact_monitor = true
	defender_params.max_contacts_reported = 16
	var ay := _spawn_y(attacker_gene)
	var dy := _spawn_y(defender_gene)
	var attacker: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(attacker_gene),
			Transform3D(Basis.IDENTITY, Vector3(0.0, ay, 1.0)), attacker_params)
	var defender: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(defender_gene),
			Transform3D(Basis.IDENTITY, Vector3(0.0, dy, 0.0)), defender_params)
	world.add_child(attacker)
	world.add_child(defender)
	for rb in attacker.call("part_bodies"):
		if rb is RigidBody3D:
			(rb as RigidBody3D).linear_velocity = Vector3(0.0, 0.0, -absf(p.strike_speed))
			(rb as RigidBody3D).set_meta("pre_contact_speed", absf(p.strike_speed))
	var ticks := maxi(1, int(round(p.horizon_s / maxf(p.fixed_dt, 0.000001))))
	var best_row := {}
	var best_result := {}
	var contact_rows: Array[Dictionary] = []
	for _i in ticks:
		await tree.physics_frame
		var rows := CombatResolverScript.capture_contact_rows(attacker, defender)
		if rows.is_empty():
			continue
		for row in rows:
			contact_rows.append(row.duplicate(true))
			if float(row.get("normal_impulse_proxy", 0.0)) < p.impulse_threshold:
				continue
			var result := CombatResolverScript.resolve_contact_row(attacker_gene, defender_gene, row)
			if best_result.is_empty() or float(result.get("damage", 0.0)) > float(best_result.get("damage", 0.0)):
				best_row = row
				best_result = result
		if not best_result.is_empty():
			break
	var torn := 0
	if not best_result.is_empty() and float(best_row.get("normal_impulse_proxy", 0.0)) > p.impulse_threshold * 8.0 \
			and defender.has_method("drive_joints"):
		var drives: Array = defender.call("drive_joints")
		if not drives.is_empty():
			var tear_part := int((drives[0] as Dictionary).get("part_index", -1))
			if defender.call("tear_joint", tear_part, "combat_contact"):
				torn = int(defender.call("torn_joints"))
	host.queue_free()
	await _flush_tree(tree)
	return {
		"ok": not contact_rows.is_empty(),
		"contact_rows": contact_rows,
		"contact_count": contact_rows.size(),
		"damage": float(best_result.get("damage", 0.0)),
		"defender_alive": bool(best_result.get("defender_alive", true)),
		"reasons": best_result.get("reasons", []),
		"result": best_result,
		"combat_torn_joints": torn,
		"synthetic_contact": false,
	}


# REAL per-part ground contact via Jolt contact monitoring (needs body_params.contact_monitor).
# Returns a bool per part body: is it currently touching the floor? This is the ground truth the
# geometric foot-bottom heuristic could not give (it over-read on tilted/splayed feet).
static func _parts_on_floor(bodies: Array, floor_body: Node) -> Array:
	var out: Array = []
	for b in bodies:
		var touching := false
		if b is RigidBody3D and (b as RigidBody3D).contact_monitor:
			for other in (b as RigidBody3D).get_colliding_bodies():
				if other != null and (other == floor_body or String(other.name) == "SimFloor"):
					touching = true
					break
		out.append(touching)
	return out


static func _make_rollout_host() -> Node:
	var viewport := SubViewport.new()
	viewport.name = "IsolatedRolloutWorld"
	viewport.disable_3d = false
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return viewport


static func _add_floor(parent: Node3D) -> void:
	SimWorldScript.add_floor(parent, 1.0)


static func _horizontal_axis(basis: Basis, local_axis: Vector3) -> Vector3:
	var axis := basis * local_axis.normalized()
	axis.y = 0.0
	if axis.length() < 0.000001:
		return Vector3.FORWARD
	return axis.normalized()


static func _horizontal_delta(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _yaw_from_heading(heading: Vector3) -> float:
	return atan2(heading.x, heading.z)


static func _flush_tree(tree: SceneTree) -> void:
	for _i in FLUSH_TICKS:
		await tree.process_frame
		await tree.physics_frame


# Public: the LocomotionViewer calls this so the editor's live "Watch it walk" spawns at the exact same
# height as the measured rollout (single source of truth for the walker-aware standing spawn).
static func spawn_y(root_gene: PartGene) -> float:
	return _spawn_y(root_gene)


static func _spawn_y(root_gene: PartGene) -> float:
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	var min_y := 0.0
	for p in fold["parts"]:
		min_y = minf(min_y, p.world_aabb.position.y)
	# A honest legged walker stands on its feet — spawn it with its soles just above the floor (a small
	# settle gap) instead of dropping it. The 0.4 m free-fall drop (fine for limp/dropped creatures) slams
	# a tall-legged walker into a collapsed, pitched pose its extensors can't recover from. It holds its
	# stance during the settle ticks, so it lands gently on its feet at full leg extension.
	if _is_leg_walker(root_gene):
		return -min_y + 0.03
	return maxf(0.4 - min_y, 0.6)


# True for creatures whose gene opts into the reference-tracking leg walker (honest + a walk/trot/lateral
# gait) — mirrors CpgController._build_leg_plan's gate, so the spawn matches how the controller drives it.
static func _is_leg_walker(root_gene: PartGene) -> bool:
	if root_gene == null or root_gene.gait == null:
		return false
	if not root_gene.tags.has(&"honest"):
		return false
	var m: StringName = root_gene.gait.locomotion_mode
	return m == &"walk" or m == &"trot" or m == &"side_scuttle" or m == &"lateral"


static func classify_locomotion(forward: float, forward_tail: float, straightness: float,
		yaw_delta: float, root_up_min: float, root_height_drop: float, finite: bool,
		assist_per_meter := 0.0, assist_ratio := 0.0,
		lateral_ratio := 0.0, yaw_rate := 0.0, theta_span := 1.0, max_omega := 1.0,
		assist_ratio_ceiling := MAX_ASSIST_RATIO,
		slip_ratio := 0.0, slip_ratio_ceiling := MAX_SLIP_RATIO) -> Dictionary:
	var reasons: Array[String] = []
	if not finite:
		reasons.append("non-finite sim")
	if root_up_min < MIN_ROOT_UP_DOT:
		reasons.append("root tipped over")
	if root_height_drop > MAX_ROOT_HEIGHT_DROP_M:
		reasons.append("root height collapsed")
	if forward < CREDIBLE_FORWARD_M:
		reasons.append("forward distance below %.1fm" % CREDIBLE_FORWARD_M)
	if forward_tail < CREDIBLE_TAIL_M:
		reasons.append("back-half progress below %.2fm" % CREDIBLE_TAIL_M)
	if straightness < MIN_STRAIGHTNESS:
		reasons.append("low straightness")
	if absf(yaw_delta) > MAX_YAW_FOR_CREDIBLE:
		reasons.append("excess yaw/spin")
	if assist_per_meter > MAX_ASSIST_PER_METER:
		reasons.append("assist per meter above budget")
	if assist_ratio > assist_ratio_ceiling:
		reasons.append("assist ratio above budget")
	if lateral_ratio > MAX_LATERAL_RATIO:
		reasons.append("sideways skating")
	if yaw_rate > MAX_YAW_RATE:
		reasons.append("spinning")
	# M37: stance feet sliding nearly as far as the body travelled = riding ground
	# reaction without planting. assist_ratio is blind to this; slip catches it.
	if slip_ratio > slip_ratio_ceiling:
		reasons.append("slip_or_skid")
	# Real stepping required: a rigid body slid forward by the traction assist has
	# near-zero hinge swing. This is the true anti-"ride the assist" gate.
	if theta_span < MIN_THETA_SPAN or max_omega < MIN_MAX_OMEGA:
		reasons.append("rigid (no leg motion)")
	var cls: StringName = &"credible_walk"
	if reasons.has("non-finite sim") or reasons.has("root tipped over") or reasons.has("root height collapsed"):
		cls = &"fall_or_tip"
	elif forward < CREDIBLE_FORWARD_M:
		cls = &"too_short"
	elif forward_tail < CREDIBLE_TAIL_M:
		cls = &"lurch_or_jam"
	elif reasons.has("rigid (no leg motion)") or reasons.has("assist per meter above budget") \
			or reasons.has("assist ratio above budget"):
		cls = &"assist_carried"
	elif lateral_ratio > MAX_LATERAL_RATIO or straightness < MIN_STRAIGHTNESS \
			or absf(yaw_delta) > MAX_YAW_FOR_CREDIBLE or yaw_rate > MAX_YAW_RATE \
			or reasons.has("slip_or_skid"):
		cls = &"skate_or_spin"
	return {
		"credible_walk": reasons.is_empty(),
		"class": cls,
		"reasons": reasons,
	}


# ===================== M38: mode-aware credibility =====================
# The verdict splits into a UNIVERSAL FLOOR (cheat-proof, every mode) + per-mode GESTURES
# (shape expectations). The strict `walk` gate is classify_locomotion() above — UNCHANGED,
# so existing champions classify identically. Non-walk modes relax the walk-shaped checks
# (clearance/straightness/yaw) while keeping the floor. Reserved swim/fly/climb dispatch
# now and return `unsupported_mode` until their force model ships (additive, see §5).

# The cheat-proof floor every mode must clear regardless of gesture: finite sim, assist
# under budget, no teleport, and conservative springs (Principle 14: released <= stored).
# slip is included but contact-subset/rolling gestures erase it (no plantable stance foot).
static func universal_floor(m: Dictionary, assist_ceiling := MAX_ASSIST_RATIO,
		slip_ceiling := MAX_SLIP_RATIO) -> Array[String]:
	var reasons: Array[String] = []
	if not bool(m.get("ok", true)):
		reasons.append("non-finite sim")
	if float(m.get("assist_ratio", 0.0)) > assist_ceiling:
		reasons.append("assist ratio above budget")
	if float(m.get("slip_ratio", 0.0)) > slip_ceiling:
		reasons.append("slip_or_skid")
	if bool(m.get("teleport", false)):
		reasons.append("teleport (non-physical CoM jump)")
	var stored := float(m.get("spring_energy_stored", 0.0))
	var released := float(m.get("spring_energy_released", 0.0))
	if released > stored * 1.05 + 0.0001:
		reasons.append("spring returned more than it stored")
	return reasons


# Detect the ACHIEVED mode from behaviour: the objective/track mode is
# only a hint. A ball-roller on a walk track is scored under `roll`, not failed under `walk`.
static func detect_mode(m: Dictionary) -> StringName:
	var yaw_rate := float(m.get("yaw_rate", 0.0))
	var bounce_ratio := float(m.get("bounce_ratio", 0.0))
	var lateral_ratio := float(m.get("lateral_ratio", 0.0))
	var root_up := float(m.get("root_up_min", 1.0))
	if yaw_rate > MAX_YAW_RATE and root_up < MIN_ROOT_UP_DOT:
		return &"roll"                                  # spinning at low CoM = rolling
	if bounce_ratio > 0.6:
		return &"hop"                                   # clear vertical excursion = hopping
	if lateral_ratio > MAX_LATERAL_RATIO:
		return &"lateral"                               # sideways-dominant = scuttle
	return &"walk"


# Score a rollout under one mode. Reserved modes short-circuit to unsupported_mode.
static func classify_mode(mode: StringName, m: Dictionary,
		assist_ceiling := MAX_ASSIST_RATIO, slip_ceiling := MAX_SLIP_RATIO) -> Dictionary:
	if RESERVED_MODES.has(mode):
		return {"credible": false, "class": &"unsupported_mode", "mode": mode,
			"reasons": ["%s needs a force model not yet shipped (see Deferred §5)" % String(mode)]}
	var floor := universal_floor(m, assist_ceiling, slip_ceiling)
	match mode:
		&"hop":
			return _gesture_hop(m, floor)
		&"lateral":
			return _gesture_lateral(m, floor)
		&"undulation", &"undulate":
			return _gesture_undulation(m, floor)
		&"roll":
			return _gesture_roll(m, floor)
		&"pogo", &"radial":
			return _gesture_pogo(m, floor)
		&"fly", &"glide":
			return _gesture_fly(m, floor)
		_:
			return _gesture_walk(m, floor)


# walk gesture == the strict gate. Recompute from the dict so a synthetic m classifies
# identically to a live one (the floor is a subset of these checks).
static func _gesture_walk(m: Dictionary, floor: Array[String]) -> Dictionary:
	var w := classify_locomotion(
		float(m.get("forward", 0.0)), float(m.get("forward_tail", 0.0)),
		float(m.get("straightness", 0.0)), float(m.get("yaw_delta", 0.0)),
		float(m.get("root_up_min", 1.0)), float(m.get("root_height_drop", 0.0)),
		bool(m.get("ok", true)),
		float(m.get("assist_per_meter", 0.0)), float(m.get("assist_ratio", 0.0)),
		float(m.get("lateral_ratio", 0.0)), float(m.get("yaw_rate", 0.0)),
		float(m.get("theta_span", 1.0)), float(m.get("max_omega", 1.0)),
		float(m.get("assist_ratio_ceiling", MAX_ASSIST_RATIO)),
		float(m.get("slip_ratio", 0.0)), float(m.get("slip_ratio_ceiling", MAX_SLIP_RATIO)))
	# Floor adds checks classify_locomotion doesn't have (spring-conservative, teleport);
	# surface them so a walk-shaped gait that broke a universal invariant says why.
	var reasons: Array[String] = floor.duplicate()
	for r in w["reasons"]:
		if not reasons.has(r):
			reasons.append(r)
	var cls: StringName = w["class"]
	if bool(w["credible_walk"]) and not floor.is_empty():
		cls = &"floor_violation"
	return {"credible": reasons.is_empty(), "class": cls, "mode": &"walk", "reasons": reasons}


# hop: require a flight phase (bounce) + ballistic apex + actuation; yaw relaxed.
static func _gesture_hop(m: Dictionary, floor: Array[String]) -> Dictionary:
	var reasons := floor.duplicate()
	if absf(float(m.get("forward", 0.0))) < CREDIBLE_FORWARD_M * 0.5:
		reasons.append("hop distance below floor")
	if float(m.get("bounce", 0.0)) < 0.20:
		reasons.append("no flight phase (bounce)")
	if float(m.get("theta_span", 0.0)) < 0.20 or float(m.get("max_omega", 0.0)) < 0.35:
		reasons.append("no spring-leg actuation")
	if bool(m.get("fell", false)):
		reasons.append("fell during hop")
	return {"credible": reasons.is_empty(),
		"class": &"hopped" if reasons.is_empty() else &"hop_failed",
		"mode": &"hop", "reasons": reasons}


# lateral: score sideways; relax forward straightness.
static func _gesture_lateral(m: Dictionary, floor: Array[String]) -> Dictionary:
	var reasons := floor.duplicate()
	var lateral := absf(float(m.get("lateral", 0.0)))
	if lateral < CREDIBLE_FORWARD_M * 0.5:
		reasons.append("lateral distance below floor")
	if float(m.get("lateral_ratio", 0.0)) < 0.6 or lateral <= absf(float(m.get("forward", 0.0))):
		reasons.append("movement was not side-dominant")
	if float(m.get("theta_span", 0.0)) < 0.20 or float(m.get("max_omega", 0.0)) < 0.35:
		reasons.append("no side-leg actuation")
	if bool(m.get("fell", false)):
		reasons.append("fell during lateral gait")
	return {"credible": reasons.is_empty(),
		"class": &"lateral_scuttle" if reasons.is_empty() else &"lateral_failed",
		"mode": &"lateral", "reasons": reasons}


# undulation: foot-clearance exempt; require net translation + real body-wave articulation AND a
# phase-coherent traveling wave (M60: phase_coherence is a real per-segment measure, not the old
# theta_span-only proxy).
static func _gesture_undulation(m: Dictionary, floor: Array[String]) -> Dictionary:
	var reasons := floor.duplicate()
	reasons.erase("slip_or_skid")            # a dragging serpent has no plantable stance foot
	if absf(float(m.get("distance_abs", 0.0))) < CREDIBLE_FORWARD_M * 0.4:
		reasons.append("undulation net translation below floor")
	if float(m.get("theta_span", 0.0)) < 0.20 or float(m.get("max_omega", 0.0)) < 0.35:
		reasons.append("no body-wave articulation")
	if float(m.get("phase_coherence", 1.0)) < 0.3:
		reasons.append("body wave not phase-coherent")
	if bool(m.get("fell", false)):
		reasons.append("body collapsed")
	return {"credible": reasons.is_empty(),
		"class": &"undulated" if reasons.is_empty() else &"undulate_failed",
		"mode": &"undulation", "reasons": reasons}


# roll: allow spin/yaw; score net displacement at low CoM.
static func _gesture_roll(m: Dictionary, floor: Array[String]) -> Dictionary:
	var reasons := floor.duplicate()
	reasons.erase("slip_or_skid")            # a rolling body has no stance foot at all
	if absf(float(m.get("distance_abs", 0.0))) < CREDIBLE_FORWARD_M * 0.4:
		reasons.append("roll net displacement below floor")
	return {"credible": reasons.is_empty(),
		"class": &"rolled" if reasons.is_empty() else &"roll_failed",
		"mode": &"roll", "reasons": reasons}


# pogo/radial: no heading; net drift from contact-subset firing (measured-only, M39).
static func _gesture_pogo(m: Dictionary, floor: Array[String]) -> Dictionary:
	var reasons := floor.duplicate()
	reasons.erase("slip_or_skid")            # contact-subset firing slides by design
	if absf(float(m.get("distance_abs", 0.0))) < CREDIBLE_FORWARD_M * 0.3:
		reasons.append("pogo net drift below floor")
	return {"credible": reasons.is_empty(),
		"class": &"pogo_drift" if reasons.is_empty() else &"pogo_failed",
		"mode": &"pogo", "reasons": reasons}


# M52 fly/glide: airborne net translation while staying aloft. Foot-clearance/slip are exempt (no
# ground contact); the floor's finite + spring-conservative + no-teleport still bind. Aero force is
# applied at the wings (WingBody), never the root.
static func _gesture_fly(m: Dictionary, floor: Array[String]) -> Dictionary:
	var reasons := floor.duplicate()
	reasons.erase("slip_or_skid")            # no stance foot in the air
	if absf(float(m.get("distance_abs", 0.0))) < CREDIBLE_FORWARD_M * 0.4:
		reasons.append("flight net translation below floor")
	return {"credible": reasons.is_empty(),
		"class": &"flew" if reasons.is_empty() else &"flight_failed",
		"mode": &"fly", "reasons": reasons}


static func _locomotion_diagnosis(locomotion: Dictionary, forward: float, forward_tail: float,
		straightness: float, root_up_min: float, root_height_drop: float,
		lateral_ratio: float, yaw_rate: float, theta_span: float, max_omega: float,
		assist_per_meter: float, assist_ratio: float, slip_ratio := 0.0) -> Dictionary:
	return {
		"credible": bool(locomotion.get("credible_walk", false)),
		"class": locomotion.get("class", &"unknown"),
		"reasons": locomotion.get("reasons", []),
		"metrics": {
			"forward": forward,
			"forward_tail": forward_tail,
			"straightness": straightness,
			"root_up_min": root_up_min,
			"root_height_drop": root_height_drop,
			"lateral_ratio": lateral_ratio,
			"yaw_rate": yaw_rate,
			"theta_span": theta_span,
			"max_omega": max_omega,
			"assist_per_meter": assist_per_meter,
			"assist_ratio": assist_ratio,
			"slip_ratio": slip_ratio,
		},
	}
