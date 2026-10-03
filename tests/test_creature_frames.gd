extends SceneTree

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== CreatureFrames tests ===")
	_test_frame_law_matches_fold()
	_test_spine_snap_socket_matches_frame_law()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _def(extents: Vector3) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = &"box"
	d.density = 1000.0
	d.extents = extents
	return d


func _test_frame_law_matches_fold() -> void:
	print("- shared frame law matches evaluator fold")
	var root := PartGene.new()
	root.definition = _def(Vector3(0.5, 0.2, 0.8))
	var child := PartGene.new()
	child.definition = _def(Vector3(0.1, 0.3, 0.1))
	child.socket = SocketDef.new()
	child.socket.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(0.3, -0.2, 0.4))
	child.socket.child_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, 0.0))
	root.children.append(child)
	var fold := CE.fold_graph(root, Transform3D.IDENTITY)
	var expected := CreatureFrames.child_world(fold["parts"][0].xform, child.socket)
	_check(fold["parts"][1].xform == expected, "fold child transform uses CreatureFrames.child_world")


func _test_spine_snap_socket_matches_frame_law() -> void:
	print("- spine snap emits a normal socket frame")
	var root := PartGene.new()
	root.definition = _def(Vector3(0.5, 0.2, 0.8))
	var socket := CreatureFrames.spine_socket(root, &"snap", 0.75, -1.0, Vector3(1, 0, 0))
	var world := CreatureFrames.child_world(Transform3D.IDENTITY, socket)
	_check(socket.id == &"snap", "socket id assigned")
	_check(is_equal_approx(world.origin.z, 0.4), "z fraction maps onto spine length")
	_check(socket.hinge_axis == Vector3(1, 0, 0), "hinge axis preserved")
