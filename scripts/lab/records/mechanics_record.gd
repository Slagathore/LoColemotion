class_name LabMechanicsRecord
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func seal(fields: Dictionary) -> Dictionary:
	var value := fields.duplicate(true)
	value["schema"] = "sporespore.lab.mechanics.v1"
	return FrozenValueScript.snapshot(value)
