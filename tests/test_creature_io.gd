extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== CreatureIO / PartCatalog tests ===")
	_test_catalog_templates_are_unique()
	_test_save_load_round_trip()
	_test_schema_gate_and_migration()
	_test_strict_load_rejects_aliasing()
	_test_scan_finds_saved_and_builtins()
	_test_loaded_card_is_isolated_from_disk()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _same_gene(a: PartGene, b: PartGene) -> bool:
	if a == null or b == null:
		return a == b
	if a == b:
		return false
	if a.definition == null or b.definition == null:
		return a.definition == b.definition
	if a.definition.part_type != b.definition.part_type: return false
	if a.definition.density != b.definition.density: return false
	if a.definition.extents != b.definition.extents: return false
	if a.definition.centroid_offset != b.definition.centroid_offset: return false
	if a.tags != b.tags: return false
	if a.scale != b.scale: return false
	if a.part_id != b.part_id or a.socket_id != b.socket_id: return false
	if (a.socket == null) != (b.socket == null): return false
	if a.socket != null:
		if a.socket == b.socket: return false
		if a.socket.id != b.socket.id: return false
		if a.socket.parent_attachment != b.socket.parent_attachment: return false
		if a.socket.child_anchor != b.socket.child_anchor: return false
		if a.socket.hinge_axis != b.socket.hinge_axis: return false
	if a.children.size() != b.children.size(): return false
	for i in a.children.size():
		if not _same_gene(a.children[i], b.children[i]):
			return false
	return true


func _card(name := "Round Trip") -> CreatureCard:
	var c := CreatureCard.new()
	c.display_name = name
	c.root = PartCatalog.make_quadruped(false)
	c.notes = "test card"
	return c


func _test_catalog_templates_are_unique() -> void:
	print("- catalog templates clone into valid editable genes")
	var leg_a := PartCatalog.clone_template(&"primitive_capsule")
	var leg_b := PartCatalog.clone_template(&"primitive_capsule")
	_check(leg_a != null and leg_b != null, "primitive capsule template exists")
	_check(leg_a != leg_b, "clone_template returns distinct PartGene instances")
	_check(bool(GenomeSnapshot.validate_unique(PartCatalog.make_quadruped(false))["ok"]),
			"built-in quadruped is uniqueness-valid")


func _test_save_load_round_trip() -> void:
	print("- embedded CreatureCard saves and loads deep-equal")
	var card := _card()
	var path := "user://_sporespore_card_roundtrip.tres"
	_check(CreatureIO.save(card, path) == OK, "save returns OK")
	var loaded := CreatureIO.load(path)
	_check(loaded != null, "load returns a CreatureCard")
	_check(loaded != card and loaded.root != card.root, "loaded card/root are isolated instances")
	_check(_same_gene(card.root, loaded.root), "loaded genome deep-equal to original")
	_check(bool(GenomeSnapshot.validate_unique(loaded.root)["ok"]), "loaded genome validates unique")


func _test_schema_gate_and_migration() -> void:
	print("- schema versions are gated and migrated")
	var future := _card("Future")
	future.schema_version = CreatureMigrations.CURRENT + 1
	var future_path := "user://_sporespore_future_card.tres"
	_check(ResourceSaver.save(future, future_path) == OK, "future-schema raw fixture saved")
	_check(CreatureIO.load(future_path) == null, "future schema is rejected")

	var old := _card("Old")
	old.schema_version = 0
	var old_path := "user://_sporespore_old_card.tres"
	_check(ResourceSaver.save(old, old_path) == OK, "old-schema raw fixture saved")
	var migrated := CreatureIO.load(old_path)
	_check(migrated != null, "old schema migrates")
	_check(migrated != null and migrated.schema_version == CreatureMigrations.CURRENT,
			"migrated card reaches current schema")


func _test_strict_load_rejects_aliasing() -> void:
	print("- strict load rejects malformed aliasing")
	var card := _card("Aliased")
	var shared := card.root.children[0].socket
	card.root.children[1].socket = shared
	var path := "user://_sporespore_aliased_card.tres"
	_check(ResourceSaver.save(card, path) == OK, "aliased raw fixture saved")
	_check(CreatureIO.load(path) == null, "strict load rejects shared SocketDef")


func _test_scan_finds_saved_and_builtins() -> void:
	print("- scan() lists built-ins and saved .tres cards")
	var path := "user://_sporespore_scan_card.tres"
	var card := _card("Scan Card")
	_check(CreatureIO.save(card, path) == OK, "scan fixture saved")
	var rows := CreatureIO.scan("user://", true)
	var saw_builtin := false
	var saw_saved := false
	for row in rows:
		if bool(row.get("builtin", false)):
			saw_builtin = true
		if String(row.get("path", "")) == path:
			saw_saved = true
	_check(saw_builtin, "scan includes built-in cards")
	_check(saw_saved, "scan includes saved .tres file")


func _test_loaded_card_is_isolated_from_disk() -> void:
	print("- mutating an in-memory card does not mutate the saved resource")
	var path := "user://_sporespore_isolation_card.tres"
	var card := _card("Isolation")
	_check(CreatureIO.save(card, path) == OK, "isolation fixture saved")
	var first := CreatureIO.load(path)
	first.root.scale = Vector3(9, 9, 9)
	var second := CreatureIO.load(path)
	_check(second.root.scale == Vector3.ONE, "fresh load ignores prior in-memory mutation")
