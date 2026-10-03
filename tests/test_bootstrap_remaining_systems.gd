extends SceneTree

const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const TissueTypesScript := preload("res://scripts/sim/tissue_types.gd")
const SkinBuilderScript := preload("res://scripts/sim/skin_builder.gd")
const TrainingDashboardScript := preload("res://scripts/sim/training_dashboard.gd")
const CreatureStageLoopScript := preload("res://scripts/sim/creature_stage_loop.gd")
const CombatResolverScript := preload("res://scripts/sim/combat.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Remaining bootstrap systems tests ===")
	_test_tissue_types()
	_test_breakable_joint_reporting()
	_test_display_skin_is_visual_only()
	_test_training_dashboard_summary()
	_test_creature_stage_loop()
	_test_loop2_combat_and_ecology()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_tissue_types() -> void:
	print("- M9B tissue properties are composable and monotonic")
	var muscle: Dictionary = TissueTypesScript.properties([&"muscle"])
	var armor: Dictionary = TissueTypesScript.properties([&"armor"])
	_check(float(muscle["strength_scale"]) > 1.0, "muscle raises strength scale")
	_check(float(armor["damage_threshold_scale"]) > float(muscle["damage_threshold_scale"]),
			"armor raises damage threshold more than muscle")
	_check(TissueTypesScript.effective_density(1000.0, [&"fat"]) < 1000.0,
			"fat lowers effective density")


func _test_breakable_joint_reporting() -> void:
	print("- M9C creature body can tear and report a driven joint")
	var body: Node3D = CreatureBodyScript.build(PartCatalog.make_quadruped(false), Transform3D.IDENTITY)
	root.add_child(body)
	var drives: Array = body.call("drive_joints")
	var part_idx := int((drives[0] as Dictionary)["part_index"])
	_check(body.call("tear_joint", part_idx, "test_overstress"), "tear_joint accepts a driven part")
	_check(int(body.call("torn_joints")) == 1 and int(body.call("measure")["torn_joints"]) == 1,
			"torn joint count is reported")
	_check((body.call("drive_joints") as Array).size() == drives.size() - 1,
			"torn joint is removed from active drive metadata")
	body.queue_free()


func _test_display_skin_is_visual_only() -> void:
	print("- M10 display skin mirrors body parts without physics")
	var body: Node3D = CreatureBodyScript.build(PartCatalog.make_quadruped(false), Transform3D.IDENTITY)
	root.add_child(body)
	var skin: Node3D = SkinBuilderScript.build_display_skin(body)
	root.add_child(skin)
	_check(bool(skin.get_meta("display_only", false)), "skin is marked display-only")
	_check(skin.get_child_count() == (body.call("part_bodies") as Array).size(),
			"skin has one visual mesh per part body")
	var no_physics := true
	for child in skin.get_children():
		no_physics = no_physics and not (child is RigidBody3D) and not (child is CollisionShape3D)
	_check(no_physics, "skin adds no physics bodies or collision shapes")
	body.queue_free()
	skin.queue_free()


func _test_training_dashboard_summary() -> void:
	print("- M11 dashboard read model summarizes runs, failures, corpus, and assist")
	TrainingLog.base_dir = "user://dashboard_test"
	TrainingLog.reset()
	TrainingLog.record_run({"creature_id": "a", "creature_name": "alpha", "credible_walk": true,
			"fell": false, "forward": 3.5, "fitness": 4.0, "assist_ratio": 0.2, "settings": {}}, 1.0)
	TrainingLog.record_run({"creature_id": "b", "creature_name": "beta", "credible_walk": false,
			"fell": true, "forward": 0.5, "fitness": -1.0, "assist_ratio": 0.8,
			"locomotion_class": "fall_or_tip", "settings": {}}, 2.0)
	var corpus := [{"source_category": &"hand_authored"}, {"source_category": &"generated"}]
	var summary: Dictionary = TrainingDashboardScript.summary(corpus)
	_check(int(summary["run_count"]) == 2 and int(summary["failure_count"]) == 1,
			"dashboard counts runs and failures")
	_check(String(summary["best_name"]) == "alpha" and float(summary["best_forward"]) == 3.5,
			"dashboard reports top forward performer")
	_check(int((summary["assist_ratio"] as Dictionary)["count"]) == 2,
			"dashboard includes assist ratio distribution")
	_check(int((summary["corpus_counts"] as Dictionary).get(&"generated", 0)) == 1,
			"dashboard includes corpus category counts")


func _test_creature_stage_loop() -> void:
	print("- M12 headless creature-stage loop runs survival and reproduction")
	var cfg = CreatureStageLoopScript.Config.new()
	cfg.seed = 22
	cfg.population_size = 4
	cfg.food_count = 8
	cfg.generations = 2
	var result: Dictionary = CreatureStageLoopScript.run(PartCatalog.make_quadruped(false), cfg)
	_check(bool(result["ok"]), "stage loop completes")
	_check((result["population"] as Array).size() == 4, "population size is maintained")
	_check((result["history"] as Array).size() == 2, "generation history is recorded")


func _test_loop2_combat_and_ecology() -> void:
	print("- M12 Loop-2 hazards and agents use graph-derived durability")
	var base := PartCatalog.make_quadruped(false)
	var tough := GenomeSnapshot.deep_copy(base)
	var muscle := PartCatalog.clone_template(&"muscle_bundle")
	muscle.socket_id = &"core_muscle"
	var sock := SocketDef.new()
	sock.id = &"core_muscle"
	sock.parent_attachment = Transform3D.IDENTITY
	muscle.socket = sock
	tough.children.append(muscle)
	var d_base: Dictionary = CombatResolverScript.durability(base)
	var d_tough: Dictionary = CombatResolverScript.durability(tough)
	_check(float(d_tough["hp"]) > float(d_base["hp"]), "added muscle raises body durability")
	var hit: Dictionary = CombatResolverScript.hazard_hit(base, 0.2)
	_check(hit.has("damage") and hit.has("defender_alive"), "hazard hit reports damage and survival")
	var contact: Dictionary = CombatResolverScript.resolve_contact(tough, base, {
		"relative_speed": 2.0,
		"normal_impulse": 5.0,
	})
	_check(bool(contact["contact_driven"]) and float(contact["damage"]) > 0.0,
			"contact resolver turns relative speed/impulse into part damage")
	_check(contact.has("attacker_part_index") and contact.has("defender_part_index"),
			"contact damage reports attacker and defender parts")
	var cfg = CreatureStageLoopScript.Config.new()
	cfg.seed = 33
	cfg.population_size = 4
	cfg.food_count = 8
	cfg.generations = 2
	cfg.hazard_count = 1
	cfg.agent_count = 1
	var result: Dictionary = CreatureStageLoopScript.run_loop2(base, cfg)
	_check(bool(result["ok"]) and int(result["loop"]) == 2, "Loop-2 stage completes")
	var hist: Array = result["history"]
	_check(hist.size() == 2 and hist[0].has("combat_events") and hist[0].has("hazard_hits"),
			"Loop-2 history records hazards and combat events")
	_check(hist[0].has("contact_events") and hist[0].has("contact_damage"),
			"Loop-2 history records contact-driven combat")
