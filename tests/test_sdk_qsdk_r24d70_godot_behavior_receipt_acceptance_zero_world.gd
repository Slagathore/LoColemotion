extends SceneTree
# gdlint: disable=max-line-length

## Data-driven R70 consumer and retention controls. These fixtures exercise
## the production receipt validator and compact invariant summarizer without
## constructing a model, world, RID, or solver step.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_ZERO_WORLD "
const ARM_ORDER := ["candidate_command", "matched_zero_command"]
const TRACE_A := "sha256:b05e62bf13857ceb23f9e7c23aec609c6404bda7f969b35a4ac06165d6e05630"
const TRACE_B := "sha256:b10cc4bed82462b1a4deed394f0d0ccbcaf6801122ae6bedbbd96607f6ce5816"
const INITIAL_STATE := "sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6"


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D70_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D70_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")

	var positive := _evaluation_fixture("physical_development_passed")
	var negative := _evaluation_fixture("physical_development_failed")
	var incomplete := _evaluation_fixture("physical_development_incomplete")
	var acceptance_specs := [
		{"id": "positive", "value": positive, "outcome": "positive"},
		{"id": "negative_r69_shape", "value": negative, "outcome": "negative"},
		{"id": "incomplete", "value": incomplete, "outcome": "incomplete"},
	]
	var ordered_acceptance_receipts: Array = []
	for spec_value in acceptance_specs:
		var spec: Dictionary = spec_value
		var accepted := RouteScript.validate_physical_evaluation_receipt_v1(
			spec["value"]
		)
		if (
			not bool(accepted.get("ok", false))
			or String(accepted.get("status", "")) != "accepted"
			or String(accepted.get("scientific_outcome", "")) != String(spec["outcome"])
			or int(accepted.get("common_check_count", -1)) != 22
			or int(accepted.get("common_pass_count", -1)) != 22
			or int(accepted.get("verdict_check_count", -1)) != 9
			or int(accepted.get("verdict_pass_count", -1)) != 9
			or not _zero_authority(accepted)
		):
			return _failure(
				"QSDK_R24D70_ZERO_WORLD_VALID_RECEIPT_REJECTED",
				{"fixture_id": spec["id"], "acceptance": accepted},
			)
		ordered_acceptance_receipts.append(accepted)

	var refused := negative.duplicate(true)
	refused["verdict"] = "refused"
	refused["support_status"] = "invalid_observation"
	refused["refusal_reason"] = "trace_or_initial_state_invalid"
	refused["initial_state_identity_matched"] = false
	refused["physical_development_trace_valid"] = false
	var refused_candidate: Dictionary = refused["candidate_trace"]
	refused_candidate["refused"] = true
	refused["candidate_trace"] = refused_candidate
	var refusal_receipt := RouteScript.validate_physical_evaluation_receipt_v1(refused)
	if (
		bool(refusal_receipt.get("ok", true))
		or String(refusal_receipt.get("status", "")) != "refused"
		or String(refusal_receipt.get("scientific_outcome", "")) != "invalid"
		or not _zero_authority(refusal_receipt)
	):
		return _failure("QSDK_R24D70_ZERO_WORLD_REFUSAL_ACCEPTED", refusal_receipt)

	var mutations := [
		{"id": "positive_all_negative_false", "value": _with(positive, "all_negative_control_requirements_enforced", false)},
		{"id": "positive_result_false", "value": _with(positive, "physical_result", false)},
		{"id": "positive_claim_false", "value": _with(positive, "prone_to_standing_claimed", false)},
		{"id": "positive_candidate_flag_false", "value": _with(positive, "candidate_physical_path_completed", false)},
		{"id": "positive_zero_flag_false", "value": _with(positive, "matched_zero_command_physical_control_failed_to_complete", false)},
		{"id": "positive_candidate_trace_incomplete", "value": _with_trace(positive, "candidate_trace", "completed", false)},
		{"id": "negative_all_negative_true", "value": _with(negative, "all_negative_control_requirements_enforced", true)},
		{"id": "negative_wrong_verdict", "value": _with(negative, "verdict", "physical_development_passed")},
		{"id": "negative_observation_rejected", "value": _with_trace(negative, "candidate_trace", "accepted_observation_count", 262)},
		{"id": "incomplete_candidate_failed", "value": _with_trace(incomplete, "candidate_trace", "final_phase", "failed")},
		{"id": "incomplete_zero_failed", "value": _with_trace(incomplete, "matched_zero_command_trace", "final_phase", "failed")},
		{"id": "physical_trace_invalid", "value": _with(negative, "physical_development_trace_valid", false)},
		{"id": "evaluator_count_nonzero", "value": _with(negative, "solver_step_count", 1)},
		{"id": "physical_authority_present", "value": _with(negative, "physical_acceptance_authority", true)},
		{"id": "synthetic_canary_present", "value": _with(negative, "synthetic_canary_passed", true)},
		{"id": "unknown_verdict", "value": _with(negative, "verdict", "unexpected")},
		{"id": "candidate_trace_missing", "value": _with(negative, "candidate_trace", null)},
	]
	var receipt_mutation_rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var rejected := RouteScript.validate_physical_evaluation_receipt_v1(
			mutation["value"]
		)
		if (
			bool(rejected.get("ok", true))
			or String(rejected.get("status", "")) != "refused"
			or String(rejected.get("scientific_outcome", "")) != "invalid"
			or not _zero_authority(rejected)
		):
			return _failure(
				"QSDK_R24D70_ZERO_WORLD_RECEIPT_MUTATION_ACCEPTED",
				{"mutation_id": mutation["id"], "acceptance": rejected},
			)
		receipt_mutation_rejection_count += 1

	var arm_results := {
		"candidate_command": _arm_fixture("candidate_command", 2, TRACE_A),
		"matched_zero_command": _arm_fixture("matched_zero_command", 3, TRACE_B),
	}
	var full_summary := RouteScript.compact_behavior_arm_invariant_summary_v1(
		sdk, arm_results, ARM_ORDER, 5
	)
	var one_arm_results := {
		"candidate_command": arm_results["candidate_command"].duplicate(true),
	}
	var one_arm_summary := RouteScript.compact_behavior_arm_invariant_summary_v1(
		sdk, one_arm_results, ARM_ORDER, 2
	)
	var zero_arm_summary := RouteScript.compact_behavior_arm_invariant_summary_v1(
		sdk, {}, ARM_ORDER, 0
	)
	for summary_value in [full_summary, one_arm_summary, zero_arm_summary]:
		var summary: Dictionary = summary_value
		if not bool(summary.get("ok", false)) or not _zero_authority(summary):
			return _failure("QSDK_R24D70_ZERO_WORLD_TERMINAL_SUMMARY_INVALID", summary)
	if (
		int(full_summary.get("completed_arm_count", -1)) != 2
		or int(full_summary.get("summarized_solver_step_count", -1)) != 5
		or not _valid_sha256(String(full_summary.get("ordered_arm_summaries_sha256", "")))
		or int(one_arm_summary.get("completed_arm_count", -1)) != 1
		or int(zero_arm_summary.get("completed_arm_count", -1)) != 0
	):
		return _failure("QSDK_R24D70_ZERO_WORLD_TERMINAL_SUMMARY_COUNTS_INVALID")

	var summary_mutations: Array = []
	var count_mutation: Dictionary = arm_results.duplicate(true)
	var count_arm: Dictionary = count_mutation["candidate_command"]
	count_arm["in_run_invariant_receipt_count"] = 1
	count_mutation["candidate_command"] = count_arm
	summary_mutations.append({"id": "declared_count_mismatch", "value": count_mutation, "total": 5, "order": ARM_ORDER})
	var invariant_mutation: Dictionary = arm_results.duplicate(true)
	var invariant_arm: Dictionary = invariant_mutation["candidate_command"]
	var invariant_population: Array = invariant_arm["in_run_invariant_receipts"]
	var invalid_invariant: Dictionary = invariant_population[0]
	invalid_invariant["all_in_run_physical_invariants_passed"] = false
	invariant_population[0] = invalid_invariant
	invariant_arm["in_run_invariant_receipts"] = invariant_population
	invariant_mutation["candidate_command"] = invariant_arm
	summary_mutations.append({"id": "invariant_flag_false", "value": invariant_mutation, "total": 5, "order": ARM_ORDER})
	summary_mutations.append({"id": "total_solver_count_mismatch", "value": arm_results, "total": 4, "order": ARM_ORDER})
	summary_mutations.append({"id": "ordered_population_incomplete", "value": arm_results, "total": 5, "order": ["candidate_command"]})
	var identity_mutation: Dictionary = arm_results.duplicate(true)
	var identity_arm: Dictionary = identity_mutation["candidate_command"]
	identity_arm["arm_kind"] = "matched_zero_command"
	identity_mutation["candidate_command"] = identity_arm
	summary_mutations.append({"id": "arm_identity_mismatch", "value": identity_mutation, "total": 5, "order": ARM_ORDER})
	var digest_mutation: Dictionary = arm_results.duplicate(true)
	var digest_arm: Dictionary = digest_mutation["candidate_command"]
	digest_arm["trace_v3_sha256"] = "invalid"
	digest_mutation["candidate_command"] = digest_arm
	summary_mutations.append({"id": "trace_digest_invalid", "value": digest_mutation, "total": 5, "order": ARM_ORDER})
	var summary_mutation_rejection_count := 0
	for mutation_value in summary_mutations:
		var mutation: Dictionary = mutation_value
		var rejected := RouteScript.compact_behavior_arm_invariant_summary_v1(
			sdk, mutation["value"], mutation["order"], int(mutation["total"])
		)
		if bool(rejected.get("ok", true)) or not _zero_authority(rejected):
			return _failure(
				"QSDK_R24D70_ZERO_WORLD_SUMMARY_MUTATION_ACCEPTED",
				{"mutation_id": mutation["id"], "summary": rejected},
			)
		summary_mutation_rejection_count += 1

	var content_mutation: Dictionary = arm_results.duplicate(true)
	var content_arm: Dictionary = content_mutation["candidate_command"]
	var content_population: Array = content_arm["in_run_invariant_receipts"]
	var content_receipt: Dictionary = content_population[0]
	content_receipt["content_mutation_control"] = true
	content_population[0] = content_receipt
	content_arm["in_run_invariant_receipts"] = content_population
	content_mutation["candidate_command"] = content_arm
	var content_summary := RouteScript.compact_behavior_arm_invariant_summary_v1(
		sdk, content_mutation, ARM_ORDER, 5
	)
	if (
		not bool(content_summary.get("ok", false))
		or String(content_summary.get("ordered_arm_summaries_sha256", ""))
		== String(full_summary.get("ordered_arm_summaries_sha256", ""))
	):
		return _failure("QSDK_R24D70_ZERO_WORLD_SUMMARY_CONTENT_DIGEST_INSENSITIVE")

	var reversed_arm_results := {
		"matched_zero_command": arm_results["matched_zero_command"].duplicate(true),
		"candidate_command": arm_results["candidate_command"].duplicate(true),
	}
	var reversed_summary := RouteScript.compact_behavior_arm_invariant_summary_v1(
		sdk, reversed_arm_results, ARM_ORDER, 5
	)
	if (
		not bool(reversed_summary.get("ok", false))
		or String(reversed_summary.get("ordered_arm_summaries_sha256", ""))
		!= String(full_summary.get("ordered_arm_summaries_sha256", ""))
	):
		return _failure("QSDK_R24D70_ZERO_WORLD_SUMMARY_DICTIONARY_ORDER_SENSITIVE")

	return {
		"schema_version": "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_zero_world_v1",
		"gate_id": "QSDK-R24D70",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_development_control",
			"question_class": "development",
		},
		"ok": true,
		"failure_code": "",
		"acceptance_fixture_count": ordered_acceptance_receipts.size(),
		"positive_acceptance_count": 1,
		"negative_acceptance_count": 1,
		"incomplete_acceptance_count": 1,
		"r69_failure_shape_accepted": true,
		"refusal_rejection_count": 1,
		"receipt_mutation_rejection_count": receipt_mutation_rejection_count,
		"receipt_common_check_count": 22,
		"receipt_verdict_check_count": 9,
		"terminal_summary_fixture_count": 3,
		"full_summary_arm_count": 2,
		"full_summary_invariant_count": 5,
		"summary_mutation_rejection_count": summary_mutation_rejection_count,
		"content_mutation_digest_change_count": 1,
		"dictionary_order_invariance_count": 1,
		"ordered_acceptance_receipts": ordered_acceptance_receipts,
		"full_summary": full_summary,
		"native_runtime_observation_collection_executed": false,
		"physical_question_opened": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _evaluation_fixture(verdict: String) -> Dictionary:
	var candidate := _trace_fixture("candidate_command", false, "failed", 263)
	var zero := _trace_fixture("matched_zero_command", false, "failed", 263)
	if verdict == "physical_development_passed":
		candidate = _trace_fixture("candidate_command", true, "complete", 307)
		zero = _trace_fixture("matched_zero_command", false, "failed", 775)
	elif verdict == "physical_development_incomplete":
		candidate = _trace_fixture("candidate_command", false, "establish_distal_support", 1200)
		zero = _trace_fixture("matched_zero_command", false, "settle_prone", 1200)
	var candidate_complete := bool(candidate["completed"])
	var zero_failed := not bool(zero["completed"]) and String(zero["final_phase"]) == "failed"
	var passed := candidate_complete and zero_failed
	return {
		"schema_version": "sporespore_recovery_evaluation_receipt_v1",
		"support_status": "supported_exact",
		"refusal_reason": null,
		"verdict": verdict,
		"descriptor_sha256": INITIAL_STATE,
		"morphology_spec_sha256": TRACE_A,
		"actuator_profile_sha256": TRACE_B,
		"capability_sha256": TRACE_A,
		"threshold_profile_sha256": TRACE_B,
		"candidate_trace": candidate,
		"matched_zero_command_trace": zero,
		"initial_state_identity_matched": true,
		"candidate_synthetic_path_completed": false,
		"matched_zero_command_control_failed_to_complete": false,
		"candidate_physical_path_completed": candidate_complete,
		"matched_zero_command_physical_control_failed_to_complete": zero_failed,
		"physical_development_trace_valid": true,
		"all_negative_control_requirements_enforced": passed,
		"controller_implemented": true,
		"synthetic_canary_passed": false,
		"physical_threshold_authority": true,
		"physical_question_opened": true,
		"physical_result": passed,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": passed,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _trace_fixture(
	arm_kind: String,
	completed: bool,
	final_phase: String,
	observation_count: int,
) -> Dictionary:
	return {
		"arm_kind": arm_kind,
		"completed": completed,
		"final_phase": final_phase,
		"observation_count": observation_count,
		"accepted_observation_count": observation_count,
		"refused": false,
		"terminal_failure_code": (
			"phase_timeout:establish_distal_support" if final_phase == "failed" else null
		),
	}


static func _arm_fixture(arm_kind: String, step_count: int, trace_sha256: String) -> Dictionary:
	var invariants: Array = []
	for step in range(1, step_count + 1):
		invariants.append(
			{
				"schema_version": "sporespore_qsdk_r24d65_godot_in_run_invariant_receipt_v1",
				"arm_kind": arm_kind,
				"semantic_step": step,
				"all_in_run_physical_invariants_passed": true,
			}
		)
	return {
		"arm_kind": arm_kind,
		"outer_step_count": step_count,
		"native_solver_step_count": step_count,
		"in_run_invariant_receipt_count": step_count,
		"in_run_invariant_receipts": invariants,
		"final_phase": "failed",
		"terminal_failure_code": "phase_timeout:establish_distal_support",
		"trace_v3_sha256": trace_sha256,
		"declared_initial_state_sha256": INITIAL_STATE,
	}


static func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var mutated := source.duplicate(true)
	mutated[key] = value
	return mutated


static func _with_trace(
	source: Dictionary,
	trace_key: String,
	field: String,
	value: Variant,
) -> Dictionary:
	var mutated := source.duplicate(true)
	var trace: Dictionary = mutated[trace_key]
	trace[field] = value
	mutated[trace_key] = trace
	return mutated


static func _valid_sha256(value: String) -> bool:
	return (
		value.begins_with("sha256:")
		and value.length() == 71
		and value.trim_prefix("sha256:").is_valid_hex_number(false)
	)


static func _zero_authority(receipt: Dictionary) -> bool:
	return (
		int(receipt.get("model_construction_count", -1)) == 0
		and int(receipt.get("world_attempt_count", -1)) == 0
		and int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("solver_step_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(receipt.get("release_authority", true))
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_zero_world_v1",
		"gate_id": "QSDK-R24D70",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"native_runtime_observation_collection_executed": false,
		"physical_question_opened": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
