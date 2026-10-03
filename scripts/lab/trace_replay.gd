class_name LabTraceReplay
extends RefCounted

## Read-only evidence playback.
##
## This class reconstructs the recorded timeline from immutable artifacts. It
## never creates a scene, advances a simulation, or reads live body state.
## Derived values are replayed only from summary/mechanics evidence; changing
## current project settings cannot change the returned timeline.

const BundleValidatorScript := preload("res://scripts/lab/run_bundle_validator.gd")
const AttestedBundleSnapshotScript := preload(
	"res://scripts/lab/attested_bundle_snapshot.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")

var _loaded := false
var _bundle_path := ""
var _manifest: Dictionary = {}
var _summary: Dictionary = {}
var _checksums: Dictionary = {}
var _frames: Array = []
var _events: Array = []
var _mechanics: Array = []
var _runtime_notes: Array = []
var _publication_attestation: Dictionary = {}


# Each early return preserves the first precise trust/read failure rather than
# collapsing independent evidence failures into one generic status.
# gdlint: disable=max-returns
func load_bundle(
		bundle_path: String,
		validation_options: Dictionary = {}) -> Dictionary:
	if _loaded:
		return _failure("A TraceReplay instance may load exactly one bundle.")
	var absolute_path := ProjectSettings.globalize_path(bundle_path).replace("\\", "/")
	var required_options := validation_options.duplicate(true)
	# Playback is a consuming trust boundary. Callers cannot downgrade it to a
	# structural-only check or bypass validation.
	required_options["attestation_requirement"] = "required"
	var validation_before := BundleValidatorScript.validate_bundle(
		absolute_path, required_options)
	if not bool(validation_before.get("ok", false)) \
			or not bool(validation_before.get("can_finalize", false)):
		return {
			"ok": false,
			"code": FailureCodesScript.TRACE_REPLAY_FAILED,
			"message": "Bundle failed required attestation before playback.",
			"details": validation_before,
		}
	var snapshot_options: Dictionary = {}
	if required_options.has("attestation_test_root"):
		snapshot_options["attestation_test_root"] = String(
			required_options["attestation_test_root"])
	var captured := AttestedBundleSnapshotScript.capture_verified(
		absolute_path, snapshot_options)
	if not bool(captured.get("ok", false)):
		return {
			"ok": false,
			"code": FailureCodesScript.TRACE_REPLAY_FAILED,
			"message":
				"Bundle could not be captured as one authenticated read-once snapshot.",
			"details": captured,
		}
	var snapshot = captured["snapshot"]
	var witness_before := _publication_witness(validation_before)
	var snapshot_witness: Dictionary = snapshot.publication_witness()
	if witness_before != snapshot_witness:
		return {
			"ok": false,
			"code": FailureCodesScript.TRACE_REPLAY_FAILED,
			"message":
				"Validator and read-once snapshot do not identify the same publication.",
			"details": {
				"validator": witness_before,
				"snapshot": snapshot_witness,
			},
		}
	var manifest_result: Dictionary = snapshot.read_json_object(
		"manifest.json")
	if not manifest_result["ok"]:
		return _snapshot_failure(
			"Authenticated manifest.json could not be parsed.", manifest_result)
	var summary_result: Dictionary = snapshot.read_json_object("summary.json")
	if not summary_result["ok"]:
		return _snapshot_failure(
			"Authenticated summary.json could not be parsed.", summary_result)
	var checksum_result: Dictionary = snapshot.read_json_object(
		"checksums.json")
	if not checksum_result["ok"]:
		return _snapshot_failure(
			"Authenticated checksums.json could not be parsed.", checksum_result)
	var frame_result: Dictionary = snapshot.read_jsonl("frames.jsonl", true)
	if not frame_result["ok"]:
		return _snapshot_failure(
			"Authenticated frames.jsonl could not be parsed.", frame_result)
	var note_result: Dictionary = snapshot.read_jsonl(
		"runtime_notes.jsonl", true)
	if not note_result["ok"]:
		return _snapshot_failure(
			"Authenticated runtime_notes.jsonl could not be parsed.",
			note_result)
	var event_result: Dictionary = snapshot.read_jsonl("events.jsonl", false)
	if not event_result["ok"]:
		return _snapshot_failure(
			"Authenticated events.jsonl could not be parsed.", event_result)
	var mechanics_result: Dictionary = snapshot.read_jsonl(
		"mechanics.jsonl", false)
	if not mechanics_result["ok"]:
		return _snapshot_failure(
			"Authenticated mechanics.jsonl could not be parsed.",
			mechanics_result)
	# This second pass is defense in depth for persistent path replacement.
	# Replay correctness does not depend on it: every returned value below was
	# already parsed from the exact buffers authenticated by snapshot_witness.
	var validation_after := BundleValidatorScript.validate_bundle(
		absolute_path, required_options)
	if not bool(validation_after.get("ok", false)) \
			or not bool(validation_after.get("can_finalize", false)):
		return {
			"ok": false,
			"code": FailureCodesScript.TRACE_REPLAY_FAILED,
			"message": "Bundle failed required attestation after playback read.",
			"details": validation_after,
		}
	var witness_after := _publication_witness(validation_after)
	if witness_before != witness_after:
		return {
			"ok": false,
			"code": FailureCodesScript.TRACE_REPLAY_FAILED,
			"message": "Bundle or detached publication receipt changed during playback read.",
			"details": {
				"before": witness_before,
				"after": witness_after,
			},
		}

	_bundle_path = absolute_path
	_manifest = manifest_result["value"]
	_summary = summary_result["value"]
	_checksums = checksum_result["value"]
	_frames = frame_result["records"]
	_runtime_notes = note_result["records"]
	_events = event_result["records"]
	_mechanics = mechanics_result["records"]
	_publication_attestation = (
		validation_after["stats"]["publication_attestation"])
	_loaded = true
	return {
		"ok": true,
		"run_id": _manifest["run_id"],
		"frame_count": _frames.size(),
		"event_count": _events.size(),
		"mechanics_count": _mechanics.size(),
		"publication_attestation": _publication_attestation,
	}
# gdlint: enable=max-returns


func replay() -> Dictionary:
	if not _loaded:
		return _failure("No completed bundle has been loaded.")
	var timeline: Array = []
	for frame_value in _frames:
		var frame: Dictionary = frame_value
		var body_transforms: Dictionary = {}
		var bodies: Variant = frame.get("bodies", {})
		if typeof(bodies) == TYPE_DICTIONARY:
			var ids := (bodies as Dictionary).keys()
			ids.sort()
			for body_id_value in ids:
				var body_id := String(body_id_value)
				var body: Dictionary = bodies[body_id_value]
				body_transforms[body_id] = body.get("transform", null)
		elif typeof(bodies) == TYPE_ARRAY:
			for body_value in bodies:
				if typeof(body_value) != TYPE_DICTIONARY:
					continue
				var body: Dictionary = body_value
				body_transforms[String(body.get("body_id", ""))] = body.get("transform", null)
		timeline.append({
			"frame_id": int(frame.get("frame_id", -1)),
			"physics_time_s": float(frame.get("physics_time_s", 0.0)),
			"sample_phase": String(frame.get("sample_phase", "")),
			"experiment_phase": String(frame.get("experiment_phase", "")),
			"body_transforms": body_transforms,
		})

	var event_order: Array = []
	for event_value in _events:
		var event: Dictionary = event_value
		event_order.append({
			"event_sequence": int(event.get("event_sequence", -1)),
			"frame_id": int(event.get("frame_id", -1)),
			"event": String(event.get("event", event.get("code", ""))),
			"subject_id": String(event.get("subject_id", "")),
		})

	var metric_values: Dictionary = {}
	for metric_value in _summary.get("metrics", []):
		var metric: Dictionary = metric_value
		metric_values[String(metric["metric_id"])] = metric["value"]

	return FrozenValueScript.snapshot({
		"ok": true,
		"run_id": _manifest["run_id"],
		"bundle_path": _bundle_path,
		"simulation_steps": 0,
		"timeline": timeline,
		"event_order": event_order,
		"metrics": metric_values,
		"metric_provenance": _summary.get("metrics", []),
		"mechanics_records": _mechanics,
		"runtime_notes": _runtime_notes,
		"artifact_hashes": _checksums.get("artifacts", {}),
		"publication_attestation": _publication_attestation,
	})


func frame(frame_id: int) -> Dictionary:
	if not _loaded:
		return {}
	for frame_value in _frames:
		var value: Dictionary = frame_value
		if int(value.get("frame_id", -1)) == frame_id:
			return FrozenValueScript.snapshot(value)
	return {}


static func replay_bundle(
		bundle_path: String,
		validation_options: Dictionary = {}) -> Dictionary:
	# Loading by resource path avoids relying on global class-cache registration
	# while this same script is being compiled by a headless test process.
	var replay_script: GDScript = load("res://scripts/lab/trace_replay.gd")
	var instance = replay_script.new()
	var loaded: Dictionary = instance.call(
		"load_bundle", bundle_path, validation_options)
	if not loaded["ok"]:
		return loaded
	return instance.call("replay")


static func _publication_witness(
		validation: Dictionary) -> Dictionary:
	var attestation: Dictionary = validation.get(
		"stats", {}).get("publication_attestation", {})
	return {
		"ok": bool(attestation.get("ok", false)),
		"algorithm": String(attestation.get("algorithm", "")),
		"trust_mode": String(attestation.get("trust_mode", "")),
		"receipt_sha256": String(attestation.get(
			"receipt_sha256", "")),
		"key_id": String(attestation.get("key_id", "")),
		"run_id": String(attestation.get("run_id", "")),
		"checksums_sha256": String(attestation.get(
			"checksums_sha256", "")),
		"manifest_sha256": String(attestation.get(
			"manifest_sha256", "")),
		"artifact_count": int(attestation.get("artifact_count", -1)),
		"attested_utc": String(attestation.get("attested_utc", "")),
	}


static func _snapshot_failure(
		message: String,
		details: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"code": FailureCodesScript.TRACE_REPLAY_FAILED,
		"message": message,
		"details": details,
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"code": FailureCodesScript.TRACE_REPLAY_FAILED,
		"message": message,
	}
