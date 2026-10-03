class_name LabInterventionExecutor
extends RefCounted

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")


static func apply_intervention_envelope(
		envelope: Dictionary,
		bodies_by_stable_id: Dictionary,
		receipt_sink: RefCounted) -> Dictionary:
	if not envelope.has("payload") or not envelope.has("intervention_payload_sha256"):
		return {"ok": false, "error": "INTERVENTION_ENVELOPE_MALFORMED"}
	var payload: Dictionary = envelope["payload"]
	var payload_sha := String(envelope["intervention_payload_sha256"])
	if CanonicalJsonScript.sha256(payload) != payload_sha:
		return {"ok": false, "error": "INTERVENTION_HASH_MISMATCH"}
	if String(payload.get("record_kind", "")) != "planned_operation":
		return {"ok": false, "error": "INTERVENTION_NOT_A_PLAN"}
	if not bool(payload.get("allowed", false)):
		return {"ok": false, "error": "INTERVENTION_FORBIDDEN"}
	var api := String(payload.get("planned_api", ""))
	var body_id := String(payload.get("target_body_id", ""))
	var receipt_base := {
		"source_kind": "intervention",
		"source_record_id": "intervention:%s" % String(payload.get("operation_id", "")),
		"source_payload_sha256": payload_sha,
		"operation_id": String(payload.get("operation_id", "")),
		"executor_call_ordinal": receipt_sink.call("next_call_ordinal"),
		"api": api,
		"target_body_id": body_id,
		"arguments": {},
	}
	if api == "lab.synthetic_noop":
		receipt_sink.call("append_call_returned", receipt_base)
		return {"ok": true, "applied_count": 1}
	if api != "RigidBody3D.apply_central_impulse" or not bodies_by_stable_id.has(body_id):
		receipt_sink.call("append_call_failed", receipt_base, "EXECUTOR_TARGET_OR_API_INVALID")
		return {"ok": false, "error": "EXECUTOR_TARGET_OR_API_INVALID"}
	var impulse: Vector3 = payload.get(
		"linear_impulse_world_n_s", Vector3(INF, INF, INF))
	receipt_base["arguments"] = {"linear_impulse_world_n_s": impulse}
	if not impulse.is_finite():
		receipt_sink.call("append_call_failed", receipt_base, "NONFINITE_OPERATION_ARGUMENT")
		return {"ok": false, "error": "NONFINITE_OPERATION_ARGUMENT"}
	var body: RigidBody3D = bodies_by_stable_id[body_id]
	body.apply_central_impulse(impulse)
	receipt_sink.call("append_call_returned", receipt_base)
	return {"ok": true, "applied_count": 1}
