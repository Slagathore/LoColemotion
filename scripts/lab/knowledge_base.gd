class_name LabKnowledgeBase
extends RefCounted

## Admission boundary between experiment evidence and reusable creature advice.
## A valid dirty-source bundle may support a development observation. Only a
## bundle that independently reports can_promote=true may support an accepted
## knowledge entry.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const BundleValidatorScript := preload("res://scripts/lab/run_bundle_validator.gd")
const AttestedBundleSnapshotScript := preload("res://scripts/lab/attested_bundle_snapshot.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const Br3aKnowledgeBaseScript := preload("res://scripts/lab/br3a_knowledge_base.gd")
const Br3bKnowledgeBaseScript := preload("res://scripts/lab/br3b_knowledge_base.gd")
const Br4KnowledgeBaseScript := preload("res://scripts/lab/br4_knowledge_base.gd")
const Br6aKnowledgeBaseScript := preload("res://scripts/lab/br6a_knowledge_base.gd")
const Br7KnowledgeBaseScript := preload("res://scripts/lab/br7_knowledge_base.gd")
const Br8KnowledgeBaseScript := preload("res://scripts/lab/br8_knowledge_base.gd")
const Br9KnowledgeBaseScript := preload("res://scripts/lab/br9_knowledge_base.gd")
const Br10KnowledgeBaseScript := preload("res://scripts/lab/br10_knowledge_base.gd")
const Br11KnowledgeBaseScript := preload("res://scripts/lab/br11_knowledge_base.gd")
const Br12KnowledgeBaseScript := preload("res://scripts/lab/br12_knowledge_base.gd")
const Br13KnowledgeBaseScript := preload("res://scripts/lab/br13_knowledge_base.gd")

const ENTRY_SCHEMA_PATH := "res://data/lab/schemas/knowledge_entry_v1.schema.json"
const ADMISSION_POLICY := "knowledge-admission-v1"
const PROMOTED_STATUSES: Array[String] = [
	"accepted",
	"refuted",
	"retired",
]
const VERSIONED_STATUSES: Array[String] = [
	"development_observation",
	"accepted",
	"refuted",
	"retired",
]


static func propose_from_bundle(
	bundle_path: String,
	draft: Dictionary,
	requested_status := "development_observation",
	validation_options: Dictionary = {}
) -> Dictionary:
	var status := String(requested_status)
	if status not in VERSIONED_STATUSES:
		return _failure("KNOWLEDGE_STATUS_INVALID", "Requested claim status is not versioned.")

	var inspection := inspect_bundle(bundle_path, validation_options)
	if not inspection["ok"]:
		return inspection
	var validation: Dictionary = inspection["bundle_validation"]
	var evidence: Dictionary = inspection["evidence"]
	var status_policy := _validate_status_policy(
		status, evidence, inspection["manifest"], inspection["summary"], validation, true
	)
	if not status_policy["ok"]:
		if status == "accepted":
			return _failure(
				"ACCEPTED_KNOWLEDGE_REQUIRES_PROMOTION",
				"Development evidence cannot silently become accepted guidance.",
				status_policy
			)
		return status_policy
	if status == "development_observation" and bool(validation.get("can_promote", false)):
		return _failure(
			"PROMOTABLE_EVIDENCE_REQUIRES_PROMOTED_STATUS",
			"A promotable bundle cannot be silently downgraded to a development observation."
		)

	var required_draft_fields := [
		"entry_id",
		"title",
		"claim",
		"scope",
		"mechanism",
		"applicability",
		"failure_boundaries",
		"morphology_tags",
		"parameter_effects",
		"minimal_repair_rules",
		"unknowns",
	]
	for field in required_draft_fields:
		if not draft.has(field):
			return _failure(
				"KNOWLEDGE_DRAFT_INCOMPLETE", "Draft is missing required field: %s" % field
			)

	var entry := {
		"schema": "sporespore.lab.knowledge_entry.v1",
		"entry_id": String(draft["entry_id"]),
		"title": String(draft["title"]),
		"claim": String(draft["claim"]),
		"claim_status": status,
		"scope": String(draft["scope"]),
		"mechanism": String(draft["mechanism"]),
		"applicability": draft["applicability"],
		"failure_boundaries": draft["failure_boundaries"],
		"morphology_tags": draft["morphology_tags"],
		"parameter_effects": draft["parameter_effects"],
		"minimal_repair_rules": draft["minimal_repair_rules"],
		"unknowns": draft["unknowns"],
		"evidence": evidence,
		"supersedes": draft.get("supersedes", []),
		"recorded_utc": Time.get_datetime_string_from_system(true, false) + "Z",
	}
	entry["admission"] = {
		"policy": ADMISSION_POLICY,
		"payload_sha256": CanonicalJsonScript.sha256(entry),
	}
	var schema_result := SchemaValidatorScript.validate_file(ENTRY_SCHEMA_PATH, entry)
	if not schema_result["ok"]:
		return _failure(
			"KNOWLEDGE_ENTRY_SCHEMA_INVALID",
			"Proposed entry does not satisfy the knowledge contract.",
			schema_result["errors"]
		)
	return {
		"ok": true,
		"entry": FrozenValueScript.snapshot(entry),
		"bundle_validation": validation,
	}


static func inspect_bundle(bundle_path: String, validation_options: Dictionary = {}) -> Dictionary:
	var absolute := _normalized_absolute(bundle_path)
	var required_options := validation_options.duplicate(true)
	# Knowledge is a long-lived consuming boundary. A caller cannot weaken it
	# to structural-only validation; development observations require a valid
	# detached receipt just as accepted entries do.
	required_options["attestation_requirement"] = "required"
	var validation_before: Dictionary = BundleValidatorScript.validate_bundle(
		absolute, required_options
	)
	if (
		not bool(validation_before.get("ok", false))
		or not bool(validation_before.get("can_finalize", false))
	):
		return _failure(
			"BUNDLE_NOT_ADMISSIBLE",
			"Knowledge requires a completed bundle with a valid detached publication receipt.",
			validation_before
		)
	var snapshot_options: Dictionary = {}
	if required_options.has("attestation_test_root"):
		snapshot_options["attestation_test_root"] = String(
			required_options["attestation_test_root"]
		)
	var captured := AttestedBundleSnapshotScript.capture_verified(absolute, snapshot_options)
	if not bool(captured.get("ok", false)):
		return _failure(
			"KNOWLEDGE_SOURCE_READ_FAILED",
			"Knowledge source could not be captured as one authenticated read-once snapshot.",
			captured
		)
	var snapshot = captured["snapshot"]
	var attestation_before := _publication_attestation_witness(validation_before)
	var snapshot_witness: Dictionary = snapshot.publication_witness()
	if attestation_before != snapshot_witness:
		return _failure(
			"KNOWLEDGE_SOURCE_CHANGED_DURING_ADMISSION",
			"Validator and read-once snapshot do not identify the same publication.",
			{
				"validator": attestation_before,
				"snapshot": snapshot_witness,
			}
		)
	var captured_provenance := _capture_snapshot_provenance(absolute, snapshot)
	if not captured_provenance["ok"]:
		return captured_provenance
	# Defense in depth for a persistent replacement after capture. Every
	# knowledge value itself is parsed only from the exact HMAC-bound snapshot
	# buffers, so an ABA restore cannot substitute unauthenticated values.
	var validation_after: Dictionary = BundleValidatorScript.validate_bundle(
		absolute, required_options
	)
	if (
		not bool(validation_after.get("ok", false))
		or not bool(validation_after.get("can_finalize", false))
	):
		return _failure(
			"BUNDLE_NOT_ADMISSIBLE",
			"Knowledge source failed detached publication verification after its evidence was read.",
			validation_after
		)
	var attestation_after := _publication_attestation_witness(validation_after)
	if attestation_before != attestation_after:
		return _failure(
			"KNOWLEDGE_SOURCE_CHANGED_DURING_ADMISSION",
			"Detached publication identity changed while evidence was being inspected.",
			{
				"before": attestation_before,
				"after": attestation_after,
			}
		)
	var evidence: Dictionary = captured_provenance["immutable_provenance"].duplicate(true)
	evidence["bundle_can_promote"] = bool(validation_after["can_promote"])
	evidence["publication_attestation"] = attestation_after
	return {
		"ok": true,
		"bundle_validation": validation_after,
		"manifest": captured_provenance["manifest"],
		"summary": captured_provenance["summary"],
		"checksums": captured_provenance["checksums"],
		"evidence": evidence,
	}


static func verify_entry(
	entry: Dictionary, require_live_promotion := false, validation_options: Dictionary = {}
) -> Dictionary:
	if String(entry.get("schema", "")) == Br3aKnowledgeBaseScript.ENTRY_SCHEMA:
		return Br3aKnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br3bKnowledgeBaseScript.ENTRY_SCHEMA:
		return Br3bKnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br4KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br4KnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br6aKnowledgeBaseScript.ENTRY_SCHEMA:
		return Br6aKnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br7KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br7KnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br8KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br8KnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br9KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br9KnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br10KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br10KnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br11KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br11KnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br12KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br12KnowledgeBaseScript.verify_entry(entry)
	if String(entry.get("schema", "")) == Br13KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br13KnowledgeBaseScript.verify_entry(entry)
	var schema_validation := SchemaValidatorScript.validate_file(ENTRY_SCHEMA_PATH, entry)
	if not schema_validation["ok"]:
		return _failure(
			"KNOWLEDGE_ENTRY_SCHEMA_INVALID",
			"Entry failed knowledge-schema validation.",
			schema_validation["errors"]
		)
	var admission: Dictionary = entry["admission"]
	var payload_sha256 := _entry_payload_sha256(entry)
	if (
		String(admission["policy"]) != ADMISSION_POLICY
		or String(admission["payload_sha256"]) != payload_sha256
	):
		return _failure(
			"KNOWLEDGE_ADMISSION_DIGEST_MISMATCH",
			"Entry content changed after its admission payload was sealed.",
			{
				"recorded": admission["payload_sha256"],
				"observed": payload_sha256,
			}
		)
	var evidence: Dictionary = entry["evidence"]
	var inspection := inspect_bundle(String(evidence["bundle_path"]), validation_options)
	if not inspection["ok"]:
		return _failure(
			"KNOWLEDGE_PROVENANCE_INVALID",
			"The referenced evidence bundle is absent, mutable, or invalid.",
			inspection
		)
	var expected: Dictionary = inspection["evidence"]
	for field in [
		"bundle_path",
		"run_id",
		"experiment_id",
		"expanded_spec_sha256",
		"manifest_sha256",
		"summary_sha256",
		"checksums_sha256",
		"evidence_validity",
		"hypothesis_result",
		"promotion",
		"observed_metric_ids",
		"publication_attestation",
	]:
		# Godot's JSON parser may surface an exact JSON integer as 4.0 after an
		# append/read cycle. Compare the canonical value domain used to seal the
		# entry, where integral floats and integers intentionally normalize to
		# the same exact representation.
		if (
			CanonicalJsonScript.normalize(evidence[field])
			!= CanonicalJsonScript.normalize(expected[field])
		):
			return _failure(
				"KNOWLEDGE_PROVENANCE_MISMATCH",
				"Entry evidence does not match the sealed bundle field: %s" % field,
				{
					"field": field,
					"recorded": evidence[field],
					"observed": expected[field],
				}
			)
	var status_policy := _validate_status_policy(
		String(entry["claim_status"]),
		evidence,
		inspection["manifest"],
		inspection["summary"],
		inspection["bundle_validation"],
		require_live_promotion
	)
	if not status_policy["ok"]:
		return status_policy
	if String(entry["entry_id"]) in entry.get("supersedes", []):
		return _failure("KNOWLEDGE_SELF_SUPERSESSION", "A knowledge entry cannot supersede itself.")
	return {
		"ok": true,
		"entry": FrozenValueScript.snapshot(entry),
		"bundle_validation": inspection["bundle_validation"],
	}


static func write_new_entry(
	path: String, entry: Dictionary, validation_options: Dictionary = {}
) -> Dictionary:
	if String(entry.get("schema", "")) == Br3aKnowledgeBaseScript.ENTRY_SCHEMA:
		return Br3aKnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br3bKnowledgeBaseScript.ENTRY_SCHEMA:
		return Br3bKnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br4KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br4KnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br6aKnowledgeBaseScript.ENTRY_SCHEMA:
		return Br6aKnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br7KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br7KnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br8KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br8KnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br9KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br9KnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br10KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br10KnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br11KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br11KnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br12KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br12KnowledgeBaseScript.write_new_entry(path, entry)
	if String(entry.get("schema", "")) == Br13KnowledgeBaseScript.ENTRY_SCHEMA:
		return Br13KnowledgeBaseScript.write_new_entry(path, entry)
	var absolute := _normalized_absolute(path)
	if not absolute.to_lower().ends_with(".json"):
		return _failure("KNOWLEDGE_ENTRY_PATH_INVALID", "Knowledge entry paths must end in .json.")
	if FileAccess.file_exists(absolute):
		return _failure(
			"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
			"Knowledge entries are append-only; supersede instead of overwrite."
		)
	var provenance := verify_entry(entry, true, validation_options)
	if not provenance["ok"]:
		return provenance
	var parent := absolute.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure("KNOWLEDGE_DIRECTORY_CREATE_FAILED", error_string(directory_error))
	var reservation := "%s.admission-lock" % absolute
	var reservation_error := DirAccess.make_dir_absolute(reservation)
	if reservation_error != OK:
		if FileAccess.file_exists(absolute):
			return _failure(
				"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
				"Knowledge entries are append-only; supersede instead of overwrite."
			)
		return _failure(
			"KNOWLEDGE_ENTRY_LOCKED",
			"Another admission owns this output path, or a prior admission left a lock.",
			error_string(reservation_error)
		)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(reservation)
		return _failure(
			"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
			"Knowledge entries are append-only; supersede instead of overwrite."
		)
	var temporary := reservation.path_join(
		"entry-%d-%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(reservation)
		return _failure("KNOWLEDGE_TEMP_OPEN_FAILED", "Cannot open entry temp file.")
	var serialized := CanonicalJsonScript.stringify(entry) + "\n"
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure("KNOWLEDGE_WRITE_FAILED", error_string(write_error))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure(
			"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
			"Knowledge entries are append-only; supersede instead of overwrite."
		)
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		if FileAccess.file_exists(absolute):
			return _failure(
				"KNOWLEDGE_ENTRY_ALREADY_EXISTS",
				"Knowledge entries are append-only; supersede instead of overwrite."
			)
		return _failure("KNOWLEDGE_RENAME_FAILED", error_string(rename_error))
	var installed_matches := FileAccess.get_file_as_string(absolute) == serialized
	DirAccess.remove_absolute(reservation)
	if not installed_matches:
		return _failure(
			"KNOWLEDGE_INSTALL_INTEGRITY_FAILED",
			"Installed entry bytes do not match the admitted canonical payload."
		)
	return {
		"ok": true,
		"code": "",
		"path": absolute,
		"sha256": _file_sha256(absolute),
	}


static func _capture_snapshot_provenance(absolute: String, snapshot: RefCounted) -> Dictionary:
	var manifest_result: Dictionary = snapshot.read_json_object("manifest.json")
	var summary_result: Dictionary = snapshot.read_json_object("summary.json")
	var checksums_result: Dictionary = snapshot.read_json_object("checksums.json")
	if not manifest_result["ok"] or not summary_result["ok"] or not checksums_result["ok"]:
		return _failure(
			"KNOWLEDGE_SOURCE_READ_FAILED",
			"Bundle manifest, summary, or checksums could not be read as JSON objects."
		)
	var manifest: Dictionary = manifest_result["value"]
	var summary: Dictionary = summary_result["value"]
	var metric_ids: Array = []
	for metric_value in summary.get("metrics", []):
		if metric_value is Dictionary:
			metric_ids.append(String(metric_value.get("metric_id", "")))
	metric_ids.sort()
	return {
		"ok": true,
		"manifest": manifest,
		"summary": summary,
		"checksums": checksums_result["value"],
		"immutable_provenance":
		{
			"bundle_path": absolute,
			"run_id": manifest.get("run_id", ""),
			"experiment_id": manifest.get("experiment_id", ""),
			"expanded_spec_sha256": manifest.get("expanded_spec_sha256", ""),
			"manifest_sha256": snapshot.sha256("manifest.json"),
			"summary_sha256": snapshot.sha256("summary.json"),
			"checksums_sha256": snapshot.sha256("checksums.json"),
			"evidence_validity": summary.get("evidence_validity", ""),
			"hypothesis_result": summary.get("hypothesis_result", ""),
			"promotion": summary.get("promotion", ""),
			"observed_metric_ids": metric_ids,
		},
	}


static func _publication_attestation_witness(validation: Dictionary) -> Dictionary:
	var stats: Dictionary = validation.get("stats", {})
	var attestation: Dictionary = stats.get("publication_attestation", {})
	return {
		"ok": bool(attestation.get("ok", false)),
		"algorithm": String(attestation.get("algorithm", "")),
		"trust_mode": String(attestation.get("trust_mode", "")),
		"key_id": String(attestation.get("key_id", "")),
		"receipt_sha256": String(attestation.get("receipt_sha256", "")),
		"run_id": String(attestation.get("run_id", "")),
		"checksums_sha256": String(attestation.get("checksums_sha256", "")),
		"manifest_sha256": String(attestation.get("manifest_sha256", "")),
		"artifact_count": int(attestation.get("artifact_count", -1)),
		"attested_utc": String(attestation.get("attested_utc", "")),
	}


static func _validate_status_policy(
	status: String,
	evidence: Dictionary,
	manifest: Dictionary,
	summary: Dictionary,
	validation: Dictionary,
	require_live_promotion: bool
) -> Dictionary:
	var declares_promotion := (
		not bool(manifest.get("dirty_worktree", true))
		and String(manifest.get("execution_mode", "")) == "promotion"
		and String(manifest.get("reproducibility", "")) == "clean_committed_source"
		and String(summary.get("evidence_validity", "")) == "valid"
		and String(summary.get("promotion", "")) == "pass"
	)
	if status == "development_observation":
		if bool(evidence.get("bundle_can_promote", true)):
			return _failure(
				"DEVELOPMENT_KNOWLEDGE_CANNOT_PROMOTE",
				"Development observations must retain bundle_can_promote=false."
			)
		if declares_promotion or bool(validation.get("can_promote", false)):
			return _failure(
				"PROMOTABLE_EVIDENCE_REQUIRES_PROMOTED_STATUS",
				"Promotion evidence cannot be relabeled as developmental."
			)
		return {"ok": true}
	if status not in PROMOTED_STATUSES:
		return _failure("KNOWLEDGE_STATUS_INVALID", "Requested claim status is not versioned.")
	if not bool(evidence.get("bundle_can_promote", false)) or not declares_promotion:
		return _failure(
			"KNOWLEDGE_STATUS_EVIDENCE_MISMATCH",
			"Accepted, refuted, and retired entries require a recorded promotable bundle."
		)
	if require_live_promotion and not bool(validation.get("can_promote", false)):
		return _failure(
			"KNOWLEDGE_STATUS_REQUIRES_PROMOTION",
			"The bundle does not pass the live promotion gate.",
			validation.get("promotion_blockers", [])
		)
	if status == "refuted" and String(summary.get("hypothesis_result", "")) != "contradicted":
		return _failure(
			"REFUTED_KNOWLEDGE_REQUIRES_CONTRADICTION",
			"A refuted entry requires hypothesis_result=contradicted."
		)
	return {"ok": true}


static func _file_sha256(path: String) -> String:
	return "sha256:%s" % FileAccess.get_sha256(path)


static func _normalized_absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()


static func _entry_payload_sha256(entry: Dictionary) -> String:
	var payload: Dictionary = {}
	for key_value in entry:
		if String(key_value) != "admission":
			payload[key_value] = entry[key_value]
	return CanonicalJsonScript.sha256(payload)


static func _failure(code: String, message: String, details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message,
		"details": details,
	}
