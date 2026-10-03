class_name LabBr13MilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's bounded BR13 milestone decision.
##
## BR13 accepts one constrained planar get-up only. Validation is pure,
## writes nothing, admits no knowledge, and cannot broaden the certified
## fixture to free-3D recovery, morphology transfer, gait, or walking.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br13_milestone_decision.v1"
const SCHEMA_PATH := "res://data/lab/schemas/br13_milestone_decision_v1.schema.json"
const DECISION_ID := "BR13_CONSTRAINED_CANONICAL_GET_UP_DECISION_V1"
const MILESTONE_ID := "BR13_CONSTRAINED_CANONICAL_GET_UP"

const CERTIFICATION_CLAIM_BOUNDARY := "This campaign can certify only the exact source-pinned BR13.0 canonical symmetry-collapsed quadruped profile, semantic prone/transition/stance observation, and successful phase-order scope; BR13.2 static work/reserve preflight and explicit post-trace actuator, contact-dissipation, guide-work, and energy-residual accounting scope; and BR13.4 digest-bound three-seed paired active-recovery and zero-command-control live Godot/Jolt scope. BR13.1 timeout, revocation, forbidden-contact, and exclusive-handoff checks and BR13.3 adversarial profile, scaffold, contact, claim, anatomy, seed, and guidance containment are integrity-only and cannot substitute for a milestone program. The BR13.4 analyzer boundary is verbatim: BR13 paired live Godot/Jolt recovery for one exact symmetry-collapsed quadruped laboratory profile. Each active seed begins in observed semantic ventral-contact prone, establishes ordinary front-pair and rear-pair distal support, raises measured whole-system center of mass with finite paired actuation, hands exclusively from the recovery controller to the stance controller, and completes the declared stance dwell. Each seed is compared with one same-state zero-command control that remains prone. Command receipts, transition-integrated actuator work, residual-inferred contact dissipation, and the material out-of-plane guide impulse/work boundary remain explicit. The positive conclusion is exactly constrained_planar_get_up for this fixture. It establishes no free-3D recovery, morphology transfer, gait, walking, repair, or automatic creature guidance. The material sagittal guide remains part of the experiment, each front or rear rigid strut represents a mirrored limb pair rather than independent left/right limbs, raw contact observations establish no per-foot load allocation, and no result generalizes beyond the exact source-pinned profile, actuator, thresholds, seed set, physics rate, or floor fixture."

const DECISION_CLAIM_BOUNDARY := "BR13 accepts only the exact BR13.0, BR13.2, and BR13.4 milestone program claim scopes in certification br13_20260723T225845Z_897b93c2 at source commit 897b93c2c1094081dd2cf411b99f967770d8c0bc. BR13.1 and BR13.3 remain integrity-only. The certification report's verbatim claim boundary, exact symmetry-collapsed profile, material sagittal guide, seed set, matched zero-command controls, finite paired actuation, transition-integrated energy account, guide bounds, exclusive stance handoff, and stable terminal dwell remain controlling. The accepted result is exactly constrained_planar_get_up for this fixture; it is not free-3D or morphology-generalized recovery, independent four-limb control, general standing or bracing, a step, gait, or walking."

const EXPECTED_AUTHORIZATION := {
	"instruction":
	(
		"continue the pipeline. i defer to your judgement on what should be "
		+ "accepted. assume i accept whatever it is that you recommend and "
		+ "keep going"
	),
	"interpretation":
	"delegated_bounded_acceptance_of_recommended_br13_constrained_canonical_get_up",
	"review_path": "docs/BR13_CANONICAL_GET_UP_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "0ed3b6ff1f02db4362fb90bbf602f8cfa863102f",
	"review_sha256": "sha256:f4983d1b0dc055d426da8680c82f12f56558681e09abf6a7d118cfa0cae004ee",
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br13_certification_report_v1",
	"certification_id": "br13_20260723T225845Z_897b93c2",
	"certification_contract_id": MILESTONE_ID,
	"campaign_id": "BR13_CANONICAL_GET_UP_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": "sha256:e90173e3974c4b50d5d5dcde29761da60c4adbab4890ee57ea87015a892aa797",
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br13_certification_report.v1",
	"report_status": "pass",
	"report_sha256": "sha256:27e3c39fcd78337fe4f749534e0824b2ba1388dafea0bbd0dbfaf82f127f865e",
	"report_bytes": 26889,
	"report_locator":
	"LabEvidence/BR13/br13_20260723T225845Z_897b93c2/br13_certification_report.json",
	"report_generated_utc": "2026-07-23T23:01:03.3690333Z",
	"receipt_schema": "sporespore.lab.br13_certification_report_attestation.v1",
	"receipt_sha256": "sha256:21593c72a0c39edc64f20aeac3d9461836784033d483c095f1f150f49d028220",
	"receipt_locator":
	(
		"LabTrust/v1/br13_certification_reports_v1/receipts/"
		+ "0f1d3afa55b7541f934701bea8239dd4279f349854b348c15a828918f0de2482.json"
	),
	"receipt_attested_utc": "2026-07-23T23:01:12Z",
	"receipt_key_id": "sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20",
	"source_commit_sha": "897b93c2c1094081dd2cf411b99f967770d8c0bc",
	"source_inventory_sha256":
	"sha256:45c727f1732261bc8da8afd0ad42e9bbd94a5d6adab3880058f0ded1afa56683",
	"source_file_count": 444,
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
	"assertions_required": 180,
	"assertions_passed": 180,
	"milestone_programs": 3,
	"milestone_assertions": 114,
	"supplementary_programs": 0,
	"supplementary_assertions": 0,
	"integrity_programs": 2,
	"integrity_assertions": 66,
	"target_process_invocations": 10,
	"unique_target_processes": 10,
	"pid_recycle_events": 0,
	"receipts_verified": 10,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"canonical_get_up_profile_v1",
	"quadruped_recovery_pose_observation_v1",
	"recovery_phase_supervisor_v1",
	"recovery_energy_ledger_v1",
	"actuator_spec_v1",
	"canonical_planar_get_up_contract_v1",
	"canonical_planar_get_up_summary_v1",
]

const ACCEPTED_CAPABILITIES := [
	"The exact BR13.0 symmetry-collapsed quadruped profile, semantic prone/transition/stance observer, declared three-seed set, material sagittal guide, matched-control requirement, and successful phase order are accepted at their certified scope",
	"The exact BR13.2 mass-gravity-height work, torque, power, structural reserve, actuator-work, mechanical-energy, residual-inferred contact-dissipation, guide-work, and energy-residual accounting gates are accepted at their certified scope",
	"Across seeds 13001, 13002, and 13003, every exact BR13.4 active Godot/Jolt world physically raised whole-system center of mass by at least 0.35 m from semantic prone and completed the certified stable stance dwell",
	"Across the same seeds, every same-state zero-command control remained semantic prone with zero actuator commands and zero actuator work",
	"The exact finite paired hinge actuator, command ledger, actuation executor, execution receipts, guide bounds, and exclusive recovery-to-stance handoff are accepted only as components of this constrained fixture",
	"The accepted physical conclusion is exactly constrained_planar_get_up for the certified fixed morphology and material scaffold",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"BR13.1 and BR13.3 remain integrity-only and cannot substitute for BR13.0, BR13.2, or BR13.4 milestone evidence",
	"The Generic6DOFJoint3D sagittal guide remains a material scaffold even though the certified residual-inferred out-of-plane impulse and guide work stayed inside their gates",
	"Each front or rear rigid strut represents one mirrored limb pair; independent left-right four-limb control was neither executed nor inferred",
	"Ground support is limited to the certified ordinary unilateral floor-contact fixture and establishes no generalized per-foot or per-contact load allocation",
	"The certified source, exact profile, actuator specification, thresholds, seeds 13001 through 13003, 120 Hz physics rate, floor, and Godot/Jolt version remain controlling",
	"Actuator work uses transition-integrated before/after relative joint rates; contact dissipation and guide work remain residual-inferred rather than direct generalized sensors",
	"Actuator saturation is recorded and allowed inside the certified finite torque, power, rate, structure, energy, and receipt gates",
	"Stable terminal stance is accepted only as the declared dwell at the end of the exact get-up, not as general standing or locomotion",
	"No encyclopedia entry, repair rule, automatic application, or creature guidance is created by this decision",
]

const EXCLUDED_CAPABILITIES := [
	"Free-3D, unscaffolded, or morphology-generalized self-righting or recovery",
	"An absent, negligible, or generally measured out-of-plane scaffold reaction",
	"Independent left-right control of four articulated limbs",
	"Morphology, actuator, terrain, complex-foot, endurance, or physics-setting transfer",
	"Measured per-contact, per-body, per-foot, per-toe, or center-of-pressure load allocation",
	"General standing, balance, bracing, fall arrest, or recovery outside the exact terminal dwell",
	"A step, weight-transfer maneuver, gait, candidate walking, or walking",
	"Creature repair or automatic creature guidance",
	"Automatic encyclopedia admission",
]

const DOWNSTREAM_OPEN := [
	"Admit selected BR13.0, BR13.2, or BR13.4 observations only through a separate append-only operation",
	"Build BR14A spatial rank and controllability evidence for one canonical morphology without changing the accepted BR13 scaffolded result",
	"Anneal recovery and balance scaffolds to zero and prove one canonical free-3D stance, brace, catch or fall-arrest, and get-up family separately",
	"Expand to BR14B morphology and strange-rig transfer only after BR14A succeeds",
	"Build L7 load transfer and constrained step cells before attempting locomotion claims",
	"Reserve candidate_walking for the later fully free flat-floor motion and causal gates, and walking for Cole's separate visual and evidence review",
	"Authorize creature guidance only from separately admitted knowledge and a later explicit guidance decision",
]

const KNOWLEDGE_EFFECTS := {
	"entries_admitted_by_decision": 0,
	"automatic_admission": false,
	"automatic_creature_guidance_allowed": false,
	"development_drafts_remain_non_entries": true,
}

const FAILURE_JSON_INVALID := "BR13_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR13_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR13_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "BR13 milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR13 milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
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
	if not errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR13 milestone decision differs from Cole's bounded acceptance.",
			{"semantic_errors": errors}
		)
	return {"ok": true, "failure_code": "", "decision": decision.duplicate(true)}


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
