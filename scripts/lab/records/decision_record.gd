class_name LabDecisionRecord
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")


static func seal(fields: Dictionary) -> Dictionary:
	var value := fields.duplicate(true)
	value["schema"] = "sporespore.lab.decision.v1"
	return FrozenValueScript.snapshot(CanonicalJsonScript.normalize(value))
