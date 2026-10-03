class_name EditorCopilot
extends RefCounted

## M49 (B20) — the in-editor LLM co-pilot's ACTION layer. It routes structured tool-calls onto the
## SAME public editor verbs a human clicks (which flow through EditSession → validated + undoable +
## re-scored; Principle 23: no privileged path). The model that PRODUCES the tool-calls — streaming
## chat, screen/genome/codebase reading, the scope checkbox UI — is play-tested; THIS is the
## deterministic router it drives, so every AI edit is inspectable and reversible.
##
## A tool-call: {"tool": &"set_spring", "args": {...}, "scope": &"current"}. scope = current binds to
## the editor creature; any other scope must NAME its target before mutating (the model states which
## creature it's about), so an unscoped request can't silently change the wrong thing.

static func execute(bench, call: Dictionary) -> Dictionary:
	if bench == null:
		return {"ok": false, "error": "no editor"}
	var tool := StringName(call.get("tool", &""))
	var args: Dictionary = call.get("args", {})
	var scope := StringName(call.get("scope", &"current"))

	# Queries + codebase reads are always safe (read-only) regardless of scope.
	if tool == &"query":
		return {"ok": true, "answer": _answer(bench, StringName(args.get("what", &"")))}
	if tool == &"read_file":
		return {"ok": true, "answer": read_codebase(String(args.get("path", "")), 8000)}

	# Mutations are bound to the editor creature only under the "current" scope; otherwise the model
	# must declare which creature it means before we touch anything.
	if scope != &"current":
		return {"ok": false, "needs_target": true, "scope": scope,
			"message": "Out-of-scope edit — name the target creature (new/saved/all) before applying."}

	match tool:
		&"select":
			bench.select_part(int(args.get("index", 0)))
			return {"ok": true, "undoable": false}
		&"add_part":
			return {"ok": bench.add_child_part_to_selected(
					StringName(args.get("part_id", &"primitive_capsule"))), "undoable": true}
		&"set_shape":
			return {"ok": bench.edit_selected_shape(
					StringName(args.get("part_type", &"box")),
					Vector3(float(args.get("size_x", 0.1)), float(args.get("size_y", 0.1)),
						float(args.get("size_z", 0.1))),
					float(args.get("density", 1000.0))), "undoable": true}
		&"set_transform":
			return {"ok": bench.edit_selected_socket(
					Vector3(float(args.get("pos_x", 0.0)), float(args.get("pos_y", 0.0)),
						float(args.get("pos_z", 0.0))),
					Vector3(float(args.get("axis_x", 0.0)), float(args.get("axis_y", 0.0)),
						float(args.get("axis_z", 0.0))),
					Vector3(float(args.get("rot_x", 0.0)), float(args.get("rot_y", 0.0)),
						float(args.get("rot_z", 0.0)))), "undoable": true}
		&"set_swing":
			return {"ok": bench.edit_selected_joint(
					float(args.get("amplitude", 1.0)), float(args.get("rest", 0.0)),
					float(args.get("min", -1.0)), float(args.get("max", 1.0))), "undoable": true}
		&"new_creature":
			bench.new_creature()
			return {"ok": true, "undoable": false}
		&"save":
			return {"ok": bench.save_current_card() == OK, "undoable": false}
		&"set_spring":
			return {"ok": bench.edit_selected_spring(float(args.get("stiffness", 220.0)),
					float(args.get("damping", 0.2)), float(args.get("efficiency", 0.7))),
					"undoable": true}
		&"set_weapon":
			return {"ok": bench.edit_selected_weapon(StringName(args.get("kind", &"blade")),
					float(args.get("sharpness", 0.6)), float(args.get("penetration", 0.3)),
					float(args.get("impact", 1.1)), float(args.get("reach", 0.1))), "undoable": true}
		&"set_mode":
			return {"ok": bench.set_root_locomotion_mode(StringName(args.get("mode", &""))),
					"undoable": true}
		&"undo":
			return {"ok": bench.undo(), "undoable": false}
		_:
			return {"ok": false, "error": "unknown tool '%s'" % String(tool)}


# ---------------------------------------------------------------------------
# M57 — the prompt / preview / read-context layer the chat dock drives. The dock UI (streaming
# log, scope checkbox, Apply/Discard) is play-tested; these are the deterministic, unit-tested
# pieces: the tool manifest the model is told about, the will-do preview shown before mutating,
# the truthful read context, and an allow-listed codebase reader (Principle 23: it answers only
# from what it can actually see).
# ---------------------------------------------------------------------------

const TOOLS := [
	{"tool": "select", "args": "{\"index\": int}", "desc": "select part N (see read-context indices)"},
	{"tool": "add_part", "args": "{\"part_id\": string}",
		"desc": "add a part (e.g. leg_upper, foot_pad, muscle_bundle) to the selected part"},
	{"tool": "set_shape",
		"args": "{\"part_type\": string, \"size_x\": float, \"size_y\": float, \"size_z\": float, \"density\": float}",
		"desc": "set the selected part's primitive (box|sphere|cylinder|capsule), half-size, and density"},
	{"tool": "set_transform",
		"args": "{\"pos_x\": f, \"pos_y\": f, \"pos_z\": f, \"axis_x\": f, \"axis_y\": f, \"axis_z\": f, \"rot_x\": f, \"rot_y\": f, \"rot_z\": f}",
		"desc": "set the selected part's Position (on parent), Joint bend axis, and Rotation (degrees)"},
	{"tool": "set_swing",
		"args": "{\"amplitude\": f, \"rest\": f, \"min\": f, \"max\": f}",
		"desc": "set the selected part's powered joint Swing (amplitude, rest, min, max radians)"},
	{"tool": "set_spring", "args": "{\"stiffness\": float, \"damping\": float, \"efficiency\": float}",
		"desc": "author a torsional spring on the selected part"},
	{"tool": "set_weapon",
		"args": "{\"kind\": string, \"sharpness\": float, \"penetration\": float, \"impact\": float, \"reach\": float}",
		"desc": "author a weapon on the selected part"},
	{"tool": "set_mode", "args": "{\"mode\": string}",
		"desc": "set the creature locomotion mode (walk|trot|hop|lateral|fly|roll)"},
	{"tool": "new_creature", "args": "{}", "desc": "start a fresh blank creature (single body box)"},
	{"tool": "save", "args": "{}", "desc": "save the current creature to the library"},
	{"tool": "query", "args": "{\"what\": string}",
		"desc": "read-only: part_count | leg_count | name | has_weapon | diagnosis (why it explodes/falls)"},
	{"tool": "read_file", "args": "{\"path\": string}",
		"desc": "read any project source/doc file (res://...) to figure out how something works"},
	{"tool": "undo", "args": "{}", "desc": "undo the last edit"},
]

# The codebase reader may read anywhere under the project (read-only). Cole asked for the model to be
# able to check the ENTIRE codebase to figure something out, so the root is res:// (still no traversal
# outside the project, still never writes).
const ALLOWED_ROOTS := ["res://"]


static func tool_manifest() -> String:
	var lines := PackedStringArray()
	for t in TOOLS:
		lines.append("- %s %s — %s" % [t["tool"], t["args"], t["desc"]])
	return "\n".join(lines)


# The tool-use system prompt (the co-pilot's own; distinct from the gait director's). The model
# must answer with EXACTLY ONE JSON tool-call object, so OllamaClient's forced format:json parses it.
static func build_system_prompt() -> String:
	return ("You are the in-editor co-pilot for a 3D creature builder. You can do EVERYTHING the human "
		+ "can in the editor via the tools below — select/add/reshape/move/rotate/set the joint swing/"
		+ "spring/weapon/mode parts, start a new creature, and save. Reply with EXACTLY ONE JSON object "
		+ "and nothing else: {\"tool\": <name>, \"args\": {...}, \"scope\": \"current\"}.\n"
		+ "Use scope \"current\" ONLY when the request is about the creature open in the editor; "
		+ "otherwise name the target. Mutating tools are previewed before they apply.\n"
		+ "The read-context gives you the selected part's current part_type/size/density/position/"
		+ "rotation_deg/joint_axis/swing — use those to compute RELATIVE edits (e.g. 'make it taller' = "
		+ "same fields with a bigger size_y).\n"
		+ "Available tools:\n" + tool_manifest()
		+ "\nIf you're unsure how a feature works, use read_file to read the actual source (any res:// "
		+ "path) and figure it out — don't guess. If the user only asks a question about the creature, "
		+ "use query. Never invent facts you cannot see.")


static func build_user_prompt(read_context: Dictionary, message: String) -> String:
	var ctx := JSON.stringify(read_context)
	return "Editor read-context (truth; do not contradict it):\n%s\n\nUser request: %s" % [ctx, message]


# Pull the first {...} JSON tool-call object out of arbitrary model text (the injection/test path;
# OllamaClient.chat already returns a parsed dict at runtime).
static func parse_tool_call(text: String) -> Dictionary:
	var start := text.find("{")
	var end := text.rfind("}")
	if start < 0 or end <= start:
		return {}
	var parsed = JSON.parse_string(text.substr(start, end - start + 1))
	return parsed if parsed is Dictionary and parsed.has("tool") else {}


# Truthful, compact snapshot of what the co-pilot is allowed to "see".
static func read_context(bench) -> Dictionary:
	if bench == null or bench.current_root() == null:
		return {"creature": "none"}
	var g: PartGene = bench.current_root()
	var score: Dictionary = bench.current_score()
	var sel: PackedInt32Array = bench.selected_parts()
	var ctx := {
		"name": CreatureFlavor.name_for(g),
		"part_count": bench.part_count(),
		"leg_count": _count_tag(g, &"leg"),
		"has_weapon": _has_weapon(g),
		"selected_parts": Array(sel),
		"mass": float(score.get("total_mass", 0.0)),
	}
	if sel.size() > 0:
		ctx["selected_authoring"] = bench.part_authoring_summary(int(sel[sel.size() - 1]))
	return ctx


# One-line "will-do" preview shown before any mutation (the trust gate).
static func preview(bench, call: Dictionary) -> String:
	var tool := StringName(call.get("tool", &""))
	var args: Dictionary = call.get("args", {})
	match tool:
		&"select":
			return "select part %d" % int(args.get("index", 0))
		&"add_part":
			return "add a %s to the selected part" % String(args.get("part_id", "primitive_capsule"))
		&"set_shape":
			return "set the selected part to a %s of size (%.2f, %.2f, %.2f), density %.0f" % [
				String(args.get("part_type", "box")), float(args.get("size_x", 0.1)),
				float(args.get("size_y", 0.1)), float(args.get("size_z", 0.1)),
				float(args.get("density", 1000.0))]
		&"set_transform":
			return "move/rotate the selected part to pos (%.2f, %.2f, %.2f), rot (%.0f, %.0f, %.0f)°" % [
				float(args.get("pos_x", 0.0)), float(args.get("pos_y", 0.0)), float(args.get("pos_z", 0.0)),
				float(args.get("rot_x", 0.0)), float(args.get("rot_y", 0.0)), float(args.get("rot_z", 0.0))]
		&"set_swing":
			return "set the selected joint swing amp=%.2f rest=%.2f [%.2f, %.2f]" % [
				float(args.get("amplitude", 1.0)), float(args.get("rest", 0.0)),
				float(args.get("min", -1.0)), float(args.get("max", 1.0))]
		&"new_creature":
			return "start a fresh blank creature"
		&"save":
			return "save the current creature to the library"
		&"read_file":
			return "read %s" % String(args.get("path", ""))
		&"set_spring":
			return "set spring k=%.0f damp=%.2f eff=%.2f on the selected part" % [
				float(args.get("stiffness", 220.0)), float(args.get("damping", 0.2)),
				float(args.get("efficiency", 0.7))]
		&"set_weapon":
			return "set a %s weapon on the selected part" % String(args.get("kind", "blade"))
		&"set_mode":
			return "set locomotion mode to '%s'" % String(args.get("mode", ""))
		&"query":
			return "answer a question (%s)" % String(args.get("what", ""))
		&"undo":
			return "undo the last edit"
		_:
			return "unknown tool '%s'" % String(tool)


static func is_mutation(call: Dictionary) -> bool:
	var t := StringName(call.get("tool", &""))
	return t != &"query" and t != &"read_file"


# Allow-listed codebase reader: lets the co-pilot answer "how does X work" from the real source,
# refusing anything outside scripts/docs (Principle 23 — it can only see what it's shown).
static func read_codebase(rel_path: String, max_bytes := 4000) -> String:
	var path := rel_path
	if not path.begins_with("res://"):
		path = "res://" + path.lstrip("/")
	# The whole project is readable, but block ".." traversal so a path can't escape res:// to the disk.
	if path.contains(".."):
		return "I can't read '%s' — no path traversal (..) outside the project." % rel_path
	var allowed := false
	for r in ALLOWED_ROOTS:
		if path.begins_with(r):
			allowed = true
			break
	if not allowed:
		return "I can't read '%s' — only files inside the project (res://) are visible." % rel_path
	if not FileAccess.file_exists(path):
		return "No such file: %s" % rel_path
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "Could not open %s" % rel_path
	var content := f.get_as_text()
	if content.length() > max_bytes:
		content = content.substr(0, max_bytes) + "\n…(truncated)"
	return content


# M57: a plain-language diagnosis of WHY the editor creature misbehaves, read from the last Measure
# (explosion / fall / not-credible-walk), never from priors. Tells the user to Measure first if
# there is no rollout data yet (Principle 23 — it answers only from what it can see).
static func diagnose(bench) -> String:
	if bench == null or bench.current_root() == null:
		return "I can't see a creature in the editor."
	var m: Dictionary = bench.last_measured() if bench.has_method("last_measured") else {}
	if m.is_empty():
		var score: Dictionary = bench.current_score()
		var msg := ""
		if score.has("reconciliation"):
			msg = String(score["reconciliation"].get("message", ""))
		return "I haven't measured this one yet — press 'Measure walk' and ask again." \
				+ ((" (Static read: %s)" % msg) if msg != "" else "")
	if not bool(m.get("ok", true)):
		return ("The physics blew up (non-finite rollout) — usually overlapping parts or a joint "
				+ "spanning empty space. %s" % String(m.get("error", ""))).strip_edges()
	if bool(m.get("teleport", false)):
		return ("It's exploding: a part jumped impossibly far in one frame, so a joint or collider "
				+ "can't hold it. Classic cause is body segments wired to a distant root instead of "
				+ "chained neighbour-to-neighbour, or too-hot a drive whipping a long body.")
	if bool(m.get("fell", false)):
		return ("It falls over: its centre of mass tips outside the support of its feet. Widen the "
				+ "stance, lower the body, or add feet.")
	if bool(m.get("credible_walk", false)):
		return "It walks credibly — forward %.2fm, tail %.2fm. No instability detected." % [
				float(m.get("forward", 0.0)), float(m.get("forward_tail", 0.0))]
	var reasons := PackedStringArray()
	for r in m.get("locomotion_reasons", []):
		reasons.append(String(r))
	var why := ", ".join(reasons) if reasons.size() > 0 else String(m.get("locomotion_class", "?"))
	return "Not a credible walk yet: %s. forward %.2fm, fell %s. Try Optimize gait or the Drive sliders." % [
			why, float(m.get("forward", 0.0)), str(bool(m.get("fell", false)))]


# Truthful answers from the READ context (the live genome/score), never from priors. Says so when it
# can't see the thing asked about (Principle 23 made literal).
static func _answer(bench, what: StringName) -> String:
	var g: PartGene = bench.current_root()
	if g == null:
		return "I can't see a creature in the editor."
	match what:
		&"part_count":
			return "This creature has %d parts." % bench.part_count()
		&"leg_count":
			return "This creature has %d legs." % _count_tag(g, &"leg")
		&"name":
			return "I'd call it %s." % CreatureFlavor.name_for(g)
		&"has_weapon":
			return "Yes, it's armed." if _has_weapon(g) else "No weapons on this one."
		&"diagnosis", &"why", &"stability":
			return diagnose(bench)
		_:
			return "I can't see '%s' from here." % String(what)


static func _count_tag(g: PartGene, tag: StringName) -> int:
	if g == null:
		return 0
	var n := 1 if g.tags.has(tag) else 0
	for c in g.children:
		n += _count_tag(c, tag)
	return n


static func _has_weapon(g: PartGene) -> bool:
	if g == null:
		return false
	if g.weapon != null or g.tags.has(&"attack"):
		return true
	for c in g.children:
		if _has_weapon(c):
			return true
	return false
