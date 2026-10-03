class_name LabBr10MilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's bounded BR10 milestone decision.
##
## BR10 owns a distinct decision family so its material scaffold, paired
## control, reachable-catch-only result, command-versus-measurement boundary,
## and integrity-only BR10.4 role cannot be erased by generic acceptance.
## Validation is pure and writes nothing.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br10_milestone_decision.v1"
const SCHEMA_PATH := "res://data/lab/schemas/br10_milestone_decision_v1.schema.json"
const DECISION_ID := "BR10_REACHABLE_PLANAR_CATCH_DECISION_V1"
const MILESTONE_ID := "BR10_REACHABLE_PLANAR_CATCH"

const CERTIFICATION_CLAIM_BOUNDARY := "This campaign can certify only the exact source-pinned BR10.0 deterministic reachable-catch planning scope; BR10.1 observed SEARCH-to-TOUCH-to-LOAD-to-BEARING phase-authority scope; BR10.2 strict sagittal tangent/normal J-transpose force-map scope; and BR10.3 paired active-catch and no-catch-control Godot/Jolt scope. BR10.4 is integrity-only containment and cannot substitute for a milestone program. The BR10.3 analyzer boundary is verbatim: BR10 paired reachable new-contact catch step on the exact inherited BR7 sagittal scaffold: one no-catch control and one active-catch world; one material unpowered out-of-plane guide with in-plane X/Y translation and pitch released; four passive hinges driven only through paired finite joint actuators; one ordinary left distal contact bearing at the declared disturbance while the observed right distal sphere is unloaded and clear; one preparation-only root freeze released exactly with one declared pitch impulse; one deterministic support-expanding plan selected on the first post-disturbance observation; finite swing commands to a world target; observed SEARCH to TOUCH to LOAD to BEARING authority; bounded normal-load rate and friction-reserved sagittal tangent commands mapped through an explicit J-transpose contract; full command-ledger, executor, receipt, and contact-capacity reconciliation; measured support-interval expansion; and a post-catch world-target/posture handoff that retains ordinary contacts through the complete horizon. Commanded contact-force shares are not measured per-foot loads. The positive result establishes only this scaffold-constrained planar reachable catch step and return to the declared stance dwell relative to its matched no-catch crash control. It establishes no per-foot measured load allocation, free-3D standing or bracing, general articulated load-bearing limb, generalized fall arrest, getting up, gait, walking, creature repair, or automatic creature guidance."

const DECISION_CLAIM_BOUNDARY := "BR10 accepts only the exact BR10.0, BR10.1, BR10.2, and BR10.3 program claim scopes in certification br10_20260723T181129Z_980549f8 at source commit 980549f87486ebcaaaf7b1653d4569b1665fc12c. BR10.4 remains integrity-only. The certification report's verbatim claim boundary, inherited BR7 sagittal scaffold, preparation-only root freeze and release, one initially bearing contact, one initially unloaded catch limb, first-post-disturbance plan timing, observed TOUCH-to-LOAD-to-BEARING authority, strict sagittal J-transpose command path, finite paired actuators, measured support expansion, full-horizon stance return, matched no-catch crash control, and command-not-measurement boundary remain controlling."

const EXPECTED_AUTHORIZATION := {
	"instruction":
	(
		"continue the pipeline. i defer to your judgement on what should be "
		+ "accepted. assume i accept whatever it is that you recommend and "
		+ "keep going"
	),
	"interpretation": "delegated_bounded_acceptance_of_recommended_br10_reachable_planar_catch",
	"review_path": "docs/BR10_REACHABLE_CATCH_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "7709d1b8be23e34867cd601b761cfe5b6391180e",
	"review_sha256": "sha256:be5f50735f69248392215691f3532fab2052995e0778534b22fe389e36900d09",
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br10_certification_report_v1",
	"certification_id": "br10_20260723T181129Z_980549f8",
	"certification_contract_id": "BR10_REACHABLE_PLANAR_CATCH",
	"campaign_id": "BR10_REACHABLE_CATCH_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": "sha256:4c536378c2086dba23183a2571f442a41643e89a2730bf86e5fdbd559c95abf0",
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br10_certification_report.v1",
	"report_status": "pass",
	"report_sha256": "sha256:f4e9aa4f396a25745346cc88d605d8a5a9fd688c28f945a11ffc0296649ddd5d",
	"report_bytes": 26842,
	"report_locator":
	"LabEvidence/BR10/br10_20260723T181129Z_980549f8/br10_certification_report.json",
	"report_generated_utc": "2026-07-23T18:13:12.1062716Z",
	"receipt_schema": "sporespore.lab.br10_certification_report_attestation.v1",
	"receipt_sha256": "sha256:502f700a48e297bbc5c8929e01dbd757780d8551ccafabbe09bc4eb2196ff4e3",
	"receipt_locator":
	(
		"LabTrust/v1/br10_certification_reports_v1/receipts/"
		+ "422586cba07341c75e67d0b3269127ccaa2f888dd65bee662562694350d088eb.json"
	),
	"receipt_attested_utc": "2026-07-23T18:13:20Z",
	"receipt_key_id": "sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20",
	"source_commit_sha": "980549f87486ebcaaaf7b1653d4569b1665fc12c",
	"source_inventory_sha256":
	"sha256:fc46455ae0986a4f5251c26983f9baeb141270867560f05c9ebf8e0184aeae9b",
	"source_file_count": 367,
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
	"assertions_required": 182,
	"assertions_passed": 182,
	"milestone_programs": 4,
	"milestone_assertions": 112,
	"supplementary_programs": 0,
	"supplementary_assertions": 0,
	"integrity_programs": 1,
	"integrity_assertions": 70,
	"target_process_invocations": 10,
	"unique_target_processes": 10,
	"pid_recycle_events": 0,
	"receipts_verified": 10,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"reachable_catch_step_planner_configuration_v1",
	"reachable_catch_step_request_v1",
	"catch_contact_phase_configuration_v1",
	"catch_contact_phase_observation_v1",
	"sagittal_contact_force_map_request_v1",
	"reachable_catch_step_experiment_configuration_v1",
	"reachable_catch_step_summary_v1",
]

const ACCEPTED_CAPABILITIES := [
	"The declared BR10.0 planner deterministically selects an explicitly feasible support-expanding new-contact target without inventing contact, bearing, root rescue, foot pinning, pose teleport, or automatic guidance",
	"The declared BR10.1 coordinator preserves observation-authoritative SEARCH, TOUCH, LOAD, BEARING, loss, and reacquisition without treating target arrival or a local load witness as generalized per-foot allocation",
	"The declared BR10.2 strict sagittal map transforms bounded tangent and unilateral normal commands through the certified two-link J-transpose contract while preserving zero-tangent parity with the earlier vertical-only map",
	"The declared BR10.3 active arm begins on the first post-disturbance observation, creates ordered new TOUCH, LOAD, and BEARING evidence, expands the measured support interval, and returns to the declared stance dwell through the complete horizon",
	"The declared BR10.3 active arm remains inside the certified touchdown, load-rate, friction, torque, actuator, receipt, and contact-capacity boundaries while the matched no-catch arm reaches only a late high-speed crash contact and never returns",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"BR10.4 is integrity-only containment and cannot substitute for BR10.0, BR10.1, BR10.2, or BR10.3",
	"The material unpowered Generic6DOF guide releases sagittal X/Y translation and pitch while locking out-of-plane translation, roll, and yaw",
	"One left distal contact is bearing at the declared disturbance while the observed right distal catch limb is unloaded and clear",
	"A preparation-only root freeze is released exactly with the one declared pitch impulse and is never restored",
	"The active and no-catch worlds share the certified scaffold, source, fixture, and disturbance and differ only by the declared catch path",
	"Commanded contact-force shares and the local predicted normal-load witness are not measured generalized per-foot loads",
	"The out-of-plane scaffold reaction is neither measured nor shown to be absent or negligible",
	"Every result remains bounded to the certified planner, phase coordinator, force map, actuator, fixture, guide, geometry, masses, friction, impulse, timing, target set, surface, timestep, solver, engine, and source",
]

const EXCLUDED_CAPABILITIES := [
	"Measured per-contact, per-foot, or per-toe load allocation",
	"An absent, negligible, or measured out-of-plane scaffold reaction",
	"Free 3D standing, free 3D bracing, or unconstrained balance",
	"Arbitrary articulated-limb, creature, morphology, terrain, complex-foot, or endurance generality",
	"Generalized fall arrest",
	"Self-righting or getting up",
	"Gait, candidate walking, or walking",
	"Creature repair, accepted encyclopedia knowledge, or automatic creature guidance",
]

const DOWNSTREAM_OPEN := [
	"Admit selected BR10.0 through BR10.3 observations only through a separate append-only operation",
	"Release and control remaining out-of-plane translation, roll, and yaw before any free 3D standing or bracing claim",
	"Generalize catch planning and contact establishment across morphology, terrain, candidate sets, and disturbances through new evidence",
	"Establish independently certified generalized fall-arrest and self-righting milestones",
	"Authorize creature guidance only from separately admitted knowledge and a later explicit guidance decision",
	"Prove every future gait and walking milestone separately",
]

const KNOWLEDGE_EFFECTS := {
	"entries_admitted_by_decision": 0,
	"automatic_admission": false,
	"automatic_creature_guidance_allowed": false,
	"development_drafts_remain_non_entries": true,
}

const FAILURE_JSON_INVALID := "BR10_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR10_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR10_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "BR10 milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR10 milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantic_errors := _semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR10 milestone decision differs from Cole's bounded acceptance.",
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
