class_name CreatureFlavor
extends RefCounted

## The fun layer. Ten small, deterministic, side-effect-free helpers that give a creature a
## name, a personality, a mock taxonomy, medals, and trash-talk — turning a pile of physics
## metrics into something with character. All pure functions of (genome / measured dict), seeded
## by the genome signature (no RNG), so the same creature always gets the same name and emoji.
##
## Nothing here feeds physics or scoring (it's the I7 "display-only" spirit applied to text).

const CreatureAffordancesScript := preload("res://scripts/sim/creature_affordances.gd")

const _PREFIX: Array[String] = ["Spiky", "Springy", "Slithery", "Wobbly", "Stompy", "Prickly",
	"Gloopy", "Craggy", "Nimble", "Lumbering", "Twitchy", "Bristly", "Squat", "Gangly", "Armored",
	"Feral"]
const _ROOT: Array[String] = ["spore", "snout", "claw", "limbus", "pod", "thorax", "carapax",
	"tendril", "gnash", "scuttle", "lurch", "bounce", "fang", "spine", "wobble", "crawl"]
const _SUFFIX: Array[String] = ["us", "ix", "or", "ax", "oid", "ling", "opod", "osaur", "imus",
	"ette"]
const _SIG_GLYPHS: Array[String] = ["🜁", "🜂", "🜃", "🜄", "✦", "✧", "❖", "◆", "◇", "⬢", "⬡", "✺",
	"❂", "✸", "⚘", "☣"]


# 1. A stable, deterministic display name from the genome signature.
static func name_for(root_gene: PartGene) -> String:
	var h := _hash(root_gene)
	var first := _PREFIX[h % _PREFIX.size()]
	var mid := _ROOT[(h / 16) % _ROOT.size()]
	var suf := _SUFFIX[(h / 256) % _SUFFIX.size()]
	return "%s %s%s" % [first, mid.capitalize(), suf]


# 2. A mock Linnaean binomial from affordances — "Genus species".
static func taxonomy(root_gene: PartGene) -> String:
	var a := CreatureAffordancesScript.affordances(root_gene)
	var genus := "Ambulator"
	if bool(a["radial_spike"]):
		genus = "Echinoides"
	elif bool(a["anisotropic_ventral"]):
		genus = "Serpentis"
	elif bool(a["spring_leg"]):
		genus = "Saltator"
	elif bool(a["curlable"]):
		genus = "Testudo"
	var species := "vulgaris"
	if bool(a["weapon"]):
		species = "bellicosus"
	elif int(a["leg_count"]) >= 8:
		species = "multipes"
	elif int(a["foot_count"]) <= 2:
		species = "bipedalis"
	return "%s %s" % [genus, species]


# 3. Personality / temperament from affordances + build.
static func temperament(root_gene: PartGene) -> String:
	var a := CreatureAffordancesScript.affordances(root_gene)
	if bool(a["weapon"]) and bool(a["curlable"]):
		return "Battle-hardened"
	if bool(a["weapon"]):
		return "Aggressive"
	if bool(a["curlable"]):
		return "Defensive"
	if bool(a["radial_spike"]):
		return "Prickly loner"
	if bool(a["spring_leg"]):
		return "Bouncy"
	if int(a["leg_count"]) >= 8:
		return "Skittery"
	return "Placid grazer"


# 4. A 3-glyph DNA signature for quick visual ID (deterministic).
static func dna_signature(root_gene: PartGene) -> String:
	var h := _hash(root_gene)
	var n := _SIG_GLYPHS.size()
	return "%s%s%s" % [_SIG_GLYPHS[h % n], _SIG_GLYPHS[(h / 16) % n], _SIG_GLYPHS[(h / 256) % n]]


# 5. Cost-of-transport medal — efficiency rewarded with bling.
static func efficiency_medal(cot: float) -> String:
	if cot <= 0.0 or cot == INF:
		return "🚫 DNF"
	if cot < 0.15:
		return "🥇 Gold (featherweight strider)"
	if cot < 0.5:
		return "🥈 Silver (steady walker)"
	if cot < 2.0:
		return "🥉 Bronze (gets there)"
	return "🚶 Participation (thirsty mover)"


# 6. A funny label for each locomotion verdict class.
static func locomotion_flavor(locomotion_class: StringName) -> String:
	match locomotion_class:
		&"credible_walk": return "🚶 Bona-fide Walker"
		&"too_short": return "🐌 Couch Potato"
		&"lurch_or_jam": return "🪨 The Statue (lurched, then froze)"
		&"fall_or_tip": return "🤕 Faceplant Specialist"
		&"assist_carried": return "🛗 Riding the Elevator"
		&"skate_or_spin": return "⛸️ Ice Dancer"
		&"hopped": return "🦘 Pronk Champion"
		&"lateral_scuttle": return "🦀 Sideways Sommelier"
		&"rolled": return "🛞 Tumbleweed"
		&"pogo_drift": return "🛼 Pogo Prophet"
		&"undulated": return "🐍 Noodle Supreme"
		_: return "❓ Cryptid"


# 7. A fun threat rating from weapons + mass (0-10, "danger stars").
static func threat_level(root_gene: PartGene) -> Dictionary:
	var parts: Array = CharacteristicsEvaluator.fold_graph(root_gene, Transform3D.IDENTITY)["parts"]
	var arms := 0.0
	for p in parts:
		if p.weapon != null:
			var w: WeaponDef = p.weapon
			arms += maxf(w.sharpness, 0.0) + maxf(w.penetration, 0.0) + maxf(w.impact_multiplier - 1.0, 0.0)
		elif p.tags.has(&"attack"):
			arms += 0.4
	var stars := clampi(int(round(arms * 1.6)), 0, 10)
	return {"stars": stars, "bar": "★".repeat(stars) + "☆".repeat(10 - stars)}


# 8. An ASCII rhythm strip of the gait (when each driven socket fires in the cycle).
static func gait_rhythm(root_gene: PartGene, columns := 16) -> String:
	if root_gene == null or root_gene.gait == null or root_gene.gait.assignments.is_empty():
		return "(no authored gait)"
	var lines: Array[String] = []
	var keys := root_gene.gait.assignments.keys()
	keys.sort()
	for k in keys:
		var phase := fposmod(float(root_gene.gait.assignments[k]), 1.0)
		var slot := clampi(int(phase * columns), 0, columns - 1)
		var strip := ""
		for i in columns:
			strip += "▮" if i == slot else "·"
		lines.append("%s |%s|" % [String(k).left(10).rpad(10), strip])
	return "\n".join(lines)


# 9. Combat trash-talk for a bout result.
static func combat_quip(attacker: String, defender: String, dealt: float, taken: float) -> String:
	if dealt <= 0.0 and taken <= 0.0:
		return "😴 %s and %s circled, sniffed, and went home." % [attacker, defender]
	if dealt > taken * 3.0:
		return "💥 %s utterly demolished %s (%.0f vs %.0f)." % [attacker, defender, dealt, taken]
	if dealt > taken:
		return "🥊 %s edged out %s (%.0f vs %.0f)." % [attacker, defender, dealt, taken]
	if taken > dealt:
		return "🩹 %s got clobbered by %s (%.0f vs %.0f)." % [attacker, defender, dealt, taken]
	return "🤝 %s and %s fought to a bloody draw (%.0f each)." % [attacker, defender, dealt]


# 10. A console "stat card" tying it all together.
static func stat_card(root_gene: PartGene, measured: Dictionary = {}) -> String:
	var cot := float(measured.get("cost_of_transport", INF))
	var cls: StringName = measured.get("locomotion_class", &"unknown")
	var threat := threat_level(root_gene)
	var lines: Array[String] = [
		"╔═══════════════════════════════════════════",
		"║ %s   %s" % [name_for(root_gene), dna_signature(root_gene)],
		"║ %s · %s" % [taxonomy(root_gene), temperament(root_gene)],
		"║ Threat %s" % threat["bar"],
	]
	if not measured.is_empty():
		lines.append("║ %s" % locomotion_flavor(cls))
		lines.append("║ Economy: %s" % efficiency_medal(cot))
	lines.append("╚═══════════════════════════════════════════")
	return "\n".join(lines)


static func _hash(root_gene: PartGene) -> int:
	if root_gene == null:
		return 0
	var sig := EvolutionEngine.genome_signature(root_gene)
	return hash(sig) & 0x7fffffff
