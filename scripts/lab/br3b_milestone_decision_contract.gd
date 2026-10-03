class_name LabBr3bMilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's bounded BR3B L3 milestone decision.
##
## The generic BR2.1 decision schema is deliberately BR1-shaped and already
## byte-pinned. This separate contract binds the BR3B report family without
## weakening or mutating that accepted record. Validation is pure and writes
## nothing; the append-only registry owns file admission and byte pins.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br3b_milestone_decision.v1"
const SCHEMA_PATH := "res://data/lab/schemas/br3b_milestone_decision_v1.schema.json"
const DECISION_ID := "BR3B_L3_BASIC_LOADED_FOOT_TRUTH_DECISION_V1"
const MILESTONE_ID := "BR3B_L3_BASIC_LOADED_FOOT_TRUTH"

const CERTIFICATION_CLAIM_BOUNDARY := (
	"This campaign can certify only the exact L3.0-L3.2 free unary loaded-pad "
	+ "observations named by the source-pinned programs. The force-controlled "
	+ "carriage is an explicit apply_force boundary and not a rail; centered "
	+ "normal loading, loaded shear breakaway, predicted contact-pressure edge "
	+ "migration, and rocking retain their declared fixture, load, geometry, "
	+ "material, timestep, and solver scopes. It establishes no general contact "
	+ "wrench, per-contact or per-foot load allocation, articulated load-bearing "
	+ "limb, standing, bracing, fall arrest, getting up, gait, walking, accepted "
	+ "knowledge, or automatic creature guidance."
)

const DECISION_CLAIM_BOUNDARY := (
	"BR3B accepts only the exact L3.0-L3.2 program claim scopes in certification "
	+ "br3b_20260723T103240Z_f5f54a58 at source commit "
	+ "f5f54a58abae57089b37ab39fdb8b76a2c157219. The certification report's "
	+ "verbatim claim boundary and all three program scopes remain controlling."
)

const EXPECTED_AUTHORIZATION := {
	"instruction":
	(
		"continue the pipeline. i defer to your judgement on what should be "
		+ "accepted. assume i accept whatever it is that you recommend and "
		+ "keep going"
	),
	"interpretation": "delegated_bounded_acceptance_of_recommended_br3b_l3_loaded_foot_truth",
	"review_path": "docs/BR3B_L3_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "190e806e59ed69f8ffda963c3d43a1fc886fe5f8",
	"review_sha256": "sha256:a142f7b606b2327298628c6a5809c5a869a8f0fdbb0cdb6f637337b2b395c4f6",
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br3b_certification_report_v1",
	"certification_id": "br3b_20260723T103240Z_f5f54a58",
	"certification_contract_id": "BR3B_L3_BASIC_LOADED_FOOT_TRUTH",
	"campaign_id": "BR3B_L3_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": "sha256:5409d646a33aa01a81e635c022362bb52bff5be98b98cf993acf077def3c210c",
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br3b_certification_report.v1",
	"report_status": "pass",
	"report_sha256": "sha256:b3e1a014cf041a8a6ab4569b363c161081dd078ef620323c67076463a0e80986",
	"report_bytes": 15072,
	"report_locator":
	"LabEvidence/BR3B/br3b_20260723T103240Z_f5f54a58/" + "br3b_certification_report.json",
	"report_generated_utc": "2026-07-23T10:34:53.5022256Z",
	"receipt_schema": "sporespore.lab.br3b_certification_report_attestation.v1",
	"receipt_sha256": "sha256:08cd88607fd461ef32739fc9a367d4cffca5719ef6a44aa4c01c7b7f2022447c",
	"receipt_locator":
	(
		"LabTrust/v1/br3b_certification_reports_v1/receipts/"
		+ "3b957e2f47e5855e1b36304336641ca82a4b7084fad409de4f1bec94a6c63a02.json"
	),
	"receipt_attested_utc": "2026-07-23T10:34:57Z",
	"receipt_key_id": "sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20",
	"source_commit_sha": "f5f54a58abae57089b37ab39fdb8b76a2c157219",
	"source_inventory_sha256":
	"sha256:11ddc05761ab144b05015b1b413817f849fe21990513408e15c0708a7e3a633b",
	"source_file_count": 237,
	"br1_inventory_sha256":
	"sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e",
	"br1_inventory_unchanged": true,
	"engine_version": "4.7.stable.mono.official.5b4e0cb0f",
	"engine_sha256": "sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4",
	"programs_required": 3,
	"programs_passed": 3,
	"replicates_per_program": 2,
	"bundles_required": 6,
	"bundles_passed": 6,
	"assertions_required": 86,
	"assertions_passed": 86,
	"milestone_programs": 3,
	"milestone_assertions": 86,
	"supplementary_programs": 0,
	"supplementary_assertions": 0,
	"integrity_programs": 0,
	"integrity_assertions": 0,
	"target_process_invocations": 6,
	"unique_target_processes": 6,
	"pid_recycle_events": 0,
	"receipts_verified": 6,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"external_contact_impulse_reconstruction_v1",
	"contact_pressure_observation_v1",
	"loaded_pad_normal_config_v1",
	"loaded_pad_normal_analysis_v1",
	"loaded_pad_shear_config_v1",
	"loaded_pad_shear_analysis_v1",
	"loaded_pad_rocking_config_v1",
	"loaded_pad_rocking_analysis_v1",
]

const ACCEPTED_CAPABILITIES := [
	"The declared L3.0 free unary pad reconstructs the exact centered normal-load grid while raw predicted contact load remains only a bounded single-manifold cross-check",
	"The declared L3.1 free unary pad retains reconstructed 59.6 N normal support and brackets friction-0.6 shear breakaway between 34 and 36 N inside accepted L1 truth",
	"The declared L3.2 free unary pad moves predicted contact pressure toward the analytic edge and brackets rocking between 0.21 and 0.24 m around the 0.2235 m threshold with a mirrored repeat",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"The force-controlled carriage is an explicit laboratory load boundary and not a creature body or physical guide",
	"Raw predicted contact impulses and their center of pressure are diagnostic cross-checks, not a general continuous contact wrench",
	"Every result remains bounded to the certified pad mass, geometry, material, load schedule, timestep, solver, engine, and source",
	"L1.8 still forbids summing same-body multi-shape predicted impulses into a foot-load measurement",
]

const EXCLUDED_CAPABILITIES := [
	"A general contact wrench or continuous foot-force sensor",
	"Per-contact, per-foot, or per-toe load allocation",
	"An articulated load-bearing limb, foot, or creature",
	"Support load produced by a creature body rather than a laboratory force source",
	"Terrain robustness, complex-foot superiority, or endurance",
	"Standing, bracing, or fall arrest",
	"Self-righting or getting up",
	"Gait, candidate walking, or walking",
	"Accepted encyclopedia knowledge or automatic creature guidance",
]

const DOWNSTREAM_OPEN := [
	"Build and certify BR6A as a contact-bearing articulated limb under externally reconstructed load",
	"Run the articulated parent-child mass-ratio grid with accepted joint truth",
	"Establish a validated multi-contact load-allocation method before any per-foot or per-toe claim",
	"Establish support-force control and contact-phase truth before standing or bracing",
	"Admit selected BR3B observations only through a separate append-only operation",
	"Authorize creature guidance only from separately admitted knowledge and later accepted support milestones",
	"Prove every future bracing, standing, fall-arrest, recovery, gait, and walking milestone separately",
]

const KNOWLEDGE_EFFECTS := {
	"entries_admitted_by_decision": 0,
	"automatic_admission": false,
	"automatic_creature_guidance_allowed": false,
	"development_drafts_remain_non_entries": true,
}

const FAILURE_JSON_INVALID := "BR3B_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR3B_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR3B_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "BR3B milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR3B milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantic_errors := _semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR3B milestone decision differs from Cole's bounded acceptance.",
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
