class_name LabBr11MilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's bounded BR11 milestone decision.
##
## BR11 owns a distinct decision family so its material scaffold, paired
## zero-command control, protective-fall-only result, proxy/allocation boundary,
## and integrity-only BR11.4 role cannot be erased by generic acceptance.
## Validation is pure and writes nothing.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br11_milestone_decision.v1"
const SCHEMA_PATH := "res://data/lab/schemas/br11_milestone_decision_v1.schema.json"
const DECISION_ID := "BR11_CONTROLLED_PLANAR_FALL_DECISION_V1"
const MILESTONE_ID := "BR11_CONTROLLED_PLANAR_FALL"

const CERTIFICATION_CLAIM_BOUNDARY := "This campaign can certify only the exact source-pinned BR11.0 semantic protective/core contact-role and pure finite-controller scope; BR11.1 observation-authoritative FALL_ARREST and stable-FALLEN supervisor scope; BR11.2 paired whole-system momentum, reconstructed external impulse, kinetic severity-proxy, energy-accounting, and local core-load witness scope; and BR11.3 paired active-arrest and zero-command-control Godot/Jolt scope. BR11.4 is integrity-only containment and cannot substitute for a milestone program. The BR11.3 analyzer boundary is verbatim: BR11 paired controlled fall arrest in one exact planar scaffold: the active world uses one finite paired hinge actuator to deploy one semantic protective distal contact before semantic core impact; whole-system mechanics samples retain available centroidal angular momentum; the declared pre-core kinetic-energy severity proxy, core approach speed, and local predicted core-load witness improve relative to one same-state zero-command control; impulse and mechanical-energy accounts remain explicit; and both worlds terminate in an observed stable FALLEN state. The severity proxy is not an injury model, raw predicted impulses are not per-body or per-foot load allocation, and the positive result establishes only this scaffold-constrained planar protective fall. It establishes no upright recovery, free-3D standing or bracing, generalized fall arrest, getting up, gait, walking, creature repair, or automatic creature guidance."

const DECISION_CLAIM_BOUNDARY := "BR11 accepts only the exact BR11.0, BR11.1, BR11.2, and BR11.3 program claim scopes in certification br11_20260723T195911Z_d4551f99 at source commit d4551f99ce0260ac901ca682e0237e81e38df3d8. BR11.4 remains integrity-only. The certification report's verbatim claim boundary, exact planar two-body scaffold, semantic protective/core roles, observation-authoritative supervisor, same-state zero-command control, finite paired hinge actuator, preregistered kinetic, linear-momentum, core-speed, and local-load comparisons, explicit angular-momentum, impulse, and energy channels, stable FALLEN terminal states, injury-proxy non-claim, and non-allocation boundary remain controlling."

const EXPECTED_AUTHORIZATION := {
	"instruction":
	(
		"continue the pipeline. i defer to your judgement on what should be "
		+ "accepted. assume i accept whatever it is that you recommend and "
		+ "keep going"
	),
	"interpretation": "delegated_bounded_acceptance_of_recommended_br11_controlled_planar_fall",
	"review_path": "docs/BR11_CONTROLLED_FALL_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "40b9bcf0342a971fbf56772db55f0c9bf02b0030",
	"review_sha256": "sha256:7c448adf9d529551921c7477f701c27d60a332cadb1056031874511548cd4d35",
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br11_certification_report_v1",
	"certification_id": "br11_20260723T195911Z_d4551f99",
	"certification_contract_id": "BR11_CONTROLLED_PLANAR_FALL",
	"campaign_id": "BR11_CONTROLLED_FALL_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": "sha256:e7b6e29e9410a7648c410a0284f09253da008e90172425b8a9e01192d4d00bf4",
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br11_certification_report.v1",
	"report_status": "pass",
	"report_sha256": "sha256:914c939f6721bac3d713e7cc62df2189c372ff86bd20416bdd186352d1768f88",
	"report_bytes": 26509,
	"report_locator":
	"LabEvidence/BR11/br11_20260723T195911Z_d4551f99/br11_certification_report.json",
	"report_generated_utc": "2026-07-23T20:00:35.1281841Z",
	"receipt_schema": "sporespore.lab.br11_certification_report_attestation.v1",
	"receipt_sha256": "sha256:c2ca9c82325d7b4dd7720f7b4809e5bcb77bb1785d586bf9b8b1378f673371c0",
	"receipt_locator":
	(
		"LabTrust/v1/br11_certification_reports_v1/receipts/"
		+ "e7fa407f1b273ee79221a37d21d08335a20105660c176ee741de24883258d151.json"
	),
	"receipt_attested_utc": "2026-07-23T20:00:43Z",
	"receipt_key_id": "sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20",
	"source_commit_sha": "d4551f99ce0260ac901ca682e0237e81e38df3d8",
	"source_inventory_sha256":
	"sha256:c5feea9802b9110fe35afe647b4343c600eda1568838b6c52682fc15151831d3",
	"source_file_count": 392,
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
	"assertions_required": 208,
	"assertions_passed": 208,
	"milestone_programs": 4,
	"milestone_assertions": 122,
	"supplementary_programs": 0,
	"supplementary_assertions": 0,
	"integrity_programs": 1,
	"integrity_assertions": 86,
	"target_process_invocations": 10,
	"unique_target_processes": 10,
	"pid_recycle_events": 0,
	"receipts_verified": 10,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"protective_contact_role_registry_configuration_v1",
	"protective_contact_role_observation_v1",
	"fall_arrest_controller_configuration_v1",
	"fall_arrest_controller_observation_v1",
	"fall_arrest_supervisor_configuration_v1",
	"fall_arrest_supervisor_observation_v1",
	"controlled_fall_arrest_configuration_v1",
	"controlled_fall_arrest_summary_v1",
]

const ACCEPTED_CAPABILITIES := [
	"The declared BR11.0 registry separates observed protective-distal and core-impact ground contacts while the pure controller requests finite hinge torque only in FALL_ARREST and grants no repair or guidance authority",
	"The declared BR11.1 supervisor enters FALL_ARREST only from infeasible upright recovery, imminent impact, and available protective capacity and enters FALLEN only after the complete stable-observation dwell",
	"The declared BR11.2 oracle preserves paired initial-state, whole-system kinetic, linear-momentum, angular-momentum, reconstructed-impulse, energy-accounting, core-speed, and explicitly local core-load-witness semantics",
	"The declared BR11.3 finite paired hinge creates semantic protective contact before core impact and improves the preregistered kinetic, core-speed, local-load, and linear-momentum comparisons relative to its same-state zero-command control",
	"The declared BR11.3 active and control worlds retain finite mechanics channels, complete receipts, zero hidden assistance, and observed stable FALLEN terminal states without upright recovery",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"BR11.4 is integrity-only containment and cannot substitute for BR11.0, BR11.1, BR11.2, or BR11.3",
	"The material unpowered Generic6DOF guide releases sagittal X/Y translation and pitch while locking out-of-plane translation, roll, and yaw",
	"The active and zero-command worlds share the exact certified source, scaffold, morphology, initial state, surface, timestep, solver, and actuator specification",
	"The active world applies only one finite paired hinge command path; root rescue, foot pinning, pose teleport, built-in motors, and automatic guidance remain absent",
	"Centroidal angular momentum remains available and explicit but is not required or claimed to decrease in magnitude",
	"The pre-core whole-system kinetic-energy severity proxy is a mechanics comparison and not an injury model",
	"The local predicted core-load witness is not measured per-contact, per-body, per-foot, or per-toe allocation",
	"The out-of-plane scaffold reaction is neither measured nor shown to be absent or negligible",
	"Every result remains bounded to the certified roles, controller, supervisor, analyzer, actuator, fixture, guide, geometry, masses, friction, initial state, timing, surface, timestep, solver, engine, and source",
]

const EXCLUDED_CAPABILITIES := [
	"Injury prediction or biomechanical injury tolerance",
	"Measured per-contact, per-body, per-foot, or per-toe load allocation",
	"An absent, negligible, or measured out-of-plane scaffold reaction",
	"Upright recovery",
	"Free 3D standing, free 3D bracing, or unconstrained balance",
	"Arbitrary articulated-limb, creature, morphology, terrain, complex-foot, or endurance generality",
	"Generalized, free-3D, morphology-transferred, or terrain-transferred fall arrest",
	"Self-righting or getting up",
	"Gait, candidate walking, or walking",
	"Creature repair, accepted encyclopedia knowledge, or automatic creature guidance",
]

const DOWNSTREAM_OPEN := [
	"Admit selected BR11.0 through BR11.3 observations only through a separate append-only operation",
	"Release and control remaining out-of-plane translation, roll, and yaw before any free 3D standing or bracing claim",
	"Generalize controlled protective falling across morphology, terrain, fall direction, contact roles, and disturbances through new evidence",
	"Establish independently certified free-3D fall arrest and self-righting or getting-up milestones",
	"Authorize creature guidance only from separately admitted knowledge and a later explicit guidance decision",
	"Prove every future gait and walking milestone separately",
]

const KNOWLEDGE_EFFECTS := {
	"entries_admitted_by_decision": 0,
	"automatic_admission": false,
	"automatic_creature_guidance_allowed": false,
	"development_drafts_remain_non_entries": true,
}

const FAILURE_JSON_INVALID := "BR11_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR11_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR11_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "BR11 milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR11 milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantic_errors := _semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR11 milestone decision differs from Cole's bounded acceptance.",
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
