extends SceneTree

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== CpgController tests ===")
	_test_helper_phase_contract()
	_test_shared_joint_model_parity()
	_test_locomotion_mode_inference()
	await _test_controller_binds_and_drives()
	await _test_controller_off_has_no_energy()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _world() -> Node3D:
	var w := Node3D.new()
	root.add_child(w)
	return w


func _floor(parent: Node3D) -> void:
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	cs.shape = box
	floor.add_child(cs)
	floor.position.y = -0.1
	parent.add_child(floor)


func _spawn_y(root_gene: PartGene) -> float:
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	var min_y := 0.0
	for p in fold["parts"]:
		min_y = minf(min_y, p.world_aabb.position.y)
	return maxf(0.4 - min_y, 0.6)


func _step_controller(ctrl: Node, ticks: int, dt: float) -> void:
	for i in ticks:
		ctrl.call("tick", float(i) * dt, dt)
		await physics_frame


# Steps the controller and returns the largest absolute hinge angle reached by any
# driven joint. Guards against the hinge constraint locking the driven axis (legs
# that receive torque but never rotate).
func _step_and_max_theta(ctrl: Node, ticks: int, dt: float) -> float:
	var max_theta := 0.0
	for i in ticks:
		ctrl.call("tick", float(i) * dt, dt)
		await physics_frame
		for cmd in ctrl.call("last_commands"):
			max_theta = maxf(max_theta, absf(float(cmd["theta"])))
	return max_theta


func _test_helper_phase_contract() -> void:
	print("- helper preserves assigned and golden phase semantics")
	var gait := GaitDef.new()
	var socket := SocketDef.new()
	socket.id = &"hip"
	gait.assignments[&"hip"] = 0.5
	var assigned := CE.cpg_phase(gait, socket, 7, 0.25)
	var golden := CE.cpg_phase(null, socket, 2, 0.25)
	_check(assigned == fmod(0.5 * TAU + 0.25, TAU), "assigned phase uses cycle fraction * TAU + perturb")
	_check(golden == fmod(float(2) * CE.GOLDEN + 0.25, TAU), "unassigned phase uses golden fallback with fmod")


func _test_shared_joint_model_parity() -> void:
	print("- live controller and evaluator share subtree joint model")
	var genome := PartCatalog.make_quadruped(false)
	var fold := CE.fold_graph(genome, Transform3D.IDENTITY)
	var eval := CE.evaluate(genome)
	var expected: float = CE._subtree_inertia(fold["parts"], 3, float(eval["total_mass"]), float(eval["body_radius"]))
	var actual: float = JointModel.subtree_inertia(fold["parts"], 3, float(eval["total_mass"]), float(eval["body_radius"]))
	_check(absf(expected - actual) <= 0.000001, "subtree inertia comes from shared helper")
	var m_expected: float = CE._subtree_muscle_frac(fold["parts"], 3)
	var m_actual: float = JointModel.subtree_muscle_frac(fold["parts"], 3)
	_check(absf(m_expected - m_actual) <= 0.000001, "subtree muscle fraction comes from shared helper")


func _test_locomotion_mode_inference() -> void:
	print("- gait pattern selects additive locomotion modes")
	var hop := PartCatalog.make_frog_v2()
	var hop_body: Node3D = CreatureBodyScript.build(hop, Transform3D.IDENTITY)
	var hop_ctrl: Node = CpgControllerScript.new()
	hop_ctrl.call("bind", hop_body, hop)
	_check(String(hop_ctrl.call("locomotion_mode")) == "hop", "hop gait selects hop propulsion mode")
	var side := PartCatalog.make_crab_v2()
	var side_body: Node3D = CreatureBodyScript.build(side, Transform3D.IDENTITY)
	var side_ctrl: Node = CpgControllerScript.new()
	side_ctrl.call("bind", side_body, side)
	_check(String(side_ctrl.call("locomotion_mode")) == "lateral", "scuttle gait selects lateral propulsion mode")
	var walk := PartCatalog.make_quadruped(false)
	var walk_body: Node3D = CreatureBodyScript.build(walk, Transform3D.IDENTITY)
	var walk_ctrl: Node = CpgControllerScript.new()
	walk_ctrl.call("bind", walk_body, walk)
	_check(String(walk_ctrl.call("locomotion_mode")) == "walk", "default quadruped remains walk mode")
	hop_body.queue_free()
	side_body.queue_free()
	walk_body.queue_free()
	hop_ctrl.queue_free()
	side_ctrl.queue_free()
	walk_ctrl.queue_free()


func _test_controller_binds_and_drives() -> void:
	print("- controller binds drives and applies real torque")
	var w := _world()
	_floor(w)
	var genome := PartCatalog.make_quadruped(false)
	var body: Node3D = CreatureBodyScript.build(genome,
			Transform3D(Basis.IDENTITY, Vector3(0.0, _spawn_y(genome), 0.0)))
	w.add_child(body)
	var ctrl: Node = CpgControllerScript.new()
	ctrl.call("bind", body, genome)
	w.add_child(ctrl)
	_check(int(ctrl.call("drive_count")) == 4, "quadruped binds four driven hinges")
	var max_theta := await _step_and_max_theta(ctrl, 120, 1.0 / 60.0)
	var commands: Array = ctrl.call("last_commands")
	var finite := not commands.is_empty()
	for cmd in commands:
		finite = finite and is_finite(float(cmd["target"])) and is_finite(float(cmd["theta"])) and is_finite(float(cmd["tau"]))
	_check(finite, "controller emits finite target/torque commands")
	_check(float(ctrl.call("total_energy")) > 0.0, "controller accumulates real torque energy")
	_check(max_theta > 0.05, "driven hinges actually rotate (legs swing, not locked)")
	_check(bool(body.call("measure")["finite"]), "driven body remains finite")
	w.queue_free()


func _test_controller_off_has_no_energy() -> void:
	print("- controller-off control has no actuation energy")
	var genome := PartCatalog.make_quadruped(false)
	var body: Node3D = CreatureBodyScript.build(genome, Transform3D.IDENTITY)
	root.add_child(body)
	var ctrl: Node = CpgControllerScript.new()
	ctrl.call("bind", body, genome)
	root.add_child(ctrl)
	await physics_frame
	_check(float(ctrl.call("total_energy")) == 0.0, "no tick -> no controller energy")
	body.queue_free()
	ctrl.queue_free()
