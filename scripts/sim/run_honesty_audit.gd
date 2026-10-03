extends SceneTree

## Honesty audit: how much of each creature's forward motion is REAL (foot/body push-off) vs the
## traction/posture CENTRAL-FORCE assist (the cheat). For every creature we run the authored gait,
## then re-run with traction=posture=0 (assist OFF). A creature that collapses to ~0 with the assist
## off is being shoved, not locomoting. Prints per-creature: assist-on forward, assist-off forward,
## the % retained without the assist, and the traction impulse (raw shove magnitude).

const CpgP := preload("res://scripts/sim/cpg_controller.gd")
const Gen := preload("res://scripts/sim/creature_generator.gd")

const HORIZON := 4.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== HONESTY AUDIT (assist-on vs assist-off) ===")
	print("%-16s %8s %8s %7s %8s %6s" % ["creature", "on", "off", "kept%", "tract_imp", "fell"])
	var roster := _roster()
	for name in roster:
		await _audit(name, roster[name])
	quit(0)


func _roster() -> Dictionary:
	return {
		"quadruped": PartCatalog.make_flagship_quadruped(),
		"biped": Gen.make_biped(7),
		"spider": PartCatalog.make_spider_v2(),
		"crab": PartCatalog.make_crab_v2(),
		"scorpion": PartCatalog.make_scorpion_v2(),
		"daddy_longlegs": PartCatalog.make_daddy_longlegs_v2(),
		"frog": PartCatalog.make_frog_v2(),
		"hopper": PartCatalog.make_hopper_v2(),
		"centipede": PartCatalog.make_centipede_v2(),
		"mantis": PartCatalog.make_mantis_v2(),
		"starfish": PartCatalog.make_starfish_v2(),
		"monopod": PartCatalog.make_monopod_v2(),
		"serpent": PartCatalog.make_serpent_v2(),
	}


func _audit(name: String, root: PartGene) -> void:
	var on: Dictionary = await _run_one(root, false)
	var off: Dictionary = await _run_one(root, true)
	var on_fwd := float(on.get("forward", 0.0))
	var off_fwd := float(off.get("forward", 0.0))
	var kept := 0.0
	if absf(on_fwd) > 0.01:
		kept = 100.0 * off_fwd / on_fwd
	print("%-16s %8.2f %8.2f %6.0f%% %8.0f %6s" % [
		name, on_fwd, off_fwd, kept, float(on.get("traction_impulse", 0.0)),
		str(bool(on.get("fell", false)))])


func _run_one(root: PartGene, kill_assist: bool) -> Dictionary:
	var g: GaitDef = root.gait
	var cp := CpgP.Params.new()
	if g != null:
		cp.amplitude_scale = g.amplitude_scale
		cp.frequency_scale = g.frequency_scale
		cp.gain_scale = g.gain_scale
		cp.traction_scale = 0.0 if kill_assist else g.traction_scale
		cp.posture_scale = 0.0 if kill_assist else g.posture_scale
		cp.turn_rate = g.turn_rate
		cp.locomotion_mode = g.locomotion_mode if g.locomotion_mode != &"" else &"walk"
	var rp := SimRollout.Params.new()
	rp.controller_params = cp
	return await SimRollout.run(root, HORIZON, 7, self, rp)
