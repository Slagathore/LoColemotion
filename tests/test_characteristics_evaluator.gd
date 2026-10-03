extends SceneTree
## Golden-creature harness for CharacteristicsEvaluator (Foundry P0 acceptance set).
##
## Run headless:  godot --headless --script res://tests/test_characteristics_evaluator.gd
## Exit code 0 = all pass, 1 = at least one failure.
##
## Assertions are RELATIONAL / invariant-based on purpose: scale-invariance, ordering,
## and "different layout -> different stats" hold regardless of debt/reach tuning
## (see EVALUATOR_PATCH.md TUNING-1/2), so this harness stays green while you tune.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const JointModel := preload("res://scripts/sim/joint_model.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== CharacteristicsEvaluator golden tests ===")
	_test_quad_walker_good()
	_test_top_heavy_tower_broken()
	_test_arrangement_proof()
	_test_stand_feasibility_gate()
	_test_scale_invariance()
	_test_heart_spam_diminishing()
	_test_no_heart_starved()
	_test_graft_payment_and_chimera()
	_test_cycle_guard_no_crash()
	_test_default_equivalence()
	_test_gait_scale_invariance()
	_test_gait_determinism()
	_test_rom_clamp_reduces_throw()
	_test_finite_torque_cap_and_muscle_monotonic()
	_test_muscle_location_monotonic()
	_test_core_muscle_assists_muscled_limbs()
	_test_missing_vitals_are_dead_unless_perked()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# ----------------------------- mini assert harness -----------------------------

func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)

func _finite(v) -> bool:
	if v is float or v is int:
		return is_finite(float(v))
	if v is Vector3:
		return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
	return true

func _approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


# ----------------------------- creature builders -----------------------------

func _def(part_type: StringName, density: float, extents: Vector3,
		centroid := Vector3.ZERO) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	d.centroid_offset = centroid
	return d

func _socket(pos: Vector3, hinge := Vector3.ZERO, id: StringName = &"") -> SocketDef:
	var s := SocketDef.new()
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = hinge
	s.id = id
	return s

func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null,
		scale := Vector3.ONE) -> PartGene:
	var g := PartGene.new()
	g.definition = defn
	var tarr: Array[StringName] = []
	for t in tags:
		tarr.append(t)
	g.tags = tarr
	g.socket = socket
	g.scale = scale
	return g

# Parametric quadruped. s scales all lengths; front=true clusters all legs forward.
func _make_quad(s: float, front: bool) -> PartGene:
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8) * s), [&"spine"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.30, 0.30, 0.30) * s),
			[&"heart"], _socket(Vector3.ZERO)))
	root.children.append(_gene(_def(&"box", 600.0, Vector3(0.18, 0.18, 0.18) * s),
			[&"brain"], _socket(Vector3(0.0, 0.1, 0.0) * s)))
	var leg := _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1) * s)
	var pos: Array
	if front:
		pos = [Vector3(-0.4, -0.2, 0.3), Vector3(0.4, -0.2, 0.3),
				Vector3(-0.4, -0.2, 0.7), Vector3(0.4, -0.2, 0.7)]
	else:
		pos = [Vector3(-0.4, -0.2, -0.6), Vector3(0.4, -0.2, -0.6),
				Vector3(-0.4, -0.2, 0.6), Vector3(0.4, -0.2, 0.6)]
	for p in pos:
		root.children.append(_gene(leg, [&"locomotor", &"ground_contact"],
				_socket(p * s, Vector3(1, 0, 0))))
	root.children.append(_gene(_def(&"sphere", 350.0, Vector3(0.15, 0.10, 0.15) * s),
			[&"lung"], _socket(Vector3(0.0, 0.05, 0.16) * s)))
	return root


# ----------------------------- tests -----------------------------

func _test_quad_walker_good() -> void:
	print("- quad_walker (good)")
	var r := CE.evaluate(_make_quad(1.0, false))
	_check(r["status"]["ok"], "status.ok")
	_check(bool(r["balance"]["stable"]), "balance.stable == true")
	_check(float(r["balance"]["balance_margin"]) > 0.0, "balance_margin > 0")
	_check(float(r["speed"]["value"]) > 0.0, "speed > 0 (>=2 locomotors)")
	_check(r["traits"].has(&"quadruped"), "trait quadruped")
	_check(_finite(r["debt"]["debt_total"]) and float(r["debt"]["debt_total"]) <= 1.0, "debt_total finite in range")
	var valid := [&"passed", &"no_translation", &"tipped", &"no_gait"]
	_check(valid.has(r["probe"]["verdict"]), "probe verdict valid (not exploded/NaN)")
	_check(_finite(r["probe"]["distance"]), "probe distance finite")
	_check(_finite(r["cog"]), "cog finite")


func _test_top_heavy_tower_broken() -> void:
	print("- top_heavy_tower (broken)")
	# Vertical column of 4 capsules; only the base touches ground; heart at the tip.
	var root := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.2, 0.3)), [&"spine", &"ground_contact"])
	var parent := root
	for i in 4:
		var seg := _gene(_def(&"capsule", 1000.0, Vector3(0.12, 0.6, 0.12)),
				[&"locomotor"], _socket(Vector3(0, 1.1, 0)), Vector3.ONE)
		parent.children.append(seg)
		parent = seg
	parent.children.append(_gene(_def(&"box", 800.0, Vector3(0.1, 0.1, 0.1)),
			[&"heart"], _socket(Vector3(0, 0.6, 0))))
	var r := CE.evaluate(root)
	# A centered tower IS horizontally stable (large balance_margin) — that's truthful, not a
	# bug. Its top-heaviness is reported as tip_risk (low tilt headroom), so assert the engine
	# RAISES that warning rather than demanding it call the build "unstable". (Cole's call.)
	_check(bool(r["balance"]["tip_risk"]), "top-heavy tower flagged tip_risk (likely to tip over)")
	_check(float(r["balance"]["tip_angle"]) < 0.30, "low tilt headroom (< ~17 deg)")
	_check(float(r["speed"]["value"]) == 0.0 or float(r["debt"]["debt_total"]) > 0.4,
			"collinear legs / high debt")
	var worst := 0.0
	for wp in r["weak_points"]:
		worst = maxf(worst, float(wp.severity))
	_check(worst >= 0.7, "a weak point with severity >= 0.7 (starved tip)")
	_check(r["probe"]["verdict"] != &"passed", "probe does NOT pass")
	_check(_finite(r["cog"]) and _finite(r["debt"]["debt_total"]), "no NaN anywhere")


func _test_arrangement_proof() -> void:
	print("- arrangement proof (identical inventory, centered vs front-loaded)")
	var c := CE.evaluate(_make_quad(1.0, false))
	var f := CE.evaluate(_make_quad(1.0, true))
	# Same part counts.
	_check(int(c["status"]["bone_cost_total"]) == int(f["status"]["bone_cost_total"]),
			"identical bone cost (same inventory)")
	# Different stats from layout alone.
	_check(bool(c["balance"]["stable"]) and not bool(f["balance"]["stable"]),
			"centered stable, front-loaded NOT (layout flips stability)")
	_check(float(c["balance"]["balance_margin"]) > float(f["balance"]["balance_margin"]),
			"centered margin > front-loaded margin")
	_check(absf(float(f["balance"]["cog_offset_fore_aft"])) > absf(float(c["balance"]["cog_offset_fore_aft"])) + 0.1,
			"front-loaded fore-aft offset larger")


func _test_stand_feasibility_gate() -> void:
	print("- stand feasibility (GRF statics vs torque caps, leg-cognizant loads)")
	var quad: PartGene = PartCatalog.make_quadruped_v2()
	var r := CE.evaluate(quad)
	var s: Dictionary = r["stand"]
	_check(int(s["n_feet"]) == 4, "quad_v2 bears on 4 feet")
	_check(bool(s["stand_feasible"]), "quad_v2 stands with the 20% torque reserve")
	_check(bool(s["gait_feasible"]), "quad_v2 holds a 3-foot mid-step with reserve")
	_check(float(s["gait_worst_margin"]) >= float(s["worst_margin"]) - 1e-9,
			"lifting a foot never lightens the worst joint")
	# Leg-cognizant loads: mid-step concentrates weight on the survivors
	# (on a square stance the lifted foot's diagonal partner ~doubles).
	var stand_max := 0.0
	for l in s["foot_loads"]:
		stand_max = maxf(stand_max, float(l["load"]))
	var gait_max := 0.0
	for l in s["gait_worst_loads"]:
		gait_max = maxf(gait_max, float(l["load"]))
	_check(gait_max > stand_max * 1.2, "mid-step peak foot load > 1.2x standing peak")
	# Calibration outputs: every margin row carries its muscle-sizing answer.
	var rows_ok := not (s["margins"] as Array).is_empty()
	for mrow in s["margins"]:
		if not (mrow.has("muscle_frac_needed") and mrow.has("muscle_achievable")):
			rows_ok = false
	_check(rows_ok, "margin rows carry muscle_frac_needed / muscle_achievable")
	# The 92 kg lesson: the same skeleton under a dense body saturates a leg joint.
	var heavy: PartGene = GenomeSnapshot.deep_copy(quad)
	heavy.definition = heavy.definition.duplicate()   # definitions are SHARED-IMMUTABLE
	heavy.definition.density = 2400.0                 # 300 -> 2400 kg/m3
	var sh: Dictionary = CE.evaluate(heavy)["stand"]
	_check(float(sh["worst_margin"]) > float(s["worst_margin"]) * 3.0,
			"8x body density multiplies the stance margins")
	_check(not bool(sh["gait_feasible"]), "dense body fails the mid-step torque gate")
	# No feet -> explicit infeasible with a reason, no crash.
	var blob := _gene(_def(&"box", 500.0, Vector3(0.3, 0.2, 0.4)), [&"spine"])
	var fold: Dictionary = CE.fold_graph(blob, Transform3D.IDENTITY)
	var sb := CE.compute_stand_feasibility(fold["parts"], Vector3.ZERO, 1.0, 40.0)
	_check(not bool(sb["stand_feasible"]) and String(sb["reason"]) != "",
			"no ground_contact -> infeasible with reason")


func _test_scale_invariance() -> void:
	print("- scale invariance (s=1 vs s=2 -> identical dimensionless stats)")
	var a := CE.evaluate(_make_quad(1.0, false))
	var b := CE.evaluate(_make_quad(2.0, false))
	_check(_approx(float(a["balance"]["balance_margin"]), float(b["balance"]["balance_margin"]), 1e-3),
			"balance_margin scale-invariant")
	_check(_approx(float(a["balance"]["tip_angle"]), float(b["balance"]["tip_angle"]), 1e-3),
			"tip_angle scale-invariant")
	_check(_approx(float(a["balance"]["cog_offset_fore_aft"]), float(b["balance"]["cog_offset_fore_aft"]), 1e-3),
			"fore_aft offset scale-invariant")
	_check(_approx(float(a["speed"]["value"]), float(b["speed"]["value"]), 1e-3),
			"speed scale-invariant")
	_check(_approx(float(a["debt"]["debt_total"]), float(b["debt"]["debt_total"]), 1e-3),
			"debt_total scale-invariant")
	_check(a["probe"]["verdict"] == b["probe"]["verdict"], "probe verdict scale-invariant")


func _test_heart_spam_diminishing() -> void:
	print("- heart spam: 10 tiny hearts worse than 1 big (same total volume)")
	# 1 big heart, volume V (box 0.4^3 dims -> extents 0.2).
	var single := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.5, 0.5)), [&"spine"])
	single.children.append(_gene(_def(&"box", 1000.0, Vector3(0.2, 0.2, 0.2)),
			[&"heart"], _socket(Vector3.ZERO)))
	# 10 hearts each 1/10 the volume: extents scaled by (1/10)^(1/3).
	var f := pow(0.1, 1.0 / 3.0)
	var many := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.5, 0.5)), [&"spine"])
	for i in 10:
		many.children.append(_gene(_def(&"box", 1000.0, Vector3(0.2, 0.2, 0.2) * f),
				[&"heart"], _socket(Vector3(0.01 * float(i), 0, 0))))
	var rs := CE.evaluate(single)
	var rm := CE.evaluate(many)
	_check(float(rm["debt"]["metabolic_debt"]) > float(rs["debt"]["metabolic_debt"]),
			"spam metabolic_debt > single (Sigma cap / sqrt(count) penalises count)")
	_check(float(rs["debt"]["aggregate_capacity"]) > float(rm["debt"]["aggregate_capacity"]),
			"single aggregate_capacity > spam")
	_check(int(rm["debt"]["heart_count"]) == 10, "heart_count == 10")


func _test_no_heart_starved() -> void:
	print("- starved heron (no heart)")
	var root := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"])
	var neck := _gene(_def(&"capsule", 600.0, Vector3(0.08, 0.8, 0.08)),
			[&"spine"], _socket(Vector3(0, 0.6, 0)))
	root.children.append(neck)
	neck.children.append(_gene(_def(&"sphere", 600.0, Vector3(0.12, 0.12, 0.12)),
			[&"brain"], _socket(Vector3(0, 0.9, 0))))
	var r := CE.evaluate(root)
	_check(_approx(float(r["debt"]["metabolic_debt"]), 1.0, 1e-6), "metabolic_debt == 1.0 (no hearts)")
	_check(int(r["debt"]["heart_count"]) == 0, "heart_count == 0")
	var worst := 0.0
	var saw_no_heart := false
	for wp in r["weak_points"]:
		worst = maxf(worst, float(wp.severity))
		if wp.kind == &"no_heart":
			saw_no_heart = true
	_check(worst >= 0.7, "tip-organ weak point severity >= 0.7")
	_check(saw_no_heart, "weak point kind == no_heart")


func _test_graft_payment_and_chimera() -> void:
	print("- graft payment + chimera trait")
	var root := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.2, 0.2, 0.2)),
			[&"heart"], _socket(Vector3(0, 0.1, 0))))
	var g1 := _gene(_def(&"box", 600.0, Vector3(0.08, 0.08, 0.08)), [&"graft"], _socket(Vector3(0.25, 0, 0)))
	var g2 := _gene(_def(&"box", 600.0, Vector3(0.08, 0.08, 0.08)), [&"graft"], _socket(Vector3(0.2, 0, 0)))
	var eye := _gene(_def(&"sphere", 500.0, Vector3(0.06, 0.06, 0.06)), [&"attack"], _socket(Vector3(0.2, 0, 0)))
	root.children.append(g1)
	g1.children.append(g2)
	g2.children.append(eye)
	var r := CE.evaluate(root)
	_check(r["traits"].has(&"chimera"), "trait chimera (grafts present)")
	var graft_wps := 0
	for wp in r["weak_points"]:
		if wp.kind == &"graft":
			graft_wps += 1
	_check(graft_wps == 2, "each graft registers as its own weak point (the payment)")
	_check(int(r["status"]["bone_cost_total"]) >= 2 + 2, "grafts cost 2 bone each")


func _test_cycle_guard_no_crash() -> void:
	print("- cycle guard (A <-> B)")
	var a := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"])
	var b := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine"], _socket(Vector3(0.6, 0, 0)))
	a.children.append(b)
	b.children.append(a)  # cycle / reuse
	var fold := CE.fold_graph(a, Transform3D.IDENTITY)
	_check(bool(fold["cycle_detected"]), "cycle_detected == true")
	_check(fold["parts"].size() == 2, "each node resolved exactly once")
	var r := CE.evaluate(a)  # must not crash
	_check(r.has("status"), "evaluate returns a result (no crash on cyclic input)")


# ============ Gait / Joint / Muscle authoring (Forks B3 / C2 / D2 / E3) ============
# Relational like the rest: the keystone is that authoring does NOT break scale-invariance,
# and an UN-authored creature is byte-identical to the legacy probe (L4 default-equivalence).

func _joint(amp: float, rest: float, amin: float, amax: float) -> JointDef:
	var jd := JointDef.new()
	jd.amplitude = amp
	jd.rest_angle = rest
	jd.angle_min = amin
	jd.angle_max = amax
	return jd

func _gait(assignments: Dictionary) -> GaitDef:
	var gd := GaitDef.new()
	var a: Dictionary[StringName, float] = {}
	for k in assignments:
		a[k] = float(assignments[k])
	gd.assignments = a
	return gd

func _muscle(s: float) -> PartGene:
	# Small capsule tagged &"muscle"; its mass is what _subtree_muscle_frac sums. Not a locomotor,
	# rigid socket => pure dead weight in the subtree, so it only feeds the strength derivation.
	return _gene(_def(&"capsule", 1000.0, Vector3(0.06, 0.25, 0.06) * s),
			[&"muscle"], _socket(Vector3(0, -0.3, 0) * s))

# Quad with NAMED leg sockets (hip_BL/BR/FL/FR) so GaitDef.assignments can key them.
func _quad_named(s: float) -> Dictionary:
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8) * s), [&"spine"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.30, 0.30, 0.30) * s),
			[&"heart"], _socket(Vector3.ZERO)))
	root.children.append(_gene(_def(&"box", 600.0, Vector3(0.18, 0.18, 0.18) * s),
			[&"brain"], _socket(Vector3(0.0, 0.1, 0.0) * s)))
	var leg := _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1) * s)
	var specs := [
		[Vector3(-0.4, -0.2, -0.6), &"hip_BL"], [Vector3(0.4, -0.2, -0.6), &"hip_BR"],
		[Vector3(-0.4, -0.2, 0.6), &"hip_FL"], [Vector3(0.4, -0.2, 0.6), &"hip_FR"],
	]
	var legs: Array = []
	for sp in specs:
		var g := _gene(leg, [&"locomotor", &"ground_contact"], _socket(sp[0] * s, Vector3(1, 0, 0), sp[1]))
		root.children.append(g)
		legs.append(g)
	root.children.append(_gene(_def(&"sphere", 350.0, Vector3(0.15, 0.10, 0.15) * s),
			[&"lung"], _socket(Vector3(0.0, 0.05, 0.16) * s)))
	return {"root": root, "legs": legs}

# quad_named + diagonal-trot gait + a RoM-limited JointDef on each leg + a muscle in each leg subtree.
func _authored(s: float, trot: Dictionary) -> PartGene:
	var q := _quad_named(s)
	var root: PartGene = q["root"]
	root.gait = _gait(trot)
	for leg in q["legs"]:
		leg.joint = _joint(1.0, 0.0, -0.5, 0.5)
		leg.children.append(_muscle(s))
	return root


func _test_default_equivalence() -> void:
	print("- default authored fields do not perturb the base gait fixture")
	var legacy := CE.evaluate(_make_quad(1.0, false))
	var named := CE.evaluate(_quad_named(1.0)["root"])   # socket ids only; gait/joint null, no muscle
	_check(legacy["probe"]["verdict"] == named["probe"]["verdict"],
			"verdict unchanged by the added schema fields")
	_check(_approx(float(legacy["probe"]["distance"]), float(named["probe"]["distance"]), 1e-9),
			"probe distance unchanged when socket ids are the only difference")

func _test_gait_scale_invariance() -> void:
	print("- authored gait+joint+muscle PRESERVES scale-invariance (s=1 vs s=2)")
	var trot := {&"hip_FL": 0.0, &"hip_FR": 0.5, &"hip_BL": 0.5, &"hip_BR": 0.0}
	var a := CE.evaluate(_authored(1.0, trot))
	var b := CE.evaluate(_authored(2.0, trot))
	_check(_approx(float(a["balance"]["balance_margin"]), float(b["balance"]["balance_margin"]), 1e-3),
			"balance_margin scale-invariant (authored)")
	_check(_approx(float(a["balance"]["tip_angle"]), float(b["balance"]["tip_angle"]), 1e-3),
			"tip_angle scale-invariant (authored)")
	_check(a["probe"]["verdict"] == b["probe"]["verdict"], "probe verdict scale-invariant (authored)")
	# Raw probe distance/body_radius is deliberately NOT asserted scale-invariant: the probe drives a
	# FIXED wall-clock window with per-step friction while gait frequency is Froude-scaled (f ~ 1/sqrt(R)),
	# so larger creatures complete fewer cycles per window and distance/R drifts with scale. Measured:
	# legacy quad drift 1.0e-2 vs authored 7.3e-3 -- authoring drifts LESS, not more. The scale-invariant
	# CONTRACT is the VERDICT (+ balance margin / tip angle), all asserted above.

func _test_gait_determinism() -> void:
	print("- authored gait is deterministic (same eval twice -> identical)")
	var trot := {&"hip_FL": 0.0, &"hip_FR": 0.5, &"hip_BL": 0.5, &"hip_BR": 0.0}
	var a := CE.evaluate(_authored(1.0, trot))
	var b := CE.evaluate(_authored(1.0, trot))
	_check(a["probe"]["verdict"] == b["probe"]["verdict"], "verdict deterministic")
	_check(_approx(float(a["probe"]["distance"]), float(b["probe"]["distance"]), 1e-9), "distance deterministic")

func _test_rom_clamp_reduces_throw() -> void:
	print("- D2 RoM clamp narrows hinge throw (clamped separation <= open)")
	var trot := {&"hip_FL": 0.0, &"hip_FR": 0.5, &"hip_BL": 0.5, &"hip_BR": 0.0}
	var oq := _quad_named(1.0)
	var oroot: PartGene = oq["root"]
	oroot.gait = _gait(trot)
	for leg in oq["legs"]:
		leg.joint = _joint(1.0, 0.0, 0.0, 0.0)        # clamp disabled (amax <= amin)
	var tq := _quad_named(1.0)
	var troot: PartGene = tq["root"]
	troot.gait = _gait(trot)
	for leg in tq["legs"]:
		leg.joint = _joint(1.0, 0.0, -0.05, 0.05)     # tight RoM
	var ro := CE.evaluate(oroot)
	var rt := CE.evaluate(troot)
	_check(float(rt["probe"]["max_separation"]) <= float(ro["probe"]["max_separation"]) + 1e-9,
			"tight-clamp separation <= open-clamp separation")
	_check(_finite(rt["probe"]["distance"]) and _finite(ro["probe"]["distance"]), "both distances finite")

func _test_finite_torque_cap_and_muscle_monotonic() -> void:
	print("- M9A torque cap is finite at zero muscle and monotonic with local muscle")
	var i_sub := 2.5
	var no_muscle := CE.cpg_torque_cap(false, 0.0, i_sub)
	var some_muscle := CE.cpg_torque_cap(false, 0.25, i_sub)
	var more_muscle := CE.cpg_torque_cap(false, 0.50, i_sub)
	_check(is_finite(no_muscle) and no_muscle > 0.0, "zero-muscle torque cap is finite and positive")
	_check(some_muscle > no_muscle and more_muscle > some_muscle,
			"more local muscle monotonically raises torque cap")
	_check(_approx(CE.cpg_torque_cap(true, 0.25, i_sub), some_muscle, 1e-9),
			"legacy has_muscle argument no longer flips cap behavior")

func _test_muscle_location_monotonic() -> void:
	print("- E3 strength is LOCAL: leg muscle drives >= spine muscle (matched mass)")
	var trot := {&"hip_FL": 0.0, &"hip_FR": 0.5, &"hip_BL": 0.5, &"hip_BR": 0.0}
	var qa := _quad_named(1.0)
	var aroot: PartGene = qa["root"]
	aroot.gait = _gait(trot)
	for i in 4:
		aroot.children.append(_muscle(1.0))           # 4 muscle parts on the body (not in leg subtrees)
	var qb := _quad_named(1.0)
	var broot: PartGene = qb["root"]
	broot.gait = _gait(trot)
	for leg in qb["legs"]:
		leg.children.append(_muscle(1.0))             # same 4 muscle parts, one inside each leg
	var ra := CE.evaluate(aroot)
	var rb := CE.evaluate(broot)
	# Matched total muscle mass; only LOCATION differs -> isolates the strength-derivation effect.
	_check(float(rb["probe"]["distance"]) >= float(ra["probe"]["distance"]) - 1e-6,
			"leg-muscled distance >= spine-muscled distance (coarse ordering)")
	_check(_finite(ra["probe"]["distance"]) and _finite(rb["probe"]["distance"]), "both distances finite")


func _test_core_muscle_assists_muscled_limbs() -> void:
	print("- core muscle assists attached limbs only when those limbs also have muscle")
	var q0 := _quad_named(1.0)
	var root0: PartGene = q0["root"]
	var fold0 := CE.fold_graph(root0, Transform3D.IDENTITY)
	var bare := CE._subtree_muscle_frac(fold0["parts"], 3)
	root0.children.append(_muscle(1.0))
	var fold_core_only := CE.fold_graph(root0, Transform3D.IDENTITY)
	var core_only := CE._subtree_muscle_frac(fold_core_only["parts"], 3)
	(q0["legs"] as Array)[0].children.append(_muscle(1.0))
	var fold_shared := CE.fold_graph(root0, Transform3D.IDENTITY)
	var with_core := CE._subtree_muscle_frac(fold_shared["parts"], 3)
	var q1 := _quad_named(1.0)
	(q1["legs"] as Array)[0].children.append(_muscle(1.0))
	var fold_local := CE.fold_graph(q1["root"], Transform3D.IDENTITY)
	var local_only := CE._subtree_muscle_frac(fold_local["parts"], 3)
	_check(_approx(bare, 0.0, 1e-9), "bare limb has zero muscle fraction")
	_check(_approx(core_only, 0.0, 1e-9), "core muscle alone does not power an unmuscled limb")
	_check(with_core > local_only, "core muscle boosts a limb that has local muscle")
	_check(with_core < local_only + JointModel.core_muscle_frac(fold_shared["parts"]) + 1e-6,
			"core boost is discounted, not full-strength")


func _test_missing_vitals_are_dead_unless_perked() -> void:
	print("- missing heart/brain/lung makes debt fatal unless a rare explicit perk exists")
	var live := CE.evaluate(_make_quad(1.0, false))
	_check(bool(live["debt"]["alive"]) and bool(live["status"]["alive"]), "complete vitals are alive")
	var no_lung := _make_quad(1.0, false)
	no_lung.children.pop_back()
	var dead := CE.evaluate(no_lung)
	_check(not bool(dead["debt"]["alive"]) and dead["probe"]["verdict"] == &"dead",
			"missing lung marks the creature dead and skips locomotion")
	_check((dead["debt"]["fatal_reasons"] as Array).has("missing lung"),
			"fatal debt explains the missing lung")
	no_lung.tags.append(&"anaerobic")
	var perked := CE.evaluate(no_lung)
	_check(bool(perked["debt"]["alive"]), "explicit anaerobic perk waives the lung requirement")
