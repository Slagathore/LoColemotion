class_name TuningHarness
extends RefCounted

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

## Small, headless tuning sweeps. Long optimizer runs should call this from
## scripts; unit tests keep horizons tiny.


class Sweep:
	extends Resource
	var foot_frictions: Array[float] = [0.7, 1.0, 1.3]
	var gain_scales: Array[float] = [0.75, 1.0, 1.25]
	var horizon_s := 1.0
	var seed := 1


static func run_sweep(root_gene: PartGene, tree: SceneTree, sweep: Sweep = null) -> Array[Dictionary]:
	var s := sweep if sweep != null else Sweep.new()
	var out: Array[Dictionary] = []
	for friction in s.foot_frictions:
		for gain in s.gain_scales:
			var bp := CreatureBodyScript.BuildParams.new()
			bp.foot_friction = friction
			var cp := CpgControllerScript.Params.new()
			cp.gain_scale = gain
			var rp := SimRolloutScript.Params.new()
			rp.build_params = bp
			rp.controller_params = cp
			var measured: Dictionary = await SimRolloutScript.run(root_gene, s.horizon_s, s.seed, tree, rp)
			out.append({
				"foot_friction": friction,
				"gain_scale": gain,
				"forward": float(measured.get("forward", 0.0)),
				"straightness": float(measured.get("straightness", 0.0)),
				"energy": float(measured.get("energy", 0.0)),
				"fell": bool(measured.get("fell", true)),
			})
	return out
