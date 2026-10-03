class_name Reconcile
extends RefCounted

## Keeps analytic and measured channels structurally separate and reports deltas.


static func compare(analytic: Dictionary, measured: Dictionary) -> Dictionary:
	var analytic_speed := float(analytic["speed"]["value"]) if analytic.has("speed") else 0.0
	var measured_speed := float(measured.get("forward", measured.get("distance", 0.0))) / maxf(float(measured.get("horizon_s", 1.0)), 0.001)
	var analytic_stable := bool(analytic["balance"]["stable"]) if analytic.has("balance") else false
	var measured_fell := bool(measured.get("fell", true))
	var credible_walk := bool(measured.get("credible_walk", false))
	var path_len := float(measured.get("path_len", absf(float(measured.get("forward", 0.0)))))
	var straightness := float(measured.get("straightness",
			float(measured.get("forward", 0.0)) / maxf(path_len, 0.001)))
	return {
		"analytic": analytic,
		"measured": measured,
		"deltas": {
			"speed": measured_speed - analytic_speed,
			"stable_match": analytic_stable == (not measured_fell),
			"energy": float(measured.get("energy", 0.0)),
			"credible_walk": credible_walk,
		},
		"fidelity": {
			"locomotion_ratio": measured_speed / maxf(absf(analytic_speed), 0.001),
			"straightness": straightness,
			"path_len": path_len,
			"locomotion_class": measured.get("locomotion_class", &"unknown"),
			"locomotion_reasons": measured.get("locomotion_reasons", []),
			"analytic_stable": analytic_stable,
			"measured_fell": measured_fell,
			"credible_walk": credible_walk,
		},
	}


static func spearman(xs: PackedFloat32Array, ys: PackedFloat32Array) -> float:
	if xs.size() != ys.size() or xs.size() < 2:
		return 0.0
	var rx := _ranks(xs)
	var ry := _ranks(ys)
	var n := xs.size()
	var sum_d2 := 0.0
	for i in n:
		var d := rx[i] - ry[i]
		sum_d2 += d * d
	return 1.0 - (6.0 * sum_d2) / (float(n) * (float(n) * float(n) - 1.0))


static func kendall(xs: PackedFloat32Array, ys: PackedFloat32Array) -> float:
	if xs.size() != ys.size() or xs.size() < 2:
		return 0.0
	var concordant := 0
	var discordant := 0
	for i in xs.size():
		for j in range(i + 1, xs.size()):
			var dx := signf(xs[i] - xs[j])
			var dy := signf(ys[i] - ys[j])
			if dx == 0.0 or dy == 0.0:
				continue
			if dx == dy:
				concordant += 1
			else:
				discordant += 1
	var denom := concordant + discordant
	return 0.0 if denom == 0 else float(concordant - discordant) / float(denom)


static func _ranks(values: PackedFloat32Array) -> PackedFloat32Array:
	var idxs: Array[int] = []
	for i in values.size():
		idxs.append(i)
	idxs.sort_custom(func(a: int, b: int) -> bool:
		if values[a] == values[b]:
			return a < b
		return values[a] < values[b]
	)
	var ranks := PackedFloat32Array()
	ranks.resize(values.size())
	for rank in idxs.size():
		ranks[idxs[rank]] = float(rank)
	return ranks
