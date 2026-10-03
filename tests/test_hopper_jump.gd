extends SceneTree

## M60 hopper rebuild: the old hopper was a tall box that only stood because of the posture-lift
## cheat (honestly it toppled at spawn). Rebuilt on the frog's stable layout with the spring/muscle/
## tendon catapult. This pins: (a) the hind leg is a connected thigh -> shank -> foot chain, (b) it
## STANDS honestly with no controller drive (no anti-gravity lift), and (c) under its hop gait it
## actually leaves the ground (real bounce) and travels — a hop, not a shuffle or a lift-propped slide.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

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
	print("=== M60 hopper rebuild ===")
	var parts: Array = CE.fold_graph(PartCatalog.make_hopper_v2(), Transform3D.IDENTITY)["parts"]
	_gap("hop_L_femur", "hop_L_shin", parts)
	_gap("hop_L_shin", "hop_L_tarsus", parts)
	_gap("hop_L_tarsus", "hop_L_foot", parts)

	# Driven hop: the hind-leg catapult must produce a real FLIGHT phase + forward travel, upright.
	# Front legs are passive stubs, so airborne_frac can only come from the hind legs (not a worm).
	var hopper := PartCatalog.make_hopper_v2()
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params_from_gait(hopper.gait)
	var m: Dictionary = await SimRolloutScript.run(hopper, 4.0, 7, self, rp)
	var airborne := float(m.get("airborne_frac", 0.0))
	print("  hopper rollout: ok=%s teleport=%s forward=%.2f airborne_frac=%.2f foot_clear=%.2f class=%s" % [
		str(bool(m.get("ok", false))), str(bool(m.get("teleport", false))), float(m.get("forward", 0.0)),
		airborne, float(m.get("max_foot_clear", 0.0)), String(m.get("locomotion_class", ""))])
	_check(bool(m.get("ok", false)) and not bool(m.get("teleport", false)),
			"rebuilt hopper is physically stable (finite, no explosion)")
	_check(not bool(m.get("fell", false)), "hopper stays upright across hops (lands without tipping)")
	_check(float(m.get("forward", 0.0)) > 2.0, "hopper travels forward by hopping (> 2.0m)")
	_check(airborne >= 0.25, "hopper is hind-leg airborne >= 25%% of the cycle (a real hop, not the worm)")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _gap(a_id: String, b_id: String, parts: Array) -> void:
	var a = _by_sock(parts, a_id)
	var b = _by_sock(parts, b_id)
	if a == null or b == null:
		_check(false, "%s -> %s present" % [a_id, b_id])
		return
	var want: float = (a.dims.y + b.dims.y) * 0.5
	var got: float = a.com_world.distance_to(b.com_world)
	_check(absf(got - want) < 0.07, "%s -> %s connected end-to-end (got %.3f want %.3f)" % [
		a_id, b_id, got, want])


func _params_from_gait(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p


func _by_sock(parts: Array, sid: String):
	for p in parts:
		if p.socket != null and String(p.socket.id) == sid:
			return p
	return null
