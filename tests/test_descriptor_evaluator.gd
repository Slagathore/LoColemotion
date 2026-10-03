extends SceneTree
## Descriptor-fed golden harness for CharacteristicsEvaluator's authored "Lane B" path.
##
## Pins that PartGene.descriptor overrides the analytic per-part physics in _fold (mass,
## volume, surface-metabolic, CoG) while leaving the primitive path (descriptor == null)
## byte-for-byte untouched. Companion to test_characteristics_evaluator.gd.
##
## Run headless:  godot --headless --path . --script res://tests/test_descriptor_evaluator.gd
## Exit code 0 = all pass, 1 = at least one failure.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Descriptor (Lane B) golden tests ===")
	_test_descriptor_overrides_mass_and_volume()
	_test_inert_excluded_from_hungry_skin()
	_test_primitive_path_untouched()
	_test_descriptor_determinism()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# ----------------------------- mini assert harness -----------------------------

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

func _def(part_type: StringName, density: float, extents: Vector3,
		centroid := Vector3.ZERO) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	d.centroid_offset = centroid
	return d

func _socket(pos: Vector3, hinge := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new()
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = hinge
	return s

func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null,
		scale := Vector3.ONE) -> PartGene:
	var g := PartGene.new()
	g.definition = defn
	var tarr: Array[StringName] = []
	for t in tags:
		tarr.append(t)
	g.tags = tarr
	g.socket = socket
	g.scale = scale
	return g

# Inert venom-spine descriptor: full mass, zero metabolic volume + zero hungry-skin SA.
func _spine_desc() -> PhysicsDescriptor:
	var d := PhysicsDescriptor.new()
	d.total_volume = 0.001508
	d.metabolic_volume = 0.0
	d.total_surface_area = 0.0875
	d.surface_metabolic = 0.0
	d.mass = 2.262
	d.center_of_mass = Vector3(0.0, 0.10, 0.0)
	d.bounding_radius = 0.21
	d.bounds = AABB(Vector3(-0.06, 0.0, -0.06), Vector3(0.12, 0.40, 0.12))
	return d


# ----------------------------- tests -----------------------------

func _test_descriptor_overrides_mass_and_volume() -> void:
	print("- descriptor overrides analytic mass/volume")
	# Box SKELETON extents (.06,.20,.06) -> dims (.12,.40,.12) -> vol .00576 -> analytic mass
	# = density(1500) * .00576 = 8.64. The descriptor says mass 2.262, volume 0.001508.
	# If the Lane B override fires, the totals reflect the descriptor, NOT the skeleton.
	var root := _gene(_def(&"box", 1500.0, Vector3(0.06, 0.20, 0.06)), [&"spine", &"ground_contact"])
	root.descriptor = _spine_desc()
	var r := CE.evaluate(root)
	_check(r["status"]["ok"], "status.ok")
	_check(_approx(float(r["total_mass"]), 2.262, 1e-3), "total_mass == descriptor mass (2.262)")
	_check(absf(float(r["total_mass"]) - 8.64) > 1.0, "total_mass is NOT analytic density*volume (8.64)")
	_check(_approx(float(r["total_volume"]), 0.001508, 1e-5), "total_volume == descriptor volume (0.001508)")
	_check(_approx(float(r["cog"].y), 0.10, 1e-6), "cog.y == descriptor center_of_mass.y (0.10)")


func _test_inert_excluded_from_hungry_skin() -> void:
	print("- inert surface_metabolic=0 lowers exposed SA vs a metabolic twin")
	# Identical creatures except the authored child's surface_metabolic.
	var inert_child := _gene(_def(&"box", 1500.0, Vector3(0.06, 0.20, 0.06)), [&"attack"], _socket(Vector3(0.3, 0.0, 0.0)))
	inert_child.descriptor = _spine_desc()                       # surface_metabolic = 0
	var root_inert := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"])
	root_inert.children.append(inert_child)

	var met_child := _gene(_def(&"box", 1500.0, Vector3(0.06, 0.20, 0.06)), [&"attack"], _socket(Vector3(0.3, 0.0, 0.0)))
	var met_d := _spine_desc()
	met_d.surface_metabolic = 1.0                                # same part, but "hungry" skin
	met_child.descriptor = met_d
	var root_met := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"])
	root_met.children.append(met_child)

	var ri := CE.evaluate(root_inert)
	var rm := CE.evaluate(root_met)
	_check(float(ri["total_sa_exposed"]) < float(rm["total_sa_exposed"]),
			"inert child contributes less exposed SA than metabolic twin")
	_check(_approx(float(ri["total_mass"]), float(rm["total_mass"]), 1e-6),
			"surface_metabolic change does not alter mass")


func _test_primitive_path_untouched() -> void:
	print("- primitive (descriptor == null) creature still evaluates analytically")
	# root box dims (1.0,0.4,1.6) vol .64 *1000 = 640;  heart box dims (.4,.4,.4) vol .064 *800 = 51.2
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8)), [&"spine", &"ground_contact"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.2, 0.2, 0.2)), [&"heart"], _socket(Vector3.ZERO)))
	var r := CE.evaluate(root)
	_check(r["status"]["ok"], "status.ok (primitive path)")
	_check(_approx(float(r["total_mass"]), 691.2, 1e-1), "analytic total_mass intact (≈691.2; override never fired)")


func _test_descriptor_determinism() -> void:
	print("- same descriptor input -> bit-identical key outputs")
	var a := _gene(_def(&"box", 1500.0, Vector3(0.06, 0.20, 0.06)), [&"spine", &"ground_contact"])
	a.descriptor = _spine_desc()
	var b := _gene(_def(&"box", 1500.0, Vector3(0.06, 0.20, 0.06)), [&"spine", &"ground_contact"])
	b.descriptor = _spine_desc()
	var ra := CE.evaluate(a)
	var rb := CE.evaluate(b)
	_check(float(ra["total_mass"]) == float(rb["total_mass"]), "total_mass bit-identical")
	_check(float(ra["total_volume"]) == float(rb["total_volume"]), "total_volume bit-identical")
	_check(float(ra["total_sa_exposed"]) == float(rb["total_sa_exposed"]), "total_sa bit-identical")
	_check(ra["cog"] == rb["cog"], "cog bit-identical")
