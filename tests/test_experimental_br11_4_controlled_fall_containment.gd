extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR11.4 digest, assistance, measurement, terminal-state, and claim containment.

const AnalyzerScript := preload("res://scripts/lab/mechanics/controlled_fall_arrest_analyzer.gd")
const OracleTestScript := preload(
	"res://tests/test_experimental_br11_2_impulse_momentum_accounting.gd"
)
const PhysicalTestScript := preload(
	"res://tests/test_experimental_br11_3_planar_controlled_fall_arrest.gd"
)

const ACTUATOR_SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const OTHER_ACTUATOR_SHA := "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR11.4 controlled-fall containment ===")
	var configuration: Dictionary = PhysicalTestScript._configuration(ACTUATOR_SHA)
	var built := AnalyzerScript.build(configuration)
	_check(bool(built.get("ok", false)), "exact paired BR11 contract seals")
	if not bool(built.get("ok", false)):
		printerr("  build_failure=", built)
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var boundary := String(contract["claim_boundary"])
	_check(
		(
			boundary.contains("one exact planar scaffold")
			and boundary.contains("not an injury model")
			and boundary.contains("not per-body or per-foot load allocation")
			and boundary.contains("no upright recovery")
			and boundary.contains("free-3D standing or bracing")
			and boundary.contains("no upright recovery")
			and boundary.contains("walking")
			and boundary.contains("automatic creature guidance")
		),
		"verbatim boundary names the scaffold, semantics, and downstream exclusions"
	)
	var accepted := AnalyzerScript.analyze(
		contract,
		OracleTestScript._valid_active(contract),
		OracleTestScript._valid_control(contract)
	)
	_check(
		bool(accepted.get("ok", false)) and bool(accepted.get("accepted", false)),
		"a fully bounded synthetic pair satisfies the sealed analyzer"
	)

	var mutated_contract := contract.duplicate(true)
	mutated_contract["maximum_active_to_control_severity_ratio"] = 1.0
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(
						mutated_contract,
						OracleTestScript._valid_active(contract),
						OracleTestScript._valid_control(contract)
					)
					. get("failure_code", "")
				)
			)
			== "CONTROLLED_FALL_CONTRACT_DIGEST_MISMATCH"
		),
		"post-seal acceptance-threshold mutation fails the digest boundary"
	)
	var missing := configuration.duplicate(true)
	missing.erase("maximum_active_to_control_linear_momentum_ratio")
	_check(
		(
			String(AnalyzerScript.build(missing).get("failure_code", ""))
			== "CONTROLLED_FALL_CONFIGURATION_FIELD_SET_MISMATCH"
		),
		"missing momentum authority fails closed"
	)
	var extra := configuration.duplicate(true)
	extra["hidden_root_assist"] = true
	_check(
		(
			String(AnalyzerScript.build(extra).get("failure_code", ""))
			== "CONTROLLED_FALL_CONFIGURATION_FIELD_SET_MISMATCH"
		),
		"extra hidden assistance field fails closed"
	)
	var invalid_actuator := configuration.duplicate(true)
	invalid_actuator["actuator_spec_sha256"] = "sha256:nope"
	_check(
		(
			String(AnalyzerScript.build(invalid_actuator).get("failure_code", ""))
			== "CONTROLLED_FALL_ACTUATOR_DIGEST_INVALID"
		),
		"the contract requires a syntactically valid actuator digest"
	)
	for forbidden_field in [
		"built_in_motor_enabled",
		"joint_limit_enabled",
		"controller_root_force_enabled",
		"foot_pin_enabled",
		"pose_teleport_enabled",
		"per_body_load_allocation_enabled",
		"injury_claim_enabled",
		"upright_recovery_claim_enabled",
		"free_3d_claim_enabled",
		"getting_up_claim_enabled",
		"gait_claim_enabled",
		"walking_claim_enabled",
		"automatic_creature_guidance_enabled",
	]:
		var forged := configuration.duplicate(true)
		forged[forbidden_field] = true
		_check(
			(
				String(AnalyzerScript.build(forged).get("failure_code", ""))
				== "CONTROLLED_FALL_FORBIDDEN_ASSIST_OR_CLAIM:%s" % forbidden_field
			),
			"forbidden %s fails closed" % forbidden_field
		)
	var no_positive_scope := configuration.duplicate(true)
	no_positive_scope["scaffold_constrained_planar_fall_arrest_claim_enabled"] = false
	_check(
		(
			String(AnalyzerScript.build(no_positive_scope).get("failure_code", ""))
			== "CONTROLLED_FALL_REQUIRED_BOUNDARY_DISABLED"
		),
		"the analyzer cannot silently erase or broaden its exact positive claim"
	)

	var wrong_actuator := OracleTestScript._valid_active(contract)
	wrong_actuator["actuator_spec_sha256"] = OTHER_ACTUATOR_SHA
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(contract, wrong_actuator, OracleTestScript._valid_control(contract))
					. get("failure_code", "")
				)
			)
			== "CONTROLLED_FALL_SUMMARY_ACTUATOR_DIGEST_MISMATCH"
		),
		"an unbound actuator specification fails before acceptance evaluation"
	)
	var wrong_configuration := OracleTestScript._valid_active(contract)
	wrong_configuration["configuration_sha256"] = OTHER_ACTUATOR_SHA
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(
						contract, wrong_configuration, OracleTestScript._valid_control(contract)
					)
					. get("failure_code", "")
				)
			)
			== "CONTROLLED_FALL_SUMMARY_CONFIGURATION_DIGEST_MISMATCH"
		),
		"a summary from another configuration cannot cross the evidence boundary"
	)
	var missing_summary_field := OracleTestScript._valid_active(contract)
	missing_summary_field.erase("angular_momentum_available")
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(
						contract, missing_summary_field, OracleTestScript._valid_control(contract)
					)
					. get("failure_code", "")
				)
			)
			== "CONTROLLED_FALL_SUMMARY_FIELD_SET_MISMATCH"
		),
		"a missing evidence channel fails the exact summary schema"
	)
	var extra_summary_field := OracleTestScript._valid_active(contract)
	extra_summary_field["injury_score"] = 0.0
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(
						contract, extra_summary_field, OracleTestScript._valid_control(contract)
					)
					. get("failure_code", "")
				)
			)
			== "CONTROLLED_FALL_SUMMARY_FIELD_SET_MISMATCH"
		),
		"an undeclared injury channel cannot enter the summary"
	)
	for integrity_forgery in [
		{"field": "planar_guide_exact", "value": false},
		{"field": "hinge_exact", "value": false},
		{"field": "all_receipts_complete", "value": false},
		{"field": "angular_momentum_available", "value": false},
		{"field": "protective_role_registered", "value": false},
		{"field": "core_role_registered", "value": false},
		{"field": "local_core_load_is_generalized_allocation", "value": true},
		{"field": "severity_proxy_is_injury_model", "value": true},
	]:
		var forged_integrity := OracleTestScript._valid_active(contract)
		forged_integrity[integrity_forgery["field"]] = integrity_forgery["value"]
		_check(
			(
				String(
					(
						AnalyzerScript
						. analyze(
							contract, forged_integrity, OracleTestScript._valid_control(contract)
						)
						. get("failure_code", "")
					)
				)
				== "CONTROLLED_FALL_SUMMARY_INTEGRITY_FAILED"
			),
			"forged %s fails summary integrity" % integrity_forgery["field"]
		)
	for forbidden_count in [
		"root_rescue_operation_count",
		"foot_pin_operation_count",
		"pose_teleport_operation_count",
		"automatic_creature_guidance_operation_count",
	]:
		var assisted := OracleTestScript._valid_active(contract)
		assisted[forbidden_count] = 1
		_check(
			(
				String(
					(
						AnalyzerScript
						. analyze(contract, assisted, OracleTestScript._valid_control(contract))
						. get("failure_code", "")
					)
				)
				== "CONTROLLED_FALL_SUMMARY_ASSIST_OR_ACTUATOR_BOUNDARY_FAILED"
			),
			"nonzero %s cannot pass as physical fall arrest" % forbidden_count
		)
	var excessive_pairing := OracleTestScript._valid_active(contract)
	excessive_pairing["maximum_pairing_residual_nm"] = 0.001
	_check(
		not bool(
			(
				AnalyzerScript
				. analyze(contract, excessive_pairing, OracleTestScript._valid_control(contract))
				. get("ok", true)
			)
		),
		"an unpaired actuator command cannot satisfy the mechanics boundary"
	)
	var excessive_torque := OracleTestScript._valid_active(contract)
	excessive_torque["maximum_applied_torque_nm"] = 45.1
	_check(
		not bool(
			(
				AnalyzerScript
				. analyze(contract, excessive_torque, OracleTestScript._valid_control(contract))
				. get("ok", true)
			)
		),
		"torque above the declared finite actuator ceiling fails closed"
	)
	var wrong_type := OracleTestScript._valid_active(contract)
	wrong_type["angular_momentum_available"] = 1
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(contract, wrong_type, OracleTestScript._valid_control(contract))
					. get("failure_code", "")
				)
			)
			== "CONTROLLED_FALL_SUMMARY_BOOL_INVALID:angular_momentum_available"
		),
		"truthy numeric values cannot impersonate boolean evidence"
	)
	var wrong_mode := OracleTestScript._valid_active(contract)
	wrong_mode["arrest_enabled"] = false
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(contract, wrong_mode, OracleTestScript._valid_control(contract))
					. get("failure_code", "")
				)
			)
			== "CONTROLLED_FALL_SUMMARY_MODE_MISMATCH"
		),
		"the active world cannot be relabeled from a zero-command summary"
	)
	var exclusions: Array = accepted["does_not_establish"]
	_check(
		(
			exclusions.has("injury_prediction")
			and exclusions.has("per_body_measured_load_allocation")
			and exclusions.has("upright_recovery")
			and exclusions.has("free_3d_standing")
			and exclusions.has("free_3d_bracing")
			and exclusions.has("generalized_fall_arrest")
			and exclusions.has("getting_up")
			and exclusions.has("gait")
			and exclusions.has("walking")
			and exclusions.has("automatic_creature_guidance")
		),
		"accepted analysis preserves every downstream physical and guidance non-claim"
	)
	_check(
		(
			(accepted["milestone_cells"] as Array) == ["BR11.0", "BR11.1", "BR11.2", "BR11.3"]
			and String(accepted["integrity_cell"]) == "BR11.4"
		),
		"integrity containment cannot substitute for a physical milestone cell"
	)
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
