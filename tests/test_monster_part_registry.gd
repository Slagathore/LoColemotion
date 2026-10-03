extends SceneTree

const MonsterPartRegistryScript := preload("res://scripts/creature/monster_part_registry.gd")
const PartMeshProviderScript := preload("res://scripts/creature/part_mesh_provider.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Monster part registry tests ===")
	_test_manifest_registers_valid_mesh_and_reports_missing()
	_test_invalid_manifest_is_actionable()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_manifest_registers_valid_mesh_and_reports_missing() -> void:
	print("- manifest validation/register/fallback")
	PartMeshProviderScript.clear_authored()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.3, 0.4)
	var mesh_path := "user://monster_part_registry_box.tres"
	_check(ResourceSaver.save(mesh, mesh_path) == OK, "test mesh resource saved")
	var manifest_path := "user://monster_part_registry_manifest.json"
	var data := {
		"parts": [
			{"id": "asset_leg", "mesh": mesh_path},
			{"id": "missing_blade", "mesh": "res://assets/parts/does_not_exist.glb"},
		],
	}
	_write_json(manifest_path, data)
	var result: Dictionary = MonsterPartRegistryScript.load_manifest(manifest_path)
	_check(not bool(result.get("ok", true)), "manifest with one missing asset is not marked fully ok")
	_check((result.get("registered", []) as Array).size() == 1, "valid authored mesh is registered")
	_check((result.get("missing", []) as Array).size() == 1, "missing authored mesh is reported")
	_check(PartMeshProviderScript.has_authored(&"asset_leg")
			and PartMeshProviderScript.authored_path(&"asset_leg") == mesh_path,
			"PartMeshProvider stores registered path by stable part_id")
	var gene := PartCatalog.clone_template(&"primitive_box")
	gene.part_id = &"asset_leg"
	var authored := PartMeshProviderScript.mesh_for_part(gene, Vector3.ONE)
	_check(authored is BoxMesh and is_equal_approx((authored as BoxMesh).size.y, 0.3),
			"registered authored mesh loads through PartMeshProvider")
	var fallback_gene := PartCatalog.clone_template(&"primitive_capsule")
	fallback_gene.part_id = &"missing_blade"
	var fallback := PartMeshProviderScript.mesh_for_part(fallback_gene, Vector3(0.1, 0.4, 0.1))
	_check(fallback is CapsuleMesh, "missing authored mesh falls back to primitive part mesh")


func _test_invalid_manifest_is_actionable() -> void:
	print("- invalid manifest entries report errors")
	var path := "user://monster_part_registry_invalid.json"
	_write_json(path, {"parts": [{"mesh": "res://assets/parts/no_id.glb"}, {"id": "no_path"}]})
	var result: Dictionary = MonsterPartRegistryScript.validate_manifest(path)
	_check(not bool(result.get("ok", true)), "invalid manifest is rejected")
	_check((result.get("invalid", []) as Array).size() == 2, "invalid entries report per-row reasons")


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
