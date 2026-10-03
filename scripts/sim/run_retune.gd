extends SceneTree

## M59 optimization campaign. Runs GaitOptimizer over every pregen, applies the tuned gait, and
## saves a tuned CreatureCard (.tres) into the library so the editor can load + Measure them. This is
## the "they actually move" deliverable: slide -> walk, the hopper hops, the urchin pogos, the
## serpent undulates. The leg re-authoring (M59 _v2_side_leg chain) fixes the morphology; this tool
## tunes the gait on top of the now-connected anatomy.
##
## Usage (headless):
##   godot --headless --path . --script res://scripts/sim/run_retune.gd                 # full campaign
##   godot --headless --path . --script res://scripts/sim/run_retune.gd -- smoke        # 1 creature, fast
##   godot --headless --path . --script res://scripts/sim/run_retune.gd -- iters=30 restarts=3 horizon=5.0
##
## It is a long-running batch (each pregen is a tournament of physics rollouts); the saved .tres set
## is what a `test_pregen_modes` gate (and Cole, in-editor) measures for mode credibility.

const OptScript := preload("res://scripts/sim/gait_optimizer.gd")

const OUT_DIR := "res://data/creatures"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var iters := int(args.get("iters", 24))
	var restarts := int(args.get("restarts", 2))
	var horizon := float(args.get("horizon", 4.0))
	var roster := _roster()
	if bool(args.get("smoke", false)):
		roster = {"tuned_quadruped": PartCatalog.make_quadruped(false)}
		iters = 6
		restarts = 1
		horizon = 2.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("=== M59 retune campaign: %d creatures, iters=%d restarts=%d horizon=%.1f ===" % [
		roster.size(), iters, restarts, horizon])
	var saved := 0
	var credible := 0
	for cname in roster:
		var root: PartGene = roster[cname]
		var r = await OptScript.optimize(root, self, iters, horizon, 1, restarts)
		OptScript.apply_to(root, r)
		var is_credible: bool = r.forward >= 3.0 or r.forward_tail >= 1.25
		if is_credible:
			credible += 1
		var card := CreatureCard.new()
		card.display_name = String(cname).capitalize()
		card.root = root
		card.notes = "M59 retuned gait (forward %+.2f, mode %s)." % [r.forward, String(r.mode)]
		var path := "%s/%s.tres" % [OUT_DIR, cname]
		var err := CreatureIO.save(card, path)
		if err == OK:
			saved += 1
		print("%-22s baseline=%+.3f -> tuned=%+.3f tail=%+.3f mode=%-8s credible=%s [%s]" % [
			cname, r.baseline_forward, r.forward, r.forward_tail, String(r.mode),
			str(is_credible), "saved" if err == OK else "save FAILED %d" % err])
	print("=== retune done: %d/%d saved, %d credible -> %s ===" % [
		saved, roster.size(), credible, OUT_DIR])
	quit(0)


func _roster() -> Dictionary:
	return {
		"tuned_quadruped": PartCatalog.make_quadruped(false),
		"tuned_spider": PartCatalog.make_spider_v2(),
		"tuned_crab": PartCatalog.make_crab_v2(),
		"tuned_scorpion": PartCatalog.make_scorpion_v2(),
		"tuned_daddy_longlegs": PartCatalog.make_daddy_longlegs_v2(),
		"tuned_frog": PartCatalog.make_frog_v2(),
		"tuned_hopper": PartCatalog.make_hopper_v2(),
		"tuned_serpent": PartCatalog.make_serpent_v2(),
		"tuned_centipede": PartCatalog.make_centipede_v2(),
		"tuned_mantis": PartCatalog.make_mantis_v2(),
		"tuned_starfish": PartCatalog.make_starfish_v2(),
		"tuned_sea_urchin": PartCatalog.make_sea_urchin_v2(),
		"tuned_tortoise": PartCatalog.make_tortoise_v2(),
		"tuned_monopod": PartCatalog.make_monopod_v2(),
		"tuned_glider": PartCatalog.make_glider_v2(),
	}


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a == "smoke":
			out["smoke"] = true
		elif a.contains("="):
			var kv := a.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out
