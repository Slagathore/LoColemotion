class_name TissueTypes
extends RefCounted

## Central tissue tag model. This is the M9B data layer: code can ask what a
## part's tags imply instead of open-coding "muscle/fat/armor" checks forever.

const DEFAULT := {
	"density_scale": 1.0,
	"metabolic_scale": 1.0,
	"strength_scale": 1.0,
	"damage_threshold_scale": 1.0,
}

const TYPES := {
	&"muscle": {
		"density_scale": 1.06,
		"metabolic_scale": 1.35,
		"strength_scale": 1.45,
		"damage_threshold_scale": 1.10,
	},
	&"fat": {
		"density_scale": 0.82,
		"metabolic_scale": 0.65,
		"strength_scale": 0.55,
		"damage_threshold_scale": 0.85,
	},
	&"armor": {
		"density_scale": 1.45,
		"metabolic_scale": 0.35,
		"strength_scale": 0.80,
		"damage_threshold_scale": 1.75,
	},
	&"tendon": {
		"density_scale": 1.12,
		"metabolic_scale": 0.80,
		"strength_scale": 1.15,
		"damage_threshold_scale": 1.50,
	},
}


static func properties(tags: Array) -> Dictionary:
	var out := DEFAULT.duplicate(true)
	for tag in tags:
		if not TYPES.has(tag):
			continue
		var p: Dictionary = TYPES[tag]
		for k in out:
			out[k] = float(out[k]) * float(p.get(k, 1.0))
	return out


static func effective_density(base_density: float, tags: Array) -> float:
	return maxf(base_density * float(properties(tags)["density_scale"]), 0.001)


static func damage_threshold(base_threshold: float, tags: Array) -> float:
	return maxf(base_threshold * float(properties(tags)["damage_threshold_scale"]), 0.001)
