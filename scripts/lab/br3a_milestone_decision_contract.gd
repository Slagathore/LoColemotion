class_name LabBr3aMilestoneDecisionContract
extends RefCounted
# gdlint: disable=max-line-length

## Exact semantic contract for Cole's first BR3A milestone decision.
##
## The generic BR2.1 decision schema is deliberately BR1-shaped and already
## byte-pinned. This separate contract binds the BR3A report family without
## weakening or mutating that accepted record. Validation is pure and writes
## nothing; the append-only registry owns file admission and byte pins.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const SCHEMA := "sporespore.lab.br3a_milestone_decision.v1"
const SCHEMA_PATH := (
	"res://data/lab/schemas/br3a_milestone_decision_v1.schema.json")
const DECISION_ID := "BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1"
const MILESTONE_ID := "BR3A_L1_ENGINE_CONTACT_TRUTH"

const CERTIFICATION_CLAIM_BOUNDARY := (
	"This campaign can certify only the L1.0-L1.7 contact-engine observations "
	+ "named by the exact source-pinned programs. L1.8 and the knowledge guard "
	+ "are supplementary constraints. It establishes no articulated "
	+ "load-bearing limb, standing, bracing, fall arrest, getting up, walking, "
	+ "accepted knowledge, automatic creature guidance, or per-foot allocation "
	+ "of reconstructed whole-system load.")

const DECISION_CLAIM_BOUNDARY := (
	"BR3A accepts only the exact L1.0-L1.7 program claim scopes in certification "
	+ "br3a_20260723T050201Z_109cc664 at source commit "
	+ "109cc664c3282077cd806e61e1ba756e6578e639. The certification report's "
	+ "verbatim claim boundary remains controlling; L1.8 and the knowledge guard "
	+ "remain supplementary constraints.")

const EXPECTED_AUTHORIZATION := {
	"instruction": (
		"Accept BR3A_L1_ENGINE_CONTACT_TRUTH using certification "
		+ "br3a_20260723T050201Z_109cc664, report SHA-256 "
		+ "sha256:8574122ad227084657bb8edd947b4e7c7d001af553f63cf645cb595afbd5fc6b, "
		+ "and detached receipt SHA-256 "
		+ "sha256:a355f549907eb87742a8310eb56e58c88aaf1ebd98ee68f22c05b459c3f8dd8c, "
		+ "limited to the exact L1.0-L1.7 program claim scopes and verbatim "
		+ "campaign claim boundary in the decision review; L1.8 and the "
		+ "knowledge guard remain supplementary constraints; no encyclopedia "
		+ "entry, automatic creature guidance, per-foot load allocation, "
		+ "articulated load-bearing limb, standing, bracing, fall arrest, "
		+ "getting up, gait, or walking is established."),
	"interpretation": (
		"explicit_bounded_acceptance_of_br3a_l1_engine_contact_truth"),
	"review_path": "docs/BR3A_L1_MILESTONE_DECISION_REVIEW.md",
	"review_commit_sha": "aeaa883198dc08e0fcdf85078312cd40db9d6655",
	"review_sha256": (
		"sha256:1340474e08b69f431fdef765024e65077655fdb3331aeb0eb0c61e04857f9a68"),
}

const EXPECTED_EVIDENCE := {
	"evidence_family": "br3a_certification_report_v1",
	"certification_id": "br3a_20260723T050201Z_109cc664",
	"certification_contract_id": "BR3A_L1_ENGINE_CONTACT_TRUTH",
	"campaign_id": "BR3A_L1_PROMOTION_CAMPAIGN_V1",
	"campaign_sha256": (
		"sha256:cc5f92d41be19c27317bbfcf92fe6ee38cfb9e45cb09b88ab0c7ed981c00c79c"),
	"certification_claim_boundary": CERTIFICATION_CLAIM_BOUNDARY,
	"report_schema": "sporespore.lab.br3a_certification_report.v1",
	"report_status": "pass",
	"report_sha256": (
		"sha256:8574122ad227084657bb8edd947b4e7c7d001af553f63cf645cb595afbd5fc6b"),
	"report_bytes": 70013,
	"report_locator": (
		"LabEvidence/BR3A/br3a_20260723T050201Z_109cc664/"
		+ "br3a_certification_report.json"),
	"report_generated_utc": "2026-07-23T05:13:56.8532588Z",
	"receipt_schema": (
		"sporespore.lab.br3a_certification_report_attestation.v1"),
	"receipt_sha256": (
		"sha256:a355f549907eb87742a8310eb56e58c88aaf1ebd98ee68f22c05b459c3f8dd8c"),
	"receipt_locator": (
		"LabTrust/v1/br3a_certification_reports_v1/receipts/"
		+ "2e95d6ede3847ffa4174b83faf945470ff6e220d34725feb269536de6d9486e6.json"),
	"receipt_attested_utc": "2026-07-23T05:14:14Z",
	"receipt_key_id": (
		"sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20"),
	"source_commit_sha": "109cc664c3282077cd806e61e1ba756e6578e639",
	"source_inventory_sha256": (
		"sha256:b05aa5c0cf91a44c86ab75dcbbdda32749b8eaa313f53dbc7389133c06838a5f"),
	"source_file_count": 185,
	"br1_inventory_sha256": (
		"sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e"),
	"br1_inventory_unchanged": true,
	"engine_version": "4.7.stable.mono.official.5b4e0cb0f",
	"engine_sha256": (
		"sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"),
	"programs_required": 19,
	"programs_passed": 19,
	"replicates_per_program": 2,
	"bundles_required": 38,
	"bundles_passed": 38,
	"assertions_required": 584,
	"assertions_passed": 584,
	"milestone_programs": 16,
	"milestone_assertions": 472,
	"supplementary_programs": 2,
	"supplementary_assertions": 86,
	"integrity_programs": 1,
	"integrity_assertions": 26,
	"target_process_invocations": 38,
	"unique_target_processes": 38,
	"pid_recycle_events": 0,
	"receipts_verified": 38,
	"production_attestation_verified": true,
}

const ACCEPTED_CONTRACTS := [
	"raw_contact_point_v2",
	"contact_patch_v1",
	"contact_canonicalization_v1",
	"contact_lifetime_frame_v1",
	"contact_support_state_v1",
	"support_geometry_v1",
	"contact_slip_observation_v1",
	"post_step_contact_kinematics_v1",
	"friction_breakaway_analysis_v1",
	"incline_threshold_analysis_v1",
	"tipping_threshold_analysis_v1",
	"contact_pressure_observation_v1",
	"timestep_convergence_analysis_v1",
	"solver_step_sensitivity_analysis_v1",
	"external_contact_impulse_reconstruction_v1",
	"mass_ratio_stability_analysis_v1",
]

const ACCEPTED_CAPABILITIES := [
	"Contact frames, normal and impulse signs, saturation refusal, contact lifetime, external-contact deduplication, self-contact exclusion, support geometry, and qualified support state under the declared L1.0 fixtures",
	"The declared L1.1 sled fixtures distinguish hold, breakaway, and sliding, with post-step contact-point kinematics owning actual-slip classification",
	"The declared L1.2 incline fixture brackets static retention and downhill sliding around its authored material threshold",
	"The declared L1.3 static prism distinguishes center of mass inside versus outside its analytic support edge and mirrors tip direction",
	"The declared L1.4 finite pad predicted-impulse center-of-pressure estimate tracks internal offsets inside its measured error bounds",
	"The exact L1.5 drop/contact fixture accepts its measured 60-240 Hz interval and rejects 30 Hz without establishing a universal physics rate",
	"Exact L1.6 solver cells are valid only after the required settings and world lifecycle, and closed-system momentum balance reconstructs aggregate external support separately from local contact transmission",
	"The unjointed L1.7 two-body stack has an orientation-dependent stability envelope over only its exact measured 1:1-1024:1 grid",
]

const SUPPLEMENTARY_CONSTRAINTS := [
	"L1.8 same-body multi-manifold raw predicted impulse sums are not additive external load",
	"Whole-system momentum reconstruction is authoritative only for the closed measured system and establishes no per-foot, per-toe, per-shape, or per-contact allocation",
	"The knowledge-draft guard remains containment evidence and admits no encyclopedia entry",
]

const EXCLUDED_CAPABILITIES := [
	"Exact continuous contact force",
	"Per-contact, per-foot, or per-toe allocation of reconstructed whole-system load",
	"Independent actuator semantics for collision shapes or contact manifolds",
	"Articulated parent-child mass-ratio stability",
	"A load-bearing joint, foot, limb, or creature",
	"Bracing, standing, or fall arrest",
	"Self-righting or getting up",
	"Gait, candidate walking, or walking",
	"Accepted encyclopedia knowledge or automatic creature guidance",
]

const DOWNSTREAM_OPEN := [
	"Version and promote any dynamic controller invariant with frame-level evidence when its consumer requires replay",
	"Establish BR4 L2 single-joint actuator and force-transmission truth",
	"Run the articulated parent-child mass-ratio grid only after L2 joint truth",
	"Establish a validated multi-contact load-allocation method before any per-foot or per-toe claim",
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

const FAILURE_JSON_INVALID := "BR3A_MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "BR3A_MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "BR3A_MILESTONE_DECISION_SEMANTICS_INVALID"


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(
			FAILURE_JSON_INVALID,
			"BR3A milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"BR3A milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])})
	var semantic_errors := _semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"BR3A milestone decision differs from Cole's bounded acceptance.",
			{"semantic_errors": semantic_errors})
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
	if typeof(decider_value) != TYPE_DICTIONARY \
			or String((decider_value as Dictionary).get("id", "")) != "Cole":
		errors.append("DECIDER_MISMATCH")
	_append_dictionary_differences(
		errors, "AUTHORIZATION", decision.get("authorization"), EXPECTED_AUTHORIZATION)
	_append_dictionary_differences(
		errors, "EVIDENCE", decision.get("evidence_basis"), EXPECTED_EVIDENCE)
	if not _arrays_equal(decision.get("accepted_contracts"), ACCEPTED_CONTRACTS):
		errors.append("ACCEPTED_CONTRACTS_MISMATCH")
	if not _arrays_equal(
			decision.get("accepted_capabilities"), ACCEPTED_CAPABILITIES):
		errors.append("ACCEPTED_CAPABILITIES_MISMATCH")
	if not _arrays_equal(
			decision.get("supplementary_constraints"), SUPPLEMENTARY_CONSTRAINTS):
		errors.append("SUPPLEMENTARY_CONSTRAINTS_MISMATCH")
	if String(decision.get("claim_boundary", "")) != DECISION_CLAIM_BOUNDARY:
		errors.append("CLAIM_BOUNDARY_MISMATCH")
	if not _arrays_equal(
			decision.get("excluded_capabilities"), EXCLUDED_CAPABILITIES):
		errors.append("EXCLUDED_CAPABILITIES_WEAKENED")
	if not _arrays_equal(decision.get("downstream_open"), DOWNSTREAM_OPEN):
		errors.append("DOWNSTREAM_OPEN_MISMATCH")
	_append_dictionary_differences(
		errors, "KNOWLEDGE_EFFECTS", decision.get("knowledge_effects"), KNOWLEDGE_EFFECTS)
	if not _arrays_equal(decision.get("supersedes"), []):
		errors.append("SUPERSEDES_MISMATCH")
	return errors


static func _append_dictionary_differences(
		errors: Array[String],
		prefix: String,
		actual_value: Variant,
		expected: Dictionary) -> void:
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


static func _failure(
		failure_code: String,
		message: String,
		extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"failure_code": failure_code,
		"message": message,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result
