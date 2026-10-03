extends SceneTree

const PreEventRingBufferScript := preload(
	"res://scripts/lab/pre_event_ring_buffer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab crash-local pre-event buffer contract ===")
	var directory := OS.get_temp_dir().path_join(
		"sporespore_pre_event_%d" % OS.get_process_id())
	var snapshot := directory.path_join("pre_event_snapshot.jsonl")
	var buffer = PreEventRingBufferScript.new(directory, 3, "pre_event_run")
	_check(bool(buffer.initialize()["ok"]), "disk-backed ring directory initializes")
	for frame_id in 5:
		var result: Dictionary = buffer.append(frame_id, {
			"frame_id": frame_id,
			"marker": "tick_%d" % frame_id,
		})
		_check(bool(result["ok"]), "tick %d reaches a complete slot" % frame_id)
	var recovered: Array = buffer.recover_contiguous()
	_check(recovered.size() == 3, "capacity-three ring recovers its latest three entries")
	if recovered.size() == 3:
		_check(int(recovered[0]["sequence"]) == 2, "recovered chain begins at evicted-window boundary")
		_check(int(recovered[2]["sequence"]) == 4, "recovered chain ends at latest complete entry")
		var materialized: Dictionary = buffer.materialize_snapshot(snapshot)
		_check(bool(materialized["ok"]), "valid contiguous chain materializes to JSONL")
		if bool(materialized["ok"]):
			var lines := FileAccess.get_file_as_string(snapshot).strip_edges().split("\n")
			_check(lines.size() == 3, "snapshot contains one parseable line per recovered entry")
			for line in lines:
				_check(JSON.parse_string(line) is Dictionary, "snapshot line is valid JSON")
	_cleanup(directory)
	_finish()


func _cleanup(directory: String) -> void:
	var access := DirAccess.open(directory)
	if access != null:
		for name in access.get_files():
			DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)


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
