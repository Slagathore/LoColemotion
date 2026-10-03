class_name ToolUseTrainer
extends RefCounted

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

## M8C bounded trainer: sweep a few controller scales on the tool-use track and
## keep the first/strongest ordered sequence. This is intentionally meta-level
## training; no LLM or planner runs inside the physics rollout.


class Config:
	extends Resource
	var horizon_s := 5.0
	var seed := 8800
	var target_distance := 1.75
	var apply_radius := 0.85
	var gain_scales: Array[float] = [1.0, 1.2]
	var traction_scales: Array[float] = [1.4, 1.8]
	var posture_scales: Array[float] = [2.2, 2.8]


static func train_once(root_gene: PartGene, tree: SceneTree, cfg: Config = null) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	if root_gene == null or tree == null:
		return {"ok": false, "error": "missing root/tree"}
	var best := {"ok": false, "fitness": -INF, "credible": false, "history": []}
	var history: Array[Dictionary] = []
	var trial := 0
	for gain in c.gain_scales:
		for traction in c.traction_scales:
			for posture in c.posture_scales:
				var params := SimRolloutScript.Params.new()
				params.controller_params = _controller_params(root_gene, gain, traction, posture)
				params.track = Track.tool_use(c.target_distance, c.apply_radius)
				var measured: Dictionary = await SimRolloutScript.run(root_gene, c.horizon_s,
						c.seed + trial, tree, params)
				var score: Dictionary = params.track.score(measured)
				var row := {
					"trial": trial,
					"gain_scale": gain,
					"traction_scale": traction,
					"posture_scale": posture,
					"grasped": bool(measured.get("grasp_grasped", false)),
					"carried": bool(measured.get("tool_carried", false)),
					"applied": bool(measured.get("tool_applied", false)),
					"flung": bool(measured.get("tool_flung", false)),
					"fell": bool(measured.get("fell", false)),
					"reach_used": bool(measured.get("reach_used", false)),
					"reach_effector_index": int(measured.get("reach_effector_index", -1)),
					"progress": int(score.get("progress", 0)),
					"fitness": float(score.get("fitness", -INF)),
					"credible": bool(score.get("credible", false)),
					"class": String(score.get("class", "")),
					"reasons": score.get("reasons", []),
				}
				history.append(row)
				if float(row["fitness"]) > float(best.get("fitness", -INF)):
					best = row.duplicate(true)
				if bool(row["credible"]):
					best = row.duplicate(true)
					best["ok"] = true
					best["history"] = history
					return best
				trial += 1
	best["ok"] = bool(best.get("credible", false))
	best["history"] = history
	return best


static func _controller_params(root_gene: PartGene, gain: float, traction: float,
		posture: float) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if root_gene != null and root_gene.gait != null:
		p.amplitude_scale = root_gene.gait.amplitude_scale
		p.frequency_scale = root_gene.gait.frequency_scale
		p.gain_scale = root_gene.gait.gain_scale
		p.traction_scale = root_gene.gait.traction_scale
		p.posture_scale = root_gene.gait.posture_scale
	p.gain_scale *= gain
	p.traction_scale = maxf(p.traction_scale, traction)
	p.posture_scale = maxf(p.posture_scale, posture)
	return p
