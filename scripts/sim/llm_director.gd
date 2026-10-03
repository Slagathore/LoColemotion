class_name LlmDirector
extends RefCounted

## Turns a local Ollama model into a gait-training director. It is fed: the
## creature it is tuning, the exact knobs it controls (with ranges + meaning),
## the known gait patterns, the goal + how success is judged, and the full
## history of previous runs and their results. It returns the next settings to
## try. The prompt-building and response-parsing are pure (unit-tested); only
## the network turn lives in propose().

const GaitLibraryScript := preload("res://scripts/sim/gait_library.gd")
const OllamaClientScript := preload("res://scripts/sim/ollama_client.gd")

## The default training director. Chosen by evidence — see docs/MODEL_BAKEOFF.md:
## qwen3-coder-next led credibility in two fair head-to-head bake-offs (88%, then 92%).
const DEFAULT_MODEL := "qwen3-coder-next:cloud"

# knob -> [min, max, recipe-default]
const SCALES := {
	"amplitude": [0.8, 2.6, 2.2],
	"frequency": [0.4, 2.5, 0.7],
	"gain": [0.5, 60.0, 8.0],
	"traction": [0.0, 2.0, 1.4],
	"posture": [0.0, 3.0, 2.2],
}


static func build_system_prompt() -> String:
	return """You are a locomotion coach for SporeSpore, a 3D physics creature simulator. Your job: \
choose gait settings that make a given creature WALK FORWARD as far as possible without falling.

HOW THE CREATURE MOVES
- The creature is a tree of rigid parts joined by hinges. Legs are driven by a central pattern \
generator (CPG): each leg joint oscillates toward a target angle on a shared cycle. A leg's PHASE \
(0..1) is where it sits in that cycle; two legs a half-cycle apart (0.0 vs 0.5) move in opposition.
- On top of the leg swing, two assist forces help (they model foot friction and active balance):
  * traction: a forward push applied to a foot ONLY while it is planted in its stance phase.
  * posture: an uprighting torque + height-hold that keeps the body vertical and off the ground.

THE KNOBS YOU CONTROL (return values inside these ranges)
- pattern: one of trot | pace | bound | gallop | walk | pronk. This sets the legs' phase structure:
  * trot  = diagonal legs together (reliable all-rounder for 4 legs).
  * pace  = same-side legs together (faster, can roll/wobble).
  * bound = front pair then back pair (springy, rabbit-like).
  * gallop= rotary sequence (fastest, least stable).
  * walk  = one leg at a time, 4-beat (most stable, slowest; good for 2 legs / tall bodies).
  * pronk = all legs together (hop).
- amplitude (0.8..2.6): swing size = foot lift / stride length. Higher clears the ground better; \
too high thrashes and destabilizes.
- frequency (0.4..2.5): step speed. Higher steps faster; too high and feet slip / it can't keep up.
- gain (0.5..60): joint stiffness — how hard a leg drives toward its target. Walking usually needs \
gain ~6-12+; too low = floppy legs that fold under weight.
- traction (0.0..2.0): the forward propulsion. ~1.0-1.6 is typical. 0 = it won't go anywhere; too \
high = it skates (slides without real stepping, which is penalized).
- posture (0.0..3.0): balance strength. ~2.0-3.0 keeps it upright. Too low = it tips or collapses; \
too high = stiff and bouncy.

WHAT COUNTS AS SUCCESS (the goal)
Maximize CREDIBLE forward distance over a ~5s trial. A run is only 'credible' if it:
  (1) goes >= 3 m forward, (2) covers >= 1.25 m in the SECOND HALF (sustained, not one lurch),
  (3) stays upright (doesn't tip or sink), (4) goes reasonably straight, (5) doesn't spin.
A run that translates but isn't credible (a fall, slide, lurch-then-jam, or spin) scores badly. \
Real stepping matters: the legs must actually articulate, not skate a stiff body forward.

HOW TO APPROACH IT
- If there is a best run so far, START FROM ITS SETTINGS and change only 1-2 knobs per step.
- If nothing has walked yet, try the known good recipe first: pattern=trot, amplitude=2.2, \
frequency=0.7, gain=8, traction=1.4, posture=2.2 (this walks a basic quadruped).
- Diagnose from the last result's class: tipped/collapsed -> raise posture, lower amplitude/frequency. \
no_translation -> raise traction and gain, ensure amplitude gives clearance. skate/spin -> raise \
amplitude, lower traction a touch, try a different pattern. too_short but credible -> nudge frequency \
and amplitude up. lurch_or_jam -> lower amplitude/frequency, raise posture.
- Match the gait to the body: 2 legs -> walk; 4 legs -> trot (then try pace/bound for speed); 6+ \
legs -> trot or pronk; light/springy -> bound/gallop.
- Do NOT repeat settings that already failed. Explore deliberately toward higher credible forward.

OUTPUT
Reply with ONLY a JSON object, no prose:
{"pattern":"trot","scales":{"amplitude":2.2,"frequency":0.7,"gain":8.0,"traction":1.4,"posture":2.2},\
"rationale":"one short sentence on why"}"""


static func build_user_prompt(context: Dictionary) -> String:
	var f: Dictionary = context.get("features", {})
	var lines: Array[String] = []
	lines.append("CREATURE TO TUNE: %s" % String(context.get("creature_name", "creature")))
	lines.append("- legs (driven joints): %d, feet: %d, body segments: %d" % [
		int(f.get("leg_count", 0)), int(f.get("foot_count", 0)), int(f.get("spine_segments", 0))])
	lines.append("- knees/multi-segment legs: %s, two-legged: %s" % [
		"yes" if int(f.get("leg_segments", 1)) > 1 else "no",
		"yes" if int(f.get("biped", 0)) == 1 else "no"])
	lines.append("- mass: %.1f, height: %.2f, width: %.2f" % [
		float(f.get("mass", 0.0)), float(f.get("height", 0.0)), float(f.get("width", 0.0))])

	var best: Dictionary = context.get("best", {})
	if not best.is_empty():
		lines.append("\nBEST SO FAR: pattern=%s scales=%s -> forward=%.2fm credible=%s" % [
			String(best.get("pattern", "?")), JSON.stringify(best.get("scales", {})),
			float(best.get("forward", 0.0)), str(best.get("credible_walk", false))])

	var history: Array = context.get("history", [])
	if history.is_empty():
		lines.append("\nNo runs yet. Start from the known recipe and adapt.")
	else:
		lines.append("\nPREVIOUS RUNS (newest last):")
		var start := maxi(0, history.size() - 12)
		for i in range(start, history.size()):
			var r: Dictionary = history[i]
			lines.append("  #%d %s amp=%.2f frq=%.2f gain=%.1f trc=%.2f pos=%.2f -> fwd=%.2f %s [%s]" % [
				int(r.get("round", i)), String(r.get("pattern", "?")),
				float(r.get("amplitude", 0)), float(r.get("frequency", 0)), float(r.get("gain", 0)),
				float(r.get("traction", 0)), float(r.get("posture", 0)),
				float(r.get("forward", 0.0)),
				"CREDIBLE" if bool(r.get("credible_walk", false)) else "fail",
				String(r.get("locomotion_class", "?"))])

	lines.append("\nGOAL: %s" % String(context.get("goal", "maximize credible forward walking distance")))
	lines.append("Propose the next settings to try as JSON.")
	return "\n".join(lines)


# Validate + clamp the model's reply into safe settings.
static func parse_response(data: Dictionary) -> Dictionary:
	var pattern := StringName(String(data.get("pattern", "trot")).to_lower())
	if not GaitLibraryScript.PATTERNS.has(pattern):
		pattern = &"trot"
	var raw: Dictionary = data.get("scales", {})
	var scales := {}
	for key in SCALES:
		var spec: Array = SCALES[key]
		var v := float(raw.get(key, spec[2]))
		scales[key] = clampf(v, float(spec[0]), float(spec[1]))
	return {
		"pattern": pattern,
		"scales": scales,
		"rationale": String(data.get("rationale", "")),
	}


# Build a trainer candidate {phases, scales, pattern, rationale} from a parsed reply.
static func to_candidate(working: PartGene, parsed: Dictionary) -> Dictionary:
	return {
		"phases": GaitLibraryScript.phases_for(working, parsed["pattern"]),
		"scales": parsed["scales"],
		"pattern": parsed["pattern"],
		"rationale": parsed.get("rationale", ""),
	}


# Async: ask the model for the next candidate. Returns {} if Ollama is unreachable
# or the reply is unusable (caller falls back to its own search).
static func propose(tree: SceneTree, model: String, working: PartGene, context: Dictionary,
		host := OllamaClientScript.DEFAULT_HOST) -> Dictionary:
	var data := await OllamaClientScript.chat(tree, model, build_system_prompt(),
			build_user_prompt(context), host)
	if data.is_empty():
		return {}
	return to_candidate(working, parse_response(data))
