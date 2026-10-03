class_name CreatureAffordances
extends RefCounted

## M42 — affordance tags on the (currently hand-authored) bodies. The design notes' "generator"
## answer is to make existing bodies SEARCHABLE by deriving affordances from their structure,
## then proposing the locomotion modes those affordances plausibly support. This is NOT
## procedural morphogenesis (an L-system that grows a body from a seed) — that and body+gait
## co-evolution are deferred (§5). Affordances are DERIVED from existing tags/structure rather
## than hand-stamped, so the same map works for generated and mutated bodies too.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")


static func affordances(root_gene: PartGene) -> Dictionary:
	var parts: Array = CE.fold_graph(root_gene, Transform3D.IDENTITY)["parts"]
	var spring_leg := false
	var radial_spike := false
	var anisotropic_ventral := false
	var weapon := false
	var curlable := false
	var legs := 0
	var feet := 0
	var spine := 0
	var max_chain := 1
	for p in parts:
		if p.spring != null and p.spring.enabled:
			spring_leg = true
		if p.tags.has(&"pogo") or p.tags.has(&"radial"):
			radial_spike = true
		if p.tags.has(&"anisotropic_ventral"):
			anisotropic_ventral = true
		if p.weapon != null or p.tags.has(&"attack"):
			weapon = true
		if p.tags.has(&"shell") or p.tags.has(&"armor"):
			curlable = true
		if p.tags.has(&"ground_contact"):
			feet += 1
		if p.tags.has(&"spine"):
			spine += 1
		if p.tags.has(&"locomotor") and p.hinge_axis.length() > CE.EPS:
			legs += 1
			max_chain = maxi(max_chain, _chain_depth(parts, int(p.index)))
	return {
		"spring_leg": spring_leg,
		"radial_spike": radial_spike,
		"segmented_chain": max_chain > 1 or spine >= 4,
		"anisotropic_ventral": anisotropic_ventral,
		"weapon": weapon,
		"curlable": curlable,
		"leg_count": legs,
		"foot_count": feet,
		"spine_segments": spine,
		"leg_segments": max_chain,
	}


# The locomotion modes a body plausibly affords. walk is always a candidate (the cheap default);
# affordances ADD modes. The tournament then measures which one actually clears the M38 floor.
static func plausible_modes(root_gene: PartGene) -> Array[StringName]:
	var a := affordances(root_gene)
	var modes: Array[StringName] = [&"walk"]
	# A radial spike ball is a pogo/urchin, not a hopper — its "springs" are radial spines, not
	# hop legs. So hop only for spring legs that AREN'T part of a radial array.
	if bool(a["radial_spike"]):
		modes.append(&"pogo")
	elif bool(a["spring_leg"]):
		modes.append(&"hop")
	if bool(a["anisotropic_ventral"]):
		modes.append(&"undulation")
	if bool(a["curlable"]):
		modes.append(&"roll")
	# Few feet + wide stance with no spring => a sideways scuttler is worth trying.
	if int(a["foot_count"]) >= 6 and not bool(a["spring_leg"]):
		modes.append(&"lateral")
	return modes


static func _chain_depth(parts: Array, index: int) -> int:
	var depth := 1
	var frontier := [index]
	var seen := {index: true}
	var changed := true
	while changed:
		changed = false
		var next: Array = []
		for u in frontier:
			for c in parts:
				if int(c.parent) == int(u) and c.tags.has(&"locomotor") and not seen.has(int(c.index)):
					seen[int(c.index)] = true
					next.append(int(c.index))
					changed = true
		if not next.is_empty():
			depth += 1
			frontier = next
	return depth
