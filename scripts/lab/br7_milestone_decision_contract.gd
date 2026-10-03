class_name LabBr7MilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's bounded BR7 milestone decision.
##
## BR7 owns a distinct decision family so its out-of-plane scaffold,
## aggregate-only measurements, and integrity-only BR7.4 role cannot be erased
## by a generic acceptance path. Validation is pure and writes nothing.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br7_milestone_decision.v1"
const SCHEMA_PATH := "res://data/lab/schemas/br7_milestone_decision_v1.schema.json"
const DECISION_ID := "BR7_PLANAR_MULTI_CONTACT_STANCE_DECISION_V1"
const MILESTONE_ID := "BR7_PLANAR_MULTI_CONTACT_STANCE"

const CERTIFICATION_CLAIM_BOUNDARY := (
	"This campaign can certify only the exact BR7.0 two-contact planar allocation, "
	+ "BR7.1 friction and unilateral rejection, BR7.2 support/capture segment and "
	+ "support-loss supervision, and BR7.3 live two-leg planar stance program scopes "
	+ "named by the source-pinned programs; BR7.4 is integrity-only containment and "
	+ "cannot substitute for a milestone program. The unpowered Generic6DOF "
	+ "out-of-plane guide is an explicit material scaffold: sagittal X/Y translation "
	+ "and pitch are released while out-of-plane translation, roll, and yaw remain "
	+ "locked, and all guide motors and springs remain off. Two ordinary distal "
	+ "contacts, four paired finite joint actuators, strict non-clamping allocation, "
	+ "whole-system aggregate support and pitch-wrench reconstruction, the declared "
	+ "positive pitch impulse, and the declared right-support removal retain their "
	+ "exact fixture, geometry, mass, timestep, solver, controller, and actuator "
	+ "scopes. Commanded left/right contact shares are not measured per-foot loads. "
	+ "This establishes scaffold-constrained planar height/pitch stance and "
	+ "support-loss detection only, not free 3D standing, unconstrained balance, "
	+ "per-foot measured load allocation, bracing, fall arrest, getting up, gait, "
	+ "walking, accepted knowledge, or automatic creature guidance."
)

const DECISION_CLAIM_BOUNDARY := (
	"BR7 accepts only the exact BR7.0, BR7.1, BR7.2, and BR7.3 program claim scopes "
	+ "in certification br7_20260723T134427Z_91a160b9 at source commit "
	+ "91a160b99dce9e7d9c33424c8bdde4b7bd1e3c4d. BR7.4 remains integrity-only. "
	+ "The certification report's verbatim claim boundary, all four milestone "
	+ "program scopes, the out-of-plane scaffold, and aggregate-only measurement "
	+ "boundary remain controlling."
)

const EXPECTED_AUTHORIZATION := {
	"instruction":
	(
		"continue the pipeline. i defer to your judgement on what should be "
		+ "accepted. assume i accept whatever it is that you recommend and "
		+ "keep going"
	),
	"interpretation": "delegated_bounded_acceptance_of_recommended_br7_planar_stance",
	"review_path": "docs/BR7_PLANAR_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "a09fea998eff5b33dbec324eca937d5d227208b1",
	"review_sha256": "sha256:0949060e53d66076cd240d863712218012a46dadbc6345cf79dbae43afec31cd",
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br7_certification_report_v1",
	"certification_id": "br7_20260723T134427Z_91a160b9",
	"certification_contract_id": "BR7_PLANAR_MULTI_CONTACT_STANCE",
	"campaign_id": "BR7_PLANAR_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": "sha256:83868168d51f2d0f30f98305d024571e5c6fd02809b4fbd8f2bd4af74cb26cf5",
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br7_certification_report.v1",
	"report_status": "pass",
	"report_sha256": "sha256:2cf0eed0bd1a27ff3c4f93fab384e0813834143ac4fe0dc2f67cb5b0f7d2087f",
	"report_bytes": 23941,
	"report_locator": "LabEvidence/BR7/br7_20260723T134427Z_91a160b9/br7_certification_report.json",
	"report_generated_utc": "2026-07-23T13:45:37.2742393Z",
	"receipt_schema": "sporespore.lab.br7_certification_report_attestation.v1",
	"receipt_sha256": "sha256:5e89081ca74e5bfc85205a8265a10a80469927e129bd3352e6422d9177b20257",
	"receipt_locator":
	(
		"LabTrust/v1/br7_certification_reports_v1/receipts/"
		+ "d1a14c5e72ff6046632a7b0ae283c7c92d107f59286e3bb1cc7eaf7429f88511.json"
	),
	"receipt_attested_utc": "2026-07-23T13:45:43Z",
	"receipt_key_id": "sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20",
	"source_commit_sha": "91a160b99dce9e7d9c33424c8bdde4b7bd1e3c4d",
	"source_inventory_sha256":
	"sha256:d37c28fc98caa552d6f6bf639d33ce3934403df4ca97046e4d708df1d39147a0",
	"source_file_count": 291,
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
	"assertions_required": 104,
	"assertions_passed": 104,
	"milestone_programs": 4,
	"milestone_assertions": 80,
	"supplementary_programs": 0,
	"supplementary_assertions": 0,
	"integrity_programs": 1,
	"integrity_assertions": 24,
	"target_process_invocations": 10,
	"unique_target_processes": 10,
	"pid_recycle_events": 0,
	"receipts_verified": 10,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"planar_contact_allocator_v2",
	"planar_support_segment_v1",
	"planar_support_supervisor_v1",
	"planar_stance_analysis_v1",
	"body_wrench_v1",
	"external_contact_impulse_reconstruction_v1",
	"force_to_joint_map_v1",
	"joint_actuator_v1",
]

const ACCEPTED_CAPABILITIES := [
	"The declared BR7.0 allocator exactly realizes feasible two-contact vertical force and pitch moment and rejects a pulling-contact request without clamping",
	"The declared BR7.1 allocator enforces unilateral and Coulomb-friction feasibility for two-support, single-support, and no-support requests",
	"The declared BR7.2 support segment reports static and linear-capture margins and emits one reasoned force-free fail-closed transition after support loss",
	"The declared BR7.3 two-leg fixture regulates scaffold-constrained planar height and pitch through two ordinary distal contacts and four paired finite joint actuators",
	"The declared BR7.3 fixture reconstructs aggregate support and pitch wrench, recovers the declared positive pitch impulse, and stops after the declared right-support removal becomes infeasible",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"BR7.4 is integrity-only containment and cannot substitute for BR7.0, BR7.1, BR7.2, or BR7.3",
	"The unpowered Generic6DOF guide releases sagittal X/Y translation and pitch while locking out-of-plane translation, roll, and yaw",
	"The live support result uses two ordinary distal contacts with no foot pin, built-in joint motor, joint limit, passive tissue, or controller root-rescue force",
	"Only aggregate external support and pitch wrench are reconstructed; commanded left/right shares are not measured per-foot loads",
	"The out-of-plane scaffold reaction is neither measured nor shown to be absent or negligible",
	"L1.8 still forbids summing same-body multi-shape predicted impulses into a foot-load measurement",
	"Every result remains bounded to the certified fixture, geometry, masses, impulse and support-removal schedule, timestep, solver, controller, actuator ceiling, engine, and source",
]

const EXCLUDED_CAPABILITIES := [
	"Measured per-contact, per-foot, or per-toe load allocation",
	"An absent, negligible, or measured out-of-plane scaffold reaction",
	"Free 3D standing or unconstrained balance",
	"Terrain robustness, morphology generality, complex-foot superiority, or endurance",
	"Bracing or fall arrest",
	"Self-righting or getting up",
	"Gait, candidate walking, or walking",
	"Accepted encyclopedia knowledge or automatic creature guidance",
]

const DOWNSTREAM_OPEN := [
	"Admit selected BR7.0 through BR7.3 observations only through a separate append-only operation",
	"Release and control the remaining out-of-plane translation, roll, and yaw before any free 3D standing claim",
	"Establish a validated per-contact measurement contract before any per-foot or per-toe feedback claim",
	"Establish independently certified bracing, fall-arrest, and self-righting milestones",
	"Authorize creature guidance only from separately admitted knowledge and a later explicit guidance decision",
	"Prove every future standing, recovery, gait, and walking milestone separately",
]

const KNOWLEDGE_EFFECTS := {
	"entries_admitted_by_decision": 0,
	"automatic_admission": false,
	"automatic_creature_guidance_allowed": false,
	"development_drafts_remain_non_entries": true,
}

const FAILURE_JSON_INVALID := "BR7_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR7_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR7_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "BR7 milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR7 milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantic_errors := _semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR7 milestone decision differs from Cole's bounded acceptance.",
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
