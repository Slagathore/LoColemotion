extends SceneTree

## Adversarial checks for Cole's append-only BR4 milestone decision.
##
## This test proves only the bounded decision and its zero-side-effect policy.
## It does not admit knowledge, authorize guidance, or claim locomotion.

const RegistryScript := preload("res://scripts/lab/milestone_decision_registry.gd")
const ContractScript := preload("res://scripts/lab/br4_milestone_decision_contract.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4 milestone-decision tests ===")
	var loaded := RegistryScript.load_by_id(RegistryScript.BR4_DECISION_ID)
	_check(
		bool(loaded.get("ok", false)),
		"allowlisted BR4 decision loads from exact schema and decision bytes"
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
		"decision binds Cole's explicit bounded acceptance and reviewed context"
	)
	_check(
		_dictionary_matches(decision["evidence_basis"], ContractScript.EXPECTED_EVIDENCE),
		"decision binds the exact campaign, report, receipt, source, and counts"
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
		"fixture constraints and every non-claim remain explicit"
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
	var br2 := RegistryScript.load_by_id(RegistryScript.BR2_1_DECISION_ID)
	_check(
		(
			bool(br2.get("ok", false))
			and String(br2["decision"]["milestone_id"]) == "BR2.1_ARTICULATED_OBSERVER"
			and String(br2["decision_sha256"]) == RegistryScript.BR2_1_DECISION_SHA256
		),
		"BR2.1 decision bytes and semantics remain independently intact"
	)
	var br3a := RegistryScript.load_by_id(RegistryScript.BR3A_DECISION_ID)
	_check(
		(
			bool(br3a.get("ok", false))
			and String(br3a["decision"]["milestone_id"]) == "BR3A_L1_ENGINE_CONTACT_TRUTH"
			and String(br3a["decision_sha256"]) == RegistryScript.BR3A_DECISION_SHA256
		),
		"BR3A decision bytes and semantics remain independently intact"
	)

	var broadened := decision.duplicate(true)
	broadened["claim_boundary"] = "BR4 generally proves creature support."
	_assert_rejected(broadened, "claim-boundary broadening fails closed")
	var weakened_exclusions := decision.duplicate(true)
	weakened_exclusions["excluded_capabilities"].erase("Gait, candidate walking, or walking")
	_assert_rejected(weakened_exclusions, "removing the walking exclusion fails closed")
	var forged_report := decision.duplicate(true)
	forged_report["evidence_basis"]["report_sha256"] = ("sha256:" + "a".repeat(64))
	_assert_rejected(forged_report, "substituting the certification report identity fails closed")
	var forged_source := decision.duplicate(true)
	forged_source["evidence_basis"]["source_inventory_sha256"] = ("sha256:" + "b".repeat(64))
	_assert_rejected(forged_source, "substituting the certified source closure fails closed")
	var forged_instruction := decision.duplicate(true)
	forged_instruction["authorization"]["instruction"] = "ship everything"
	_assert_rejected(forged_instruction, "rewriting Cole's bounded instruction fails closed")
	var forged_review := decision.duplicate(true)
	forged_review["authorization"]["review_sha256"] = ("sha256:" + "c".repeat(64))
	_assert_rejected(forged_review, "substituting the reviewed decision context fails closed")
	var automatic_admission := decision.duplicate(true)
	automatic_admission["knowledge_effects"]["entries_admitted_by_decision"] = 8
	_assert_rejected(automatic_admission, "decision cannot smuggle in knowledge admission")
	var automatic_guidance := decision.duplicate(true)
	automatic_guidance["knowledge_effects"]["automatic_creature_guidance_allowed"] = true
	_assert_rejected(automatic_guidance, "decision cannot authorize automatic creature guidance")
	var invented_program := decision.duplicate(true)
	invented_program["accepted_contracts"].append("contact_bearing_limb_analysis_v1")
	_assert_rejected(
		invented_program, "an uncertified contact-bearing program cannot enter the milestone"
	)
	var removed_allocation_guard := decision.duplicate(true)
	removed_allocation_guard["excluded_capabilities"].erase(
		"Per-contact, per-foot, or per-toe load allocation"
	)
	_assert_rejected(removed_allocation_guard, "per-foot allocation guard cannot be removed")
	var promoted_limit_strength := decision.duplicate(true)
	promoted_limit_strength["supplementary_constraints"].erase(
		"A hard-limit constraint reaction is not available muscle or actuator strength"
	)
	_assert_rejected(
		promoted_limit_strength, "hard-limit reaction cannot be promoted into available strength"
	)
	var fake_rejection := decision.duplicate(true)
	fake_rejection["status"] = "rejected"
	_assert_rejected(fake_rejection, "registered accepted record cannot be relabeled as rejected")
	var forged_decider := decision.duplicate(true)
	forged_decider["decided_by"]["id"] = "automatic_gate"
	_assert_rejected(forged_decider, "an automatic gate cannot impersonate Cole")
	var unknown := RegistryScript.load_by_id("BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V2")
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
