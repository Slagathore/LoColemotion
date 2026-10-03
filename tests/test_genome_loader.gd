extends SceneTree
## Through-loader acceptance for GenomeLoader (S1 / Problem 2 round-trip).
##
## Proves authored joints + gait reach the evaluator via the LOADER's stable-key resolution,
## NOT via hand-set snapshots -- the exact gap the golden harness is structurally blind to
## (it builds PartGene trees directly). Also proves JointDef/SocketDef survive .tres
## serialization, that resolve() is a no-op on legacy trees (L4-safe), and that the D1
## hinge_axis_2 guard fires through the loader.
##
## Run headless:  godot --headless --script res://tests/test_genome_loader.gd
## Exit code 0 = all pass, 1 = at least one failure.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const GL := preload("res://scripts/creature/genome_loader.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== GenomeLoader round-trip tests ===")
	_test_stamps_socket_joint_gait()
	_test_probe_consumes_gait()
	_test_tres_round_trip()
	_test_legacy_passthrough_is_noop()
	_test_guard_contract()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# ----------------------------- assert harness -----------------------------

func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)

func _approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


# ----------------------------- builders -----------------------------

func _tags(arr: Array) -> Array[StringName]:
	var t: Array[StringName] = []
	for x in arr:
		t.append(x)
	return t

func _def(part_type: StringName, density: float, extents: Vector3) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	return d

func _socket(pos: Vector3, hinge: Vector3, id: StringName, hinge2 := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new()
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = hinge
	s.hinge_axis_2 = hinge2
	s.id = id
	return s

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


# --- The authored content: a body whose sockets/joints describe how its CHILDREN attach. ---

const HIPS: Array[StringName] = [&"hip_BL", &"hip_BR", &"hip_FL", &"hip_FR"]
const HIP_POS := {
	&"hip_BL": Vector3(-0.4, -0.2, -0.6), &"hip_BR": Vector3(0.4, -0.2, -0.6),
	&"hip_FL": Vector3(-0.4, -0.2, 0.6),  &"hip_FR": Vector3(0.4, -0.2, 0.6),
}
const TROT := {&"hip_FL": 0.0, &"hip_FR": 0.5, &"hip_BL": 0.5, &"hip_BR": 0.0}

# hip2 != ZERO authors a 2-DoF second axis on hip_BL, to exercise the D1 guard path.
func _body_resource(hip2 := Vector3.ZERO) -> PartResource:
	var res := PartResource.new()
	res.id = &"body"
	var socks: Dictionary[StringName, SocketDef] = {}
	var joints: Dictionary[StringName, JointDef] = {}
	socks[&"organ"] = _socket(Vector3.ZERO, Vector3.ZERO, &"organ")   # rigid mount for required organs
	for h in HIPS:
		var second: Vector3 = hip2 if h == &"hip_BL" else Vector3.ZERO
		socks[h] = _socket(HIP_POS[h], Vector3(1, 0, 0), h, second)
		joints[h] = _joint(1.0, 0.0, -0.5, 0.5)
	res.sockets = socks
	res.joints = joints
	return res

# Skeletal genome: snapshots (.socket/.joint/.gait) LEFT NULL; only stable keys set. The loader
# must fill them. This is what an authored .tres genome resolves to before resolve().
func _skeleton() -> PartGene:
	var root := PartGene.new()
	root.definition = _def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8))
	root.tags = _tags([&"spine"])
	root.part_id = &"body"
	var heart := PartGene.new()
	heart.definition = _def(&"box", 800.0, Vector3(0.3, 0.3, 0.3))
	heart.tags = _tags([&"heart"])
	heart.part_id = &"organ"
	heart.socket_id = &"organ"
	root.children.append(heart)
	var brain := PartGene.new()
	brain.definition = _def(&"sphere", 600.0, Vector3(0.18, 0.18, 0.18))
	brain.tags = _tags([&"brain"])
	brain.part_id = &"organ"
	brain.socket_id = &"organ"
	root.children.append(brain)
	var lung := PartGene.new()
	lung.definition = _def(&"sphere", 350.0, Vector3(0.16, 0.11, 0.16))
	lung.tags = _tags([&"lung"])
	lung.part_id = &"organ"
	lung.socket_id = &"organ"
	root.children.append(lung)
	for h in HIPS:
		var leg := PartGene.new()
		leg.definition = _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1))
		leg.tags = _tags([&"locomotor", &"ground_contact"])
		leg.part_id = &"leg"
		leg.socket_id = h
		root.children.append(leg)
	return root

func _legs_of(root: PartGene) -> Array:
	var out: Array = []
	for c in root.children:
		if c.socket_id in HIPS:
			out.append(c)
	return out

# Legacy/hand-built tree: sockets set DIRECTLY, no stable keys -> loader should not touch it.
func _hand_built() -> PartGene:
	var root := PartGene.new()
	root.definition = _def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8))
	root.tags = _tags([&"spine"])
	for h in HIPS:
		var leg := PartGene.new()
		leg.definition = _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1))
		leg.tags = _tags([&"locomotor", &"ground_contact"])
		leg.socket = _socket(HIP_POS[h], Vector3(1, 0, 0), h)   # direct snapshot, no socket_id
		root.children.append(leg)
	return root


# ----------------------------- tests -----------------------------

func _test_stamps_socket_joint_gait() -> void:
	print("- resolve() stamps socket + joint (B3) + gait (C2) from stable keys")
	var root := _skeleton()
	var legs := _legs_of(root)
	# Pre-condition: snapshots are null before the loader runs (keys only).
	var pre_null := root.gait == null
	for leg in legs:
		pre_null = pre_null and leg.socket == null and leg.joint == null
	_check(pre_null, "skeleton has null snapshots before resolve (keys only)")
	GL.resolve(root, {&"body": _body_resource()}, _gait(TROT))
	_check(root.gait != null, "root.gait stamped (C2)")
	var all_socket := true
	var all_joint := true
	var ids_match := true
	for leg in legs:
		all_socket = all_socket and leg.socket != null
		all_joint = all_joint and leg.joint != null
		ids_match = ids_match and leg.socket != null and leg.socket.id == leg.socket_id
	_check(all_socket, "every leg.socket stamped from parent resource")
	_check(all_joint, "every leg.joint stamped (B3)")
	_check(ids_match, "stamped socket.id matches the child's socket_id")

func _test_probe_consumes_gait() -> void:
	print("- the probe CONSUMES the loaded gait (authored trot != golden default)")
	var with_gait := GL.resolve(_skeleton(), {&"body": _body_resource()}, _gait(TROT))
	var no_gait := GL.resolve(_skeleton(), {&"body": _body_resource()}, null)  # golden default
	var rg := CE.evaluate(with_gait)
	var rn := CE.evaluate(no_gait)
	_check(is_finite(float(rg["probe"]["distance"])), "gait probe distance finite")
	_check(is_finite(float(rn["probe"]["distance"])), "control probe distance finite")
	_check(absf(float(rg["probe"]["distance"]) - float(rn["probe"]["distance"])) > 1e-9,
			"authored gait changes probe distance vs no-gait control (gait consumed end-to-end)")

func _test_tres_round_trip() -> void:
	print("- JointDef/SocketDef survive .tres serialization (load -> identical stamps)")
	var res := _body_resource()
	var path := "user://_s1_body_roundtrip.tres"
	var err := ResourceSaver.save(res, path)
	_check(err == OK, "ResourceSaver.save OK")
	var loaded: PartResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded != null, "reloaded PartResource from .tres")
	var socks_ok := loaded != null and loaded.sockets.has(&"hip_BL") and loaded.sockets[&"hip_BL"].id == &"hip_BL"
	_check(socks_ok, "sockets dict round-tripped (keys + SocketDef.id intact)")
	var joint_ok := loaded != null and loaded.joints.has(&"hip_FL") \
			and _approx(loaded.joints[&"hip_FL"].amplitude, 1.0, 1e-9) \
			and _approx(loaded.joints[&"hip_FL"].angle_max, 0.5, 1e-9)
	_check(joint_ok, "joints dict round-tripped (JointDef fields intact)")
	# And the reloaded resource drives the loader identically.
	var root := GL.resolve(_skeleton(), {&"body": loaded}, _gait(TROT))
	var leg0: PartGene = _legs_of(root)[0]
	_check(leg0.joint != null and _approx(leg0.joint.angle_max, 0.5, 1e-9),
			"loader stamps correctly from the .tres-loaded resource")

func _test_legacy_passthrough_is_noop() -> void:
	print("- resolve() on a legacy tree (snapshots pre-set, no keys) is a no-op (L4-safe)")
	var legacy := _hand_built()
	var d_before := float(CE.evaluate(legacy)["probe"]["distance"])
	GL.resolve(legacy, {&"body": _body_resource()}, null)   # no stable keys -> nothing to stamp
	var d_after := float(CE.evaluate(legacy)["probe"]["distance"])
	_check(_approx(d_before, d_after, 1e-9), "probe distance byte-identical after resolve (loader is a no-op here)")

func _test_guard_contract() -> void:
	print("- D1 guard: hinge_axis_2 set -> warning; clean socket -> empty; fires through loader")
	var dirty := _socket(Vector3(0.4, 0, 0), Vector3(1, 0, 0), &"hip_BL", Vector3(0, 0, 1))
	var clean := _socket(Vector3(0.4, 0, 0), Vector3(1, 0, 0), &"hip_BR")
	_check(dirty.authoring_warning() != "", "non-zero hinge_axis_2 yields a warning")
	_check(clean.authoring_warning() == "", "clean socket yields empty warning")
	# resolve() over a body with a 2-DoF hip must complete (guard fires internally, no crash).
	var root := GL.resolve(_skeleton(), {&"body": _body_resource(Vector3(0, 0, 1))}, _gait(TROT))
	_check(root != null, "resolve() with a 2-DoF socket completes (guard fired, no crash)")
	# validate() surfaces the same problem without emitting.
	var warns := GL.validate(root)
	_check(warns.size() >= 1, "validate() collects the hinge_axis_2 warning")
