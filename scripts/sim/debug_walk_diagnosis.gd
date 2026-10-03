extends SceneTree

const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

const OUT_PATH := "res://data/runs/walk_diagnosis_latest.jsonl"

var _file: FileAccess


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/runs"))
	_file = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	_write({"event": "start", "out_path": OUT_PATH})
	await _diagnose("builtin_quad", PartCatalog.make_quadruped(false))
	await _diagnose("generated_biped", CreatureGenerator.make_biped(7))
	await _diagnose("generated_hexapod", CreatureGenerator.make_hexapod(11))
	await _diagnose("generated_segmented_quadruped", CreatureGenerator.make_segmented_quadruped(13))
	var tuned := CreatureIO.load("res://data/creatures/tuned_walker.tres")
	if tuned != null:
		await _diagnose("tuned_walker", tuned.root)
	_write({"event": "done"})
	_file.close()
	print("wrote ", OUT_PATH)
	quit(0)


func _diagnose(label: String, root_gene: PartGene) -> void:
	var eval := CharacteristicsEvaluator.evaluate(root_gene)
	var gait: GaitDef = root_gene.gait
	var tuned_params := _params_from_gait(gait)
	_write({
		"event": "creature",
		"label": label,
		"parts": CharacteristicsEvaluator.fold_graph(root_gene, Transform3D.IDENTITY)["parts"].size(),
		"drive_sockets": GaitOptimizer.driven_sockets(root_gene).size(),
		"analytic_speed": float(eval["speed"]["value"]),
		"analytic_probe_distance": float(eval["probe"]["distance"]),
		"probe_verdict": String(eval["probe"]["verdict"]),
		"gait_scales": _gait_scales(gait),
	})
	if gait != null:
		await _rollout(label, "editor_gait_params", root_gene, tuned_params)
	else:
		await _rollout(label, "default_params", root_gene, null)


func _rollout(label: String, mode: String, root_gene: PartGene,
		ctrl_params: CpgControllerScript.Params) -> void:
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = ctrl_params
	var m: Dictionary = await SimRolloutScript.run(root_gene, 5.0, 123, self, rp)
	_write({
		"event": "rollout",
		"label": label,
		"mode": mode,
		"forward": float(m.get("forward", 0.0)),
		"forward_tail": float(m.get("forward_tail", 0.0)),
		"path_len": float(m.get("path_len", 0.0)),
		"straightness": float(m.get("straightness", 0.0)),
		"yaw_delta": float(m.get("yaw_delta", 0.0)),
		"energy": float(m.get("energy", 0.0)),
		"fell": bool(m.get("fell", true)),
		"credible_walk": bool(m.get("credible_walk", false)),
		"locomotion_class": String(m.get("locomotion_class", &"unknown")),
		"locomotion_reasons": m.get("locomotion_reasons", []),
		"root_up_min": float(m.get("root_up_min", 0.0)),
		"root_height_drop": float(m.get("root_height_drop", 0.0)),
		"theta_span": float(m.get("theta_span", 0.0)),
		"max_omega": float(m.get("max_omega", 0.0)),
		"drive_count": int(m.get("drive_count", 0)),
	})


func _params_from_gait(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p


func _gait_scales(gait: GaitDef) -> Dictionary:
	if gait == null:
		return {
			"amplitude": 1.0,
			"frequency": 1.0,
			"gain": 1.0,
			"traction": 0.0,
			"posture": 0.0,
			"assignments": 0,
		}
	return {
		"amplitude": gait.amplitude_scale,
		"frequency": gait.frequency_scale,
		"gain": gait.gain_scale,
		"traction": gait.traction_scale,
		"posture": gait.posture_scale,
		"assignments": gait.assignments.size(),
	}


func _write(row: Dictionary) -> void:
	print(JSON.stringify(row))
	if _file != null:
		_file.store_line(JSON.stringify(row))
