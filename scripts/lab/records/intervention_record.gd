class_name LabInterventionRecord
extends RefCounted

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func seal(payload_fields: Dictionary) -> Dictionary:
	var builder := payload_fields.duplicate(true)
	builder["schema"] = "sporespore.lab.intervention.v1"
	var payload: Dictionary = FrozenValueScript.snapshot(
		CanonicalJsonScript.normalize(builder))
	return FrozenValueScript.snapshot({
		"intervention_payload_sha256": CanonicalJsonScript.sha256(payload),
		"payload": payload,
	})
