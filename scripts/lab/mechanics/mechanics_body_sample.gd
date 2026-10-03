class_name LabMechanicsBodySample
extends RefCounted

## Append-only projection from the sealed frame_v1 body dictionary into the
## richer identity contract used by BR2+ mechanics estimators.  The source
## dictionary is never modified, so published frame_v1 bytes and schemas stay
## untouched.  Run/capture identity is attached at the acquisition seam and is
## then carried by each body independently; estimators can therefore reject a
## pair of samples that merely happen to share step numbers.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const SCHEMA_VERSION := "mechanics_body_sample_v1"
const SOURCE_SCHEMA_VERSION := "frame_v1_body"


static func project(
		source: Dictionary,
		run_id: String,
		capture_stream_id: String) -> Dictionary:
	var reasons: Array[String] = []
	if run_id.is_empty():
		reasons.append("RUN_ID_INVALID")
	if capture_stream_id.is_empty():
		reasons.append("CAPTURE_STREAM_ID_INVALID")
	for field in ["observer_profile_id", "observer_adapter_id", "body_id"]:
		var value: Variant = source.get(field)
		if not (value is String or value is StringName) \
				or String(value).is_empty():
			reasons.append("SOURCE_%s_INVALID" % field.to_upper())
	if typeof(source.get("physics_step_id")) != TYPE_INT \
			or int(source.get("physics_step_id", -1)) < 0:
		reasons.append("SOURCE_PHYSICS_STEP_INVALID")
	if typeof(source.get("capture_epoch")) != TYPE_INT \
			or int(source.get("capture_epoch", -1)) < 0:
		reasons.append("SOURCE_CAPTURE_EPOCH_INVALID")
	var source_phase: Variant = source.get("sample_phase")
	if not (source_phase is String or source_phase is StringName) \
			or String(source_phase).is_empty():
		reasons.append("SOURCE_SAMPLE_PHASE_INVALID")
	if not reasons.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false,
			"errors": reasons,
			"sample": null,
		})

	var sample := source.duplicate(true)
	sample["schema_version"] = SCHEMA_VERSION
	sample["source_schema_version"] = SOURCE_SCHEMA_VERSION
	sample["run_id"] = run_id
	sample["capture_stream_id"] = capture_stream_id
	# A finite source can be canonically hashed.  Nonfinite samples remain
	# useful to per-channel availability logic, but cannot pretend to possess a
	# canonical source digest.
	var source_finite := bool(source.get("finite", false))
	sample["source_sample_digest_sha256"] = (
		CanonicalJsonScript.sha256(source) if source_finite else null)
	return FrozenValueScript.snapshot({
		"ok": true,
		"errors": [],
		"sample": sample,
	})
