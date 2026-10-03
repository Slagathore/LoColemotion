extends SceneTree
## Tier-D golden harness: metabolic demand reads the metabolic-volume subset.
##
## On a SUPPLY-LIMITED creature (heart under-supplies, so metabolic_debt is strictly between
## 0 and 1), adding an INERT spike (descriptor.metabolic_volume == 0) must leave metabolic_debt
## unchanged, while a METABOLIC twin of identical total_volume/mass (only metabolic_volume
## differs) must RAISE it. This is the behavior the compute_debt Tier-D swap delivers; without
## it, both twins would raise demand identically.
##
## Run headless:  godot --headless --path . --script res://tests/test_tier_d_metabolic_demand.gd
## Exit code 0 = all pass, 1 = at least one failure.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Tier-D metabolic-demand golden tests ===")
	_test_inert_spike_does_not_raise_demand()
	_test_muscle_surcharge_raises_demand()
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


func _def(part_type: StringName, density: float, extents: Vector3) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	return d

func _socket(pos: Vector3, hinge := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new()
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.hinge_axis = hinge
	return s

func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null) -> PartGene:
	var g := PartGene.new()
	g.definition = defn
	var tarr: Array[StringName] = []
	for t in tags:
		tarr.append(t)
	g.tags = tarr
	g.socket = socket
	return g

# Supply-limited body: a small heart relative to a large torso + 4 legs, so the heart cannot
# fully perfuse the mass and metabolic_debt lands strictly inside (0, 1).
func _supply_limited_body() -> PartGene:
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8)), [&"spine", &"ground_contact"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.1, 0.1, 0.1)), [&"heart"], _socket(Vector3.ZERO)))
	var leg := _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1))
	for p in [Vector3(-0.4, -0.2, -0.6), Vector3(0.4, -0.2, -0.6),
			Vector3(-0.4, -0.2, 0.6), Vector3(0.4, -0.2, 0.6)]:
		root.children.append(_gene(leg, [&"locomotor", &"ground_contact"], _socket(p, Vector3(1, 0, 0))))
	return root

# A bulky authored spike. metabolic flag decides only metabolic_volume; total_volume/mass/SA
# are identical so the ONLY variable is demand contribution.
func _spike(metabolic: bool) -> PhysicsDescriptor:
	var d := PhysicsDescriptor.new()
	d.total_volume = 0.20
	d.metabolic_volume = (0.20 if metabolic else 0.0)
	d.surface_metabolic = 0.0                       # keep SA out of it: isolate metabolic_debt
	d.mass = 30.0
	d.center_of_mass = Vector3(0.0, 0.10, 0.0)
	d.bounding_radius = 0.3
	return d

func _with_spike(metabolic: bool) -> PartGene:
	var root := _supply_limited_body()
	var spike := _gene(_def(&"box", 1500.0, Vector3(0.1, 0.2, 0.1)), [&"attack"], _socket(Vector3(0.0, 0.2, 0.5)))
	spike.descriptor = _spike(metabolic)
	root.children.append(spike)
	return root


# Same supply-limited body, but the four legs are tagged muscle. Mass/volume are identical
# (tags don't change density); only the M9B muscle-mass fraction differs.
func _muscled_body() -> PartGene:
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8)), [&"spine", &"ground_contact"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.1, 0.1, 0.1)), [&"heart"], _socket(Vector3.ZERO)))
	var leg := _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1))
	for p in [Vector3(-0.4, -0.2, -0.6), Vector3(0.4, -0.2, -0.6),
			Vector3(-0.4, -0.2, 0.6), Vector3(0.4, -0.2, 0.6)]:
		root.children.append(_gene(leg, [&"locomotor", &"ground_contact", &"muscle"], _socket(p, Vector3(1, 0, 0))))
	return root


func _test_muscle_surcharge_raises_demand() -> void:
	print("- M9B: muscle tissue raises metabolic demand (scale-invariant surcharge)")
	var base := CE.evaluate(_supply_limited_body())
	var muscled := CE.evaluate(_muscled_body())
	var d_base := float(base["debt"]["metabolic_debt"])
	var d_musc := float(muscled["debt"]["metabolic_debt"])
	print("    metabolic_debt: base=%.5f  +muscle=%.5f" % [d_base, d_musc])
	# Muscle is expensive tissue -> higher demand -> higher debt on a supply-limited body.
	_check(d_musc > d_base + 1e-4, "muscle-tagged legs RAISE metabolic_debt")
	# Mass is independent of the muscle tag (surcharge is metabolic, not structural).
	_check(_approx(float(base["total_mass"]), float(muscled["total_mass"]), 1e-6),
			"muscle tag does not change mass (surcharge is metabolic only)")


func _test_inert_spike_does_not_raise_demand() -> void:
	print("- inert spike adds mass but ZERO metabolic demand; metabolic twin raises demand")
	var base := CE.evaluate(_supply_limited_body())
	var inert := CE.evaluate(_with_spike(false))
	var meta := CE.evaluate(_with_spike(true))

	var d_base := float(base["debt"]["metabolic_debt"])
	var d_inert := float(inert["debt"]["metabolic_debt"])
	var d_meta := float(meta["debt"]["metabolic_debt"])
	print("    metabolic_debt: base=%.5f  +inert=%.5f  +metabolic=%.5f" % [d_base, d_inert, d_meta])

	# Sanity: the body must actually be supply-limited (debt strictly inside the open interval),
	# otherwise the comparison is masked by the 0/1 clamp.
	_check(d_base > 0.01 and d_base < 0.99, "baseline is supply-limited (0 < metabolic_debt < 1)")
	# Inert spike: metabolic_volume = 0 -> demand unchanged -> debt unchanged.
	_check(_approx(d_inert, d_base, 1e-6), "inert spike leaves metabolic_debt unchanged")
	# Metabolic twin: identical volume/mass but metabolic_volume = 0.20 -> demand up -> debt up.
	_check(d_meta > d_inert + 1e-4, "metabolic twin RAISES metabolic_debt above the inert spike")
	# Both spikes weigh the same (mass is independent of metabolic class).
	_check(_approx(float(inert["total_mass"]), float(meta["total_mass"]), 1e-6),
			"inert and metabolic spikes have identical mass")
	# And both enlarge total_volume equally (inert still feeds body_radius — BITE NOTE B-BR).
	_check(_approx(float(inert["total_volume"]), float(meta["total_volume"]), 1e-9),
			"both spikes add identical total_volume (inert still occupies space)")
