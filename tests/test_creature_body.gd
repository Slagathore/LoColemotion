extends SceneTree

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== CreatureBody / headless physics tests ===")
	await _test_one_box_headless_physics()
	await _test_creature_body_construction()
	await _test_rom_friction_and_drive_metadata()
	await _test_descriptor_mass_uses_resolved_part_mass()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _world() -> Node3D:
	var w := Node3D.new()
	root.add_child(w)
	return w


func _floor(parent: Node3D) -> StaticBody3D:
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	cs.shape = box
	floor.add_child(cs)
	floor.position.y = -0.1
	parent.add_child(floor)
	return floor


func _step(count: int) -> void:
	for _i in count:
		await physics_frame


func _test_one_box_headless_physics() -> void:
	print("- M4.0 one-box headless physics proof")
	var w := _world()
	_floor(w)
	var body := RigidBody3D.new()
	body.mass = 1.0
	body.position = Vector3(0.0, 3.0, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	cs.shape = box
	body.add_child(cs)
	w.add_child(body)
	var start_y := body.global_position.y
	await _step(90)
	_check(body.global_position.y < start_y - 0.5, "box falls under headless physics")
	_check(is_finite(body.global_position.y), "box y remains finite")
	await _step(90)
	_check(body.global_position.y > 0.35, "box settles above the floor")
	w.queue_free()


func _test_creature_body_construction() -> void:
	print("- M4.1 creature body construction and mass parity")
	var w := _world()
	_floor(w)
	var genome := PartCatalog.make_quadruped(false)
	var eval := CE.evaluate(genome)
	var body: Node3D = CreatureBodyScript.build(genome, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)))
	w.add_child(body)
	var measure: Dictionary = body.measure()
	var fold := CE.fold_graph(genome, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)))
	_check(int(measure["part_count"]) == fold["parts"].size(), "body count matches fold count in one-body model")
	_check(_approx(float(measure["total_mass"]), float(eval["total_mass"]), 0.001),
			"live body mass equals analytic total_mass")
	await _step(30)
	_check(bool(body.measure()["finite"]), "creature body steps without NaN/explosion")
	w.queue_free()


func _test_rom_friction_and_drive_metadata() -> void:
	print("- A1 body applies friction, RoM limits, and drive metadata")
	var genome := PartCatalog.make_quadruped(false)
	for child in genome.children:
		if child.tags.has(&"locomotor"):
			child.joint = JointDef.new()
			child.joint.angle_min = -0.35
			child.joint.angle_max = 0.45
	var params := CreatureBodyScript.BuildParams.new()
	params.foot_friction = 1.25
	params.body_friction = 0.6
	params.enforce_rom = true
	var body: Node3D = CreatureBodyScript.build(genome, Transform3D.IDENTITY, params)
	root.add_child(body)
	var drive_meta: Array = body.call("drive_joints")
	_check(drive_meta.size() == 4, "quadruped exposes four authoritative hinge drive records")
	var saw_foot_material := false
	for b in body.call("part_bodies"):
		var rb := b as RigidBody3D
		if rb != null and rb.physics_material_override != null:
			var idx := int(rb.get_meta("part_index"))
			var part = body.call("parts")[idx]
			if part.tags.has(&"ground_contact"):
				saw_foot_material = _approx(rb.physics_material_override.friction, 1.25, 0.001)
	_check(saw_foot_material, "ground-contact bodies receive foot friction material")
	var all_limited := true
	for joint in body.call("joints"):
		if joint is HingeJoint3D:
			all_limited = all_limited and joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
			all_limited = all_limited and _approx(joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER), -0.35, 0.001)
			all_limited = all_limited and _approx(joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER), 0.45, 0.001)
	_check(all_limited, "hinge joints apply JointDef range-of-motion limits")
	body.queue_free()


func _test_descriptor_mass_uses_resolved_part_mass() -> void:
	print("- descriptor-backed body uses ResolvedPart.mass")
	var genome := PartGene.new()
	var def := PartDefinition.new()
	def.part_type = &"box"
	def.density = 1500.0
	def.extents = Vector3(0.06, 0.20, 0.06)
	genome.definition = def
	genome.tags = [&"spine", &"ground_contact"]
	var desc := PhysicsDescriptor.new()
	desc.total_volume = 0.001508
	desc.metabolic_volume = 0.0
	desc.surface_metabolic = 0.0
	desc.mass = 2.262
	desc.center_of_mass = Vector3(0.0, 0.1, 0.0)
	desc.bounding_radius = 0.21
	genome.descriptor = desc
	var eval := CE.evaluate(genome)
	var body: Node3D = CreatureBodyScript.build(genome, Transform3D.IDENTITY)
	root.add_child(body)
	var measure: Dictionary = body.measure()
	_check(_approx(float(measure["total_mass"]), float(eval["total_mass"]), 0.0001),
			"descriptor mass matches evaluator mass")
	_check(absf(float(measure["total_mass"]) - 8.64) > 1.0,
			"descriptor mass is not recomputed from density*volume")
	body.queue_free()
