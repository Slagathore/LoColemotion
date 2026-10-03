class_name LabBr8MilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's bounded BR8 milestone decision.
##
## BR8 owns a distinct decision family so its material scaffold,
## observation-only result, and integrity-only BR8.4 role cannot be erased by
## a generic acceptance path. Validation is pure and writes nothing.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br8_milestone_decision.v1"
const SCHEMA_PATH := "res://data/lab/schemas/br8_milestone_decision_v1.schema.json"
const DECISION_ID := "BR8_EARLY_LOSS_OF_VIABILITY_DETECTION_DECISION_V1"
const MILESTONE_ID := "BR8_EARLY_LOSS_OF_VIABILITY_DETECTION"

const CERTIFICATION_CLAIM_BOUNDARY := (
	"This campaign can certify only the exact BR8.0 static-margin, support-count, "
	+ "and impact-deadline oracles; BR8.1 linear-capture margin, boundary-clock, "
	+ "mirrored-direction, and delayed REACTION_TOO_LATE oracles; BR8.2 immediate "
	+ "STAND/PRECARIOUS/BRACE escalation and hysteretic one-state-at-a-time release; "
	+ "and BR8.3 passive central-horizontal-impulse, slowly-tilting-platform, and "
	+ "disappearing-right-support program scopes named by the source-pinned programs. "
	+ "BR8.4 is integrity-only containment and cannot substitute for a milestone "
	+ "program. Every live fixture retains an explicit unpowered Generic6DOF planar "
	+ "guide: sagittal X/Y translation and pitch are released while out-of-plane "
	+ "translation, roll, and yaw remain locked, and all guide motors and springs "
	+ "remain off. Detector and supervisor outputs are observations, not force, "
	+ "torque, brace, step, foot-pin, root-rescue, creature-edit, or guidance "
	+ "commands. The declared timing thresholds, rigid-body geometry, masses, "
	+ "friction, timestep, solver, central impulse, platform rotation, support "
	+ "removal, measured transforms, measured velocities, and observed contact "
	+ "membership retain their exact fixture scopes. This establishes early "
	+ "loss-of-viability detection in the passive planar-scaffold matrix only, not "
	+ "an executed existing-contact brace, catch step, new support contact, free 3D "
	+ "standing, unconstrained balance, fall arrest, getting up, gait, walking, "
	+ "accepted knowledge, or automatic creature guidance."
)

const DECISION_CLAIM_BOUNDARY := (
	"BR8 accepts only the exact BR8.0, BR8.1, BR8.2, and BR8.3 program claim scopes "
	+ "in certification br8_20260723T144351Z_90b2c1ce at source commit "
	+ "90b2c1ce6ebefc24edf7998298ca2bbb861dc57c. BR8.4 remains integrity-only. "
	+ "The certification report's verbatim claim boundary, all four milestone "
	+ "program scopes, material planar scaffold, and observer-only boundary remain "
	+ "controlling."
)

const EXPECTED_AUTHORIZATION := {
	"instruction":
	(
		"continue the pipeline. i defer to your judgement on what should be "
		+ "accepted. assume i accept whatever it is that you recommend and "
		+ "keep going"
	),
	"interpretation": "delegated_bounded_acceptance_of_recommended_br8_brace_detection",
	"review_path": "docs/BR8_BRACE_DETECTION_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "7a8ee01fa23ec63df1545009ac6cbfad1c7933cd",
	"review_sha256": "sha256:14bfb96eaec9eea31e7b472729e337668563a17950e9411c93ceadea8453f3ef",
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br8_certification_report_v1",
	"certification_id": "br8_20260723T144351Z_90b2c1ce",
	"certification_contract_id": "BR8_EARLY_LOSS_OF_VIABILITY_DETECTION",
	"campaign_id": "BR8_BRACE_DETECTION_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": "sha256:d11ffd8116f945f2a14ec481fcc69caa072b98fd850e44ab9e2e4f5b8c701c41",
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br8_certification_report.v1",
	"report_status": "pass",
	"report_sha256": "sha256:c7b51fd857816450577afa3973e6397f48e6b4a1afe47f006fdef95f8c9754d7",
	"report_bytes": 24488,
	"report_locator": "LabEvidence/BR8/br8_20260723T144351Z_90b2c1ce/br8_certification_report.json",
	"report_generated_utc": "2026-07-23T14:45:14.4925187Z",
	"receipt_schema": "sporespore.lab.br8_certification_report_attestation.v1",
	"receipt_sha256": "sha256:5e27523e4fb26479ec3147e3f4e13badd035495e332b599e38a5ce261ec217ec",
	"receipt_locator":
	(
		"LabTrust/v1/br8_certification_reports_v1/receipts/"
		+ "486d99c81d0b771ae4347d2e01f7eeeba85866f592c19f1171b5d5def27db7b8.json"
	),
	"receipt_attested_utc": "2026-07-23T14:45:21Z",
	"receipt_key_id": "sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20",
	"source_commit_sha": "90b2c1ce6ebefc24edf7998298ca2bbb861dc57c",
	"source_inventory_sha256":
	"sha256:3f70de308c5f6134dcd3dd5c9d615602da863c5ae60f0af85489f9869a6c8c60",
	"source_file_count": 315,
	"br1_inventory_sha256":
	"sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e",
	"br1_inventory_unchanged": true,
	"engine_version": "4.7.stable.mono.official.5b4e0cb0f",
	"engine_sha256": "sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4",
	"programs_required": 5,
	"programs_passed": 5,
	"replicates_per_program": 2,
	"bundles_required": 10,
	"bundles_passed": 10,
	"assertions_required": 116,
	"assertions_passed": 116,
	"milestone_programs": 4,
	"milestone_assertions": 80,
	"supplementary_programs": 0,
	"supplementary_assertions": 0,
	"integrity_programs": 1,
	"integrity_assertions": 36,
	"target_process_invocations": 10,
	"unique_target_processes": 10,
	"pid_recycle_events": 0,
	"receipts_verified": 10,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"brace_detection_request_v1",
	"brace_detection_evidence_v1",
	"brace_transition_v1",
	"brace_detection_configuration_v1",
	"brace_detection_fixture_summary_v1",
]

const ACCEPTED_CAPABILITIES := [
	"The declared BR8.0 observer computes the exact static-margin, support-count, impact-deadline, and delayed-airborne classifications",
	"The declared BR8.1 observer computes exact linear-capture position, mirrored loss direction, boundary time, reaction-viable warning, and delayed REACTION_TOO_LATE classification",
	"The declared BR8.2 supervisor escalates immediately and releases by one state after each complete safe dwell with digest-bound transition evidence",
	"The declared BR8.3 impulse fixture enters capture-driven BRACE while static margin and reaction time remain",
	"The declared BR8.3 slow-tilt fixture enters PRECARIOUS then BRACE before measured static support exhaustion",
	"The declared BR8.3 support-removal fixture observes and classifies the changed support set on the declared removal tick",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"BR8.4 is integrity-only containment and cannot substitute for BR8.0, BR8.1, BR8.2, or BR8.3",
	"The unpowered Generic6DOF guide releases sagittal X/Y translation and pitch while locking out-of-plane translation, roll, and yaw",
	"The detector and supervisor are observation-only and execute no force, torque, brace, step, foot pin, root rescue, creature edit, or automatic guidance",
	"The central impulse, platform rotation, and right-support removal are declared fixture interventions rather than controller outputs",
	"The out-of-plane scaffold reaction is neither measured nor shown to be absent or negligible",
	"REACTION_TOO_LATE is accepted only as the declared delayed negative-control classification and not as proof of a failed physical brace",
	"Every result remains bounded to the certified thresholds, fixture, geometry, masses, friction, disturbance schedules, timestep, solver, engine, and source",
]

const EXCLUDED_CAPABILITIES := [
	"An executed existing-contact brace",
	"A catch step or new support contact",
	"An absent, negligible, or measured out-of-plane scaffold reaction",
	"Free 3D standing or unconstrained balance",
	"Terrain robustness, morphology generality, complex-foot superiority, or endurance",
	"Fall arrest",
	"Self-righting or getting up",
	"Gait, candidate walking, or walking",
	"Accepted encyclopedia knowledge or automatic creature guidance",
]

const DOWNSTREAM_OPEN := [
	"Admit selected BR8.0 through BR8.3 observations only through a separate append-only operation",
	"Build and certify BR9 existing-contact brace control through the normal command, feasibility, ledger, executor, and receipt path",
	"Build and certify BR10 catch stepping separately from BR8 detector evidence",
	"Release and control remaining out-of-plane translation, roll, and yaw before any free 3D standing claim",
	"Establish independently certified fall-arrest and self-righting milestones",
	"Authorize creature guidance only from separately admitted knowledge and a later explicit guidance decision",
	"Prove every future standing, recovery, gait, and walking milestone separately",
]

const KNOWLEDGE_EFFECTS := {
	"entries_admitted_by_decision": 0,
	"automatic_admission": false,
	"automatic_creature_guidance_allowed": false,
	"development_drafts_remain_non_entries": true,
}

const FAILURE_JSON_INVALID := "BR8_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR8_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR8_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "BR8 milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR8 milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantic_errors := _semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR8 milestone decision differs from Cole's bounded acceptance.",
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
	if actual.size() != expected.size():
		errors.append("%s_FIELD_SET_MISMATCH" % prefix)
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
