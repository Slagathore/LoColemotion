extends SceneTree

## Experimental L1.1 pure observer/analyzer commissioning.
##
## The filename intentionally does not match test_lab_*.gd. BR1's released
## report-v2 contract pins exactly 62 test identities; L1.1 will enter a later
## versioned inventory only after its semantics and live fixture are stable.

const SlipObserverScript := preload(
	"res://scripts/lab/mechanics/contact_slip_observer.gd")
const BreakawayAnalyzerScript := preload(
	"res://scripts/lab/mechanics/friction_breakaway_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

# Vector3 components are float32 in this Godot build. The rotated projection
# oracle performs normalization, projection, and division by a 0.02 s step;
# 1e-5 bounds that accumulated representation error without approaching any
# physical hold/sliding threshold used by the live experiment.
const EPSILON := 1.0e-5
const FORCE_RESIDUAL_EPSILON_N := 1.0e-4

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Experimental L1.1 contact-slip observer tests ===")
	_test_world_orientation_invariant_decomposition()
	_test_normal_motion_is_not_slip()
	_test_zero_normal_impulse_keeps_ratio_unavailable()
	_test_invalid_patch_fails_closed()
	_test_staged_breakaway_bracket()
	_test_breakaway_refuses_invalid_histories()
	_finish()


func _test_world_orientation_invariant_decomposition() -> void:
	print("- decomposes velocity, impulse, and applied force in the contact plane")
	var normal := Vector3(1.0, 1.0, 0.0).normalized()
	var tangent := Vector3(1.0, -1.0, 0.0).normalized()
	var step_s := 0.02
	var patch := _patch(
		normal,
		normal * 0.2 + tangent * 0.3,
		normal * 10.0 - tangent * 2.0)
	var observed: Dictionary = SlipObserverScript.observe(
		patch,
		step_s,
		tangent * 100.0,
		_post_step_kinematics(normal * 0.2 + tangent * 0.3))
	_check(bool(observed["observation_valid"]),
		"finite canonical patch produces a valid slip observation")
	_check_close(float(observed["relative_separation_speed_mps"]), 0.2,
		"normal relative velocity is preserved separately")
	_check_close(float(observed["slip_speed_mps"]), 0.3,
		"tangential slip speed excludes normal approach/separation")
	_check_close(float(observed["normal_impulse_ns"]), 10.0,
		"normal impulse is J dot n")
	_check_close(float(observed["tangential_impulse_ns"]), 2.0,
		"tangential impulse removes the normal projection")
	_check_close(float(observed["predicted_normal_load_n"]), 500.0,
		"normal step-average estimate is Jn divided by delta-t")
	_check_close(float(observed["predicted_tangential_load_n"]), 100.0,
		"tangential step-average estimate is magnitude(Jt)/delta-t")
	_check_close(float(observed["solver_friction_ratio"]), 0.2,
		"solver friction utilization is magnitude(Jt)/Jn")
	_check_close(float(observed["applied_to_predicted_normal_ratio"]), 0.2,
		"commanded shear is normalized by the observed normal-load estimate")
	_check_close(float(observed["contact_opposes_applied_shear_cosine"]), 1.0,
		"predicted contact shear points opposite the applied force")
	var residual: Vector3 = observed[
		"predicted_tangential_force_balance_residual_world_n"]
	_check(residual.length() <= FORCE_RESIDUAL_EPSILON_N,
		"static synthetic case closes the tangential force-balance residual "
			+ "(%.9f N)" % residual.length())
	_check(String(observed["static_or_sliding_classification"])
			== "not_decided_by_single_sample",
		"one frame cannot declare static hold or breakaway")


func _test_normal_motion_is_not_slip() -> void:
	print("- does not confuse approach/separation with tangential slip")
	var patch := _patch(
		Vector3.UP,
		Vector3(0.0, -0.4, 0.0),
		Vector3(0.0, 3.0, 0.0))
	var observed: Dictionary = SlipObserverScript.observe(
		patch,
		0.01,
		Vector3.ZERO,
		_post_step_kinematics(Vector3(0.0, -0.4, 0.0)))
	_check(bool(observed["observation_valid"])
		and float(observed["slip_speed_mps"]) <= EPSILON
		and absf(float(observed["relative_separation_speed_mps"]) + 0.4)
			<= EPSILON,
		"pure normal contact motion has zero tangential slip")


func _test_zero_normal_impulse_keeps_ratio_unavailable() -> void:
	print("- preserves unavailable load ratios instead of inventing numeric zero")
	var observed: Dictionary = SlipObserverScript.observe(
		_patch(Vector3.UP, Vector3.ZERO, Vector3.ZERO),
		0.01,
		Vector3(2.0, 0.0, 0.0),
		_post_step_kinematics(Vector3.ZERO))
	_check(bool(observed["observation_valid"])
		and not bool(observed["normal_load_available"])
		and observed["solver_friction_ratio"] == null
		and observed["applied_to_predicted_normal_ratio"] == null,
		"zero normal impulse leaves both friction ratios explicitly unavailable")


func _test_invalid_patch_fails_closed() -> void:
	print("- rejects nonfinite, inconsistent, and unsupported contact evidence")
	var nonfinite := _patch(
		Vector3.UP,
		Vector3(INF, 0.0, 0.0),
		Vector3.UP)
	var nonfinite_result: Dictionary = SlipObserverScript.observe(
		nonfinite,
		0.01,
		Vector3.ZERO,
		_post_step_kinematics(Vector3.ZERO))
	_check(not bool(nonfinite_result["observation_valid"])
		and (nonfinite_result["invalid_reasons"] as Array).has(
			"SOLVER_INPUT_RELATIVE_VELOCITY_NONFINITE"),
		"nonfinite solver-input relative velocity invalidates the observation")

	var inconsistent := _patch(
		Vector3.UP,
		Vector3.ZERO,
		Vector3(0.0, 5.0, 0.0))
	inconsistent["normal_impulse_ns"] = 50.0
	var inconsistent_result: Dictionary = SlipObserverScript.observe(
		inconsistent,
		0.01,
		Vector3.ZERO,
		_post_step_kinematics(Vector3.ZERO))
	_check(not bool(inconsistent_result["observation_valid"])
		and (inconsistent_result["invalid_reasons"] as Array).has(
			"CONTACT_NORMAL_IMPULSE_INCONSISTENT"),
		"stored and recomputed normal impulse must agree")

	var unsupported := _patch(
		Vector3.UP, Vector3.ZERO, Vector3.UP)
	unsupported["impulse_quality"] = "exact_force_claim"
	var unsupported_result: Dictionary = SlipObserverScript.observe(
		unsupported,
		0.01,
		Vector3.ZERO,
		_post_step_kinematics(Vector3.ZERO))
	_check(not bool(unsupported_result["observation_valid"])
		and (unsupported_result["invalid_reasons"] as Array).has(
			"CONTACT_IMPULSE_QUALITY_UNSUPPORTED"),
		"an unsupported impulse interpretation cannot enter L1.1")


func _test_staged_breakaway_bracket() -> void:
	print("- brackets breakaway between completed hold and sliding stages")
	var built: Dictionary = BreakawayAnalyzerScript.build_config(
		_breakaway_configuration())
	_check(bool(built["ok"]),
		"valid hysteretic staged-breakaway configuration builds")
	var stages := [
		_stage("load_00", 0.0, 0.001, 0.0001, 20.0),
		_stage("load_08", 8.0, 0.004, 0.0005, 20.0),
		_stage("load_10", 10.0, 0.02, 0.004, 20.0),
		_stage("load_12", 12.0, 0.08, 0.02, 20.0),
	]
	var result: Dictionary = BreakawayAnalyzerScript.analyze(
		built["config"], stages)
	_check(bool(result["ok"]) and bool(result["breakaway_detected"]),
		"monotonic stages with hold then sustained sliding produce a bracket")
	_check(String(result["last_held_stage_id"]) == "load_08"
		and String(result["first_sliding_stage_id"]) == "load_12",
		"ambiguous transition stage is retained inside the bracket")
	_check_close(float(result["breakaway_force_lower_n"]), 8.0,
		"last held force is the bracket lower endpoint")
	_check_close(float(result["breakaway_force_upper_n"]), 12.0,
		"first sustained sliding force is the bracket upper endpoint")
	_check_close(float(result["empirical_static_ratio_lower"]), 0.4,
		"lower empirical ratio uses the lower stage's measured normal load")
	_check_close(float(result["empirical_static_ratio_upper"]), 0.6,
		"upper empirical ratio uses the upper stage's measured normal load")
	_check((result["does_not_establish"] as Array).has("walking"),
		"breakaway analysis carries its locomotion claim exclusion")


func _test_breakaway_refuses_invalid_histories() -> void:
	print("- refuses histories that cannot bound a unique monotonic breakaway")
	var config: Dictionary = BreakawayAnalyzerScript.build_config(
		_breakaway_configuration())["config"]
	var extended_config: Dictionary = config.duplicate(true)
	extended_config["automatic_walking_claim"] = true
	var extended_payload := extended_config.duplicate(true)
	extended_payload.erase("config_digest_sha256")
	extended_config["config_digest_sha256"] = CanonicalJsonScript.sha256(
		extended_payload)
	var extended_result: Dictionary = BreakawayAnalyzerScript.analyze(
		extended_config, [
			_stage("hold", 1.0, 0.001, 0.0001, 20.0),
			_stage("slide", 2.0, 0.08, 0.02, 20.0),
		])
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] \
			== ["BREAKAWAY_CONFIG_INVALID"],
		"even a coherently rehashed unknown config field fails closed")

	var no_hold: Dictionary = BreakawayAnalyzerScript.analyze(config, [
		_stage("slide_1", 1.0, 0.08, 0.02, 20.0),
		_stage("slide_2", 2.0, 0.12, 0.04, 20.0),
	])
	_check(not bool(no_hold["ok"])
		and (no_hold["invalid_reasons"] as Array).has(
			"BREAKAWAY_NO_COMPLETED_HOLD_STAGE"),
		"sliding from the first stage yields no lower bound")

	var held_after_slide: Dictionary = BreakawayAnalyzerScript.analyze(config, [
		_stage("hold", 1.0, 0.001, 0.0001, 20.0),
		_stage("slide", 2.0, 0.08, 0.02, 20.0),
		_stage("impossible_hold", 3.0, 0.001, 0.0001, 20.0),
	])
	_check(not bool(held_after_slide["ok"])
		and (held_after_slide["invalid_reasons"] as Array).has(
			"BREAKAWAY_HELD_STAGE_AFTER_SLIDING"),
		"a higher-force held stage after sliding invalidates the run")

	var incomplete := _stage("missing_contact", 1.0, 0.001, 0.0001, 20.0)
	incomplete["contact_sample_count"] = 11
	var incomplete_result: Dictionary = BreakawayAnalyzerScript.analyze(config, [
		incomplete,
		_stage("slide", 2.0, 0.08, 0.02, 20.0),
	])
	_check(not bool(incomplete_result["ok"])
		and (incomplete_result["invalid_reasons"] as Array).has(
			"BREAKAWAY_STAGE_CONTACT_INCOMPLETE:0"),
		"missing contact frames cannot be silently treated as holding")


func _patch(
		normal: Vector3,
		relative_velocity: Vector3,
		impulse: Vector3) -> Dictionary:
	return {
		"schema_version": "contact_patch_v1",
		"contact_patch_id": "sha256:" + "a".repeat(64),
		"physics_step_id": 7,
		"capture_epoch": 7,
		"sample_phase": "integrate_callback",
		"run_id": "l1-1-pure-run",
		"capture_stream_id": "l1-1-pure-stream",
		"observer_profile_id": "full_contacts_v2",
		"observer_adapter_id": "rigid_body_integrate_forces_v2",
		"contact_present": true,
		"point_world": Vector3.ZERO,
		"normal_available": true,
		"normal_world": normal,
		"relative_velocity_world_mps": relative_velocity,
		"impulse_world_ns": impulse,
		"normal_impulse_ns": impulse.dot(normal.normalized()),
		"impulse_quality": "jolt_predicted_estimate",
		"finite": true,
	}


func _post_step_kinematics(
		body_linear_velocity_world_mps: Vector3) -> Dictionary:
	return {
		"physics_step_id": 7,
		"capture_epoch": 7,
		"sample_phase": "post_step",
		"body_linear_velocity_world_mps": body_linear_velocity_world_mps,
		"body_angular_velocity_world_rad_s": Vector3.ZERO,
		"body_center_of_mass_world_m": Vector3.ZERO,
		"counterparty_velocity_world_mps": Vector3.ZERO,
	}


func _breakaway_configuration() -> Dictionary:
	return {
		"minimum_samples_per_stage": 12,
		"maximum_holding_speed_mps": 0.005,
		"maximum_holding_displacement_m": 0.001,
		"minimum_sliding_speed_mps": 0.05,
		"minimum_sliding_displacement_m": 0.01,
	}


func _stage(
		stage_id: String,
		force_n: float,
		max_speed_mps: float,
		displacement_m: float,
		normal_load_n: float) -> Dictionary:
	return {
		"stage_id": stage_id,
		"applied_shear_force_n": force_n,
		"sample_count": 12,
		"valid_sample_count": 12,
		"contact_sample_count": 12,
		"max_slip_speed_mps": max_speed_mps,
		"tangential_displacement_m": displacement_m,
		"mean_normal_load_n": normal_load_n,
	}


func _check_close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) <= EPSILON,
		"%s (actual %.8f, expected %.8f)" % [label, actual, expected])


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
