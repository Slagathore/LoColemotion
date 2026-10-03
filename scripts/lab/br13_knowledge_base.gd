class_name LabBr13KnowledgeBase
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Append-only, certification-backed BR13.0/BR13.2/BR13.4 observations.
##
## Every entry is observation-only. Verification reopens the accepted
## decision and independently revalidates the complete production report,
## detached report receipt, and all ten production-attested bundles. The
## integrity-only BR13.1 and BR13.3 cells cannot be represented. The schema
## cannot represent repair rules or automatic guidance.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const MilestoneDecisionRegistryScript := preload("res://scripts/lab/milestone_decision_registry.gd")
const PublicationAttestationScript := preload("res://scripts/lab/publication_attestation.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const ENTRY_SCHEMA := "sporespore.lab.br13_knowledge_entry.v1"
const ENTRY_SCHEMA_PATH := "res://data/lab/schemas/br13_knowledge_entry_v1.schema.json"
const ENTRY_SCHEMA_SHA256 := "sha256:b92e462dab8eed7e789fec05fb182ba19ae766a79de000b63cb2ae0eb93eb6cd"
const MANIFEST_SCHEMA_PATH := "res://data/lab/schemas/br13_knowledge_admission_manifest_v1.schema.json"
const MANIFEST_SCHEMA_SHA256 := "sha256:5131d4492f9e5063d976bf7e63eaa2f080c3ddd9688318efef6e4346494ed7ae"
const MANIFEST_PATH := (
	"res://data/lab/knowledge/admission_manifests/"
	+ "BR13_canonical_get_up_knowledge_admission_v1.json"
)
const MANIFEST_SHA256 := "sha256:741fff3812c9fb7267ac192e2de3c8354f872410f0dcc0b2bc0490ee6983f7cd"
const REPORT_SCHEMA_PATH := "res://data/lab/schemas/br13_certification_report_v1.schema.json"
const REPORT_RECEIPT_SCHEMA_PATH := "res://data/lab/schemas/br13_certification_report_attestation_v1.schema.json"
const DECISION_ID := "BR13_CONSTRAINED_CANONICAL_GET_UP_DECISION_V1"
const DECISION_SHA256 := "sha256:524363ee5ea52bd4f81c3407dd1e5b895fb56cb6027c5ec7f8a8646ef34db95e"
const MILESTONE_ID := "BR13_CONSTRAINED_CANONICAL_GET_UP"
const MANIFEST_ID := "BR13_CANONICAL_GET_UP_KNOWLEDGE_ADMISSION_V1"
const ADMISSION_POLICY := "br13-knowledge-admission-v1"
const AUTHORIZATION_BASIS := "standing_authority_to_admit_recommended_observation_only_br13_knowledge"
const ENTRY_DIRECTORY := "res://data/lab/knowledge/entries/"
const GUIDANCE_POLICY := {
	"mode": "observation_only",
	"automatic_creature_guidance_allowed": false,
	"automatic_application_allowed": false,
	"unlock_requires":
	[
		"VALIDATED_CREATURE_GUIDANCE_CONSUMER",
		"CERTIFIED_MORPHOLOGY_TERRAIN_TRANSFER",
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
const MILESTONE_CELLS: Array[String] = ["BR13.0", "BR13.2", "BR13.4"]
const MILESTONE_PROGRAMS: Array[String] = [
	"BR13_CANONICAL_GET_UP_0_PROFILE_PHASE_ORDER_V1",
	"BR13_CANONICAL_GET_UP_2_ENERGY_GATE_V1",
	"BR13_CANONICAL_GET_UP_4_LIVE_PAIRED_GET_UP_V1",
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
	for spec_value in (manifest_result["manifest"] as Dictionary)["entries"]:
		var spec: Dictionary = spec_value
		if String(spec["entry_id"]) == entry_id:
			var timestamp := String(recorded_utc).strip_edges()
			if timestamp.is_empty():
				timestamp = _utc_now()
			return _propose_spec(spec, timestamp, manifest_result["manifest"])
	return _failure(
		"BR13_KNOWLEDGE_ENTRY_UNKNOWN",
		"Entry ID is not authorized by the fixed BR13 admission manifest."
	)


static func verify_entry(entry: Dictionary) -> Dictionary:
	var schema_result := SchemaValidatorScript.validate_file(ENTRY_SCHEMA_PATH, entry)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR13_KNOWLEDGE_ENTRY_SCHEMA_INVALID",
			"Entry failed the strict BR13 knowledge schema.",
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
			"BR13_KNOWLEDGE_ENTRY_UNKNOWN",
			"Entry ID is not authorized by the fixed BR13 admission manifest."
		)
	var proposal := _propose_spec(matched, String(entry["recorded_utc"]), manifest)
	if not bool(proposal.get("ok", false)):
		return proposal
	if CanonicalJsonScript.stringify(proposal["entry"]) != CanonicalJsonScript.stringify(entry):
		return _failure(
			"BR13_KNOWLEDGE_ENTRY_MISMATCH",
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
			"BR13_KNOWLEDGE_ENTRY_PATH_INVALID",
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
			"KNOWLEDGE_TEMP_OPEN_FAILED", "Could not open the BR13 entry temporary file."
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
		var parsed := _read_json_object(path)
		if not bool(parsed.get("ok", false)):
			(
				errors
				. append(
					{
						"entry_id": spec["entry_id"],
						"code": "BR13_KNOWLEDGE_ENTRY_MISSING_OR_INVALID",
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
						"code": "BR13_KNOWLEDGE_ENTRY_UNTRUSTED",
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
			"BR13_KNOWLEDGE_PROPOSAL_SCHEMA_INVALID",
			"Generated BR13 observation does not satisfy its strict schema.",
			{"schema_errors": schema_result.get("errors", [])}
		)
	return {"ok": true, "entry": FrozenValueScript.snapshot(entry)}


static func _inspect_certification(program_id: String) -> Dictionary:
	var decision_result := MilestoneDecisionRegistryScript.load_by_id(DECISION_ID)
	if (
		not bool(decision_result.get("ok", false))
		or String(decision_result.get("decision_sha256", "")) != DECISION_SHA256
	):
		return _failure(
			"BR13_KNOWLEDGE_DECISION_INVALID",
			"The exact accepted BR13 decision is unavailable or invalid.",
			{"decision": decision_result}
		)
	var decision: Dictionary = decision_result["decision"]
	if String(decision["status"]) != "accepted" or String(decision["milestone_id"]) != MILESTONE_ID:
		return _failure(
			"BR13_KNOWLEDGE_DECISION_NOT_ACCEPTED",
			"BR13 observation admission requires the exact accepted milestone."
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
		"BR13_KNOWLEDGE_REPORT_MISSING",
		"BR13_KNOWLEDGE_REPORT_HASH_MISMATCH"
	)
	if not bool(report_hash.get("ok", false)):
		return report_hash
	if _file_size(report_path) != int(basis["report_bytes"]):
		return _failure(
			"BR13_KNOWLEDGE_REPORT_SIZE_MISMATCH",
			"Certification report byte count differs from the accepted decision."
		)
	var receipt_hash := _verify_file_hash(
		receipt_path,
		String(basis["receipt_sha256"]),
		"BR13_KNOWLEDGE_REPORT_RECEIPT_MISSING",
		"BR13_KNOWLEDGE_REPORT_RECEIPT_HASH_MISMATCH"
	)
	if not bool(receipt_hash.get("ok", false)):
		return receipt_hash
	var report_result := _read_json_object(report_path)
	var receipt_result := _read_json_object(receipt_path)
	if not bool(report_result.get("ok", false)) or not bool(receipt_result.get("ok", false)):
		return _failure(
			"BR13_KNOWLEDGE_CERTIFICATION_JSON_INVALID",
			"Certification report or detached receipt is not one JSON object."
		)
	var report: Dictionary = report_result["value"]
	var receipt: Dictionary = receipt_result["value"]
	var report_schema := SchemaValidatorScript.validate_file(REPORT_SCHEMA_PATH, report)
	var receipt_schema := SchemaValidatorScript.validate_file(REPORT_RECEIPT_SCHEMA_PATH, receipt)
	if not bool(report_schema.get("ok", false)) or not bool(receipt_schema.get("ok", false)):
		return _failure(
			"BR13_KNOWLEDGE_CERTIFICATION_SCHEMA_INVALID",
			"Certification report or receipt failed its owned schema.",
			{
				"report_errors": report_schema.get("errors", []),
				"receipt_errors": receipt_schema.get("errors", []),
			}
		)
	var boundary := _verify_report_boundary(report, receipt, basis)
	if not bool(boundary.get("ok", false)):
		return boundary
	var matched_program: Dictionary = {}
	for program_value in report["programs"]:
		var candidate: Dictionary = program_value
		if String(candidate["program_id"]) == program_id:
			if not matched_program.is_empty():
				return _failure(
					"BR13_KNOWLEDGE_PROGRAM_DUPLICATE",
					"Certification report contains a duplicate program ID."
				)
			matched_program = candidate
	if matched_program.is_empty():
		return _failure(
			"BR13_KNOWLEDGE_PROGRAM_MISSING",
			"Authorized program is absent from the exact certification report."
		)
	var compact := _compact_milestone_program(matched_program, basis)
	if not bool(compact.get("ok", false)):
		return compact
	return {
		"ok": true,
		"evidence":
		{
			"family": "br13_certification_program_v1",
			"decision_id": DECISION_ID,
			"decision_sha256": DECISION_SHA256,
			"certification_id": basis["certification_id"],
			"report_sha256": basis["report_sha256"],
			"report_bytes": basis["report_bytes"],
			"report_receipt_sha256": basis["receipt_sha256"],
			"source_commit_sha": basis["source_commit_sha"],
			"campaign_sha256": basis["campaign_sha256"],
			"certification_claim_boundary": basis["certification_claim_boundary"],
			"program": compact["program"],
		},
	}


static func _verify_report_boundary(
	report: Dictionary, receipt: Dictionary, basis: Dictionary
) -> Dictionary:
	if (
		String(report.get("schema", "")) != "sporespore.lab.br13_certification_report.v1"
		or String(report.get("status", "")) != "pass"
		or String(report.get("certification_id", "")) != String(basis["certification_id"])
		or String(report.get("milestone_id", "")) != MILESTONE_ID
		or String(report.get("claim_boundary", "")) != String(basis["certification_claim_boundary"])
	):
		return _failure(
			"BR13_KNOWLEDGE_REPORT_IDENTITY_MISMATCH",
			"Certification report identity contradicts the accepted decision."
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
			"BR13_KNOWLEDGE_REPORT_SOURCE_MISMATCH",
			"Certification report source identity contradicts the accepted decision."
		)
	if (
		String(receipt["certification_id"]) != String(basis["certification_id"])
		or String(receipt["report_sha256"]) != String(basis["report_sha256"])
		or int(receipt["report_bytes"]) != int(basis["report_bytes"])
		or String(receipt["commit_sha"]) != String(basis["source_commit_sha"])
		or String(receipt["campaign_sha256"]) != String(basis["campaign_sha256"])
		or String(receipt["key_id"]) != String(basis["receipt_key_id"])
		or (String(receipt["domain"]) != "sporespore.lab.br13_certification_report_attestation.v1")
	):
		return _failure(
			"BR13_KNOWLEDGE_REPORT_RECEIPT_IDENTITY_MISMATCH",
			"Detached report receipt contradicts the accepted decision."
		)
	var capabilities: Dictionary = report["capabilities"]
	var constraints: Dictionary = report["canonical_get_up_constraints"]
	if (
		int(capabilities["accepted_knowledge_entries"]) != 0
		or bool(capabilities["automatic_creature_guidance_allowed"])
		or not bool(capabilities["constrained_planar_get_up"])
		or not bool(capabilities["paired_zero_command_control"])
		or not bool(capabilities["stable_stance_terminal"])
		or bool(capabilities["free_3d_recovery"])
		or bool(capabilities["morphology_transfer"])
		or bool(capabilities["independent_four_limb_control"])
		or bool(capabilities["general_standing"])
		or bool(capabilities["bracing"])
		or bool(capabilities["fall_arrest"])
		or bool(capabilities["gait"])
		or bool(capabilities["walking"])
		or not bool(constraints["constrained_planar_get_up_established"])
		or not bool(constraints["out_of_plane_translation_locked"])
		or not bool(constraints["roll_and_yaw_locked"])
		or not bool(constraints["front_and_rear_each_represent_mirrored_pair"])
		or bool(constraints["independent_left_right_control"])
		or not bool(constraints["same_initial_state_control_required"])
		or not bool(constraints["zero_command_control_required"])
	):
		return _failure(
			"BR13_KNOWLEDGE_CAPABILITY_BOUNDARY_WEAKENED",
			"Certification report no longer preserves the accepted BR13 non-claims."
		)
	return {"ok": true}


static func _compact_milestone_program(program: Dictionary, basis: Dictionary) -> Dictionary:
	var program_id := String(program["program_id"])
	var cell_id := String(program["cell_id"])
	if (
		program_id not in MILESTONE_PROGRAMS
		or cell_id not in MILESTONE_CELLS
		or String(program["evidence_role"]) != "milestone"
	):
		return _failure(
			"BR13_KNOWLEDGE_PROGRAM_CLASS_INVALID",
			"Program is not one of the three accepted BR13 milestone cells."
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
				"BR13_KNOWLEDGE_REPLICATE_RECONCILIATION_FAILED",
				"Program replicate reconciliation is incomplete.",
				{"field": field}
			)
	var replicates: Array = program["replicates"]
	if replicates.size() != 2:
		return _failure(
			"BR13_KNOWLEDGE_REPLICATE_COUNT_INVALID",
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
				"BR13_KNOWLEDGE_REPLICATE_IDENTITY_INVALID",
				"Replicate identity, assertion count, or source closure is inconsistent."
			)
		var live := PublicationAttestationScript.verify_production(String(replicate["bundle_path"]))
		var recorded: Dictionary = replicate["attestation"]
		if (
			not bool(live.get("ok", false))
			or String(live.get("trust_mode", "")) != "production"
			or String(live.get("run_id", "")) != String(replicate["bundle_id"])
			or String(live.get("manifest_sha256", "")) != String(replicate["manifest_sha256"])
			or String(live.get("checksums_sha256", "")) != String(replicate["checksums_sha256"])
			or int(live.get("artifact_count", -1)) != 7
			or not bool(recorded["valid"])
			or String(live.get("key_id", "")) != String(recorded["key_id"])
			or String(live.get("receipt_sha256", "")) != String(recorded["receipt_sha256"])
			or (
				_path_identity(String(live.get("receipt_path", "")))
				!= _path_identity(String(recorded["receipt_path"]))
			)
		):
			return _failure(
				"BR13_KNOWLEDGE_CAPSULE_ATTESTATION_INVALID",
				"A cited capsule no longer matches its production receipt."
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
						"algorithm": live["algorithm"],
						"trust_mode": live["trust_mode"],
						"key_id": live["key_id"],
						"receipt_path": live["receipt_path"],
						"receipt_sha256": live["receipt_sha256"],
						"artifact_count": live["artifact_count"],
						"attested_utc": live["attested_utc"],
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
	var owned := _verify_owned_resources()
	if not bool(owned.get("ok", false)):
		return owned
	var parsed := _read_json_object(MANIFEST_PATH)
	if not bool(parsed.get("ok", false)):
		return _failure(
			"BR13_KNOWLEDGE_MANIFEST_JSON_INVALID", "Admission manifest is not one JSON object."
		)
	var manifest: Dictionary = parsed["value"]
	var schema_result := SchemaValidatorScript.validate_file(MANIFEST_SCHEMA_PATH, manifest)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR13_KNOWLEDGE_MANIFEST_SCHEMA_INVALID",
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
				"BR13_KNOWLEDGE_MANIFEST_DUPLICATE",
				"Entry IDs, cells, programs, and output names must be unique."
			)
		seen_ids[entry_id] = true
		seen_cells[cell_id] = true
		seen_programs[program_id] = true
		seen_outputs[output_name] = true
		for field in AUTHORING_FIELDS:
			if not (spec["authoring"] as Dictionary).has(field):
				return _failure(
					"BR13_KNOWLEDGE_AUTHORING_INCOMPLETE",
					"Manifest authoring block is incomplete.",
					{"entry_id": entry_id, "field": field}
				)
	if (
		seen_cells.keys().duplicate().size() != MILESTONE_CELLS.size()
		or seen_programs.size() != MILESTONE_PROGRAMS.size()
	):
		return _failure(
			"BR13_KNOWLEDGE_MANIFEST_ACCOUNTING_INVALID",
			"Manifest must authorize exactly the three accepted milestone observations."
		)
	for required_cell in MILESTONE_CELLS:
		if not seen_cells.has(required_cell):
			return _failure(
				"BR13_KNOWLEDGE_MANIFEST_CELL_MISSING",
				"Manifest omits a required BR13 milestone cell."
			)
	for required_program in MILESTONE_PROGRAMS:
		if not seen_programs.has(required_program):
			return _failure(
				"BR13_KNOWLEDGE_MANIFEST_PROGRAM_MISSING",
				"Manifest omits a required BR13 milestone program."
			)
	if seen_cells.has("BR13.1") or seen_cells.has("BR13.3"):
		return _failure(
			"BR13_KNOWLEDGE_INTEGRITY_CELL_FORBIDDEN",
			"Integrity-only BR13 cells cannot become accepted observation entries."
		)
	return {"ok": true, "manifest": FrozenValueScript.snapshot(manifest)}


static func _verify_owned_resources() -> Dictionary:
	for item in [
		{"path": ENTRY_SCHEMA_PATH, "sha256": ENTRY_SCHEMA_SHA256},
		{"path": MANIFEST_SCHEMA_PATH, "sha256": MANIFEST_SCHEMA_SHA256},
		{"path": MANIFEST_PATH, "sha256": MANIFEST_SHA256},
	]:
		var path := String(item["path"])
		if not FileAccess.file_exists(path):
			return _failure(
				"BR13_KNOWLEDGE_OWNED_RESOURCE_MISSING",
				"Required BR13 knowledge resource is missing.",
				{"path": path}
			)
		var actual := _sha256_file(path)
		if actual != String(item["sha256"]):
			return _failure(
				"BR13_KNOWLEDGE_OWNED_RESOURCE_HASH_MISMATCH",
				"Required BR13 knowledge resource bytes do not match.",
				{"path": path, "expected_sha256": item["sha256"], "actual_sha256": actual}
			)
	return {"ok": true}


static func _resolve_local_locator(locator: String) -> Dictionary:
	var local_app_data := OS.get_environment("LOCALAPPDATA").strip_edges()
	if local_app_data.is_empty():
		return _failure("BR13_KNOWLEDGE_LOCAL_STORE_UNAVAILABLE", "LOCALAPPDATA is unavailable.")
	var root := _normalized_absolute(local_app_data.path_join("SporeSpore"))
	var resolved := _normalized_absolute(root.path_join(locator))
	if not _is_descendant(resolved, root):
		return _failure(
			"BR13_KNOWLEDGE_EVIDENCE_PATH_INVALID",
			"Evidence locator escapes the fixed SporeSpore local store."
		)
	return {"ok": true, "path": resolved}


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


static func _verify_file_hash(
	path: String, expected: String, missing_code: String, mismatch_code: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(
			missing_code, "Required BR13 knowledge evidence is missing.", {"path": path}
		)
	var actual := _sha256_file(path)
	if actual != expected:
		return _failure(
			mismatch_code,
			"Required BR13 knowledge evidence bytes do not match.",
			{"path": path, "expected_sha256": expected, "actual_sha256": actual}
		)
	return {"ok": true, "path": path, "sha256": actual}


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
