class_name CorpusBuilder
extends RefCounted

## Builds categorized calibration/correlation corpora. Each entry is
## {name, source_category, root}; runners write outputs separately.


class Config:
	extends Resource
	var seed := 1
	var generated_count := 40
	var mutation_count := 12
	var known_bad_count := 2
	var include_builtins := true
	var include_trained := true

const REQUIRED_CATEGORIES := [&"hand_authored", &"generated", &"random_mutation"]
const EXEMPT_CATEGORIES := [&"known_bad"]
const REQUIRED_BODY_PLANS := ["biped_kneed", "quadruped", "quadruped_kneed", "hexapod", "8_feet"]


static func build(cfg: Config = null) -> Array[Dictionary]:
	var c := cfg if cfg != null else Config.new()
	var out: Array[Dictionary] = []
	if c.include_builtins:
		for card in PartCatalog.built_in_cards():
			out.append(_entry({
				"name": card.display_name,
				"source_category": &"hand_authored",
				"root": GenomeSnapshot.deep_copy(card.root),
			}))

	if c.include_trained:
		for row in TrainingLog.trained_root_entries():
			out.append(_entry(row))

	for i in c.generated_count:
		out.append(_entry({
			"name": "generated_%02d" % i,
			"source_category": &"generated",
			"root": _generated_for_slot(c.seed + i, i),
		}))

	var mut_cfg := GenomeMutator.Config.new()
	var base := PartCatalog.make_quadruped(false)
	for i in c.mutation_count:
		var rng := RandomNumberGenerator.new()
		rng.seed = c.seed * 1009 + i
		out.append(_entry({
			"name": "mutation_%02d" % i,
			"source_category": &"random_mutation",
			"root": GenomeMutator.mutate(base, mut_cfg, rng),
		}))
	for i in c.known_bad_count:
		out.append(_entry({
			"name": "known_bad_%02d" % i,
			"source_category": &"known_bad",
			"root": _known_bad(i),
		}))
	return out


static func category_counts(corpus: Array) -> Dictionary:
	var counts := {}
	for row in corpus:
		var k: StringName = row.get("source_category", &"unknown")
		counts[k] = int(counts.get(k, 0)) + 1
	return counts


static func body_plan_counts(corpus: Array) -> Dictionary:
	var counts := {}
	for row in corpus:
		var k := String(row.get("body_plan", "unknown"))
		counts[k] = int(counts.get(k, 0)) + 1
	return counts


static func _entry(data: Dictionary) -> Dictionary:
	var root: PartGene = data.get("root", null)
	var features := CreatureFeatures.extract(root) if root != null else {}
	var row := data.duplicate(true)
	row["features"] = features
	row["body_plan"] = body_plan_label(features)
	return row


static func body_plan_label(features: Dictionary) -> String:
	var feet := int(features.get("foot_count", 0))
	var leg_segments := int(features.get("leg_segments", 1))
	if feet <= 0:
		return "no_feet"
	if feet == 2:
		return "biped_kneed" if leg_segments > 1 else "biped"
	if feet == 4:
		return "quadruped_kneed" if leg_segments > 1 else "quadruped"
	if feet == 6:
		return "hexapod_kneed" if leg_segments > 1 else "hexapod"
	return "%d_feet" % feet


static func floor_report(corpus: Array, min_total := 60, min_category := 10,
		min_body_plan := 8) -> Dictionary:
	var cat := category_counts(corpus)
	var bp := body_plan_counts(corpus)
	var blockers: Array[String] = []
	if corpus.size() < min_total:
		blockers.append("total %d < floor %d" % [corpus.size(), min_total])
	for k in REQUIRED_CATEGORIES:
		if int(cat.get(k, 0)) < min_category:
			blockers.append("category %s has %d < %d" % [String(k), int(cat.get(k, 0)), min_category])
	for k in EXEMPT_CATEGORIES:
		if not cat.has(k):
			cat[k] = 0
	for k in REQUIRED_BODY_PLANS:
		if int(bp.get(k, 0)) < min_body_plan:
			blockers.append("body_plan %s has %d < %d" % [String(k), int(bp.get(k, 0)), min_body_plan])
	return {"ok": blockers.is_empty(), "total": corpus.size(), "category_counts": cat,
		"body_plan_counts": bp, "blockers": blockers}


static func _generated_for_slot(seed_value: int, slot: int) -> PartGene:
	match slot % 5:
		0:
			return CreatureGenerator.make_biped(seed_value)
		1:
			var qcfg := CreatureGenerator.Config.new()
			qcfg.seed = seed_value
			qcfg.spine_segments_min = 1
			qcfg.spine_segments_max = 1
			qcfg.limb_pairs_min = 2
			qcfg.limb_pairs_max = 2
			qcfg.leg_segments = 1
			qcfg.want_head = false
			qcfg.want_organs = true
			return CreatureGenerator.generate(qcfg)
		2:
			return CreatureGenerator.make_segmented_quadruped(seed_value)
		3:
			return CreatureGenerator.make_hexapod(seed_value)
		4:
			return CreatureGenerator.make_spider(seed_value)
	return CreatureGenerator.generate()


static func _known_bad(i: int) -> PartGene:
	var d := PartDefinition.new()
	d.part_type = &"box"
	d.density = 1000.0
	d.extents = Vector3(0.35, 0.30, 0.45)
	var g := PartGene.new()
	g.definition = d
	g.tags = [&"spine", &"ground_contact"]
	if i % 2 == 1:
		g.tags.append(&"anaerobic")
	return g
