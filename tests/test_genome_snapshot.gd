extends SceneTree
## F4 acceptance — genome snapshot/restore + sharing rule + undo/redo.
## Run: godot --headless --script res://tests/test_genome_snapshot.gd   (exit 0 = all pass)

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0

func _check(c: bool, l: String) -> void:
	if c: _passed += 1; print("  PASS  ", l)
	else: _failed += 1; printerr("  FAIL  ", l)


# ----------------------------- builders -----------------------------

func _def(pt: StringName, d: float, e: Vector3) -> PartDefinition:
	var x := PartDefinition.new(); x.part_type = pt; x.density = d; x.extents = e
	return x
func _sock(p: Vector3, h := Vector3.ZERO, id: StringName = &"", name := "") -> SocketDef:
	var s := SocketDef.new(); s.parent_attachment = Transform3D(Basis.IDENTITY, p); s.hinge_axis = h
	s.id = id; s.display_name = name
	return s
func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null) -> PartGene:
	var g := PartGene.new(); g.definition = defn
	var t: Array[StringName] = []
	for x in tags: t.append(x)
	g.tags = t; g.socket = socket
	return g
func _joint(amp: float, rest: float, amin: float, amax: float) -> JointDef:
	var j := JointDef.new(); j.amplitude = amp; j.rest_angle = rest; j.angle_min = amin; j.angle_max = amax
	return j
func _gait(asg: Dictionary) -> GaitDef:
	var g := GaitDef.new(); var a: Dictionary[StringName, float] = {}
	for k in asg: a[k] = float(asg[k])
	g.assignments = a
	return g
func _spring() -> SpringDef:
	var s := SpringDef.new()
	s.stiffness = 240.0
	s.damping = 0.15
	s.max_compression = 0.22
	s.release_threshold = 0.18
	s.efficiency = 0.7
	return s

# Quad sharing ONE leg PartDefinition (legal), with named sockets, a root gait, leg joints,
# a muscle in one leg, and non-default round-trip fields (part_id / socket_id / dial_values).
func _authored_quad() -> PartGene:
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8)), [&"spine"])
	root.part_id = &"root_part"
	var dv: Dictionary[StringName, float] = {&"length": 1.5}
	root.dial_values = dv
	root.gait = _gait({&"hip_FL": 0.0, &"hip_FR": 0.5, &"hip_BL": 0.5, &"hip_BR": 0.0})
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.3, 0.3, 0.3)), [&"heart"], _sock(Vector3.ZERO)))
	var leg := _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1))   # SHARED across 4 legs (allowed)
	var specs := [
		[Vector3(-0.4,-0.2,-0.6), &"hip_BL"], [Vector3(0.4,-0.2,-0.6), &"hip_BR"],
		[Vector3(-0.4,-0.2,0.6), &"hip_FL"], [Vector3(0.4,-0.2,0.6), &"hip_FR"],
	]
	for sp in specs:
		var g := _gene(leg, [&"locomotor", &"ground_contact"], _sock(sp[0], Vector3(1,0,0), sp[1], "Hip"))
		g.socket_id = sp[1]
		g.joint = _joint(1.0, 0.0, -0.5, 0.5)
		root.children.append(g)
	root.children[2].spring = _spring()
	root.children[2].children.append(_gene(_def(&"capsule", 1000.0, Vector3(0.06,0.25,0.06)), [&"muscle"], _sock(Vector3(0,-0.3,0))))
	return root


# ----------------------------- evaluate signature (byte-identity proxy) -----------------------------

func _sig(r: Dictionary) -> Array:
	var b: Dictionary = r["balance"]
	return [
		float(r["total_mass"]), float(r["total_volume"]), float(r["total_sa_exposed"]), float(r["body_radius"]),
		r["cog"].x, r["cog"].y, r["cog"].z,
		float(b["balance_margin"]), float(b["tip_angle"]), (1 if bool(b["stable"]) else 0),
		float(r["debt"]["debt_total"]), float(r["debt"]["metabolic_debt"]),
		float(r["speed"]["value"]), float(r["strength"]["value"]), float(r["intelligence"]["value"]),
		float(r["probe"]["distance"]), str(r["probe"]["verdict"]), int(r["weak_points"].size()),
	]
func _sig_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if a[i] != b[i]: return false
	return true


# ----------------------------- structural deep equality (catches a missed copied field) ----------

func _struct_eq(a: PartGene, b: PartGene) -> bool:
	if a == null or b == null: return a == b
	if a == b: return false                                   # must be DISTINCT instances
	if a.definition != b.definition: return false             # ... but SHARE the immutable definition
	if a.scale != b.scale or a.part_id != b.part_id or a.socket_id != b.socket_id: return false
	if a.tags != b.tags or a.dial_values != b.dial_values: return false
	if not _sock_eq(a.socket, b.socket): return false
	if not _joint_eq(a.joint, b.joint): return false
	if not _gait_eq(a.gait, b.gait): return false
	if not _spring_eq(a.spring, b.spring): return false
	if a.children.size() != b.children.size(): return false
	for i in a.children.size():
		if not _struct_eq(a.children[i], b.children[i]): return false
	return true
func _sock_eq(a: SocketDef, b: SocketDef) -> bool:
	if a == null or b == null: return a == b
	if a == b: return false
	return a.id == b.id and a.display_name == b.display_name and a.parent_attachment == b.parent_attachment \
		and a.child_anchor == b.child_anchor and a.hinge_axis == b.hinge_axis and a.hinge_axis_2 == b.hinge_axis_2
func _joint_eq(a: JointDef, b: JointDef) -> bool:
	if a == null or b == null: return a == b
	if a == b: return false
	return a.amplitude == b.amplitude and a.rest_angle == b.rest_angle and a.angle_min == b.angle_min and a.angle_max == b.angle_max
func _gait_eq(a: GaitDef, b: GaitDef) -> bool:
	if a == null or b == null: return a == b
	if a == b: return false
	return a.pattern == b.pattern and a.assignments == b.assignments \
		and a.amplitude_scale == b.amplitude_scale and a.frequency_scale == b.frequency_scale \
		and a.gain_scale == b.gain_scale and a.traction_scale == b.traction_scale \
		and a.posture_scale == b.posture_scale
func _spring_eq(a: SpringDef, b: SpringDef) -> bool:
	if a == null or b == null: return a == b
	if a == b: return false
	return a.enabled == b.enabled and a.stiffness == b.stiffness and a.damping == b.damping \
		and a.max_compression == b.max_compression and a.release_threshold == b.release_threshold \
		and a.axis == b.axis and a.efficiency == b.efficiency


# ----------------------------- tests -----------------------------

func _initialize() -> void:
	print("=== F4 genome snapshot / sharing / undo-redo ===")
	_test_roundtrip_byte_identical()
	_test_deep_isolation()
	_test_structural_equality()
	_test_json_snapshot_roundtrip()
	_test_validate_allows_shared_definition()
	_test_validate_rejects_shared_partgene()
	_test_validate_rejects_shared_socket()
	_test_history_undo_redo_byte_identical()
	_test_history_isolation()
	_test_deep_copy_cycle_safe()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_roundtrip_byte_identical() -> void:
	print("- snapshot -> restore -> evaluate() byte-identical")
	var root := _authored_quad()
	var r0 := CE.evaluate(root)
	var snap := GenomeSnapshot.deep_copy(root)
	var live := GenomeSnapshot.deep_copy(snap)         # restore = another isolated copy
	var r1 := CE.evaluate(live)
	_check(_sig_eq(_sig(r0), _sig(r1)), "restored evaluate() == original (byte-identical signature)")

func _test_deep_isolation() -> void:
	print("- snapshot is isolated from later mutation of the live tree")
	var root := _authored_quad()
	var r0 := CE.evaluate(root)
	var snap := GenomeSnapshot.deep_copy(root)
	# Mutate the live tree across several field kinds: scale, socket pose, joint, tags, dials.
	root.children[2].scale = Vector3(2, 2, 2)
	root.children[2].socket.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(3, 3, 3))
	root.children[2].joint.amplitude = 9.0
	root.tags.append(&"mutated")
	root.dial_values[&"length"] = 99.0
	_check(not _sig_eq(_sig(r0), _sig(CE.evaluate(root))), "mutation actually changed the live score")
	_check(_sig_eq(_sig(r0), _sig(CE.evaluate(snap))), "snapshot score unchanged by the mutation")

func _test_structural_equality() -> void:
	print("- deep copy is structurally equal, distinct nodes, shared definition")
	var root := _authored_quad()
	var copy := GenomeSnapshot.deep_copy(root)
	_check(_struct_eq(root, copy), "full structural deep-equality (all fields, distinct instances)")
	_check(root.children[2].definition == copy.children[2].definition, "PartDefinition shared by reference (catalog)")
	_check(root.children[2].socket != copy.children[2].socket, "SocketDef is a distinct copy")


func _test_json_snapshot_roundtrip() -> void:
	print("- JSON-safe genome snapshot reconstructs the scored creature")
	var root := _authored_quad()
	var packed := GenomeSnapshot.to_dictionary(root)
	var text := JSON.stringify(packed)
	var parsed = JSON.parse_string(text)
	var restored := GenomeSnapshot.from_dictionary(parsed if parsed is Dictionary else {})
	_check(restored != null, "snapshot restores to a PartGene")
	_check(restored != root and restored.children.size() == root.children.size(),
			"restored tree is distinct and keeps child count")
	_check(_sig_eq(_sig(CE.evaluate(root)), _sig(CE.evaluate(restored))),
			"restored JSON snapshot evaluates byte-identical")
	_check(restored.gait != null and restored.gait.assignments.has(&"hip_FL"),
			"gait assignments survive JSON key conversion")
	_check(restored.children[2].spring != null
			and is_equal_approx(restored.children[2].spring.max_compression, 0.22),
			"spring definitions survive JSON round-trip")

func _test_validate_allows_shared_definition() -> void:
	print("- validate_unique: shared PartDefinition is allowed")
	var v := GenomeSnapshot.validate_unique(_authored_quad())
	_check(bool(v["ok"]), "valid tree (4 legs share one PartDefinition) passes")

func _test_validate_rejects_shared_partgene() -> void:
	print("- validate_unique: shared PartGene rejected")
	var root := _authored_quad()
	root.children.append(root.children[1])             # reuse the heart gene under root twice
	var v := GenomeSnapshot.validate_unique(root)
	_check(not bool(v["ok"]) and String(v["error"]).contains("PartGene"), "shared PartGene flagged with a clear error")

func _test_validate_rejects_shared_socket() -> void:
	print("- validate_unique: shared SocketDef rejected")
	var root := _gene(_def(&"box", 1000.0, Vector3(0.3,0.3,0.3)), [&"spine"])
	var shared := _sock(Vector3(0.5, 0, 0), Vector3.ZERO, &"s")
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.2,0.2,0.2)), [&"heart"], shared))
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.2,0.2,0.2)), [&"brain"], shared))  # same SocketDef
	var v := GenomeSnapshot.validate_unique(root)
	_check(not bool(v["ok"]) and String(v["error"]).contains("SocketDef"), "shared SocketDef flagged with a clear error")

func _test_history_undo_redo_byte_identical() -> void:
	print("- undo/redo reproduce pre/post-edit scores byte-identical")
	var root := _authored_quad()
	var r_pre := CE.evaluate(root)
	var hist := GenomeHistory.new()
	hist.reset(root)
	# Commit an edit on the live tree, then push.
	root.children[2].scale = Vector3(1.5, 1.5, 1.5)
	var r_post := CE.evaluate(root)
	hist.push(root)
	_check(not _sig_eq(_sig(r_pre), _sig(r_post)), "edit changed the score (sanity)")
	var undone := hist.undo()
	_check(undone != null and _sig_eq(_sig(r_pre), _sig(CE.evaluate(undone))), "undo restores pre-edit score")
	var redone := hist.redo()
	_check(redone != null and _sig_eq(_sig(r_post), _sig(CE.evaluate(redone))), "redo restores post-edit score")

func _test_history_isolation() -> void:
	print("- mutating an undo result does not corrupt history")
	var root := _authored_quad()
	var hist := GenomeHistory.new()
	hist.reset(root)
	root.children[2].scale = Vector3(1.5, 1.5, 1.5)
	var r_post := CE.evaluate(root)
	hist.push(root)
	var undone := hist.undo()
	undone.children[2].scale = Vector3(7, 7, 7)         # vandalise the returned copy
	var redone := hist.redo()
	_check(_sig_eq(_sig(r_post), _sig(CE.evaluate(redone))), "redo still byte-identical to the committed post-edit state")


func _test_deep_copy_cycle_safe() -> void:
	print("- deep_copy handles cycles defensively (validation remains the gate)")
	var a := PartGene.new()
	a.definition = _def(&"box", 1000.0, Vector3.ONE)
	var b := PartGene.new()
	b.definition = _def(&"box", 1000.0, Vector3.ONE)
	a.children.append(b)
	b.children.append(a)
	var chk := GenomeSnapshot.validate_unique(a)
	var copied := GenomeSnapshot.deep_copy(a)
	_check(not bool(chk["ok"]), "cycle rejected by validate_unique")
	_check(copied != null and copied.children.size() == 1 and copied.children[0].children.is_empty(),
			"deep_copy truncates repeated node instead of recursing forever")
