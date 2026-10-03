extends SceneTree

## Experimental BR4/L2.7 deliberate anchor-error perturbation.

const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/anchor_error_perturbation_analyzer.gd")

const ANCHOR_TOLERANCE_M := 0.005
const PERTURBATIONS_M := [0.0, 0.0025, 0.0075, 0.02]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.7 anchor perturbation ===")
	var build: Dictionary = AnalyzerScript.build(_configuration())
	_check(bool(build.get("ok", false)), "four-point perturbation grid seals")
	_test_configuration_refusals()
	if not bool(build.get("ok", false)):
		_finish()
		return
	var binding_build: Dictionary = JointBindingScript.build(_binding_configuration())
	_check(bool(binding_build.get("ok", false)), "strict anchor-test binding compiles")
	if not bool(binding_build.get("ok", false)):
		_finish()
		return
	var samples: Array = []
	for index in PERTURBATIONS_M.size():
		var perturbation := float(PERTURBATIONS_M[index])
		var state: Dictionary = JointStateScript.sample(
			binding_build["binding"],
			_body_sample("anchor_parent", index, Transform3D.IDENTITY),
			_body_sample(
				"anchor_child", index, Transform3D(Basis.IDENTITY, Vector3(perturbation, 0.0, 0.0))
			)
		)
		var availability: Dictionary = state["availability"]
		(
			samples
			. append(
				{
					"index": index,
					"perturbation_m": perturbation,
					"predicted_anchor_error_m": perturbation,
					"observed_anchor_error_m": state["anchor_agreement_error_m"],
					"observation_valid": bool(state["observation_valid"]),
					"geometry_available":
					(
						String((availability["/anchor_agreement_error_m"] as Dictionary)["status"])
						!= "unavailable"
					),
					"angle_available":
					(
						String((availability["/wrapped_angle_rad"] as Dictionary)["status"])
						!= "unavailable"
					),
					"rate_available":
					(
						String((availability["/axis_rate_rad_s"] as Dictionary)["status"])
						!= "unavailable"
					),
					"invalid_reasons": state["invalid_reasons"],
					"active_torque_nm": 0.0,
					"passive_torque_nm": 0.0,
					"command_count": 0,
				}
			)
		)
		_print_state(index, perturbation, state)
	var analysis: Dictionary = AnalyzerScript.analyze(build["contract"], samples)
	_check(bool(analysis.get("ok", false)), "perturbation trace satisfies digest-bound analyzer")
	if not bool(analysis.get("ok", false)):
		print("  analysis_failure=", analysis)
		_finish()
		return
	var result: Dictionary = analysis["result"]
	_check(bool(result["accepted"]), "four-point grid satisfies all L2.7 gates")
	_check(
		int(result["valid_count"]) == 2 and int(result["rejected_count"]) == 2,
		"two in-tolerance cases remain valid and two out-of-tolerance cases reject"
	)
	_check(
		(
			is_equal_approx(float(result["largest_valid_error_m"]), 0.0025)
			and is_equal_approx(float(result["smallest_rejected_error_m"]), 0.0075)
			and int(result["first_rejected_index"]) == 2
		),
		"measured validity boundary is monotonic and brackets the 5 mm tolerance"
	)
	_check(
		(
			String((result["case_signatures"] as Array)[0]) == "valid"
			and String((result["case_signatures"] as Array)[1]) == "valid"
			and String((result["case_signatures"] as Array)[2]) == "anchor_mismatch_fail_closed"
			and String((result["case_signatures"] as Array)[3]) == "anchor_mismatch_fail_closed"
		),
		"out-of-tolerance cases carry the exact anchor-mismatch failure signature"
	)
	_check(
		(
			String(result["rejected_numeric_anchor_channel_policy"]) == "null"
			and String(result["dependent_channel_policy"]) == "unavailable_not_zero"
		),
		"rejected geometry suppresses dependent numeric channels instead of forging zeros"
	)
	_check(
		(
			float(result["active_torque_nm"]) == 0.0
			and float(result["passive_torque_nm"]) == 0.0
			and int(result["command_count"]) == 0
		),
		"anchor classification uses no motor, passive torque, or command"
	)
	_test_analyzer_refusals(build["contract"], samples)
	_check(
		(
			String(result["claim_boundary"])
			== (
				"Exact synthetic same-epoch joint-observer anchor perturbations only; this "
				+ "establishes failure signatures and channel availability, not physical joint "
				+ "strength, load bearing, standing, bracing, recovery, gait, or walking."
			)
		),
		"L2.7 result carries the exact observer-only non-claim boundary"
	)
	_finish()


func _test_configuration_refusals() -> void:
	var no_bracket := _configuration()
	no_bracket["perturbations_m"] = [0.0, 0.001, 0.002, 0.003]
	var hidden_motor := _configuration()
	hidden_motor["built_in_motor_enabled"] = true
	var unsorted := _configuration()
	unsorted["perturbations_m"] = [0.0, 0.01, 0.002, 0.02]
	var unknown := _configuration()
	unknown["repair_anchor"] = true
	_check(
		(
			not bool(AnalyzerScript.build(no_bracket).get("ok", true))
			and not bool(AnalyzerScript.build(hidden_motor).get("ok", true))
			and not bool(AnalyzerScript.build(unsorted).get("ok", true))
			and not bool(AnalyzerScript.build(unknown).get("ok", true))
		),
		"perturbation contract rejects unbracketed/unsorted grids, hidden motor, and repair"
	)


func _test_analyzer_refusals(contract: Dictionary, source_samples: Array) -> void:
	var mutated := contract.duplicate(true)
	mutated["anchor_tolerance_m"] = 0.006
	var mutated_result: Dictionary = AnalyzerScript.analyze(mutated, source_samples)
	var short := source_samples.duplicate(true)
	short.pop_back()
	var short_result: Dictionary = AnalyzerScript.analyze(contract, short)
	var forged_valid := source_samples.duplicate(true)
	(forged_valid[2] as Dictionary)["observation_valid"] = true
	var forged_result: Dictionary = AnalyzerScript.analyze(contract, forged_valid)
	var hidden_torque := source_samples.duplicate(true)
	(hidden_torque[0] as Dictionary)["active_torque_nm"] = 1.0
	var torque_result: Dictionary = AnalyzerScript.analyze(contract, hidden_torque)
	_check(
		(
			(
				String(mutated_result.get("failure_code", ""))
				== "ANCHOR_PERTURBATION_CONTRACT_DIGEST_MISMATCH"
			)
			and (
				String(short_result.get("failure_code", ""))
				== "ANCHOR_PERTURBATION_SAMPLE_COUNT_MISMATCH"
			)
			and (
				String(forged_result.get("failure_code", ""))
				== "ANCHOR_PERTURBATION_REJECTION_SIGNATURE_MISMATCH"
			)
			and (
				String(torque_result.get("failure_code", ""))
				== "ANCHOR_PERTURBATION_HIDDEN_TORQUE_OR_COMMAND"
			)
		),
		"mutated contract, missing case, forged validity, and hidden torque fail closed"
	)


static func _configuration() -> Dictionary:
	return {
		"schema_version": "anchor_error_perturbation_configuration_v1",
		"experiment_id": "l2_7_anchor_error_boundary",
		"anchor_tolerance_m": ANCHOR_TOLERANCE_M,
		"perturbations_m": PERTURBATIONS_M.duplicate(),
		"gravity_enabled": false,
		"contact_enabled": false,
		"built_in_motor_enabled": false,
		"limit_enabled": false,
		"active_torque_enabled": false,
		"passive_torque_enabled": false,
	}


static func _binding_configuration() -> Dictionary:
	return {
		"joint_id": "l2_7_anchor_observer",
		"parent_body_id": "anchor_parent",
		"child_body_id": "anchor_child",
		"axis_parent_local": Vector3.BACK,
		"axis_child_local": Vector3.BACK,
		"anchor_parent_local": Vector3.ZERO,
		"anchor_child_local": Vector3.ZERO,
		"rest_child_rotation_parent_local": Quaternion.IDENTITY,
		"anchor_agreement_tolerance_m": ANCHOR_TOLERANCE_M,
		"axis_agreement_tolerance_rad": 0.02,
		"swing_tolerance_rad": 0.02,
		"local_joint_scale_m": 0.2,
		"local_joint_scale_basis": "joint_fixture_extent_min_v1",
		"morphology_config_digest_sha256": "sha256:%s" % "l2_7_anchor_error_boundary".sha256_text(),
		"requires_unwrapped_angle": false,
	}


static func _body_sample(body_id: String, index: int, transform: Transform3D) -> Dictionary:
	return {
		"schema_version": "mechanics_body_sample_v1",
		"physics_step_id": index,
		"capture_epoch": index,
		"sample_phase": "post_step",
		"step_s": 1.0 / 120.0,
		"body_id": body_id,
		"run_id": "l2_7_anchor_error_boundary",
		"capture_stream_id": "l2_7_synthetic_joint_pair",
		"observer_profile_id": "l2_7_joint_frames",
		"observer_adapter_id": "synthetic_same_epoch_pair_v1",
		"finite": true,
		"transform":
		{
			"basis":
			[
				_vec(transform.basis.x),
				_vec(transform.basis.y),
				_vec(transform.basis.z),
			],
			"origin": _vec(transform.origin),
		},
		"angular_velocity": [0.0, 0.0, 0.0],
	}


static func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _print_state(index: int, perturbation: float, state: Dictionary) -> void:
	print(
		(
			"  case=%d injected=%.4fm valid=%s anchor=%s reasons=%s"
			% [
				index,
				perturbation,
				str(bool(state["observation_valid"])),
				str(state["anchor_agreement_error_m"]),
				str(state["invalid_reasons"]),
			]
		)
	)


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
