extends SceneTree

## M47 — creature reality. Connected anatomy (B1), exploding chains aborted (B2/§C), tournament +
## assist-annealing wired into the optimizer (B3/E2), and the biarticular tendon (E4) + muscle demo.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const GaitOptimizerScript := preload("res://scripts/sim/gait_optimizer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== M47 creature-reality tests ===")
	_test_anatomy_connected()
	_test_tendon_round_trips()
	await _test_chain_stays_finite()
	_test_muscle_raises_torque_cap()
	await _test_tendon_conservative()
	await _test_tournament_wired()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# B1/E1: parts attach by their PROXIMAL END, not their centroid.
func _test_anatomy_connected() -> void:
	print("- limb segments anchor by proximal end (no centroid gap)")
	# A _piece-built pregen leg part now has a non-identity child_anchor (the fix marker).
	var frog := PartCatalog.make_frog_v2()
	var hip := _find_by_socket_id(frog, "frog_L_femur")   # M60 frog rebuild: femur is the hip segment
	_check(hip != null and hip.socket != null and hip.socket.child_anchor.origin.y < -0.01,
			"frog leg segment is anchored by its proximal end, not centroid (IDENTITY)")
	# The chained demo leg folds CONNECTED: upper & lower centers are exactly half-lengths apart.
	var parts: Array = CE.fold_graph(PartCatalog.make_demo_creature(&"bare"), Transform3D.IDENTITY)["parts"]
	var up = _fold_by_id(parts, "demo_FL_upper")
	var lo = _fold_by_id(parts, "demo_FL_lower")
	_check(up != null and lo != null, "demo chain parts fold")
	if up != null and lo != null:
		var want: float = (up.dims.y + lo.dims.y) * 0.5   # end-to-end => centers a half-length+half apart
		var got: float = up.com_world.distance_to(lo.com_world)
		print("  demo chain center-gap got=%.3f want=%.3f" % [got, want])
		_check(absf(got - want) < 0.06, "upper/lower segments are connected end-to-end (no gap)")


func _test_tendon_round_trips() -> void:
	print("- TendonDef survives GenomeSnapshot round-trip")
	var g := PartCatalog.make_demo_creature(&"tendon")
	var restored := GenomeSnapshot.from_dictionary(JSON.parse_string(JSON.stringify(
			GenomeSnapshot.to_dictionary(g))))
	var up := _find_by_id(restored, "demo_FL_upper")
	_check(up != null and up.tendon != null and up.tendon.partner_part_id == &"demo_FL_lower",
			"authored tendon + partner survive reload")


# B2/§C: long serpent/centipede chains stay finite (softening + teleport abort), don't explode.
func _test_chain_stays_finite() -> void:
	print("- serpent + centipede stay finite (no explosion)")
	for body_name in ["serpent", "centipede"]:
		var g: PartGene = PartCatalog.make_serpent_v2() if body_name == "serpent" \
				else PartCatalog.make_centipede_v2()
		var rp := SimRolloutScript.Params.new()
		rp.controller_params = _params(g.gait)
		var r: Dictionary = await SimRolloutScript.run(g, 4.0, 7, self, rp)
		print("  %s ok=%s dist=%.2f teleport=%s" % [body_name, str(r.get("ok", false)),
				float(r.get("distance_abs", 0.0)), str(r.get("teleport", false))])
		_check(bool(r.get("ok", false)), "%s rollout stays finite" % body_name)


func _test_muscle_raises_torque_cap() -> void:
	print("- muscle raises the joint torque ceiling on the same body")
	var bare := _max_tau_cap(PartCatalog.make_demo_creature(&"bare"))
	var musc := _max_tau_cap(PartCatalog.make_demo_creature(&"muscle"))
	print("  max tau_cap bare=%.4f muscle=%.4f" % [bare, musc])
	_check(musc > bare, "muscle-tagged limbs get a higher torque cap")


func _test_tendon_conservative() -> void:
	print("- the biarticular tendon is active and conservative (released <= stored)")
	var g := PartCatalog.make_demo_creature(&"tendon")
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params(g.gait)
	var r: Dictionary = await SimRolloutScript.run(g, 1.5, 7, self, rp)
	var stored := float(r.get("tendon_energy_stored", 0.0))
	var rel := float(r.get("tendon_energy_released", 0.0))
	print("  tendon stored=%.3f released=%.3f" % [stored, rel])
	_check(stored > 0.0, "tendon stores energy (it is coupling the pair)")
	_check(rel <= stored * 1.05 + 0.0001, "tendon released <= stored (conservative)")


func _test_tournament_wired() -> void:
	print("- GaitOptimizer runs the tournament, returns the mode, and persists it")
	var g := PartCatalog.make_quadruped(false)
	var res = await GaitOptimizerScript.optimize(g, self, 2, 1.5, 7, 1)
	print("  optimize mode=%s tournament=%d" % [String(res.mode), (res.tournament as Array).size()])
	_check(res.mode != &"", "optimizer returns a selected mode (tournament wired)")
	_check((res.tournament as Array).size() >= 1, "optimizer carries tournament candidates")
	GaitOptimizerScript.apply_to(g, res)
	_check(g.gait != null and g.gait.locomotion_mode == res.mode,
			"apply_to persists the selected locomotion_mode")


func _params(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p


func _max_tau_cap(g: PartGene) -> float:
	var ctrl := CpgControllerScript.new()
	root.add_child(ctrl)
	var body := CreatureBody.build(g)
	root.add_child(body)
	ctrl.call("bind", body, g, null)
	var best := float(ctrl.call("max_tau_cap"))
	ctrl.queue_free()
	body.queue_free()
	return best


func _find_by_id(g: PartGene, id: String) -> PartGene:
	if g == null:
		return null
	if String(g.part_id) == id:
		return g
	for c in g.children:
		var f := _find_by_id(c, id)
		if f != null:
			return f
	return null


func _find_by_socket_id(g: PartGene, id: String) -> PartGene:
	if g == null:
		return null
	if g.socket != null and String(g.socket.id) == id:
		return g
	for c in g.children:
		var f := _find_by_socket_id(c, id)
		if f != null:
			return f
	return null


func _fold_by_id(parts: Array, id: String):
	for p in parts:
		if String(p.part_id) == id:
			return p
	return null
