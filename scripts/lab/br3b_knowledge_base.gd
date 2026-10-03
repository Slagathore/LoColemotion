class_name LabBr3bKnowledgeBase
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Append-only, certification-backed BR3B observations.
##
## Every entry remains observation-only. Verification reopens the accepted
## decision, exact report and receipt bytes, and both production-attested
## bundles for the entry's one L3 program. No repair rule can be represented
## by the schema.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const MilestoneDecisionRegistryScript := preload("res://scripts/lab/milestone_decision_registry.gd")
const PublicationAttestationScript := preload("res://scripts/lab/publication_attestation.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const ENTRY_SCHEMA := "sporespore.lab.br3b_knowledge_entry.v1"
const ENTRY_SCHEMA_PATH := "res://data/lab/schemas/br3b_knowledge_entry_v1.schema.json"
const ENTRY_SCHEMA_SHA256 := "sha256:1528c40023e93f03d10ab5964f03d6f0b582605e1113600c2895a7f12c472457"
const MANIFEST_SCHEMA_PATH := "res://data/lab/schemas/br3b_knowledge_admission_manifest_v1.schema.json"
const MANIFEST_SCHEMA_SHA256 := "sha256:659022e70f29530a69fe08bd34094e317fb940a9ce3ad3c353f70e9196e01f3a"
const MANIFEST_PATH := "res://data/lab/knowledge/admission_manifests/BR3B_L3_knowledge_admission_v1.json"
const MANIFEST_SHA256 := "sha256:de68b7ffa37ef1eb74296561f8d64eb85120189d7e802e637d343a81b2103266"
const REPORT_SCHEMA_PATH := "res://data/lab/schemas/br3b_certification_report_v1.schema.json"
const REPORT_RECEIPT_SCHEMA_PATH := "res://data/lab/schemas/br3b_certification_report_attestation_v1.schema.json"
const DECISION_ID := "BR3B_L3_BASIC_LOADED_FOOT_TRUTH_DECISION_V1"
const DECISION_SHA256 := "sha256:f607c2b86599b1bc2ef085ff29819edd736ef161c8e5024916fae8b7d753ea85"
const MANIFEST_ID := "BR3B_L3_KNOWLEDGE_ADMISSION_V1"
const ADMISSION_POLICY := "br3b-knowledge-admission-v1"
const AUTHORIZATION_BASIS := "standing_authority_to_admit_recommended_observation_only_br3b_knowledge"
const ENTRY_DIRECTORY := "res://data/lab/knowledge/entries/"
const GUIDANCE_POLICY := {
	"mode": "observation_only",
	"automatic_creature_guidance_allowed": false,
	"automatic_application_allowed": false,
	"unlock_requires":
	[
		"ACCEPTED_ARTICULATED_CONTACT_BEARING_SUPPORT_MILESTONE",
		"SEPARATE_GUIDANCE_DECISION",
	],
}
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


static func propose_all(recorded_utc := "") -> Dictionary:
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var timestamp := String(recorded_utc).strip_edges()
	if timestamp.is_empty():
		timestamp = _utc_now()
	var entries: Array = []
	for spec_value in (manifest_result["manifest"] as Dictionary)["entries"]:
		var proposal := _propose_spec(spec_value, timestamp, manifest_result["manifest"])
		if not bool(proposal.get("ok", false)):
			return proposal
		entries.append(proposal["entry"])
	return {
		"ok": true,
		"entries": FrozenValueScript.snapshot(entries),
		"manifest": FrozenValueScript.snapshot(manifest_result["manifest"]),
	}


static func propose_entry(entry_id: String, recorded_utc := "") -> Dictionary:
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var manifest: Dictionary = manifest_result["manifest"]
	for spec_value in manifest["entries"]:
		var spec: Dictionary = spec_value
		if String(spec["entry_id"]) == entry_id:
			var timestamp := String(recorded_utc).strip_edges()
			if timestamp.is_empty():
				timestamp = _utc_now()
			return _propose_spec(spec, timestamp, manifest)
	return _failure(
		"BR3B_KNOWLEDGE_ENTRY_UNKNOWN",
		"Entry ID is not authorized by the fixed BR3B admission manifest."
	)


static func verify_entry(entry: Dictionary) -> Dictionary:
	var schema_result := SchemaValidatorScript.validate_file(ENTRY_SCHEMA_PATH, entry)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3B_KNOWLEDGE_ENTRY_SCHEMA_INVALID",
			"Entry failed the strict BR3B knowledge schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var manifest: Dictionary = manifest_result["manifest"]
	var matched: Dictionary = {}
	for spec_value in manifest["entries"]:
		var spec: Dictionary = spec_value
		if String(spec["entry_id"]) == String(entry["entry_id"]):
			matched = spec
			break
	if matched.is_empty():
		return _failure(
			"BR3B_KNOWLEDGE_ENTRY_UNKNOWN",
			"Entry ID is not authorized by the fixed BR3B admission manifest."
		)
	var proposal := _propose_spec(matched, String(entry["recorded_utc"]), manifest)
	if not bool(proposal.get("ok", false)):
		return proposal
	if CanonicalJsonScript.stringify(proposal["entry"]) != CanonicalJsonScript.stringify(entry):
		return _failure(
			"BR3B_KNOWLEDGE_ENTRY_MISMATCH",
			"Entry differs from the exact manifest, decision, or live certification evidence."
		)
	return {
		"ok": true,
		"entry": FrozenValueScript.snapshot(entry),
		"automatic_creature_guidance_allowed": false,
		"automatic_application_allowed": false,
	}


static func write_new_entry(path: String, entry: Dictionary) -> Dictionary:
	var absolute := _normalized_absolute(path)
	var entry_root := _normalized_absolute(ENTRY_DIRECTORY)
	if (
		not absolute.to_lower().ends_with(".json")
		or absolute.get_base_dir().to_lower() != entry_root.to_lower()
	):
		return _failure(
			"BR3B_KNOWLEDGE_ENTRY_PATH_INVALID",
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
			"KNOWLEDGE_TEMP_OPEN_FAILED", "Could not open the BR3B entry temporary file."
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
	for spec_value in (manifest_result["manifest"] as Dictionary)["entries"]:
		var spec: Dictionary = spec_value
		var path := ENTRY_DIRECTORY.path_join(String(spec["output_name"]))
		if not FileAccess.file_exists(path):
			(
				errors
				. append(
					{
						"entry_id": spec["entry_id"],
						"code": "BR3B_KNOWLEDGE_ENTRY_MISSING",
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
						"code": "BR3B_KNOWLEDGE_ENTRY_JSON_INVALID",
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
						"code": "BR3B_KNOWLEDGE_ENTRY_UNTRUSTED",
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
		"expected_entry_count": 3,
		"installed_entry_count": entries.size(),
		"minimal_repair_rule_count": 0,
		"automatic_creature_guidance_allowed": false,
		"automatic_application_allowed": false,
	}


static func output_plan() -> Dictionary:
	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var outputs: Array = []
	for spec_value in (manifest_result["manifest"] as Dictionary)["entries"]:
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
	return {"ok": true, "outputs": FrozenValueScript.snapshot(outputs)}


static func _propose_spec(
	spec: Dictionary, recorded_utc: String, manifest: Dictionary
) -> Dictionary:
	var certification := _inspect_certification(String(spec["program_id"]))
	if not bool(certification.get("ok", false)):
		return certification
	var authoring: Dictionary = spec["authoring"]
	var entry := {
		"schema": ENTRY_SCHEMA,
		"entry_id": spec["entry_id"],
		"cell_id": spec["cell_id"],
		"knowledge_class": "milestone_observation",
		"title": authoring["title"],
		"claim": authoring["claim"],
		"claim_status": "accepted",
		"scope": authoring["scope"],
		"mechanism": authoring["mechanism"],
		"applicability": authoring["applicability"],
		"failure_boundaries": authoring["failure_boundaries"],
		"morphology_tags": authoring["morphology_tags"],
		"parameter_effects": authoring["parameter_effects"],
		"minimal_repair_rules": [],
		"unknowns": authoring["unknowns"],
		"evidence": certification["evidence"],
		"guidance_policy": GUIDANCE_POLICY,
		"authoring_source":
		{
			"kind": "admission_manifest_inline",
			"path": MANIFEST_PATH,
			"sha256": MANIFEST_SHA256,
		},
		"supersedes": authoring["supersedes"],
		"recorded_utc": recorded_utc,
	}
	entry["admission"] = {
		"policy": ADMISSION_POLICY,
		"manifest_id": MANIFEST_ID,
		"manifest_sha256": MANIFEST_SHA256,
		"authorized_by": manifest["authorized_by"],
		"authorization_basis": AUTHORIZATION_BASIS,
		"payload_sha256": CanonicalJsonScript.sha256(entry),
	}
	var schema_result := SchemaValidatorScript.validate_file(ENTRY_SCHEMA_PATH, entry)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3B_KNOWLEDGE_PROPOSAL_SCHEMA_INVALID",
			"Generated BR3B observation does not satisfy its strict schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	return {"ok": true, "entry": FrozenValueScript.snapshot(entry)}


static func _inspect_certification(program_id: String) -> Dictionary:
	var decision_result := MilestoneDecisionRegistryScript.load_by_id(DECISION_ID)
	if not bool(decision_result.get("ok", false)):
		return _failure(
			"BR3B_KNOWLEDGE_DECISION_INVALID",
			"The accepted BR3B decision is unavailable or invalid.",
			{"decision": decision_result}
		)
	if String(decision_result["decision_sha256"]) != DECISION_SHA256:
		return _failure(
			"BR3B_KNOWLEDGE_DECISION_HASH_MISMATCH",
			"The BR3B decision registry no longer names the admitted decision bytes."
		)
	var decision: Dictionary = decision_result["decision"]
	if (
		String(decision["status"]) != "accepted"
		or String(decision["milestone_id"]) != "BR3B_L3_BASIC_LOADED_FOOT_TRUTH"
	):
		return _failure(
			"BR3B_KNOWLEDGE_DECISION_NOT_ACCEPTED",
			"BR3B observation admission requires the exact accepted L3 milestone."
		)
	var basis: Dictionary = decision["evidence_basis"]
	var report_locator := _resolve_local_locator(String(basis["report_locator"]))
	var receipt_locator := _resolve_local_locator(String(basis["receipt_locator"]))
	if not bool(report_locator.get("ok", false)):
		return report_locator
	if not bool(receipt_locator.get("ok", false)):
		return receipt_locator
	var report_path := String(report_locator["path"])
	var receipt_path := String(receipt_locator["path"])
	var report_hash := _verify_file_hash(
		report_path,
		String(basis["report_sha256"]),
		"BR3B_KNOWLEDGE_REPORT_MISSING",
		"BR3B_KNOWLEDGE_REPORT_HASH_MISMATCH"
	)
	if not bool(report_hash.get("ok", false)):
		return report_hash
	if _file_size(report_path) != int(basis["report_bytes"]):
		return _failure(
			"BR3B_KNOWLEDGE_REPORT_SIZE_MISMATCH",
			"Certification report byte count differs from the accepted decision."
		)
	var receipt_hash := _verify_file_hash(
		receipt_path,
		String(basis["receipt_sha256"]),
		"BR3B_KNOWLEDGE_REPORT_RECEIPT_MISSING",
		"BR3B_KNOWLEDGE_REPORT_RECEIPT_HASH_MISMATCH"
	)
	if not bool(receipt_hash.get("ok", false)):
		return receipt_hash
	var report_result := _read_json_object(report_path)
	var receipt_result := _read_json_object(receipt_path)
	if not bool(report_result.get("ok", false)) or not bool(receipt_result.get("ok", false)):
		return _failure(
			"BR3B_KNOWLEDGE_CERTIFICATION_JSON_INVALID",
			"Certification report or detached receipt is not one JSON object."
		)
	var report: Dictionary = report_result["value"]
	var receipt: Dictionary = receipt_result["value"]
	var report_schema := SchemaValidatorScript.validate_file(REPORT_SCHEMA_PATH, report)
	var receipt_schema := SchemaValidatorScript.validate_file(REPORT_RECEIPT_SCHEMA_PATH, receipt)
	if not bool(report_schema.get("ok", false)) or not bool(receipt_schema.get("ok", false)):
		return _failure(
			"BR3B_KNOWLEDGE_CERTIFICATION_SCHEMA_INVALID",
			"Certification report or receipt failed its owned schema.",
			{
				"report_errors": report_schema.get("errors", []),
				"receipt_errors": receipt_schema.get("errors", []),
			}
		)
	var identity := _verify_report_identity(report, receipt, basis)
	if not bool(identity.get("ok", false)):
		return identity
	var matched_program: Dictionary = {}
	for program_value in report["programs"]:
		var candidate: Dictionary = program_value
		if String(candidate["program_id"]) == program_id:
			if not matched_program.is_empty():
				return _failure(
					"BR3B_KNOWLEDGE_PROGRAM_DUPLICATE",
					"Certification report contains a duplicate program ID.",
					{"program_id": program_id}
				)
			matched_program = candidate
	if matched_program.is_empty():
		return _failure(
			"BR3B_KNOWLEDGE_PROGRAM_MISSING",
			"Authorized program is absent from the exact certification report.",
			{"program_id": program_id}
		)
	var program_result := _inspect_program(matched_program, basis)
	if not bool(program_result.get("ok", false)):
		return program_result
	return {
		"ok": true,
		"evidence":
		{
			"family": "br3b_certification_program_v1",
			"decision_id": DECISION_ID,
			"decision_sha256": DECISION_SHA256,
			"certification_id": basis["certification_id"],
			"report_sha256": basis["report_sha256"],
			"report_bytes": basis["report_bytes"],
			"report_receipt_sha256": basis["receipt_sha256"],
			"source_commit_sha": basis["source_commit_sha"],
			"campaign_sha256": basis["campaign_sha256"],
			"certification_claim_boundary": basis["certification_claim_boundary"],
			"program": program_result["program"],
		},
	}


static func _verify_report_identity(
	report: Dictionary, receipt: Dictionary, basis: Dictionary
) -> Dictionary:
	var exact := {
		"schema": "sporespore.lab.br3b_certification_report.v1",
		"status": "pass",
		"certification": "BR3B_L3_BASIC_LOADED_FOOT_TRUTH",
		"certification_id": basis["certification_id"],
		"milestone_id": "BR3B_L3_BASIC_LOADED_FOOT_TRUTH",
		"claim_boundary": basis["certification_claim_boundary"],
	}
	for field in exact:
		if report.get(field) != exact[field]:
			return _failure(
				"BR3B_KNOWLEDGE_REPORT_IDENTITY_MISMATCH",
				"Certification report contradicts the accepted decision field.",
				{"field": field}
			)
	var source: Dictionary = report["source"]
	if (
		String(source["commit_sha"]) != String(basis["source_commit_sha"])
		or String(source["campaign_sha256"]) != String(basis["campaign_sha256"])
		or String(source["source_inventory_sha256"]) != String(basis["source_inventory_sha256"])
		or int(source["source_file_count"]) != int(basis["source_file_count"])
		or String(source["br1_inventory_sha256"]) != String(basis["br1_inventory_sha256"])
		or not bool(source["br1_inventory_unchanged"])
	):
		return _failure(
			"BR3B_KNOWLEDGE_REPORT_SOURCE_MISMATCH",
			"Certification report source identity contradicts the accepted decision."
		)
	var accounting: Dictionary = report["accounting"]
	var accounting_pairs := {
		"programs_required": "programs_required",
		"programs_passed": "programs_passed",
		"bundles_required": "bundles_required",
		"bundles_passed": "bundles_passed",
		"assertions_required": "assertions_required",
		"assertions_passed": "assertions_passed",
	}
	for report_field in accounting_pairs:
		var basis_field := String(accounting_pairs[report_field])
		if int(accounting[report_field]) != int(basis[basis_field]):
			return _failure(
				"BR3B_KNOWLEDGE_REPORT_ACCOUNTING_MISMATCH",
				"Certification accounting contradicts the accepted decision.",
				{"field": report_field}
			)
	var final_readback: Dictionary = report["final_readback"]
	for field in [
		"target_process_invocations",
		"unique_target_processes",
		"pid_recycle_events",
		"receipts_verified",
	]:
		if int(final_readback[field]) != int(basis[field]):
			return _failure(
				"BR3B_KNOWLEDGE_REPORT_READBACK_MISMATCH",
				"Certification final readback contradicts the accepted decision.",
				{"field": field}
			)
	if not bool(final_readback["complete_campaign"]):
		return _failure(
			"BR3B_KNOWLEDGE_REPORT_READBACK_INCOMPLETE",
			"Certification final readback is not complete."
		)
	if (
		String(receipt["certification_id"]) != String(basis["certification_id"])
		or String(receipt["report_sha256"]) != String(basis["report_sha256"])
		or int(receipt["report_bytes"]) != int(basis["report_bytes"])
		or String(receipt["commit_sha"]) != String(basis["source_commit_sha"])
		or String(receipt["campaign_sha256"]) != String(basis["campaign_sha256"])
		or String(receipt["key_id"]) != String(basis["receipt_key_id"])
		or String(receipt["domain"]) != "sporespore.lab.br3b_certification_report_attestation.v1"
	):
		return _failure(
			"BR3B_KNOWLEDGE_REPORT_RECEIPT_IDENTITY_MISMATCH",
			"Detached report receipt contradicts the accepted decision."
		)
	var capabilities: Dictionary = report["capabilities"]
	var constraints: Dictionary = report["loaded_foot_constraints"]
	if (
		int(capabilities["accepted_knowledge_entries"]) != 0
		or bool(capabilities["automatic_creature_guidance_allowed"])
		or bool(capabilities["general_per_foot_load_allocation"])
		or bool(capabilities["articulated_load_bearing_limb"])
		or bool(capabilities["standing"])
		or bool(capabilities["bracing"])
		or bool(capabilities["fall_arrest"])
		or bool(capabilities["getting_up"])
		or bool(capabilities["walking"])
		or String(constraints["force_application_method"]) != "RigidBody3D.apply_force"
		or bool(constraints["physical_carriage_rail_present"])
		or bool(constraints["hidden_pin_or_lock_present"])
		or bool(constraints["hidden_balancing_moment_present"])
		or bool(constraints["raw_contact_impulse_is_general_wrench"])
		or bool(constraints["articulated_load_bearing_limb_established"])
	):
		return _failure(
			"BR3B_KNOWLEDGE_CAPABILITY_BOUNDARY_WEAKENED",
			"Certification report no longer preserves the accepted BR3B non-claims."
		)
	return {"ok": true}


static func _inspect_program(program: Dictionary, basis: Dictionary) -> Dictionary:
	var program_id := String(program["program_id"])
	var cell_id := String(program["cell_id"])
	if (
		String(program["evidence_role"]) != "milestone"
		or not cell_id.begins_with("L3.")
		or int(cell_id.trim_prefix("L3.")) < 0
		or int(cell_id.trim_prefix("L3.")) > 2
	):
		return _failure(
			"BR3B_KNOWLEDGE_PROGRAM_CLASS_INVALID",
			"Program role and cell do not match the accepted L3 boundary.",
			{"program_id": program_id, "cell_id": cell_id}
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
				"BR3B_KNOWLEDGE_REPLICATE_RECONCILIATION_FAILED",
				"Program replicate reconciliation is not complete.",
				{"program_id": program_id, "field": field}
			)
	var replicates: Array = program["replicates"]
	if replicates.size() != 2:
		return _failure(
			"BR3B_KNOWLEDGE_REPLICATE_COUNT_INVALID",
			"Every admitted program requires exactly two certified replicates."
		)
	var compact_replicates: Array = []
	for index in range(2):
		var replicate: Dictionary = replicates[index]
		if (
			int(replicate["replicate"]) != index + 1
			or int(replicate["assertions_passed"]) != int(program["expected_assertions"])
			or (
				String(replicate["source_inventory_sha256"])
				!= String(basis["source_inventory_sha256"])
			)
		):
			return _failure(
				"BR3B_KNOWLEDGE_REPLICATE_IDENTITY_INVALID",
				"Replicate identity, assertions, or source closure is inconsistent.",
				{"program_id": program_id, "replicate": index + 1}
			)
		var attestation := PublicationAttestationScript.verify_production(
			String(replicate["bundle_path"])
		)
		if not bool(attestation.get("ok", false)):
			return _failure(
				"BR3B_KNOWLEDGE_CAPSULE_ATTESTATION_INVALID",
				"A cited capsule fails its production receipt or artifact checksums.",
				{
					"program_id": program_id,
					"replicate": index + 1,
					"attestation": attestation,
				}
			)
		var recorded: Dictionary = replicate["attestation"]
		if (
			String(attestation["trust_mode"]) != "production"
			or String(attestation["run_id"]) != String(replicate["bundle_id"])
			or String(attestation["manifest_sha256"]) != String(replicate["manifest_sha256"])
			or String(attestation["checksums_sha256"]) != String(replicate["checksums_sha256"])
			or int(attestation["artifact_count"]) != 7
			or not bool(recorded["valid"])
			or String(attestation["key_id"]) != String(recorded["key_id"])
			or String(attestation["receipt_sha256"]) != String(recorded["receipt_sha256"])
			or (
				_path_identity(String(attestation["receipt_path"]))
				!= _path_identity(String(recorded["receipt_path"]))
			)
		):
			return _failure(
				"BR3B_KNOWLEDGE_CAPSULE_WITNESS_MISMATCH",
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
			"evidence_role": "milestone",
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
			"BR3B_KNOWLEDGE_MANIFEST_JSON_INVALID", "Admission manifest is not one JSON object."
		)
	var manifest: Dictionary = parsed["value"]
	var schema_result := SchemaValidatorScript.validate_file(MANIFEST_SCHEMA_PATH, manifest)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3B_KNOWLEDGE_MANIFEST_SCHEMA_INVALID",
			"Admission manifest failed its owned schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	var seen_ids: Dictionary = {}
	var seen_cells: Dictionary = {}
	var seen_programs: Dictionary = {}
	var seen_outputs: Dictionary = {}
	for spec_value in manifest["entries"]:
		var spec: Dictionary = spec_value
		var entry_id := String(spec["entry_id"])
		var cell_id := String(spec["cell_id"])
		var program_id := String(spec["program_id"])
		var output_name := String(spec["output_name"])
		if (
			seen_ids.has(entry_id)
			or seen_cells.has(cell_id)
			or seen_programs.has(program_id)
			or seen_outputs.has(output_name)
		):
			return _failure(
				"BR3B_KNOWLEDGE_MANIFEST_DUPLICATE",
				"Entry IDs, cells, programs, and output names must be unique."
			)
		seen_ids[entry_id] = true
		seen_cells[cell_id] = true
		seen_programs[program_id] = true
		seen_outputs[output_name] = true
		for field in AUTHORING_FIELDS:
			if not (spec["authoring"] as Dictionary).has(field):
				return _failure(
					"BR3B_KNOWLEDGE_AUTHORING_INCOMPLETE",
					"Manifest authoring block is incomplete.",
					{"entry_id": entry_id, "field": field}
				)
	if seen_cells.size() != 3:
		return _failure(
			"BR3B_KNOWLEDGE_MANIFEST_ACCOUNTING_INVALID",
			"Manifest must authorize exactly one observation for every L3.0-L3.2 cell."
		)
	for index in range(3):
		if not seen_cells.has("L3.%d" % index):
			return _failure(
				"BR3B_KNOWLEDGE_MANIFEST_CELL_MISSING",
				"Manifest omits a required L3 cell.",
				{"cell_id": "L3.%d" % index}
			)
	return {"ok": true, "manifest": FrozenValueScript.snapshot(manifest)}


static func _verify_owned_resources() -> Dictionary:
	for item in [
		{"path": ENTRY_SCHEMA_PATH, "sha256": ENTRY_SCHEMA_SHA256, "label": "entry schema"},
		{
			"path": MANIFEST_SCHEMA_PATH,
			"sha256": MANIFEST_SCHEMA_SHA256,
			"label": "manifest schema",
		},
		{"path": MANIFEST_PATH, "sha256": MANIFEST_SHA256, "label": "admission manifest"},
	]:
		var result := _verify_file_hash(
			String(item["path"]),
			String(item["sha256"]),
			"BR3B_KNOWLEDGE_OWNED_RESOURCE_MISSING",
			"BR3B_KNOWLEDGE_OWNED_RESOURCE_HASH_MISMATCH"
		)
		if not bool(result.get("ok", false)):
			result["label"] = item["label"]
			return result
	return {"ok": true}


static func _resolve_local_locator(locator: String) -> Dictionary:
	var local_app_data := OS.get_environment("LOCALAPPDATA").strip_edges()
	if local_app_data.is_empty():
		return _failure("BR3B_KNOWLEDGE_LOCAL_STORE_UNAVAILABLE", "LOCALAPPDATA is unavailable.")
	var root := _normalized_absolute(local_app_data.path_join("SporeSpore"))
	var resolved := _normalized_absolute(root.path_join(locator))
	if not _is_descendant(resolved, root):
		return _failure(
			"BR3B_KNOWLEDGE_EVIDENCE_PATH_INVALID",
			"Evidence locator escapes the fixed SporeSpore local store."
		)
	return {"ok": true, "path": resolved}


static func _verify_file_hash(
	path: String, expected: String, missing_code: String, mismatch_code: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(missing_code, "Required BR3B knowledge resource is missing.", {"path": path})
	var actual := _sha256_file(path)
	if actual != expected:
		return _failure(
			mismatch_code,
			"Required BR3B knowledge resource bytes do not match.",
			{"path": path, "expected_sha256": expected, "actual_sha256": actual}
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
