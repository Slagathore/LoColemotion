extends SceneTree

const GenScript := preload("res://scripts/sim/creature_generator.gd")

var _passed := 0
var _failed := 0
var _stub_calls := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Training pipeline tests ===")
	TrainingLog.base_dir = "user://training_test"   # isolate from any live training store
	TrainingLog.reset()
	WarmStartLibrary.reset()
	_test_training_log()
	_test_gait_library()
	_test_features()
	_test_warm_start()
	_test_ollama_helpers()
	_test_director_helpers()
	_test_tracks()
	await _test_steering()
	await _test_breakable_joints()
	await _test_trainer_do_no_harm_baseline_only()
	await _test_trainer()
	await _test_trainer_llm_routing()
	await _test_trainer_on_track()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_training_log() -> void:
	print("- TrainingLog records runs and maintains counters")
	TrainingLog.reset()
	TrainingLog.record_run({"creature_id": "c1", "credible_walk": true, "fell": false,
			"forward": 3.0, "fitness": 5.0, "settings": {"gain": 8.0}}, 100.0)
	TrainingLog.record_run({"creature_id": "c1", "credible_walk": false, "fell": true,
			"forward": 1.0, "fitness": -2.0, "settings": {"gain": 2.0},
			"locomotion_class": "fall_or_tip", "locomotion_reasons": ["root tipped over"],
			"assist_per_meter": 0.0, "assist_ratio": 0.0}, 101.0)
	var agg := TrainingLog.aggregate()
	_check(int(agg["total_runs"]) == 2, "aggregate counts total runs")
	_check(int(agg["total_credible"]) == 1, "aggregate counts credible walks")
	_check(int(agg["total_falls"]) == 1, "aggregate counts falls")
	var s := TrainingLog.creature_summary("c1")
	_check(int(s["runs"]) == 2 and int(s["credible"]) == 1, "per-creature counters")
	_check(absf(float(s["best_fitness"]) - 5.0) < 1e-6, "tracks best fitness")
	_check(absf(float((s["best_settings"] as Dictionary).get("gain", 0.0)) - 8.0) < 1e-6,
			"keeps the settings that scored best")
	_check(TrainingLog.load_runs().size() == 2, "JSONL holds one line per run")
	var failures := TrainingLog.load_failures()
	_check(failures.size() == 1 and String(failures[0]["class"]) == "fall_or_tip",
			"non-credible runs are also written to failures.jsonl")


func _test_gait_library() -> void:
	print("- GaitLibrary produces distinct position-based gait templates")
	var quad := PartCatalog.make_quadruped(false)
	var trot := GaitLibrary.phases_for(quad, &"trot")
	var pace := GaitLibrary.phases_for(quad, &"pace")
	_check(trot.size() >= 4, "a phase per driven leg")
	var differ := false
	for k in trot:
		if absf(float(trot[k]) - float(pace.get(k, -9.0))) > 1e-6:
			differ = true
	_check(differ, "trot and pace assign different phases")


func _test_features() -> void:
	print("- CreatureFeatures extracts a body descriptor with semantic distance")
	var quad := PartCatalog.make_quadruped(false)
	var f := CreatureFeatures.extract(quad)
	_check(int(f["foot_count"]) == 4, "quad has four feet")
	_check(int(f["leg_count"]) >= 4, "quad has >= four driven legs")
	_check(CreatureFeatures.distance(f, f) < 1e-6, "identical bodies have zero distance")
	var biped := GenScript.make_biped(7)
	var bf := CreatureFeatures.extract(biped)
	_check(CreatureFeatures.distance(f, bf) > 1.0, "quad and biped are semantically far apart")


func _test_warm_start() -> void:
	print("- WarmStartLibrary stores best gait and finds the nearest body")
	WarmStartLibrary.reset()
	var f := {"leg_count": 4, "foot_count": 4, "leg_segments": 2, "biped": 0,
			"mass": 100.0, "height": 1.0, "width": 1.0, "spine_segments": 1}
	WarmStartLibrary.remember("c1", f, {"amplitude": 2.2, "gain": 8.0}, &"trot", 5.0)
	var near := {"leg_count": 4, "foot_count": 4, "leg_segments": 2, "biped": 0,
			"mass": 110.0, "height": 1.0, "width": 1.0, "spine_segments": 1}
	var seed := WarmStartLibrary.best_seed_for(near)
	_check(not seed.is_empty(), "finds a nearest-neighbour seed")
	_check(String(seed["pattern"]) == "trot", "returns the proven pattern")
	_check(absf(float((seed["scales"] as Dictionary).get("gain", 0.0)) - 8.0) < 1e-6,
			"returns the proven drive scales")
	WarmStartLibrary.remember("c1", f, {"gain": 99.0}, &"pace", 1.0)   # worse, must not overwrite
	_check(String(WarmStartLibrary.best_seed_for(near)["pattern"]) == "trot",
			"a worse result does not overwrite the best")


func _test_ollama_helpers() -> void:
	print("- OllamaClient pure helpers parse models and chat payloads")
	var models := OllamaClient.parse_models({"models": [
		{"name": "llama3:latest"}, {"name": "qwen2.5:7b"}, {"no_name": 1}]})
	_check(models.size() == 2 and models.has("llama3:latest"), "parse_models extracts model names")
	var body := OllamaClient.build_chat_body("m", "sys", "usr")
	_check(String(body["model"]) == "m" and String(body["format"]) == "json"
			and (body["messages"] as Array).size() == 2, "chat body has model, json format, 2 messages")
	var content := OllamaClient.extract_content({"message": {"content": "{\"pattern\":\"trot\"}"}})
	_check(String(content.get("pattern", "")) == "trot", "extract_content parses the JSON reply")
	var fenced := OllamaClient.extract_content({"message": {"content":
			"```json\n{\"pattern\":\"pace\",\"scales\":{\"gain\":8}}\n```"}})
	_check(String(fenced.get("pattern", "")) == "pace", "extract_content parses fenced JSON replies")
	_check(OllamaClient.extract_content({}).is_empty(), "extract_content is empty on a bad reply")


func _test_director_helpers() -> void:
	print("- LlmDirector builds a rich prompt and clamps the reply")
	var sys := LlmDirector.build_system_prompt()
	_check(sys.length() > 800 and sys.contains("traction") and sys.contains("credible"),
			"system prompt explains the knobs and the success gate")
	var ctx := {"creature_name": "quad", "features": {"leg_count": 4, "foot_count": 4,
			"leg_segments": 2, "biped": 0, "mass": 900.0, "height": 1.0, "width": 1.0,
			"spine_segments": 1}, "history": [], "best": {}, "goal": "walk far"}
	var user := LlmDirector.build_user_prompt(ctx)
	_check(user.contains("quad") and user.contains("legs"), "user prompt describes the creature")
	var parsed := LlmDirector.parse_response({"pattern": "gallop", "scales": {"amplitude": 99.0,
			"frequency": 0.7, "gain": 8.0, "traction": 1.4, "posture": 2.2}, "rationale": "x"})
	_check(String(parsed["pattern"]) == "gallop", "valid pattern is kept")
	_check(float((parsed["scales"] as Dictionary)["amplitude"]) <= 2.6, "out-of-range scale is clamped")
	var bad := LlmDirector.parse_response({"pattern": "sprint"})
	_check(String(bad["pattern"]) == "trot", "an invalid pattern falls back to trot")


func _stub_propose(working: PartGene, _context: Dictionary) -> Dictionary:
	_stub_calls += 1
	return {"phases": GaitLibrary.phases_for(working, &"trot"),
		"scales": {"amplitude": 2.0, "frequency": 0.7, "gain": 8.0, "traction": 1.4, "posture": 2.2},
		"pattern": &"trot", "rationale": "stub"}


func _test_trainer_llm_routing() -> void:
	print("- Trainer routes phase-2 proposals through an injected director")
	TrainingLog.base_dir = "user://training_test"
	TrainingLog.reset()
	WarmStartLibrary.reset()
	_stub_calls = 0
	var quad := PartCatalog.make_quadruped(false)
	var cfg := Trainer.Config.new()
	cfg.rounds = 4
	cfg.horizon = 1.2
	cfg.seed = 3
	cfg.creature_name = "llm_test"
	var best := await Trainer.train(quad, self, cfg, 0.0, Callable(), Callable(self, "_stub_propose"))
	_check(not best.is_empty(), "trainer with an injected proposer returns a best")
	_check(int(TrainingLog.aggregate()["total_runs"]) == 5, "logged baseline plus every round")
	_check(_stub_calls == 2, "the injected director drove the 2 non-seed rounds")


func _test_tracks() -> void:
	print("- Track factories + scoring for straight/obstacle/target/curved/hop/lateral")
	_check(String(Track.straight().kind) == "straight"
			and String(Track.obstacle().kind) == "obstacle"
			and String(Track.target(6.0).kind) == "target"
			and String(Track.curved(8.0, 1.0).kind) == "curved"
			and String(Track.push_object().kind) == "push"
			and String(Track.hop().kind) == "hop"
			and String(Track.lateral().kind) == "lateral", "factories build the right kinds")
	_check(Track.obstacle(3).obstacles.size() == 3, "obstacle track places its rows")

	# straight: credible walk scores by sustained forward
	var straight := Track.straight().score({"forward": 5.0, "forward_tail": 2.0, "lateral": 0.0,
			"credible_walk": true, "locomotion_class": "credible_walk", "locomotion_reasons": []})
	_check(bool(straight["credible"]) and float(straight["fitness"]) > 10.0, "straight rewards forward+tail")

	# target: reaching the point is credible; missing is not
	var tgt := Track.target(6.0, 1.0)
	var hit := tgt.score({"forward": 6.0, "lateral": 0.0, "fell": false})
	var miss := tgt.score({"forward": 2.0, "lateral": 0.0, "fell": false})
	_check(bool(hit["credible"]) and String(hit["class"]) == "reached", "target reached = credible")
	_check(not bool(miss["credible"]) and float(hit["fitness"]) > float(miss["fitness"]),
			"missing the target scores worse")

	# curved: on-arc trajectory beats a straight one (cross-track gradient)
	var cv := Track.curved(8.0, 1.0)
	var center := Vector3(-8.0, 0.0, 0.0)   # left of heading -Z for a left turn
	var arc: Array = []
	var line: Array = []
	for k in 10:
		var a := PI * 0.5 + 0.06 * k   # sweep forward (-Z) along the arc, curving
		arc.append(Vector3(center.x + 8.0 * sin(a), 0.0, center.z + 8.0 * cos(a)))
		line.append(Vector3(0.0, 0.0, -0.5 * k))
	var on := cv.score({"trajectory": arc, "heading": Vector3.FORWARD, "fell": false, "yaw_delta": 0.6})
	var off := cv.score({"trajectory": line, "heading": Vector3.FORWARD, "fell": false, "yaw_delta": 0.0})
	_check(float(on["fitness"]) > float(off["fitness"]), "following the arc beats going straight")

	var push := Track.push_object(1.2, 0.5)
	var pushed := push.score({"object_forward": 0.75, "fell": false, "ok": true, "root_up_min": 1.0})
	var flop := push.score({"object_forward": 0.75, "fell": true, "ok": true, "root_up_min": 1.0})
	_check(bool(pushed["credible"]) and not bool(flop["credible"]),
			"push scoring requires object movement without falling")

	var hop := Track.hop(2.5, 0.25)
	var hopped := hop.score({"forward": 2.7, "bounce": 0.32, "fell": false,
			"theta_span": 0.4, "max_omega": 0.7})
	var hop_fail := hop.score({"forward": 2.7, "bounce": 0.05, "fell": false,
			"theta_span": 0.4, "max_omega": 0.7})
	_check(bool(hopped["credible"]) and String(hopped["class"]) == "hopped"
			and not bool(hop_fail["credible"]), "hop scoring requires distance plus vertical spring")

	var side := Track.lateral(2.0)
	var lateral := side.score({"forward": 0.4, "lateral": 2.4, "lateral_ratio": 0.86,
			"fell": false, "theta_span": 0.4, "max_omega": 0.7})
	var drift := side.score({"forward": 2.4, "lateral": 2.1, "lateral_ratio": 0.46,
			"fell": false, "theta_span": 0.4, "max_omega": 0.7})
	_check(bool(lateral["credible"]) and String(lateral["class"]) == "lateral_scuttle"
			and not bool(drift["credible"]), "lateral scoring is side-dominant and separate from walking")


func _test_trainer_on_track() -> void:
	print("- Trainer runs on a non-straight track (obstacle world builds + scores)")
	TrainingLog.base_dir = "user://training_test"
	TrainingLog.reset()
	WarmStartLibrary.reset()
	var quad := PartCatalog.make_quadruped(false)
	var cfg := Trainer.Config.new()
	cfg.rounds = 3
	cfg.horizon = 1.2
	cfg.seed = 5
	cfg.creature_name = "obstacle_quad"
	cfg.track = Track.obstacle(3)
	var best := await Trainer.train(quad, self, cfg, 0.0)
	_check(not best.is_empty(), "trainer returns a best on the obstacle track")
	_check(int(TrainingLog.aggregate()["total_runs"]) == 4, "logged baseline plus every obstacle run")
	var runs := TrainingLog.load_runs()
	_check(not runs.is_empty() and String(runs[-1].get("track", "")) == "obstacle",
			"runs are tagged with the obstacle track")


func _test_trainer_do_no_harm_baseline_only() -> void:
	print("- Trainer do-no-harm keeps the starting gait when no candidate beats baseline")
	TrainingLog.base_dir = "user://training_test"
	TrainingLog.reset()
	WarmStartLibrary.reset()
	var quad := PartCatalog.make_quadruped(false)
	var before := quad.gait.duplicate(true) as GaitDef
	var cfg := Trainer.Config.new()
	cfg.rounds = 0
	cfg.horizon = 0.6
	cfg.seed = 7
	cfg.creature_name = "baseline_only"
	var best := await Trainer.train(quad, self, cfg, 0.0)
	_check(bool(best.get("no_improvement", false)), "baseline-only training reports no improvement")
	_check(int(TrainingLog.aggregate()["total_runs"]) == 1, "baseline row is logged")
	_check(WarmStartLibrary.entries().is_empty(), "baseline-only run is not remembered as a trained champion")
	_check(absf(quad.gait.amplitude_scale - before.amplitude_scale) < 1e-6
			and absf(quad.gait.frequency_scale - before.frequency_scale) < 1e-6
			and quad.gait.assignments.size() == before.assignments.size(),
			"starting gait is unchanged")


func _run_with_turn(root_gene: PartGene, turn: float) -> Dictionary:
	var g: GaitDef = root_gene.gait
	var p := CpgController.Params.new()
	if g != null:
		p.amplitude_scale = g.amplitude_scale
		p.frequency_scale = g.frequency_scale
		p.gain_scale = g.gain_scale
		p.traction_scale = g.traction_scale
		p.posture_scale = g.posture_scale
	p.turn_rate = turn
	var rp := SimRollout.Params.new()
	rp.controller_params = p
	return await SimRollout.run(root_gene, 3.0, 7, self, rp)


func _test_steering() -> void:
	print("- steering: turn_rate makes the creature yaw")
	var quad := PartCatalog.make_quadruped(false)
	var straight := await _run_with_turn(quad, 0.0)
	var turning := await _run_with_turn(quad, 1.5)
	var turning_yaw := float(turning.get("yaw_rate", 0.0))
	var straight_yaw := float(straight.get("yaw_rate", 0.0))
	_check(turning_yaw >= 0.30 and turning_yaw > straight_yaw * 3.0,
			"turn_rate produces robust yaw (%.2f vs %.2f rad/s)" % [
				turning_yaw, straight_yaw])


func _run_with_tear(root_gene: PartGene, tear_omega: float) -> Dictionary:
	var g: GaitDef = root_gene.gait
	var p := CpgController.Params.new()
	if g != null:
		p.amplitude_scale = g.amplitude_scale
		p.frequency_scale = g.frequency_scale
		p.gain_scale = g.gain_scale
		p.traction_scale = g.traction_scale
		p.posture_scale = g.posture_scale
	p.tear_omega = tear_omega
	var rp := SimRollout.Params.new()
	rp.controller_params = p
	return await SimRollout.run(root_gene, 3.0, 11, self, rp)


func _test_breakable_joints() -> void:
	print("- M9C: overstressed joints tear and are reported; default never tears")
	var intact := await _run_with_tear(PartCatalog.make_quadruped(false), 0.0)
	# A pathologically low tear threshold guarantees normal walking motion exceeds it.
	var shredded := await _run_with_tear(PartCatalog.make_quadruped(false), 0.5)
	_check(int(intact.get("torn_joints", -1)) == 0, "default (tear_omega 0) tears nothing")
	_check(int(shredded.get("torn_joints", 0)) > 0,
			"low tear_omega tears joints (%d torn)" % int(shredded.get("torn_joints", 0)))


func _test_trainer() -> void:
	print("- Trainer runs a closed loop: logs every run, updates counters + library")
	TrainingLog.reset()
	WarmStartLibrary.reset()
	var quad := PartCatalog.make_quadruped(false)
	var cfg := Trainer.Config.new()
	cfg.rounds = 4
	cfg.horizon = 1.2
	cfg.seed = 3
	cfg.creature_name = "test_quad"
	var best := await Trainer.train(quad, self, cfg, 200.0)
	_check(not best.is_empty(), "trainer returns a best candidate")
	_check(int(TrainingLog.aggregate()["total_runs"]) == 5, "logged baseline plus every training run")
	var runs := TrainingLog.load_runs()
	_check(runs.size() == 5 and (runs[0] as Dictionary).has("baseline_root")
			and (runs[0] as Dictionary).has("candidate_root"),
			"every training row carries reconstructable root snapshots")
	var restored := GenomeSnapshot.from_dictionary((runs[0] as Dictionary).get("candidate_root", {}))
	_check(restored != null and restored.gait != null,
			"logged candidate root rehydrates with its gait")
	var summary := TrainingLog.creature_summary(String((runs[0] as Dictionary).get("creature_id", "")))
	_check(not (summary.get("best_root", {}) as Dictionary).is_empty(),
			"per-creature summary stores the best root snapshot")
	if bool(best.get("no_improvement", false)):
		_check(WarmStartLibrary.entries().is_empty(), "do-no-harm skips warm-start memory when nothing improved")
	else:
		_check(WarmStartLibrary.entries().size() == 1, "remembered the trained creature")
		_check(not ((WarmStartLibrary.entries()[0] as Dictionary).get("root", {}) as Dictionary).is_empty(),
				"warm-start entry preserves the trained champion root")
	_check(quad.gait != null and not quad.gait.assignments.is_empty(),
			"creature keeps a usable gait after training")
