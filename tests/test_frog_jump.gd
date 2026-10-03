extends SceneTree

## M60 frog rebuild: the hind legs were a FAN of disjoint stubs off the body (couldn't fold/extend
## to jump). Now they are a CONNECTED femur -> shin -> tarsus -> foot chain that hinges in the
## sagittal plane. This pins: (a) the chain is connected end-to-end (no gap), (b) the rebuilt frog is
## physically stable (finite, no teleport), (c) it makes honest forward progress under the hop gait.

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
	print("=== M60 frog rebuild ===")
	var parts: Array = CE.fold_graph(PartCatalog.make_frog_v2(), Transform3D.IDENTITY)["parts"]
	_gap("frog_L_femur", "frog_L_shin", parts)
	_gap("frog_L_shin", "frog_L_tarsus", parts)
	_gap("frog_L_tarsus", "frog_L_foot", parts)
	# Drive the rollout with the frog's own baked hop gait (same path the game uses), not the
	# default 1.0 scales — otherwise the catapult never fires and the test would measure nothing.
	var frog := PartCatalog.make_frog_v2()
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params_from_gait(frog.gait)
	var m: Dictionary = await SimRolloutScript.run(frog, 4.0, 7, self, rp)
	var airborne := float(m.get("airborne_frac", 0.0))
	print("  frog rollout: ok=%s teleport=%s forward=%.2f airborne_frac=%.2f foot_clear=%.2f class=%s" % [
		str(bool(m.get("ok", false))), str(bool(m.get("teleport", false))), float(m.get("forward", 0.0)),
		airborne, float(m.get("max_foot_clear", 0.0)), String(m.get("locomotion_class", ""))])
	_check(bool(m.get("ok", false)) and not bool(m.get("teleport", false)),
			"rebuilt frog is physically stable (finite, no explosion)")
	_check(float(m.get("forward", 0.0)) > 2.5, "frog travels forward by leaping (> 2.5m)")
	# The real fix: assert a true FLIGHT PHASE driven by the HIND legs. The front legs are passive, so
	# airborne_frac (ALL feet off the floor) can ONLY come from the hind-leg catapult — v1's front-leg
	# push / body-shift could fake forward+bounce but never this.
	_check(airborne >= 0.25, "frog is hind-leg airborne >= 25%% of the cycle (a real leap, not a shuffle)")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _params_from_gait(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p


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


func _by_sock(parts: Array, sid: String):
	for p in parts:
		if p.socket != null and String(p.socket.id) == sid:
			return p
	return null
