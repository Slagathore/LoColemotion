class_name TrainingLog
extends RefCounted

## Append-only training history + counters. Every training run writes one JSONL
## line with ALL tunable settings and ALL measured metrics; a per-creature
## summary and a global aggregate are maintained alongside for fast counters.
##
## JSONL (not a DB) is deliberate: append-only is crash-safe, headless-friendly,
## and trivially scales to 100k+ runs (load + in-memory filter). If indefinite
## training ever needs live querying over millions of rows, swap the read side
## for SQLite — the write schema here is designed so that migration is mechanical.

## Base directory for this log store. Set a unique dir for isolated/concurrent
## training sessions (and so tests never collide with a live training run).
static var base_dir := "user://training"

static func _runs_path() -> String: return base_dir.path_join("runs.jsonl")
static func _failures_path() -> String: return base_dir.path_join("failures.jsonl")
static func _creatures_path() -> String: return base_dir.path_join("creatures.json")
static func _aggregate_path() -> String: return base_dir.path_join("aggregate.json")


# Record one run. `record` should already contain creature_id, body features,
# track, settings, and metrics. Returns the updated per-creature summary.
static func record_run(record: Dictionary, now_unix := 0.0) -> Dictionary:
	_ensure_dir()
	var row := record.duplicate(true)
	row["ts"] = now_unix
	_append_jsonl(_runs_path(), row)
	if not bool(record.get("credible_walk", false)):
		record_failure(record, now_unix)

	var cid := String(record.get("creature_id", "unknown"))
	var credible := bool(record.get("credible_walk", false))
	var fell := bool(record.get("fell", false))
	var fitness := float(record.get("fitness", record.get("forward", 0.0)))

	var creatures := _read_json(_creatures_path(), {})
	var s: Dictionary = creatures.get(cid, {
		"creature_id": cid, "runs": 0, "credible": 0, "falls": 0,
		"best_fitness": -INF, "best_forward": 0.0, "best_settings": {}, "last_ts": 0.0,
		"baseline_root": {}, "best_root": {},
	})
	if (s.get("baseline_root", {}) as Dictionary).is_empty() and record.has("baseline_root"):
		s["baseline_root"] = (record.get("baseline_root", {}) as Dictionary).duplicate(true)
	s["runs"] = int(s["runs"]) + 1
	if credible:
		s["credible"] = int(s["credible"]) + 1
	if fell:
		s["falls"] = int(s["falls"]) + 1
	if fitness > float(s["best_fitness"]):
		s["best_fitness"] = fitness
		s["best_forward"] = float(record.get("forward", 0.0))
		s["best_settings"] = record.get("settings", {}).duplicate(true)
		s["best_root"] = record.get("candidate_root", {}).duplicate(true)
	s["last_ts"] = now_unix
	creatures[cid] = s
	_write_json(_creatures_path(), creatures)

	var agg := _read_json(_aggregate_path(), {
		"total_runs": 0, "total_credible": 0, "total_falls": 0, "creatures_trained": 0,
	})
	agg["total_runs"] = int(agg["total_runs"]) + 1
	if credible:
		agg["total_credible"] = int(agg["total_credible"]) + 1
	if fell:
		agg["total_falls"] = int(agg["total_falls"]) + 1
	agg["creatures_trained"] = creatures.size()
	_write_json(_aggregate_path(), agg)
	return s


static func record_failure(record: Dictionary, now_unix := 0.0) -> void:
	_ensure_dir()
	var row := {
		"ts": now_unix,
		"creature_id": String(record.get("creature_id", "unknown")),
		"creature_name": String(record.get("creature_name", "")),
		"round": int(record.get("round", -1)),
		"track": String(record.get("track", "straight")),
		"class": String(record.get("locomotion_class", "unknown")),
		"reasons": record.get("locomotion_reasons", []),
		"forward": float(record.get("forward", 0.0)),
		"forward_tail": float(record.get("forward_tail", 0.0)),
		"fell": bool(record.get("fell", false)),
		"assist_per_meter": float(record.get("assist_per_meter", 0.0)),
		"assist_ratio": float(record.get("assist_ratio", 0.0)),
		"settings": record.get("settings", {}).duplicate(true),
	}
	_append_jsonl(_failures_path(), row)


static func aggregate() -> Dictionary:
	return _read_json(_aggregate_path(), {
		"total_runs": 0, "total_credible": 0, "total_falls": 0, "creatures_trained": 0,
	})


static func creature_summary(creature_id: String) -> Dictionary:
	return _read_json(_creatures_path(), {}).get(creature_id, {})


static func all_creatures() -> Dictionary:
	return _read_json(_creatures_path(), {})


static func trained_root_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var creatures := all_creatures()
	for cid in creatures:
		var s: Dictionary = creatures[cid]
		var root: Dictionary = s.get("best_root", {})
		if root.is_empty():
			continue
		var restored := GenomeSnapshot.from_dictionary(root)
		if restored == null:
			continue
		out.append({
			"name": "trained_%s" % String(cid),
			"creature_id": String(cid),
			"source_category": &"trained",
			"root": restored,
			"best_fitness": float(s.get("best_fitness", 0.0)),
			"best_forward": float(s.get("best_forward", 0.0)),
		})
	return out


# Loads every run record (for analysis / library building). Fine for 1000s-100k.
static func load_runs() -> Array:
	return _load_jsonl(_runs_path())


static func load_failures() -> Array:
	return _load_jsonl(_failures_path())


static func reset() -> void:
	for p in [_runs_path(), _failures_path(), _creatures_path(), _aggregate_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func _load_jsonl(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	f.close()
	return out


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base_dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))


static func _append_jsonl(path: String, row: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) \
			else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(row))
	f.close()


static func _read_json(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback.duplicate(true)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fallback.duplicate(true)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else fallback.duplicate(true)


static func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
