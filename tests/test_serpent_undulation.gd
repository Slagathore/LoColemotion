extends SceneTree

## M59 — HONEST serpent undulation. The serpent's authored gait has traction_scale=0 and
## posture_scale=0 (no central-force assist), and the stance-traction assist is mode-gated off for
## undulation anyway. So any forward travel is REAL: a lateral body-wave (identity-frame box chain,
## yaw hinges) rectified into thrust by the anisotropic belly friction (grips sideways, slides
## forward). This pins the cheat shut — earlier the serpent only "moved" via a traction central force
## shoving it (forward collapsed to ~0 with the assist off); now it crawls on its own.

const CpgP := preload("res://scripts/sim/cpg_controller.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== M59 honest serpent undulation ===")
	# Authored gait (no assist) — real undulation.
	var driven: Dictionary = await SimRollout.run(PartCatalog.make_serpent_v2(), 4.0, 7, self)
	# Same body, drive killed — isolates how much the wave itself contributes.
	var dead_root := PartCatalog.make_serpent_v2()
	dead_root.gait.amplitude_scale = 0.0
	dead_root.gait.gain_scale = 0.0
	var dead: Dictionary = await SimRollout.run(dead_root, 4.0, 7, self)
	var fwd := float(driven.get("forward", 0.0))
	var dead_fwd := float(dead.get("forward", 0.0))
	print("  driven fwd=%.3f | no-drive fwd=%.3f | traction_impulse=%.1f" % [
		fwd, dead_fwd, float(driven.get("traction_impulse", 0.0))])
	_check(bool(driven.get("ok", false)) and not bool(driven.get("teleport", false)),
			"serpent rollout is finite + no solver blow-up")
	_check(float(driven.get("traction_impulse", 0.0)) < 1.0,
			"NO central-force traction assist is applied (honest: the body does the work)")
	_check(fwd > 0.8, "the body-wave propels the serpent forward on its own (no assist)")
	_check(fwd > dead_fwd + 0.3, "driving the undulation beats the no-drive baseline (real thrust)")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
