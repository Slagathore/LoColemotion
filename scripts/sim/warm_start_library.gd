class_name WarmStartLibrary
extends RefCounted

## Cross-creature gait memory. Stores, per trained creature, the body feature
## vector + the creature-agnostic drive scales + gait pattern that worked best.
## A new creature warm-starts from the nearest known body, so it doesn't search
## from scratch — "it walked a body like yours with a trot and these scales."
##
## Only the SCALES (amplitude/frequency/gain/traction/posture) and the PATTERN
## name transfer across creatures; per-socket phases don't (socket ids differ),
## so the trainer re-instantiates the pattern for the new creature's legs.

static func _path() -> String:
	return TrainingLog.base_dir.path_join("warm_start.json")


# Remember a result if it beats what we have for this creature_id.
static func remember(creature_id: String, features: Dictionary, scales: Dictionary,
		pattern: StringName, fitness: float, root_snapshot: Dictionary = {}) -> void:
	var lib := _read()
	var prev = lib.get(creature_id, null)
	if prev != null and float(prev.get("fitness", -INF)) >= fitness:
		return
	lib[creature_id] = {
		"creature_id": creature_id,
		"features": features,
		"scales": scales,
		"pattern": String(pattern),
		"fitness": fitness,
		"root": root_snapshot,
	}
	_write(lib)


# Best seed for a new body: nearest stored entry by feature distance.
# Returns {} if the library is empty. min_fitness filters out junk entries.
static func best_seed_for(features: Dictionary, min_fitness := -1e9) -> Dictionary:
	var lib := _read()
	var best = null
	var best_d := INF
	for cid in lib:
		var entry = lib[cid]
		if float(entry.get("fitness", -INF)) < min_fitness:
			continue
		var d := CreatureFeatures.distance(features, entry.get("features", {}))
		if d < best_d:
			best_d = d
			best = entry
	if best == null:
		return {}
	return {
		"scales": best.get("scales", {}),
		"pattern": StringName(best.get("pattern", "trot")),
		"distance": best_d,
		"from": best.get("creature_id", ""),
		"fitness": float(best.get("fitness", 0.0)),
	}


static func entries() -> Array:
	var out: Array = []
	for cid in _read():
		out.append(_read()[cid])
	return out


static func reset() -> void:
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path()))


static func _read() -> Dictionary:
	if not FileAccess.file_exists(_path()):
		return {}
	var f := FileAccess.open(_path(), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


static func _write(lib: Dictionary) -> void:
	var dir := _path().get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(lib, "\t"))
	f.close()
