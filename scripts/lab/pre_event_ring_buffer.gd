class_name LabPreEventRingBuffer
extends RefCounted

## Disk-backed crash context. Each complete slot is independently parseable and
## participates in a sequence/hash chain.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

var _directory := ""
var _capacity := 0
var _run_id := ""
var _next_sequence := 0
var _previous_record_hash: Variant = null


func _init(directory := "", capacity := 120, run_id := "") -> void:
	_directory = directory
	_capacity = maxi(capacity, 1)
	_run_id = run_id


func initialize() -> Dictionary:
	var error := DirAccess.make_dir_recursive_absolute(_directory)
	return {
		"ok": error == OK or error == ERR_ALREADY_EXISTS,
		"code": error,
	}


func append(frame_id: int, payload: Dictionary) -> Dictionary:
	if frame_id < 0 or _directory.is_empty():
		return {"ok": false, "error": "INVALID_PRE_EVENT_ENTRY"}
	var normalized_payload: Dictionary = CanonicalJsonScript.normalize(payload)
	var body := {
		"schema": "sporespore.lab.pre_event_entry.v1",
		"run_id": _run_id,
		"sequence": _next_sequence,
		"frame_id": frame_id,
		"previous_record_sha256": _previous_record_hash,
		"payload": normalized_payload,
	}
	var sealed: Dictionary = FrozenValueScript.snapshot(body)
	var record_hash := CanonicalJsonScript.sha256(sealed)
	var entry: Dictionary = FrozenValueScript.snapshot({
		"schema": "sporespore.lab.pre_event_entry.v1",
		"run_id": _run_id,
		"sequence": _next_sequence,
		"frame_id": frame_id,
		"previous_record_sha256": _previous_record_hash,
		"record_sha256": record_hash,
		"payload": normalized_payload,
	})
	var slot := _next_sequence % _capacity
	var slot_path := _directory.path_join("slot_%06d.json" % slot)
	var result := _atomic_store(slot_path, CanonicalJsonScript.stringify(entry) + "\n")
	if not result["ok"]:
		return result
	_previous_record_hash = record_hash
	_next_sequence += 1
	return {"ok": true, "entry": entry, "slot_path": slot_path}


func recover_contiguous() -> Array:
	var entries: Array = []
	for slot in _capacity:
		var path := _directory.path_join("slot_%06d.json" % slot)
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and _entry_hash_is_valid(parsed):
			entries.append(parsed)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["sequence"]) < int(b["sequence"]))
	if entries.is_empty():
		return []
	var contiguous: Array = [entries[entries.size() - 1]]
	for index in range(entries.size() - 2, -1, -1):
		var newer: Dictionary = contiguous[0]
		var candidate: Dictionary = entries[index]
		if (int(candidate["sequence"]) + 1 == int(newer["sequence"])
			and String(newer.get("previous_record_sha256", "")) == String(
				candidate.get("record_sha256", ""))):
			contiguous.push_front(candidate)
		else:
			break
	return contiguous


func materialize_snapshot(target_path: String) -> Dictionary:
	var entries := recover_contiguous()
	if entries.is_empty():
		return {"ok": false, "error": "NO_VALID_PRE_EVENT_ENTRIES"}
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "SNAPSHOT_OPEN_FAILED"}
	for entry in entries:
		file.store_line(CanonicalJsonScript.stringify(entry))
	file.flush()
	file.close()
	return {"ok": true, "entry_count": entries.size(), "path": target_path}


func cleanup_transient_slots() -> Dictionary:
	if not DirAccess.dir_exists_absolute(_directory):
		return {"ok": true, "removed": 0}
	var access := DirAccess.open(_directory)
	if access == null:
		return {"ok": false, "error": "RING_DIRECTORY_OPEN_FAILED"}
	var removed := 0
	for name in access.get_files():
		var path := _directory.path_join(name)
		var error := DirAccess.remove_absolute(path)
		if error != OK:
			return {
				"ok": false,
				"error": "RING_SLOT_REMOVE_FAILED",
				"path": path,
				"code": error,
			}
		removed += 1
	var directory_error := DirAccess.remove_absolute(_directory)
	return {
		"ok": directory_error == OK,
		"removed": removed,
		"error": "" if directory_error == OK else "RING_DIRECTORY_REMOVE_FAILED",
		"code": directory_error,
	}


func _entry_hash_is_valid(entry: Dictionary) -> bool:
	var hash_domain := {
		"schema": entry.get("schema"),
		"run_id": entry.get("run_id"),
		"sequence": entry.get("sequence"),
		"frame_id": entry.get("frame_id"),
		"previous_record_sha256": entry.get("previous_record_sha256"),
		"payload": entry.get("payload"),
	}
	return CanonicalJsonScript.sha256(hash_domain) == String(entry.get("record_sha256", ""))


static func _atomic_store(path: String, text: String) -> Dictionary:
	var tmp := "%s.tmp" % path
	var backup := "%s.previous" % path
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "TEMP_OPEN_FAILED"}
	file.store_string(text)
	file.flush()
	file.close()
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	var had_previous := FileAccess.file_exists(path)
	if had_previous:
		var backup_error := DirAccess.rename_absolute(path, backup)
		if backup_error != OK:
			return {"ok": false, "error": "SLOT_BACKUP_FAILED", "code": backup_error}
	var rename_error := DirAccess.rename_absolute(tmp, path)
	if rename_error != OK:
		if had_previous and FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		return {"ok": false, "error": "SLOT_REPLACE_FAILED", "code": rename_error}
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return {"ok": true}
