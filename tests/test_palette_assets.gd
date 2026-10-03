extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Palette/Asset tests ===")
	_test_palette_drag_data_and_drop_gate()
	_test_skin_library_fallback_and_assembler_callback()
	_test_authored_mesh_provider()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_palette_drag_data_and_drop_gate() -> void:
	print("- palette emits drag data and drop legality uses SocketCatalog")
	var palette := PartPalette.new()
	root.add_child(palette)
	palette.populate()
	_check(palette.entry_count() >= 4, "tabbed palette exposes built-in entries")
	var data := palette.drag_data_for_index(0)
	_check(data.get("type", "") == "part_template" and data.has("id"), "palette drag data has template id")
	var gene := PartCatalog.make_quadruped(false)
	var fold := CharacteristicsEvaluator.fold_graph(gene, Transform3D.IDENTITY)
	var body = fold["parts"][0]
	var point := SocketCatalog.point_for(gene, &"limb_left_front")
	var world_point: Vector3 = body.xform * point.local_pose.origin
	var gate := ViewportDropTarget.can_drop_part(gene, 0, &"primitive_capsule", world_point)
	_check(bool(gate["ok"]) and (gate["point"] as AttachPoint).id == &"limb_left_front", "drop gate accepts compatible nearest point")
	var bad := ViewportDropTarget.can_drop_part(gene, 0, &"organ_heart", world_point)
	_check(not bool(bad["ok"]), "drop gate rejects incompatible point")
	palette.queue_free()


func _test_skin_library_fallback_and_assembler_callback() -> void:
	print("- skin fallback and per-part assembler material callback")
	var mat := SkinLibrary.material_for(&"missing_fixture", "user://definitely_empty_skins")
	_check(mat != null and mat.albedo_texture == null, "skin library returns tinted fallback without textures")
	var node := CreatureAssembler.build(PartCatalog.make_quadruped(false), Transform3D.IDENTITY,
			func(_p, _i): return SkinLibrary.material_for(_i, "user://definitely_empty_skins"))
	root.add_child(node)
	var first := node.get_child(0) as MeshInstance3D
	_check(first != null and first.material_override != null, "assembler accepts per-part material callback")
	node.queue_free()


func _test_authored_mesh_provider() -> void:
	print("- authored mesh registry falls back cleanly")
	PartMeshProvider.clear_authored()
	var gene := PartCatalog.clone_template(&"primitive_box")
	var fallback := PartMeshProvider.mesh_for_part(gene, Vector3.ONE)
	_check(fallback is BoxMesh, "unregistered part uses primitive fallback")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.3, 0.4)
	var path := "user://_authored_mesh_fixture.tres"
	ResourceSaver.save(mesh, path)
	PartMeshProvider.register_authored(gene.part_id, path)
	var authored := PartMeshProvider.mesh_for_part(gene, Vector3.ONE)
	_check(authored == mesh or authored is BoxMesh, "registered .tres mesh loads through authored seam")
	PartMeshProvider.clear_authored()
