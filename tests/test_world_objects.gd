extends SceneTree

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const WorldObjectScript := preload("res://scripts/sim/world_object.gd")
const ToolUseTrainerScript := preload("res://scripts/sim/tool_use_trainer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== World object / manipulation tests ===")
	await _test_push_track_rollout()
	await _test_grasp_weld_release()
	await _test_grasp_carry_track_rollout()
	await _test_tool_use_track_rollout()
	await _test_tool_use_trainer()
	_test_grasp_score_gauntlet()
	_test_tool_sequence_score()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_push_track_rollout() -> void:
	print("- push track measures object displacement and credibility")
	var root_gene := PartCatalog.make_quadruped(false)
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params_from_gait(root_gene.gait)
	rp.track = Track.push_object(1.2, 0.15)
	var m: Dictionary = await SimRolloutScript.run(root_gene, 5.0, 3001, self, rp)
	var sc: Dictionary = rp.track.score(m)
	print("  push measured: object=%.3f forward=%.3f credible=%s class=%s reasons=%s" % [
		float(m.get("object_forward", 0.0)), float(m.get("forward", 0.0)),
		str(sc["credible"]), String(sc["class"]), str(sc["reasons"])])
	_check(m.has("objects") and (m["objects"] as Array).size() == 1, "rollout reports world object metrics")
	_check(float(m.get("object_forward", 0.0)) > 0.0, "creature physically moved the object")
	_check(bool(sc["credible"]) and String(sc["class"]) == "pushed_object",
			"push track scores a credible push")
	var cheat: Dictionary = rp.track.score({"object_forward": 2.0, "fell": true, "ok": true, "root_up_min": 1.0})
	_check(not bool(cheat["credible"]), "falling onto the object is rejected")


func _test_grasp_weld_release() -> void:
	print("- grasp helper creates and releases a temporary weld")
	var world := Node3D.new()
	root.add_child(world)
	var carrier: RigidBody3D = WorldObjectScript.make_rigid(&"hand", Vector3.ZERO, Vector3(0.2, 0.2, 0.2), 1.0, false)
	var obj: RigidBody3D = WorldObjectScript.make_tool(Vector3(0.1, 0.0, 0.0))
	world.add_child(carrier)
	world.add_child(obj)
	var joint: Generic6DOFJoint3D = WorldObjectScript.make_grasp_joint(world, carrier, obj)
	await physics_frame
	_check(joint != null and joint is Generic6DOFJoint3D, "grasp creates a 6DOF weld")
	_check(bool(obj.get_meta("grasped", false)), "object records grasped state")
	WorldObjectScript.release_grasp(joint, obj)
	await process_frame
	_check(not bool(obj.get_meta("grasped", true)), "release clears grasped state")
	world.queue_free()


func _test_grasp_carry_track_rollout() -> void:
	print("- grasp track: a creature welds, carries, and follows the object credibly")
	var root_gene := PartCatalog.make_quadruped(false)
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params_from_gait(root_gene.gait)
	rp.track = Track.grasp_carry(1.0)
	var m: Dictionary = await SimRolloutScript.run(root_gene, 5.0, 33, self, rp)
	var sc: Dictionary = rp.track.score(m)
	print("  grasp measured: grasped=%s carry=%.2f follows=%s credible=%s class=%s" % [
		str(m.get("grasp_grasped")), float(m.get("grasp_carry", 0.0)),
		str(m.get("grasp_follows")), str(sc["credible"]), String(sc["class"])])
	_check(bool(m.get("grasp_grasped", false)), "carrier welds to the graspable object on contact")
	_check(bool(m.get("grasp_follows", false)), "the object follows the hand (rigid weld holds)")
	_check(float(m.get("grasp_carry", 0.0)) >= 1.0, "the object is carried past the target distance")
	_check(bool(sc["credible"]) and String(sc["class"]) == "carried",
			"grasp track scores a credible carry")


func _test_tool_use_track_rollout() -> void:
	print("- tool-use track requires grasp, carry, and target application")
	var root_gene := PartCatalog.make_quadruped(false)
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params_from_gait(root_gene.gait)
	rp.track = Track.tool_use(1.5, 0.9)
	var m: Dictionary = await SimRolloutScript.run(root_gene, 5.0, 44, self, rp)
	var sc: Dictionary = rp.track.score(m)
	print("  tool measured: grasped=%s carried=%s applied=%s dist=%.2f credible=%s" % [
		str(m.get("grasp_grasped")), str(m.get("tool_carried")), str(m.get("tool_applied")),
		float(m.get("tool_distance_to_target", 99.0)), str(sc["credible"])])
	_check(bool(m.get("grasp_grasped", false)), "tool is grasped")
	_check(bool(m.get("tool_carried", false)), "tool is carried in order")
	_check(bool(m.get("tool_applied", false)), "tool reaches the target")
	_check(bool(sc["credible"]) and String(sc["class"]) == "tool_applied",
			"tool track scores ordered application")


func _test_tool_use_trainer() -> void:
	print("- M8C trainer finds at least one ordered tool-use rollout")
	var cfg := ToolUseTrainerScript.Config.new()
	cfg.horizon_s = 5.0
	cfg.target_distance = 1.5
	cfg.apply_radius = 0.9
	cfg.gain_scales = [1.0]
	cfg.traction_scales = [1.4]
	cfg.posture_scales = [2.2]
	var result: Dictionary = await ToolUseTrainerScript.train_once(PartCatalog.make_quadruped(false), self, cfg)
	_check(bool(result.get("ok", false)) and bool(result.get("credible", false)),
			"trainer completes the ordered tool sequence")
	_check((result.get("history", []) as Array).size() >= 1,
			"trainer returns ordered sub-goal history")


func _test_grasp_score_gauntlet() -> void:
	print("- grasp scoring rejects phantom / non-following / short / fallen carries")
	var t := Track.grasp_carry(1.0)
	var base := {"grasp_grasped": true, "grasp_follows": true, "grasp_carry": 3.0,
		"fell": false, "ok": true}
	_check(bool(t.score(base)["credible"]), "a real carry passes")
	var no_grasp := base.duplicate(); no_grasp["grasp_grasped"] = false
	_check(not bool(t.score(no_grasp)["credible"]), "never-grasped is rejected")
	var no_follow := base.duplicate(); no_follow["grasp_follows"] = false
	_check(not bool(t.score(no_follow)["credible"])
			and (t.score(no_follow)["reasons"] as Array).has(
				"object did not move with the hand (phantom/clipping grasp)"),
			"phantom/clipping grasp (object doesn't follow) is rejected")
	var short := base.duplicate(); short["grasp_carry"] = 0.2
	_check(not bool(t.score(short)["credible"]), "carrying less than the target is rejected")
	var fell := base.duplicate(); fell["fell"] = true
	_check(not bool(t.score(fell)["credible"]), "falling while carrying is rejected")


func _test_tool_sequence_score() -> void:
	print("- tool sequence scoring requires ordered sub-goals")
	var ok: Dictionary = WorldObjectScript.tool_sequence_score(true, true, true, false, false)
	_check(bool(ok["credible"]) and String(ok["class"]) == "tool_applied",
			"grasp + carry + apply is credible")
	var skipped: Dictionary = WorldObjectScript.tool_sequence_score(true, false, true, false, false)
	_check(not bool(skipped["credible"]) and (skipped["reasons"] as Array).has("tool was not carried"),
			"skipping carry is rejected")
	var flung: Dictionary = WorldObjectScript.tool_sequence_score(true, true, true, true, false)
	_check(not bool(flung["credible"]) and (flung["reasons"] as Array).has("tool was flung"),
			"flung tool is rejected")


func _params_from_gait(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p
