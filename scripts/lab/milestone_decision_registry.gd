class_name LabMilestoneDecisionRegistry
extends RefCounted
# gdlint: disable=max-line-length

## Append-only, fail-closed access to human milestone decisions.
##
## A machine certification proves only its own claim boundary.  This registry
## records Cole's explicit interpretation without rewriting that report.  Both
## the strict schema and every admitted decision file are byte-pinned here so a
## later edit cannot silently broaden an accepted milestone.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Br3aDecisionContractScript := preload("res://scripts/lab/br3a_milestone_decision_contract.gd")
const Br4DecisionContractScript := preload("res://scripts/lab/br4_milestone_decision_contract.gd")
const Br3bDecisionContractScript := preload("res://scripts/lab/br3b_milestone_decision_contract.gd")
const Br6aDecisionContractScript := preload("res://scripts/lab/br6a_milestone_decision_contract.gd")
const Br7DecisionContractScript := preload("res://scripts/lab/br7_milestone_decision_contract.gd")
const Br8DecisionContractScript := preload("res://scripts/lab/br8_milestone_decision_contract.gd")
const Br9DecisionContractScript := preload("res://scripts/lab/br9_milestone_decision_contract.gd")
const Br10DecisionContractScript := preload("res://scripts/lab/br10_milestone_decision_contract.gd")
const Br11DecisionContractScript := preload("res://scripts/lab/br11_milestone_decision_contract.gd")
const Br12DecisionContractScript := preload("res://scripts/lab/br12_milestone_decision_contract.gd")
const Br13DecisionContractScript := preload("res://scripts/lab/br13_milestone_decision_contract.gd")

const SCHEMA_PATH := "res://data/lab/schemas/milestone_decision_v1.schema.json"
const SCHEMA_SHA256 := "sha256:495e2f615f92c3b706b818dcb7aa7101bbcb70ce7d93f229f4077700c15ffd5d"

const BR2_1_DECISION_ID := "BR2_1_ARTICULATED_OBSERVER_DECISION_V1"
const BR2_1_MILESTONE_ID := "BR2.1_ARTICULATED_OBSERVER"
const BR2_1_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br2_1_articulated_observer_decision_v1.json"
)
const BR2_1_DECISION_SHA256 := "sha256:6cd15ef94c737741bd4119a8849ae17a8732069054c17db80da7b49fafe0a37c"

const BR3A_DECISION_ID := "BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1"
const BR3A_MILESTONE_ID := "BR3A_L1_ENGINE_CONTACT_TRUTH"
const BR3A_SCHEMA_PATH := "res://data/lab/schemas/br3a_milestone_decision_v1.schema.json"
const BR3A_SCHEMA_SHA256 := "sha256:d4ed0d71fab4a39531f1cae9d0e1ab5c41bdacddf5b7f6b78b3c473ebdee6c3a"
const BR3A_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br3a_l1_engine_contact_truth_decision_v1.json"
)
const BR3A_DECISION_SHA256 := "sha256:78b4a6daae8f7b1f981bf5feed5f54a6dcee08b991b39afe51df85327080bb6d"

const BR4_DECISION_ID := "BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1"
const BR4_MILESTONE_ID := "BR4_L2_JOINT_ACTUATOR_TRUTH"
const BR4_SCHEMA_PATH := "res://data/lab/schemas/br4_milestone_decision_v1.schema.json"
const BR4_SCHEMA_SHA256 := "sha256:0512f74ceef3bf994a301dccf7008a49dd4e48ce6156aa21c934d072a0b1fa82"
const BR4_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br4_l2_joint_actuator_truth_decision_v1.json"
)
const BR4_DECISION_SHA256 := "sha256:19dc2da4b372d3e50549eb9586b08ae796c6045897190ab4b60b8af4a72421a2"

const BR3B_DECISION_ID := "BR3B_L3_BASIC_LOADED_FOOT_TRUTH_DECISION_V1"
const BR3B_MILESTONE_ID := "BR3B_L3_BASIC_LOADED_FOOT_TRUTH"
const BR3B_SCHEMA_PATH := "res://data/lab/schemas/br3b_milestone_decision_v1.schema.json"
const BR3B_SCHEMA_SHA256 := "sha256:cddbd82f39364e048f50f2a0d607fe60ab6b69ff55298a762d0af2f13cc8f8f1"
const BR3B_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br3b_l3_basic_loaded_foot_truth_decision_v1.json"
)
const BR3B_DECISION_SHA256 := "sha256:f607c2b86599b1bc2ef085ff29819edd736ef161c8e5024916fae8b7d753ea85"

const BR6A_DECISION_ID := "BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT_DECISION_V1"
const BR6A_MILESTONE_ID := "BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT"
const BR6A_SCHEMA_PATH := "res://data/lab/schemas/br6a_milestone_decision_v1.schema.json"
const BR6A_SCHEMA_SHA256 := "sha256:9827fe76ae1330563abb23aee248ea3ba808b26bfa46cb2953c8d3bbe7f4b558"
const BR6A_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br6a_l4_vertical_rail_leg_support_decision_v1.json"
)
const BR6A_DECISION_SHA256 := "sha256:ab580fe2f146f74eaa413c8105f0852863faabae5e0139032b8854b438a3d289"

const BR7_DECISION_ID := "BR7_PLANAR_MULTI_CONTACT_STANCE_DECISION_V1"
const BR7_MILESTONE_ID := "BR7_PLANAR_MULTI_CONTACT_STANCE"
const BR7_SCHEMA_PATH := "res://data/lab/schemas/br7_milestone_decision_v1.schema.json"
const BR7_SCHEMA_SHA256 := "sha256:049a106b859ede8a939b6aebb75f9d3fd076f735e44b324b955dca76520081bf"
const BR7_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br7_planar_multi_contact_stance_decision_v1.json"
)
const BR7_DECISION_SHA256 := "sha256:ecd2528d6d766e137b6f69272054a455f047d97befd268ca2989399df3b9aa41"

const BR8_DECISION_ID := "BR8_EARLY_LOSS_OF_VIABILITY_DETECTION_DECISION_V1"
const BR8_MILESTONE_ID := "BR8_EARLY_LOSS_OF_VIABILITY_DETECTION"
const BR8_SCHEMA_PATH := "res://data/lab/schemas/br8_milestone_decision_v1.schema.json"
const BR8_SCHEMA_SHA256 := "sha256:88630b89264c8c430c249391ccdba55ccd8f42129a13a3025dabaef555aeb17c"
const BR8_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br8_early_loss_of_viability_detection_decision_v1.json"
)
const BR8_DECISION_SHA256 := "sha256:17b1aa1482fcdcda1f6c421477d6f360b2c4633b35f18a307ec29d6aa9b5bc18"

const BR9_DECISION_ID := "BR9_EXISTING_CONTACT_PLANAR_BRACE_DECISION_V1"
const BR9_MILESTONE_ID := "BR9_EXISTING_CONTACT_PLANAR_BRACE"
const BR9_SCHEMA_PATH := "res://data/lab/schemas/br9_milestone_decision_v1.schema.json"
const BR9_SCHEMA_SHA256 := "sha256:8c252cfe2d1832dd27e80a86a0d10585a390f0e88731b23cdeb2f3516a2ef21a"
const BR9_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br9_existing_contact_planar_brace_decision_v1.json"
)
const BR9_DECISION_SHA256 := "sha256:a68e903c14b70555914c0b755957dc0cfb1a53ce5c4c35f1cc9f42d0995c77e0"

const BR10_DECISION_ID := "BR10_REACHABLE_PLANAR_CATCH_DECISION_V1"
const BR10_MILESTONE_ID := "BR10_REACHABLE_PLANAR_CATCH"
const BR10_SCHEMA_PATH := "res://data/lab/schemas/br10_milestone_decision_v1.schema.json"
const BR10_SCHEMA_SHA256 := "sha256:e3bf15169c0542834f7761e44f0bf011a5a296963a49d96502b49fa4e63e924d"
const BR10_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br10_reachable_planar_catch_decision_v1.json"
)
const BR10_DECISION_SHA256 := "sha256:14610d2dbc9840c481d8f546bdeace38ade29cdc745ac4f9732da8ab6dc1708e"

const BR11_DECISION_ID := "BR11_CONTROLLED_PLANAR_FALL_DECISION_V1"
const BR11_MILESTONE_ID := "BR11_CONTROLLED_PLANAR_FALL"
const BR11_SCHEMA_PATH := "res://data/lab/schemas/br11_milestone_decision_v1.schema.json"
const BR11_SCHEMA_SHA256 := "sha256:e7fe1a89b46ea3933a44fe4e29171923306e5eded84cd42aa33b3ce6453f9903"
const BR11_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br11_controlled_planar_fall_decision_v1.json"
)
const BR11_DECISION_SHA256 := "sha256:6ece0786474a86eb031deb3f4b5cdca225489b0cd2bcbcbc346ade1eddca9455"

const BR12_DECISION_ID := "BR12_POSE_RECOVERY_FEASIBILITY_DECISION_V1"
const BR12_MILESTONE_ID := "BR12_POSE_AND_RECOVERY_FEASIBILITY"
const BR12_SCHEMA_PATH := "res://data/lab/schemas/br12_milestone_decision_v1.schema.json"
const BR12_SCHEMA_SHA256 := "sha256:c71a107f22804ee251622a14abbc590ed69a63797dbeb301da508709ef757219"
const BR12_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br12_pose_recovery_feasibility_decision_v1.json"
)
const BR12_DECISION_SHA256 := "sha256:224f0e1fed6b5016bec69e6f6628d8ca0c8473cb9ff798dcbe1430818d003463"

const BR13_DECISION_ID := "BR13_CONSTRAINED_CANONICAL_GET_UP_DECISION_V1"
const BR13_MILESTONE_ID := "BR13_CONSTRAINED_CANONICAL_GET_UP"
const BR13_SCHEMA_PATH := "res://data/lab/schemas/br13_milestone_decision_v1.schema.json"
const BR13_SCHEMA_SHA256 := "sha256:b3af6e1db2495725f140b9e3294ba67631f97dcc40a7e57ca230e8e591b9252a"
const BR13_DECISION_PATH := (
	"res://data/lab/milestone_decisions/" + "br13_constrained_canonical_get_up_decision_v1.json"
)
const BR13_DECISION_SHA256 := "sha256:524363ee5ea52bd4f81c3407dd1e5b895fb56cb6027c5ec7f8a8646ef34db95e"

const FAILURE_DECISION_UNKNOWN := "MILESTONE_DECISION_UNKNOWN"
const FAILURE_SCHEMA_MISSING := "MILESTONE_DECISION_SCHEMA_MISSING"
const FAILURE_SCHEMA_HASH_MISMATCH := "MILESTONE_DECISION_SCHEMA_HASH_MISMATCH"
const FAILURE_FILE_MISSING := "MILESTONE_DECISION_FILE_MISSING"
const FAILURE_FILE_HASH_MISMATCH := "MILESTONE_DECISION_FILE_HASH_MISMATCH"
const FAILURE_JSON_INVALID := "MILESTONE_DECISION_JSON_INVALID"
const FAILURE_SCHEMA_INVALID := "MILESTONE_DECISION_SCHEMA_INVALID"
const FAILURE_SEMANTICS_INVALID := "MILESTONE_DECISION_SEMANTICS_INVALID"

const _REGISTRY := {
	BR2_1_DECISION_ID:
	{
		"path": BR2_1_DECISION_PATH,
		"sha256": BR2_1_DECISION_SHA256,
		"schema_path": SCHEMA_PATH,
		"schema_sha256": SCHEMA_SHA256,
	},
	BR3A_DECISION_ID:
	{
		"path": BR3A_DECISION_PATH,
		"sha256": BR3A_DECISION_SHA256,
		"schema_path": BR3A_SCHEMA_PATH,
		"schema_sha256": BR3A_SCHEMA_SHA256,
	},
	BR4_DECISION_ID:
	{
		"path": BR4_DECISION_PATH,
		"sha256": BR4_DECISION_SHA256,
		"schema_path": BR4_SCHEMA_PATH,
		"schema_sha256": BR4_SCHEMA_SHA256,
	},
	BR3B_DECISION_ID:
	{
		"path": BR3B_DECISION_PATH,
		"sha256": BR3B_DECISION_SHA256,
		"schema_path": BR3B_SCHEMA_PATH,
		"schema_sha256": BR3B_SCHEMA_SHA256,
	},
	BR6A_DECISION_ID:
	{
		"path": BR6A_DECISION_PATH,
		"sha256": BR6A_DECISION_SHA256,
		"schema_path": BR6A_SCHEMA_PATH,
		"schema_sha256": BR6A_SCHEMA_SHA256,
	},
	BR7_DECISION_ID:
	{
		"path": BR7_DECISION_PATH,
		"sha256": BR7_DECISION_SHA256,
		"schema_path": BR7_SCHEMA_PATH,
		"schema_sha256": BR7_SCHEMA_SHA256,
	},
	BR8_DECISION_ID:
	{
		"path": BR8_DECISION_PATH,
		"sha256": BR8_DECISION_SHA256,
		"schema_path": BR8_SCHEMA_PATH,
		"schema_sha256": BR8_SCHEMA_SHA256,
	},
	BR9_DECISION_ID:
	{
		"path": BR9_DECISION_PATH,
		"sha256": BR9_DECISION_SHA256,
		"schema_path": BR9_SCHEMA_PATH,
		"schema_sha256": BR9_SCHEMA_SHA256,
	},
	BR10_DECISION_ID:
	{
		"path": BR10_DECISION_PATH,
		"sha256": BR10_DECISION_SHA256,
		"schema_path": BR10_SCHEMA_PATH,
		"schema_sha256": BR10_SCHEMA_SHA256,
	},
	BR11_DECISION_ID:
	{
		"path": BR11_DECISION_PATH,
		"sha256": BR11_DECISION_SHA256,
		"schema_path": BR11_SCHEMA_PATH,
		"schema_sha256": BR11_SCHEMA_SHA256,
	},
	BR12_DECISION_ID:
	{
		"path": BR12_DECISION_PATH,
		"sha256": BR12_DECISION_SHA256,
		"schema_path": BR12_SCHEMA_PATH,
		"schema_sha256": BR12_SCHEMA_SHA256,
	},
	BR13_DECISION_ID:
	{
		"path": BR13_DECISION_PATH,
		"sha256": BR13_DECISION_SHA256,
		"schema_path": BR13_SCHEMA_PATH,
		"schema_sha256": BR13_SCHEMA_SHA256,
	},
}

const _ACCEPTED_CONTRACTS := [
	"joint_binding_v2",
	"joint_state_v2",
	"joint_angle_stream_operation_v1",
	"mechanics_body_sample_v1",
	"whole_body_state_v3",
]

const _EXCLUDED_CAPABILITIES := [
	"frame_v2 sealed-stream consumer integration",
	"BR3A contact-engine truth as a complete milestone",
	"Actuator strength, torque application, or force transmission",
	"A load-bearing foot or leg",
	"Bracing or standing",
	"Fall arrest, self-righting, or getting up",
	"Gait, candidate walking, or walking",
]


static func decision_ids() -> Array[String]:
	var ids: Array[String] = []
	for id_value in _REGISTRY.keys():
		ids.append(String(id_value))
	ids.sort()
	return ids


static func load_by_id(decision_id: String) -> Dictionary:
	if not _REGISTRY.has(decision_id):
		return _failure(
			FAILURE_DECISION_UNKNOWN, "Milestone decision ID is not present in the fixed allowlist."
		)
	var entry: Dictionary = _REGISTRY[decision_id]
	var schema_hash := _verify_file_hash(
		String(entry["schema_path"]),
		String(entry["schema_sha256"]),
		FAILURE_SCHEMA_MISSING,
		FAILURE_SCHEMA_HASH_MISMATCH
	)
	if not bool(schema_hash.get("ok", false)):
		return schema_hash
	var path := String(entry["path"])
	var file_hash := _verify_file_hash(
		path, String(entry["sha256"]), FAILURE_FILE_MISSING, FAILURE_FILE_HASH_MISMATCH
	)
	if not bool(file_hash.get("ok", false)):
		return file_hash
	var loaded := _read_json_object(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var validated := validate_candidate(loaded["value"])
	if not bool(validated.get("ok", false)):
		return validated
	return {
		"ok": true,
		"failure_code": "",
		"decision_id": decision_id,
		"decision_path": path,
		"decision_sha256": String(entry["sha256"]),
		"decision": FrozenValueScript.snapshot(loaded["value"]),
	}


static func validate_candidate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "Milestone decision root must be a JSON object.")
	var decision: Dictionary = value
	if String(decision.get("schema", "")) == Br3aDecisionContractScript.SCHEMA:
		return Br3aDecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br4DecisionContractScript.SCHEMA:
		return Br4DecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br3bDecisionContractScript.SCHEMA:
		return Br3bDecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br6aDecisionContractScript.SCHEMA:
		return Br6aDecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br7DecisionContractScript.SCHEMA:
		return Br7DecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br8DecisionContractScript.SCHEMA:
		return Br8DecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br9DecisionContractScript.SCHEMA:
		return Br9DecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br10DecisionContractScript.SCHEMA:
		return Br10DecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br11DecisionContractScript.SCHEMA:
		return Br11DecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br12DecisionContractScript.SCHEMA:
		return Br12DecisionContractScript.validate_candidate(decision)
	if String(decision.get("schema", "")) == Br13DecisionContractScript.SCHEMA:
		return Br13DecisionContractScript.validate_candidate(decision)
	var schema_result := SchemaValidatorScript.validate_file(SCHEMA_PATH, decision)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FAILURE_SCHEMA_INVALID,
			"Milestone decision fails its strict owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantic_errors := _br2_semantic_errors(decision)
	if not semantic_errors.is_empty():
		return _failure(
			FAILURE_SEMANTICS_INVALID,
			"Milestone decision does not match its bounded acceptance contract.",
			{"semantic_errors": semantic_errors}
		)
	return {"ok": true, "failure_code": "", "decision": decision.duplicate(true)}


static func accepted_milestone_ids() -> Array[String]:
	var accepted: Array[String] = []
	for decision_id in decision_ids():
		var loaded := load_by_id(decision_id)
		if (
			bool(loaded.get("ok", false))
			and String(loaded["decision"].get("status", "")) == "accepted"
		):
			accepted.append(String(loaded["decision"]["milestone_id"]))
	accepted.sort()
	return accepted


static func _br2_semantic_errors(decision: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if String(decision.get("decision_id", "")) != BR2_1_DECISION_ID:
		errors.append("DECISION_ID_NOT_ALLOWLISTED")
	if String(decision.get("milestone_id", "")) != BR2_1_MILESTONE_ID:
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
	var evidence_value: Variant = decision.get("evidence_basis")
	if typeof(evidence_value) != TYPE_DICTIONARY:
		errors.append("EVIDENCE_BASIS_MISSING")
	else:
		var evidence: Dictionary = evidence_value
		var exact_evidence := {
			"certification_id": "br1_20260721T200358Z_63a593be",
			"certification_contract_id": "BR1_L0_V2_CURRENT_I62",
			"report_schema": "sporespore.lab.br1_certification_report.v2",
			"report_sha256":
			"sha256:af7551251b2a53f0cdd0b2431d262067540c70467db3e4efcd907c633f15f828",
			"report_bytes": 291137,
			"receipt_schema": "sporespore.lab.br1_certification_report_attestation.v2",
			"receipt_sha256":
			"sha256:e99b84576f676e7a5acd948dc719248a2a712f255bd79516eff692930059366c",
			"source_commit_sha": "1779accd87b8b30f3985c83a3fdb2ea536856389",
			"test_inventory_sha256":
			"sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e",
			"tests_required": 62,
			"test_artifacts_required": 124,
			"tests_passed": 62,
			"cells_passed": 7,
			"bundles_passed": 14,
			"replays_passed": 14,
			"replicate_comparisons_passed": 7,
			"final_readbacks_passed": 14,
			"production_attestation_verified": true,
		}
		for key_value in exact_evidence.keys():
			var key := String(key_value)
			if evidence.get(key) != exact_evidence[key]:
				errors.append("EVIDENCE_%s_MISMATCH" % key.to_upper())
	if not _arrays_equal(decision.get("accepted_contracts", []), _ACCEPTED_CONTRACTS):
		errors.append("ACCEPTED_CONTRACTS_MISMATCH")
	if not _arrays_equal(decision.get("excluded_capabilities", []), _EXCLUDED_CAPABILITIES):
		errors.append("EXCLUDED_CAPABILITIES_WEAKENED")
	var claim := String(decision.get("claim_boundary", ""))
	if (
		claim
		!= (
			"BR2.1 accepts only the articulated observer foundation and its "
			+ "tested availability/provenance contracts at source commit "
			+ "1779accd87b8b30f3985c83a3fdb2ea536856389."
		)
	):
		errors.append("CLAIM_BOUNDARY_MISMATCH")
	return errors


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


static func _verify_file_hash(
	path: String, expected: String, missing_code: String, mismatch_code: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(missing_code, "Required milestone-decision resource is missing.")
	var actual := "sha256:%s" % FileAccess.get_sha256(path)
	if actual != expected:
		return _failure(
			mismatch_code,
			"Milestone-decision resource bytes do not match the allowlist.",
			{"path": path, "expected_sha256": expected, "actual_sha256": actual}
		)
	return {"ok": true, "failure_code": "", "path": path, "sha256": actual}


static func _read_json_object(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(FAILURE_JSON_INVALID, "Milestone decision cannot be opened.")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure(FAILURE_JSON_INVALID, "Milestone decision is not valid JSON object data.")
	return {"ok": true, "failure_code": "", "value": parser.data}


static func _failure(failure_code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"failure_code": failure_code,
		"message": message,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result
