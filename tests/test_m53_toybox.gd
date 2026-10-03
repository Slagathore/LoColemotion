extends SceneTree

## M53 Toybox — arena hazards (ice/mud/wind/low-g), the mutation brush, and gait sonification.

const TrackScript := preload("res://scripts/sim/track.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const MutationBrushScript := preload("res://scripts/editor/mutation_brush.gd")
const GaitSonifierScript := preload("res://scripts/sim/gait_sonifier.gd")

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
	print("=== M53 toybox tests ===")
	_test_hazard_params()
	_test_mutation_brush()
	_test_sonifier()
	await _test_low_g_drops_less()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_hazard_params() -> void:
	print("- hazard tracks carry the right physics")
	_check(TrackScript.ice().friction < 0.1, "ice is slick")
	_check(TrackScript.mud().hazard_physics()["linear_damp"] > 0.0, "mud drags")
	_check(TrackScript.wind_track().wind != Vector3.ZERO and TrackScript.wind_track().has_hazard(),
			"wind blows")
	_check(TrackScript.low_g(0.3).gravity_scale < 1.0 and TrackScript.low_g(0.3).has_hazard(),
			"low-g lightens gravity")
	_check(not TrackScript.straight().has_hazard(), "a plain track has no hazard")


func _test_mutation_brush() -> void:
	print("- the mutation brush edits the genome deterministically")
	var g := PartCatalog.clone_template(&"leg_upper")
	var y0 := g.scale.y
	MutationBrushScript.lengthen(g, 1.5)
	_check(is_equal_approx(g.scale.y, y0 * 1.5), "lengthen stretches the long axis")
	var x0 := g.scale.x
	MutationBrushScript.thicken(g, 2.0)
	_check(is_equal_approx(g.scale.x, x0 * 2.0), "thicken fattens the cross-section")
	var m := PartCatalog.clone_template(&"leg_upper")
	m.socket = SocketDef.new()
	m.socket.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(0.5, 0.0, 0.0))
	MutationBrushScript.mirror_x(m)
	_check(is_equal_approx(m.socket.parent_attachment.origin.x, -0.5), "mirror_x flips the socket side")


func _test_sonifier() -> void:
	print("- gait sonification maps telemetry to sound")
	_check(GaitSonifierScript.cadence_to_tempo(2.0) > GaitSonifierScript.cadence_to_tempo(1.0),
			"faster cadence -> higher tempo")
	_check(GaitSonifierScript.cot_to_pitch(0.1) > GaitSonifierScript.cot_to_pitch(3.0),
			"efficient (low CoT) -> brighter pitch")
	var note := GaitSonifierScript.contact_note(3)
	_check(note >= GaitSonifierScript.ROOT_MIDI, "contact notes sit on the scale")
	_check(GaitSonifierScript.midi_to_hz(69) > 439.0 and GaitSonifierScript.midi_to_hz(69) < 441.0,
			"A4 = 440 Hz")


func _test_low_g_drops_less() -> void:
	print("- low-g reduces gravity so a body falls less (the hazard's physics effect)")
	var normal := await _drop(1.0)
	var lowg := await _drop(TrackScript.low_g(0.25).gravity_scale)
	print("  free-fall drop normal_g=%.3f low_g=%.3f" % [normal, lowg])
	_check(lowg < normal * 0.6, "low-g body falls much less over the same time")


# Free-fall a body with the given gravity_scale (what low_g() sets on the rollout bodies).
func _drop(gravity_scale: float) -> float:
	var world := Node3D.new()
	root.add_child(world)
	var rb := RigidBody3D.new()
	rb.gravity_scale = gravity_scale
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.3
	cs.shape = box
	rb.add_child(cs)
	rb.position = Vector3(0.0, 8.0, 0.0)
	world.add_child(rb)
	var y0 := rb.global_position.y
	for _i in 30:
		await physics_frame
	var drop := y0 - rb.global_position.y
	world.queue_free()
	await physics_frame
	return drop
