# The comparator keeps normalization, exact mismatch reporting, process proof,
# and evidence digests together so exclusions cannot drift between modules.
# gdlint: disable=max-file-lines
class_name LabL0ReplicateComparator
extends RefCounted

## Strict BR1 same-seed, fresh-process replicate comparator.
##
## This comparator does not decide whether either run is truthful by itself.
## It first delegates that job to LabRunBundleValidator for both bundles and
## unconditionally requires detached attestation. It then compares values
## parsed only from authenticated read-once snapshots; caller options can
## select an explicit test trust root but cannot downgrade this boundary.
## Only two independently valid COMPLETE bundles cross it.
##
## The comparison is exact after CanonicalJson normalization. There is no
## floating-point epsilon here: a replicate is either the same canonical
## scientific observation or it is a measured divergence. The only omitted
## fields are the explicitly enumerated run-instance metadata below.

const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const AttestedBundleSnapshotScript := preload(
	"res://scripts/lab/attested_bundle_snapshot.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const COMPARATOR_ID := "sporespore.lab.br1_l0_replicate_comparator.v1"
const REQUIRED_PROCESS_ISOLATION := "outer_parent_reserved_fresh_godot_v1"
const MAX_REPORTED_MISMATCHES := 256

## These fields identify the execution instance, not its scientific state.
## Their omission is deliberately name-based and recursively applied. Additions
## require a comparator-version change and an adversarial test.
const EXCLUDED_RUN_FIELD_NAMES: Array[String] = [
	"run_id",
	"paired_run_id",
	"started_utc",
	"finalized_utc",
	"completed_utc",
	"created_utc",
	"ended_utc",
	"attested_utc",
	"parent_process_id",
	"child_process_id",
	"termination_observer_process_id",
	"process_id",
	"pid",
	"reservation_id",
	"adoption_token_sha256",
	"launch_plan_sha256",
	"launch_plan_payload_sha256",
	"bundle_path",
	"partial_path",
	"final_path",
	"output_root",
	"working_directory",
	"launch_plan_path",
	"token_descriptor_path",
	"engine_log_path",
	"stdout_path",
	"stderr_path",
	"receipt_path",
	"receipt_sha256",
	"command_payload_sha256",
	"intervention_payload_sha256",
	"source_payload_sha256",
	"record_sha256",
	"previous_record_sha256",
]

## Detached publication receipts authenticate a bundle but are not themselves
## physics. These complete containers are excluded if a future version embeds
## a receipt reference in a summary or runtime-note record.
const EXCLUDED_RECEIPT_CONTAINERS: Array[String] = [
	"publication_attestation",
	"publication_receipt",
	"receipt_metadata",
]

## A validator-valid legacy fixture can omit many modern identity fields. BR1
## certification cannot: absence of any of these makes "same experiment" an
## unprovable statement and therefore fails closed.
const REQUIRED_MANIFEST_IDENTITY_FIELDS: Array[String] = [
	"schema_set",
	"recorder_version",
	"experiment_id",
	"experiment_resource_path",
	"experiment_resource_sha256",
	"fixture_id",
	"fixture_version",
	"fixture_resource_path",
	"fixture_resource_sha256",
	"loaded_resource_hashes",
	"expanded_spec_sha256",
	"resolved_configuration_sha256",
	"applied_configuration_sha256",
	"godot_version",
	"godot_commit",
	"physics_backend",
	"physics_backend_adapter",
	"platform",
	"physics_ticks_per_second",
	"solver_velocity_iterations",
	"solver_position_iterations",
	"observer_profile",
	"observer_channel_set_sha256",
	"observer_parity_envelope_id",
	"contact_cap_per_body",
	"process_isolation",
	"body_dynamics",
	"joint_dynamics",
	"surface_materials",
	"seed_root",
	"rng_derivation",
	"rng_streams",
	"scaffolds_allowed",
	"scaffolds_forbidden",
	"expanded_parameters",
	"units",
]


static func compare(
		left_bundle_path: String,
		right_bundle_path: String,
		validator_options: Dictionary = {
			"attestation_requirement": "required",
		}) -> Dictionary:
	var left_path := _absolute(left_bundle_path)
	var right_path := _absolute(right_bundle_path)
	var mismatches: Array[Dictionary] = []
	var required_options := validator_options.duplicate(true)
	# Replicate comparison is a consuming boundary. A caller cannot downgrade
	# either side to structural-only validation.
	required_options["attestation_requirement"] = "required"
	var left_validation := BundleValidatorScript.validate_bundle(
		left_path, required_options)
	var right_validation := BundleValidatorScript.validate_bundle(
		right_path, required_options)
	if not bool(left_validation.get("ok", false)) \
			or not bool(left_validation.get("can_finalize", false)):
		_add_mismatch(
			mismatches,
			"LEFT_BUNDLE_VALIDATION_FAILED",
			"/left/validation",
			left_validation.get("errors", []),
			true,
			null,
			false)
	if not bool(right_validation.get("ok", false)) \
			or not bool(right_validation.get("can_finalize", false)):
		_add_mismatch(
			mismatches,
			"RIGHT_BUNDLE_VALIDATION_FAILED",
			"/right/validation",
			null,
			false,
			right_validation.get("errors", []),
			true)

	var snapshot_options: Dictionary = {}
	if required_options.has("attestation_test_root"):
		snapshot_options["attestation_test_root"] = String(
			required_options["attestation_test_root"])
	var left_capture: Dictionary = {}
	var right_capture: Dictionary = {}
	if mismatches.is_empty():
		left_capture = AttestedBundleSnapshotScript.capture_verified(
			left_path, snapshot_options)
		right_capture = AttestedBundleSnapshotScript.capture_verified(
			right_path, snapshot_options)
		if not bool(left_capture.get("ok", false)):
			_add_mismatch(
				mismatches,
				"LEFT_AUTHENTICATED_SNAPSHOT_FAILED",
				"/left/authenticated_snapshot",
				_safe_snapshot_failure(left_capture),
				true,
				null,
				false)
		if not bool(right_capture.get("ok", false)):
			_add_mismatch(
				mismatches,
				"RIGHT_AUTHENTICATED_SNAPSHOT_FAILED",
				"/right/authenticated_snapshot",
				null,
				false,
				_safe_snapshot_failure(right_capture),
				true)

	var left_witness_validated := _bundle_witness(
		left_path, left_validation)
	var right_witness_validated := _bundle_witness(
		right_path, right_validation)
	if mismatches.is_empty():
		var left_snapshot_witness: Dictionary = (
			left_capture["snapshot"].publication_witness())
		var right_snapshot_witness: Dictionary = (
			right_capture["snapshot"].publication_witness())
		if left_witness_validated.get("publication_attestation", {}) \
				!= left_snapshot_witness:
			_add_mismatch(
				mismatches,
				"LEFT_SNAPSHOT_WITNESS_MISMATCH",
				"/left/authenticated_snapshot/witness",
				left_witness_validated.get("publication_attestation", {}),
				true,
				left_snapshot_witness,
				true)
		if right_witness_validated.get("publication_attestation", {}) \
				!= right_snapshot_witness:
			_add_mismatch(
				mismatches,
				"RIGHT_SNAPSHOT_WITNESS_MISMATCH",
				"/right/authenticated_snapshot/witness",
				right_witness_validated.get("publication_attestation", {}),
				true,
				right_snapshot_witness,
				true)
	if not mismatches.is_empty():
		return _result(
			left_path,
			right_path,
			left_validation,
			right_validation,
			{},
			{},
			{},
			mismatches,
			{},
			{
				"left_initial": left_witness_validated,
				"right_initial": right_witness_validated,
			})

	var left_snapshot = left_capture["snapshot"]
	var right_snapshot = right_capture["snapshot"]
	var left_manifest_result: Dictionary = left_snapshot.read_json_object(
		"manifest.json")
	var right_manifest_result: Dictionary = right_snapshot.read_json_object(
		"manifest.json")
	if not left_manifest_result["ok"] or not right_manifest_result["ok"]:
		if not left_manifest_result["ok"]:
			_add_mismatch(
				mismatches,
				"MANIFEST_READ_FAILED",
				"/left/manifest.json",
				null,
				false,
				null,
				false)
		if not right_manifest_result["ok"]:
			_add_mismatch(
				mismatches,
				"MANIFEST_READ_FAILED",
				"/right/manifest.json",
				null,
				false,
				null,
				false)
		return _result(
			left_path,
			right_path,
			left_validation,
			right_validation,
			{},
			{},
			{},
			mismatches,
			{},
			{
				"left_initial": left_witness_validated,
				"right_initial": right_witness_validated,
			})

	var left_manifest: Dictionary = left_manifest_result["value"]
	var right_manifest: Dictionary = right_manifest_result["value"]
	var left_run_id := String(left_manifest.get("run_id", ""))
	var right_run_id := String(right_manifest.get("run_id", ""))
	if left_path == right_path:
		_add_mismatch(
			mismatches,
			"BUNDLE_PATH_NOT_DISTINCT",
			"/bundle_paths",
			left_path,
			true,
			right_path,
			true)
	if left_run_id.is_empty() or left_run_id == right_run_id:
		_add_mismatch(
			mismatches,
			"RUN_ID_NOT_DISTINCT",
			"/run_ids",
			left_run_id,
			true,
			right_run_id,
			true)

	_check_required_identity_fields(
		left_manifest, right_manifest, mismatches)
	_check_configuration_hashes(
		left_manifest, right_manifest, mismatches)
	var process_proof := _check_fresh_process_proof(
		left_snapshot,
		right_snapshot,
		left_manifest,
		right_manifest,
		mismatches)

	var normalized_left_manifest: Variant = _normalize_scientific(
		left_manifest)
	var normalized_right_manifest: Variant = _normalize_scientific(
		right_manifest)
	_compare_values(
		normalized_left_manifest,
		normalized_right_manifest,
		"/identity/manifest",
		mismatches)
	var identity_report := {
		"left_digest": _digest(normalized_left_manifest),
		"right_digest": _digest(normalized_right_manifest),
		"match": normalized_left_manifest == normalized_right_manifest,
		"required_fields": REQUIRED_MANIFEST_IDENTITY_FIELDS.duplicate(),
	}

	_compare_optional_configuration(
		left_snapshot, right_snapshot, mismatches, identity_report)
	var stream_report := _compare_jsonl_streams(
		left_snapshot, right_snapshot, mismatches)
	var summary_report := _compare_summaries(
		left_snapshot, right_snapshot, mismatches)
	# Defense in depth for persistent replacement after snapshot capture.
	# Scientific comparison correctness does not depend on these later path
	# reads: all compared values above came from the exact authenticated
	# snapshot buffers, so an ABA restore cannot substitute different evidence.
	var left_post_validation := BundleValidatorScript.validate_bundle(
		left_path, required_options)
	var right_post_validation := BundleValidatorScript.validate_bundle(
		right_path, required_options)
	var left_witness_after := _bundle_witness(
		left_path, left_post_validation)
	var right_witness_after := _bundle_witness(
		right_path, right_post_validation)
	if not bool(left_post_validation.get("ok", false)) \
			or not bool(left_post_validation.get("can_finalize", false)):
		_add_mismatch(
			mismatches,
			"LEFT_POST_READ_VALIDATION_FAILED",
			"/left/post_read_validation",
			left_validation.get("errors", []),
			true,
			left_post_validation.get("errors", []),
			true)
	if not bool(right_post_validation.get("ok", false)) \
			or not bool(right_post_validation.get("can_finalize", false)):
		_add_mismatch(
			mismatches,
			"RIGHT_POST_READ_VALIDATION_FAILED",
			"/right/post_read_validation",
			right_validation.get("errors", []),
			true,
			right_post_validation.get("errors", []),
			true)
	_check_witness_unchanged(
		"left",
		left_witness_validated,
		left_witness_after,
		"/left/post_read_witness",
		mismatches)
	_check_witness_unchanged(
		"right",
		right_witness_validated,
		right_witness_after,
		"/right/post_read_witness",
		mismatches)

	return _result(
		left_path,
		right_path,
		left_validation,
		right_validation,
		identity_report,
		process_proof,
		{
			"streams": stream_report,
			"summary": summary_report,
		},
		mismatches,
		{
			"left": left_post_validation,
			"right": right_post_validation,
		},
		{
			"left_initial": left_witness_validated,
			"left_post_read": left_witness_after,
			"right_initial": right_witness_validated,
			"right_post_read": right_witness_after,
		})


static func _check_required_identity_fields(
		left: Dictionary,
		right: Dictionary,
		mismatches: Array[Dictionary]) -> void:
	for field in REQUIRED_MANIFEST_IDENTITY_FIELDS:
		var left_has := left.has(field)
		var right_has := right.has(field)
		if not left_has or not right_has:
			_add_mismatch(
				mismatches,
				"IDENTITY_FIELD_MISSING",
				"/identity/manifest/%s" % _pointer_segment(field),
				left.get(field),
				left_has,
				right.get(field),
				right_has)


static func _check_configuration_hashes(
		left: Dictionary,
		right: Dictionary,
		mismatches: Array[Dictionary]) -> void:
	for side_value in [
		{"name": "left", "manifest": left},
		{"name": "right", "manifest": right},
	]:
		var side: Dictionary = side_value
		var manifest: Dictionary = side["manifest"]
		var resolved := String(manifest.get(
			"resolved_configuration_sha256", ""))
		var applied := String(manifest.get(
			"applied_configuration_sha256", ""))
		if resolved.is_empty() or applied.is_empty() or resolved != applied:
			_add_mismatch(
				mismatches,
				"CONFIGURATION_IDENTITY_INVALID",
				"/%s/manifest.json/configuration_sha256" % side["name"],
				resolved,
				not resolved.is_empty(),
				applied,
				not applied.is_empty())


static func _check_fresh_process_proof(
		left_snapshot: LabAttestedBundleSnapshot,
		right_snapshot: LabAttestedBundleSnapshot,
		left_manifest: Dictionary,
		right_manifest: Dictionary,
		mismatches: Array[Dictionary]) -> Dictionary:
	for side_value in [
		{"name": "left", "manifest": left_manifest},
		{"name": "right", "manifest": right_manifest},
	]:
		var side: Dictionary = side_value
		var manifest: Dictionary = side["manifest"]
		if String(manifest.get("process_isolation", "")) \
				!= REQUIRED_PROCESS_ISOLATION:
			_add_mismatch(
				mismatches,
				"FRESH_PROCESS_POLICY_MISSING",
				"/%s/manifest.json/process_isolation" % side["name"],
				manifest.get("process_isolation"),
				manifest.has("process_isolation"),
				REQUIRED_PROCESS_ISOLATION,
				true)

	var left_result: Dictionary = left_snapshot.read_json_object(
		"process_metadata.json")
	var right_result: Dictionary = right_snapshot.read_json_object(
		"process_metadata.json")
	if not left_result["ok"] or not right_result["ok"]:
		if not left_result["ok"]:
			_add_mismatch(
				mismatches,
				"PROCESS_METADATA_MISSING",
				"/left/process_metadata.json",
				null,
				false,
				null,
				false)
		if not right_result["ok"]:
			_add_mismatch(
				mismatches,
				"PROCESS_METADATA_MISSING",
				"/right/process_metadata.json",
				null,
				false,
				null,
				false)
		return {
			"ok": false,
			"required_policy": REQUIRED_PROCESS_ISOLATION,
		}

	var left: Dictionary = left_result["value"]
	var right: Dictionary = right_result["value"]
	var left_child := _exact_positive_integer(left.get("child_process_id"))
	var right_child := _exact_positive_integer(right.get("child_process_id"))
	var left_parent := _exact_positive_integer(left.get("parent_process_id"))
	var right_parent := _exact_positive_integer(right.get("parent_process_id"))
	var left_terminal_valid := (
		String(left.get("status", "")) == "COMPLETE"
		and int(left.get("exit_code", -1)) == 0
		and String(left.get("argument_capture_quality", ""))
			== "launcher_exact"
		and String(left.get("run_id", ""))
			== String(left_manifest.get("run_id", ""))
		and left_child > 0
		and left_parent > 0
		and left_child != left_parent)
	var right_terminal_valid := (
		String(right.get("status", "")) == "COMPLETE"
		and int(right.get("exit_code", -1)) == 0
		and String(right.get("argument_capture_quality", ""))
			== "launcher_exact"
		and String(right.get("run_id", ""))
			== String(right_manifest.get("run_id", ""))
		and right_child > 0
		and right_parent > 0
		and right_child != right_parent)
	if not left_terminal_valid:
		_add_mismatch(
			mismatches,
			"PROCESS_PROVENANCE_INVALID",
			"/left/process_metadata.json",
			_normalize_scientific(left),
			true,
			null,
			false)
	if not right_terminal_valid:
		_add_mismatch(
			mismatches,
			"PROCESS_PROVENANCE_INVALID",
			"/right/process_metadata.json",
			null,
			false,
			_normalize_scientific(right),
			true)
	if left_child > 0 and left_child == right_child:
		_add_mismatch(
			mismatches,
			"CHILD_PROCESS_NOT_DISTINCT",
			"/process_metadata/child_process_id",
			left_child,
			true,
			right_child,
			true)
	if left_parent > 0 and left_parent == right_parent:
		_add_mismatch(
			mismatches,
			"OUTER_PARENT_PROCESS_NOT_DISTINCT",
			"/process_metadata/parent_process_id",
			left_parent,
			true,
			right_parent,
			true)
	var left_outer_identity := {
		"parent_process_id": left_parent,
		"child_process_id": left_child,
		"started_utc": String(left.get("started_utc", "")),
		"reservation_id": String(left.get("reservation_id", "")),
		"launch_plan_payload_sha256": String(left.get(
			"launch_plan_payload_sha256", "")),
		"run_id": String(left.get("run_id", "")),
	}
	var right_outer_identity := {
		"parent_process_id": right_parent,
		"child_process_id": right_child,
		"started_utc": String(right.get("started_utc", "")),
		"reservation_id": String(right.get("reservation_id", "")),
		"launch_plan_payload_sha256": String(right.get(
			"launch_plan_payload_sha256", "")),
		"run_id": String(right.get("run_id", "")),
	}
	var left_outer_identity_digest := _digest(left_outer_identity)
	var right_outer_identity_digest := _digest(right_outer_identity)
	var outer_launch_fields_complete := (
		not String(left_outer_identity["started_utc"]).is_empty()
		and not String(left_outer_identity["reservation_id"]).is_empty()
		and not String(left_outer_identity[
			"launch_plan_payload_sha256"]).is_empty()
		and not String(right_outer_identity["started_utc"]).is_empty()
		and not String(right_outer_identity["reservation_id"]).is_empty()
		and not String(right_outer_identity[
			"launch_plan_payload_sha256"]).is_empty())
	var outer_launches_distinct := (
		left_parent > 0
		and right_parent > 0
		and left_parent != right_parent
		and left_child != right_child
		and left_outer_identity_digest != right_outer_identity_digest
		and String(left_outer_identity["reservation_id"])
			!= String(right_outer_identity["reservation_id"])
		and String(left_outer_identity["launch_plan_payload_sha256"])
			!= String(right_outer_identity["launch_plan_payload_sha256"]))
	if not outer_launch_fields_complete or not outer_launches_distinct:
		_add_mismatch(
			mismatches,
			"OUTER_LAUNCH_IDENTITY_NOT_DISTINCT",
			"/process_metadata/outer_launch_identity",
			left_outer_identity,
			true,
			right_outer_identity,
			true)
	return {
		"ok": (
			left_terminal_valid
			and right_terminal_valid
			and outer_launch_fields_complete
			and outer_launches_distinct),
		"required_policy": REQUIRED_PROCESS_ISOLATION,
		"left": {
			"parent_process_id": left_parent,
			"child_process_id": left_child,
			"outer_launch_identity_digest":
				left_outer_identity_digest,
			"status": left.get("status"),
			"exit_code": left.get("exit_code"),
		},
		"right": {
			"parent_process_id": right_parent,
			"child_process_id": right_child,
			"outer_launch_identity_digest":
				right_outer_identity_digest,
			"status": right.get("status"),
			"exit_code": right.get("exit_code"),
		},
	}


static func _compare_optional_configuration(
		left_snapshot: LabAttestedBundleSnapshot,
		right_snapshot: LabAttestedBundleSnapshot,
		mismatches: Array[Dictionary],
		identity_report: Dictionary) -> void:
	var left_has := left_snapshot.artifact_names().has(
		"configuration.json")
	var right_has := right_snapshot.artifact_names().has(
		"configuration.json")
	if left_has != right_has:
		_add_mismatch(
			mismatches,
			"CONFIGURATION_ARTIFACT_MISSING",
			"/identity/configuration.json",
			"present" if left_has else null,
			left_has,
			"present" if right_has else null,
			right_has)
		identity_report["configuration"] = {
			"present": false,
			"match": false,
		}
		return
	if not left_has:
		identity_report["configuration"] = {
			"present": false,
			"match": true,
			"identity_source": "manifest_configuration_hashes",
		}
		return
	var left_result: Dictionary = left_snapshot.read_json_object(
		"configuration.json")
	var right_result: Dictionary = right_snapshot.read_json_object(
		"configuration.json")
	if not left_result["ok"] or not right_result["ok"]:
		_add_mismatch(
			mismatches,
			"CONFIGURATION_ARTIFACT_READ_FAILED",
			"/identity/configuration.json",
			left_result.get("value"),
			bool(left_result.get("ok", false)),
			right_result.get("value"),
			bool(right_result.get("ok", false)))
		identity_report["configuration"] = {
			"present": true,
			"match": false,
		}
		return
	var left_normalized: Variant = _normalize_scientific(
		left_result["value"])
	var right_normalized: Variant = _normalize_scientific(
		right_result["value"])
	_compare_values(
		left_normalized,
		right_normalized,
		"/identity/configuration.json",
		mismatches)
	identity_report["configuration"] = {
		"present": true,
		"left_digest": _digest(left_normalized),
		"right_digest": _digest(right_normalized),
		"match": left_normalized == right_normalized,
	}


static func _compare_jsonl_streams(
		left_snapshot: LabAttestedBundleSnapshot,
		right_snapshot: LabAttestedBundleSnapshot,
		mismatches: Array[Dictionary]) -> Dictionary:
	var left_names := _sealed_jsonl_names(left_snapshot)
	var right_names := _sealed_jsonl_names(right_snapshot)
	var union: Array[String] = []
	for name in left_names + right_names:
		if not union.has(name):
			union.append(name)
	union.sort()
	var streams: Dictionary = {}
	for stream_name in union:
		var left_has := left_names.has(stream_name)
		var right_has := right_names.has(stream_name)
		var stream_path := "/streams/%s" % _pointer_segment(stream_name)
		if not left_has or not right_has:
			_add_mismatch(
				mismatches,
				"STREAM_MISSING",
				stream_path,
				"present" if left_has else null,
				left_has,
				"present" if right_has else null,
				right_has)
			streams[stream_name] = {
				"left_present": left_has,
				"right_present": right_has,
				"match": false,
			}
			continue
		var left_result: Dictionary = left_snapshot.read_jsonl(
			stream_name, true)
		var right_result: Dictionary = right_snapshot.read_jsonl(
			stream_name, true)
		if not left_result["ok"] or not right_result["ok"]:
			_add_mismatch(
				mismatches,
				"STREAM_READ_FAILED",
				stream_path,
				left_result.get("records"),
				bool(left_result.get("ok", false)),
				right_result.get("records"),
				bool(right_result.get("ok", false)))
			streams[stream_name] = {
				"left_present": true,
				"right_present": true,
				"match": false,
			}
			continue
		var left_records: Array = _normalize_record_array(
			left_result["records"])
		var right_records: Array = _normalize_record_array(
			right_result["records"])
		var left_digest := _digest(left_records)
		var right_digest := _digest(right_records)
		if _is_frame_stream(stream_name):
			_compare_frame_records(
				left_records,
				right_records,
				stream_path,
				mismatches)
		else:
			_compare_values(
				left_records,
				right_records,
				stream_path,
				mismatches)
		streams[stream_name] = {
			"left_records": left_records.size(),
			"right_records": right_records.size(),
			"left_digest": left_digest,
			"right_digest": right_digest,
			"match": left_digest == right_digest,
		}
	return {
		"names": union,
		"count": union.size(),
		"comparisons": streams,
	}


static func _compare_frame_records(
		left_records: Array,
		right_records: Array,
		path: String,
		mismatches: Array[Dictionary]) -> void:
	var left_map := _frames_by_id(
		left_records, "%s/left" % path, mismatches)
	var right_map := _frames_by_id(
		right_records, "%s/right" % path, mismatches)
	var frame_ids: Array[int] = []
	for raw_id in left_map.keys() + right_map.keys():
		var frame_id := int(raw_id)
		if not frame_ids.has(frame_id):
			frame_ids.append(frame_id)
	frame_ids.sort()
	for frame_id in frame_ids:
		var left_has := left_map.has(frame_id)
		var right_has := right_map.has(frame_id)
		var frame_path := "%s/frames/%d" % [path, frame_id]
		if not left_has or not right_has:
			_add_mismatch(
				mismatches,
				"FRAME_MISSING",
				frame_path,
				left_map.get(frame_id),
				left_has,
				right_map.get(frame_id),
				right_has)
			continue
		_compare_values(
			left_map[frame_id],
			right_map[frame_id],
			frame_path,
			mismatches)


static func _frames_by_id(
		records: Array,
		path: String,
		mismatches: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for index in records.size():
		var record: Variant = records[index]
		if typeof(record) != TYPE_DICTIONARY \
				or not (record as Dictionary).has("frame_id"):
			_add_mismatch(
				mismatches,
				"FRAME_ID_MISSING",
				"%s/%d/frame_id" % [path, index],
				record,
				true,
				null,
				false)
			continue
		var exact_id := _exact_nonnegative_integer(
			(record as Dictionary)["frame_id"])
		if exact_id < 0 or result.has(exact_id):
			_add_mismatch(
				mismatches,
				"FRAME_ID_INVALID",
				"%s/%d/frame_id" % [path, index],
				(record as Dictionary)["frame_id"],
				true,
				null,
				false)
			continue
		result[exact_id] = record
	return result


static func _compare_summaries(
		left_snapshot: LabAttestedBundleSnapshot,
		right_snapshot: LabAttestedBundleSnapshot,
		mismatches: Array[Dictionary]) -> Dictionary:
	var left_result: Dictionary = left_snapshot.read_json_object(
		"summary.json")
	var right_result: Dictionary = right_snapshot.read_json_object(
		"summary.json")
	if not left_result["ok"] or not right_result["ok"]:
		_add_mismatch(
			mismatches,
			"SUMMARY_READ_FAILED",
			"/summary.json",
			left_result.get("value"),
			bool(left_result.get("ok", false)),
			right_result.get("value"),
			bool(right_result.get("ok", false)))
		return {"match": false}
	var left: Variant = _normalize_scientific(left_result["value"])
	var right: Variant = _normalize_scientific(right_result["value"])
	_compare_values(left, right, "/summary.json", mismatches)
	return {
		"left_digest": _digest(left),
		"right_digest": _digest(right),
		"match": left == right,
		"compared_fields": [
			"all summary fields except EXCLUDED_RUN_FIELD_NAMES",
			"metrics",
			"gate_results",
		],
	}


static func _compare_values(
		left: Variant,
		right: Variant,
		path: String,
		mismatches: Array[Dictionary]) -> void:
	if mismatches.size() >= MAX_REPORTED_MISMATCHES:
		return
	if typeof(left) != typeof(right):
		_add_mismatch(
			mismatches,
			"VALUE_TYPE_MISMATCH",
			path,
			left,
			true,
			right,
			true)
		return
	if typeof(left) == TYPE_DICTIONARY:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		var keys: Array[String] = []
		for raw_key in left_dictionary.keys() + right_dictionary.keys():
			var key := String(raw_key)
			if not keys.has(key):
				keys.append(key)
		keys.sort()
		for key in keys:
			var left_has := left_dictionary.has(key)
			var right_has := right_dictionary.has(key)
			var child_path := "%s/%s" % [path, _pointer_segment(key)]
			if not left_has or not right_has:
				_add_mismatch(
					mismatches,
					"VALUE_MISSING",
					child_path,
					left_dictionary.get(key),
					left_has,
					right_dictionary.get(key),
					right_has)
				continue
			_compare_values(
				left_dictionary[key],
				right_dictionary[key],
				child_path,
				mismatches)
		return
	if typeof(left) == TYPE_ARRAY:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			_add_mismatch(
				mismatches,
				"ARRAY_LENGTH_MISMATCH",
				path,
				left_array.size(),
				true,
				right_array.size(),
				true)
		var shared_size := mini(left_array.size(), right_array.size())
		for index in shared_size:
			_compare_values(
				left_array[index],
				right_array[index],
				"%s/%d" % [path, index],
				mismatches)
		for index in range(shared_size, maxi(
				left_array.size(), right_array.size())):
			var left_has := index < left_array.size()
			var right_has := index < right_array.size()
			_add_mismatch(
				mismatches,
				"VALUE_MISSING",
				"%s/%d" % [path, index],
				left_array[index] if left_has else null,
				left_has,
				right_array[index] if right_has else null,
				right_has)
		return
	if left != right:
		_add_mismatch(
			mismatches,
			"VALUE_MISMATCH",
			path,
			left,
			true,
			right,
			true)


static func _normalize_scientific(value: Variant) -> Variant:
	return CanonicalJsonScript.normalize(_strip_run_metadata(value))


static func _strip_run_metadata(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		var result: Dictionary = {}
		for raw_key in source:
			var key := String(raw_key)
			if EXCLUDED_RUN_FIELD_NAMES.has(key) \
					or EXCLUDED_RECEIPT_CONTAINERS.has(key):
				continue
			result[key] = _strip_run_metadata(source[raw_key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value:
			result.append(_strip_run_metadata(item))
		return result
	return value


static func _normalize_record_array(records: Array) -> Array:
	var normalized: Array = []
	for record in records:
		normalized.append(_normalize_scientific(record))
	return normalized


static func _sealed_jsonl_names(snapshot: LabAttestedBundleSnapshot) -> Array[String]:
	var result: Array[String] = []
	var checksums_result: Dictionary = snapshot.read_json_object(
		"checksums.json")
	if not checksums_result["ok"]:
		return result
	var artifacts: Variant = (
		checksums_result["value"] as Dictionary).get("artifacts")
	if typeof(artifacts) != TYPE_DICTIONARY:
		return result
	for raw_name in (artifacts as Dictionary):
		var name := String(raw_name)
		var entry: Variant = (artifacts as Dictionary)[raw_name]
		if name.ends_with(".jsonl") \
				or (
					typeof(entry) == TYPE_DICTIONARY
					and String((entry as Dictionary).get("kind", ""))
						== "jsonl"
				):
			result.append(name)
	result.sort()
	return result


static func _is_frame_stream(stream_name: String) -> bool:
	return stream_name == "frames.jsonl" \
		or stream_name.ends_with("_frames.jsonl")


static func _exact_positive_integer(value: Variant) -> int:
	var parsed := _exact_nonnegative_integer(value)
	return parsed if parsed > 0 else -1


static func _exact_nonnegative_integer(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value) if int(value) >= 0 else -1
	if (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and float(value) >= 0.0
		and float(value) <= 9007199254740991.0
		and floor(float(value)) == float(value)
	):
		return int(value)
	return -1


static func _digest(value: Variant) -> String:
	return CanonicalJsonScript.sha256(value)


static func _bundle_witness(
		bundle_path: String,
		validation: Dictionary = {}) -> Dictionary:
	var witness := {
		"bundle_path": bundle_path,
	}
	var stats_value: Variant = validation.get("stats")
	var attestation: Variant = (
		(stats_value as Dictionary).get("publication_attestation")
		if typeof(stats_value) == TYPE_DICTIONARY
		else null)
	if typeof(attestation) == TYPE_DICTIONARY \
			and not (attestation as Dictionary).is_empty():
		var attestation_value: Dictionary = attestation
		witness["publication_attestation"] = {
			"ok": bool(attestation_value.get("ok", false)),
			"algorithm": String(attestation_value.get("algorithm", "")),
			"trust_mode": String(attestation_value.get(
				"trust_mode", "")),
			"receipt_sha256": String(attestation_value.get(
				"receipt_sha256", "")),
			"key_id": String(attestation_value.get("key_id", "")),
			"run_id": String(attestation_value.get("run_id", "")),
			"checksums_sha256": String(attestation_value.get(
				"checksums_sha256", "")),
			"manifest_sha256": String(attestation_value.get(
				"manifest_sha256", "")),
			"artifact_count": int(attestation_value.get(
				"artifact_count", -1)),
			"attested_utc": String(attestation_value.get(
				"attested_utc", "")),
		}
	return witness


static func _safe_snapshot_failure(failure: Dictionary) -> Dictionary:
	return {
		"failure_code": String(failure.get(
			"failure_code", failure.get("code", ""))),
		"message": String(failure.get("message", "")),
		"path": String(failure.get("path", "")),
	}


static func _check_witness_unchanged(
		_side: String,
		before: Dictionary,
		after: Dictionary,
		path: String,
		mismatches: Array[Dictionary]) -> void:
	if before == after:
		return
	_add_mismatch(
		mismatches,
		"BUNDLE_CHANGED_DURING_COMPARISON",
		path,
		before,
		true,
		after,
		true)


static func _add_mismatch(
		mismatches: Array[Dictionary],
		code: String,
		path: String,
		left: Variant,
		left_present: bool,
		right: Variant,
		right_present: bool) -> void:
	if mismatches.size() >= MAX_REPORTED_MISMATCHES:
		return
	mismatches.append({
		"code": code,
		"path": path,
		"left_present": left_present,
		"right_present": right_present,
		"left_digest": _digest(left) if left_present else null,
		"right_digest": _digest(right) if right_present else null,
	})


static func _result(
		left_path: String,
		right_path: String,
		left_validation: Dictionary,
		right_validation: Dictionary,
		identity: Dictionary,
		process_proof: Dictionary,
		evidence: Dictionary,
		mismatches: Array[Dictionary],
		post_validations: Dictionary = {},
		witnesses: Dictionary = {}) -> Dictionary:
	var left_evidence: Variant = _side_evidence_digest(
		identity, evidence, "left")
	var right_evidence: Variant = _side_evidence_digest(
		identity, evidence, "right")
	return {
		"ok": mismatches.is_empty(),
		"comparator_id": COMPARATOR_ID,
		"left_bundle_path": left_path,
		"right_bundle_path": right_path,
		"left_validation": left_validation,
		"right_validation": right_validation,
		"post_read_validations": post_validations,
		"bundle_witnesses": witnesses,
		"identity": identity,
		"fresh_process_proof": process_proof,
		"evidence": evidence,
		"left_evidence_digest": left_evidence,
		"right_evidence_digest": right_evidence,
		"mismatch_count": mismatches.size(),
		"mismatches": mismatches,
		"mismatch_limit": MAX_REPORTED_MISMATCHES,
		"excluded_run_field_names": EXCLUDED_RUN_FIELD_NAMES.duplicate(),
		"excluded_receipt_containers":
			EXCLUDED_RECEIPT_CONTAINERS.duplicate(),
	}


static func _side_evidence_digest(
		identity: Dictionary,
		evidence: Dictionary,
		side: String) -> Variant:
	var identity_digest: Variant = identity.get("%s_digest" % side)
	var summary: Dictionary = evidence.get("summary", {})
	var streams: Dictionary = evidence.get("streams", {})
	var stream_digests: Dictionary = {}
	var comparisons: Dictionary = streams.get("comparisons", {})
	for stream_name in comparisons:
		var comparison: Dictionary = comparisons[stream_name]
		stream_digests[stream_name] = comparison.get("%s_digest" % side)
	if identity_digest == null \
			and summary.get("%s_digest" % side) == null \
			and stream_digests.is_empty():
		return null
	return _digest({
		"identity": identity_digest,
		"summary": summary.get("%s_digest" % side),
		"streams": stream_digests,
	})


static func _pointer_segment(value: String) -> String:
	return value.replace("~", "~0").replace("/", "~1")


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
