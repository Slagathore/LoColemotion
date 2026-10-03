extends SceneTree

## M40 — anisotropic ground friction for undulation. A lateral-velocity damper in
## AnisotropicBody._integrate_forces: belly slides ALONG the body (axial, kept), grips
## SIDEWAYS (lateral, damped). These prove the force model is correct, dissipative, and
## NOT a free-drift exploit. (Full serpent propulsion needs a wave gait — deferred to M42.)

const AnisotropicBodyScript := preload("res://scripts/sim/anisotropic_body.gd")
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
	print("=== M40 anisotropic friction tests ===")
	await _test_lateral_decays_axial_retained()
	await _test_anisotropic_damping_is_dissipative()
	await _test_damper_no_free_drift()
	await _test_serpent_is_wired_and_undulates_forward()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _spawn(world: Node3D, vel: Vector3) -> RigidBody3D:
	var ab = AnisotropicBodyScript.new()   # untyped: cache-independent, no global class_name dep
	ab.gravity_scale = 0.0
	ab.can_sleep = false
	ab.axial_axis_local = Vector3(0.0, 0.0, 1.0)
	ab.lateral_damp_coeff = 12.0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.3
	cs.shape = box
	ab.add_child(cs)
	world.add_child(ab)
	ab.linear_velocity = vel
	return ab


# Spike: equal axial + lateral velocity must lose the lateral fast, retain the axial.
func _test_lateral_decays_axial_retained() -> void:
	print("- lateral velocity decays, axial velocity is retained")
	var world := Node3D.new()
	root.add_child(world)
	var ab := _spawn(world, Vector3(1.0, 0.0, 1.0))
	for _i in 30:
		await physics_frame
	var v := ab.linear_velocity
	print("  final v=(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z])
	_check(absf(v.x) < 0.15, "lateral (x) component damped toward zero")
	# Axial retention bar relaxed 0.8 -> 0.72 with the small honest forward drag (axial_damp 0.15 -> 0.4)
	# that stops the light serpent free-coasting. The belly is still clearly axial-DOMINANT (v.z ~0.78 vs
	# v.x ~0, a ~50x asymmetry) — a real belly has some forward friction, so 100% retention is unphysical.
	_check(absf(v.z) > 0.72, "axial (z) component retained (belly still slides freely along the body)")
	world.queue_free()
	await physics_frame


func _test_anisotropic_damping_is_dissipative() -> void:
	print("- the damper is strictly dissipative (KE decreases)")
	var world := Node3D.new()
	root.add_child(world)
	var ab := _spawn(world, Vector3(1.0, 0.0, 1.0))
	await physics_frame
	var ke0 := ab.linear_velocity.length_squared()
	for _i in 15:
		await physics_frame
	var ke1 := ab.linear_velocity.length_squared()
	print("  KE0=%.4f KE1=%.4f" % [ke0, ke1])
	_check(ke1 < ke0, "kinetic energy strictly decreases under the damper")
	world.queue_free()
	await physics_frame


# A drift-farming damper cheat: pure lateral wiggle (zero axial thrust) must net ~0 forward.
func _test_damper_no_free_drift() -> void:
	print("- pure lateral oscillation produces no net axial drift")
	var world := Node3D.new()
	root.add_child(world)
	var ab := _spawn(world, Vector3.ZERO)
	var start := ab.global_position
	for i in 60:
		var dir_sign := 1.0 if (i / 6) % 2 == 0 else -1.0
		ab.apply_central_impulse(Vector3(dir_sign * 0.5, 0.0, 0.0))   # lateral only, no axial
		await physics_frame
	var drift_z := absf(ab.global_position.z - start.z)
	print("  net axial drift = %.4f" % drift_z)
	_check(drift_z < 0.05, "lateral wiggle nets ~0 axial displacement (no free drift)")
	world.queue_free()
	await physics_frame


func _test_serpent_is_wired_and_undulates_forward() -> void:
	print("- serpent segments build as AnisotropicBody and move axial-dominant")
	# Wiring: the tagged serpent actually builds anisotropic belly segments.
	var body: Node3D = CreatureBody.build(PartCatalog.make_serpent_v2())
	var aniso := 0
	for rb in body.call("part_bodies"):
		if rb != null and rb.get_script() == AnisotropicBodyScript:
			aniso += 1
	body.queue_free()
	await physics_frame
	_check(aniso >= 9, "serpent builds >=9 anisotropic belly segments")
	# Behaviour: net displacement is axial-dominant (the lateral component is gripped away).
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params(PartCatalog.make_serpent_v2().gait)
	var r: Dictionary = await SimRolloutScript.run(PartCatalog.make_serpent_v2(), 3.0, 7, self, rp)
	var fwd := absf(float(r.get("forward", 0.0)))
	var lat := absf(float(r.get("lateral", 0.0)))
	print("  serpent |fwd|=%.3f |lat|=%.3f" % [fwd, lat])
	_check(bool(r.get("ok", false)), "serpent rollout is finite")
	# M59 honest re-baseline: the serpent now propels via REAL undulation, not a central-force assist.
	# Its authored gait sets traction=posture=0 and the stance-traction assist is mode-gated off for
	# undulation, so traction_impulse ~ 0 — the lateral body-wave is rectified into forward thrust by
	# the anisotropic belly friction alone. Modest (~1.8m/3s; real snakes are slow) but HONEST. The
	# old fanned serpent only "moved" by being shoved (forward collapsed to ~0 with the assist off).
	# See test_serpent_undulation.gd for the full assist-off / no-drive comparison.
	_check(float(r.get("traction_impulse", 0.0)) < 1.0, "no central-force assist (the body does the work)")
	_check(fwd > 0.8, "the body-wave propels the serpent forward on its own")
	_check(fwd > lat, "net motion is axial-dominant (the belly grips lateral drift away)")


func _params(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p
