class_name CorrelationRunner
extends RefCounted

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

## C1 measured correlation runner. Streams one JSON object per creature and
## caches expensive measured rollouts by genome+rollout parameters.

var _cache: Dictionary = {}


class Config:
	extends Resource
	var horizon_s := 1.0
	var seed := 1
	var output_path := "user://correlation.jsonl"
	var controller_params = null
	var track = null


func run(corpus: Array[Dictionary], tree: SceneTree, cfg: Config = null) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	var file := FileAccess.open(c.output_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "cannot open output", "path": c.output_path}
	var analytic_scores := PackedFloat32Array()
	var measured_scores := PackedFloat32Array()
	var rows_data: Array[Dictionary] = []
	var rows := 0
	var measured_only_rows := 0
	for i in corpus.size():
		var entry := corpus[i]
		var root_gene: PartGene = entry["root"]
		var analytic := CharacteristicsEvaluator.evaluate(root_gene)
		var measured := await measured_rollout(root_gene, c.horizon_s, c.seed + i, tree,
				_rollout_params(c))
		# M39: contact-subset creatures (pogo/urchin) are probe-BLIND (Principle 16) — the
		# phase-stance probe cannot see real contact, so they are excluded from the analytic
		# correlation rather than dragging it down with an un-predictable score.
		var measured_only := int(measured.get("contact_subset_drives", 0)) > 0
		var row := {
			"index": i,
			"name": String(entry.get("name", "creature_%02d" % i)),
			"source_category": String(entry.get("source_category", &"unknown")),
			"body_plan": String(entry.get("body_plan", "unknown")),
			"genome_hash": genome_hash(root_gene),
			"analytic_speed": float(analytic["speed"]["value"]),
			"measured_forward": float(measured.get("forward", 0.0)),
			"measured_speed": float(measured.get("mean_speed", 0.0)),
			"assist_ratio": float(measured.get("assist_ratio", 0.0)),
			"energy": float(measured.get("energy", 0.0)),
			"fell": bool(measured.get("fell", true)),
			"ok": bool(measured.get("ok", false)),
			"cached": bool(measured.get("cached", false)),
			"measured_only": measured_only,
		}
		file.store_line(JSON.stringify(row))
		rows_data.append(row)
		if measured_only:
			measured_only_rows += 1
		else:
			analytic_scores.append(float(row["analytic_speed"]))
			measured_scores.append(float(row["measured_speed"]))
		rows += 1
	file.close()
	var global := _corr(analytic_scores, measured_scores)
	return {
		"ok": true,
		"rows": rows,
		"measured_only_rows": measured_only_rows,   # M39: excluded from the probe correlation
		"row_data": rows_data,
		"output_path": c.output_path,
		"spearman": global["spearman"],
		"kendall": global["kendall"],
		"by_category": _group_corr(rows_data, "source_category"),
		"by_body_plan": _group_corr(rows_data, "body_plan"),
		"cache_entries": _cache.size(),
	}


func measured_rollout(root_gene: PartGene, horizon_s: float, seed: int,
		tree: SceneTree, params = null) -> Dictionary:
	var key := measured_cache_key(root_gene, horizon_s, seed, rollout_params_signature(params))
	if _cache.has(key):
		var cached: Dictionary = _cache[key].duplicate(true)
		cached["cached"] = true
		return cached
	var measured: Dictionary = await SimRolloutScript.run(root_gene, horizon_s, seed, tree, params)
	measured["cached"] = false
	_cache[key] = measured.duplicate(true)
	return measured


static func measured_cache_key(root_gene: PartGene, horizon_s: float, seed: int,
		params_signature := "params=derived_gait") -> String:
	return "%s|h=%.3f|seed=%d|%s" % [genome_hash(root_gene), horizon_s, seed, params_signature]


static func rollout_params_signature(params = null) -> String:
	if params == null:
		return "params=derived_gait"
	var parts: Array[String] = []
	var cp = params.controller_params
	if cp != null:
		parts.append("controller=a%.4f,f%.4f,g%.4f,t%.4f,p%.4f,turn%.4f" % [
			cp.amplitude_scale,
			cp.frequency_scale,
			cp.gain_scale,
			cp.traction_scale,
			cp.posture_scale,
			cp.turn_rate,
		])
	else:
		parts.append("controller=derived_gait")
	parts.append("assist_ceiling=%.4f" % float(params.assist_ratio_ceiling))
	if params.track != null:
		parts.append("track=%s" % String(params.track.kind))
	else:
		parts.append("track=none")
	return "|".join(parts)


static func _rollout_params(c: Config):
	if c.controller_params == null and c.track == null:
		return null
	var p := SimRolloutScript.Params.new()
	p.controller_params = c.controller_params
	p.track = c.track
	return p


static func genome_hash(root_gene: PartGene) -> String:
	var sig := EvolutionEngine.genome_signature(root_gene)
	return "%08x" % (hash(sig) & 0x7fffffff)


static func _corr(xs: PackedFloat32Array, ys: PackedFloat32Array) -> Dictionary:
	return {"n": xs.size(), "spearman": Reconcile.spearman(xs, ys),
		"kendall": Reconcile.kendall(xs, ys)}


static func _group_corr(rows: Array[Dictionary], key: String) -> Dictionary:
	var groups := {}
	for row in rows:
		if bool(row.get("measured_only", false)):
			continue                                # M39: probe-blind, not in any probe correlation
		var k := String(row.get(key, "unknown"))
		if not groups.has(k):
			groups[k] = {"x": PackedFloat32Array(), "y": PackedFloat32Array(), "n": 0}
		groups[k]["x"].append(float(row.get("analytic_speed", 0.0)))
		groups[k]["y"].append(float(row.get("measured_speed", 0.0)))
		groups[k]["n"] = int(groups[k]["n"]) + 1
	var out := {}
	for k in groups.keys():
		var g: Dictionary = groups[k]
		var c := _corr(g["x"], g["y"])
		c["n"] = int(g["n"])
		out[k] = c
	return out
