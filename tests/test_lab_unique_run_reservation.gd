extends SceneTree

const RunIndexScript := preload("res://scripts/lab/run_index.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab unique-run reservation contract ===")
	var root_path := OS.get_temp_dir().path_join(
		"sporespore_run_reservation_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		])
	DirAccess.make_dir_recursive_absolute(root_path)
	var first: Dictionary = RunIndexScript.reserve_partial(root_path, "same_run")
	var second: Dictionary = RunIndexScript.reserve_partial(root_path, "same_run")
	_check(bool(first["ok"]), "first run ID reserves a .partial directory")
	_check(not bool(second["ok"]), "same run ID cannot overwrite an existing reservation")
	_check(
		String(second["error"]) == "RUN_ID_ALREADY_RESERVED",
		"collision has a stable failure code")

	var existing_file_path := root_path.path_join("existing_file_run")
	_write_text(existing_file_path, "reservation-sentinel")
	var existing_file: Dictionary = RunIndexScript.reserve_partial(
		root_path, "existing_file_run")
	_check(
		not bool(existing_file["ok"])
			and String(existing_file["error"]) == "RUN_ID_ALREADY_RESERVED",
		"a pre-existing final-path file blocks initial reservation")
	_check(
		FileAccess.get_file_as_string(existing_file_path)
			== "reservation-sentinel",
		"initial collision detection never replaces the existing file")

	var late: Dictionary = RunIndexScript.reserve_partial(
		root_path, "late_file_run")
	_check(bool(late["ok"]), "late-collision fixture reserves its candidate")
	if bool(late["ok"]):
		_write_text(String(late["final_path"]), "publication-sentinel")
		var publication: Dictionary = RunIndexScript.finalize_partial(
			String(late["partial_path"]),
			String(late["final_path"]),
			true)
		_check(
			not bool(publication["ok"])
				and String(publication["error"]) == "FINAL_RUN_ALREADY_EXISTS",
			"a file appearing after reservation blocks parent publication")
		_check(
			FileAccess.get_file_as_string(String(late["final_path"]))
				== "publication-sentinel",
			"late collision detection preserves the existing file bytes")
		_check(
			DirAccess.dir_exists_absolute(String(late["partial_path"])),
			"late collision failure preserves the partial candidate")

	_remove_tree(root_path)
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


static func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.flush()
	file = null


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
