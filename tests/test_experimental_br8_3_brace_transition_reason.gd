extends SceneTree
# gdlint: disable=max-line-length

## BR8.3 live impulse, platform-tilt, and disappearing-support evidence.

const AnalyzerScript := preload("res://scripts/lab/mechanics/brace_detection_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/brace_detection_fixture_rig.gd")

const CONFIGURATION := {
	"schema_version": "brace_detection_configuration_v1",
	"physics_hz": 60,
	"impulse_tick": 60,
	"impulse_total_ticks": 180,
	"impulse_n_s": 3.4,
	"tilt_start_tick": 60,
	"tilt_ramp_ticks": 180,
	"tilt_total_ticks": 270,
	"tilt_maximum_angle_rad": deg_to_rad(36.0),
	"support_loss_tick": 90,
	"support_loss_total_ticks": 150,
	"brace_margin_m": 0.03,
	"precarious_margin_m": 0.08,
	"release_margin_m": 0.12,
	"reaction_time_s": 0.08,
	"safety_time_s": 0.02,
	"brace_trigger_time_s": 0.25,
	"precarious_trigger_time_s": 0.50,
	"release_dwell_ticks": 3,
	"planar_guide_enabled": true,
	"guide_motors_enabled": false,
	"guide_springs_enabled": false,
	"active_brace_controller_enabled": false,
	"step_controller_enabled": false,
	"root_rescue_enabled": false,
	"automatic_creature_guidance_enabled": false,
	"free_3d_standing_claim_enabled": false,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR8.3 live brace transition reasons ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = int(CONFIGURATION["physics_hz"])
	var built := AnalyzerScript.build(CONFIGURATION)
	_check(bool(built.get("ok", false)), "digest-bound passive disturbance contract seals")
	if not bool(built.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var summary: Dictionary = await rig.run(self, built["contract"])
	print("  summary=", summary)
	_check(bool(summary.get("ok", false)), "all three fresh physics fixtures complete")
	if not bool(summary.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var impulse: Dictionary = summary["impulse"]
	var tilt: Dictionary = summary["tilt"]
	var support_loss: Dictionary = summary["support_loss"]
	var analysis := AnalyzerScript.analyze(built["contract"], summary)
	_check(
		bool(analysis.get("ok", false)) and bool(analysis.get("accepted", false)),
		"digest-bound BR8 analyzer accepts the complete causal matrix"
	)
	_check(
		(
			int(impulse["initial_stand_samples"]) >= 55
			and int(impulse["impulse_operation_count"]) == 1
			and int(impulse["first_brace_tick"]) >= 60
		),
		"horizontal impulse fixture is stable before one declared impulse"
	)
	_check(
		(
			String(impulse["first_brace_reason"]) == "CAPTURE_MARGIN_BRACE"
			and float(impulse["first_brace_static_margin_m"]) > 0.03
			and float(impulse["first_brace_capture_margin_m"]) <= 0.03
			and bool(impulse["first_brace_reaction_viable"])
		),
		"impulse BRACE is capture-driven while static support and reaction time remain"
	)
	_check(
		(
			String(impulse["first_transition"]["to_state"]) == "BRACE"
			and String(impulse["first_transition"]["reason"]) == "CAPTURE_MARGIN_BRACE"
			and bool(impulse["guide_exact"])
		),
		"impulse transition retains its reason under the exact passive planar guide"
	)

	_check(
		(
			int(tilt["initial_stand_samples"]) >= 55
			and int(tilt["first_precarious_tick"]) >= 60
			and int(tilt["first_brace_tick"]) > int(tilt["first_precarious_tick"])
		),
		"slow platform tilt progresses from STAND through PRECARIOUS to BRACE"
	)
	_check(
		(
			float(tilt["first_brace_static_margin_m"]) >= 0.0
			and (
				int(tilt["first_static_exhaustion_tick"]) < 0
				or int(tilt["first_brace_tick"]) < int(tilt["first_static_exhaustion_tick"])
			)
			and bool(tilt["guide_exact"])
		),
		"tilt detector fires before measured static support is exhausted"
	)

	_check(
		(
			int(support_loss["initial_two_support_samples"]) >= 80
			and int(support_loss["support_removal_operation_count"]) == 1
			and int(support_loss["first_loss_observed_tick"]) >= 90
			and int(support_loss["first_loss_observed_tick"]) <= 92
		),
		"two real contacts precede one observed support removal"
	)
	_check(
		(
			int(support_loss["first_brace_tick"]) == int(support_loss["first_loss_observed_tick"])
			and int(support_loss["first_brace_support_count"]) == 1
			and String(support_loss["first_brace_reason"]) == "STATIC_MARGIN_EXHAUSTED"
		),
		"disappearing support produces an immediate reasoned BRACE observation"
	)
	_check(
		(
			String(support_loss["first_transition"]["to_state"]) == "BRACE"
			and String(support_loss["first_transition"]["reason"]) == "STATIC_MARGIN_EXHAUSTED"
			and bool(support_loss["guide_exact"])
		),
		"support-loss transition retains exact decomposed evidence"
	)
	_check(
		(
			not bool(summary["active_brace_controller_present"])
			and not bool(summary["step_controller_present"])
			and not bool(summary["root_rescue_present"])
			and not bool(summary["automatic_creature_guidance"])
		),
		"fixture contains no brace actuation, step, root rescue, or guidance"
	)
	_check(
		(
			not bool(analysis["active_brace_executed"])
			and (analysis["does_not_establish"] as Array).has("free_3d_standing")
			and (analysis["does_not_establish"] as Array).has("walking")
		),
		"accepted detector observation remains fenced from bracing and locomotion"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
