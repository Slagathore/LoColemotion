class_name LabActuationExecutor
extends RefCounted

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")


static func apply_command_envelope(
		envelope: Dictionary,
		bodies_by_stable_id: Dictionary,
		receipt_sink: RefCounted) -> Dictionary:
	if not envelope.has("payload") or not envelope.has("command_payload_sha256"):
		return {"ok": false, "error": "COMMAND_ENVELOPE_MALFORMED"}
	var payload: Dictionary = envelope["payload"]
	var payload_sha := String(envelope["command_payload_sha256"])
	if CanonicalJsonScript.sha256(payload) != payload_sha:
		return {"ok": false, "error": "COMMAND_HASH_MISMATCH"}
	var seen: Dictionary = {}
	for joint_command in payload.get("joint_commands", []):
		for operation in joint_command.get("planned_application_operations", []):
			var operation_id := String(operation.get("operation_id", ""))
			if operation_id.is_empty() or seen.has(operation_id):
				return {"ok": false, "error": "DUPLICATE_OR_EMPTY_OPERATION_ID"}
			seen[operation_id] = true
			var api := String(operation.get("api", "RigidBody3D.apply_torque"))
			var body_id := String(operation.get("body_id", ""))
			var receipt_base := {
				"source_kind": "command",
				"source_record_id": "command:%d" % int(payload["command_id"]),
				"source_payload_sha256": payload_sha,
				"operation_id": operation_id,
				"executor_call_ordinal": receipt_sink.call("next_call_ordinal"),
				"api": api,
				"target_body_id": body_id,
				"arguments": operation.get("arguments", {
					"torque_world_nm": operation.get("torque_world_nm", Vector3.ZERO),
				}),
			}
			if api == "lab.synthetic_noop":
				receipt_sink.call("append_call_returned", receipt_base)
				continue
			if api != "RigidBody3D.apply_torque" or not bodies_by_stable_id.has(body_id):
				receipt_sink.call("append_call_failed", receipt_base, "EXECUTOR_TARGET_OR_API_INVALID")
				return {"ok": false, "error": "EXECUTOR_TARGET_OR_API_INVALID"}
			var torque: Vector3 = operation.get(
				"torque_world_nm", Vector3(INF, INF, INF))
			if not torque.is_finite():
				receipt_sink.call("append_call_failed", receipt_base, "NONFINITE_OPERATION_ARGUMENT")
				return {"ok": false, "error": "NONFINITE_OPERATION_ARGUMENT"}
			var body: RigidBody3D = bodies_by_stable_id[body_id]
			body.apply_torque(torque)
			receipt_sink.call("append_call_returned", receipt_base)
	return {"ok": true, "applied_count": seen.size()}
