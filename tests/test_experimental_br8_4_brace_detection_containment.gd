extends SceneTree
# gdlint: disable=max-line-length

## BR8.4 adversarial contract, assistance, and claim containment.

const AnalyzerScript := preload("res://scripts/lab/mechanics/brace_detection_analyzer.gd")

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
	print("=== Experimental BR8.4 brace detection containment ===")
	var mutable_configuration := CONFIGURATION.duplicate(true)
	var built := AnalyzerScript.build(mutable_configuration)
	_check(bool(built.get("ok", false)), "exact BR8 detector configuration seals")
	if not bool(built.get("ok", false)):
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var valid_summary := _valid_summary()
	var accepted := AnalyzerScript.analyze(contract, valid_summary)
	_check(
		bool(accepted.get("ok", false)) and bool(accepted.get("accepted", false)),
		"exact causal summary is representable at detector-only scope"
	)
	mutable_configuration["active_brace_controller_enabled"] = true
	_check(
		not bool(contract["active_brace_controller_enabled"]),
		"post-seal source mutation cannot enable an active brace"
	)

	var missing := CONFIGURATION.duplicate(true)
	missing.erase("reaction_time_s")
	_check(
		(
			String(AnalyzerScript.build(missing).get("failure_code", ""))
			== "BRACE_DETECTION_CONFIGURATION_FIELD_SET_MISMATCH"
		),
		"missing timing authority fails closed"
	)
	for forbidden_field in [
		"guide_motors_enabled",
		"guide_springs_enabled",
		"active_brace_controller_enabled",
		"step_controller_enabled",
		"root_rescue_enabled",
		"automatic_creature_guidance_enabled",
		"free_3d_standing_claim_enabled",
	]:
		var forged := CONFIGURATION.duplicate(true)
		forged[forbidden_field] = true
		_check(
			(
				String(AnalyzerScript.build(forged).get("failure_code", ""))
				== "BRACE_DETECTION_FORBIDDEN_ASSIST_OR_CLAIM:%s" % forbidden_field
			),
			"forbidden %s fails closed" % forbidden_field
		)

	var hidden_controller := valid_summary.duplicate(true)
	hidden_controller["active_brace_controller_present"] = true
	_check(
		(
			String(AnalyzerScript.analyze(contract, hidden_controller).get("failure_code", ""))
			== "BRACE_DETECTION_HIDDEN_ASSIST_OR_GUIDANCE"
		),
		"summary cannot hide an active brace controller"
	)
	var false_impulse := valid_summary.duplicate(true)
	false_impulse["impulse"]["first_brace_reason"] = "STATIC_MARGIN_BRACE"
	_check(
		(
			String(AnalyzerScript.analyze(contract, false_impulse).get("failure_code", ""))
			== "BRACE_DETECTION_IMPULSE_CAUSAL_GATE_FAILED"
		),
		"impulse cannot be accepted with the wrong causal channel"
	)
	var late_tilt := valid_summary.duplicate(true)
	late_tilt["tilt"]["first_static_exhaustion_tick"] = 120
	late_tilt["tilt"]["first_brace_tick"] = 120
	_check(
		(
			String(AnalyzerScript.analyze(contract, late_tilt).get("failure_code", ""))
			== "BRACE_DETECTION_TILT_CAUSAL_GATE_FAILED"
		),
		"tilt detection at rather than before exhaustion fails"
	)
	var delayed_loss := valid_summary.duplicate(true)
	delayed_loss["support_loss"]["first_loss_observed_tick"] = 94
	delayed_loss["support_loss"]["first_brace_tick"] = 94
	_check(
		(
			String(AnalyzerScript.analyze(contract, delayed_loss).get("failure_code", ""))
			== "BRACE_DETECTION_SUPPORT_LOSS_GATE_FAILED"
		),
		"late support-loss observation fails its bounded tick window"
	)
	_check(
		(
			String(accepted["claim_boundary"]) == AnalyzerScript.CLAIM_BOUNDARY
			and not bool(accepted["active_brace_executed"])
			and not bool(accepted["automatic_creature_guidance"])
		),
		"positive boundary is verbatim and cannot imply executed bracing"
	)
	var exclusions: Array = accepted["does_not_establish"]
	_check(
		(
			exclusions.has("existing_contact_brace")
			and exclusions.has("catch_step")
			and exclusions.has("free_3d_standing")
			and exclusions.has("fall_arrest")
			and exclusions.has("walking")
		),
		"explicit non-claims retain every downstream physical rung"
	)
	_check(
		(
			(accepted["milestone_cells"] as Array) == ["BR8.0", "BR8.1", "BR8.2", "BR8.3"]
			and String(accepted["integrity_cell"]) == "BR8.4"
		),
		"integrity containment cannot substitute for a physical milestone cell"
	)
	_finish()


static func _valid_summary() -> Dictionary:
	return {
		"ok": true,
		"schema_version": "brace_detection_fixture_summary_v1",
		"impulse":
		{
			"complete": true,
			"guide_exact": true,
			"impulse_operation_count": 1,
			"first_brace_tick": 60,
			"first_brace_reason": "CAPTURE_MARGIN_BRACE",
			"first_brace_static_margin_m": 0.24,
			"first_brace_capture_margin_m": -0.03,
			"first_brace_reaction_viable": true,
		},
		"tilt":
		{
			"complete": true,
			"guide_exact": true,
			"first_precarious_tick": 150,
			"first_brace_tick": 190,
			"first_brace_static_margin_m": 0.04,
			"first_static_exhaustion_tick": 220,
		},
		"support_loss":
		{
			"complete": true,
			"guide_exact": true,
			"support_removal_operation_count": 1,
			"first_loss_observed_tick": 90,
			"first_brace_tick": 90,
			"first_brace_support_count": 1,
			"first_brace_reason": "STATIC_MARGIN_EXHAUSTED",
		},
		"planar_guide_declared": true,
		"guide_motors_enabled": false,
		"guide_springs_enabled": false,
		"active_brace_controller_present": false,
		"step_controller_present": false,
		"root_rescue_present": false,
		"automatic_creature_guidance": false,
	}


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
