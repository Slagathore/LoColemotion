class_name CalibrationRunner
extends RefCounted

## C2 calibration guardrails. This class does not mutate evaluator constants in
## tests; it decides whether a calibration result is promising or has hit the
## structural ceiling described in the bootstrap.


class Config:
	extends Resource
	var target_spearman := 0.55
	var plateau_epsilon := 0.02
	var max_gain_scale := 2.0
	var min_gain_scale := 0.25


static func assess(history: Array[Dictionary], cfg: Config = null) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	if history.is_empty():
		return {"ok": false, "decision": &"no_data", "reason": "empty calibration history"}
	var best := -INF
	for row in history:
		best = maxf(best, float(row.get("spearman", -INF)))
	var latest := float(history[history.size() - 1].get("spearman", -INF))
	var plateau := history.size() >= 3 and absf(latest - best) <= c.plateau_epsilon
	if best >= c.target_spearman:
		return {"ok": true, "decision": &"accept", "best_spearman": best,
			"live_behavior_changes": true}
	if plateau:
		return {"ok": true, "decision": &"structural_ceiling", "best_spearman": best,
			"reason": "rank correlation plateaued below target; improve probe contact/thrust structure before overfitting constants"}
	return {"ok": true, "decision": &"continue", "best_spearman": best,
		"live_behavior_changes": true}
