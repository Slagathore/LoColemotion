class_name LabBr3aKnowledgeBase
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Certification-backed admission and verification for accepted BR3A
## observations. This evidence family is intentionally separate from the BR1
## summary-bundle knowledge contract. It preserves the accepted milestone's
## historical source identity while independently rechecking every cited
## capsule's current production receipt and artifact checksums.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const MilestoneDecisionRegistryScript := preload("res://scripts/lab/milestone_decision_registry.gd")
const PublicationAttestationScript := preload("res://scripts/lab/publication_attestation.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const ENTRY_SCHEMA := "sporespore.lab.br3a_knowledge_entry.v1"
const ENTRY_SCHEMA_PATH := "res://data/lab/schemas/br3a_knowledge_entry_v1.schema.json"
const ENTRY_SCHEMA_SHA256 := "sha256:6e720e8cebe94e73cf89bf62baef2d2e8a4c7725f793e9df7a9578768e295faf"
const MANIFEST_SCHEMA_PATH := (
	"res://data/lab/schemas/" + "br3a_knowledge_admission_manifest_v1.schema.json"
)
const MANIFEST_SCHEMA_SHA256 := "sha256:04543282558b0b3ad84866cf3d6971ef08131a22c88948cf6ad7abdc77010d9d"
const MANIFEST_PATH := (
	"res://data/lab/knowledge/admission_manifests/" + "BR3A_L1_knowledge_admission_v1.json"
)
const MANIFEST_SHA256 := "sha256:4e23b8f514e2f6e815bb64f1e70ffc0d790fe6c447c073f8d6ec75447a0feed9"
const DRAFT_SCHEMA_PATH := "res://data/lab/schemas/br3a_development_observation_v1.schema.json"
const REPORT_SCHEMA_PATH := "res://data/lab/schemas/br3a_certification_report_v1.schema.json"
const REPORT_RECEIPT_SCHEMA_PATH := (
	"res://data/lab/schemas/" + "br3a_certification_report_attestation_v1.schema.json"
)
const DECISION_ID := "BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1"
const DECISION_SHA256 := "sha256:78b4a6daae8f7b1f981bf5feed5f54a6dcee08b991b39afe51df85327080bb6d"
const MANIFEST_ID := "BR3A_L1_KNOWLEDGE_ADMISSION_V1"
const ADMISSION_POLICY := "br3a-knowledge-admission-v1"
const ENTRY_DIRECTORY := "res://data/lab/knowledge/entries/"
const AUTHORIZATION_BASIS := "standing_authority_to_accept_recommended_evidence_backed_knowledge"
const AUTHORING_FIELDS: Array[String] = [
	"title",
	"claim",
	"scope",
	"mechanism",
	"applicability",
	"failure_boundaries",
	"morphology_tags",
	"parameter_effects",
	"unknowns",
	"supersedes",
]
const FORBIDDEN_PROGRAM_IDS: Array[String] = [
	"BR3A_KNOWLEDGE_DRAFT_GUARD_V1",
	"BR3A_COMMISSIONING_REGISTRY_INTEGRITY_V1",
]


static func propose_all(recorded_utc := "") -> Dictionary:
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var manifest: Dictionary = manifest_result["manifest"]
	var program_ids: Array[String] = []
	for spec_value in manifest["entries"]:
		var spec: Dictionary = spec_value
		for program_id_value in spec["program_ids"]:
			var program_id := String(program_id_value)
			if program_id not in program_ids:
				program_ids.append(program_id)
	var certification := _inspect_certification(program_ids)
	if not bool(certification.get("ok", false)):
		return certification
	var timestamp := String(recorded_utc).strip_edges()
	if timestamp.is_empty():
		timestamp = _utc_now()
	var entries: Array = []
	for spec_value in manifest["entries"]:
		var proposal := _propose_from_inspection(spec_value, timestamp, manifest, certification)
		if not bool(proposal.get("ok", false)):
			return proposal
		entries.append(proposal["entry"])
	return {
		"ok": true,
		"entries": FrozenValueScript.snapshot(entries),
		"manifest": FrozenValueScript.snapshot(manifest),
		"certification": FrozenValueScript.snapshot(certification["summary"]),
	}


static func propose_entry(entry_id: String, recorded_utc := "") -> Dictionary:
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var manifest: Dictionary = manifest_result["manifest"]
	var matched: Dictionary = {}
	for spec_value in manifest["entries"]:
		var spec: Dictionary = spec_value
		if String(spec["entry_id"]) == entry_id:
			matched = spec
			break
	if matched.is_empty():
		return _failure(
			"BR3A_KNOWLEDGE_ENTRY_UNKNOWN",
			"Entry ID is not authorized by the fixed admission manifest."
		)
	var ids: Array[String] = []
	for value in matched["program_ids"]:
		ids.append(String(value))
	var certification := _inspect_certification(ids)
	if not bool(certification.get("ok", false)):
		return certification
	var timestamp := String(recorded_utc).strip_edges()
	if timestamp.is_empty():
		timestamp = _utc_now()
	return _propose_from_inspection(matched, timestamp, manifest, certification)


static func verify_entry(entry: Dictionary) -> Dictionary:
	var infrastructure := _verify_owned_resources()
	if not bool(infrastructure.get("ok", false)):
		return infrastructure
	var schema_result := SchemaValidatorScript.validate_file(ENTRY_SCHEMA_PATH, entry)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_ENTRY_SCHEMA_INVALID",
			"Entry failed the strict BR3A knowledge schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var admission: Dictionary = entry["admission"]
	if (
		String(admission["policy"]) != ADMISSION_POLICY
		or String(admission["manifest_id"]) != MANIFEST_ID
		or String(admission["manifest_sha256"]) != MANIFEST_SHA256
		or String(admission["authorized_by"]) != "Cole"
		or String(admission["authorization_basis"]) != AUTHORIZATION_BASIS
	):
		return _failure(
			"BR3A_KNOWLEDGE_ADMISSION_IDENTITY_INVALID",
			"Entry admission identity does not match the authorized manifest."
		)
	var observed_payload_sha := _entry_payload_sha256(entry)
	if String(admission["payload_sha256"]) != observed_payload_sha:
		return _failure(
			"BR3A_KNOWLEDGE_ADMISSION_DIGEST_MISMATCH",
			"Entry content changed after admission.",
			{
				"recorded": admission["payload_sha256"],
				"observed": observed_payload_sha,
			}
		)
	var reproposal := propose_entry(String(entry["entry_id"]), String(entry["recorded_utc"]))
	if not bool(reproposal.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_PROVENANCE_INVALID",
			"Entry evidence can no longer be reproduced from the accepted trust chain.",
			{"inspection": reproposal}
		)
	if (
		CanonicalJsonScript.stringify(_entry_payload(entry))
		!= CanonicalJsonScript.stringify(_entry_payload(reproposal["entry"]))
	):
		return _failure(
			"BR3A_KNOWLEDGE_PROVENANCE_MISMATCH",
			"Entry does not equal the claim and evidence authorized by the manifest."
		)
	if String(entry["entry_id"]) in entry["supersedes"]:
		return _failure(
			"KNOWLEDGE_SELF_SUPERSESSION", "A BR3A knowledge entry cannot supersede itself."
		)
	return {
		"ok": true,
		"entry": FrozenValueScript.snapshot(entry),
		"evidence_program_count": (entry["evidence"]["programs"] as Array).size(),
	}


static func write_new_entry(path: String, entry: Dictionary) -> Dictionary:
	var absolute := _normalized_absolute(path)
	var entry_root := _normalized_absolute(ENTRY_DIRECTORY)
	if (
		not absolute.to_lower().ends_with(".json")
		or absolute.get_base_dir().to_lower() != entry_root.to_lower()
	):
		return _failure(
			"BR3A_KNOWLEDGE_ENTRY_PATH_INVALID",
			"Entries must be direct JSON children of the accepted knowledge directory."
		)
	if _path_entry_exists(absolute):
		return _failure(
			"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
			"Knowledge entries are append-only; an existing path cannot be replaced."
		)
	var verification := verify_entry(entry)
	if not bool(verification.get("ok", false)):
		return verification
	var make_result := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if make_result != OK and make_result != ERR_ALREADY_EXISTS:
		return _failure("KNOWLEDGE_DIRECTORY_CREATE_FAILED", error_string(make_result))
	var reservation := "%s.admission-lock" % absolute
	var reservation_error := DirAccess.make_dir_absolute(reservation)
	if reservation_error != OK:
		return _failure(
			"KNOWLEDGE_ENTRY_LOCKED",
			"Another admission owns this output path or left an unresolved lock."
		)
	if _path_entry_exists(absolute):
		DirAccess.remove_absolute(reservation)
		return _failure(
			"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
			"Knowledge entries are append-only; an existing path won the race."
		)
	var temporary := reservation.path_join(
		"entry-%d-%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	var serialized := CanonicalJsonScript.stringify(entry) + "\n"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(reservation)
		return _failure(
			"KNOWLEDGE_TEMP_OPEN_FAILED", "Could not open the BR3A entry temporary file."
		)
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure("KNOWLEDGE_WRITE_FAILED", error_string(write_error))
	if _path_entry_exists(absolute):
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure(
			"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
			"Knowledge entries are append-only; an existing path won the race."
		)
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure("KNOWLEDGE_RENAME_FAILED", error_string(rename_error))
	var installed_matches := FileAccess.get_file_as_string(absolute) == serialized
	DirAccess.remove_absolute(reservation)
	if not installed_matches:
		return _failure(
			"KNOWLEDGE_INSTALL_INTEGRITY_FAILED",
			"Installed entry bytes differ from the admitted canonical payload."
		)
	return {
		"ok": true,
		"path": absolute,
		"sha256": _sha256_file(absolute),
	}


static func inspect_installed() -> Dictionary:
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var entries: Array = []
	var errors: Array = []
	for spec_value in manifest_result["manifest"]["entries"]:
		var spec: Dictionary = spec_value
		var path := ENTRY_DIRECTORY.path_join(String(spec["output_name"]))
		if not FileAccess.file_exists(path):
			(
				errors
				. append(
					{
						"entry_id": spec["entry_id"],
						"code": "BR3A_KNOWLEDGE_ENTRY_MISSING",
						"path": path,
					}
				)
			)
			continue
		var parsed := _read_json_object(path)
		if not bool(parsed.get("ok", false)):
			(
				errors
				. append(
					{
						"entry_id": spec["entry_id"],
						"code": "BR3A_KNOWLEDGE_ENTRY_JSON_INVALID",
						"path": path,
					}
				)
			)
			continue
		var verification := verify_entry(parsed["value"])
		if not bool(verification.get("ok", false)):
			(
				errors
				. append(
					{
						"entry_id": spec["entry_id"],
						"code": "BR3A_KNOWLEDGE_ENTRY_UNTRUSTED",
						"path": path,
						"details": verification,
					}
				)
			)
			continue
		entries.append(verification["entry"])
	return {
		"ok": errors.is_empty(),
		"entries": FrozenValueScript.snapshot(entries),
		"errors": errors,
		"expected_entry_count": 9,
		"installed_entry_count": entries.size(),
		"automatic_creature_guidance_allowed": false,
	}


static func output_plan() -> Dictionary:
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var outputs: Array = []
	for spec_value in manifest_result["manifest"]["entries"]:
		var spec: Dictionary = spec_value
		(
			outputs
			. append(
				{
					"entry_id": spec["entry_id"],
					"path": ENTRY_DIRECTORY.path_join(String(spec["output_name"])),
				}
			)
		)
	return {"ok": true, "outputs": outputs}


static func _propose_from_inspection(
	spec: Dictionary, recorded_utc: String, manifest: Dictionary, certification: Dictionary
) -> Dictionary:
	var authoring_result := _load_authoring(spec)
	if not bool(authoring_result.get("ok", false)):
		return authoring_result
	var authoring: Dictionary = authoring_result["authoring"]
	var programs: Array = []
	for program_id_value in spec["program_ids"]:
		var program_id := String(program_id_value)
		if not certification["programs"].has(program_id):
			return _failure(
				"BR3A_KNOWLEDGE_PROGRAM_MISSING",
				"Authorized program is absent from the inspected certification.",
				{"program_id": program_id}
			)
		programs.append(certification["programs"][program_id])
	var entry := {
		"schema": ENTRY_SCHEMA,
		"entry_id": String(spec["entry_id"]),
		"cell_id": String(spec["cell_id"]),
		"knowledge_class": String(spec["knowledge_class"]),
		"title": String(authoring["title"]),
		"claim": String(authoring["claim"]),
		"claim_status": "accepted",
		"scope": String(authoring["scope"]),
		"mechanism": String(authoring["mechanism"]),
		"applicability": authoring["applicability"],
		"failure_boundaries": authoring["failure_boundaries"],
		"morphology_tags": authoring["morphology_tags"],
		"parameter_effects": authoring["parameter_effects"],
		"minimal_repair_rules": [],
		"unknowns": authoring["unknowns"],
		"evidence":
		{
			"family": "br3a_certification_program_set_v1",
			"decision_id": DECISION_ID,
			"decision_sha256": DECISION_SHA256,
			"certification_id": certification["summary"]["certification_id"],
			"report_sha256": certification["summary"]["report_sha256"],
			"report_bytes": certification["summary"]["report_bytes"],
			"report_receipt_sha256": certification["summary"]["report_receipt_sha256"],
			"source_commit_sha": certification["summary"]["source_commit_sha"],
			"campaign_sha256": certification["summary"]["campaign_sha256"],
			"certification_claim_boundary":
			certification["summary"]["certification_claim_boundary"],
			"programs": programs,
		},
		"guidance_policy": manifest["guidance_policy"],
		"authoring_source": authoring_result["source"],
		"supersedes": authoring["supersedes"],
		"recorded_utc": recorded_utc,
	}
	entry["admission"] = {
		"policy": ADMISSION_POLICY,
		"manifest_id": MANIFEST_ID,
		"manifest_sha256": MANIFEST_SHA256,
		"authorized_by": "Cole",
		"authorization_basis": AUTHORIZATION_BASIS,
		"payload_sha256": _entry_payload_sha256(entry),
	}
	var schema_result := SchemaValidatorScript.validate_file(ENTRY_SCHEMA_PATH, entry)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_ENTRY_SCHEMA_INVALID",
			"Generated entry failed the owned BR3A knowledge schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	return {
		"ok": true,
		"entry": FrozenValueScript.snapshot(entry),
	}


static func _load_authoring(spec: Dictionary) -> Dictionary:
	var source: Dictionary = spec["authoring"]
	if String(source["kind"]) == "inline":
		var authoring: Dictionary = {}
		for field in AUTHORING_FIELDS:
			authoring[field] = source[field]
		return {
			"ok": true,
			"authoring": authoring,
			"source":
			{
				"kind": "admission_manifest_inline",
				"path": MANIFEST_PATH,
				"sha256": MANIFEST_SHA256,
			},
		}
	var path := String(source["path"])
	var expected_sha := String(source["sha256"])
	var hash_result := _verify_file_hash(
		path, expected_sha, "BR3A_KNOWLEDGE_DRAFT_MISSING", "BR3A_KNOWLEDGE_DRAFT_HASH_MISMATCH"
	)
	if not bool(hash_result.get("ok", false)):
		return hash_result
	var parsed := _read_json_object(path)
	if not bool(parsed.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_DRAFT_JSON_INVALID", "Pinned development draft is not one JSON object."
		)
	var schema_result := SchemaValidatorScript.validate_file(DRAFT_SCHEMA_PATH, parsed["value"])
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_DRAFT_SCHEMA_INVALID",
			"Pinned development draft failed its owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var draft: Dictionary = parsed["value"]
	if String(draft["cell_id"]) != String(spec["cell_id"]):
		return _failure(
			"BR3A_KNOWLEDGE_DRAFT_CELL_MISMATCH",
			"Pinned development draft does not describe the authorized cell."
		)
	var authoring: Dictionary = {}
	for field in AUTHORING_FIELDS:
		authoring[field] = draft[field]
	return {
		"ok": true,
		"authoring": authoring,
		"source":
		{
			"kind": "pinned_development_draft",
			"path": path,
			"sha256": expected_sha,
		},
	}


static func _inspect_certification(requested_program_ids: Array[String]) -> Dictionary:
	var decision_result := MilestoneDecisionRegistryScript.load_by_id(DECISION_ID)
	if not bool(decision_result.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_DECISION_INVALID",
			"Accepted BR3A decision is unavailable or invalid.",
			{"decision": decision_result}
		)
	if String(decision_result["decision_sha256"]) != DECISION_SHA256:
		return _failure(
			"BR3A_KNOWLEDGE_DECISION_HASH_MISMATCH",
			"Accepted BR3A decision bytes do not match the admission contract."
		)
	var decision: Dictionary = decision_result["decision"]
	if String(decision["status"]) != "accepted":
		return _failure(
			"BR3A_KNOWLEDGE_DECISION_NOT_ACCEPTED",
			"BR3A knowledge requires an accepted milestone decision."
		)
	var basis: Dictionary = decision["evidence_basis"]
	var report_path_result := _resolve_local_locator(String(basis["report_locator"]))
	var receipt_path_result := _resolve_local_locator(String(basis["receipt_locator"]))
	if (
		not bool(report_path_result.get("ok", false))
		or not bool(receipt_path_result.get("ok", false))
	):
		return _failure(
			"BR3A_KNOWLEDGE_EVIDENCE_PATH_INVALID",
			"Decision evidence locators cannot be resolved below the fixed local store."
		)
	var report_path := String(report_path_result["path"])
	var receipt_path := String(receipt_path_result["path"])
	var report_hash := _verify_file_hash(
		report_path,
		String(basis["report_sha256"]),
		"BR3A_KNOWLEDGE_REPORT_MISSING",
		"BR3A_KNOWLEDGE_REPORT_HASH_MISMATCH"
	)
	if not bool(report_hash.get("ok", false)):
		return report_hash
	if _file_size(report_path) != int(basis["report_bytes"]):
		return _failure(
			"BR3A_KNOWLEDGE_REPORT_SIZE_MISMATCH",
			"Certification report byte count differs from the accepted decision."
		)
	var receipt_hash := _verify_file_hash(
		receipt_path,
		String(basis["receipt_sha256"]),
		"BR3A_KNOWLEDGE_REPORT_RECEIPT_MISSING",
		"BR3A_KNOWLEDGE_REPORT_RECEIPT_HASH_MISMATCH"
	)
	if not bool(receipt_hash.get("ok", false)):
		return receipt_hash
	var report_result := _read_json_object(report_path)
	var receipt_result := _read_json_object(receipt_path)
	if not bool(report_result.get("ok", false)) or not bool(receipt_result.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_CERTIFICATION_JSON_INVALID",
			"Certification report or detached receipt is not one JSON object."
		)
	var report: Dictionary = report_result["value"]
	var report_schema := SchemaValidatorScript.validate_file(REPORT_SCHEMA_PATH, report)
	var receipt_schema := SchemaValidatorScript.validate_file(
		REPORT_RECEIPT_SCHEMA_PATH, receipt_result["value"]
	)
	if not bool(report_schema.get("ok", false)) or not bool(receipt_schema.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_CERTIFICATION_SCHEMA_INVALID",
			"Certification report or receipt failed its owned schema.",
			{
				"report_errors": report_schema.get("errors", []),
				"receipt_errors": receipt_schema.get("errors", []),
			}
		)
	var identity := _verify_report_identity(report, basis)
	if not bool(identity.get("ok", false)):
		return identity
	var report_programs: Dictionary = {}
	for program_value in report["programs"]:
		var program: Dictionary = program_value
		var program_id := String(program["program_id"])
		if report_programs.has(program_id):
			return _failure(
				"BR3A_KNOWLEDGE_PROGRAM_DUPLICATE",
				"Certification report contains a duplicate program ID.",
				{"program_id": program_id}
			)
		report_programs[program_id] = program
	var admitted_programs: Dictionary = {}
	for program_id in requested_program_ids:
		if program_id in FORBIDDEN_PROGRAM_IDS:
			return _failure(
				"BR3A_KNOWLEDGE_PROGRAM_FORBIDDEN",
				"Integrity or containment programs cannot become knowledge entries.",
				{"program_id": program_id}
			)
		if not report_programs.has(program_id):
			return _failure(
				"BR3A_KNOWLEDGE_PROGRAM_MISSING",
				"Authorized program is absent from the exact certification report.",
				{"program_id": program_id}
			)
		var program_result := _inspect_program(report_programs[program_id])
		if not bool(program_result.get("ok", false)):
			return program_result
		admitted_programs[program_id] = program_result["program"]
	return {
		"ok": true,
		"summary":
		{
			"certification_id": basis["certification_id"],
			"report_sha256": basis["report_sha256"],
			"report_bytes": basis["report_bytes"],
			"report_receipt_sha256": basis["receipt_sha256"],
			"source_commit_sha": basis["source_commit_sha"],
			"campaign_sha256": basis["campaign_sha256"],
			"certification_claim_boundary": basis["certification_claim_boundary"],
		},
		"programs": admitted_programs,
	}


static func _verify_report_identity(report: Dictionary, basis: Dictionary) -> Dictionary:
	var source: Dictionary = report["source"]
	var exact := {
		"schema": "sporespore.lab.br3a_certification_report.v1",
		"status": "pass",
		"certification": "BR3A_L1_ENGINE_CONTACT_TRUTH",
		"certification_id": basis["certification_id"],
		"milestone_id": "BR3A_L1_ENGINE_CONTACT_TRUTH",
		"claim_boundary": basis["certification_claim_boundary"],
	}
	for field in exact:
		if report.get(field) != exact[field]:
			return _failure(
				"BR3A_KNOWLEDGE_REPORT_IDENTITY_MISMATCH",
				"Certification report contradicts the accepted decision field.",
				{"field": field}
			)
	if (
		String(source["commit_sha"]) != String(basis["source_commit_sha"])
		or String(source["campaign_sha256"]) != String(basis["campaign_sha256"])
		or String(source["source_inventory_sha256"]) != String(basis["source_inventory_sha256"])
		or int(source["source_file_count"]) != int(basis["source_file_count"])
		or String(source["br1_inventory_sha256"]) != String(basis["br1_inventory_sha256"])
	):
		return _failure(
			"BR3A_KNOWLEDGE_REPORT_SOURCE_MISMATCH",
			"Certification report source identity contradicts the accepted decision."
		)
	var instrumentation: Dictionary = report["instrumentation_constraints"]
	if (
		bool(instrumentation["raw_multi_manifold_sum_is_external_load"])
		or bool(instrumentation["per_foot_allocation_established"])
		or String(instrumentation["l1_8_role"]) != "supplementary_instrumentation_constraint"
	):
		return _failure(
			"BR3A_KNOWLEDGE_INSTRUMENTATION_BOUNDARY_WEAKENED",
			"Certification report no longer preserves the L1.8 load boundary."
		)
	return {"ok": true}


static func _inspect_program(program: Dictionary) -> Dictionary:
	var program_id := String(program["program_id"])
	var cell_id := String(program["cell_id"])
	var role := String(program["evidence_role"])
	if (
		(role == "milestone" and not cell_id.begins_with("L1."))
		or (role == "milestone" and cell_id == "L1.8")
		or (role == "supplementary" and cell_id != "L1.8")
	):
		return _failure(
			"BR3A_KNOWLEDGE_PROGRAM_CLASS_INVALID",
			"Program role and cell do not match the admission boundary.",
			{"program_id": program_id, "cell_id": cell_id, "role": role}
		)
	var reconciliation: Dictionary = program["reconciliation"]
	for field in [
		"pass",
		"source_identity_match",
		"assertion_count_match",
		"ordered_assertion_labels_match",
		"both_raw_transcripts_retained",
	]:
		if not bool(reconciliation[field]):
			return _failure(
				"BR3A_KNOWLEDGE_REPLICATE_RECONCILIATION_FAILED",
				"Program replicate reconciliation is not complete.",
				{"program_id": program_id, "field": field}
			)
	var replicates: Array = program["replicates"]
	if replicates.size() != 2:
		return _failure(
			"BR3A_KNOWLEDGE_REPLICATE_COUNT_INVALID",
			"Every admitted program requires exactly two certified replicates."
		)
	var compact_replicates: Array = []
	for index in range(2):
		var replicate: Dictionary = replicates[index]
		if int(replicate["replicate"]) != index + 1:
			return _failure(
				"BR3A_KNOWLEDGE_REPLICATE_INDEX_INVALID",
				"Replicate order is not the certified r1/r2 sequence."
			)
		var attestation := PublicationAttestationScript.verify_production(
			String(replicate["bundle_path"])
		)
		if not bool(attestation.get("ok", false)):
			return _failure(
				"BR3A_KNOWLEDGE_CAPSULE_ATTESTATION_INVALID",
				"A cited capsule fails its production receipt or artifact checksums.",
				{
					"program_id": program_id,
					"replicate": index + 1,
					"attestation": attestation,
				}
			)
		var recorded_attestation: Dictionary = replicate["attestation"]
		if (
			String(attestation["trust_mode"]) != "production"
			or String(attestation["run_id"]) != String(replicate["bundle_id"])
			or String(attestation["manifest_sha256"]) != String(replicate["manifest_sha256"])
			or String(attestation["checksums_sha256"]) != String(replicate["checksums_sha256"])
			or int(attestation["artifact_count"]) != 7
			or not bool(recorded_attestation["valid"])
			or String(attestation["key_id"]) != String(recorded_attestation["key_id"])
			or (
				String(attestation["receipt_sha256"])
				!= String(recorded_attestation["receipt_sha256"])
			)
			or (
				_path_identity(String(attestation["receipt_path"]))
				!= _path_identity(String(recorded_attestation["receipt_path"]))
			)
		):
			return _failure(
				"BR3A_KNOWLEDGE_CAPSULE_WITNESS_MISMATCH",
				"Live capsule receipt contradicts the certification report.",
				{"program_id": program_id, "replicate": index + 1}
			)
		(
			compact_replicates
			. append(
				{
					"replicate": index + 1,
					"bundle_id": replicate["bundle_id"],
					"bundle_path": replicate["bundle_path"],
					"manifest_sha256": replicate["manifest_sha256"],
					"checksums_sha256": replicate["checksums_sha256"],
					"capsule_sha256": replicate["capsule_sha256"],
					"metrics_sha256": replicate["metrics_sha256"],
					"source_inventory_sha256": replicate["source_inventory_sha256"],
					"transcript_sha256": replicate["transcript_sha256"],
					"attestation":
					{
						"algorithm": attestation["algorithm"],
						"trust_mode": attestation["trust_mode"],
						"key_id": attestation["key_id"],
						"receipt_path": attestation["receipt_path"],
						"receipt_sha256": attestation["receipt_sha256"],
						"artifact_count": attestation["artifact_count"],
						"attested_utc": attestation["attested_utc"],
					},
				}
			)
		)
	return {
		"ok": true,
		"program":
		{
			"program_id": program_id,
			"cell_id": cell_id,
			"evidence_role": role,
			"claim_scope": program["claim_scope"],
			"replicates": compact_replicates,
		},
	}


static func _load_manifest() -> Dictionary:
	var infrastructure := _verify_owned_resources()
	if not bool(infrastructure.get("ok", false)):
		return infrastructure
	var parsed := _read_json_object(MANIFEST_PATH)
	if not bool(parsed.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_MANIFEST_JSON_INVALID", "Admission manifest is not one JSON object."
		)
	var manifest: Dictionary = parsed["value"]
	var schema_result := SchemaValidatorScript.validate_file(MANIFEST_SCHEMA_PATH, manifest)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3A_KNOWLEDGE_MANIFEST_SCHEMA_INVALID",
			"Admission manifest failed its owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var semantics := _validate_manifest_semantics(manifest)
	if not bool(semantics.get("ok", false)):
		return semantics
	return {
		"ok": true,
		"manifest": FrozenValueScript.snapshot(manifest),
	}


static func _validate_manifest_semantics(manifest: Dictionary) -> Dictionary:
	var seen_ids: Dictionary = {}
	var seen_cells: Dictionary = {}
	var seen_outputs: Dictionary = {}
	var milestone_count := 0
	var supplementary_count := 0
	for spec_value in manifest["entries"]:
		var spec: Dictionary = spec_value
		var entry_id := String(spec["entry_id"])
		var cell_id := String(spec["cell_id"])
		var output_name := String(spec["output_name"])
		if seen_ids.has(entry_id) or seen_cells.has(cell_id) or seen_outputs.has(output_name):
			return _failure(
				"BR3A_KNOWLEDGE_MANIFEST_DUPLICATE",
				"Entry IDs, cells, and output names must be unique."
			)
		seen_ids[entry_id] = true
		seen_cells[cell_id] = true
		seen_outputs[output_name] = true
		var knowledge_class := String(spec["knowledge_class"])
		if knowledge_class == "milestone_observation":
			milestone_count += 1
			if cell_id == "L1.8":
				return _failure(
					"BR3A_KNOWLEDGE_L1_8_MISCLASSIFIED",
					"L1.8 cannot be admitted as a milestone observation."
				)
		elif knowledge_class == "supplementary_constraint":
			supplementary_count += 1
			if cell_id != "L1.8":
				return _failure(
					"BR3A_KNOWLEDGE_SUPPLEMENTARY_CELL_INVALID",
					"Only L1.8 is authorized as a supplementary knowledge constraint."
				)
		for program_id_value in spec["program_ids"]:
			if String(program_id_value) in FORBIDDEN_PROGRAM_IDS:
				return _failure(
					"BR3A_KNOWLEDGE_PROGRAM_FORBIDDEN",
					"Containment and registry programs cannot become knowledge."
				)
	if milestone_count != 8 or supplementary_count != 1 or seen_cells.size() != 9:
		return _failure(
			"BR3A_KNOWLEDGE_MANIFEST_ACCOUNTING_INVALID",
			"Manifest must authorize exactly L1.0-L1.7 plus supplementary L1.8."
		)
	return {"ok": true}


static func _verify_owned_resources() -> Dictionary:
	for item in [
		{
			"path": ENTRY_SCHEMA_PATH,
			"sha256": ENTRY_SCHEMA_SHA256,
			"label": "entry schema",
		},
		{
			"path": MANIFEST_SCHEMA_PATH,
			"sha256": MANIFEST_SCHEMA_SHA256,
			"label": "manifest schema",
		},
		{
			"path": MANIFEST_PATH,
			"sha256": MANIFEST_SHA256,
			"label": "admission manifest",
		},
	]:
		var result := _verify_file_hash(
			String(item["path"]),
			String(item["sha256"]),
			"BR3A_KNOWLEDGE_OWNED_RESOURCE_MISSING",
			"BR3A_KNOWLEDGE_OWNED_RESOURCE_HASH_MISMATCH"
		)
		if not bool(result.get("ok", false)):
			result["label"] = item["label"]
			return result
	return {"ok": true}


static func _resolve_local_locator(locator: String) -> Dictionary:
	var local_app_data := OS.get_environment("LOCALAPPDATA").strip_edges()
	if local_app_data.is_empty():
		return _failure("BR3A_KNOWLEDGE_LOCAL_STORE_UNAVAILABLE", "LOCALAPPDATA is unavailable.")
	var root := _normalized_absolute(local_app_data.path_join("SporeSpore"))
	var resolved := _normalized_absolute(root.path_join(locator))
	if not _is_descendant(resolved, root):
		return _failure(
			"BR3A_KNOWLEDGE_EVIDENCE_PATH_INVALID",
			"Evidence locator escapes the fixed SporeSpore local store."
		)
	return {"ok": true, "path": resolved}


static func _verify_file_hash(
	path: String, expected: String, missing_code: String, mismatch_code: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(
			missing_code, "Required BR3A knowledge resource is missing.", {"path": path}
		)
	var actual := _sha256_file(path)
	if actual != expected:
		return _failure(
			mismatch_code,
			"Required BR3A knowledge resource bytes do not match.",
			{
				"path": path,
				"expected_sha256": expected,
				"actual_sha256": actual,
			}
		)
	return {"ok": true, "path": path, "sha256": actual}


static func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {"ok": true, "value": parser.data}


static func _entry_payload(entry: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	for key_value in entry:
		if String(key_value) != "admission":
			payload[key_value] = entry[key_value]
	return payload


static func _entry_payload_sha256(entry: Dictionary) -> String:
	return CanonicalJsonScript.sha256(_entry_payload(entry))


static func _sha256_file(path: String) -> String:
	return "sha256:%s" % FileAccess.get_sha256(path)


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1


static func _path_entry_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _normalized_absolute(path: String) -> String:
	var value := path.strip_edges().replace("\\", "/")
	if value.begins_with("res://") or value.begins_with("user://"):
		value = ProjectSettings.globalize_path(value).replace("\\", "/")
	return value.simplify_path().trim_suffix("/")


static func _path_identity(path: String) -> String:
	return _normalized_absolute(path).to_lower()


static func _is_descendant(candidate: String, parent: String) -> bool:
	return _path_identity(candidate).begins_with("%s/" % _path_identity(parent).trim_suffix("/"))


static func _utc_now() -> String:
	var timestamp := Time.get_datetime_string_from_system(true, false)
	return timestamp if timestamp.ends_with("Z") else "%sZ" % timestamp


static func _failure(code: String, message: String, details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"failure_code": code,
		"message": message,
		"details": details,
	}
