class_name LabBr9CertificationReportAttestation
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# Report authentication and complete evidence readback intentionally remain one
# auditable trust boundary, matching the released certification attester.

## Detached authentication for a complete BR9 existing-contact brace report.
##
## The report receipt is stored outside the repository and evidence tree. The
## verifier re-reads every declared capsule through the generic production
## publication verifier before authenticating the report. Test-root APIs are
## explicit and can never return can_promote=true.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const PublicationAttestationScript := preload("res://scripts/lab/publication_attestation.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const RECEIPT_SCHEMA := "sporespore.lab.br9_certification_report_attestation.v1"
const RECEIPT_DOMAIN := RECEIPT_SCHEMA
const REPORT_SCHEMA := "sporespore.lab.br9_certification_report.v1"
const CERTIFICATION := "BR9_EXISTING_CONTACT_PLANAR_BRACE"
const CAMPAIGN_ID := "BR9_EXISTING_CONTACT_BRACE_PROMOTION_CAMPAIGN_V1"
const REPORT_NAME := "br9_certification_report.json"
const ALGORITHM := "hmac-sha256"
const ACTIVE_KEY_SCHEMA := "sporespore.lab_attestation.active_key.v1"
const ACTIVE_KEY_FILE := "active_key.json"
const RECEIPT_DIRECTORY := "br9_certification_reports_v1/receipts"
const RECEIPT_SCHEMA_PATH := (
	"res://data/lab/schemas/" + "br9_certification_report_attestation_v1.schema.json"
)
const REPORT_SCHEMA_PATH := "res://data/lab/schemas/br9_certification_report_v1.schema.json"
const CAMPAIGN_SCHEMA_PATH := "res://data/lab/schemas/br9_existing_contact_brace_promotion_campaign_v1.schema.json"
const CAPSULE_SCHEMA_PATH := "res://data/lab/schemas/br9_existing_contact_brace_evidence_capsule_v1.schema.json"
const METRICS_SCHEMA_PATH := "res://data/lab/schemas/br9_existing_contact_brace_evidence_metrics_v1.schema.json"
const SOURCE_INVENTORY_SCHEMA_PATH := (
	"res://data/lab/schemas/" + "br9_existing_contact_brace_source_inventory_v1.schema.json"
)
const MANIFEST_SCHEMA_PATH := "res://data/lab/schemas/manifest_v1.schema.json"
const KEY_BYTES := 32
const MAX_REPORT_BYTES := 64 * 1024 * 1024
const CHUNK_BYTES := 65536


static func production_trust_root() -> String:
	return PublicationAttestationScript.production_trust_root()


static func attest_production(report_path: String, certification_id: String) -> Dictionary:
	var root := production_trust_root()
	if root.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"LOCALAPPDATA is unavailable; the production trust root cannot be resolved."
		)
	return _attest(report_path, certification_id, root, "", "production")


static func verify_production(report_path: String, certification_id: String) -> Dictionary:
	var root := production_trust_root()
	if root.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"LOCALAPPDATA is unavailable; the production trust root cannot be resolved."
		)
	return _verify(report_path, certification_id, root, "production")


static func attest_with_test_trust_root(
	report_path: String,
	certification_id: String,
	test_trust_root: String,
	attested_utc: String = ""
) -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not bool(root_result.get("ok", false)):
		return root_result
	return _attest(
		report_path, certification_id, String(root_result["trust_root"]), attested_utc, "test"
	)


static func verify_with_test_trust_root(
	report_path: String, certification_id: String, test_trust_root: String
) -> Dictionary:
	var root_result := _validate_test_trust_root(test_trust_root)
	if not bool(root_result.get("ok", false)):
		return root_result
	return _verify(report_path, certification_id, String(root_result["trust_root"]), "test")


static func receipt_path_for_certification_id(
	trust_root: String, certification_id: String
) -> String:
	if not _is_safe_certification_id(certification_id):
		return ""
	var root := _normalized_absolute(trust_root)
	if root.is_empty():
		return ""
	return root.path_join(RECEIPT_DIRECTORY).path_join("%s.json" % certification_id.sha256_text())


static func _attest(
	report_path: String,
	certification_id: String,
	trust_root: String,
	attested_utc: String,
	trust_mode: String
) -> Dictionary:
	var paths := _validate_paths(report_path, trust_root)
	if not bool(paths.get("ok", false)):
		return paths
	var inspected := _inspect_report(
		String(paths["report_path"]), certification_id, trust_root, trust_mode
	)
	if not bool(inspected.get("ok", false)):
		return inspected
	var active := _load_active_key_reference(String(paths["trust_root"]))
	if not bool(active.get("ok", false)):
		return active
	var instant := attested_utc.strip_edges()
	if instant.is_empty():
		instant = _utc_now()
	var envelope := _unsigned_envelope(String(active["key_id"]), inspected, instant)
	var key_result := _load_key_by_id(String(paths["trust_root"]), String(active["key_id"]))
	if not bool(key_result.get("ok", false)):
		return key_result
	var key := _take_loaded_key(key_result)
	var hmac := _hmac_sha256(key, CanonicalJsonScript.encode(envelope))
	key.fill(0)
	key.resize(0)
	if not bool(hmac.get("ok", false)):
		return hmac
	var receipt: Dictionary = envelope.duplicate(true)
	receipt["tag"] = "%s:%s" % [ALGORITHM, String(hmac["hex"])]
	var schema_result := SchemaValidatorScript.validate_file(RECEIPT_SCHEMA_PATH, receipt)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Generated BR9 report receipt failed its owned schema.",
			{"errors": schema_result.get("errors", [])}
		)
	var receipt_path := receipt_path_for_certification_id(
		String(paths["trust_root"]), certification_id
	)
	var write_result := _write_receipt_new(receipt_path, receipt)
	if not bool(write_result.get("ok", false)):
		return write_result
	return _verify(
		String(paths["report_path"]), certification_id, String(paths["trust_root"]), trust_mode
	)


static func _verify(
	report_path: String, certification_id: String, trust_root: String, trust_mode: String
) -> Dictionary:
	var paths := _validate_paths(report_path, trust_root)
	if not bool(paths.get("ok", false)):
		return paths
	var inspected := _inspect_report(
		String(paths["report_path"]), certification_id, trust_root, trust_mode
	)
	if not bool(inspected.get("ok", false)):
		return inspected
	var receipt_path := receipt_path_for_certification_id(
		String(paths["trust_root"]), certification_id
	)
	if not FileAccess.file_exists(receipt_path):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_MISSING,
			"No detached BR9 certification-report receipt exists.",
			{"receipt_path": receipt_path}
		)
	var receipt_result := _read_json_object_exact(receipt_path, MAX_REPORT_BYTES)
	if not bool(receipt_result.get("ok", false)):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached BR9 report receipt is not strict UTF-8 JSON."
		)
	var receipt: Dictionary = receipt_result["value"]
	var schema_result := SchemaValidatorScript.validate_file(RECEIPT_SCHEMA_PATH, receipt)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached BR9 report receipt failed its owned schema.",
			{"errors": schema_result.get("errors", [])}
		)
	var canonical_bytes := (CanonicalJsonScript.stringify(receipt) + "\n").to_utf8_buffer()
	if not _bytes_equal(receipt_result["bytes"], canonical_bytes):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"Detached BR9 report receipt is not canonically encoded."
		)
	var expected_envelope := _unsigned_envelope(
		String(receipt["key_id"]), inspected, String(receipt["attested_utc"])
	)
	var recorded_envelope: Dictionary = receipt.duplicate(true)
	recorded_envelope.erase("tag")
	if (
		CanonicalJsonScript.stringify(expected_envelope)
		!= CanonicalJsonScript.stringify(recorded_envelope)
	):
		return _failure(
			FailureCodesScript.PUBLICATION_ENVELOPE_MISMATCH,
			"Detached BR9 report receipt contradicts the report bytes or identity."
		)
	var key_result := _load_key_by_id(String(paths["trust_root"]), String(receipt["key_id"]))
	if not bool(key_result.get("ok", false)):
		return key_result
	var key := _take_loaded_key(key_result)
	var hmac := _hmac_sha256(key, CanonicalJsonScript.encode(recorded_envelope))
	key.fill(0)
	key.resize(0)
	if not bool(hmac.get("ok", false)):
		return hmac
	var expected_tag := "%s:%s" % [ALGORITHM, String(hmac["hex"])]
	if not _constant_time_equal(String(receipt["tag"]), expected_tag):
		return _failure(
			FailureCodesScript.PUBLICATION_TAG_MISMATCH,
			"Detached BR9 certification-report authentication failed."
		)
	return {
		"ok": true,
		"can_promote": trust_mode == "production",
		"trust_mode": trust_mode,
		"algorithm": ALGORITHM,
		"key_id": String(receipt["key_id"]),
		"receipt_path": receipt_path,
		"receipt_sha256": _sha256_bytes(receipt_result["bytes"]),
		"certification_id": certification_id,
		"report_path": String(paths["report_path"]),
		"report_sha256": String(receipt["report_sha256"]),
		"report_bytes": int(receipt["report_bytes"]),
		"report_schema": REPORT_SCHEMA,
		"report_status": "pass",
		"certification": CERTIFICATION,
		"commit_sha": String(receipt["commit_sha"]),
		"campaign_id": CAMPAIGN_ID,
		"campaign_sha256": String(receipt["campaign_sha256"]),
		"attested_utc": String(receipt["attested_utc"]),
	}


static func _inspect_report(
	report_path: String, certification_id: String, trust_root: String, trust_mode: String
) -> Dictionary:
	if not _is_safe_certification_id(certification_id):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "BR9 certification_id has an unsafe format."
		)
	if report_path.get_file() != REPORT_NAME:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 certification report has an unexpected filename."
		)
	var report_result := _read_json_object_exact(report_path, MAX_REPORT_BYTES)
	if not bool(report_result.get("ok", false)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 certification report is not strict UTF-8 JSON."
		)
	var report: Dictionary = report_result["value"]
	var report_schema := SchemaValidatorScript.validate_file(REPORT_SCHEMA_PATH, report)
	if not bool(report_schema.get("ok", false)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 certification report failed its owned schema.",
			{"errors": report_schema.get("errors", [])}
		)
	if String(report.get("certification_id", "")) != certification_id:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 report and caller identify different certifications."
		)
	var source: Dictionary = report["source"]
	var project_root := _normalized_absolute(ProjectSettings.globalize_path("res://"))
	var expected_campaign_path := project_root.path_join(
		"data/lab/campaigns/BR9_existing_contact_brace_promotion_campaign_v1.json"
	)
	var expected_br1_inventory_path := project_root.path_join(
		"data/lab/campaigns/BR1_required_lab_tests_v2.json"
	)
	var campaign_path := _normalized_absolute(String(source["campaign_path"]))
	var running_engine := _normalized_absolute(OS.get_executable_path())
	var report_engine: Dictionary = report["engine"]
	if (
		_path_identity(String(source["repository_root"])) != _path_identity(project_root)
		or _path_identity(campaign_path) != _path_identity(expected_campaign_path)
		or (
			_path_identity(String(source["br1_inventory_path"]))
			!= _path_identity(expected_br1_inventory_path)
		)
		or _path_identity(String(report_engine["executable"])) != _path_identity(running_engine)
		or _sha256_file(running_engine) != String(report_engine["sha256"])
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 report paths or running engine identity differ from live inputs."
		)
	var campaign_result := _read_json_object_exact(campaign_path, MAX_REPORT_BYTES)
	if (
		not bool(campaign_result.get("ok", false))
		or (
			_sha256_bytes(campaign_result.get("bytes", PackedByteArray()))
			!= String(source["campaign_sha256"])
		)
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 campaign bytes are missing or differ from the report witness."
		)
	var campaign: Dictionary = campaign_result["value"]
	var campaign_schema := SchemaValidatorScript.validate_file(CAMPAIGN_SCHEMA_PATH, campaign)
	if not bool(campaign_schema.get("ok", false)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "BR9 campaign failed its owned schema."
		)
	if String(report["claim_boundary"]) != String(campaign["claim_boundary"]):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 report claim boundary differs from the campaign."
		)
	if (
		CanonicalJsonScript.stringify(report["does_not_establish"])
		!= (CanonicalJsonScript.stringify(campaign["does_not_establish"]))
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "BR9 report non-claims differ from the campaign."
		)
	var expected_paths_result := _expected_source_paths(campaign, project_root)
	if not bool(expected_paths_result.get("ok", false)):
		return expected_paths_result
	var expected_source_paths: Array = expected_paths_result["paths"]
	var declared_programs: Array = campaign["programs"]
	var reported_programs: Array = report["programs"]
	if declared_programs.size() != 5 or reported_programs.size() != 5:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 report does not contain the complete 5-program campaign."
		)
	var target_process_windows: Dictionary = {}
	var target_process_invocations := 0
	var pid_recycle_events := 0
	var bundle_paths: Dictionary = {}
	var assertions_total := 0
	var role_assertions := {"milestone": 0, "supplementary": 0, "integrity": 0}
	var common_inventory_sha := ""
	var common_inventory_count := -1
	for program_index in declared_programs.size():
		var declared: Dictionary = declared_programs[program_index]
		var program: Dictionary = reported_programs[program_index]
		var expected_test := String(declared["test_resource_path"]).get_file()
		if (
			String(program["program_id"]) != String(declared["program_id"])
			or String(program["cell_id"]) != String(declared["cell_id"])
			or String(program["evidence_role"]) != String(declared["evidence_role"])
			or String(program["test"]) != expected_test
			or int(program["expected_assertions"]) != int(declared["expected_assertions"])
			or String(program["claim_scope"]) != String(declared["claim_scope"])
		):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"BR9 report program order or identity differs from the campaign."
			)
		var metrics_per_replicate: Array = []
		var replicates: Array = program["replicates"]
		for replicate_index in 2:
			var replicate: Dictionary = replicates[replicate_index]
			var inspected := _inspect_capsule(
				replicate,
				declared,
				replicate_index + 1,
				String(source["commit_sha"]),
				String(source["campaign_sha256"]),
				certification_id,
				String(report["claim_boundary"]),
				expected_source_paths,
				trust_root,
				trust_mode
			)
			if not bool(inspected.get("ok", false)):
				return inspected
			var pid := int(inspected["target_process_id"])
			var bundle_identity := _path_identity(String(replicate["bundle_path"]))
			if bundle_paths.has(bundle_identity):
				return _failure(
					FailureCodesScript.EVIDENCE_INVALID, "BR9 campaign reused a bundle path."
				)
			if target_process_windows.has(pid):
				var prior_window: Dictionary = target_process_windows[pid]
				if String(prior_window["ended_utc"]) > String(inspected["started_utc"]):
					return _failure(
						FailureCodesScript.EVIDENCE_INVALID,
						"A recycled BR9 target PID has overlapping run windows."
					)
				pid_recycle_events += 1
			target_process_windows[pid] = {
				"started_utc": String(inspected["started_utc"]),
				"ended_utc": String(inspected["ended_utc"]),
			}
			target_process_invocations += 1
			bundle_paths[bundle_identity] = true
			assertions_total += int(inspected["assertions_passed"])
			var role := String(declared["evidence_role"])
			role_assertions[role] = int(role_assertions[role]) + int(inspected["assertions_passed"])
			if common_inventory_sha.is_empty():
				common_inventory_sha = String(inspected["source_inventory_sha256"])
				common_inventory_count = int(inspected["source_file_count"])
			elif (
				common_inventory_sha != String(inspected["source_inventory_sha256"])
				or common_inventory_count != int(inspected["source_file_count"])
			):
				return _failure(
					FailureCodesScript.EVIDENCE_INVALID,
					"BR9 capsules do not share one exact source inventory."
				)
			metrics_per_replicate.append(inspected["metrics"])
		if (
			CanonicalJsonScript.stringify(
				(metrics_per_replicate[0] as Dictionary)["assertion_labels"]
			)
			!= CanonicalJsonScript.stringify(
				(metrics_per_replicate[1] as Dictionary)["assertion_labels"]
			)
		):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"BR9 replicate assertion labels do not reconcile exactly."
			)
	var final_readback: Dictionary = report["final_readback"]
	if (
		target_process_invocations != 10
		or bundle_paths.size() != 10
		or assertions_total != 120
		or int(role_assertions["milestone"]) != 78
		or int(role_assertions["supplementary"]) != 0
		or int(role_assertions["integrity"]) != 42
		or common_inventory_sha != String(source["source_inventory_sha256"])
		or common_inventory_count != int(source["source_file_count"])
		or int(final_readback["target_process_invocations"]) != target_process_invocations
		or int(final_readback["unique_target_processes"]) != target_process_windows.size()
		or int(final_readback["pid_recycle_events"]) != pid_recycle_events
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 final accounting does not match the complete campaign."
		)
	return {
		"ok": true,
		"report_sha256": _sha256_bytes(report_result["bytes"]),
		"report_bytes": (report_result["bytes"] as PackedByteArray).size(),
		"certification_id": certification_id,
		"commit_sha": String(source["commit_sha"]),
		"campaign_sha256": String(source["campaign_sha256"]),
	}


static func _inspect_capsule(
	replicate: Dictionary,
	declared: Dictionary,
	expected_replicate: int,
	expected_commit: String,
	expected_campaign_sha: String,
	expected_certification_id: String,
	expected_claim_boundary: String,
	expected_source_paths: Array,
	trust_root: String,
	trust_mode: String
) -> Dictionary:
	var bundle_path := _normalized_absolute(String(replicate["bundle_path"]))
	var attestation := (
		PublicationAttestationScript.verify_production(bundle_path)
		if trust_mode == "production"
		else PublicationAttestationScript.verify_with_test_trust_root(bundle_path, trust_root)
	)
	if not bool(attestation.get("ok", false)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"A BR9 capsule lacks a valid detached bundle receipt.",
			{"bundle_path": bundle_path, "attestation": attestation}
		)
	var report_attestation: Dictionary = replicate["attestation"]
	if (
		String(attestation.get("trust_mode", "")) != trust_mode
		or (
			String(attestation.get("receipt_sha256", ""))
			!= String(report_attestation["receipt_sha256"])
		)
		or (
			_path_identity(String(attestation.get("receipt_path", "")))
			!= _path_identity(String(report_attestation["receipt_path"]))
		)
		or String(attestation.get("key_id", "")) != String(report_attestation["key_id"])
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 report bundle-attestation witness is inconsistent."
		)
	if (
		String(attestation.get("run_id", "")) != String(replicate["bundle_id"])
		or String(attestation.get("manifest_sha256", "")) != String(replicate["manifest_sha256"])
		or String(attestation.get("checksums_sha256", "")) != String(replicate["checksums_sha256"])
		or int(attestation.get("artifact_count", -1)) != 7
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 bundle receipt contradicts the report's bundle index."
		)
	var manifest_path := bundle_path.path_join("manifest.json")
	var checksums_path := bundle_path.path_join("checksums.json")
	var capsule_path := bundle_path.path_join("capsule.json")
	var metrics_path := bundle_path.path_join("metrics.json")
	var inventory_path := bundle_path.path_join("source_inventory.json")
	var harness_path := bundle_path.path_join("harness_report.json")
	var engine_log_path := bundle_path.path_join("engine.log")
	var transcript_path := bundle_path.path_join("transcript.log")
	var manifest_result := _read_json_object_exact(manifest_path, MAX_REPORT_BYTES)
	var capsule_result := _read_json_object_exact(capsule_path, MAX_REPORT_BYTES)
	var metrics_result := _read_json_object_exact(metrics_path, MAX_REPORT_BYTES)
	var inventory_result := _read_json_object_exact(inventory_path, MAX_REPORT_BYTES)
	var harness_result := _read_json_object_exact(harness_path, MAX_REPORT_BYTES)
	if not (
		bool(manifest_result.get("ok", false))
		and bool(capsule_result.get("ok", false))
		and bool(metrics_result.get("ok", false))
		and bool(inventory_result.get("ok", false))
		and bool(harness_result.get("ok", false))
		and FileAccess.file_exists(checksums_path)
		and FileAccess.file_exists(engine_log_path)
		and FileAccess.file_exists(transcript_path)
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "A BR9 capsule is missing a required artifact."
		)
	var manifest: Dictionary = manifest_result["value"]
	var capsule: Dictionary = capsule_result["value"]
	var metrics: Dictionary = metrics_result["value"]
	var inventory: Dictionary = inventory_result["value"]
	var harness: Dictionary = harness_result["value"]
	for schema_pair in [
		[MANIFEST_SCHEMA_PATH, manifest],
		[CAPSULE_SCHEMA_PATH, capsule],
		[METRICS_SCHEMA_PATH, metrics],
		[SOURCE_INVENTORY_SCHEMA_PATH, inventory],
	]:
		var schema_result := SchemaValidatorScript.validate_file(
			String(schema_pair[0]), schema_pair[1]
		)
		if not bool(schema_result.get("ok", false)):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"A BR9 capsule artifact failed its owned schema.",
				{"schema": schema_pair[0], "errors": schema_result.get("errors", [])}
			)
	var expected_program := String(declared["program_id"])
	var expected_test := String(declared["test_resource_path"]).get_file()
	var expected_bundle_id := (
		"%s.%s.r%d" % [expected_certification_id, expected_program, expected_replicate]
	)
	var inventory_sha := _sha256_bytes(inventory_result["bytes"])
	var metrics_sha := _sha256_bytes(metrics_result["bytes"])
	var manifest_sha := _sha256_bytes(manifest_result["bytes"])
	var capsule_sha := _sha256_bytes(capsule_result["bytes"])
	var harness_sha := _sha256_bytes(harness_result["bytes"])
	var checksums_sha := _sha256_file(checksums_path)
	var engine_sha := _sha256_file(engine_log_path)
	var transcript_sha := _sha256_file(transcript_path)
	var metrics_process: Dictionary = metrics["process"]
	var capsule_process: Dictionary = capsule["process"]
	var artifact_hashes: Dictionary = metrics["artifact_hashes"]
	var loaded_hashes: Dictionary = manifest["loaded_resource_hashes"]
	var campaign_resource := "res://data/lab/campaigns/BR9_existing_contact_brace_promotion_campaign_v1.json"
	var test_resource := String(declared["test_resource_path"])
	var test_path := _normalized_absolute(ProjectSettings.globalize_path(test_resource))
	var expected_nonclaims := _expected_does_not_establish(expected_program)
	var transcript_evidence := _extract_transcript_evidence(
		transcript_path, int(declared["expected_assertions"])
	)
	if not bool(transcript_evidence.get("ok", false)):
		return transcript_evidence
	var harness_inspection := _inspect_harness_report(
		harness, declared, replicate, engine_sha, transcript_sha
	)
	if not bool(harness_inspection.get("ok", false)):
		return harness_inspection
	if (
		String(replicate["bundle_id"]) != expected_bundle_id
		or String(manifest.get("run_id", "")) != expected_bundle_id
		or String(manifest.get("experiment_id", "")) != expected_program
		or (
			String(manifest.get("recorder_version", ""))
			!= "br9_existing_contact_brace_evidence_capsule_v1"
		)
		or String(manifest.get("git_commit", "")) != expected_commit
		or String(manifest.get("expanded_spec_sha256", "")) != expected_campaign_sha
		or manifest.get("dirty_worktree") != false
		or String(manifest.get("execution_mode", "")) != "promotion"
		or String(manifest.get("reproducibility", "")) != "clean_committed_source"
		or String(manifest.get("process_isolation", "")) != "outer_parent_reserved_fresh_godot_v1"
		or loaded_hashes.size() != 2
		or String(loaded_hashes.get(campaign_resource, "")) != expected_campaign_sha
		or String(loaded_hashes.get(test_resource, "")) != _sha256_file(test_path)
		or String(capsule["bundle_id"]) != expected_bundle_id
		or String(capsule["campaign_id"]) != CAMPAIGN_ID
		or String(capsule["certification_id"]) != expected_certification_id
		or String(capsule["program_id"]) != expected_program
		or String(capsule["cell_id"]) != String(declared["cell_id"])
		or String(capsule["evidence_role"]) != String(declared["evidence_role"])
		or int(capsule["replicate"]) != expected_replicate
		or String(capsule["source_commit_sha"]) != expected_commit
		or String(capsule["campaign_sha256"]) != expected_campaign_sha
		or String(capsule["source_inventory_sha256"]) != inventory_sha
		or String(capsule["metrics_sha256"]) != metrics_sha
		or String(capsule["harness_report_sha256"]) != harness_sha
		or String(capsule["engine_log_sha256"]) != engine_sha
		or String(capsule["transcript_log_sha256"]) != transcript_sha
		or String(capsule["claim_boundary"]) != expected_claim_boundary
		or String(metrics["program_id"]) != expected_program
		or String(metrics["cell_id"]) != String(declared["cell_id"])
		or String(metrics["evidence_role"]) != String(declared["evidence_role"])
		or String(metrics["test"]) != expected_test
		or int(metrics["replicate"]) != expected_replicate
		or String(metrics["source_commit_sha"]) != expected_commit
		or String(metrics["claim_scope"]) != String(declared["claim_scope"])
		or (
			CanonicalJsonScript.stringify(metrics["does_not_establish"])
			!= CanonicalJsonScript.stringify(expected_nonclaims)
		)
		or (
			int((metrics["harness"] as Dictionary)["assertions_passed"])
			!= int(declared["expected_assertions"])
		)
		or (metrics["assertion_labels"] as Array).size() != int(declared["expected_assertions"])
		or (
			CanonicalJsonScript.stringify(metrics["assertion_labels"])
			!= CanonicalJsonScript.stringify(transcript_evidence["assertion_labels"])
		)
		or (
			CanonicalJsonScript.stringify(metrics["observation_lines"])
			!= CanonicalJsonScript.stringify(transcript_evidence["observation_lines"])
		)
		or (
			int(metrics["transcript_line_count"])
			!= int(transcript_evidence["transcript_line_count"])
		)
		or String(artifact_hashes["harness_report"]) != harness_sha
		or String(artifact_hashes["engine_log"]) != engine_sha
		or String(artifact_hashes["transcript_log"]) != transcript_sha
		or String(artifact_hashes["source_inventory"]) != inventory_sha
		or String(replicate["manifest_sha256"]) != manifest_sha
		or String(replicate["checksums_sha256"]) != checksums_sha
		or String(replicate["capsule_sha256"]) != capsule_sha
		or String(replicate["metrics_sha256"]) != metrics_sha
		or String(replicate["source_inventory_sha256"]) != inventory_sha
		or (
			int(replicate["containment_host_process_id"])
			!= int(metrics_process["containment_host_process_id"])
		)
		or (
			String(replicate["assertion_labels_sha256"])
			!= CanonicalJsonScript.sha256(metrics["assertion_labels"])
		)
		or String(replicate["transcript_sha256"]) != transcript_sha
		or int(replicate["assertions_passed"]) != int(declared["expected_assertions"])
		or int(replicate["target_process_id"]) != int(metrics_process["target_process_id"])
		or String(replicate["started_utc"]) != String(metrics_process["started_utc"])
		or String(replicate["ended_utc"]) != String(metrics_process["ended_utc"])
		or (
			int(capsule_process["containment_host_process_id"])
			!= int(metrics_process["containment_host_process_id"])
		)
		or int(capsule_process["target_process_id"]) != int(metrics_process["target_process_id"])
		or String(capsule_process["started_utc"]) != String(replicate["started_utc"])
		or String(capsule_process["ended_utc"]) != String(replicate["ended_utc"])
		or String(replicate["started_utc"]) > String(replicate["ended_utc"])
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"A BR9 capsule contradicts its campaign or report witness.",
			{"bundle_path": bundle_path}
		)
	var source_result := _verify_source_inventory(inventory, expected_commit, expected_source_paths)
	if not bool(source_result.get("ok", false)):
		return source_result
	return {
		"ok": true,
		"metrics": metrics,
		"target_process_id": int(replicate["target_process_id"]),
		"started_utc": String(replicate["started_utc"]),
		"ended_utc": String(replicate["ended_utc"]),
		"assertions_passed": int(declared["expected_assertions"]),
		"source_inventory_sha256": inventory_sha,
		"source_file_count": int(inventory["file_count"]),
	}


static func _inspect_harness_report(
	harness: Dictionary,
	declared: Dictionary,
	replicate: Dictionary,
	engine_log_sha: String,
	transcript_sha: String
) -> Dictionary:
	var results_value: Variant = harness.get("results", [])
	if typeof(results_value) != TYPE_ARRAY or (results_value as Array).size() != 1:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 harness report must contain exactly one result row."
		)
	var row_value: Variant = (results_value as Array)[0]
	if typeof(row_value) != TYPE_DICTIONARY:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "BR9 harness result row is not an object."
		)
	var row: Dictionary = row_value
	for array_field in [
		"unexpected_engine_errors",
		"missing_expected_engine_error_codes",
		"unknown_expected_engine_error_codes",
	]:
		if typeof(row.get(array_field, null)) != TYPE_ARRAY:
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"BR9 harness error-accounting fields must be arrays."
			)
	var expected_test := String(declared["test_resource_path"]).get_file()
	if (
		String(harness.get("schema", "")) != "sporespore.lab.test_report.v1"
		or String(harness.get("pattern", "")) != expected_test
		or int(harness.get("total", -1)) != 1
		or int(harness.get("passed", -1)) != 1
		or int(harness.get("failed", -1)) != 0
		or String(row.get("test", "")) != expected_test
		or String(row.get("status", "")) != "pass"
		or int(row.get("process_exit_code", -1)) != 0
		or row.get("timed_out", true) != false
		or row.get("containment_tree_closed", false) != true
		or row.get("exit_marker_observed", false) != true
		or row.get("footer_found", false) != true
		or int(row.get("footer_count", -1)) != 1
		or int(row.get("assertions_passed", -1)) != int(declared["expected_assertions"])
		or int(row.get("assertions_failed", -1)) != 0
		or (row.get("unexpected_engine_errors", []) as Array).size() != 0
		or (row.get("missing_expected_engine_error_codes", []) as Array).size() != 0
		or (row.get("unknown_expected_engine_error_codes", []) as Array).size() != 0
		or (
			int(row.get("containment_host_process_id", -1))
			!= int(replicate["containment_host_process_id"])
		)
		or int(row.get("target_process_id", -1)) != int(replicate["target_process_id"])
		or row.get("target_time_window_valid", false) != true
		or String(row.get("target_started_utc", "")) != String(replicate["started_utc"])
		or String(row.get("target_ended_utc", "")) != String(replicate["ended_utc"])
		or String(row.get("engine_log_sha256", "")) != engine_log_sha
		or String(row.get("transcript_log_sha256", "")) != transcript_sha
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 harness report contradicts the sealed capsule evidence."
		)
	return {"ok": true}


static func _extract_transcript_evidence(path: String, expected_assertions: int) -> Dictionary:
	var bytes_result := _read_file_bytes_exact(path, MAX_REPORT_BYTES)
	if not bool(bytes_result.get("ok", false)):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 transcript is missing, oversized, or not strict UTF-8."
		)
	var text := String(bytes_result["text"])
	var lines: Array = Array(text.split("\n", true))
	if text.ends_with("\n") and not lines.is_empty() and String(lines[-1]).is_empty():
		lines.pop_back()
	var pass_regex := RegEx.new()
	pass_regex.compile("^\\s+PASS\\s{2}(.+?)\\s*$")
	var fail_regex := RegEx.new()
	fail_regex.compile("^\\s+FAIL\\s{2}")
	var heading_regex := RegEx.new()
	heading_regex.compile("^===.+===$")
	var labels: Array = []
	var observations: Array = []
	for line_value in lines:
		var line := String(line_value).trim_suffix("\r")
		var pass_match := pass_regex.search(line)
		if pass_match != null:
			labels.append(pass_match.get_string(1).strip_edges())
			continue
		if fail_regex.search(line) != null:
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"A passing BR9 transcript contains a FAIL assertion line."
			)
		if (
			line.strip_edges().is_empty()
			or line.begins_with("Godot Engine v")
			or heading_regex.search(line) != null
		):
			continue
		observations.append(line.strip_edges(false, true))
	if labels.size() != expected_assertions:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"BR9 transcript assertion count differs from the campaign."
		)
	return {
		"ok": true,
		"assertion_labels": labels,
		"observation_lines": observations,
		"transcript_line_count": lines.size(),
	}


static func _expected_does_not_establish(_program_id: String) -> Array:
	var values: Array = [
		"per_contact_per_foot_or_toe_measured_load_allocation",
		"free_3d_standing_or_unconstrained_balance",
		"absent_negligible_or_measured_out_of_plane_scaffold_reaction",
		"bracing_or_fall_arrest",
		"self_righting_or_getting_up",
		"gait_or_walking",
		"morphology_terrain_complex_foot_or_endurance_claim",
		"accepted_knowledge_or_automatic_guidance",
	]
	return values


static func _expected_source_paths(campaign: Dictionary, project_root: String) -> Dictionary:
	var path_set: Dictionary = {}
	for root_value in campaign["source_policy"]["inventory_roots"]:
		var root: Dictionary = root_value
		var relative := String(root["path"]).replace("\\", "/")
		var absolute := _normalized_absolute(project_root.path_join(relative))
		if not _is_descendant(absolute, project_root):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"A BR9 source-inventory root escapes the repository."
			)
		if String(root["kind"]) == "file":
			if not FileAccess.file_exists(absolute) or _path_contains_link(absolute):
				return _failure(
					FailureCodesScript.EVIDENCE_INVALID,
					"A declared BR9 source file is missing or link-backed."
				)
			path_set[relative] = true
			continue
		var extensions: Dictionary = {}
		for extension_value in root["extensions"]:
			extensions[String(extension_value).to_lower()] = true
		var collected := _collect_source_tree(absolute, project_root, extensions, path_set)
		if not bool(collected.get("ok", false)):
			return collected
	for program_value in campaign["programs"]:
		var resource_path := String(program_value["test_resource_path"])
		var relative_test := resource_path.trim_prefix("res://")
		var absolute_test := _normalized_absolute(ProjectSettings.globalize_path(resource_path))
		if (
			not _is_descendant(absolute_test, project_root)
			or not FileAccess.file_exists(absolute_test)
			or _path_contains_link(absolute_test)
		):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"A declared BR9 test resource is missing or unsafe."
			)
		path_set[relative_test] = true
	var paths: Array = path_set.keys()
	paths.sort()
	return {"ok": true, "paths": paths}


static func _collect_source_tree(
	absolute: String, project_root: String, extensions: Dictionary, path_set: Dictionary
) -> Dictionary:
	if not DirAccess.dir_exists_absolute(absolute) or _path_contains_link(absolute):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID,
			"A declared BR9 source tree is missing or link-backed."
		)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "A declared BR9 source tree cannot be opened."
		)
	var entries: Array = []
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			(
				entries
				. append(
					{
						"name": name,
						"directory": directory.current_is_dir(),
						"link": directory.is_link(name),
					}
				)
			)
		name = directory.get_next()
	directory.list_dir_end()
	entries.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left["name"]) < String(right["name"])
	)
	for entry_value in entries:
		var entry: Dictionary = entry_value
		if bool(entry["link"]):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"A declared BR9 source tree contains a filesystem link."
			)
		var child := absolute.path_join(String(entry["name"]))
		if bool(entry["directory"]):
			var nested := _collect_source_tree(child, project_root, extensions, path_set)
			if not bool(nested.get("ok", false)):
				return nested
			continue
		var extension := ".%s" % String(entry["name"]).get_extension().to_lower()
		if extensions.has(extension):
			path_set[child.trim_prefix(project_root.trim_suffix("/") + "/")] = true
	return {"ok": true}


static func _verify_source_inventory(
	inventory: Dictionary, expected_commit: String, expected_paths: Array
) -> Dictionary:
	if String(inventory.get("commit_sha", "")) != expected_commit:
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "A BR9 source inventory names a different commit."
		)
	var files: Array = inventory.get("files", [])
	if (
		int(inventory.get("file_count", -1)) != files.size()
		or files.size() != expected_paths.size()
	):
		return _failure(
			FailureCodesScript.EVIDENCE_INVALID, "A BR9 source inventory count is inconsistent."
		)
	var project_root := _normalized_absolute(ProjectSettings.globalize_path("res://"))
	var previous_path := ""
	var seen: Dictionary = {}
	for file_index in files.size():
		var file_value: Variant = files[file_index]
		var entry: Dictionary = file_value
		var relative := String(entry["path"])
		if (
			relative != String(expected_paths[file_index])
			or seen.has(relative)
			or (not previous_path.is_empty() and relative <= previous_path)
		):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"BR9 source inventory paths are duplicated or not ordinally sorted."
			)
		seen[relative] = true
		previous_path = relative
		var absolute := project_root.path_join(relative)
		if (
			not _is_descendant(absolute, project_root)
			or _path_contains_link(absolute)
			or not FileAccess.file_exists(absolute)
			or _sha256_file(absolute) != String(entry["sha256"])
			or _file_size(absolute) != int(entry["bytes"])
		):
			return _failure(
				FailureCodesScript.EVIDENCE_INVALID,
				"A declared BR9 source file changed or disappeared.",
				{"path": relative}
			)
	return {"ok": true}


static func _unsigned_envelope(
	key_id: String, inspected: Dictionary, attested_utc: String
) -> Dictionary:
	return {
		"schema": RECEIPT_SCHEMA,
		"domain": RECEIPT_DOMAIN,
		"algorithm": ALGORITHM,
		"key_id": key_id,
		"certification_id": String(inspected["certification_id"]),
		"report_name": REPORT_NAME,
		"report_sha256": String(inspected["report_sha256"]),
		"report_bytes": int(inspected["report_bytes"]),
		"report_schema": REPORT_SCHEMA,
		"report_status": "pass",
		"certification": CERTIFICATION,
		"commit_sha": String(inspected["commit_sha"]),
		"campaign_id": CAMPAIGN_ID,
		"campaign_sha256": String(inspected["campaign_sha256"]),
		"attested_utc": attested_utc,
	}


static func _validate_paths(report_path: String, trust_root: String) -> Dictionary:
	var report := _normalized_absolute(report_path)
	var trust := _normalized_absolute(trust_root)
	var project := _normalized_absolute(ProjectSettings.globalize_path("res://"))
	if report.is_empty() or trust.is_empty():
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Report and trust-root paths must be absolute."
		)
	if _paths_overlap(report, trust):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Detached trust root must not overlap the report path."
		)
	if trust == project or _is_descendant(trust, project):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Detached trust root must remain outside the repository."
		)
	return {"ok": true, "report_path": report, "trust_root": trust}


static func _validate_test_trust_root(value: String) -> Dictionary:
	var root := _normalized_absolute(value)
	var temp := _normalized_absolute(OS.get_temp_dir())
	if root.is_empty() or temp.is_empty() or root == temp or not _is_descendant(root, temp):
		return _failure(
			FailureCodesScript.PUBLICATION_TRUST_ROOT_INVALID,
			"Test trust roots must be strict descendants of OS.get_temp_dir()."
		)
	return {"ok": true, "trust_root": root}


static func _load_active_key_reference(trust_root: String) -> Dictionary:
	var result := _read_json_object_exact(trust_root.path_join(ACTIVE_KEY_FILE), 1024 * 1024)
	if not bool(result.get("ok", false)):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_MISSING,
			"The BR9 report trust root has no readable active key pointer."
		)
	var pointer: Dictionary = result["value"]
	var expected_fields := ["schema_version", "algorithm", "key_id", "key_file"]
	if pointer.size() != expected_fields.size():
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"active_key.json contains an unexpected field set."
		)
	for field in expected_fields:
		if not pointer.has(field):
			return _failure(
				FailureCodesScript.PUBLICATION_KEY_INVALID,
				"active_key.json is missing an owned field."
			)
	var key_id := String(pointer["key_id"])
	if (
		String(pointer["schema_version"]) != ACTIVE_KEY_SCHEMA
		or String(pointer["algorithm"]) != ALGORITHM
		or not _is_sha256(key_id)
		or String(pointer["key_file"]) != "keys/%s.key" % key_id.trim_prefix("sha256:")
	):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"active_key.json uses an invalid schema, algorithm, or key identity."
		)
	return {"ok": true, "key_id": key_id}


static func _load_key_by_id(trust_root: String, key_id: String) -> Dictionary:
	if not _is_sha256(key_id):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID, "BR9 report receipt key_id is invalid."
		)
	var key_path := trust_root.path_join("keys").path_join("%s.key" % key_id.trim_prefix("sha256:"))
	if not _is_descendant(key_path, trust_root) or not FileAccess.file_exists(key_path):
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_MISSING, "BR9 report receipt key is missing."
		)
	var file := FileAccess.open(key_path, FileAccess.READ)
	if file == null or file.get_length() != KEY_BYTES:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"BR9 report HMAC keys must be exactly 32 bytes."
		)
	var key := file.get_buffer(KEY_BYTES)
	file.close()
	if key.size() != KEY_BYTES or not _constant_time_equal(_sha256_bytes(key), key_id):
		key.fill(0)
		key.resize(0)
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID,
			"BR9 report key bytes do not match their key_id."
		)
	return {"ok": true, "key": key}


static func _take_loaded_key(result: Dictionary) -> PackedByteArray:
	var key: PackedByteArray = result.get("key", PackedByteArray())
	result["key"] = PackedByteArray()
	return key


static func _write_receipt_new(path: String, receipt: Dictionary) -> Dictionary:
	var parent := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not create the BR9 report-receipt directory."
		)
	if _path_entry_exists(path):
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_COLLISION,
			"A BR9 report receipt already exists; receipts are append-only."
		)
	var reservation := "%s.attestation-lock" % path
	if DirAccess.make_dir_absolute(reservation) != OK:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_BUSY,
			"Another BR9 report attester owns this receipt path."
		)
	var temporary := reservation.path_join(
		"receipt-%d-%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	var serialized := CanonicalJsonScript.stringify(receipt) + "\n"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Could not open the BR9 report-receipt temporary file."
		)
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _path_entry_exists(path):
		DirAccess.remove_absolute(temporary)
		DirAccess.remove_absolute(reservation)
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"BR9 report receipt could not be safely installed."
		)
	var rename_error := DirAccess.rename_absolute(temporary, path)
	DirAccess.remove_absolute(reservation)
	if rename_error != OK or FileAccess.get_file_as_string(path) != serialized:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_WRITE_FAILED,
			"Installed BR9 report receipt differs from its canonical payload."
		)
	return {"ok": true}


static func _hmac_sha256(key: PackedByteArray, message: PackedByteArray) -> Dictionary:
	var context := HMACContext.new()
	if context.start(HashingContext.HASH_SHA256, key) != OK:
		return _failure(
			FailureCodesScript.PUBLICATION_KEY_INVALID, "HMAC-SHA-256 initialization failed."
		)
	if context.update(message) != OK:
		context.finish()
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID, "HMAC-SHA-256 message update failed."
		)
	var digest := context.finish()
	if digest.size() != 32:
		return _failure(
			FailureCodesScript.PUBLICATION_RECEIPT_INVALID,
			"HMAC-SHA-256 returned an invalid digest length."
		)
	return {"ok": true, "hex": digest.hex_encode()}


static func _read_json_object_exact(path: String, maximum_bytes: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > maximum_bytes:
		return {"ok": false}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {"ok": true, "value": parser.data, "bytes": bytes}


static func _read_file_bytes_exact(path: String, maximum_bytes: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > maximum_bytes:
		return {"ok": false}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false}
	return {"ok": true, "bytes": bytes, "text": text}


static func _sha256_file(path: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		if context.update(file.get_buffer(mini(CHUNK_BYTES, remaining))) != OK:
			context.finish()
			return ""
	return "sha256:%s" % context.finish().hex_encode()


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return "sha256:%s" % context.finish().hex_encode()


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1


static func _bytes_equal(left: PackedByteArray, right: PackedByteArray) -> bool:
	if left.size() != right.size():
		return false
	var difference := 0
	for index in left.size():
		difference = difference | (int(left[index]) ^ int(right[index]))
	return difference == 0


static func _constant_time_equal(left: String, right: String) -> bool:
	var left_bytes := left.to_utf8_buffer()
	var right_bytes := right.to_utf8_buffer()
	var difference := left_bytes.size() ^ right_bytes.size()
	var length := maxi(left_bytes.size(), right_bytes.size())
	for index in length:
		var left_byte := int(left_bytes[index]) if index < left_bytes.size() else 0
		var right_byte := int(right_bytes[index]) if index < right_bytes.size() else 0
		difference = difference | (left_byte ^ right_byte)
	return difference == 0


static func _path_contains_link(path: String) -> bool:
	var cursor := _normalized_absolute(path)
	if cursor.is_empty():
		return true
	var windows_root := RegEx.new()
	windows_root.compile("^[A-Za-z]:/?$")
	while true:
		if cursor == "/" or windows_root.search(cursor) != null:
			return false
		var parent := cursor.get_base_dir()
		if parent.is_empty() or parent == cursor:
			return false
		var leaf := cursor.get_file()
		var directory := DirAccess.open(parent)
		if directory != null and directory.is_link(leaf):
			return true
		cursor = parent
	return false


static func _paths_overlap(left: String, right: String) -> bool:
	return (
		_path_identity(left) == _path_identity(right)
		or _is_descendant(left, right)
		or _is_descendant(right, left)
	)


static func _is_descendant(candidate: String, parent: String) -> bool:
	var child := _path_identity(candidate)
	var root := _path_identity(parent).trim_suffix("/")
	return child.begins_with("%s/" % root)


static func _path_identity(path: String) -> String:
	return _normalized_absolute(path).trim_suffix("/").to_lower()


static func _normalized_absolute(path: String) -> String:
	var value := path.strip_edges().replace("\\", "/")
	if value.begins_with("res://") or value.begins_with("user://"):
		value = ProjectSettings.globalize_path(value).replace("\\", "/")
	value = value.simplify_path()
	var windows_absolute := RegEx.new()
	windows_absolute.compile("^[A-Za-z]:/")
	if value.is_empty() or (not value.begins_with("/") and windows_absolute.search(value) == null):
		return ""
	return value.trim_suffix("/")


static func _path_entry_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _is_safe_certification_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^br9_[0-9]{8}T[0-9]{6}Z_[a-f0-9]{8}$")
	return regex.search(value) != null


static func _is_sha256(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^sha256:[a-f0-9]{64}$")
	return regex.search(value) != null


static func _utc_now() -> String:
	var timestamp := Time.get_datetime_string_from_system(true, false)
	return timestamp if timestamp.ends_with("Z") else "%sZ" % timestamp


static func _failure(failure_code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"code": failure_code,
		"failure_code": failure_code,
		"message": message,
		"detail": detail,
	}
