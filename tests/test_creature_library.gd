extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== CreatureLibrary tests ===")
	_test_add_refresh_load_remove()
	_test_rename_moves_card()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _card(name: String) -> CreatureCard:
	var c := CreatureCard.new()
	c.display_name = name
	c.root = PartCatalog.make_quadruped(false)
	c.notes = "library test"
	return c


func _test_add_refresh_load_remove() -> void:
	print("- add/refresh/load/remove reflect scan")
	var dir := "user://_sporespore_library"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var lib := CreatureLibrary.new(dir, false)
	var path := dir.path_join("library_card.tres")
	_remove_if_exists(path)
	_check(lib.add(_card("Library Card"), path) == OK, "library add saves a card")
	var row := lib.by_name("library_card")
	_check(not row.is_empty(), "refresh exposes saved card by file stem")
	var loaded := lib.load_row(row)
	_check(loaded != null and loaded.display_name == "Library Card", "load_row lazy-loads saved card")
	loaded.root.scale = Vector3(2, 2, 2)
	var loaded_again := lib.load_row(row)
	_check(loaded_again.root.scale == Vector3.ONE, "load_row returns isolated cards")
	_check(lib.remove(path) == OK, "library remove deletes saved file")
	_check(lib.by_name("library_card").is_empty(), "refresh drops removed card")


func _test_rename_moves_card() -> void:
	print("- rename saves under a new stem and removes the old file")
	var dir := "user://_sporespore_library"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var lib := CreatureLibrary.new(dir, false)
	var old_path := dir.path_join("rename_source.tres")
	var new_path := dir.path_join("renamed_card.tres")
	_remove_if_exists(old_path)
	_remove_if_exists(new_path)
	_check(lib.add(_card("Rename Source"), old_path) == OK, "rename fixture saved")
	_check(lib.rename(old_path, "Renamed Card") == OK, "rename returns OK")
	_check(not FileAccess.file_exists(old_path), "old file removed")
	_check(FileAccess.file_exists(new_path), "new file exists")
	var renamed := CreatureIO.load(new_path)
	_check(renamed != null and renamed.display_name == "Renamed Card", "renamed card display name updated")
	_remove_if_exists(new_path)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
