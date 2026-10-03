extends SceneTree

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

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
	print("=== Spring mechanics tests ===")
	_test_catalog_and_pregens_have_real_springs()
	_test_snapshot_preserves_spring_def()
	await _test_rollout_reports_spring_energy()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_catalog_and_pregens_have_real_springs() -> void:
	print("- catalog/pregen spring resources")
	var spring_joint := PartCatalog.clone_template(&"spring_joint")
	var spring_foot := PartCatalog.clone_template(&"spring_foot")
	_check(spring_joint != null and spring_joint.spring != null, "spring_joint template carries SpringDef")
	_check(spring_foot != null and spring_foot.spring != null, "spring_foot template carries SpringDef")
	_check(_count_springs(PartCatalog.make_frog_v2()) >= 2, "frog v2 has spring-defined hindlimbs")
	_check(_count_springs(PartCatalog.make_hopper_v2()) >= 2, "hopper v2 has spring-defined hindlimbs")
	_check(_count_springs(PartCatalog.make_monopod_v2()) >= 1, "monopod v2 has a spring-defined pogo leg")


func _test_snapshot_preserves_spring_def() -> void:
	print("- SpringDef snapshot round-trip")
	var root := PartCatalog.clone_template(&"spring_joint")
	root.spring.stiffness = 333.0
	root.spring.max_compression = 0.27
	var packed := GenomeSnapshot.to_dictionary(root)
	var restored := GenomeSnapshot.from_dictionary(JSON.parse_string(JSON.stringify(packed)))
	_check(restored != null and restored.spring != null, "spring snapshot restores resource")
	_check(is_equal_approx(restored.spring.stiffness, 333.0)
			and is_equal_approx(restored.spring.max_compression, 0.27),
			"spring numeric properties survive JSON round-trip")
	_check(restored.spring != root.spring, "restored spring resource is isolated")


func _test_rollout_reports_spring_energy() -> void:
	print("- measured rollout reports stored/released spring energy")
	var params := SimRolloutScript.Params.new()
	params.horizon_s = 0.85
	params.settle_ticks = 36
	var measured: Dictionary = await SimRolloutScript.run(PartCatalog.make_monopod_v2(), 0.85, 34, self, params)
	_check(measured.has("spring_energy_stored") and measured.has("spring_energy_released"),
			"rollout exposes spring energy fields")
	_check(int(measured.get("spring_drive_count", 0)) > 0,
			"rollout binds at least one spring-enabled drive")
	_check(float(measured.get("spring_energy_stored", 0.0)) > 0.0,
			"spring compression stores positive energy")
	_check(float(measured.get("spring_energy_released", 0.0)) > 0.0,
			"spring release reports positive work")


func _count_springs(g: PartGene) -> int:
	if g == null:
		return 0
	var count := 1 if g.spring != null else 0
	for child in g.children:
		count += _count_springs(child)
	return count
