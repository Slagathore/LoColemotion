extends SceneTree

## Adversarial checks for Cole's append-only BR12 milestone decision.
##
## This test proves only the bounded decision and its zero-side-effect policy.
## It does not admit knowledge, authorize guidance, execute a recovery,
## or claim getting up, free 3D bracing, or standing.

const RegistryScript := preload("res://scripts/lab/milestone_decision_registry.gd")
const ContractScript := preload("res://scripts/lab/br12_milestone_decision_contract.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR12 milestone-decision tests ===")
	var loaded := RegistryScript.load_by_id(RegistryScript.BR12_DECISION_ID)
	_check(
		bool(loaded.get("ok", false)),
		"allowlisted BR12 decision loads from exact schema and decision bytes"
	)
	if not bool(loaded.get("ok", false)):
		printerr("  decision_failure=", loaded)
		_finish()
		return
	var decision: Dictionary = loaded["decision"]
	_check(
		(
			decision.is_read_only()
			and decision["status"] == "accepted"
			and decision["decided_by"]["id"] == "Cole"
		),
		"accepted decision is immutable and names the project decider"
	)
	_check(
		decision["authorization"] == ContractScript.EXPECTED_AUTHORIZATION,
		"decision binds Cole's delegated acceptance and exact review"
	)
	_check(
		_dictionary_matches(decision["evidence_basis"], ContractScript.EXPECTED_EVIDENCE),
		"decision binds the exact campaign, report, receipt, source, and role counts"
	)
	_check(
		(
			decision["accepted_contracts"] == ContractScript.ACCEPTED_CONTRACTS
			and decision["accepted_capabilities"] == ContractScript.ACCEPTED_CAPABILITIES
		),
		"accepted contracts and fixture-bounded capabilities match exactly"
	)
	_check(
		(
			decision["supplementary_constraints"] == ContractScript.SUPPLEMENTARY_CONSTRAINTS
			and decision["excluded_capabilities"] == ContractScript.EXCLUDED_CAPABILITIES
		),
		"integrity role, scaffold, measurement boundary, and non-claims remain exact"
	)
	_check(
		(
			_dictionary_matches(decision["knowledge_effects"], ContractScript.KNOWLEDGE_EFFECTS)
			and int(decision["knowledge_effects"]["entries_admitted_by_decision"]) == 0
			and not bool(decision["knowledge_effects"]["automatic_creature_guidance_allowed"])
		),
		"acceptance admits no knowledge and authorizes no automatic guidance"
	)
	_check(
		(
			RegistryScript.accepted_milestone_ids()
			== [
				"BR10_REACHABLE_PLANAR_CATCH",
				"BR11_CONTROLLED_PLANAR_FALL",
				"BR12_POSE_AND_RECOVERY_FEASIBILITY",
				"BR13_CONSTRAINED_CANONICAL_GET_UP",
				"BR2.1_ARTICULATED_OBSERVER",
				"BR3A_L1_ENGINE_CONTACT_TRUTH",
				"BR3B_L3_BASIC_LOADED_FOOT_TRUTH",
				"BR4_L2_JOINT_ACTUATOR_TRUTH",
				"BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT",
				"BR7_PLANAR_MULTI_CONTACT_STANCE",
				"BR8_EARLY_LOSS_OF_VIABILITY_DETECTION",
				"BR9_EXISTING_CONTACT_PLANAR_BRACE",
			]
		),
		"registry exposes exactly the twelve bounded accepted decision records"
	)
	for previous_id in [
		RegistryScript.BR2_1_DECISION_ID,
		RegistryScript.BR3A_DECISION_ID,
		RegistryScript.BR4_DECISION_ID,
		RegistryScript.BR3B_DECISION_ID,
		RegistryScript.BR6A_DECISION_ID,
		RegistryScript.BR7_DECISION_ID,
		RegistryScript.BR8_DECISION_ID,
		RegistryScript.BR9_DECISION_ID,
		RegistryScript.BR10_DECISION_ID,
		RegistryScript.BR11_DECISION_ID,
	]:
		var previous := RegistryScript.load_by_id(previous_id)
		_check(bool(previous.get("ok", false)), "previous decision remains independently intact")

	var broadened := decision.duplicate(true)
	broadened["claim_boundary"] = "BR12 proves free 3D bracing and standing."
	_assert_rejected(broadened, "claim-boundary broadening fails closed")
	var promoted_integrity := decision.duplicate(true)
	promoted_integrity["supplementary_constraints"].erase(
		ContractScript.SUPPLEMENTARY_CONSTRAINTS[0]
	)
	_assert_rejected(promoted_integrity, "BR12.4 cannot be promoted into physical capability")
	var removed_profile := decision.duplicate(true)
	removed_profile["supplementary_constraints"].erase(ContractScript.SUPPLEMENTARY_CONSTRAINTS[1])
	_assert_rejected(removed_profile, "exact canonical pose profile cannot be removed")
	var forged_dynamic_proof := decision.duplicate(true)
	var forged_constraints: Array = forged_dynamic_proof["supplementary_constraints"]
	forged_constraints[5] = "Static feasibility proves the dynamic recovery will succeed."
	_assert_rejected(
		forged_dynamic_proof, "static feasibility cannot be relabeled as dynamic execution"
	)
	var weakened_get_up_exclusion := decision.duplicate(true)
	weakened_get_up_exclusion["excluded_capabilities"].erase("Physical self-righting or getting up")
	_assert_rejected(weakened_get_up_exclusion, "physical get-up exclusion cannot be removed")
	var weakened_measurement_exclusion := decision.duplicate(true)
	weakened_measurement_exclusion["excluded_capabilities"].erase(
		"Measured per-contact, per-body, per-foot, or per-toe load allocation"
	)
	_assert_rejected(weakened_measurement_exclusion, "measured-load exclusion cannot be removed")
	var weakened_standing_exclusion := decision.duplicate(true)
	weakened_standing_exclusion["excluded_capabilities"].erase(
		"Free 3D standing, bracing, recovery, or unconstrained balance"
	)
	_assert_rejected(weakened_standing_exclusion, "free 3D exclusion cannot be weakened")
	var forged_report := decision.duplicate(true)
	forged_report["evidence_basis"]["report_sha256"] = "sha256:" + "a".repeat(64)
	_assert_rejected(forged_report, "substituting certification report identity fails closed")
	var forged_source := decision.duplicate(true)
	forged_source["evidence_basis"]["source_inventory_sha256"] = "sha256:" + "b".repeat(64)
	_assert_rejected(forged_source, "substituting certified source closure fails closed")
	var forged_review := decision.duplicate(true)
	forged_review["authorization"]["review_sha256"] = "sha256:" + "c".repeat(64)
	_assert_rejected(forged_review, "substituting reviewed decision context fails closed")
	var wrong_role_count := decision.duplicate(true)
	wrong_role_count["evidence_basis"]["integrity_assertions"] = 29
	_assert_rejected(wrong_role_count, "integrity assertions cannot be hidden from accounting")
	var automatic_admission := decision.duplicate(true)
	automatic_admission["knowledge_effects"]["entries_admitted_by_decision"] = 4
	_assert_rejected(automatic_admission, "decision cannot smuggle in knowledge admission")
	var automatic_guidance := decision.duplicate(true)
	automatic_guidance["knowledge_effects"]["automatic_creature_guidance_allowed"] = true
	_assert_rejected(automatic_guidance, "decision cannot authorize automatic creature guidance")
	var forged_decider := decision.duplicate(true)
	forged_decider["decided_by"]["id"] = "automatic_gate"
	_assert_rejected(forged_decider, "an automatic gate cannot impersonate Cole")
	var unknown := RegistryScript.load_by_id("BR12_POSE_AND_RECOVERY_FEASIBILITY_DECISION_V2")
	_check(
		(
			not bool(unknown.get("ok", true))
			and unknown.get("failure_code") == RegistryScript.FAILURE_DECISION_UNKNOWN
		),
		"unregistered revisions have no permissive fallback"
	)
	_finish()


func _assert_rejected(candidate: Dictionary, label: String) -> void:
	var result := RegistryScript.validate_candidate(candidate)
	_check(not bool(result.get("ok", true)), label)


func _dictionary_matches(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key in expected:
		if not actual.has(key) or actual[key] != expected[key]:
			return false
	return true


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
