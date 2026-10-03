extends SceneTree

## Honest contact diagnostic. Uses the new Jolt-contact sensors to answer the user's exact questions:
## is it ever airborne (true_air), does it drag its body (drag), do the feet ever step (plants /
## feet_up), how much do the feet vs body touch.

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _pf(g) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if g.gait != null:
		p.amplitude_scale = g.gait.amplitude_scale; p.frequency_scale = g.gait.frequency_scale
		p.gain_scale = g.gait.gain_scale; p.traction_scale = g.gait.traction_scale
		p.posture_scale = g.gait.posture_scale
		if g.gait.locomotion_mode != &"":
			p.locomotion_mode = g.gait.locomotion_mode
	return p


func _diag(label: String, g) -> void:
	if g == null:
		print("  %-12s <null>" % label); return
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _pf(g)
	rp.sense_contacts = true
	var r: Dictionary = await SimRolloutScript.run(g, 12.0, 7, self, rp)   # long horizon catches blowups
	print("  %-12s fwd=%+.2f  lat=%+.2f  up_min=%.2f  h_drop=%.2f  finite=%s  teleport=%s  traction=%.1f" % [
		label, float(r.get("forward", 0.0)), float(r.get("lateral", 0.0)),
		float(r.get("root_up_min", 1.0)), float(r.get("root_height_drop", 0.0)),
		str(r.get("finite", true)), str(r.get("teleport", false)),
		float(r.get("traction_impulse", 0.0))])
	print("      motion: true_air=%.2f body_drag=%.2f foot_touch=%.2f plants=%d fell=%s class=%s" % [
		float(r.get("true_airborne_frac", 0.0)), float(r.get("body_drag_frac", 0.0)),
		float(r.get("foot_contact_frac", 0.0)), int(r.get("foot_plants", 0)),
		str(r.get("fell", false)), String(r.get("locomotion_class", ""))])


func _run() -> void:
	print("=== honest contact diagnostic (true_air=0 -> never airborne; body_drag~1 -> worming; plants=0 -> feet never step) ===")
	await _diag("frog", PartCatalog.make_frog_v2())
	await _diag("hopper", PartCatalog.make_hopper_v2())
	await _diag("serpent", PartCatalog.make_serpent_v2())
	await _diag("centipede", PartCatalog.make_centipede_v2())
	await _diag("urchin", PartCatalog.make_sea_urchin_v2())
	await _diag("quad_v2", PartCatalog.make_quadruped_v2())
	await _diag("crab", PartCatalog.make_crab_v2())
	await _diag("mantis", PartCatalog.make_mantis_v2())
	await _diag("scorpion", PartCatalog.make_scorpion_v2())
	await _diag("spider", PartCatalog.make_spider_v2())
	await _diag("daddylong", PartCatalog.make_daddy_longlegs_v2())
	await _diag("tortoise", PartCatalog.make_tortoise_v2())
	await _diag("starfish", PartCatalog.make_starfish_v2())
	await _diag("monopod", PartCatalog.make_monopod_v2())
	await _diag("glider", PartCatalog.make_glider_v2())
	quit(0)
