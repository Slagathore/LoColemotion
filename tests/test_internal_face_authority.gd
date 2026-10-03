extends SceneTree
## F2 internal-face physics-authority harness.
## Pins the shared-face haircut's source authority (the B-IF seam fix):
##   - PRIMITIVE parts take a LITERAL absolute subtraction (byte-identical to pre-F2 -> L4).
##   - DESCRIPTOR parts lose a dimensionless COVERAGE FRACTION of their canonical descriptor SA.
## Run: godot --headless --path . --script res://tests/test_internal_face_authority.gd

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0

func _initialize() -> void:
    print("=== F2 internal-face authority tests ===")
    _test_primitive_haircut_is_literal()
    _test_descriptor_haircut_is_fractional_not_hybrid()
    _test_descriptor_magnitude_is_descriptor_sourced()
    _test_coverage_fraction_scale_invariant()
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

func _socket(pos: Vector3) -> SocketDef:
    var s := SocketDef.new()
    s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
    s.child_anchor = Transform3D.IDENTITY
    return s

func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null, scale := Vector3.ONE) -> PartGene:
    var g := PartGene.new()
    g.definition = defn
    g.tags = _tags(tags)
    g.socket = socket
    g.scale = scale
    return g

func _descriptor_creature(surf: float, s: float) -> PartGene:
    var root := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"], null, Vector3(s, s, s))
    var child := _gene(_def(&"box", 1500.0, Vector3(0.06, 0.20, 0.06)), [&"attack"], _socket(Vector3(0.3, 0.0, 0.0)))
    var d := PhysicsDescriptor.new()
    d.total_volume = 0.001508
    d.metabolic_volume = 0.001508
    d.total_surface_area = 0.0875
    d.surface_metabolic = surf
    d.mass = 2.262
    d.center_of_mass = Vector3.ZERO
    d.bounding_radius = 0.21
    d.bounds = AABB(Vector3(-0.06, 0.0, -0.06), Vector3(0.12, 0.40, 0.12))
    child.descriptor = d
    root.children.append(child)
    return root

func _total_sa(surf: float, s: float) -> float:
    return float(CE.evaluate(_descriptor_creature(surf, s))["total_sa_exposed"])

func _test_primitive_haircut_is_literal() -> void:
    print("- primitive haircut is a LITERAL subtraction (byte-exact pre-F2 path)")
    # root box dims (0.6,0.6,0.6) SA=2.16 ; child box dims (0.4,0.4,0.4) SA=0.96.
    # shared = min(0.16, 0.36)*0.5 = 0.08, removed from BOTH -> (2.16-0.08)+(0.96-0.08)=2.96.
    var root := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"])
    root.children.append(_gene(_def(&"box", 1000.0, Vector3(0.2, 0.2, 0.2)), [&"attack"], _socket(Vector3(0.5, 0.0, 0.0))))
    var total := float(CE.evaluate(root)["total_sa_exposed"])
    _check(_approx(total, 2.96, 1e-4), "primitive total_sa == 2.96 (literal -shared on both parts)")

func _test_descriptor_haircut_is_fractional_not_hybrid() -> void:
    print("- descriptor haircut removes a FRACTION of descriptor SA, not the old absolute area")
    # f = shared/ref = 0.0072/0.2208 = 0.0326087. fractional: 1*(1-f)=0.9673913 ; old absolute: 1-0.0072=0.9928.
    var r0 := _total_sa(0.0, 1.0)
    var c1 := _total_sa(1.0, 1.0) - r0
    _check(_approx(c1, 0.9673913, 1e-3), "trimmed descriptor SA matches the fractional rule (0.9674)")
    _check(absf(c1 - 0.9928) > 0.01, "trimmed descriptor SA is NOT the old absolute-subtraction value (0.9928)")

func _test_descriptor_magnitude_is_descriptor_sourced() -> void:
    print("- descriptor SA flows through the haircut LINEARLY (seam closed: magnitude is descriptor-sourced)")
    # Non-inert points so the root cancels exactly and no EPS floor bites: d31 == 2*d21.
    var base := _total_sa(1.0, 1.0)
    var d21 := _total_sa(2.0, 1.0) - base
    var d31 := _total_sa(3.0, 1.0) - base
    _check(d21 > 0.0, "descriptor SA contributes to exposed SA")
    _check(_approx(d31, 2.0 * d21, 1e-6), "trimmed SA exactly linear in surface_metabolic (no skeleton magnitude leaks)")

func _test_coverage_fraction_scale_invariant() -> void:
    print("- coverage fraction is SCALE-INVARIANT (child trimmed SA scales exactly s^2)")
    var c1 := _total_sa(1.0, 1.0) - _total_sa(0.0, 1.0)
    var c2 := _total_sa(1.0, 2.0) - _total_sa(0.0, 2.0)
    _check(_approx(c2, 4.0 * c1, 1e-3), "child trimmed SA(s=2) == 4 * SA(s=1) -> fraction f is scale-invariant")
