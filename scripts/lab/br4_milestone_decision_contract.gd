class_name LabBr4MilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's bounded BR4 L2 milestone decision.
##
## The generic BR2.1 decision schema is deliberately BR1-shaped and already
## byte-pinned. This separate contract binds the BR4 report family without
## weakening or mutating that accepted record. Validation is pure and writes
## nothing; the append-only registry owns file admission and byte pins.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br4_milestone_decision.v1"
const SCHEMA_PATH := "res://data/lab/schemas/br4_milestone_decision_v1.schema.json"
const DECISION_ID := "BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1"
const MILESTONE_ID := "BR4_L2_JOINT_ACTUATOR_TRUTH"

const CERTIFICATION_CLAIM_BOUNDARY := (
	"This campaign can certify only the exact L2.0-L2.7 joint-actuator "
	+ "observations named by the source-pinned programs. Fixed scaffolds, free "
	+ "roots, actuator envelopes, hard-limit reactions, two-joint behavior, "
	+ "and anchor-observer failures retain their declared fixture scopes. It "
	+ "establishes no contact-bearing articulated limb, per-foot or "
	+ "per-contact load allocation, standing, bracing, fall arrest, getting "
	+ "up, gait, walking, accepted knowledge, or automatic creature guidance."
)

const DECISION_CLAIM_BOUNDARY := (
	"BR4 accepts only the exact L2.0-L2.7 program claim scopes in certification "
	+ "br4_20260723T090118Z_1760c2cf at source commit "
	+ "1760c2cfdfd4cf6fd5b482d090588a680515d1db. The certification report's "
	+ "verbatim claim boundary and all eight program scopes remain controlling."
)

const EXPECTED_AUTHORIZATION := {
	"instruction":
	(
		"continue the pipeline. i defer to your judgement on what should be "
		+ "accepted. assume i accept whatever it is that you recommend and "
		+ "keep going"
	),
	"interpretation": "delegated_bounded_acceptance_of_recommended_br4_l2_joint_actuator_truth",
	"review_path": "docs/BR4_L2_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "3588f92b5fe0e56e4c07aa114491ab4544c0988b",
	"review_sha256": "sha256:f82f25c51086cfb8f286cf8e98513a3d123b1c57c0221d86665a994e1e8d6fb8",
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br4_certification_report_v1",
	"certification_id": "br4_20260723T090118Z_1760c2cf",
	"certification_contract_id": "BR4_L2_JOINT_ACTUATOR_TRUTH",
	"campaign_id": "BR4_L2_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": "sha256:c5a8c97bd5bb3b58e79412f742d44eb266ef6e8f6eb6d83ad25eab15d49af417",
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br4_certification_report.v1",
	"report_status": "pass",
	"report_sha256": "sha256:c21e209a37a94cc24072a135c33689b6511965ae9c14c8a56ca1d0b4d253dc33",
	"report_bytes": 32649,
	"report_locator":
	"LabEvidence/BR4/br4_20260723T090118Z_1760c2cf/" + "br4_certification_report.json",
	"report_generated_utc": "2026-07-23T09:03:54.6764262Z",
	"receipt_schema": "sporespore.lab.br4_certification_report_attestation.v1",
	"receipt_sha256": "sha256:d652b1ab1484110c00ce8769f361033a3e6e58632dcac71cd8b11d11f760f34c",
	"receipt_locator":
	(
		"LabTrust/v1/br4_certification_reports_v1/receipts/"
		+ "24706133a89b48611af23b2fb4f2cc2ee45063d008a5e841c8edf9687306004a.json"
	),
	"receipt_attested_utc": "2026-07-23T09:04:01Z",
	"receipt_key_id": "sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20",
	"source_commit_sha": "1760c2cfdfd4cf6fd5b482d090588a680515d1db",
	"source_inventory_sha256":
	"sha256:a7780e98f0801894d474bb0af02ab78499c4768d8e13fd1c75a66b588c0fcec3",
	"source_file_count": 214,
	"br1_inventory_sha256":
	"sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e",
	"br1_inventory_unchanged": true,
	"engine_version": "4.7.stable.mono.official.5b4e0cb0f",
	"engine_sha256": "sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4",
	"programs_required": 8,
	"programs_passed": 8,
	"replicates_per_program": 2,
	"bundles_required": 16,
	"bundles_passed": 16,
	"assertions_required": 262,
	"assertions_passed": 262,
	"milestone_programs": 8,
	"milestone_assertions": 262,
	"supplementary_programs": 0,
	"supplementary_assertions": 0,
	"integrity_programs": 0,
	"integrity_assertions": 0,
	"target_process_invocations": 16,
	"unique_target_processes": 16,
	"pid_recycle_events": 0,
	"receipts_verified": 16,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"passive_pendulum_analysis_v1",
	"joint_torque_pulse_analysis_v1",
	"joint_pd_controller_resolution_v1",
	"unloaded_pd_step_analysis_v1",
	"gravity_hold_analysis_v1",
	"actuator_spec_v1",
	"joint_actuator_resolution_v1",
	"actuator_envelope_case_analysis_v1",
	"hard_limit_reaction_analysis_v1",
	"two_link_chain_analysis_v1",
	"anchor_error_perturbation_analysis_v1",
]

const ACCEPTED_CAPABILITIES := [
	"The declared L2.0 single-link passive pendulum matches its analytic period, energy, sign, geometry, and damping controls within the certified fixture tolerances",
	"The declared L2.1 free-root hinge applies equal-and-opposite parent-child torque, preserves total angular momentum, and rejects root-only assistance",
	"The declared L2.2 unloaded PD controller resolves mirrored step requests into deterministic paired torque with the certified rise, settling, decomposition, and momentum behavior",
	"The declared L2.3 fixed-scaffold link responds with the certified sign and magnitude at 0, 80, 100, and 120 percent analytic gravity compensation",
	"The declared L2.4 finite actuator enforces its exact isometric torque, speed, positive-power, absorption, and eccentric limits at the certified operating points",
	"The declared L2.5 mirrored hinge approaches are arrested near the hard limits by constraint reaction while the disabled control crosses without commanded torque",
	"The declared L2.6 two-link chain distinguishes fixed and free roots, produces only paired joint torque receipts, and preserves free-system momentum without root assistance",
	"The declared L2.7 joint observer accepts anchor mismatch only inside tolerance and fails closed with zero commands when geometry is mismatched or unavailable",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"A fixed scaffold is an analytic fixture and does not establish free-creature support",
	"A hard-limit constraint reaction is not available muscle or actuator strength",
	"Exact actuator operating points do not establish continuous endurance, fatigue, or thermal capacity",
	"Anchor-observer rejection is a fail-closed measurement boundary and performs no automatic repair",
]

const EXCLUDED_CAPABILITIES := [
	"A contact-bearing articulated limb, foot, or creature",
	"Per-contact, per-foot, or per-toe load allocation",
	"Built-in motor authority or root-only assistance",
	"A hard-limit reaction as available muscle strength",
	"Continuous endurance, fatigue, or thermal capacity",
	"Standing, bracing, or fall arrest",
	"Self-righting or getting up",
	"Gait, candidate walking, or walking",
	"Accepted encyclopedia knowledge or automatic creature guidance",
]

const DOWNSTREAM_OPEN := [
	"Build and certify a contact-bearing articulated limb under externally measured load",
	"Run the articulated parent-child mass-ratio grid with accepted joint truth",
	"Establish a validated multi-contact load-allocation method before any per-foot or per-toe claim",
	"Establish support-force control and contact-phase truth before standing or bracing",
	"Admit selected knowledge entries through a separate promotion operation",
	"Authorize creature guidance only from separately admitted knowledge and later accepted support milestones",
	"Prove every future bracing, standing, fall-arrest, recovery, gait, and walking milestone separately",
]

const KNOWLEDGE_EFFECTS := {
	"entries_admitted_by_decision": 0,
	"automatic_admission": false,
	"automatic_creature_guidance_allowed": false,
	"development_drafts_remain_non_entries": true,
}

const FAILURE_JSON_INVALID := "BR4_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR4_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR4_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "BR4 milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR4 milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantic_errors := _semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR4 milestone decision differs from Cole's bounded acceptance.",
			{"semantic_errors": semantic_errors}
		)
	return {
		"ok": true,
		"failure_code": "",
		"decision": decision.duplicate(true),
	}


static func _semantic_errors(decision: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if String(decision.get("schema", "")) != SCHEMA:
		errors.append("SCHEMA_MISMATCH")
	if String(decision.get("decision_id", "")) != DECISION_ID:
		errors.append("DECISION_ID_MISMATCH")
	if String(decision.get("milestone_id", "")) != MILESTONE_ID:
		errors.append("MILESTONE_ID_MISMATCH")
	if int(decision.get("decision_revision", -1)) != 1:
		errors.append("DECISION_REVISION_MISMATCH")
	if String(decision.get("status", "")) != "accepted":
		errors.append("STATUS_NOT_ACCEPTED")
	var decider_value: Variant = decision.get("decided_by")
	if (
		typeof(decider_value) != TYPE_DICTIONARY
		or String((decider_value as Dictionary).get("id", "")) != "Cole"
	):
		errors.append("DECIDER_MISMATCH")
	_append_dictionary_differences(
		errors, "AUTHORIZATION", decision.get("authorization"), EXPECTED_AUTHORIZATION
	)
	_append_dictionary_differences(
		errors, "EVIDENCE", decision.get("evidence_basis"), EXPECTED_EVIDENCE
	)
	if not _arrays_equal(decision.get("accepted_contracts"), ACCEPTED_CONTRACTS):
		errors.append("ACCEPTED_CONTRACTS_MISMATCH")
	if not _arrays_equal(decision.get("accepted_capabilities"), ACCEPTED_CAPABILITIES):
		errors.append("ACCEPTED_CAPABILITIES_MISMATCH")
	if not _arrays_equal(decision.get("supplementary_constraints"), SUPPLEMENTARY_CONSTRAINTS):
		errors.append("SUPPLEMENTARY_CONSTRAINTS_MISMATCH")
	if String(decision.get("claim_boundary", "")) != DECISION_CLAIM_BOUNDARY:
		errors.append("CLAIM_BOUNDARY_MISMATCH")
	if not _arrays_equal(decision.get("excluded_capabilities"), EXCLUDED_CAPABILITIES):
		errors.append("EXCLUDED_CAPABILITIES_WEAKENED")
	if not _arrays_equal(decision.get("downstream_open"), DOWNSTREAM_OPEN):
		errors.append("DOWNSTREAM_OPEN_MISMATCH")
	_append_dictionary_differences(
		errors, "KNOWLEDGE_EFFECTS", decision.get("knowledge_effects"), KNOWLEDGE_EFFECTS
	)
	if not _arrays_equal(decision.get("supersedes"), []):
		errors.append("SUPERSEDES_MISMATCH")
	return errors


static func _append_dictionary_differences(
	errors: Array[String], prefix: String, actual_value: Variant, expected: Dictionary
) -> void:
	if typeof(actual_value) != TYPE_DICTIONARY:
		errors.append("%s_MISSING" % prefix)
		return
	var actual: Dictionary = actual_value
	for key_value in expected.keys():
		var key := String(key_value)
		if actual.get(key) != expected[key]:
			errors.append("%s_%s_MISMATCH" % [prefix, key.to_upper()])


static func _arrays_equal(left_value: Variant, right: Array) -> bool:
	if typeof(left_value) != TYPE_ARRAY:
		return false
	var left: Array = left_value
	if left.size() != right.size():
		return false
	for index in range(right.size()):
		if left[index] != right[index]:
			return false
	return true


static func _failure(failure_code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"failure_code": failure_code,
		"message": message,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result
