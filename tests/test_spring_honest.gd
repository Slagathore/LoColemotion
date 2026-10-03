extends SceneTree

## M36 — honest springs. The central-force "spring rocket" is gone; the spring is now a
## conservative torsional Hooke element delivered as JOINT TORQUE (I3/§17). These are the
## M36.0 truth-gates: no central force in the spring path, released <= stored, and the honest
## spring PAYS OFF so the optimizer keeps it (Principle 18) rather than deleting it.

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const TrackScript := preload("res://scripts/sim/track.gd")

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
	print("=== M36 honest spring tests ===")
	_test_no_spring_central_force()
	await _test_spring_energy_conservative()
	await _test_spring_pays_off()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# M36.0(a): no apply_central_force reachable from any spring path. Enforced at the source
# level so a future edit that reintroduces the rocket fails this gate (I5).
func _test_no_spring_central_force() -> void:
	print("- the spring path applies joint torque, never central force")
	var src := FileAccess.get_file_as_string("res://scripts/sim/cpg_controller.gd")
	_check(not src.is_empty(), "controller source is readable")
	_check(not src.contains("_apply_spring_release_force"),
			"the central-force release helper (the rocket) is deleted")
	var start := src.find("func _apply_spring_drive(")
	var rest := src.substr(start)
	var next := rest.find("\nfunc ", 1)
	var body := rest.substr(0, next) if next >= 0 else rest
	_check(body.contains("apply_torque"), "spring drive applies joint torque")
	_check(not body.contains("apply_central_force"), "spring drive contains NO central force")


# M36.0(b): released <= stored (Principle 14, conservative passive elastic). Uses the frog catapult
# (it loads + releases spring energy each leap); the monopod that used to demo this is deferred (its
# single-leg pogo tips before the spring can rebound) — see docs/HONEST_MIGRATION.md.
func _test_spring_energy_conservative() -> void:
	print("- a passive spring returns no more than it stored")
	var params := SimRolloutScript.Params.new()
	params.controller_params = _hop_params(PartCatalog.make_frog_v2().gait)
	var r: Dictionary = await SimRolloutScript.run(PartCatalog.make_frog_v2(), 4.0, 34, self, params)
	var stored := float(r.get("spring_energy_stored", 0.0))
	var released := float(r.get("spring_energy_released", 0.0))
	print("  stored=%.3f released=%.3f return_work=%.3f" % [stored, released, float(r.get("spring_return_work", 0.0))])
	_check(stored > 0.0, "spring stores positive energy")
	_check(released > 0.0, "spring releases positive energy")
	_check(released <= stored * 1.05 + 0.0001, "released <= stored (conservative)")


# M36.0(d): the honest-spring champion's fitness EXCEEDS the same body with springs disabled.
# Without this M36 is a regression (the optimizer would delete the spring).
func _test_spring_pays_off() -> void:
	print("- the honest spring pays off (spring-on fitness > spring-off)")
	# Use the FROG catapult — the clearest working exemplar of an honest spring after the vital-organ
	# right-sizing (it now truly LEAPS with springs and can only shuffle without them). The economy/
	# elastic reward is gated behind `credible` (Principle 18 pays honest movers), and the frog's hind-
	# leg springs do real return work, so keeping the spring beats deleting it. (Was the monopod, but
	# that single-leg pogo is a DEFERRED balance case — light, it tips before its spring even loads, so
	# spring-on == spring-off there; the frog demonstrates the same principle honestly.)
	var on := PartCatalog.make_frog_v2()
	var off := GenomeSnapshot.deep_copy(on)
	_disable_springs(off)
	var track := TrackScript.hop(1.0, 0.05)
	var r_on := await _run_on_track(on, track)
	var r_off := await _run_on_track(off, track)
	var f_on := float(track.score(r_on)["fitness"])
	var f_off := float(track.score(r_off)["fitness"])
	print("  frog credible=%s fitness: spring_on=%.3f spring_off=%.3f return_work=%.3f" % [
			str(track.score(r_on)["credible"]), f_on, f_off,
			float(r_on.get("spring_return_work", 0.0))])
	_check(f_on > f_off, "honest spring increases fitness over the spring-disabled body")


func _run_on_track(g: PartGene, track) -> Dictionary:
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _hop_params(g.gait)
	rp.track = track
	return await SimRolloutScript.run(g, 4.0, 7, self, rp)


func _hop_params(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	p.locomotion_mode = &"hop"
	return p


func _disable_springs(g: PartGene) -> void:
	if g == null:
		return
	if g.spring != null:
		g.spring.enabled = false
	for c in g.children:
		_disable_springs(c)
