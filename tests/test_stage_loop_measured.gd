extends SceneTree

## M12 Loop-1: survival is decided by MEASURED locomotion (SimRollout), not by the
## analytic probe. A real walker must out-eat and out-survive a creature that can't move.

const CSL := preload("res://scripts/sim/creature_stage_loop.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Stage loop (measured) tests ===")
	await _test_measured_selection()
	await _test_run_measured_smoke()
	await _test_run_measured_loop2_smoke()
	await _test_measured_loop2_campaign_control()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _inert_blob() -> PartGene:
	var d := PartDefinition.new()
	d.part_type = &"box"
	d.density = 1000.0
	d.extents = Vector3(0.4, 0.3, 0.6)
	var g := PartGene.new()
	g.definition = d
	var tags: Array[StringName] = [&"spine", &"ground_contact"]
	g.tags = tags
	return g


func _test_measured_selection() -> void:
	print("- a real walker out-ranks an inert blob on MEASURED energy")
	var pop: Array[PartGene] = [PartCatalog.make_quadruped(false), _inert_blob()]
	var cfg := CSL.Config.new()
	cfg.horizon = 4.0
	cfg.food_count = 12
	cfg.prescreen_keep = 2   # measure both so the ranking is purely physical
	var ranked: Array = await CSL.measure_population(pop, cfg, self, 0)
	_check(ranked.size() == 2, "both finalists were physically measured")
	_check(bool(ranked[0]["credible"]) and float(ranked[0]["forward"]) > 3.0,
			"the walker is the measured winner (%.2fm)" % float(ranked[0]["forward"]))
	_check(int(ranked[0]["food"]) > int(ranked[1]["food"]),
			"the walker gathers more food than the blob (%d vs %d)" % [
				int(ranked[0]["food"]), int(ranked[1]["food"])])
	_check(float(ranked[0]["energy"]) > float(ranked[1]["energy"]),
			"the walker ends with more energy than the blob")


func _test_run_measured_smoke() -> void:
	print("- run_measured closes the generation loop on measured fitness")
	var cfg := CSL.Config.new()
	cfg.population_size = 4
	cfg.generations = 2
	cfg.horizon = 3.0
	cfg.seed = 7
	var res: Dictionary = await CSL.run_measured(PartCatalog.make_quadruped(false), cfg, self)
	_check(bool(res.get("ok", false)), "measured loop completes")
	var hist: Array = res.get("history", [])
	_check(hist.size() == 2, "history records every generation")
	_check(hist.size() > 0 and float(hist[0].get("best_forward", -1.0)) > 0.0,
			"best survivor has a real measured forward distance")
	_check((res.get("population", []) as Array).size() == cfg.population_size,
			"the next generation is repopulated")


func _test_run_measured_loop2_smoke() -> void:
	print("- run_measured_loop2 uses measured contacts for hazards and agents")
	var cfg := CSL.Config.new()
	cfg.population_size = 3
	cfg.generations = 1
	cfg.horizon = 0.5
	cfg.prescreen_keep = 2
	cfg.seed = 17
	cfg.hazard_count = 1
	cfg.agent_count = 1
	var res: Dictionary = await CSL.run_measured_loop2(PartCatalog.make_quadruped(false), cfg, self)
	_check(bool(res.get("ok", false)) and int(res.get("loop", 0)) == 2 and bool(res.get("measured", false)),
			"measured Loop-2 completes")
	_check(not bool(res.get("synthetic_contact", true)), "measured Loop-2 is not synthetic contact")
	var hist: Array = res.get("history", [])
	_check(hist.size() == 1 and hist[0].has("best_forward") and hist[0].has("contact_events"),
			"measured Loop-2 history carries locomotion and contact metrics")
	_check(hist.size() == 1 and hist[0].has("median_energy") and hist[0].has("credible_rate"),
			"measured Loop-2 history carries median and credible-rate stats")
	_check(hist.size() == 1 and int(hist[0].get("contact_events", 0)) > 0,
			"measured Loop-2 records real contact events")
	_check((res.get("population", []) as Array).size() == cfg.population_size,
			"measured Loop-2 repopulates survivors")


func _test_measured_loop2_campaign_control() -> void:
	print("- M26 campaign includes a degraded random-selection control arm")
	var cfg := CSL.Config.new()
	cfg.population_size = 3
	cfg.generations = 2
	cfg.horizon = 0.45
	cfg.prescreen_keep = 2
	cfg.seed = 23
	cfg.hazard_count = 0
	cfg.agent_count = 0
	var res: Dictionary = await CSL.run_measured_loop2_campaign(
			PartCatalog.make_quadruped(false), cfg, self, [23])
	_check(bool(res.get("ok", false)), "campaign wrapper completes normal and control arms")
	_check(String(res.get("control_arm", "")) == "random_selection",
			"campaign labels the degraded control arm")
	var normal: Dictionary = res.get("normal", {})
	var control: Dictionary = res.get("control", {})
	_check(normal.has("median_energy_delta") and control.has("median_energy_delta"),
			"campaign summarizes median-energy deltas")
	var normal_runs: Array = res.get("normal_runs", [])
	var control_runs: Array = res.get("control_runs", [])
	_check(not normal_runs.is_empty()
			and String(((normal_runs[0] as Dictionary)["history"] as Array)[0].get("selection_mode", "")) == "fitness",
			"normal arm uses fitness selection")
	_check(not control_runs.is_empty()
			and String(((control_runs[0] as Dictionary)["history"] as Array)[0].get("selection_mode", "")) == "random",
			"control arm uses random selection")
